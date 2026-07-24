function [yhat, yvel, yacc, tol]=filter_data(varargin)
% save temp
% clear
% close all
% load temp
% nargin=3;

% FILTER_DATA quintic spline using tolerance calculed from predefined
% cut-off frequency.
%
%   YHAT=FILTER_DATA(Y,Wn,F), for a vector Y returns the vector YHAT
%   containing the smoothed values of Y. Smoothing is performed using the
%   SPAPS function to fit a quintic spline to the data in Y using a
%   tolerance calculated from a butterworth filter. The data is padded at
%   the start and end points using reflection around the boundary point to
%   reduce errors at the start and end of the data series.
%
%   Wn and F are positive scalers, with Wn being the desired cut-off
%   frequency and F being the sampling frequency. The tolerance factor for
%   SPAPS is the 1.1*sum((R).^2), where R are the residuals after applying
%   a 3rd order butterworth filter with normalized cut-off frequency
%   Wn/(0.5*F).
%
%   If NaNs are present in the data, then these are estimated through linear
%   interpolation and used in the butterworth filter, however the
%   datapoints are excluded from the calculations of the tolerance for the
%   quintic spine.
%
%   [YHAT YVEL]=FILTER_DATA(Y,Wn,F), returns YVEL, a vector containing the
%   first derivative of Y, calculated using the FNVAL command on the B-form
%   spline calculated using SPAPS.
%
%   [YHAT YVEL YACC]=FILTER_DATA(Y,Wn,F), returns YACC, a vector containing
%   the second derivative of Y, calculated using the FNVAL command on the
%   B-form spline calculated using SPAPS.
%
%   [YHAT YVEL YACC TOL]=FILTER_DATA(Y,Wn,F), returns TOL, a scalr containing
%   the tolerance value used by SPAPS, which should approximate the sum of
%   the square of the residuals of the filtered data
%
%   [YHAT...]=FILTER_DATA(...,X,XI), uses the vectors X and XI to
%   interpolate YHAT to the specified locations in XI from X
%
%   See also SPAPS, FILTFILT, BUTTER, FNVAL.

% clear
% close all
% load temp
% nargin=3;

if nargin<3
    error('Error - three inputs are required')
end

y=varargin{1};
Wn=varargin{2};
F=varargin{3};

% y=y(1:200);

if ~any(size(y)==1)
    error('Error - input Y must be a vector')
end

if numel(Wn)~=1
    error('Error - filter frequency must be scaler')
end

if numel(F)~=1
    error('Error - sampling frequency must be a scalar')
end

if Wn>=0.5*F
    error('Error - filter frequency must be less thatn the Nyquist frequency')
end

if nargin==5
    x=varargin{4};
    xi=varargin{5};
else
    x=1:length(y);
    xi=x;
end

x=x(:);
y=y(:);

n1=find(~isnan(y),1);
n2=find(~isnan(y),1,'last');

if any(isnan(y))

    xx=x(n1:n2);
    yy=y(n1:n2);
    
    xi2=xx;
    n=isnan(yy);
    
    if sum(n)==0
        yi=yy;
    else
        xx(n)=[];
        yy(n)=[];

        yi=interp1(xx,yy,xi2,'linear');
    end
    yi=yi(:);
else
    yi=y;
    yy=y;
    n=[];
end

Nq=0.5*F;
[bbb aaa]=butter(3,Wn/Nq);
yf=filtfilt(bbb,aaa,yi);

yf(n)=[];

res=(yf-yy).^2;
tol=1.1*nanmean(res)*length(y);

% n1=find(~isnan(y),1);
% n2=find(~isnan(y),1,'last');

% y_pad1=flipdim(2*y(n1)-y(n1+1:n1+10),1);
% x_pad1=(n1-10:n1-1)'+x(1)-1;

% y_pad2=flipdim(2*y(n2)-y(n2-10:n2-1),1);
% x_pad2=(1:10)'+x(end);

