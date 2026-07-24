clear
close all 
   
% This version only tracks outer half of wing (50%-90%), so that it is more reliable
% and fits better with the track_wing_veinsX code, which will be used to
% get the entire wing outline.

warning off

%% EDITABLE PART %%
% folder where recordings are stored
base_folder=fullfile('D:','Micro_arena');
date_folder='2026_06_30';
sequence_name='Fly7_a'; % assummed to be in base_folder -> date folder
background_name='Fly7_background'; % name of folder container background videos (with no fly attached)

% load calibration file - assumed to be in base_folder -> date_folder
calib_name='Fly6_calib_results_0dist';
%% END EDITABLE PART %%

load CalliphoraWing_new
% load Calliphora_wing

% set to 0 to disable drawing while the tracker runs (improves speed).
draw=1;

write_vids=0;

use_cameras=[1 2 3 4 5 6];

% [ym,xm]=pol2cart(linspace(-pi/5,pi/4,8),1);
% xmask0=[xm xm(end-1) flip(xm(3:end-3),2) xm(1) xm(1)];
% ymask0=[ym+0.3 0.5 -(flip(ym(3:end-3),2)-0.9) 0.5 ym(1)+0.2];

% [ym,xm]=pol2cart(linspace(-pi/6,pi/6,8),1);
% xmask0=[xm flip(xm(3:end-2),2) xm(1)];
% ymask0=[ym+0.2 0.5-(flip(ym(3:end-2),2)-0.9) ym(1)+0.2];

[xm,ym]=pol2cart(linspace(0,2*pi),0.6);

xm=xm*0.8;
ym=ym*1.3+0.4;

ym(ym<mean(ym))=ym(ym<mean(ym))*0.5;

xmask0=xm;
ymask0=ym;

% plot(xmask0,ymask0);axis image
% plot(xm,ym);axis image

% return

% create different sized structural elements for morphological operations
se1 = strel('disk',1);
se2 = strel('disk',2);
se3 = strel('disk',3,4);
se5 = strel('disk',5,8);

se10 = strel('disk',10,6);
se20 = strel('disk',20,8);
se40 = strel('disk',40,8);

scale=1;


% thresh_wings=[50 50 50 50 50 50].*2^4;
thresh_wings=10.*2^4; % based on <255-thresh_wings from background subtracted image

thresh_body=20.*2^4; % based on >thresh_body from original image
thresh_legs=75.*2^4; % based on >thresh_legs from original image

close all
% load initial points
load(fullfile('single_wing_init_points',[sequence_name '_init_click_combined.mat']))
load(fullfile('single_wing_backgrounds',[sequence_name '_backgrounds.mat']))
load(fullfile('single_wing_tracked_points',[sequence_name '_tracked_wt.mat']))

% find camera file in sequence folder
filenames=dir(fullfile(base_folder,date_folder,sequence_name,'*.cihx'));
filenames={filenames.name};
filenames=filenames(1:6);

% number of cameras
num_cams=length(filenames);

num_frames=size(xxwtL,1);

load(fullfile(base_folder,date_folder,calib_name))

% empty variables for number of frames and image size
im_size=NaN(2,num_cams);

% for each camera load the video file and check it's 

xwt_ref=NaN(num_frames,num_cams);
ywt_ref=NaN(num_frames,num_cams);

xwb_ref=NaN(1,num_cams);
ywb_ref=NaN(1,num_cams);

xlead_all=cell(num_frames,num_cams);
ylead_all=cell(num_frames,num_cams);
xtrail_all=cell(num_frames,num_cams);
ytrail_all=cell(num_frames,num_cams);

if write_vids==1
    vid_save = VideoWriter(fullfile([sequence_name '_3D.mp4']),'MPEG-4');
    vid_save.FrameRate=25;
    open(vid_save)
end

for v=1:num_cams

    % get filename excluding extension
    % [~,name,ext] = fileparts(filenames{v});
    
    % function for loading raw video file
    vid(v)=quick_parse_cihx(fullfile(base_folder,date_folder,sequence_name,filenames{v}));
  
    % image size
    im_size(:,v)=[vid(v).ImageHeight vid(v).ImageWidth];

    [xwt_ref(:,v),ywt_ref(:,v)]=reproject_points(calib_data,v,[Xwt,Ywt,Zwt],1);
    [xwb_ref(:,v),ywb_ref(:,v)]=reproject_points(calib_data,v,[Xwb,Ywb,Zwb],1);

    vid_back(v)=quick_parse_cihx(fullfile(base_folder,date_folder,background_name,filenames{v}));
    im_vid_back{v}=double(readmraw(vid_back(v),1));

end

w=1;

ref_cams_all=zeros(num_frames,num_cams);

rec_freq=6400;

stroke_ang=NaN(size(Xwt,1),1);
dev_ang=NaN(size(Xwt,1),1);
wing_length=NaN(size(Xwt,1),1);

XXwt=[Xwt(:,w) Ywt(:,w) Zwt(:,w)]-[Xwb Ywb Zwb];

[stroke_ang,dev_ang,wing_length]=cart2sph(XXwt(:,2),XXwt(:,1),XXwt(:,3));

wing_length_med=median(wing_length,'omitmissing');
stroke_ang=180/pi*stroke_ang;
dev_ang=180/pi*dev_ang;

Xmwing0=Xwing*0.9*wing_length_med;
Ymwing0=(Ywing*0.9+0.1)*wing_length_med;
Zmwing0=zeros(size(Xmwing0));

% plot(Xmwing0,Ymwing0);axis image; labels
% labels
% return

stroke_ang2=fillmissing(stroke_ang(:,w),'linear','EndValues','none');
stroke_ang2=rmmissing(stroke_ang2);

[f,P1]=quick_fft(stroke_ang2,rec_freq);

P1(1:3)=NaN;
wb_freq_est(w)=f(P1==max(P1));

wb_freq_est=mean(wb_freq_est);

% % plot(f,P1,'.-')
% plot3(-Xwt,Ywt,Zwt); hold on
% plot3(-Xwt(6),Ywt(6),Zwt(6),'.g','markersize',20); hold on
% plot3(-Xwt(8),Ywt(8),Zwt(8),'.c','markersize',20); hold on
% plot3(-Xwb,Ywb,Zwb,'.r','markersize',20);
% plot3(-XwbR,YwbR,ZwbR,'.r','markersize',20);
% plot3(-Xant,Yant,Zant,'.b','markersize',20);
% set(gca,'zdir','reverse')
% labels
% axis image
% return

[stroke_ang_f(:,w) stroke_vel(:,w) stroke_acc(:,w)]=filter_data(stroke_ang(:,w),5*wb_freq_est,rec_freq);
[dev_ang_f(:,w), dev_vel(:,w),dev_acc(:,w)]=filter_data(dev_ang(:,w),4*wb_freq_est,rec_freq);

Xwt_f(:,w)=filter_data(Xwt(:,w),5*wb_freq_est,rec_freq);
Ywt_f(:,w)=filter_data(Ywt(:,w),5*wb_freq_est,rec_freq);
Zwt_f(:,w)=filter_data(Zwt(:,w),5*wb_freq_est,rec_freq);

