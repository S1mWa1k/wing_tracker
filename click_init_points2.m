clear
close all

% New version that also gets you to select right wingbase and base of
% antennae.

%% EDITABLE PART %%
% folder where recordings are stored
base_folder=fullfile('D:','Micro_arena');
date_folder='2026_06_30';
sequence_name='Fly7_a'; % assummed to be in date folder

% load calibration file - assumed to be in base_folder -> date_folder
calib_name='Fly6_calib_results_0dist';
%% END EDITABLE PART %%

% starting frame, set to 6 so that previous frames can be used for average
% background subtraction
i_start=6;

% create empty variable
sequences=[];

% get the size of the screen
screensize = get( groot, 'Screensize');

% create [R G B] colours for wingtip and wingbase plots
col_wt=[0.7 0.0 0.7;
        0.8 0.0 0.0;
        0.9 0.4 0.0;
        0.8 0.8 0.0;
        0.7 0.0 0.7;
        0.8 0.0 0.0;
        0.9 0.4 0.0;
        0.8 0.8 0.0];
    
col_wb=[0.0 0.0 0.8;
        0.0 0.4 1.0;
        0.0 0.6 0.6;
        0.0 0.8 0.0;
        0.0 0.0 0.8;
        0.0 0.4 1.0;
        0.0 0.6 0.6;
        0.0 0.8 0.0];

% clear unneeded variables
% clearvars -except sequence_folders sequence_names S i_start screensize col_wt col_wb

% get camera names in folder
filenames=dir(fullfile(base_folder,date_folder,sequence_name,'*.cihx'));
filenames={filenames.name};

% number of cameras (although code only really works with 4)
num_cams=6;
use_cameras=1:num_cams;
       
load(fullfile(date_folder,calib_name));

% empty variables
n_frames=NaN(1,num_cams);
im_size=NaN(2,num_cams);

% for each camera load the video file and get parameters
for v=1:num_cams

    % function for loading raw video file
    vid(v)=quick_parse_cihx(fullfile(base_folder,date_folder,sequence_name,filenames{v}));
    
    % number of frames
    n_frames(v)=vid(v).TotalFrame;
    
    % image size
    im_size(:,v)=[vid(v).ImageHeight vid(v).ImageWidth];

end

xwtL=NaN(1,num_cams);
ywtL=NaN(1,num_cams);

xwbL=NaN(1,num_cams);
ywbL=NaN(1,num_cams);

xwbR=NaN(1,num_cams);
ywbR=NaN(1,num_cams);

xant=NaN(1,num_cams);
yant=NaN(1,num_cams);

curr_point=1;

% create new figure with handle
FigH = figure('UserData', []);

ii=1;

