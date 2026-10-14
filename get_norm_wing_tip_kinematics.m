clear
close all 
   
project_folder ='Calliphora';

d=dir(fullfile(project_folder,'single_wing_tracked_points','20*'));
date_folders={d.name};

d=dir(fullfile(project_folder,[project_folder '_Yaw*.xlsx']));

t=readtable(fullfile(project_folder,d.name),ReadVariableNames=false);

fly_yaw_names=table2array(t(3:end,1));
fly_end=find(isnan(fly_yaw_names),1)-1;
fly_yaw_names=fly_yaw_names(1:fly_end);

fly_yaw_order=table2array(t(3:end,2:8));
fly_yaw_order=fly_yaw_order(1:fly_end,:);

yaw_rates=[-50 -100 -150 50 100 150 0];

dates_all=[];
sequences_all=[];

for D=1:length(date_folders)
    d=dir(fullfile(project_folder,'single_wing_tracked_points',date_folders{D},'*_tracked_wt.mat'));
    
    sequences={d.name};

    sequences_all=[sequences_all;sequences'];
    dates_all=[dates_all;repmat(date_folders(D),length(sequences),1)];
end

SS=1;

for S=1:length(sequences_all)

    date_curr=dates_all{S};
    sequence=sequences_all{S};
    sequence_name=erase(sequence, '_tracked_wt.mat');
    
    num_strs = regexp(sequence_name, '\d+', 'match');
    nums = str2double(num_strs);

    fly_number=nums(1);
    sequence_number=nums(2);

    fly_yaw_row=find(fly_yaw_names==fly_number);

    yaw_rate=yaw_rates(fly_yaw_order(fly_yaw_row,sequence_number));
    
    if ~isempty(yaw_rate)
       
        load(fullfile(project_folder,'single_wing_tracked_points',date_curr,sequence))
    
        Xwt2=-(Xwt-Xwb);
        Ywt2=Ywt-Ywb;
        Zwt2=Zwt-Zwb;
    
        % plot3(Xwt2,Ywt2,Zwt2); hold on
        % plot3(0,0,0,'.r','markersize',20);
        % plot3(Xwt2(1),Ywt2(1),Zwt2(1),'.g','markersize',20);axis image; labels
        % plot3(Xwt2(1:5),Ywt2(1:5),Zwt2(1:5),'g','linewidth',2);axis image; labels
    
        % return
    
        [stroke_ang,dev_ang,wing_length]=cart2sph(Ywt2,-Xwt2,Zwt2);
    
        wing_length_med=median(wing_length,'omitmissing');
        stroke_ang=180/pi*stroke_ang;
        dev_ang=180/pi*dev_ang;
    
        rec_freq=5400;
    
        [f,P1]=quick_fft(stroke_ang,rec_freq);
    
        P1(1:3)=NaN;
        wb_freq_est=f(P1==max(P1));
    
        wb_freq_est=mean(wb_freq_est);
        
        [stroke_ang_f, stroke_vel, stroke_acc]=filter_data(stroke_ang,5*wb_freq_est,rec_freq);
        [dstroke, ustroke]=find_wingbeats_function(stroke_vel',wb_freq_est,rec_freq);
    
        Xwt_f=filter_data(Xwt2,5*wb_freq_est,rec_freq);
        Ywt_f=filter_data(Ywt2,5*wb_freq_est,rec_freq);
        Zwt_f=filter_data(Zwt2,5*wb_freq_est,rec_freq);
    
        thv_mean=stroke_vel;
        thv_mean_diff=diff(thv_mean);
    
        frame_num=1:length(thv_mean);
    
        Kinematics(SS).flyName=sequence_name;
        Kinematics(SS).flyNumber=fly_number;
        Kinematics(SS).seqNumber=sequence_number;
        Kinematics(SS).yawRate=yaw_rate;
    
        Kinematics(SS).recFreq=rec_freq;
        Kinematics(SS).recDate=date_curr;
        
        time=linspace(0,1,101);
        Kinematics(SS).StrokeAngleLeft=NaN(length(time),size(dstroke,1));
    
        Kinematics(SS).XXwtL=NaN(length(time),size(dstroke,1));
        Kinematics(SS).YYwtL=NaN(length(time),size(dstroke,1));
        Kinematics(SS).ZZwtL=NaN(length(time),size(dstroke,1));
    
        Kinematics(SS).down=NaN(1,size(dstroke,1));
    
        Kinematics(SS).WingbeatStart=NaN(1,size(dstroke,1));
        Kinematics(SS).WingbeatPeriod=NaN(1,size(dstroke,1));
    
        Kinematics(SS).XXwtL_u=NaN(1,size(dstroke,1));
        Kinematics(SS).YYwtL_u=NaN(1,size(dstroke,1));
        Kinematics(SS).ZZwtL_u=NaN(1,size(dstroke,1));
    
        for i=1:size(dstroke,1)
    
            dn1_zero_start=find(thv_mean_diff(1:dstroke(i,1))>0,1,'last')+1;
            dn1_zero_end=dstroke(i,1)+find(thv_mean_diff(dstroke(i,1):end)>0,1)-1;
    
            if isempty(dn1_zero_start)
                dn1_zero_start=find(~isnan(thv_mean),1);
            end
    
            dn1=interp1(thv_mean(dn1_zero_start:dn1_zero_end),1:dn1_zero_end-dn1_zero_start+1,0,'pchip');
            dn1=dstroke(i,1)+dn1-floor(dn1);
    
            dn2_zero_start=find(thv_mean_diff(1:dstroke(i,2))>0,1,'last')+1;
            dn2_zero_end=dstroke(i,2)+find(thv_mean_diff(dstroke(i,2):end)>0,1)-1;
    
            if isempty(dn2_zero_end)
                dn2_zero_end=find(~isnan(thv_mean),1,'last');
            end
    
            dn2=interp1(thv_mean(dn2_zero_start:dn2_zero_end),1:dn2_zero_end-dn2_zero_start+1,0,'pchip');
            dn2=dstroke(i,2)+dn2-floor(dn2);
    
            frame_interp=linspace(dn1,dn2,length(time));
    
            Kinematics(SS).StrokeAngleLeft(:,i)=interp1(frame_num,stroke_ang_f,frame_interp,'pchip');
    
            Kinematics(SS).WingbeatPeriod(1,i)=1000.*(dn2-dn1)/rec_freq;
            Kinematics(SS).WingbeatStart(1,i)=(dn1-1)/rec_freq;
    
            Kinematics(SS).XXwtL(:,i)=interp1(frame_num,Xwt_f,frame_interp,'pchip');
            Kinematics(SS).YYwtL(:,i)=interp1(frame_num,Ywt_f,frame_interp,'pchip');
            Kinematics(SS).ZZwtL(:,i)=interp1(frame_num,Zwt_f,frame_interp,'pchip');
    
            thvL_n=interp1(frame_num,thv_mean,frame_interp,'pchip');
            Kinematics(SS).down(i,1)=interp1(thvL_n(20:end-20),time(20:end-20),0,'linear');
    
            Kinematics(SS).XXwtL_u(1,i)=interp1(time,Kinematics(SS).XXwtL(:,i),Kinematics(SS).down(i,1),'pchip');
            Kinematics(SS).YYwtL_u(1,i)=interp1(time,Kinematics(SS).YYwtL(:,i),Kinematics(SS).down(i,1),'pchip');
            Kinematics(SS).ZZwtL_u(1,i)=interp1(time,Kinematics(SS).ZZwtL(:,i),Kinematics(SS).down(i,1),'pchip');
    
        end
    
        Kinematics(SS).StartFrames=dstroke';
    
        Kinematics(SS).XXwtL_d=Kinematics(SS).XXwtL(1,:);
        Kinematics(SS).YYwtL_d=Kinematics(SS).YYwtL(1,:);
        Kinematics(SS).ZZwtL_d=Kinematics(SS).ZZwtL(1,:);
    
        Kinematics(SS).StrokeAmpL=180/pi*anglePoints3d([Kinematics(SS).XXwtL_d;Kinematics(SS).YYwtL_d;Kinematics(SS).ZZwtL_d]',...
        [Kinematics(SS).XXwtL_u;Kinematics(SS).YYwtL_u;Kinematics(SS).ZZwtL_u]')';
    
        Kinematics(SS).StrokeAmpL_mean=mean(Kinematics(SS).StrokeAmpL);
        Kinematics(SS).StrokeAmpL_std=std(Kinematics(SS).StrokeAmpL);
    
        Kinematics(SS).ForwardStrokeAngleL=atan2d(-Kinematics(SS).XXwtL_u,Kinematics(SS).YYwtL_u);
        Kinematics(SS).DownStrokeAngleL=atan2d(-Kinematics(SS).XXwtL_d,Kinematics(SS).YYwtL_d);
    
        Kinematics(SS).StrokePlaneL=atan2d(Kinematics(SS).ZZwtL_u-Kinematics(SS).ZZwtL_d,Kinematics(SS).XXwtL_u-Kinematics(SS).XXwtL_d);
    
        SS=SS+1;
    end

end

save([project_folder '_kinematics_norm'],'Kinematics')

StrokeAmpL_mean=[Kinematics.StrokeAmpL_mean];
StrokeAmpL_std=[Kinematics.StrokeAmpL_std];

yawRate=[Kinematics.yawRate];

errorbar(yawRate,StrokeAmpL_mean,StrokeAmpL_std,'.')