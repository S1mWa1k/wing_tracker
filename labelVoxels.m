function [Lout,numClusters,sizeCLusters]=labelVoxels(pts,minDistance)
% save templabelVoxels
% clear
% close all
% load templabelVoxels
% based on pcsegdist function
            
Lout=zeros(size(pts,1),1);
pts_ind=~isnan(pts(:,1));

pts(isnan(pts(:,1)),:)=[];
npts=size(pts,1);

L=zeros(npts,1);
newLabel = 0;

for i=1:npts

    if L(i) ~= 0
        continue;
    end

    Hdist=sqrt((pts(i,1)-pts(:,1)).^2+(pts(i,2)-pts(:,2)).^2+(pts(i,3)-pts(:,3)).^2);
%     Hdist=sqrt(sum((repmat(pts(i,:),npts,1)-pts).^2,2));

    ind=find(Hdist<=minDistance);

    for k = 1:numel(ind)
        j = ind(k);
        if L(j) > 0 && L(i) > 0
            if L(j) > L(i)
                L(L==L(j)) = L(i);
            elseif L(j) < L(i)
                L(L==L(i)) = L(j);
            end
        else
            if L(j) > 0
                L(i) = L(j);
            elseif L(i) > 0
                L(j) = L(i);
            end
        end
    end
    if L(i) == 0
        newLabel = newLabel+1;
        L(ind) = newLabel;
    end
    
end

% Get unique labels sorted in increasing order
uniqueLabels = unique(L);
numClusters = numel(uniqueLabels);

sizeCLusters=zeros(numClusters,1);

for k = 1:numClusters
    L(L == uniqueLabels(k)) = k;
    sizeCLusters(k)=sum(L==k);
end

Lout(pts_ind)=L;