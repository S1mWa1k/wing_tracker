clear
close all 
   
% This version for carrying on with 
warning off

%% EDITABLE PART %%
% folder where recordings are stored
base_folder=fullfile('D:','Micro_arena');
date_folder='2026_06_30';
sequence_name='Fly7_a'; % assummed to be in date folder
background_name='Fly7_background'; % name of folder container background videos (with no fly attached)

% load calibration file - assumed to be in base_folder -> date_folder
calib_name='Fly6_calib_results_0dist';
%% END EDITABLE PART %%

load CalliphoraWing_new

% set to 0 to disable drawing while the tracker runs (improves speed).
draw=1;

write_vids=0;

use_cameras=[1 2 3 4 5 6];

thresh=100.*ones(1,6);

se40 = strel('disk',40,8);

% load initial points
load(fullfile('single_wing_init_points',[sequence_name '_init_click.mat']))
load(fullfile('single_wing_backgrounds',[sequence_name '_backgrounds.mat']))
load(fullfile('single_wing_tracked_points',[sequence_name '_tracked_wt.mat']))
load(fullfile('single_wing_tracked_points',[sequence_name '_tracked_outline.mat']))
load(fullfile('single_wing_filtered_points',[sequence_name '_filtered_outline.mat']))

% find camera file in sequence folder
filenames=dir(fullfile(base_folder,date_folder,sequence_name,'*.cihx'));
filenames={filenames.name};
filenames=filenames(1:6);

% number of cameras
num_cams=length(filenames);
     
num_frames=size(xxwtL,1);

% load calibration file
load(fullfile(date_folder,calib_name))

% empty variables for number of frames and image size
im_size=NaN(2,num_cams);

XXwt=[Xwt Ywt Zwt]-[Xwb Ywb Zwb];
wing_length=sqrt(sum(XXwt.^2,2));

% scale model wing
Xmwing0=(Xwing*0.98)*wing_length_med;
Ymwing0=(Ywing*0.9+0.1)*wing_length_med;
Zmwing0=zeros(size(Xmwing0));

% Xmwing0=Xwing*wing_length_med;
% Ymwing0=Ywing*wing_length_med;
% Zmwing0=zeros(size(Xmwing0));

Xmbranches0=Xbranches'*0.98*wing_length_med;
Ymbranches0=(Ybranches'*0.9+0.1)*wing_length_med;
Zmbranches0=zeros(size(Xmbranches0));

% Xmbranches0=Xbranches'*wing_length_med;
% Ymbranches0=Ybranches'*wing_length_med;
% Zmbranches0=zeros(size(Xmbranches0));

res_scale=1;
res=wing_length_med/(100*res_scale);
    
% main voxels for carving
wing_yrange=0:110;
xvoxels_range=(-35:35)*res*res_scale;
yvoxels_range=wing_yrange.*res*res_scale;
zvoxels_range=(-35:35)*res*res_scale;

[Y,X,Z] = meshgrid(yvoxels_range, xvoxels_range, zvoxels_range);
voxels_wing5_0_110 = [X(:)'; Y(:)'; Z(:)'];

% for each camera load the video file and check it's 

xwt_ref=NaN(num_frames,num_cams);
ywt_ref=NaN(num_frames,num_cams);

xwb_ref=NaN(1,num_cams);
ywb_ref=NaN(1,num_cams);

if write_vids==1
    if ~exist(fullfile('DLC_crops','BG removed',sequence_name),'dir')
        mkdir(fullfile('DLC_crops','BG removed',sequence_name))
    end

     if ~exist(fullfile('DLC_crops','BG removed inverted',sequence_name),'dir')
        mkdir(fullfile('DLC_crops','BG removed inverted',sequence_name))
    end
end

for v=1:num_cams

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

rec_freq=6400;

f_start=find(~isnan(pitch_ang_init),1);
f_end=find(~isnan(pitch_ang_init),1,'last');

% f_start=6;

i_curr=f_start;

vid_lims=NaN(num_cams,4);

for v=use_cameras

    % get filename excluding extension
    [~,name,ext] = fileparts(filenames{v});
    
    if write_vids==1
        vid_save1 = VideoWriter(fullfile('DLC_crops','BG removed',sequence_names{S},[name '.avi']),'Grayscale AVI');
        vid_save1.FrameRate=25;
        open(vid_save1)

        vid_save2 = VideoWriter(fullfile('DLC_crops','BG removed inverted',sequence_names{S},[name '.avi']),'Grayscale AVI');
        vid_save2.FrameRate=25;
        open(vid_save2)
    end

    use_frames=find(ref_cams_all(:,v)==1)';

    Bwing_mask=cell2mat(Bwing_mask_all(use_frames,v));

    vid_lims(v,:)=[min(Bwing_mask) max(Bwing_mask)]+[-5 -5 5 +5];
    
    vid_lims(v,vid_lims(v,:)<0)=1;
    
    if vid_lims(v,3)>im_size(1,v)
         vid_lims(v,3)=im_size(1,v);
    end
    
    if vid_lims(v,4)>im_size(2,v)
         vid_lims(v,4)=im_size(2,v);
    end

    ff=1;

    for f=use_frames

        % if draw==0
        %     if mod(f,100)==0
        % 
        %         fprintf(['...' num2str(i) ' '])
        %     end
        % 
        %     if mod(i,1200)==0 
        %         fprintf('\n')
        %     end
        % end

        im=double(readmraw(vid(v),f));

        % im_ind=(im>1.5*thresh(v)).*(im_back{v}>1.5*thresh(v));
        % im_ind=imerode(im_ind,se40);
        % 
        % im_back_scale=mean(mean(im(im_ind==1)))./mean((im_back{v}(im_ind==1)));
        im_back_scale=1;

        im_back2=im_vid_back{v}.*im_back_scale;
        im2=im_back2-im;
        im2(im2<0)=0;
        
        wing_mask2_ind=sub2ind(im_size(:,v)',Bwing_mask_all{f,v}(:,1),Bwing_mask_all{f,v}(:,2));
        wing_mask2=false(im_size(:,v)');
        wing_mask2(wing_mask2_ind)=1;
        wing_mask2=imfill(wing_mask2,'holes');

        im_mask=im.*wing_mask2;
        im_mask_crop=im_mask(vid_lims(v,1):vid_lims(v,3),vid_lims(v,2):vid_lims(v,4));

        im2_mask=im2.*wing_mask2;
        im2_mask_crop=im2_mask(vid_lims(v,1):vid_lims(v,3),vid_lims(v,2):vid_lims(v,4));

        % vid_lims_all
        if write_vids==1

            writeVideo(vid_save1,uint8((2^12-im2_mask_crop)./2^4));

            writeVideo(vid_save2,uint8(im2_mask_crop./2^4));
            
        end

        % imagesc2(im_mask_crop);

        % figure

        if f==use_frames(1)
            close
            I=imagesc2(2^12-im2_mask_crop);
        else
            set(I,'cdata',2^12-im2_mask_crop)
        end

        drawnow

        % figure
        % 
        % imagesc2(im2_mask_crop);
        % 
        % 
        % return
    end

    if write_vids==1
        close(vid_save1)
        close(vid_save2)
    end

end

save(fullfile('DLC_crops','BG removed',sequence_name,[sequence_name '_crop_offsets']),'vid_lims')