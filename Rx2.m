function [X2,Y2,Z2] = Rx2(varargin)

% Ry2: Rotate 3D Cartesian coordinates around the Y axis
%
% Useage:   [X2,Y2,Z2] = Rx2(X,Y,Z,alpha)
% 
% 'X,Y,Z' - scalers or matrices of equal size
% 
% 'alpha'  - angle of rotation about the Y axis in degrees. If alpha is a
% scalar, then all elements of [X,Y,Z] are rotated by alpha. Otherwise,
% size(alpha) must equal size(X).
%
% See also Rx2 Rz2
%

% Licence:  GNU GPL, no express or implied warranties
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

X=varargin{1};
Y=varargin{2};
Z=varargin{3};
alpha=varargin{4};

if numel(alpha)==1   
    
    [yc, ~]=size(X);
    
    XYZ=[X(:) Y(:) Z(:)]';
    
    Rx = [1 0 0; 0 cosd(alpha) -sind(alpha); 0 sind(alpha) cosd(alpha)];

    XYZ = Rx * XYZ;
    
    X2=reshape(XYZ(1,:),yc,[]);
    Y2=reshape(XYZ(2,:),yc,[]);
    Z2=reshape(XYZ(3,:),yc,[]);

elseif size(alpha)==size(X)

    X2=NaN(size(X));
    Y2=NaN(size(Y));
    Z2=NaN(size(Z));
    
    for i=1:numel(alpha)
            
        XYZ=[X(i) Y(i) Z(i)]';

        Rx = [1 0 0; 0 cosd(alpha(i)) -sind(alpha(i)); 0 sind(alpha(i)) cosd(alpha(i))];

        XYZ = Rx * XYZ;
        
        X2(i)=XYZ(1);
        Y2(i)=XYZ(2);
        Z2(i)=XYZ(3);
        
    end
else
    error('alpha must be a scalar or size(alpha) must equal size(X)')
end