% run loop for each camera
for v=use_cameras

    % create stack of images
    for i=i_start:4:(i_start+13)
        if i==i_start
            im_base=double(readmraw(vid(v),i));
            im_stack=im_base;
        else
            im_stack=im_stack+double(readmraw(vid(v),i));
        end

    end
    
    % combine stack, with weighted first frame
    im{v}=im_stack+5.*im_base;
    
    % create subplots
    % ax(v)=subplot(1,2,ii);
    ax(v)=subplot(2,3,ii);

    % display image and set function 'Callback_button' for when you click mouse button
    I(v)=imagesc2(im{v},'ButtonDownFcn', {@Callback_button, v}); hold on
    
    % brigthen the images
    brighten(.6)
    
    % make new graphic objects add to axes (same as 'hold on')
    set(ax(v),'parent', FigH, 'nextplot', 'add');
    
    % set the userdata to the camera number
    set(ax(v),'UserData',v);
    
    % set function 'Callback_scroll' to run when mouse wheel used
    % and function 'Callback_key' when keyboard used
    set(FigH,'WindowScrollWheelFcn',{@Callback_scroll, v},'MenuBar','none','resize','off','WindowKeyPress',{@Callback_key, v});
    set(FigH,'DoubleBuffer','on')

    % create plot handles for epipolar lines
    for vv=1:num_cams
        Pepi_wt(v,vv)=plot(NaN(1000,1),NaN(1000,1),'linewidth',1);
        set(Pepi_wt(v,vv),'color',col_wt(vv,:))

        Pepi_wbL(v,vv)=plot(NaN(1000,1),NaN(1000,1),'linewidth',1);
        set(Pepi_wbL(v,vv),'color',col_wb(vv,:))

        Pepi_wbR(v,vv)=plot(NaN(1000,1),NaN(1000,1),'linewidth',1);
        set(Pepi_wbR(v,vv),'color',col_wb(vv,:))

        Pepi_ant(v,vv)=plot(NaN(1000,1),NaN(1000,1),'linewidth',1);
        set(Pepi_ant(v,vv),'color',col_wt(vv,:))
    end

    % create plot handles
    PwtL(v)=plot(xwtL(v),ywtL(v),['.' col_wt(ii,:)],'markersize',20);
    PwbL(v)=plot(xwbL(v),ywbL(v),['.' col_wb(ii,:)],'markersize',20);
    PwbR(v)=plot(xwbL(v),ywbL(v),['.' col_wb(ii,:)],'markersize',20);
    Pant(v)=plot(xwbL(v),ywbL(v),['.' col_wt(ii,:)],'markersize',20);

    % set function for 'Callback_button' for if you click on a
    % prevous point or line
    set(PwtL(v),'ButtonDownFcn', {@Callback_button, v},'color',col_wt(ii,:))
    set(PwbL(v),'ButtonDownFcn', {@Callback_button, v},'color',col_wb(ii,:))
    set(PwbR(v),'ButtonDownFcn', {@Callback_button, v},'color',col_wb(ii,:))
    set(Pant(v),'ButtonDownFcn', {@Callback_button, v},'color',col_wt(ii,:))

    set(Pepi_wt(v,:),'ButtonDownFcn', {@Callback_button, v})
    set(Pepi_wbL(v,:),'ButtonDownFcn', {@Callback_button, v})
    set(Pepi_wbR(v,:),'ButtonDownFcn', {@Callback_button, v})
    set(Pepi_ant(v,:),'ButtonDownFcn', {@Callback_button, v})

    % set axis to size of image
    axis([1 im_size(2,v) 1 im_size(1,v)]);

    % turn of axis lines
    axis off

    % set positions of axes
    if ii==1
        set(gca,'position',[0 0.48 1/3 0.48]);
    elseif ii==2
        set(gca,'position',[1/3 0.48 1/3 0.48]);
    elseif ii==3
        set(gca,'position',[2/3 0.48 1/3 0.48]);
    elseif ii==4
        set(gca,'position',[0 0 1/3 0.48]);
    elseif ii==5
        set(gca,'position',[1/3 0 1/3 0.48]);
    else
        set(gca,'position',[2/3 0 1/3 0.48]);
    end

    % if ii==1
    %     set(gca,'position',[0 0.48 0.5 0.48]);
    % elseif ii==2
    %     set(gca,'position',[0.5 0.48 0.5 0.48]);
    % elseif ii==3
    %     set(gca,'position',[0 0 0.5 0.48]);
    % else
    %     set(gca,'position',[0.5 0 0.5 0.48]);
    % end

    % if ii==1
    %     set(gca,'position',[0 0 0.5 1]);
    % elseif ii==2
    %     set(gca,'position',[0.5 0 0.5 1]);
    % end

    ii=ii+1;
end

% set(gcf,'position',[100 100 1024 512])
% set(gcf,'position',[100 100 1024 1024])
set(gcf,'position',[100 100 1024 683])

% make the image fill the screen, but keep the aspect ratio correct,
% so check if the aspect ratio is taller or wider than the screen
% if sum(im_size(2,1:2))/sum(im_size(1,1:2)) < screensize(3)/screensize(4)
% 
%     % set figure height to screen height-72px to account for taskbar
%     fig_h=screensize(4)-72;
%     % set figure width based on ratio of images
%     fig_w=0.96*fig_h*sum(im_size(2,1:2))/sum(im_size(1,1:2));
% 
%     set(gcf,'position',[0.5*(screensize(3)-fig_w) 42 fig_w fig_h])
% else
% 
%     % set figure width to screen width
%     fig_w=screensize(3);
%     % set figure height based on ratio of images
%     fig_h=0.96*fig_w*sum(im_size(1,1:2))/sum(im_size(2,1:2));
% 
%     set(gcf,'position',[0 0.5*(screensize(4)-fig_h) fig_w fig_h])
% end

% create new  axes for title
axTitle=axes('parent', FigH, 'nextplot', 'add');

% set axes position and turn off borders
set(axTitle,'position',[0 0.96 1 0.04],'UserData',0,'xtick',[],'ytick',[])

% create text for sequence number
T=text(0.1,0.5,['Sequence: ' sequence_name]);
set(T,'horizontalalignment','left','interpreter','none');

% create text for clicking instructions
TT=text(0.9,0.5,'left click for wing tip, right-click to move to next point, middle-click to clear points');
set(TT,'horizontalalignment','right','interpreter','none');

% set axis limits for figure
axis([0 1 0 1])
axis off

% change pointer to a crosshair
set(gcf,'pointer','crosshair','color','w')

