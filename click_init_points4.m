clear
close all

%% EDITABLE PART %%
% base_folder   = fullfile('D:','Micro_arena','Soldier Fly');
% date_folder   = '2026_08_27';
% sequence_name = 'S_Fly1_7'; 
% calib_name    = 'Calib_AM_results';

base_folder   = fullfile('Z:','Beth_Microarena','Calliphora');
date_folder   = '2026_09_09';
sequence_name = 'Fly15_2'; 
calib_name    = 'Calib_AM_results';

project_folder ='Calliphora';

%% END EDITABLE PART %%

i_use = 1;

% Colors for wingbase plots
col_wb = [0.0 0.0 0.8; 0.0 0.4 1.0; 0.0 0.6 0.6; 0.0 0.8 0.0;
          0.0 0.0 0.8; 0.0 0.4 1.0; 0.0 0.6 0.6; 0.0 0.8 0.0];

% Get camera names
filenames = dir(fullfile(base_folder, date_folder, sequence_name, '*.cihx'));
filenames = {filenames.name};
use_cams = [7 8];
load(fullfile(project_folder, 'calibrations', date_folder, calib_name));

% Pre-allocate based on highest camera index
max_cam  = use_cams(end);
n_frames = NaN(1, max_cam);
im_size  = NaN(2, max_cam);

% Coordinate variables
xwbL = NaN(1, max_cam); ywbL = NaN(1, max_cam);
% xwbR = NaN(1, max_cam); ywbR = NaN(1, max_cam);

% Pre-allocate cell arrays and graphics objects
im       = cell(1, max_cam);
ax       = gobjects(1, max_cam);
I        = gobjects(1, max_cam);
PwbL     = gobjects(1, max_cam);
% PwbR     = gobjects(1, max_cam);
Pepi_wbL = gobjects(max_cam, max_cam);
Pepi_wbR = gobjects(max_cam, max_cam);

curr_point = 1;
last_warned = 0;

% Create Figure
FigH = figure('UserData', [], 'MenuBar', 'none', 'Resize', 'off');
set(FigH, 'WindowScrollWheelFcn', @Callback_scroll, 'WindowKeyPressFcn', @Callback_change_frame);

ii = 1;
% Setup each camera
for v = use_cams
    % Load video info
    vid(v) = quick_parse_cihx(fullfile(base_folder, date_folder, sequence_name, filenames{v}));
    n_frames(v) = vid(v).TotalFrame;
    im_size(:,v) = [vid(v).ImageHeight, vid(v).ImageWidth];
    
    im{v} = readmraw(vid(v), i_use);
    
    % Subplots
    ax(v) = subplot(1, 2, ii);
    set(ax(v), 'Parent', FigH, 'NextPlot', 'add', 'UserData', v);
    
    I(v) = imagesc2(im{v}, 'ButtonDownFcn', {@Callback_button, v}); 
    brighten(0.6);
    
    % Epipolar line pre-allocation
    for vv = use_cams
        Pepi_wbL(v,vv) = plot(NaN, NaN, 'LineWidth', 1, 'Color', col_wb(vv,:), 'ButtonDownFcn', {@Callback_button, v});
        % Pepi_wbR(v,vv) = plot(NaN, NaN, 'LineWidth', 1, 'Color', col_wb(vv,:), 'ButtonDownFcn', {@Callback_button, v});
    end
    
    % Point handles
    PwbL(v) = plot(xwbL(v), ywbL(v), '.', 'Color', col_wb(ii,:), 'MarkerSize', 20, 'ButtonDownFcn', {@Callback_button, v});
    % PwbR(v) = plot(xwbR(v), ywbR(v), '.', 'Color', col_wb(ii,:), 'MarkerSize', 20, 'ButtonDownFcn', {@Callback_button, v});
    
    axis([1 im_size(2,v) 1 im_size(1,v)]);
    set(gca, 'YDir', 'reverse')
    axis off;
    
    % Subplots take up the full figure space
    if ii == 1
        set(gca, 'Position', [0 0 0.5 1]);
    elseif ii == 2
        set(gca, 'Position', [0.5 0 0.5 1]);
    end
    ii = ii + 1;
end

set(FigH, 'Position', [100 100 1024 512], 'Pointer', 'crosshair', 'Color', 'w');

