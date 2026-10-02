clear
close all

%% EDITABLE PART %%
% folder where recordings are stored
% base_folder   = fullfile('D:','Micro_arena','Hermetia');
base_folder   = fullfile('Z:','Beth_Microarena','Calliphora');

project_folder ='Calliphora';

date_folder='2026_08_18';

d=dir(fullfile(project_folder,'single_wing_init_points',date_folder,'*_init_click.mat'));

% sequence_pref='S_Fly';
% 
% d=dir(fullfile(base_folder,date_folder,[sequence_pref '*']));

sequences={d.name};

% sequences(contains(sequences, 'background'))=[];

for S=1:length(sequences)

    clearvars -except S sequences base_folder date_folder project_folder
    sequence_name=erase(sequences{S}, '_init_click.mat');

    if ~exist(fullfile(project_folder,'single_wing_backgrounds',date_folder,[sequence_name '_backgrounds.mat']),'file')

        sequence_name = erase(sequence_name, '_init_click.mat');
        % sequence_name='S_Fly2_6'; % assumed to be in date folder
        
        %% END EDITABLE PART %%
            
        if exist(fullfile(project_folder,'single_wing_init_points',date_folder,[sequence_name '_init_click.mat']),'file')
        
            load(fullfile(project_folder,'single_wing_init_points',date_folder,[sequence_name '_init_click.mat']))
        
        else
            
            error('Run single_wing_click_init_points.m first')
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
        
        if ~exist(fullfile(project_folder,'single_wing_backgrounds',date_folder),'dir')
            mkdir(fullfile(project_folder,'single_wing_backgrounds',date_folder))
        end
        
        save(fullfile(project_folder,'single_wing_backgrounds',date_folder,[sequence_name '_backgrounds.mat']),'im_back')
        disp(['made background for ' sequence_name])
    end
end