% xx=[x_pad1;x(n1:n2);x_pad2];
% yy=[y_pad1;y(n1:n2);y_pad2];

xx=x;
yy=y;
% disp(tol)
w=ones(1,length(xx));
% for some long sequences, need to split it into two parts

done=0;

% while done==0
try
    sp = spaps(xx,yy,tol,w,3);

    yfcheck=fnval(sp,xx);
    rescheck=(yfcheck-yy).^2;
    tolcheck=1.1*nanmean(rescheck)*length(y);

    if tolcheck>10*tol
        error
    end

    yhat=fnval(sp,xi);
    spv=fnder(sp);
    yvel = fnval(spv,xi)*F;
    spa=fnder(spv);
    yacc = fnval(spa,xi)*F^2;
    done=1;

catch
    % 
    num_sections=ceil(length(yy)/500);
    sections=round(linspace(1,length(yy),num_sections+1));

    transition_length=round(diff(sections(1:2)));
    transition_function=[zeros(1,100) 0.5*sin(linspace(-pi/2,pi/2,transition_length-200))+0.5 ones(1,100)];
     
    yhat_temp=NaN(num_sections,length(yy));
    yvel_temp=NaN(num_sections,length(yy));
    yacc_temp=NaN(num_sections,length(yy));

    mean_weights=zeros(num_sections,length(yy));

    for i=1:num_sections

        if i~=num_sections
            section_curr=sections(i):sections(i+1)+transition_length;
        else
            section_curr=sections(i):sections(i+1);
        end

        section_curr(section_curr>length(xx))=[];

        xx_temp=xx(section_curr);
        yy_temp=yy(section_curr);

        % yi_temp=yi(section_curr);
        % yf_temp=filtfilt(bbb,aaa,yi_temp);
        % yf_temp=yf(section_curr);
%         yf(n)=[];
        
        % res=(yf_temp-yy_temp).^2;
        
        tol_temp=1.1*nanmean(res(section_curr))*length(yy_temp);

%         tol_temp=1.1*nanmean(res)*length(xx_temp);
        w_temp=ones(1,length(xx_temp));
        
        xi_temp=xi(section_curr);
        
        sp = spaps(xx_temp,yy_temp,tol_temp,w_temp,3);
        yhat_temp(i,section_curr)=fnval(sp,xi_temp);
        spv=fnder(sp);
        yvel_temp(i,section_curr) = fnval(spv,xi_temp)*F;
        spa=fnder(spv);
        yacc_temp(i,section_curr) = fnval(spa,xi_temp)*F^2;
        
        if i==1
            mean_weights(i,1)=1;
        end

        mean_weights(i,sections(i)+1:sections(i+1))=1;
            
        if i~=num_sections
            mean_weights(i,sections(i+1)+1:sections(i+1)+transition_length)=1-transition_function;
        end
        
        if i~=1
            
            mean_weights(i,sections(i)+1:sections(i)+transition_length)=transition_function;

        end
        
    end

    mean_weights=mean_weights(:,1:size(yhat_temp,2));
  
    % plot(yhat_temp','.-')
    yhat=nansum(yhat_temp.*mean_weights);
    yvel=nansum(yvel_temp.*mean_weights);
    yacc=nansum(yacc_temp.*mean_weights);

end

if exist('xi2')
    yhat(1:xi2(1)-1)=NaN;
    yvel(1:xi2(1)-1)=NaN;
    yacc(1:xi2(1)-1)=NaN;

    if xi2(end)~=length(yhat)
        yhat(xi2(end)+1:end)=NaN;
        yvel(xi2(end)+1:end)=NaN;
        yacc(xi2(end)+1:end)=NaN;
    end
end


% if size(y,2)==1
%     yhat=yhat';
%     yvel=yvel';
%     yacc=yacc';
% end
% plot(y,'.k'); hold on
% plot(yhat,'r','linewidth',2)
