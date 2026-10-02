clear
close all 

%% New version that doesn't use moving averages or initial estimates.
% uses carving of entire area try and find wing tip initially. Can run with
% any starting frame and use parallel processing

%% This version uses carving to try and find the point furthest from wing base.
% Updated to use first calibration grid for orientation  

%% EDITABLE PART %%
% folder where recordings are stored
% base_folder   = fullfile('D:','Micro_arena','Soldier Fly');
% 
% date_folders={'2026_08_27';
%               '2026_08_28';
%               '2026_09_02';
%               '2026_09_03'};

base_folder   = fullfile('Z:','Beth_Microarena','Calliphora');
date_folders={'2026_08_18';
              '2026_08_19';
              '2026_09_09'};

project_folder ='Calliphora';

%% END EDITABLE PART %%

% sequence_pref='S_Fly';

dates_all=[];
sequences_all=[];

for D=1:length(date_folders)

    d=dir(fullfile(project_folder,'single_wing_init_points',date_folders{D},'*_init_click.mat'));

    sequences={d.name};

    sequences_all=[sequences_all;sequences'];
    dates_all=[dates_all;repmat(date_folders(D),length(sequences),1)];
end

for S=1:length(sequences_all)

    clearvars -except project_folder S base_folder dates_all sequences_all
    
    date_folder=dates_all{S};

    sequence=sequences_all{S};
    sequence_name=erase(sequence, '_init_click.mat');

    if ~exist(fullfile('single_wing_tracked_points',date_folder,[sequence_name '_tracked_wt.mat']),'file')
        
        sequence_base = regexprep(sequence_name, '\d+$', '');
        background_name=[sequence_base 'Background'];
        
        % load calibration file - assumed to be in base_folder -> date_folder
        % calib_name='Calib_AM_S_Fly settings results';

        d=dir(fullfile(project_folder,'calibrations',date_folder,'*.mat'));
        calib_name=d.name;
        load(fullfile(project_folder,'calibrations',date_folder, calib_name));

        max_wing_length=12; % estimate of maximum likely wing length (mm)
                
        % whether to subtract the body (and potentially legs) or just the large
        % mask
        subtract_body=0;
        
        % create different sized structural elements for morphological operations
        se1 = strel('disk',1);
        se2 = strel('disk',2);
        se3 = strel('disk',3);
        se5 = strel('disk',5,8);
        
        se10 = strel('disk',10,6);
        se20 = strel('disk',20,8);
        se40 = strel('disk',40,8);
        
        % create initial carving voxels
        carve_xlim0=[-1  1]*max_wing_length;
        carve_ylim0=[-0.1 1]*max_wing_length;
        carve_zlim0=[-1  1]*max_wing_length;
        
        [voxels_wing0, res_wing] = makevoxels( carve_xlim0, carve_ylim0, carve_zlim0, 600000);
        
        voxels_hwing0=sqrt(sum(voxels_wing0.^2));
        voxels_wing0(:,voxels_hwing0<max_wing_length*0.2)=NaN;
        voxels_wing0(:,voxels_hwing0>max_wing_length)=NaN;
        
        % can try getting rid of vertical column, but doesn't seem to be needed
        % voxels_vwing0=sqrt(sum(voxels_wing0(1:2,:).^2));
        % voxels_vwing0(voxels_wing0(3,:)<0)=inf;
        % voxels_wing0(:,voxels_vwing0<max_wing_length*0.2)=NaN;
        
        voxels_wing0(:,isnan(voxels_wing0(1,:)))=[];
        
        % plot3(voxels_wt0(1,:),voxels_wt0(2,:),voxels_wt0(3,:),'.');axis image; labels
        % return
        
        % mask for wing
        [ym,xm]=pol2cart(linspace(-pi/5,pi/4,8),1);
        xmask0=[xm xm(end-1) flip(xm(3:end-3),2) xm(1) xm(1)];
        ymask0=[ym+0.3 0.5 -(flip(ym(3:end-3),2)-0.9) 0.5 ym(1)+0.2];
        
        thresh_wings=20.*2^4; % based on <255-thresh_wings from background subtracted image
        thresh_body=230.*2^4; % based on >thresh_body from original image
        thresh_background_body=180.*2^4; % used for stacked background image
      
        f_start=1;
    
        % load initial points
        load(fullfile(project_folder,'single_wing_init_points',date_folder,[sequence_name '_init_click.mat']))
        load(fullfile(project_folder,'single_wing_backgrounds',date_folder,[sequence_name '_backgrounds.mat']))
    
        % end
        % find camera file in sequence folder
        filenames=dir(fullfile(base_folder,date_folder,sequence_name,'*.cihx'));
        filenames={filenames.name};
    
        filenames=filenames(1:6);
        % number of cameras
        num_cams=length(filenames);
        
        % empty variables for number of frames and image size
        n_frames=NaN(1,num_cams);
        im_size=NaN(2,num_cams);
    
        % for each camera load the video file and check it's 
        for v=1:num_cams
    
            % get filename excluding extension
            % [~,name,ext] = fileparts(filenames{v});
            
            % function for loading raw video file
            vid(v)=quick_parse_cihx(fullfile(base_folder,date_folder,sequence_name,filenames{v}));
            
            % number of frames
            n_frames(v)=vid(v).TotalFrame;
            
            % image size
            im_size(:,v)=[vid(v).ImageHeight vid(v).ImageWidth];
    
            % load background images (image without insect there)
            vid_back(v)=quick_parse_cihx(fullfile(base_folder,date_folder,background_name,filenames{v}));
            im_vid_back{v}=readmraw(vid_back(v),1);
    
            bw_back{v}=false(im_size(:,v)');
            bw_back{v}(im_back{v}<(2^12-thresh_background_body))=1;
    
            bw_back{v}=imopen(bw_back{v},se20);
            bw_back{v}=imdilate(bw_back{v},se40);
    
            bw_back{v}=bwareafilt(bw_back{v}, 1);
    
            % B = imshowpair(im_back{v},bw_back{v},'blend');
            % return
    
        end
    
        % recording rate
        Fs=vid(1).RecordRate_fps;
    
        % take minimum on chance cameras recorded different number of frames
        n_frames=min(n_frames);
    
        % calculate 3D points of initial estimates of wing tips and wing bases
        % [Xwt_init,Ywt_init,Zwt_init,resnorm_wt_init,residual_wt_init]=calc3D(xwtL',ywtL',calib_data);
        [Xwb,Ywb,Zwb,resnorm_wb,residual_wb,~,Xwb0,Ywb0,Zwb0]=calc3D(xwbL',ywbL',calib_data);
        % [XwbR,YwbR,ZwbR,resnorm_wbR,residual_wbR]=calc3D(xwbR',ywbR',calib_data);
        % [Xant,Yant,Zant,resnorm_ant,residual_ant]=calc3D(xant',yant',calib_data);
    
        % create initial carving voxels
        carve_xlim0=[-1  1]*max_wing_length*0.1;
        carve_ylim0=[-1  1]*max_wing_length*0.1;
        carve_zlim0=[-1  1]*max_wing_length*0.1;
        
        [voxels_wt0, res_wt] = makevoxels( carve_xlim0, carve_ylim0, carve_zlim0, 600000);
        
        voxels_hwt0=sqrt(sum(voxels_wt0.^2));
        voxels_wt0(:,voxels_hwt0>max_wing_length*0.1)=[];
    
        %% Get initial x y coords and make stack
        
        xwt_init=NaN(1,num_cams);
        ywt_init=NaN(1,num_cams);
    
        % for each camera reproject 3D wingtip and wingbase points back into 2D
        for v=1:num_cams
    
            % [xwt_ref(:,v),ywt_ref(:,v)]=reproject_points(calib_data,v,[Xwt_init',Ywt_init',Zwt_init'],1);
            [xwb(:,v),ywb(:,v)]=reproject_points(calib_data,v,[Xwb',Ywb',Zwb'],1);
                        
        end
    
        % if starting at the beginning of the sequence, create empty variables 
        xxwtL=NaN(n_frames,num_cams);
        yywtL=NaN(n_frames,num_cams);

        Xwt0=NaN(n_frames,1);
        Ywt0=NaN(n_frames,1);
        Zwt0=NaN(n_frames,1);

        Xwt=NaN(n_frames,1);
        Ywt=NaN(n_frames,1);
        Zwt=NaN(n_frames,1);
    
        % display sequence number in command window
        fprintf('\n\n')
        
        f_start=1;
        % tic
        % run from current frame to end-5 frames
        parfor f=f_start:n_frames
            
            % tic
    
            %% image processing for each camera
    
            % create empty cell arrays
            im=cell(1,num_cams);
            im2=cell(1,num_cams);
    
            bw=cell(1,num_cams);
            bw2=cell(1,num_cams);
    
            bw_body=cell(1,num_cams);
    
            S_body=cell(1,num_cams);
            S_wing=cell(1,num_cams);
    
            for v=1:num_cams
    
                im{v}=readmraw(vid(v),f);
    
                % background subtraction
    
                im2{v}=im_vid_back{v}-im{v};
              
                % imagesc2(im2{v});
                % 
                % return
    
                % now threshold the image
                bw{v}=false(size(im2{v}));
                bw{v}(im2{v}>thresh_wings)=1;
                % return
    
                % open the image - gets ride of small speckles or bits of legs
                bw2{v}=imopen(bw{v},se1);
    
                % then close the image
                % bw2{v}=imclose(bw2{v},se2);
    
                bw_body{v}=bw2{v};
                bw_body{v}(im2{v}<thresh_body)=0;
                % bw_body{v}=imfill(bw_body{v},'holes');
    
                % bw_body{v}=imopen(bw_body{v},se2);
    
                S_wing{v}=bw2{v};
                S_wing{v}=bwareafilt(bw2{v}, 1);
    
                if subtract_body==1
                    S_body{v} = bw_body{v};
                    S_body{v} = logical(imdilate(bwareafilt(bw_body{v}, 1),se5)+bw_back{v});
                else
                    S_body{v} = bw_back{v};
    
                end
               
            end
    
            % Now use carving to find initial estimate of wing. Can
            % subtract body and legs
            voxels_wing=voxels_wing0+[Xwb;Ywb;Zwb];
    
            % XX_wt_edge0=voxels_wing;
    
            R2=rodrigues(calib_data.om_grids(:,1));
            T2=calib_data.T_grids(:,1);
    
            voxels_wing=R2*voxels_wing+repmat(T2,1,size(voxels_wing,2));
    
            starting_volume = size(voxels_wing,2);
    
            % index so that points can be matched up between the two carves
            index_wing=1:starting_volume;
    
            voxels_all=voxels_wing;
            % voxels_body=voxels_wing;
    
            index_all=index_wing;
            % index_body=index_wing;
            % tic
    
            for v=1:num_cams
    
                [voxels_all,index_all] = carve2_scale_crop(voxels_all, v, S_wing{v}, calib_data, index_all, 1);
                % [voxels_body,index_body] = carve2_scale_crop(voxels_body, v, imdilate(S_body{v},se5), calib_data, index_body, 1);
            end
    
            voxels_body=voxels_all;
            index_body=index_all;
    
            for v=1:num_cams
    
                [voxels_body,index_body] = carve2_scale_crop(voxels_body, v, S_body{v}, calib_data, index_body, 1);
    
            end
            % toc
    
            index_wing = setdiff(index_all, index_body, 'stable');
            voxels_wing=voxels_wing(:,index_wing);
    
            voxels_wing00=voxels_wing0(:,index_wing);
    
            [L,numClusters,sizeClusters]=labelVoxels(voxels_wing00',sqrt(3*res_wing.^2));
    
            index_wing2=find(L==find(sizeClusters==max(sizeClusters)));
    
            % voxels_wing02=voxels_wing00(:,index_wing2);
            voxels_wing2=voxels_wing(:,index_wing2);
    
            h_wing2=sqrt(sum((voxels_wing2-[Xwb0;Ywb0;Zwb0]).^2));
    
            % gives initial estimate of where wing tip is
            XXwt_init=voxels_wing2(:,find(h_wing2==max(h_wing2),1));
    
            % Now use carving to find more exact wingtip point
    
            voxels_wt=voxels_wt0+XXwt_init;
    
    %             return
            % create voxels for the everything and the wings
    
            starting_volume = size(voxels_wt,2);
    
            % index so that points can be matched up between the two carves
            index_wt=1:starting_volume;
    
            % plot3(voxels_all(1,:),voxels_all(2,:),voxels_all(3,:),'.','markersize',1); hold on
            % plot3(voxels_body(1,:),voxels_body(2,:),voxels_body(3,:),'.r'); hold on
            % plot3(voxels_wing2(1,:),voxels_wing2(2,:),voxels_wing2(3,:),'.g'); hold on
            % plot3(Xwb0,Ywb0,Zwb0,'.m','markersize',20); hold on
            % plot3(XXwt_init(1),XXwt_init(2),XXwt_init(3),'.m','markersize',20)
            % % 
            % % plot3(voxels_wt(1,:),voxels_wt(2,:),voxels_wt(3,:),'.')
            % % axis image
            % % 
            % return
    
            
            for v= 1:num_cams
    
               [voxels_wt,index_wt,x_cropped,y_cropped,x_rep,y_rep,x_keep,y_keep] = carve2_scale_crop(voxels_wt, v, S_wing{v}, calib_data, index_wt);
    
            end
    
            h_wt=sqrt(sum((voxels_wt-[Xwb0;Ywb0;Zwb0]).^2));
    
            % gives initial estimate of where wing tip is
            XX_wt0=voxels_wt(:,find(h_wt==max(h_wt),1));
    
            Xwt0(f)=XX_wt0(1);
            Ywt0(f)=XX_wt0(2);
            Zwt0(f)=XX_wt0(3);
    
            XX_wt=R2'*(XX_wt0-T2);

            Xwt(f)=XX_wt(1);
            Ywt(f)=XX_wt(2);
            Zwt(f)=XX_wt(3);
        
            % plot3(voxels_wing2(1,:),voxels_wing2(2,:),voxels_wing2(3,:),'.'); hold on
            % plot3(voxels_wt(1,:),voxels_wt(2,:),voxels_wt(3,:),'.')
            % axis image
            % labels
            % return
    
            % toc
            % pause(0);
            % plot tracker results
    %             if draw==1
    %                 vv=1;
    %                 stop_vid=0;
    % 
    %                 for v=1:num_cams
    %                     % if it's the first frame create subplot for each camera view
    % 
    %                     [xwt_ref(:,v),ywt_ref(:,v)]=reproject_points(calib_data,v,[Xwt(f),Ywt(f),Zwt(f)]);
    % 
    %                     xxwtL(f,v)=xwt_ref(:,v);
    %                     yywtL(f,v)=ywt_ref(:,v);
    % 
    %                     if f==f_curr
    % 
    %                         if v==1
    %                             figure
    %                         end
    % 
    %                         if num_cams==4
    %                             subplot(2,2,vv)
    %                         else
    %                             subplot(2,3,vv)
    %                         end
    % 
    %                         I(v)=imagesc(im{v}); hold on
    %                         colormap(gray)
    %                         axis image
    %                         caxis([0 2^12])
    %                         axis([0.5 im_size(2,v)+0.5 0.5 im_size(1,v)+0.5]);
    % 
    %                         T(v)=text(320,30,['Frame ' num2str(f) ' of ' num2str(n_frames)],'horizontalalignment','center');
    %                         PwtL(v)=plot([xwt_ref(v) xwb(v)],[ywt_ref(v) ywb(v)],'.-b','markersize',20);
    %                         % PmaskL(v)=patch(xmask{v}([1:end 1]),ymask{v}([1:end 1]),'b','facealpha',0.3);
    % 
    %                         set(T(v),'color','g')
    % 
    %                         if num_cams==4
    %                             if vv<3
    %                                 set(gca,'position',[0+0.5*(vv-1) 0.5 0.5 0.5])
    %                             else
    %                                 set(gca,'position',[0+0.5*(vv-3) 0 0.5 0.5])
    %                             end
    % % 
    %                             set(gcf,'position',[1 300 768 528])
    %                         else
    % 
    %                             if vv==1
    %                                 set(gca,'position',[0 0.48 1/3 0.48]);
    %                             elseif vv==2
    %                                 set(gca,'position',[1/3 0.48 1/3 0.48]);
    %                             elseif vv==3
    %                                 set(gca,'position',[2/3 0.48 1/3 0.48]);
    %                             elseif v==4
    %                                 set(gca,'position',[0 0 1/3 0.48]);
    %                             elseif v==5
    %                                 set(gca,'position',[1/3 0 1/3 0.48]);
    %                             else
    %                                 set(gca,'position',[2/3 0 1/3 0.48]);
    %                             end
    % 
    %                             set(gcf,'position',[100 100 1024 683])
    %                         end
    % 
    %                         axis off
    %                         caxis([0 2^12])
    % 
    %                         vv=vv+1;
    % 
    %                     else
    %                         % for other frames, just update graphics
    %                         set(I(v),'cdata',im{v});
    %                         set(T(v),'string',['Frame ' num2str(f) ' of ' num2str(n_frames)])
    %                         set(PwtL(v),'xdata',[xwt_ref(v) xwb(1,v)],'ydata',[ywt_ref(v) ywb(1,v)]);
    %                         % set(PmaskL(v),'xdata',xmask{v}([1:end 1]),'ydata',ymask{v}([1:end 1]));
    % 
    %                         if isnan(xxwtL(f,v))
    %                             set(PwtL(v),'color','r')
    %                             stop_vid=1;
    %                         else
    %                             set(PwtL(v),'color','b')
    %                         end
    %                     end
    %                 end
    % 
    %                 % refresh onscreen
    %                 drawnow
    %                 % return
    % 
    %                 if stop_vid==1
    %                     return
    %                 end
    % 
    %                 % if i==1110
    %                     % return
    %                 % end
    % 
    %             end
    
        end
        % toc
        % check if there is already a 
        if ~exist(fullfile(project_folder,'single_wing_tracked_points',date_folder),'dir')
            mkdir(fullfile(project_folder,'single_wing_tracked_points',date_folder))
        end
    
        if ~exist(fullfile(project_folder,'wt_path_png',date_folder),'dir')
            mkdir(fullfile(project_folder,'wt_path_png',date_folder))
        end
        
        disp(['finished ' sequence_name])
        save(fullfile(project_folder,'single_wing_tracked_points',date_folder,[sequence_name '_tracked_wt.mat']),'Xwt','Ywt','Zwt','Xwt0','Ywt0','Zwt0','xxwtL','yywtL','Xwb','Ywb','Zwb','Xwb0','Ywb0','Zwb0','Fs','n_frames')
    
        plot3(Xwt0,Ywt0,Zwt0,'linewidth',1.5);axis image; hold on
        plot3(Xwb0,Ywb0,Zwb0,'.','markersize',25)
        xlabel('x (mm)')
        ylabel('x (mm)')
        zlabel('x (mm)')

        set(gcf,'color','w','position',[100 100 1024 1024])
        set(gca,'fontsize',18,'linewidth',2)
        sequence_title = replace(sequence_name, '_', '-');
        title([sequence_title ' wt path'])

        drawnow
        pause(0.2)
        % return
% 
        print('-dpng','-r0',fullfile(project_folder,'wt_path_png',date_folder,[sequence_name '.png']))
        close
    end

end
