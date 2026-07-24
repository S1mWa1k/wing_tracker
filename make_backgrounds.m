clear
close all

%% EDITABLE PART %%
% folder where recordings are stored
base_folder=fullfile('D:','Micro_arena');
date_folder='2026_06_30';
sequence_name='Fly7_a'; % assummed to be in base_folder -> date folder
%% END EDITABLE PART %%

draw=0;
se = strel('disk',1);
se2 = strel('disk',2);
se_large = strel('disk',10);

h = fspecial('gaussian', 3, 1);

thresh=[100 100 100 50].*2^3;

wb_period_lim=50;

fly_name=sequence_name;

if exist(fullfile('single_wing_init_points',[fly_name '_init_click.mat']))

    load(fullfile('single_wing_init_points',[fly_name '_init_click.mat']))

else
    
    error('Run single_wing_click_init_points.m first')
end

if ~exist('single_wing_backgrounds')
    mkdir('single_wing_backgrounds');
end

filenames=dir(fullfile(base_folder,date_folder,sequence_name,'*.cihx'));
filenames={filenames.name};

filenames=filenames(1:6);
num_cams=length(filenames);

for v=1:num_cams
    
    [~,name,ext] = fileparts(filenames{v});

    vid(v)=quick_parse_cihx(fullfile(base_folder,date_folder,sequence_name,filenames{v}));
    
    n_frames(v)=vid(v).TotalFrame;
    im_size(:,v)=[vid(v).ImageHeight vid(v).ImageWidth];

    im_back_stack=zeros(im_size(1,v),im_size(2,v),100,'double');
    
    for i=1:200
        im_back_stack(:,:,i)=double(readmraw(vid(v),i));
    end
    
    im_back{v}=max(im_back_stack,[],3);
    
end

if ~exist(fullfile('single_wing_backgrounds',[fly_name '_backgrounds.mat']),'dir')
    mkdir(fullfile('single_wing_backgrounds',[fly_name '_backgrounds.mat']))
end

save(fullfile('single_wing_backgrounds',[fly_name '_backgrounds.mat']),'im_back')