%% CREATE SEMI-TRANSPARENT TEXT ANNOTATION
total_frames = min(n_frames(use_cams));
msg_line1 = sprintf('Sequence: %s    |    Frame: %d / %d    |    Use <- / -> arrows to change frame', sequence_name, i_use, total_frames);
% msg_line2 = 'left click for left wing base, right-click to move to next point';
msg_line2 = 'left click for left wing base, close figure to save';

textboxH = annotation(FigH, 'textbox', [0, 0.90, 1, 0.10], ...
    'String', {msg_line1, msg_line2}, ...
    'Color', 'g', ...                      
    'BackgroundColor', 'k', ...            
    'FaceAlpha', 0.6, ...                  
    'EdgeColor', 'none', ...               
    'HorizontalAlignment', 'center', ...   
    'VerticalAlignment', 'middle', ...
    'Interpreter', 'none', ...
    'FontSize', 12, ...
    'FontWeight', 'bold');

%% MAIN POLLING LOOP
while isgraphics(FigH)
    
    C = get(FigH, 'UserData');
    
    if ~isempty(C)
        set(FigH, 'UserData', []); 
        
        curr_cam = C(1);
        but = C(2);
        x = C(3);
        y = C(4);
        
        % ==========================================
        % KEYBOARD ARROWS: CHANGE FRAME
        % ==========================================
        if curr_cam == -1
            direction = but; % -1 for left arrow, 1 for right arrow
            new_frame = i_use + direction;
            
            % Ensure we don't go out of bounds for the video
            if new_frame >= 1 && new_frame <= total_frames
                i_use = new_frame;
                
                % Read new frames and update the image objects
                for v = use_cams
                    im{v} = readmraw(vid(v), i_use);
                    set(I(v), 'CData', im{v}); % Only changes the image, leaves plots intact
                end
                
                % Update the top annotation line with the new frame number
                msg_line1 = sprintf('Sequence: %s    |    Frame: %d / %d    |    Use <- / -> arrows to change frame', sequence_name, i_use, total_frames);
                set(textboxH, 'String', {msg_line1, msg_line2});
            end
            
        % ==========================================
        % MOUSE LEFT CLICK: PLACE POINTS
        % ==========================================
        elseif but == 1 
            if curr_point == 1
                xwbL(curr_cam) = x;
                ywbL(curr_cam) = y;
                set(PwbL(curr_cam), 'XData', x, 'YData', y);
                for vv = use_cams
                    if vv ~= curr_cam
                        [X1, Y1] = draw_epipolar_emg(vv, curr_cam, x, y, calib_data);
                        set(Pepi_wbL(vv, curr_cam), 'XData', X1, 'YData', Y1);
                    end
                end
                last_warned = 0;
                
            % elseif curr_point == 2
            %     xwbR(curr_cam) = x;
            %     ywbR(curr_cam) = y;
            %     set(PwbR(curr_cam), 'XData', x, 'YData', y);
            %     for vv = use_cams
            %         if vv ~= curr_cam
            %             [X1, Y1] = draw_epipolar_emg(vv, curr_cam, x, y, calib_data);
            %             set(Pepi_wbR(vv, curr_cam), 'XData', X1, 'YData', Y1);
            %         end
            %     end
            %     last_warned = 0;
            end
            
        % % ==========================================
        % % MOUSE RIGHT CLICK: NEXT STEP
        % % ==========================================
        % elseif but == 3
        %     if curr_point == 1
        %         if sum(~isnan(xwbL)) > 1
        %             curr_point = 2;
        %             % Update the annotation text for step 2
        %             msg_line2 = 'left click for right wing base, close figure to save';
        %             set(textboxH, 'String', {msg_line1, msg_line2});
        % 
        %             delete(Pepi_wbL(isgraphics(Pepi_wbL))); 
        %             last_warned = 0;
        %         elseif last_warned == 0
        %             warning('You need to click in at least two camera views before moving on.');
        %             last_warned = 1;
        %         end
        % 
        %     % Note: curr_point == 2 right-click logic removed. Figure must be closed manually.
        %     end
        end
    end
    
    pause(0.02); 
end

%% POST-CLOSURE SAVE LOGIC
if ~exist(fullfile('single_wing_init_points',date_folder), 'dir')
    mkdir(fullfile('single_wing_init_points',date_folder))
end

% if sum(~isnan(xwbL)) > 1 && sum(~isnan(xwbR)) > 1
if sum(~isnan(xwbL)) > 1
    save(fullfile('single_wing_init_points',date_folder,[sequence_name '_init_click.mat']),'xwbL','ywbL')
    disp(['Successfully done' sequence_name]);
else
    disp('Not saved');
end