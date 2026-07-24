function [X,Y,Z,resnorm,residual_all,coords,X0,Y0,Z0,x_rep,y_rep]=calc3D(xx,yy,calib_data)

% NOTE, now includes lens distortion (two radial terms)

% INPUTS
% xx, yy are the 'x' and 'y' coordinates, these must be in a nxm matrix
% where n is the number of cameras, and m is the number of datapoints
%
% calib_data is a calibration data file
%
% num_cam is the number of cameras used
%
% OUTPUTS
% X, Y, Z, are the 3D coordinates, after rotating the data according the
% orientation and position of the first grid, which is normally aligned with gravity
%
% resnorm is the sum of squares of the residuals
%
% residual_all are the residuals
%
% coords are just the same as the input but reordered into a single
% parameter
%
% X0, Y0, Z0, are the 3D coordinates, but in the coordinate system of the
% first camera
%
% x_rep and y_rep are the reprojected coordinates

num_cam=size(xx,1);
coords=NaN(2*num_cam,size(xx,2));

fc=calib_data.fc;
cc=calib_data.cc;
kc = calib_data.kc;
T_cams=calib_data.T_cams;
om_cams=calib_data.om_cams;

% --- STEP 1: ASSEMBLE RAW COORDS & UNDISTORT ---
coords_u = NaN(2*num_cam, size(xx,2)); % Preallocate for undistorted coordinates

for c = 1:num_cam
    % Store raw, distorted coordinates for residual calculations later
    coords(2*c-1, :) = xx(c,:);
    coords(2*c, :)   = yy(c,:);
    
    % Extract camera-specific parameters
    c_x = fc(1,c);
    c_y = fc(2,c);
    k1  = kc(1,c);
    k2  = kc(2,c);
    
    % 1. Convert to Normalized Coordinates
    xd = (xx(c,:) - cc(1,c)) / c_x;
    yd = (yy(c,:) - cc(2,c)) / c_y;
    
    % 2. Iterative Undistortion (Standard Bouguet Method)
    xu = xd;
    yu = yd;
    for iter = 1:5
        r2 = xu.^2 + yu.^2;
        dist_factor = 1 + k1*r2 + k2*(r2.^2);
        xu = xd ./ dist_factor;
        yu = yd ./ dist_factor;
    end
    
    % 3. Convert back to True Pinhole Pixel Coordinates
    coords_u(2*c-1, :) = xu * c_x + cc(1,c);
    coords_u(2*c, :)   = yu * c_y + cc(2,c);
end

% Use the UNDISTORTED coordinates for the DLT triangulation
x = coords_u;

% --- STEP 2: BUILD PROJECTION MATRICES ---
for c = 1:num_cam
    K{c} = [fc(1,c) 0 cc(1,c);
            0 fc(2,c) cc(2,c);
            0 0 1];
    R{c} = rodrigues(om_cams(:,c))';
    T_cams2(:,c) = R{c}*T_cams(:,c);
    P{c} = K{c}*[R{c} T_cams2(:,c)];
end

% --- STEP 3: DLT TRIANGULATION ---
XX=zeros(3,size(x,2));
for i=1:size(x,2)
    
    for c=1:num_cam
        
        A(2*c-1,:)=x(2*c-1,i)*P{c}(3,:)-P{c}(1,:);
        A(2*c,:)=x(2*c,i)*P{c}(3,:)-P{c}(2,:);
        
    end
       
   A(isnan(A(:,1)),:)=[];
   
   if size(A,1)>2
       [~, ~, v]=svd(A);
       XX(:,i)=v(1:3,end)./-v(4,end);
   else
       XX(:,i)=NaN;
   end
end
XX(XX==0)=NaN;

% --- STEP 4: REPROJECTION AND REDISTORTION ---
xr = NaN(2*num_cam, size(XX,2));

for c=1:num_cam
    c_x=fc(1,c);
    c_y=fc(2,c);                        
    k1  = kc(1,c);
    k2  = kc(2,c);

    T=repmat(T_cams(:,c),1,size(XX,2));
    R=rodrigues(om_cams(:,c))'; 

    % 1. Project 3D points to normalized camera coordinates
    Zc = R(3,:)*(T-XX);
    xn = (R(1,:)*(T-XX)) ./ Zc;
    yn = (R(2,:)*(T-XX)) ./ Zc;

    % 2. Apply Forward Radial Distortion
    r2 = xn.^2 + yn.^2;
    dist_factor = 1 + k1*r2 + k2*(r2.^2);

    xd = xn .* dist_factor;
    yd = yn .* dist_factor;

    % 3. Convert normalized distorted coordinates to pixel coordinates
    xr(2*c-1,:) = c_x * xd + cc(1,c);
    xr(2*c,:)   = c_y * yd + cc(2,c);
    
end

% --- STEP 5: CALCULATE RESIDUALS ---
x_rep = xr(1:2:end,:);
y_rep = xr(2:2:end,:);

% Compare redistorted reprojections against the RAW, distorted input coords
residual_all = xr - coords;
resnorm = nansum(nansum(residual_all.^2));

% --- STEP 6: ALIGN WITH WORLD GRID ---
if isfield(calib_data,'om_grids')

    R2=rodrigues(calib_data.om_grids(:,1));
    T2=calib_data.T_grids(:,1);
    rotate=0;
else
    R2=rodrigues(calib_data.om_bar(:,1));
    T2=calib_data.T_bar(:,1);
    rotate=1;
end

R1=rodrigues([0;0;0]);
T1=[0;0;0];

R21=R1*R2';
T21=-R1*R2'*T2+T1;

XX2=R21*XX+repmat(T21,1,size(XX,2));

X=XX2(1,:);
Y=XX2(2,:);
Z=XX2(3,:);

if rotate==1
   [X,Y,Z]= Ry2(X,Y,Z,90);
end

X0=XX(1,:);
Y0=XX(2,:);
Z0=XX(3,:);
