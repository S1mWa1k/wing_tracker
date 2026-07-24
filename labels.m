function varargout=labels(x,y,z);

if nargin<1
    h(1)=xlabel('x');
    h(2)=ylabel('y');
    h(3)=zlabel('z');
elseif nargin<2
    h(1)=xlabel(x);
elseif nargin<3
    h(1)=xlabel(x);
    h(2)=ylabel(y);
elseif nargin<4
    h(1)=xlabel(x);
    h(2)=ylabel(y);
    h(3)=zlabel(z);
end

if nargout>0
    varargout{1}=h;
end
    