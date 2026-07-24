function [X2,Y2,Z2] = Rz2(varargin)

% Ry2: Rotate 3D Cartesian coordinates around the Z axis
%
% Useage:   [X2,Y2,Z2] = Rz2(X,Y,Z,gamma)
% 
% 'X,Y,Z' - scalers or matrices of equal size
% 
% 'gamma'  - angle of rotation about the Y axis in degrees. If beta is a
% scalar, then all elements of [X,Y,Z] are rotated by beta. Otherwise,
% size(beta) must equal size(X).
%
% See also Rx2 Ry2
%

% Licence:  GNU GPL, no express or implied warranties
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

X=varargin{1};
Y=varargin{2};

if nargin==3
    Z=zeros(size(X));
    gamma=varargin{3};
elseif nargin==4
    Z=varargin{3};
    gamma=varargin{4};
else
   error('must have three or four inputs') 
end

if numel(gamma)==1   
    
    [yc, ~]=size(X);
    
    XYZ=[X(:) Y(:) Z(:)]';
    
    Rz = [ cosd(gamma) -sind(gamma) 0;  sind(gamma) cosd(gamma) 0;  0 0 1 ];

    XYZ = Rz * XYZ;
    
    X2=reshape(XYZ(1,:),yc,[]);
    Y2=reshape(XYZ(2,:),yc,[]);
    Z2=reshape(XYZ(3,:),yc,[]);

elseif size(gamma)==size(X)

    X2=NaN(size(X));
    Y2=NaN(size(Y));
    Z2=NaN(size(Z));
    
    for i=1:numel(gamma)
            
        XYZ=[X(i) Y(i) Z(i)]';

        Rz = [ cosd(gamma(i)) -sind(gamma(i)) 0;  sind(gamma(i)) cosd(gamma(i)) 0;  0 0 1 ];

        XYZ = Rz * XYZ;
        
        X2(i)=XYZ(1);
        Y2(i)=XYZ(2);
        Z2(i)=XYZ(3);
        
    end
else
    error('gamma must be a scalar or size(gamma) must equal size(X)')
end