% while the image handle exists (i.e. figure hasn't been closed)
while ishandle(I(v))

    % get user data from the figure
    C = get(FigH, 'UserData');

    % if the userdata isn't empty, it means that an image has
    % been clicked on
    % C = [clicked image axes, mouse button, x, y]
    if ~isempty(C)

        curr_cam=C(1);
        but=C(2);

        x=C(3);
        y=C(4);

        % if left mouse button was clicked then it is wing tip
        if but==1 && curr_point==1

            % set wing tip coordinates
            xwtL(curr_cam)=x;
            ywtL(curr_cam)=y;

            % update plot
            set(PwtL(curr_cam),'xdata',x,'ydata',y);

            % calculate epipolar lines in each camera view and
            % update plots
            for vv=use_cameras
                if vv~=curr_cam
                    [X1, Y1]=draw_epipolar_emg(vv, curr_cam,x,y,calib_data);
                    set(Pepi_wt(vv,curr_cam),'xdata',X1,'ydata',Y1);
                end
            end

        % left wing base
        elseif but==1 && curr_point==2

            xwbL(curr_cam)=x;
            ywbL(curr_cam)=y;

            set(PwbL(curr_cam),'xdata',x,'ydata',y);

            for vv=use_cameras
                if vv~=curr_cam
                    [X1, Y1]=draw_epipolar_emg(vv, curr_cam,x,y,calib_data);
                    set(Pepi_wbL(vv,curr_cam),'xdata',X1,'ydata',Y1);
                end
            end

        % right wing base
        elseif but==1 && curr_point==3

            xwbR(curr_cam)=x;
            ywbR(curr_cam)=y;

            set(PwbR(curr_cam),'xdata',x,'ydata',y);

            for vv=use_cameras
                if vv~=curr_cam
                    [X1, Y1]=draw_epipolar_emg(vv, curr_cam,x,y,calib_data);
                    set(Pepi_wbR(vv,curr_cam),'xdata',X1,'ydata',Y1);
                end
            end

        % base of antennae
        elseif but==1 && curr_point==4

            xant(curr_cam)=x;
            yant(curr_cam)=y;

            set(Pant(curr_cam),'xdata',x,'ydata',y);

            for vv=use_cameras
                if vv~=curr_cam
                    [X1, Y1]=draw_epipolar_emg(vv, curr_cam,x,y,calib_data);
                    set(Pepi_ant(vv,curr_cam),'xdata',X1,'ydata',Y1);
                end
            end

        % if right button, move onto next point
        elseif but==3 && curr_point<4

            if curr_point==1 && sum(~isnan(xwtL))>1
                curr_point=curr_point+1;
                set(TT,'string','left click for left wing base, right-click to move to next point, middle-click to clear points');
                delete(Pepi_wt)
            elseif curr_point==2 && sum(~isnan(xwbL))>1
                curr_point=curr_point+1;
                set(TT,'string','left click for right wing base, right-click to move to next point, middle-click to clear points');
                delete(Pepi_wbL)

            elseif curr_point==3 && sum(~isnan(xwbR))>1
                curr_point=curr_point+1;
                set(TT,'string','left click for antennae base, middle-click to clear points, close figure to save');
                delete(Pepi_wbR)

            else
                warning('you need to click in at least two cameras views before moving on')

            end

            

        % if middle button (or scroll wheel) was pressed then remove points for image
        elseif but==2
           
            xwtL(curr_cam)=NaN;
            ywtL(curr_cam)=NaN;
            xwbL(curr_cam)=NaN;
            ywbL(curr_cam)=NaN;

            set(PwtL(curr_cam),'xdata',NaN,'ydata',NaN);
            set(PwbL(curr_cam),'xdata',NaN,'ydata',NaN);
            set(PwbR(curr_cam),'xdata',NaN,'ydata',NaN);
            set(Pant(curr_cam),'xdata',NaN,'ydata',NaN);

            for vv=1:num_cams
                if vv~=curr_cam
                    set(Pepi_wt(vv,curr_cam),'xdata',NaN(1,2),'ydata',NaN(1,2));
                    set(Pepi_wbL(vv,curr_cam),'xdata',NaN(1,2),'ydata',NaN(1,2));
                end
            end
            
        end

    end

    % empty C  
    C=[];

    % update plots
    drawnow

end

% create save folder if it doesn't already exist
if ~exist('single_wing_init_points','dir')
    mkdir('single_wing_init_points')
end

% if there are two or more values for wingbase and wing tips then
% save the clicked points
if sum(~isnan(xwbL))>1 && sum(~isnan(xwtL))>1 && sum(~isnan(xwbR))>1 && sum(~isnan(xant))>1 && curr_point

    save(fullfile('single_wing_init_points',[sequence_name '_init_click.mat']),'xw*','yw*','xant','yant','i_start')
    disp('saved')

end