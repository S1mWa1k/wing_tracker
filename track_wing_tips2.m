clear
close all 

%% This version uses carving to try and find the point furthest from wing base.
% Updated to use first calibration grid for orientation  

%% EDITABLE PART %%
% folder where recordings are stored
base_folder=fullfile('D:','Micro_arena');
date_folder='2026_06_30';
sequence_name='Fly7_a'; % assummed to be in date folder

% load calibration file - assumed to be in base_folder -> date_folder
calib_name='Fly6_calib_results_0dist';

% cameras that have consistent views of the wingtip
ref_cameras=[3 4]; 
%% END EDITABLE PART %%

% set to 0 to disable drawing while the tracker runs (improves speed).
draw=1;

use_cameras=[1 2 3 4 5 6];

% create different sized structural elements for morphological operations
se1 = strel('disk',1);
se2 = strel('disk',2);
se3 = strel('disk',3);
se5 = strel('disk',5,8);

se10 = strel('disk',10,6);
se20 = strel('disk',20,8);
se40 = strel('disk',40,8);

% mask for wing
[ym,xm]=pol2cart(linspace(-pi/5,pi/4,8),1);
xmask0=[xm xm(end-1) flip(xm(3:end-3),2) xm(1) xm(1)];
ymask0=[ym+0.3 0.5 -(flip(ym(3:end-3),2)-0.9) 0.5 ym(1)+0.2];

% return
% thresholds for background subtraction
% thresh=[100 100 100 100 100 100].*2^3; % old value
% thresh_body=20.*2^3;  % old value

thresh_wings=10.*2^4; % based on <255-thresh_wings from background subtracted image
thresh_body=20.*2^4; % based on >thresh_body from original image

% create empty variable
sequences=[];

% variable to determine if loaded tracked points file is already complete
finished=0;

