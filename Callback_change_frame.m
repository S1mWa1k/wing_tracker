function Callback_change_frame(src, event)
    % Listen for left/right arrow keys and send a signal to the main loop's UserData
    % Format: [-1 (Keyboard ID), Direction (-1 or 1), 0, 0]
    
    if strcmp(event.Key, 'leftarrow')
        set(src, 'UserData', [-1, -1, 0, 0]);
        
    elseif strcmp(event.Key, 'rightarrow')
        set(src, 'UserData', [-1, 1, 0, 0]);
        
    end
end