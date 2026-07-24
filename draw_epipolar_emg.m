function [X1, Y1]=draw_epipolar_emg(target, ref,x_ref,y_ref,calib_data)

% This version takes into account lens distortion
cam1=target;
cam2=ref;

% --- EXTRACT CALIBRATION DATA ---
fc=calib_data.fc;
cc=calib_data.cc;
kc = calib_data.kc;
T_cams=calib_data.T_cams;
om_cams=calib_data.om_cams;

om_cams=om_cams*-1;

% --- CAMERA 2 (REFERENCE) PARAMETERS ---
fc2=fc(:,cam2);
cc2=cc(:,cam2);
kc2 = kc(:,cam2);
T_cam2=T_cams(:,cam2);
om_cam2=om_cams(:,cam2);
T_cam2=rodrigues(om_cam2)*T_cam2;
R_cam2=rodrigues(om_cam2);
KK2=[fc2(1) 0 cc2(1); 0 fc2(2) cc2(2) ; 0 0 1];

fc1=fc(:,cam1);
cc1=cc(:,cam1);
kc1 = kc(:,cam1);
T_cam1 = T_cams(:,cam1);
om_cam1 = om_cams(:,cam1);
T_cam1 = rodrigues(om_cam1) * T_cam1;
R_cam1 = rodrigues(om_cam1);
KK1 = [fc1(1) 0 cc1(1); 0 fc1(2) cc1(2) ; 0 0 1];

% --- 1. UNDISTORT THE REFERENCE POINT (CAMERA 2) ---
xd = (x_ref - cc2(1)) / fc2(1);
yd = (y_ref - cc2(2)) / fc2(2);

xu = xd;
yu = yd;
for iter = 1:5
    r2 = xu.^2 + yu.^2;
    dist_factor = 1 + kc2(1)*r2 + kc2(2)*(r2.^2);
    xu = xd ./ dist_factor;
    yu = yd ./ dist_factor;
end

% True Pinhole Coordinate
x_ref_u = xu * fc2(1) + cc2(1);
y_ref_u = yu * fc2(2) + cc2(2);

% --- 2. COMPUTE FUNDAMENTAL MATRIX ---
R_cam24=R_cam1*R_cam2';
T_cam24=-R_cam1*R_cam2'*T_cam2+T_cam1;

t = [   0  -T_cam24(3)  T_cam24(2); % -- changes to 3x3 matrix --
    T_cam24(3)   0   -T_cam24(1);
    -T_cam24(2)  T_cam24(1)   0 ];

% F24=inv(KK1')*t*R_cam24*inv(KK2); % -- compute fundamental matrix --
% OPTIMIZED: Replaced explicit inv() with matrix division (\ and /)
% Old: F24 = inv(KK1') * t * R_cam24 * inv(KK2);
F24 = (KK1' \ (t * R_cam24)) / KK2;

X_left=[x_ref_u; y_ref_u; 1];

l_right=F24*X_left;

a=l_right(1);
b=l_right(2);
c=l_right(3);

% --- 4. ADAPTIVE SAMPLING FOR EPIPOLAR LINE ---
% We check if the line is more vertical or horizontal to prevent 
% coordinates from exploding to infinity when dividing by near-zero.
if abs(a) > abs(b)
    % Line is mostly vertical: Sample Y to find X
    % We sample tightly around the image height (approx 2 * cc_y)
    Y_ideal = linspace(-500, 2*cc1(2) + 500, 500);
    X_ideal = (b * Y_ideal + c) / -a;
else
    % Line is mostly horizontal: Sample X to find Y
    % We sample tightly around the image width (approx 2 * cc_x)
    X_ideal = linspace(-500, 2*cc1(1) + 500, 500);
    Y_ideal = (a * X_ideal + c) / -b;
end

% --- 5. REDISTORT POINTS INTO TARGET IMAGE ---
xn = (X_ideal - cc1(1)) / fc1(1);
yn = (Y_ideal - cc1(2)) / fc1(2);
r2 = xn.^2 + yn.^2;

% --- THE MATHEMATICAL FOLD FIX ---
% Calculate the exact derivative of the distortion curve.
% If it drops below 0, the lens model is folding backwards.
poly_diff = 1 + 3*kc1(1)*r2 + 5*kc1(2)*(r2.^2);

% Keep only the points where the polynomial is stable (leaving a 10% safety margin)
valid_idx = poly_diff > 0.1; 

xn = xn(valid_idx);
yn = yn(valid_idx);
r2 = r2(valid_idx);

% Apply Forward Radial Distortion to the safe points
dist_factor = 1 + kc1(1)*r2 + kc1(2)*(r2.^2);

xd = xn .* dist_factor;
yd = yn .* dist_factor;

% Scale back to pixels
X1 = xd * fc1(1) + cc1(1);
Y1 = yd * fc1(2) + cc1(2);