% check that initial points have already been clicked on
if exist(fullfile('single_wing_init_points',[sequence_name '_init_click_combined.mat']),'file')

    % load initial points
    load(fullfile('single_wing_init_points',[sequence_name '_init_click_combined.mat']))
  
    f_start=i_start;

    f_curr=f_start;
    % end
    % if the sequence isn't already finished, run tracker
    if finished==0

        % find camera file in sequence folder
        filenames=dir(fullfile(base_folder,date_folder,sequence_name,'*.cihx'));
        filenames={filenames.name};

        filenames=filenames(1:6);
        % number of cameras
        num_cams=length(filenames);

        % calib_name='calib_results_0dist.mat';
        % calib_name='calib_results';

        load(fullfile(base_folder,date_folder,calib_name))

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
            % vid_backgrounds(v)=parse_cih(fullfile(sequence_folders{S},'background1',[name,'.cih']));
            % im_back{v}=readmraw(vid_backgrounds(v),1);

        end

        % recording rate
        Fs=vid(1).RecordRate_fps;

        % take minimum on chance cameras recorded different number of frames
        n_frames=min(n_frames);

        % calculate 3D points of initial estimates of wing tips and wing bases
        [Xwt_init,Ywt_init,Zwt_init,resnorm_wt_init,residual_wt_init]=calc3D(xwtL',ywtL',calib_data);
        [Xwb,Ywb,Zwb,resnorm_wb,residual_wb,~,Xwb0,Ywb0,Zwb0]=calc3D(xwbL',ywbL',calib_data);
        [XwbR,YwbR,ZwbR,resnorm_wbR,residual_wbR]=calc3D(xwbR',ywbR',calib_data);
        [Xant,Yant,Zant,resnorm_ant,residual_ant]=calc3D(xant',yant',calib_data);

        wing_length_init=sqrt((Xwt_init-Xwb).^2+(Ywt_init-Ywb).^2+(Zwt_init-Zwb).^2);
        % create initial carving voxels
        carve_xlim0=[-1  1]*wing_length_init*0.15;
        carve_ylim0=[-1  1]*wing_length_init*0.15;
        carve_zlim0=[-1  1]*wing_length_init*0.15;
        
        [voxels_wt0, res_wing] = makevoxels( carve_xlim0, carve_ylim0, carve_zlim0, 600000);
        
        voxels_hwt0=sqrt(sum(voxels_wt0.^2));
        voxels_wt0(:,voxels_hwt0>wing_length_init*0.2)=[];

        %% Get initial x y coords and make stack
        
        xwt_init=NaN(1,num_cams);
        ywt_init=NaN(1,num_cams);

        % for each camera reproject 3D wingtip and wingbase points back into 2D
        for v=use_cameras

            [xwt_ref(:,v),ywt_ref(:,v)]=reproject_points(calib_data,v,[Xwt_init',Ywt_init',Zwt_init'],1);
            [xwb(:,v),ywb(:,v)]=reproject_points(calib_data,v,[Xwb',Ywb',Zwb'],1);
                      
            % create a stack of 11 images +/- 5 frames from current frame
            ii=1;
            
            if f_curr>5
                for f=f_curr-5:f_curr+5

                    im_stack{v}(:,:,ii)=readmraw(vid(v),f);

                    ii=ii+1;
                end
            else
                for f=1:f_curr+5

                    im_stack{v}(:,:,ii)=readmraw(vid(v),f);

                    ii=ii+1;
                end
            end
            
        end

        % if starting at the beginning of the sequence, create empty variables 
        if f_curr==f_start
            xxwtL=NaN(n_frames,num_cams);
            yywtL=NaN(n_frames,num_cams);

            Xwt=NaN(n_frames,1);
            Ywt=NaN(n_frames,1);
            Zwt=NaN(n_frames,1);
        end

        % display sequence number in command window
        fprintf('\n\n')
        
        % run from current frame to end-5 frames
        for f=f_curr:n_frames-5
            
            % if not drawing tracker, display every 100th frame in command window
            if draw==0
                if mod(f,100)==0

                    fprintf(['...' num2str(f) ' '])
                end

                if mod(f,1200)==0 
                    fprintf('\n')
                end
            end
            
            % if f==1110
            %     return
            % end

            %% image processing for each camera
           
            % i6nd

            for v=use_cameras

                % create new background image from stack
                im_stack_max{v}=max(im_stack{v},[],3);
                
                % read in next image from stack (6th in each stack)
                if f<6
                    im{v}=im_stack{v}(:,:,f);
                elseif f>n_frames-5
                    im{v}=im_stack{v}(:,:,end);
                else
                    im{v}=im_stack{v}(:,:,6);
                end

                S_body{v}=false(im_size(:,v)');
                S_body{v}(im{v}<thresh_body)=1;

                % return
                % distance between reference wingtip and wingbase in 2D
                hwt_ref=hypot(xwt_ref(v)-xwb(v),ywt_ref(v)-ywb(v));

                % set minimum to 150
                hwt_ref(hwt_ref<250)=250;

                % angle of line joining reference wingtip and wingbase
                wt_ref_angle=atan2d(xwt_ref(v)-xwb(v),ywt_ref(v)-ywb(v));

                % scale wing mask by reference length and rotate by reference angle
                [xmask_init, ymask_init]=Rz2(xmask0*hwt_ref,ymask0*hwt_ref,-wt_ref_angle);
                
                xmask_init3=xmask_init;
                ymask_init3=ymask_init;
          
                % position mask on wingbase
                xmask{v}=xmask_init3+mean(xwb(:,v));
                ymask{v}=ymask_init3+mean(ywb(:,v));
                
                % if f==5033 && v==2
                %     return
                % end

                % imagesc2(im{v}); hold on
                % plot(xwt_ref(v),ywt_ref(v),'.g','markersize',15)
                % plot(xwb(v),ywb(v),'.y','markersize',15)
                % plot(xmask{v},ymask{v},'r')
                % plot(xmask0*hwt_ref,ymask0*hwt_ref,'r')
                % plot(xmask_init,ymask_init,'r')
                % return
            
                % use mask to set limits for cropping image
                xcrop=[floor(min(xmask{v})-1) ceil(max(xmask{v})+1)];
                ycrop=[floor(min(ymask{v})-1) ceil(max(ymask{v})+1)];

                xcrop(xcrop<1)=1;
                xcrop(xcrop>im_size(2))=im_size(2);

                ycrop(ycrop<1)=1;
                ycrop(ycrop>im_size(1))=im_size(1);

                xmask_crop=xmask{v}-xcrop(1)+1;
                ymask_crop=ymask{v}-ycrop(1)+1;

                xcrop_adj(v)=xcrop(1);
                ycrop_adj(v)=ycrop(1);

                % crop images and backgrounds
                im_crop{v}=im{v}(ycrop(1):ycrop(2),xcrop(1):xcrop(2));
                im_stack_max_crop=im_stack_max{v}(ycrop(1):ycrop(2),xcrop(1):xcrop(2));

                S_body_crop{v}=S_body{v}(ycrop(1):ycrop(2),xcrop(1):xcrop(2));

                % im_back_crop{v}=im_back{v}(ycrop(1):ycrop(2),xcrop(1):xcrop(2));

                % threshold the image to find background features
                % bw_back_crop=zeros(size(im_stack_max_crop));
                % bw_back_crop(im_stack_max_crop<thresh_wings)=1;
                
                % dilate the image
                % bw_back_crop_2=imdilate(bw_back_crop,se2);
                % bw_back_crop_large=imdilate(bw_back_crop,se10);

                % background subtraction
                im_crop3=im_stack_max_crop-im_crop{v};

                % return
                % remove points that are from the body
                % im_crop3(bw_back_crop_2==1)=0;

                % now threshold the image
                bw_crop=false(size(im_crop3));
                bw_crop(im_crop3>thresh_wings)=1;

                % create image mask and remove points outside
                bw_mask=poly2mask(xmask_crop,ymask_crop,size(im_crop3,1),size(im_crop3,2));
                bw_crop=(bw_crop.*bw_mask);

                % open the image - gets ride of small speckles or bits of legs
                bw_crop2=imopen(bw_crop,se1);

                % then close the image - gets ride of small speckles or bits of legs
                bw_crop2=imclose(bw_crop2,se2);

                xwt_ref_crop(v)=xwt_ref(v)-xcrop(1)+1;
                ywt_ref_crop(v)=ywt_ref(v)-ycrop(1)+1;
                
                % label image
                if ~any(v==ref_cameras)
                    S_wings_crop{v}=logical(bw_crop2+S_body_crop{v});
                    
                    xwt_init(v)=NaN;
                    ywt_init(v)=NaN;

                    S_edge_crop{v}=[];

                else

                    S_body_crop2{v}=imopen(S_body_crop{v},se10);

                    [B, bw_label_crop2] = bwboundaries(bw_crop2.*~imdilate(S_body_crop2{v},se40), 'noholes');

                    % now use reference wintip position to detect
                    % correct object (should be less likely to detect
                    % other wing)
                   
                    stats = regionprops(bw_label_crop2, 'Area');

                    % 3. Define your threshold and reference point
                    min_area_threshold = 100; % Replace with your desired minimum area
                    
                    % 4. Find the indices of the labels that meet the area threshold
                    valid_indices = find([stats.Area] >= min_area_threshold);

                    min_dist_per_label = inf(length(valid_indices), 1);

                    % 5. Loop through only the valid regions to check their outlines
                    for k = 1:length(valid_indices)
                        idx = valid_indices(k);
                        
                        % Extract the boundary coordinates for this specific label
                        % IMPORTANT: bwboundaries returns [row, column], which is [y, x]
                        boundary_coords = B{idx}; 
                        
                        % Separate into x and y arrays for clarity
                        b_x = boundary_coords(:, 2); % Columns are X
                        b_y = boundary_coords(:, 1); % Rows are Y
                        
                        % Calculate distance from the reference point to ALL points on this boundary
                        dists = hypot(b_x - xwt_ref_crop(v), b_y - ywt_ref_crop(v));
                        
                        % Store the absolute minimum distance for this specific outline
                        min_dist_per_label(k) = min(dists);
                    end
                
                    % 6. Find the index of the overall minimum distance
                    [~, winning_idx] = min(min_dist_per_label);
                
                    % 7. Map back to the original label and extract the winning outline
                    closest_label = valid_indices(winning_idx);
                    closest_outline = B{closest_label}; % This is your N-by-2 array of outline points

                    S_wings_crop{v}=false(size(im_crop{v}));
                    S_wings_crop{v}(bw_label_crop2==closest_label)=1;

                    B_wings_crop{v}=closest_outline;

                    % return
                    % % % if more than one label measure the area of each
                    % % % region and use largest region
                    % % bw_crop3=false(size(bw_crop2));
                    % % 
                    % % stats_crop2=regionprops(bw_label_crop2,'Area');
                    % % 
                    % % bw_area=cell2mat({stats_crop2.Area});
                    % % 
                    % % bw_area_max=find(bw_area==max(bw_area),1);
                    % % 
                    % % bw_crop3(bw_label_crop2==bw_area_max)=1;
                    % 
                    % B_wings_crop{v}=B{bw_area_max};
                    % S_wings_crop{v}=bw_crop3;
    
                    wing_edge_ind=sub2ind(size(im_crop{v}),B_wings_crop{v}(:,1),B_wings_crop{v}(:,2));
                    S_edge_crop{v}=false(size(im_crop{v}));
                    S_edge_crop{v}(wing_edge_ind)=1;

                    % transform points to original coordinates of image
                    xwing=B_wings_crop{v}(:,2)+xcrop(1)-1;
                    ywing=B_wings_crop{v}(:,1)+ycrop(1)-1;

                    % distance between points and wingbase
                    hwing2=hypot(xwing-xwb(v),ywing-ywb(v));

                    % find point(s) furthest away from wingbase
                    if any(v==ref_cameras)
                        xwt_init(v)=mean(xwing(hwing2==max(hwing2)));
                        ywt_init(v)=mean(ywing(hwing2==max(hwing2)));
                    
                    end
                end
               
                % imagesc2(im_crop{v}); hold on
                % % imagesc2(S_wings_crop{v}); hold on
                % plot(B_wings_crop{v}(:,2),B_wings_crop{v}(:,1),'g')
                % % 
                % % if v==2
                % %     return
                % % end
                % imagesc2(im{v}); hold on
                % plot(xwt_ref(v),ywt_ref(v),'.g','markersize',15)
                % plot(xwb(v),ywb(v),'.y','markersize',15)
                % plot(xmask{v},ymask{v},'r')
                % % plot(xmask0*hwt_ref,ymask0*hwt_ref,'r')
                % % plot(xmask_init,ymask_init,'r')
                % plot(xwt_init(v),ywt_init(v),'og');
                % return

                % read next frame and add it to the stack, while
                % removing the first frame
                if f<n_frames-5

                    im_temp=readmraw(vid(v),f+6);
     
                    im_stack{v}(:,:,1)=im_temp;
                    
                    im_stack{v}=circshift(im_stack{v},-1,3);

                end
            end

            % xxwtL(i,1)=150;
            % yywtL(i,1)=150;
            % 
            % if f==24
            %     return
            % end

            % calculate 3D coordinates
            [Xwt_init,Ywt_init,Zwt_init,resnorm_wt,residual_wt]=calc3D(xwt_init',ywt_init',calib_data);
            
            % Now use carving to find more exact wingtip point
            voxels_wt=voxels_wt0+repmat([Xwt_init,Ywt_init,Zwt_init]',1,size(voxels_wt0,2));
    
            XX_wt_edge0=voxels_wt;

            R2=rodrigues(calib_data.om_grids(:,1));
            T2=calib_data.T_grids(:,1);

            voxels_wt=R2*voxels_wt+repmat(T2,1,size(voxels_wt,2));
            
    %             return
            % create voxels for the everything and the wings
    
            starting_volume = size(voxels_wt,2);
    
            % index so that points can be matched up between the two carves
            index_wt=1:starting_volume;
    
            % if f==28
            %     return
            % end

            % for v=use_cameras
            for v=  [1 2 3 4 5 6]

                if any(v==ref_cameras)

                    [voxels_wt,index_wt,x_cropped,y_cropped,x_rep,y_rep,x_keep,y_keep] = carve2_scale_crop(voxels_wt, v, imdilate(S_edge_crop{v},se3).*imdilate(S_wings_crop{v},se1), calib_data, index_wt, 1, xcrop_adj(v), ycrop_adj(v));

                else

                   [voxels_wt,index_wt,x_cropped,y_cropped,x_rep,y_rep,x_keep,y_keep] = carve2_scale_crop(voxels_wt, v, imdilate(S_wings_crop{v},se3), calib_data, index_wt, 1, xcrop_adj(v), ycrop_adj(v));

                end
            end
            
            XX_wt_edge=R2'*(voxels_wt-repmat(T2,1,size(voxels_wt,2)));

            XX_wt_edge2=XX_wt_edge-repmat([Xwb;Ywb;Zwb],1,size(XX_wt_edge,2));
            
            H_wt_edge2=sum(XX_wt_edge2.^2);

            H_wt_edgemax=find(H_wt_edge2==max(H_wt_edge2));

            XX_wt=mean(XX_wt_edge(:,H_wt_edgemax),2);

            Xwt(f)=XX_wt(1);
            Ywt(f)=XX_wt(2);
            Zwt(f)=XX_wt(3);
            
            % plot3(XX_wt_edge(1,:),XX_wt_edge(2,:),XX_wt_edge(3,:),'.','markersize',1); hold on
            % 
            % % plot3(XX_wt_edge0(1,:),XX_wt_edge0(2,:),XX_wt_edge0(3,:),'.','markersize',1); hold on
            % plot3(Xwt_init,Ywt_init,Zwt_init,'.r','markersize',16);
            % plot3(Xwb,Ywb,Zwb,'.g','markersize',16);
            % 
            % axis image
            % labels
            % 
            % return
            % 
            % reproject wing tip points back into 2D
            if ~isnan(Xwt(f))
                for v=use_cameras
                    [xwt_ref(:,v),ywt_ref(:,v)]=reproject_points(calib_data,v,[Xwt(f),Ywt(f),Zwt(f)],1);

                    xxwtL(f,v)=xwt_ref(:,v);
                    yywtL(f,v)=ywt_ref(:,v);
                    
                end
            end
            
            % plot tracker results
            if draw==1
                vv=1;
                stop_vid=0;

                for v=use_cameras
                    % if it's the first frame create subplot for each camera view
                    if f==f_curr

                        if v==1
                            figure
                        end

                        if length(use_cameras)==4
                            subplot(2,2,vv)
                        else
                            subplot(2,3,vv)
                        end

                        I(v)=imagesc(im{v}); hold on
                        colormap(gray)
                        axis image
                        caxis([0 2^12])
                        axis([0.5 im_size(2,v)+0.5 0.5 im_size(1,v)+0.5]);

                        T(v)=text(320,30,['Frame ' num2str(f) ' of ' num2str(n_frames)],'horizontalalignment','center');
                        PwtL(v)=plot([xwt_ref(v) xwb(v)],[ywt_ref(v) ywb(v)],'.-b','markersize',20);
                        PmaskL(v)=patch(xmask{v}([1:end 1]),ymask{v}([1:end 1]),'b','facealpha',0.3);

                        set(T(v),'color','g')

                        if length(use_cameras)==4
                            if vv<3
                                set(gca,'position',[0+0.5*(vv-1) 0.5 0.5 0.5])
                            else
                                set(gca,'position',[0+0.5*(vv-3) 0 0.5 0.5])
                            end
% 
                            set(gcf,'position',[1 300 768 528])
                        else

                            if vv==1
                                set(gca,'position',[0 0.48 1/3 0.48]);
                            elseif vv==2
                                set(gca,'position',[1/3 0.48 1/3 0.48]);
                            elseif vv==3
                                set(gca,'position',[2/3 0.48 1/3 0.48]);
                            elseif v==4
                                set(gca,'position',[0 0 1/3 0.48]);
                            elseif v==5
                                set(gca,'position',[1/3 0 1/3 0.48]);
                            else
                                set(gca,'position',[2/3 0 1/3 0.48]);
                            end

                            set(gcf,'position',[100 100 1024 683])
                        end

                        axis off
                        caxis([0 2^12])

                        vv=vv+1;
                        
                    else
                        % for other frames, just update graphics
                        set(I(v),'cdata',im{v});
                        set(T(v),'string',['Frame ' num2str(f) ' of ' num2str(n_frames)])
                        set(PwtL(v),'xdata',[xwt_ref(v) xwb(1,v)],'ydata',[ywt_ref(v) ywb(1,v)]);
                        set(PmaskL(v),'xdata',xmask{v}([1:end 1]),'ydata',ymask{v}([1:end 1]));

                        if isnan(xxwtL(f,v))
                            set(PwtL(v),'color','r')
                            stop_vid=1;
                        else
                            set(PwtL(v),'color','b')
                        end
                    end
                end

                % refresh onscreen
                drawnow
                % return

                if stop_vid==1
                    return
                end

                % if i==1110
                    % return
                % end

            end

        end

        % check if there is already a 
        if ~exist('single_wing_tracked_points','dir')
            mkdir('single_wing_tracked_points')
        end

        % if it gets to the end, then set finished=1 and save file
        finished=1;
        close all
        disp('finished')
        save(fullfile('single_wing_tracked_points',[sequence_name '_tracked_wt.mat']),'Xwt','Ywt','Zwt','xxwtL','yywtL','Xwb','Ywb','Zwb','XwbR','Xwb0','Ywb0','Zwb0','YwbR','ZwbR','Xant','Yant','Zant','Fs','n_frames','finished')
    end

end

