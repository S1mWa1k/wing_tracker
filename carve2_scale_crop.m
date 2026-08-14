function [voxels2,index2,x_cropped,y_cropped,x_rep,y_rep,x_keep,y_keep] = carve2_scale_crop(voxels, camera, Silhouette, calib_data, index, scale, xcrop_adj, ycrop_adj)
% save temp
% clear 
% load temp
%CARVE: remove voxels that are not in the silhouette
%
%   VOXELS = CARVE(VOXELS,CAMERA) carves away voxels that are not inside
%   the silhouette contained in CAMERA. The resulting voxel array is
%   returned.
%
%   [VOXELS,KEEP] = CARVE(VOXELS,CAMERA) also returns the indices of the
%   voxels that were retained.
%
%   Example:
%   >> camera = loadcameradata(1);
%   >> camera.Silhouette = getsilhouette( camera.Image );
%   >> voxels = carve( makevoxels(50), camera );
%   >> showscene( camera, voxels );
%
%   See also: LOADCAMERADATA
%             MAKEVOXELS
%             CARVEALL

%   Copyright 2005-2009 The MathWorks, Inc.
%   $Revision: 1.0 $    $Date: 2006/06/30 00:00:00 $

if nargin<=5
    scale=1;
end

if nargin<=6
    xcrop_adj=0;
    ycrop_adj=0;
end

if isempty(Silhouette) % allow empty arrays to be used for frames to skip

    index2=index;
    voxels2=voxels;
else
    % Project into image
    [x_rep, y_rep] = reproject_points(calib_data, camera, voxels);
    
    if scale~=1 || xcrop_adj~=0 || ycrop_adj~=0
        x_cropped=x_rep.*scale-xcrop_adj;
        y_cropped=y_rep.*scale-ycrop_adj;
    else
        x_cropped=x_rep;
        y_cropped=y_rep;
    end
    % Clear any that are out of the image
    [h,w] = size(Silhouette);
    
    [Sily, Silx]=ind2sub([h,w],find(Silhouette==1));
    
    if ~isempty(Silx)
        keep = (x_cropped>=min(Silx)-0.5) & (x_cropped<=max(Silx)+0.5) & (y_cropped>=min(Sily)-0.5) & (y_cropped<=max(Sily)+0.5);
    else
        keep=[];
    end
    
    % keep = (x>=1) & (x<=w) & (y>=1) & (y<=h);
    x_keep = x_cropped(keep);
    y_keep = y_cropped(keep);
    index=index(keep);
    voxels=voxels(:,keep);
    
    % keep = find( (x>=1) & (x<=w) & (y>=1) & (y<=h) );
    % x = x(keep);
    % y = y(keep);
    
    % Now clear any that are not inside the silhouette
    ind = sub2ind( [h,w], round(y_keep), round(x_keep) );
    keep=Silhouette(ind) >= 1;
    % keep = keep(Silhouette(ind) >= 1);
    
    index2=index(keep);
    voxels2=voxels(:,keep);
    
    % imagesc(Silhouette); hold on;
    % plot(x(keep),y(keep),'.r')
    % plot(x(keep),y(keep),'.g')
end