% wb_offsetxyz=find_centre_sphere(Xwt(:),Ywt(:),Zwt(:))';
% % for v=use_cameras
% % end
% plot3(Xwt_f,Ywt_f,Zwt_f); hold on
% plot3(Xwb,Ywb,Zwb,'.r','markersize',20);
% plot3(wb_offsetxyz(1),wb_offsetxyz(2),wb_offsetxyz(3),'.g','markersize',20)
% axis image; labels
% return

res_scale=1;
res=wing_length_med/(100*res_scale);
    
% main voxels for carving
wing_yrange=50:90;
xvoxels_range=(-35:35)*res*res_scale;
yvoxels_range=wing_yrange.*res*res_scale;
zvoxels_range=(-35:35)*res*res_scale;

[Y,X,Z] = meshgrid(yvoxels_range, xvoxels_range, zvoxels_range);
voxels_wing5_0_110 = [X(:)'; Y(:)'; Z(:)'];

pitch_ang_init=NaN(num_frames,1);

XwLead=NaN(n_frames,size(yvoxels_range,2));
YwLead=NaN(n_frames,size(yvoxels_range,2));
ZwLead=NaN(n_frames,size(yvoxels_range,2));

XwTrail=NaN(n_frames,size(yvoxels_range,2));
YwTrail=NaN(n_frames,size(yvoxels_range,2));
ZwTrail=NaN(n_frames,size(yvoxels_range,2));

f_start=find(~isnan(Xwt_f),1);
f_end=find(~isnan(Xwt_f),1,'last');

f_start=27;

f_curr=f_start;

for v=use_cameras
    % create a stack of 11 images +/- 5 frames from current frame
    ii=1;
    
    if f_curr>5
        for i=f_curr-5:f_curr+5

            im_stack{v}(:,:,ii)=readmraw(vid(v),i);

            ii=ii+1;
        end
    else
        for i=1:f_curr+5

            im_stack{v}(:,:,ii)=readmraw(vid(v),i);

            ii=ii+1;
        end
    end
end

for f=f_start:f_end

    % tic
    if draw==0
        if mod(f,10)==0

            fprintf(['...' num2str(f) ' '])
        end

        if mod(f,100)==0 
            fprintf('\n')
        end
    end

    xcrop_adj=NaN(1,num_cams);
    ycrop_adj=NaN(1,num_cams);
    
    for v=use_cameras

        % create new background image from stack
        im_stack_max{v}=max(im_stack{v},[],3);

        % read in next image from stack (6th in each stack)
        if f<6
            im{v}=double(im_stack{v}(:,:,f));
        elseif f>num_frames-5
            im{v}=double(im_stack{v}(:,:,end));
        else
            im{v}=double(im_stack{v}(:,:,6));
        end

        % read next frame and add it to the stack, while
        % removing the first frame
        if f<num_frames-5

            im_temp=readmraw(vid(v),f+6);

            im_stack{v}(:,:,1)=im_temp;
            
            im_stack{v}=circshift(im_stack{v},-1,3);

        end

        % im{v}=double(readmraw(vid(v),f));

        % im_ind=(im{v}>1.5*thresh_wings).*(im_back{v}>1.5*thresh_wings);
        % im_ind=imerode(im_ind,se40);

        % im_back_scale=mean(mean(im{v}(im_ind==1)))./mean((im_back{v}(im_ind==1)));
        im_back_scale=1;
        im_back2{v}=im_back{v}.*im_back_scale;

        % im_vid_back_scale=mean(mean(im{v}(im_ind==1)))./mean((im_vid_back{v}(im_ind==1)));
        im_vid_back_scale=1;
        im_vid_back2{v}=im_vid_back{v}.*im_vid_back_scale;

        S_body{v}=false(im_size(:,v)');
        S_body{v}(im_back2{v}<thresh_body)=1;
        S_body{v}=imdilate(S_body{v},se10);

        % Have a go at using stack images to detect legs
        S_legs{v}=false(im_size(:,v)');
        S_legs{v}(im_stack_max{v}<thresh_legs)=1;

        S_legs{v}=imclose(S_legs{v},se5);
        S_legs{v}=imdilate(S_legs{v},se10);

        % if v==3
        % %     imshowpair(im_stack_max{v},S_legs{v})
        %     imagesc2(im_stack_max{v});
        %     return
        % end

        % distance between reference wingtip and wingbase in 2D
        hwtx_ref=hypot(xwt_ref(f,v)-xwb_ref(v),ywt_ref(f,v)-ywb_ref(v));
        hwty_ref=hwtx_ref;
        proj_wing_length(v)=hwtx_ref;

        % set minimum to 400 for x-axis
        hwtx_ref(hwtx_ref<400)=400;
        % set minimum to 250 for x-axis
        hwty_ref(hwty_ref<250)=250;

        % angle of line joining reference wingtip and wingbase
        wt_ref_angle=atan2d(xwt_ref(f,v)-xwb_ref(v),ywt_ref(f,v)-ywb_ref(v));

        % scale wing mask by reference length and rotate by reference angle
        [xmask_init, ymask_init]=Rz2(xmask0*hwtx_ref,ymask0*hwty_ref,-wt_ref_angle);
        
        xmask_init3=xmask_init;
        ymask_init3=ymask_init;
   
        % position mask on wingbase
        xmask{v}=xmask_init3+mean(xwb_ref(:,v));
        ymask{v}=ymask_init3+mean(ywb_ref(:,v));
        
        % imagesc2(im{v}); hold on
        % plot(xwt_ref(f,v),ywt_ref(f,v),'.g','markersize',15)
        % plot(xwb_ref(v),ywb_ref(v),'.y','markersize',15)
        % plot(xmask{v},ymask{v},'r')
        % % plot(xmask0*hwt_ref,ymask0*hwt_ref,'r')
        % % plot(xmask_init,ymask_init,'r')
        % return
    
        % use mask to set limits for cropping image
        xcrop=[floor(min(xmask{v})-1) ceil(max(xmask{v})+1)];
        ycrop=[floor(min(ymask{v})-1) ceil(max(ymask{v})+1)];

        xcrop(xcrop<1)=1;
        xcrop(xcrop>im_size(2))=im_size(2);

        ycrop(ycrop<1)=1;
        ycrop(ycrop>im_size(1))=im_size(1);

        xcrop_adj(v)=xcrop(1);
        ycrop_adj(v)=ycrop(1);
        
        xmask_crop=xmask{v}-xcrop(1)+1;
        ymask_crop=ymask{v}-ycrop(1)+1;

        % crop images and backgrounds
        im_crop{v}=im{v}(ycrop(1):ycrop(2),xcrop(1):xcrop(2));
        im_back_crop=im_back2{v}(ycrop(1):ycrop(2),xcrop(1):xcrop(2));
        im_vid_back_crop=im_vid_back2{v}(ycrop(1):ycrop(2),xcrop(1):xcrop(2));

        % S_legs_crop{v}=S_legs{v}(ycrop(1):ycrop(2),xcrop(1):xcrop(2));
        % S_body_crop{v}=S_body{v}(ycrop(1):ycrop(2),xcrop(1):xcrop(2));

        % S_legs_crop2{v}=logical(S_legs_crop{v}.*(1-S_body_crop{v}));

        % threshold the image to find background features
        % bw_back_crop=zeros(size(im_stack_max_crop));
        % bw_back_crop(im_stack_max_crop<thresh(v))=1;
        
        % dilate the image
        % bw_back_crop_2=imdilate(bw_back_crop,se2);
        % bw_back_crop_large=imdilate(bw_back_crop,se_large);

        % background subtraction
        % im_crop3{v}=im_back_crop-im_crop{v};
        im_crop3{v}=im_vid_back_crop-im_crop{v};

        % remove points that are from the body
        % im_crop3{v}(bw_back_crop_2==1)=0;

        % now threshold the image
        bw_crop=false(size(im_crop3{v}));
        bw_crop(im_crop3{v}>thresh_wings)=1;

        % if v==4
        %     imshowpair(im_crop3{v},bw_crop)
        %     return
        % end

        % reinsert points that are likely the body
        bw_crop(im_crop{v}<thresh_body)=1;

        % create image mask and remove points outside
        bw_mask=poly2mask(xmask_crop,ymask_crop,size(im_crop3{v},1),size(im_crop3{v},2));
        bw_crop=(bw_crop.*bw_mask);

        % open the image - gets ride of small speckles or bits of legs
        % bw_crop2=imopen(bw_crop.*(1-S_legs_crop2{v}),se3);
        % bw_crop2=bw_crop.*(1-S_legs_crop2{v});

        bw_crop2=imopen(bw_crop,se1);

        % bw_crop2(im_crop3{v}>thresh_wings & im_crop{v}>20*thresh_legs)=1;
        % bw_crop2=imclose(bw_crop2,se10);

        % return
        % if v==3
        %     imshowpair(im_crop{v},bw_crop2)
        %     % imagesc2(inpaintExemplar(im_crop3{v},S_legs_crop2{v},'FillOrder','gradient','PatchSize',15));
        %     % imagesc2(inpaintCoherent(im_crop3{v},S_legs_crop2{v},'Radius',20,'SmoothingFactor',10));
        %     return
        % end

        % return
        % 1. Find boundaries and the label matrix simultaneously
        % We use 'noholes' to only get the exterior outlines and speed up computation
        [B, L] = bwboundaries(bw_crop2, 'noholes');
        
        xwt_ref_crop=xwt_ref(f,v)-xcrop(1)+1;
        ywt_ref_crop=ywt_ref(f,v)-ycrop(1)+1;

        % if v==4
        %     % imagesc2(im{v}); hold on
        %     % plot(xwt_ref(f,v),ywt_ref(f,v),'.r')
        %     % figure
        %     imagesc2(bw_crop2); hold on
        %     plot(xwt_ref_crop,ywt_ref_crop,'.r')
        %     return
        % end
        
        % Note: L acts exactly as your previous 'bw_label_crop2' did.
        bw_label_crop2 = L; 
        
        % 2. Extract the Area for each labeled region
        stats = regionprops(bw_label_crop2, 'Area');
        
        % 3. Define your threshold and reference point
        min_area_threshold = 100; % Replace with your desired minimum area
        
        % 4. Find the indices of the labels that meet the area threshold
        valid_indices = find([stats.Area] >= min_area_threshold);
        
        if isempty(valid_indices)
            disp('No objects meet the area threshold.');
            closest_outline = [];
        else
            % Preallocate an array for the minimum distances
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
                dists = hypot(b_x - xwt_ref_crop, b_y - ywt_ref_crop);
                
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


            B_wings{v}=closest_outline-1+repmat([ycrop_adj(v), xcrop_adj(v)],size(closest_outline,1),1);
            B_wings_all{f,v}=B_wings{v};

            S_wings{v}=false(size(im{v}));
            S_wings{v}(ycrop_adj(v):ycrop_adj(v)+size(S_wings_crop{v},1)-1,...
                           xcrop_adj(v):xcrop_adj(v)+size(S_wings_crop{v},2)-1)=S_wings_crop{v};

            % S_wings_temp{v}=poly2mask(B_wings_all{f,v}(:,2),B_wings_all{f,v}(:,1),im_size(1,v),im_size(2,v));

            % wing_ind=sub2ind(im_size(:,v)',B_wings_all{f,v}(:,1),B_wings_all{f,v}(:,2));
            % S_wings_temp{v}=false(im_size(:,v)');
            % S_wings_temp{v}(wing_ind)=1;
            % S_wings_temp{v}=imfill(S_wings_temp{v},'holes');
            % 
            % imagesc2(S_wings{v});
            % figure
            % imagesc2(S_wings_temp{v})
            

            % imagesc2(im_crop{v}); hold on
            % % imagesc2(S_wings{v}); hold on
            % plot(closest_outline(:,2),closest_outline(:,1),'.g','markersize',10)
            % 
            % figure
            % imagesc2(im{v}); hold on
            % % imagesc2(S_wings{v}); hold on
            % plot(B_wings_all{f,v}(:,2),B_wings_all{f,v}(:,1),'.g','markersize',10)
            % return

        end

    end

    % return
    % 
    % % find location of all non-zero pixels
    % [ywing_crop,xwing_crop]=find(bw_crop2);
    % 
    % % transform points to original coordinates of image
    % xwing=xwing_crop+xcrop(1)-1;
    % ywing=ywing_crop+ycrop(1)-1;

    % imagesc2(im_crop{v}); hold on
    % 
    % plot(closest_outline(:,2),closest_outline(:,1),'g')
    % 
    % plot(xwt_ref_crop,ywt_ref_crop,'.r')

    XX5=voxels_wing5_0_110';
    XX44=NaN(size(XX5));

    [XX44(:,1),XX44(:,2),XX44(:,3)]=Rx2(XX5(:,1),XX5(:,2),XX5(:,3),dev_ang(f,w));
    [XX44(:,1),XX44(:,2),XX44(:,3)]=Rz2(XX44(:,1),XX44(:,2),XX44(:,3),-stroke_ang(f,w));

    voxels_wing=XX44+repmat([Xwb Ywb Zwb],size(XX44,1),1);
    voxels_wing=voxels_wing';
    voxels_wing0=voxels_wing;

    R2=rodrigues(calib_data.om_grids(:,1));
    T2=calib_data.T_grids(:,1);

    voxels_wing=R2*voxels_wing+repmat(T2,1,size(voxels_wing,2));
    
    % create voxels for the everything and the wings
    starting_volume = size(voxels_wing,2);

    % index so that points can be matched up between the two carves
    index_wing=1:starting_volume;

    % plot3(voxels_wing0(1,:),voxels_wing0(2,:),voxels_wing0(3,:),'.','markersize',0.1); hold on
    % plot3([Xwb Xwt(f)],[Ywb Ywt(f)],[Zwb Zwt(f)],'.-r','markersize',20,'linewidth',3)
    % axis image
    % labels
    % % 
    % return

    for v=use_cameras
        [voxels_wing,index_wing] = carve2_scale_crop( voxels_wing, v, S_wings_crop{v}, calib_data, index_wing, scale, xcrop_adj(v), ycrop_adj(v));
    
        % plot3(voxels_wing(1,:),voxels_wing(2,:),voxels_wing(3,:),'.','markersize',0.1);
        % axis image
        % labels

    end

    % plot3(voxels_wing(1,:),voxels_wing(2,:),voxels_wing(3,:),'.','markersize',0.1);
    % axis image
    % labels
    % return

    voxels_wing=R2'*(voxels_wing-repmat(T2,1,size(voxels_wing,2)));

    XX_wing=voxels_wing'-repmat([Xwb Ywb Zwb],size(voxels_wing',1),1);
    XX_wing2=NaN(size(XX_wing));

    [XX_wing2(:,1),XX_wing2(:,2),XX_wing2(:,3)]=Rz2(XX_wing(:,1),XX_wing(:,2),XX_wing(:,3),stroke_ang(f,w));
    [XX_wing2(:,1),XX_wing2(:,2),XX_wing2(:,3)]=Rx2(XX_wing2(:,1),XX_wing2(:,2),XX_wing2(:,3),-dev_ang(f,w));
    
    [L,numClusters,sizeClusters]=labelVoxels(XX_wing2,sqrt(3)*res);
    
    [sizeCLusters_ordered,sizeCLusters_order_index]=sort(sizeClusters);

    if length(sizeClusters)>1

        XX_wing2(L~=sizeCLusters_order_index(end),:)=[];
        voxels_wing(:,L~=sizeCLusters_order_index(end))=[];
    end

    XX_wing3=XX_wing2(XX_wing2(:,2)>0.6*wing_length_med,:);

    ind50=find(XX_wing2(:,2)>0.5*wing_length_med);
    
    [coeff_wing, score_wing]=pca(XX_wing3(:,[1 3]));

    pitch_ang_init(f,w)=atan2d(coeff_wing(1).*sign(coeff_wing(2)),coeff_wing(2).*sign(coeff_wing(2)));

    XX5=[Xmwing0(:,1) Ymwing0(:,1) Zmwing0(:,1);flip([Xmwing0(:,2) Ymwing0(:,2) Zmwing0(:,2)],1)];
    XX44=NaN(size(XX5));

    [XX44(:,1),XX44(:,2),XX44(:,3)]=Ry2(XX5(:,1),XX5(:,2),XX5(:,3),-(90-pitch_ang_init(f,w)));
    [XX44(:,1),XX44(:,2),XX44(:,3)]=Rx2(XX44(:,1),XX44(:,2),XX44(:,3),dev_ang(f,w));
    [XX44(:,1),XX44(:,2),XX44(:,3)]=Rz2(XX44(:,1),XX44(:,2),XX44(:,3),-stroke_ang(f,w));

    XXm_wing=XX44+repmat([Xwb Ywb Zwb],size(XX44,1),1);

    Xm_wing=XXm_wing(:,1);
    Ym_wing=XXm_wing(:,2);
    Zm_wing=XXm_wing(:,3);

    xwing_rep=NaN(size(voxels_wing,2),num_cams);
    ywing_rep=NaN(size(voxels_wing,2),num_cams);

    wing_mask50_area=zeros(1,num_cams);

    xwing60_rep=NaN(length(ind50),num_cams);
    ywing60_rep=NaN(length(ind50),num_cams);
    
    for v=use_cameras

        [xwing_rep(:,v),ywing_rep(:,v)]=reproject_points(calib_data,v,voxels_wing',1);
        wing_mask{v}=false(size(im{v}));
        
        indwing_rep=sub2ind(size(im{v}),round(ywing_rep(:,v)),round(xwing_rep(:,v)));

        wing_mask{v}(indwing_rep)=1;
        wing_mask2{v}=imdilate(wing_mask{v},se20);

        [Bwing_mask, ~] = bwboundaries(wing_mask2{v}, 'noholes');

        if length(Bwing_mask)>1
            moo=1
            return
        end
        
        Bwing_mask_all{f,v}=Bwing_mask{1};

        [xwing60_rep(:,v),ywing60_rep(:,v)]=reproject_points(calib_data,v,voxels_wing(:,ind50)',1);
        wing_mask60{v}=false(size(im{v}));

        indwing60_rep=sub2ind(size(im{v}),round(ywing60_rep(:,v)),round(xwing60_rep(:,v)));

        wing_mask60{v}(indwing60_rep)=1;

        wing_mask60{v}=imdilate(wing_mask60{v},se5).*S_wings{v}.*(1-imdilate(S_body{v},se40));

        wing_mask50_area(v)=sum(wing_mask60{v}(:));
        % return

        % im_temp = regionfill(im{v},S_legs{v});

        % subplot(2,3,v)
        % imagesc2(im_temp); hold on
        % % imagesc2(im{v}); hold on
        % [r, c]=find(wing_mask60{v});
        % 
        % [r2, c2]=find(S_body{v});
        % 
        % plot(c2,r2,'.y','markersize',10);
        % plot(c,r,'.r','markersize',10);

    end
    % return

    [~,wing_mask50_area_order]=sort(wing_mask50_area);

    ref_cams=wing_mask50_area_order([end end-1]);

    ref_cams_all(f,ref_cams)=1;
    % ref_cam=2;
    
    L_skel=[];
    n_skel=[];

    for v=ref_cams

        % get rid of any spurs caused by legs that might not have been
        % picked up elsewhere
        Bwing_mask=poly2mask(B_wings{v}(:,2),B_wings{v}(:,1),im_size(1),im_size(2));
        
        Bwing_mask2=imopen(Bwing_mask,se20);
        
        B = bwboundaries(Bwing_mask2, 'noholes');
        
        num_boundaries = length(B);
        
        % 3. Check if there are multiple objects
        if num_boundaries > 1

            % 2. Isolate your reference coordinates for readability
            ref_x = xwt_ref(f,v);
            ref_y = ywt_ref(f,v);
            
            % Preallocate an array to hold the shortest distance for each boundary
            min_dist_per_boundary = zeros(num_boundaries, 1);
            
            for k = 1:num_boundaries
                % Extract the current boundary matrix
                current_B = B{k};
                
                % CRITICAL: bwboundaries outputs [Row, Col] which means [Y, X]
                Y_coords = current_B(:, 1);
                X_coords = current_B(:, 2);
                
                % Calculate the Euclidean distance from every point on this boundary to the reference point
                distances = sqrt((X_coords - ref_x).^2 + (Y_coords - ref_y).^2);
                
                % Store the absolute minimum distance found for this specific boundary
                min_dist_per_boundary(k) = min(distances);
            end
            
            % 4. Find which boundary had the smallest minimum distance
            [~, best_idx] = min(min_dist_per_boundary);
            
            % 5. Overwrite B to keep ONLY the closest boundary
            B = B(best_idx); % Keeps it as a 1x1 cell array containing your target boundary
            
        end

        % return
        B_wings{v}=B{1};
        B_wings_all{f,v}=B_wings{v};
        
        Bcx=B_wings{v}(:,2);
        Bcy=B_wings{v}(:,1);

        % Initially order so starts at point furthest from wingtip
        bound_wt_dist=hypot(Bcx-xwt_ref(f,v),Bcy-ywt_ref(f,v));
        bound_wt_dist_max=find(bound_wt_dist==max(bound_wt_dist),1);
    
        Bcx=Bcx([bound_wt_dist_max:end 1:bound_wt_dist_max]);
        Bcy=Bcy([bound_wt_dist_max:end 1:bound_wt_dist_max]);

        [y_legs,x_legs]=find(S_legs{v});

        [is_overlap, ~] = ismember([Bcx, Bcy], [x_legs, y_legs], 'rows');

        % Create a logical array of points we initially want to keep
        keep_mask = ~is_overlap;

        fragment_threshold = 5; % Remove any isolated segments of this length or shorte

        % Pad the mask with 0s (false) to ensure we detect segments that 
        % start at the very first index or end at the very last index.
        padded_mask = [false; keep_mask; false];

        % 'diff' finds the transitions. 
        % 1 = transition from false to true (Start of segment)
        % -1 = transition from true to false (End of segment)
        transitions = diff(padded_mask);
        start_idx = find(transitions == 1);
        end_idx = find(transitions == -1) - 1;

        % Calculate lengths of each contiguous segment
        segment_lengths = end_idx - start_idx + 1;

        % Loop through segments and turn them off in the mask if they are too short
        for i = 1:length(segment_lengths)
            if segment_lengths(i) <= fragment_threshold
                keep_mask(start_idx(i):end_idx(i)) = false;
            end
        end

        % Generate the final indices to keep based on the cleaned mask
        keep_idx = find(keep_mask);

        % Determine the range of indices to interpolate
        query_idx = (min(keep_idx):max(keep_idx))';

        Bcx_interp = interp1(keep_idx, Bcx(keep_idx), query_idx, 'makima');
        Bcy_interp = interp1(keep_idx, Bcy(keep_idx), query_idx, 'makima');

        % Round to the nearest integer (pixel grid)
        Bcx_rounded = round(Bcx_interp);
        Bcy_rounded = round(Bcy_interp);

        % Remove duplicates while preserving the outline's order
        unique_coords = unique([Bcx_rounded, Bcy_rounded], 'rows', 'stable');

        % Extract the final, clean integer coordinates
        Bcx_final = unique_coords(:, 1);
        Bcy_final = unique_coords(:, 2);

        Bcx_final=Bcx;
        Bcy_final=Bcy;

        % imagesc2(im{v}); hold on
        % plot(xwb_ref(v),ywb_ref(v),'.y','markersize',20)
        % plot(Bcx,Bcy,'r','linewidth',2);
        % plot(Bcx(1),Bcy(1),'or');
        % plot(Bcx_final,Bcy_final,'.-g','linewidth',2);
        % % plot(x_legs,y_legs,'.y','markersize',0.1);
        % return

        bound_dist=hypot(Bcx_final-xwt_ref(f,v),Bcy_final-ywt_ref(f,v));
        
        bound_dist_min=find(bound_dist==min(bound_dist),1);
    
        Bcxx=Bcx_final([bound_dist_min:end 1:bound_dist_min]);
        Bcyy=Bcy_final([bound_dist_min:end 1:bound_dist_min]);

        Bcx1_temp=Bcxx(1:floor(0.5*length(Bcx_final)));
        Bcy1_temp=Bcyy(1:floor(0.5*length(Bcx_final)));
        Bcx2_temp=flip(Bcxx(ceil(0.5*length(Bcx_final)):end),1);
        Bcy2_temp=flip(Bcyy(ceil(0.5*length(Bcx_final)):end),1);

        Bc1_wt_dist=smooth(hypot(Bcx1_temp-xwt_ref(f,v),Bcy1_temp-ywt_ref(f,v)),20);
        Bc1_wt_dist_diff=smooth(diff(Bc1_wt_dist));
        Bc1_wt_dist_diff(1:30)=NaN;

        if any(Bc1_wt_dist_diff<0)
            xedge1=Bcx1_temp(1:find(Bc1_wt_dist_diff<0,1));
            yedge1=Bcy1_temp(1:find(Bc1_wt_dist_diff<0,1));
        else
            xedge1=Bcx1_temp;
            yedge1=Bcy1_temp;
        end

        % imagesc2(im{v}); hold on;
        % plot(xedge1,yedge1,'linewidth',2);
        % plot(xedge1(50:50:end),yedge1(50:50:end),'.g','markersize',5);
        % plot(xedge1(100:100:end),yedge1(100:100:end),'.r','markersize',10);
        % % plot(xedge2,yedge2','linewidth',2);
        % return

        % remove edges that go onto body
        Bc1_ind=sub2ind(im_size,yedge1,xedge1);
        Bc1_ind2=find(S_body{v}(Bc1_ind)==1,1);

        Bc1_wb_dist=hypot(xedge1-xwb_ref(v),yedge1-ywb_ref(v));
        xedge1=xedge1(1:find(Bc1_wb_dist==min(Bc1_wb_dist),1));
        yedge1=yedge1(1:find(Bc1_wb_dist==min(Bc1_wb_dist),1));

        % same for other edge
        Bc2_wt_dist=smooth(hypot(Bcx2_temp-xwt_ref(f,v),Bcy2_temp-ywt_ref(f,v)),20);
        Bc2_wt_dist_diff=smooth(diff(Bc2_wt_dist));
        Bc2_wt_dist_diff(1:30)=NaN;

        if any(Bc2_wt_dist_diff<0)
            xedge2=Bcx2_temp(1:find(Bc2_wt_dist_diff<0,1));
            yedge2=Bcy2_temp(1:find(Bc2_wt_dist_diff<0,1));
        else
            xedge2=Bcx2_temp;
            yedge2=Bcy2_temp;
        end

        % imagesc2(im{v}); hold on;
        % % plot(Bcx1_temp,Bcy1_temp,'linewidth',2)
        % % plot(Bcx2_temp,Bcy2_temp,'linewidth',2)
        % plot(xedge1,yedge1,'linewidth',2);
        % plot(xedge2,yedge2','linewidth',2);
        % return

        % remove edges that go onto body
        Bc2_ind=sub2ind(im_size,yedge2,xedge2);
        Bc2_ind2=find(S_body{v}(Bc2_ind)==1,1);

        if ~isempty(Bc2_ind2)
            xedge2=xedge2(1:Bc2_ind2);
            yedge2=yedge2(1:Bc2_ind2);

        end

        Bc2_wb_dist=hypot(xedge2-xwb_ref(v),yedge2-ywb_ref(v));
        xedge2=xedge2(1:find(Bc2_wb_dist==min(Bc2_wb_dist),1));
        yedge2=yedge2(1:find(Bc2_wb_dist==min(Bc2_wb_dist),1));

        % % hopefully no longer need as now implemented earlier
        xedge11{v}=xedge1;
        yedge11{v}=yedge1;

        xedge22{v}=xedge2;
        yedge22{v}=yedge2;

        % [y_legs,x_legs]=find(S_legs{v});

        % imagesc2(im{v}); hold on
        % plot(xedge1,yedge1,'r','linewidth',2);
        % plot(xedge2,yedge2,'g','linewidth',2);
        % % plot(x_legs,y_legs,'.');
        % return

        % hopefully this time fixed so no longer need this leg code
        % remove edge that's near a likely leg and interpolate gaps if
        % needed

        % h_edge1=NaN(size(xedge1));
        % 
        % for i=1:length(xedge1)
        % 
        %     h_edge1(i)=min(hypot(xedge1(i)-x_legs,yedge1(i)-y_legs));
        % 
        % end
        % 
        % h_edge2=NaN(size(xedge2));
        % 
        % for i=1:length(xedge2)
        % 
        %     h_edge2(i)=min(hypot(xedge2(i)-x_legs,yedge2(i)-y_legs));
        % 
        % end
        % 
        % xedge1(h_edge1<5)=NaN;
        % yedge1(h_edge1<5)=NaN;
        % 
        % idx1 = strfind(isnan([NaN xedge1' NaN]), [true false true]);
        % xedge1(idx1)=NaN;
        % yedge1(idx1)=NaN;
        % 
        % idx1 = strfind(isnan([NaN xedge1' NaN]), [true false false true]);
        % xedge1([idx1 idx1+1])=NaN;
        % yedge1([idx1 idx1+1])=NaN;
        % 
        % xedge11{v}=fillmissing(xedge1,'spline','EndValues','none');
        % yedge11{v}=fillmissing(yedge1,'spline','EndValues','none');
        % xedge11{v}=rmmissing(xedge11{v});
        % yedge11{v}=rmmissing(yedge11{v});
        % 
        % xedge2(h_edge2<5)=NaN;
        % yedge2(h_edge2<5)=NaN;
        % 
        % idx2 = strfind(isnan([NaN xedge2' NaN]), [true false true]);
        % xedge2(idx2)=NaN;
        % yedge2(idx2)=NaN;
        % 
        % idx2 = strfind(isnan([NaN xedge2' NaN]), [true false false true]);
        % xedge2([idx2 idx2+1])=NaN;
        % yedge2([idx2 idx2+1])=NaN;
        % 
        % xedge22{v}=fillmissing(xedge2,'spline','EndValues','none');
        % yedge22{v}=fillmissing(yedge2,'spline','EndValues','none');
        % xedge22{v}=rmmissing(xedge22{v});
        % yedge22{v}=rmmissing(yedge22{v});
        

        edge11_ind=sub2ind(im_size(:,v)',round(yedge11{v}),round(xedge11{v}));
        S_edges1{v}=false(im_size(:,v)');
        S_edges1{v}(edge11_ind)=1;

        edge22_ind=sub2ind(im_size(:,v)',round(yedge22{v}),round(xedge22{v}));
        S_edges2{v}=false(im_size(:,v)');
        S_edges2{v}(edge22_ind)=1;
        
        % S_edges1_all{f,v}=S_edges1{v};
        % S_edges2_all{f,v}=S_edges2{v};
        
        % imagesc2(im{v}); hold on;
        % % % imagesc2(bw_legs{v}); hold on;
        % plot(xedge1,yedge1,'.-','linewidth',3);
        % plot(xedge2,yedge2,'.-','linewidth',3);
        % % % 
        % plot(xedge11{v},yedge11{v},'linewidth',2);
        % plot(xedge22{v},yedge22{v},'linewidth',2);
        % return

        % imagesc2(im2{v});
        % return

    end

    % return

    voxels_edges=voxels_wing0;
    
    R2=rodrigues(calib_data.om_grids(:,1));
    T2=calib_data.T_grids(:,1);

    voxels_edges=R2*voxels_edges+repmat(T2,1,size(voxels_edges,2));
    
    % create voxels for the everything and the wings
    starting_volume = size(voxels_edges,2);

    % index so that points can be matched up between the two carves
    index_edges=1:starting_volume;

    % plot3(voxels_edges(1,:),voxels_edges(2,:),voxels_edges(3,:),'.r','markersize',0.1); hold on

    for v=use_cameras
        
        if ~any(v==ref_cams)
            [voxels_edges,index_edges] = carve2_scale_crop(voxels_edges, v, imdilate(S_wings_crop{v},se3), calib_data, index_edges, scale, xcrop_adj(v), ycrop_adj(v));
        end

    end
    
    % plot3(voxels_edges(1,:),voxels_edges(2,:),voxels_edges(3,:),'.'); hold on
    % axis image
    % return

    voxels_edge1=voxels_edges;
    index_edge1=index_edges;

    voxels_edge2=voxels_edges;
    index_edge2=index_edges;
    
    v=ref_cams(1);

    [voxels_edge1,index_edge1] = carve2_scale_crop(voxels_edge1, v, imdilate(S_edges1{v},se5), calib_data, index_edge1, scale, 0, 0);
    [voxels_edge2,index_edge2] = carve2_scale_crop(voxels_edge2, v, imdilate(S_edges2{v},se5), calib_data, index_edge2, scale, 0, 0 );
    
    % plot3(voxels_edge1(1,:),voxels_edge1(2,:),voxels_edge1(3,:),'.'); hold on
    % plot3(voxels_edge2(1,:),voxels_edge2(2,:),voxels_edge2(3,:),'.'); hold on
    % axis image
    % labels
    % 
    % return

    v=ref_cams(2);

    [voxels_edge1_1,index_edge1_1] = carve2_scale_crop(voxels_edge1, v, imdilate(S_edges1{v},se5), calib_data, index_edge1, scale, 0, 0);
    [voxels_edge2_2,index_edge2_2] = carve2_scale_crop(voxels_edge2, v, imdilate(S_edges2{v},se5), calib_data, index_edge2, scale, 0, 0 );

    [voxels_edge1_2,index_edge1_2] = carve2_scale_crop(voxels_edge1, v, imdilate(S_edges2{v},se5), calib_data, index_edge1, scale, 0, 0);
    [voxels_edge2_1,index_edge2_1] = carve2_scale_crop(voxels_edge2, v, imdilate(S_edges1{v},se5), calib_data, index_edge2, scale, 0, 0 );

    % return
    if size(voxels_edge1_1,2)+size(voxels_edge2_2,2) > size(voxels_edge1_2,2)+size(voxels_edge2_1,2)
        voxels_edge1=voxels_edge1_1;
        index_edge1=index_edge1_1;
        
        voxels_edge2=voxels_edge2_2;
        index_edge2=index_edge2_2;
        
    else

        voxels_edge1=voxels_edge1_2;
        index_edge1=index_edge1_2;
        
        voxels_edge2=voxels_edge2_1;
        index_edge2=index_edge2_1;

        xtemp=xedge22{ref_cams(2)};
        ytemp=yedge22{ref_cams(2)};

        xedge22{ref_cams(2)}=xedge11{ref_cams(2)};
        yedge22{ref_cams(2)}=yedge11{ref_cams(2)};

        xedge11{ref_cams(2)}=xtemp;
        yedge11{ref_cams(2)}=ytemp;
        
    end

    voxels_edge1=R2'*(voxels_edge1-repmat(T2,1,size(voxels_edge1,2)));
    voxels_edge2=R2'*(voxels_edge2-repmat(T2,1,size(voxels_edge2,2)));

    % plot3(-voxels_edge1(1,:),voxels_edge1(2,:),voxels_edge1(3,:),'.'); hold on
    % plot3(-voxels_edge2(1,:),voxels_edge2(2,:),voxels_edge2(3,:),'.')
    % 
    % plot3(-Xwt,Ywt,Zwt); hold on
    % plot3(-Xwt(f),Ywt(f),Zwt(f),'.g','markersize',20); hold on
    % plot3(-Xwb,Ywb,Zwb,'.r','markersize',20);
    % plot3(-XwbR,YwbR,ZwbR,'.r','markersize',20);
    % plot3(-Xant,Yant,Zant,'.b','markersize',20);
    % set(gca,'zdir','reverse')
    % labels
    % axis image
    % return

    voxels_edge0_1=voxels_wing5_0_110(:,index_edge1)./wing_length_med;
    voxels_edge0_2=voxels_wing5_0_110(:,index_edge2)./wing_length_med;
    
    voxels_edge0_1_mid=voxels_edge0_1(:,voxels_edge0_1(2,:)>0.4 & voxels_edge0_1(2,:)<0.75);
    voxels_edge0_2_mid=voxels_edge0_2(:,voxels_edge0_2(2,:)>0.4 & voxels_edge0_2(2,:)<0.75);

    if median(hypot(voxels_edge0_1_mid(1,:),voxels_edge0_1_mid(3,:)))<median(hypot(voxels_edge0_2_mid(1,:),voxels_edge0_2_mid(3,:)))

        voxels_lead=voxels_edge1;
        voxels_trail=voxels_edge2;

        voxels_lead0=voxels_edge0_1;
        voxels_trail0=voxels_edge0_2;

        xlead=xedge11;
        ylead=yedge11;
        
        xtrail=xedge22;
        ytrail=yedge22;

    else

        voxels_lead=voxels_edge2;
        voxels_trail=voxels_edge1;

        voxels_lead0=voxels_edge0_2;
        voxels_trail0=voxels_edge0_1;

        xlead=xedge22;
        ylead=yedge22;
        
        xtrail=xedge11;
        ytrail=yedge11;

    end

    xlead_all(f,1:length(xlead))=xlead;
    ylead_all(f,1:length(ylead))=ylead;
    xtrail_all(f,1:length(xtrail))=xtrail;
    ytrail_all(f,1:length(ytrail))=ytrail;

    % voxels_lead0_all{f,1}=voxels_lead0;
    % voxels_trail0_all{f,1}=voxels_trail0;
    % 
    % voxels_lead_all{f,1}=voxels_lead;
    % voxels_trail_all{f,1}=voxels_trail;
    
    % plot3(-voxels_edge0_1(1,:),voxels_edge0_1(2,:),voxels_edge0_1(3,:),'.'); hold on
    % plot3(-voxels_edge0_2(1,:),voxels_edge0_2(2,:),voxels_edge0_2(3,:),'.')
    % 
    % plot3(-voxels_edge0_1_mid(1,:),voxels_edge0_1_mid(2,:),voxels_edge0_1_mid(3,:),'.r','markersize',15); hold on
    % plot3(-voxels_edge0_2_mid(1,:),voxels_edge0_2_mid(2,:),voxels_edge0_2_mid(3,:),'.r','markersize',15)
    % set(gca,'zdir','reverse')
    % axis image
    % labels
    % return

    [L,numClusters,sizeClusters]=labelVoxels(XX_wing2,sqrt(3)*res);
    
    [sizeCLusters_ordered,sizeCLusters_order_index]=sort(sizeClusters);

    if length(sizeClusters)>1

        XX_wing2(L~=sizeCLusters_order_index(end),:)=[];
        voxels_wing(:,L~=sizeCLusters_order_index(end))=[];
    end

    % plot3(Xm_wing,Ym_wing,Zm_wing); hold on
    % plot3(voxels_wing(1,:),voxels_wing(2,:),voxels_wing(3,:),'.');
    % plot3(voxels_lead0(1,:),voxels_lead0(2,:),voxels_lead0(3,:),'.','color',[0.0660 0.4430 0.7450],'markersize',10); hold on
    % plot3(voxels_trail0(1,:),voxels_trail0(2,:),voxels_trail0(3,:),'.','color',[0.8660 0.3290 0.0000],'markersize',10);

    % axis image
    % labels
    % return

    XwLe2=voxels_lead0(1,:).*wing_length_med;
    YwLe2=voxels_lead0(2,:).*wing_length_med;
    ZwLe2=voxels_lead0(3,:).*wing_length_med;
    
    XwTr2=voxels_trail0(1,:).*wing_length_med;
    YwTr2=voxels_trail0(2,:).*wing_length_med;
    ZwTr2=voxels_trail0(3,:).*wing_length_med;

    for i=1:size(yvoxels_range,2)

        
        XwLe2_slice=XwLe2(abs(YwLe2-yvoxels_range(i))<0.5*res);
        YwLe2_slice=YwLe2(abs(YwLe2-yvoxels_range(i))<0.5*res);
        ZwLe2_slice=ZwLe2(abs(YwLe2-yvoxels_range(i))<0.5*res);

        XwLe2_slice_rep=repmat(XwLe2_slice,length(XwLe2_slice),1);
        ZwLe2_slice_rep=repmat(ZwLe2_slice,length(ZwLe2_slice),1);

        HwLe_slice=hypot(XwLe2_slice_rep-XwLe2_slice_rep',ZwLe2_slice_rep-ZwLe2_slice_rep');

        if ~isempty(XwLe2_slice) && max(HwLe_slice(:)<0.5*wing_length_med)

            XwLead(f,i)=mean(XwLe2_slice)./wing_length_med;
            YwLead(f,i)=mean(YwLe2_slice)./wing_length_med;
            ZwLead(f,i)=mean(ZwLe2_slice)./wing_length_med;

        end

        XwTr2_slice=XwTr2(abs(YwTr2-yvoxels_range(i))<0.5*res);
        YwTr2_slice=YwTr2(abs(YwTr2-yvoxels_range(i))<0.5*res);
        ZwTr2_slice=ZwTr2(abs(YwTr2-yvoxels_range(i))<0.5*res);

        XwTr2_slice_rep=repmat(XwTr2_slice,length(XwTr2_slice),1);
        ZwTr2_slice_rep=repmat(ZwTr2_slice,length(ZwTr2_slice),1);

        HwTr_slice=hypot(XwTr2_slice_rep-XwTr2_slice_rep',ZwTr2_slice_rep-ZwTr2_slice_rep');

        if ~isempty(XwTr2_slice) && max(HwTr_slice(:)<0.5*wing_length_med)

            XwTrail(f,i)=mean(XwTr2_slice)./wing_length_med;
            YwTrail(f,i)=mean(YwTr2_slice)./wing_length_med;
            ZwTrail(f,i)=mean(ZwTr2_slice)./wing_length_med;

        end

    end

    % plot3(voxels_lead0(1,:),voxels_lead0(2,:),voxels_lead0(3,:),'.','color',[0.0660 0.4430 0.7450],'markersize',10); hold on
    % plot3(voxels_trail0(1,:),voxels_trail0(2,:),voxels_trail0(3,:),'.','color',[0.8660 0.3290 0.0000],'markersize',10);
    % 
    % plot3(XwLead(f,:),YwLead(f,:),ZwLead(f,:),'linewidth',2);
    % plot3(XwTrail(f,:),YwTrail(f,:),ZwTrail(f,:),'linewidth',2);
    % 
    % axis image
    % labels
    % return

    if draw==1
        if f==f_start
   
            for v=use_cameras

                % [xmwing_rep(:,v),ymwing_rep(:,v)]=reproject_points(calib_data,v,XXm_wing,1);
                
                axes
                % I(v)=imagesc2(im{v}.*(wing_mask2{v}./2+0.5)); hold on

                I(v)=imagesc2(im{v}); hold on
                
                % PmaskL(v)=patch(xmask{v}([1:end 1]),ymask{v}([1:end 1]),'b','facealpha',0.1);
                % Pmwing(v)=plot(xmwing_rep(:,v),ymwing_rep(:,v),'y');
                Poutline(v)=plot(B_wings{v}(:,2),B_wings{v}(:,1),'g','linewidth',2);

                plot(xwb_ref(v),ywb_ref(v),'.y','markersize',14)

                if any(v==ref_cams)
                
                    Pe11(v)=plot(xlead{v},ylead{v},'color',[0.0660 0.4430 0.7450],'linewidth',2);
                    Pe22(v)=plot(xtrail{v},ytrail{v},'color',[0.8660 0.3290 0.0000],'linewidth',2);

                else

                    Pe11(v)=plot(NaN,NaN,'color',[0.0660 0.4430 0.7450],'linewidth',2);
                    Pe22(v)=plot(NaN,NaN,'color',[0.8660 0.3290 0.0000],'linewidth',2);
                    
                end
                
                axis off

                if v==1
                    set(gca,'position',[0.0 0.5 0.2 0.5])
                elseif v==2
                    set(gca,'position',[0.2 0.5 0.2 0.5])
                elseif v==3
                    set(gca,'position',[0.4 0.5 0.2 0.5])
                elseif v==4
                    set(gca,'position',[0.0 0.0 0.2 0.5])
                elseif v==5
                    set(gca,'position',[0.2 0.0 0.2 0.5])
                elseif v==6
                    set(gca,'position',[0.4 0.0 0.2 0.5])
                end
            end

            axes
            % plot3(Xwt,Ywt,Zwt); hold on
            % Pwt=plot3([Xwb Xwt(f)],[Ywb Ywt(f)],[Zwb Zwt(f)],'.-r','markersize',20,'linewidth',3); hold on
        
            Pwt=plot3([0 0],[0 1],[0 0],'.-r','markersize',16,'linewidth',2); hold on
            % P=plot3(voxels_wing(1,:),voxels_wing(2,:),voxels_wing(3,:),'.r','markersize',1);

            PeL=plot3(-voxels_lead0(1,:),voxels_lead0(2,:),voxels_lead0(3,:),'.','color',[0.0660 0.4430 0.7450],'markersize',8);
            PeT=plot3(-voxels_trail0(1,:),voxels_trail0(2,:),voxels_trail0(3,:),'.','color',[0.8660 0.3290 0.0000],'markersize',8);

            PeLL=plot3(-XwLead(f,:),YwLead(f,:),ZwLead(f,:),'color',0.8*[0.8660 0.3290 0.0000],'linewidth',2);
            PeTT=plot3(-XwTrail(f,:),YwTrail(f,:),ZwTrail(f,:),'color',0.8*[0.8660 0.3290 0.0000],'linewidth',2);

            axis image
            labels      

            set(gca,'position',[0.65 0.0 0.3 1],'zdir','reverse')
            view(-120,25)

            axis([-0.35 0.35 0 1 -0.35 0.35])

            set(gcf,'position',[100 100 1500 600],'color','w')


            T=annotation('textbox','position',[0.5,0.85,.5, 0.1],'edgecolor','none','horizontalalignment','center',...
                         'fontsize',14,'string',[sequence_name ': ' num2str(f) ' / ' num2str(f_end)]);

        else

            for v=use_cameras

                [xmwing_rep(:,v),ymwing_rep(:,v)]=reproject_points(calib_data,v,XXm_wing,1);

                set(I(v),'cdata',im{v});
                % set(I(v),'cdata',im{v}.*(wing_mask2{v}./2+0.5));
                set(Poutline(v),'xdata',B_wings{v}(:,2),'ydata',B_wings{v}(:,1));
                % set(PmaskL(v),'xdata',xmask{v}([1:end 1]),'ydata',ymask{v}([1:end 1]));
                % set(Pmwing(v),'xdata',xmwing_rep(:,v),'ydata',ymwing_rep(:,v))

                if any(v==ref_cams)
                
                    set(Pe11(v),'xdata',xlead{v},'ydata',ylead{v});
                    set(Pe22(v),'xdata',xtrail{v},'ydata',ytrail{v});

                else

                    set(Pe11(v),'xdata',NaN,'ydata',NaN);
                    set(Pe22(v),'xdata',NaN,'ydata',NaN);
                    
                end

            end

            % set(Pwt,'xdata',[Xwb Xwt(f)],'ydata',[Ywb Ywt(f)],'zdata',[Zwb Zwt(f)])
            % set(P,'xdata',voxels_wing(1,:),'ydata',voxels_wing(2,:),'zdata',voxels_wing(3,:))
            % set(PwingL,'xdata',Xm_wing,'ydata',Ym_wing,'zdata',Zm_wing)

            set(PeL,'xdata',-voxels_lead0(1,:),'ydata',voxels_lead0(2,:),'zdata',voxels_lead0(3,:));
            set(PeT,'xdata',-voxels_trail0(1,:),'ydata',voxels_trail0(2,:),'zdata',voxels_trail0(3,:));

            set(PeLL,'xdata',-XwLead(f,:),'ydata',YwLead(f,:),'zdata',ZwLead(f,:));
            set(PeTT,'xdata',-XwTrail(f,:),'ydata',YwTrail(f,:),'zdata',ZwTrail(f,:));

            set(T,'string',[sequence_name ': ' num2str(f) ' / ' num2str(f_end)])

        end
        
        drawnow
        % return

        if write_vids==1
            cdata=print('-RGBImage','-r0');
            cdata2=cdata;
            % cdata2=imresize(cdata,0.5,'bicubic');
            writeVideo(vid_save,uint8(cdata2));
        end

    end

    % toc
    % return
    
end

if ~exist('single_wing_tracked_points','dir')
    mkdir('single_wing_tracked_points')
end

save(fullfile('single_wing_tracked_points',[sequence_name '_tracked_outline_outer.mat']),'pitch_ang_init','stroke_ang','dev_ang','stroke_ang_f','dev_ang_f','Xwt_f','Ywt_f','Zwt_f','*all','*Lead','*Trail','wing_yrange','wing_length_med')

if write_vids==1
    close(vid_save)
    close all
end