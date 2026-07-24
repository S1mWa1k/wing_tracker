function [im_x, im_y] = reproject_points(varargin)
%PROJECT: project a 3D point into an image

% Note, this now takes into acount lens distorion

calib_data=varargin{1};
camera=varargin{2};
XWP=varargin{3};

if size(XWP,1)~=3
    XWP=XWP';
end

% Optional argument to untransform relative to first calibration grid
if nargin==4
    if varargin{4}==1

        R2=rodrigues(calib_data.om_grids(:,1));
        T2=calib_data.T_grids(:,1);

        XWP=R2*XWP+repmat(T2,1,size(XWP,2));
      
    end
end

c_x=calib_data.fc(1,camera);
c_y=calib_data.fc(2,camera);
cc_x = calib_data.cc(1, camera);
cc_y = calib_data.cc(2, camera);
k1   = calib_data.kc(1, camera);
k2   = calib_data.kc(2, camera);

R=rodrigues(calib_data.om_cams(:,camera))'; 
T = calib_data.T_cams(:, camera);

% --- 1. TRANSLATE TO CAMERA CENTER ---
% Vectorized subtraction (T - XWP)
dX = T - XWP;

% --- 2. ROTATE INTO CAMERA FRAME ---
Xc = R(1,:) * dX;
Yc = R(2,:) * dX;
Zc = R(3,:) * dX;

% --- 3. NORMALIZE COORDINATES ---
% Project rays onto the Z=1 plane
xn = Xc ./ Zc;
yn = Yc ./ Zc;

% --- 4. APPLY RADIAL DISTORTION ---
r2 = xn.^2 + yn.^2;
dist_factor = 1 + k1.*r2 + k2.*(r2.^2);

xd = xn .* dist_factor;
yd = yn .* dist_factor;

% --- 5. CONVERT TO PIXELS ---
im_x = c_x * xd + cc_x;
im_y = c_y * yd + cc_y;
