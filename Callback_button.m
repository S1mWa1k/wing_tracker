function Callback_button(ObjectH, EventData, v)

% get the figure that was clicked on
FigH = ancestor(ObjectH, 'figure');

% gets the position of the mouse cursor when it clicked
pt = get(gca, 'CurrentPoint');

% get which mouse button was used
mouse_button=get(gcf,'SelectionType');

% x & y coordinates
xp=pt(1,1);
yp=pt(1,2);

% convert mouse buttons to numerical form
% 'normal' = left mouse button
% 'alt' = right mouse button
% 'extend' = clicking middle button (or scroll wheel)
if strcmp(mouse_button,'normal')
    button=1;
elseif strcmp(mouse_button,'alt')
    button=3;
elseif strcmp(mouse_button,'extend')
    button=2;
else
    button=NaN;
end

% set userdata
UserData = [v button xp yp];

% update user data of figure
set(FigH, 'Userdata', UserData);