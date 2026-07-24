function [X2,Y2,Z2] = Ry2(varargin)

% Ry2: Rotate 3D Cartesian coordinates around the Y axis
%
% Useage:   [X2,Y2,Z2] = Ry2(X,Y,Z,beta)
% 
% 'X,Y,Z' - scalers or matrices of equal size
% 
% 'beta'  - angle of rotation about the Y axis in degrees. If beta is a
% scalar, then all elements of [X,Y,Z] are rotated by beta. Otherwise,
% size(beta) must equal size(X).
%
% See also Rx2 Rz2
%

% Licence:  GNU GPL, no express or implied warranties
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

X=varargin{1};
Y=varargin{2};
Z=varargin{3};
beta=varargin{4};

if numel(beta)==1   
    
    [yc, ~]=size(X);
    
    XYZ=[X(:) Y(:) Z(:)]';
    
    Ry = [ cosd(beta) 0 sind(beta); 0 1 0; -sind(beta) 0 cosd(beta)];

    XYZ = Ry * XYZ;
    
    X2=reshape(XYZ(1,:),yc,[]);
    Y2=reshape(XYZ(2,:),yc,[]);
    Z2=reshape(XYZ(3,:),yc,[]);

elseif size(beta)==size(X)

    X2=NaN(size(X));
    Y2=NaN(size(Y));
    Z2=NaN(size(Z));
    
    for i=1:numel(beta)
            
        XYZ=[X(i) Y(i) Z(i)]';

        Ry = [cosd(beta(i)) 0 sind(beta(i)); 0 1 0; -sind(beta(i)) 0 cosd(beta(i))];

        XYZ = Ry * XYZ;
        
        X2(i)=XYZ(1);
        Y2(i)=XYZ(2);
        Z2(i)=XYZ(3);
        
    end
else
    error('beta must be a scalar or size(beta) must equal size(X)')
end