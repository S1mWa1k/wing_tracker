function [dstroke2, ustroke2]=find_wingbeats_function(thv,wb_freq_est,rec_freq)

% check that thv doesn't consist just of NaNs
if min(sum(~isnan(thv)))>1

    % find where angular velocity is positive
    A=find(thv>0);

    % take differences
    A2=diff(A);
    
    % find where differences are greater than one, should be where there is a new wingbeat or gap
    dstroke=A(A2>1);
    
%     plot(thv,'.-'); hold on
%     plot(dstroke,thv(dstroke),'.r','markersize',12),
%     xlim([1 200])
%     return
    
    % add last frame if it's not already there so that last wingbeat is captured
    if A(end)~=size(thv,1)
        dstroke=[dstroke; A(end)];
    end    

    % remove points where the next one is a NaN, should remove gaps
    d=isnan(thv(dstroke(1:end-1)+1));
    dstroke(d==1)=[];

%     plot(dstroke,thv(dstroke),'.g','markersize',12),
%     return
    
    % repeat steps but for upstroke
    A=find(thv<0);

    A2=diff(A);
    ustroke=A(A2>1);

    if A(end)~=size(thv,1)
        ustroke=[ustroke; A(end)];
    end

    u=isnan(thv(ustroke(1:end-1)+1));
    ustroke(u==1)=[];

    % counter
    j=1;

    % for each upstroke check that there is an downstroke on either side
    for i=1:length(ustroke)

        % find downstrokes before upstroke
        a=ustroke(i)-dstroke;
        a(a<0)=inf;
        
        % find nearest downstroke preceding upstroke and check that it's
        % less than one wingbeat before
        aa=find(a<(rec_freq/wb_freq_est),1);

        % now repeat but find downstrokes after upstroke
        b=dstroke-ustroke(i);
        b(b<0)=inf;
        bb=find(b<(rec_freq/wb_freq_est),1);

        % checks to make sure suitable downstrokes before and after the upstroke were found
        if ~isempty(aa) && ~isempty(bb) && a(aa)~=inf && ~any(isnan(thv(dstroke(aa):dstroke(bb)))) && thv(dstroke(bb)+1)<0
            
            dstroke2(j,:)=dstroke([aa bb]);
            ustroke2(j,:)=ustroke(i);
            j=j+1;
        end
    end
    
    % get number of frames of each wingbeat and take median
    A=diff(dstroke2,1,2);
    Amean=nanmedian(A);
    
    % remove any where wingbeat duration is too high or low
    dstroke2(max([A<0.8*Amean A>1.25*Amean],[],2),:)=[];
    ustroke2(max([A<0.8*Amean A>1.25*Amean],[],2),:)=[];
    
end