function Callback_scroll(ObjectH, EventData, Index)

% Allows mouse wheel to be used to zoom in and out of image.
% Have to first work out which is the current axis

% measures mouse wheel negative for scroll up and positive for scroll down
count = EventData.VerticalScrollCount;

% find all axes
allaxes = findall(ObjectH, 'type', 'axes');

% get current pointer locatoin
pt=get(0, 'PointerLocation');

% get position of the figure
fig_pos=get(gcbf,'position');

% normalised figure coordinates
ptx=(pt(1)-fig_pos(1))/fig_pos(3);
pty=(pt(2)-fig_pos(2))/fig_pos(4);

% create empty variable to avoid potential errors if very near edge of
% image
curr_axis=[];

% based on normalised coordinates can work out with quarter of figure is
% the current one. Then work out the normalsed coordinates for that image
if ptx<0.5 && pty>=0.48 && pty<=0.96
    curr_axis=1;
    
    xr=ptx.*2;
    yr=1-(pty-0.5).*2;
    
elseif ptx>=0.5 && pty>=0.48 && pty<=0.96
    curr_axis=2;
    
    xr=(ptx-0.5).*2;
    yr=1-(pty-0.5).*2;
    
elseif ptx<0.5 && pty<0.48
    curr_axis=3;
    
    xr=ptx.*2;
    yr=1-pty.*2;
    
elseif ptx>=0.5 && pty<0.48
    curr_axis=4;
    
    xr=(ptx-0.5).*2;
    yr=1-pty.*2;
    
end

% get list of axis numbers from userdata
for i=1:length(allaxes)

    ax_list(i)=allaxes(i).UserData;
    
end

% if there is a current axis then continue
if ~isempty(curr_axis)
    
    % find which is the current axis
    ax_list_curr=ax_list==curr_axis;

    % make sure it's the active axis
    axes(allaxes(ax_list_curr));

    % get plots in axis. The image will be the last one
    g=get(gca,'children');
    g=g(end);

    % get size of image
    xl0=get(g,'XData');
    yl0=get(g,'YData');
    imsize(1)=max(yl0(:))-min(yl0(:));
    imsize(2)=max(xl0(:))-min(xl0(:));

    % get current axis limits
    xl=get(gca,'xlim');
    yl=get(gca,'ylim');

    % get coordinates relative to current axis limits
    ptxx=xr*(diff(xl))+xl(1);
    ptyy=yr*(diff(yl))+yl(1);

    % if it was a scroll up then descrease axis limits otherwise increase
    if count<-0
        xld=0.8*(xl(2)-xl(1));
    else
        xld=1.2*(xl(2)-xl(1));
    end

    % make sure limits are more than one pixel wide
    if xld<1
        xld=1;
    end

    % calculate y axis limits based on image aspect ratio
    yld=xld*imsize(1)/imsize(2);

    % disp([ptxx ptyy])
    % disp([xr yr])

    % calculate what new axis limits
    xl2=[ptxx-xld*xr ptxx+xld*(1-xr)];
    yl2=[ptyy-yld*yr ptyy+yld*(1-yr)];

    % check neither x or y limits are large than image size
    if xl2(2)-xl2(1)>imsize(2)
        xl2=[1 imsize(2)];
    end

    if yl2(2)-yl2(1)>imsize(1)
        yl2=[1 imsize(1)];
    end

    % disp([xl2 yl2])
    
    % finally set axes and make sure aspect ratio is still 1:1
    set(gca,'xlim',xl2,'ylim',yl2,'DataAspectRatio',[1 1 1]);
end
