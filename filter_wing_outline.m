clear
close all 
   
% This version for carrying on with 
warning off

%% EDITABLE PART %%
% folder where recordings are stored
base_folder=fullfile('D:','Micro_arena');
date_folder='2026_06_30';
sequence_name='Fly7_a';

rec_freq=5400; % recording frequency
%% END EDITABLE PART %%

w=1;

wing_pitch_reg_order=1;

% return
% create loop for each sequence

% load initial points
load(fullfile('single_wing_init_points',[sequence_name '_init_click_combined.mat']))
load(fullfile('single_wing_tracked_points',[sequence_name '_tracked_wt.mat']))
load(fullfile('single_wing_tracked_points',[sequence_name '_tracked_outline.mat']),'voxels_lead0_all','voxels_trail0_all','Xwt_f','*Lead','*Trail','wing_yrange','stroke_ang','pitch_ang_init')

stroke_ang2=fillmissing(stroke_ang(:,w),'linear','EndValues','none');
stroke_ang2=rmmissing(stroke_ang2);

[f,P1]=quick_fft(stroke_ang2,rec_freq);

P1(1:3)=NaN;
wb_freq_est=f(P1==max(P1));

wb_freq_est=mean(wb_freq_est);

use_range=20:80;
wing_yrange=wing_yrange(use_range);
wing_yrange_sc=wing_yrange./100;

num_frames=size(xxwtL,1);

spanwise_camber=NaN(num_frames,1);
chord_length=NaN(num_frames,length(use_range));

wing_pitch_const=NaN(num_frames,1);
wing_pitch_grad=NaN(num_frames,1);
wing_pitch_grad_sq=NaN(num_frames,1);
wing_pitch_rsq=NaN(num_frames,1);
wing_pitch_pv=NaN(num_frames,1);

f_start=find(~isnan(Xwt_f),1);
f_end=find(~isnan(pitch_ang_init),1,'last');

for f=f_start:f_end

    XwLe2=XwLead(f,use_range);
    YwLe2=YwLead(f,use_range);
    ZwLe2=ZwLead(f,use_range);

    XwTr2=XwTrail(f,use_range);
    YwTr2=YwTrail(f,use_range);
    ZwTr2=ZwTrail(f,use_range);

    wing_pitch_temp=atan2d(ZwLe2-ZwTr2,XwLe2-XwTr2);

    % return

    if any(~isnan(wing_pitch_temp))

        if wing_pitch_reg_order==1
            [b,bint,r,rint,stats]=regress(wing_pitch_temp',[ones(length(wing_pitch_temp),1) wing_yrange_sc']);
        elseif wing_pitch_reg_order==2
            [b,bint,r,rint,stats]=regress(wing_pitch_temp',[ones(length(wing_pitch_temp),1) wing_yrange_sc' wing_yrange_sc'.^2]);
        end

        wing_pitch_const(f,1)=b(1);
        wing_pitch_grad(f,1)=b(2);

        if wing_pitch_reg_order==1
            wing_pitch_grad_sq(f,1)=0;

        elseif wing_pitch_reg_order==2

            wing_pitch_grad_sq(f,1)=b(3);
        end

        % plot(wing_yrange_sc,wing_pitch_temp); hold on
        % plot(wing_yrange_sc,wing_pitch_const(f)+wing_yrange_sc.*wing_pitch_grad(f)+wing_yrange_sc.^2.*wing_pitch_grad_sq(f))
        % 
        % return
        wing_pitch_rsq(f,1)=stats(1);
        wing_pitch_pv(f,1)=stats(3);

        [XwLe3,YwLe3,ZwLe3]=Ry2(XwLe2,YwLe2,ZwLe2,wing_pitch_temp);
        [XwTr3,YwTr3,ZwTr3]=Ry2(XwTr2,YwTr2,ZwTr2,wing_pitch_temp);
%         chord_zdist=ZwTr3';
        chord_zdist=ZwLe3';

        % span_range=(2*wing_yrange'-1);
        wing_yrange2=wing_yrange;
        wing_yrange2(isnan(chord_zdist))=[];
        % span_range(isnan(chord_zdist))=[];
        chord_zdist(isnan(chord_zdist))=[];

        chord_length(f,:)=hypot(XwLe2-XwTr2,ZwLe2-ZwTr2);

        wing_yrange2_norm=(wing_yrange2-1)/100;

        spanwise_camber(f,1)=sin(pi*wing_yrange2_norm')\chord_zdist;

    
        % if f==16
        %     return
        % end


%          plot3(XwLe2,YwLe2,ZwLe2,'.-','MarkerSize',20,'linewidth',2); hold on
%         plot3(XwTr2,YwTr2,ZwTr2,'.-','MarkerSize',20,'linewidth',2); hold on
% 
%         plot3([XwLe3;XwTr3],[YwLe3;YwTr3],[ZwLe3;ZwTr3]); hold on
%         % plot3([XwLe2;XwTr2],[YwLe2;YwTr2],[ZwLe2;ZwTr2]); hold on
%         plot3([0 0],[0 1],[0 0],'r','linewidth',2)
%         axis image
% %                 axis([-0.4 0.4 0.0 1.0 -0.4 0.4])
%         labels
%         title(['Frame ' num2str(f)])
%         return
    % return
    end
   
end

chord_length_ratio(:,w)=median(chord_length./repmat(median(chord_length,'omitnan'),size(chord_length,1),1),2,'omitnan');

spanwise_camber(abs(spanwise_camber(:,w))>0.15,w)=NaN;

spanwise_camber_f_temp=NaN(size(spanwise_camber));

% spanwise_camber_f_temp=filter_data(spanwise_camber(:,w),fp.wing_tip_filter_freq,rec_freq);
spanwise_camber_f_temp(f_start:f_end,w)=filter_data(spanwise_camber(f_start:f_end,w),4*wb_freq_est,rec_freq);
res_spanwise_camber=abs(spanwise_camber_f_temp-spanwise_camber(:,w));
err_spanwise_camber=find(res_spanwise_camber>0.05);

spanwise_camber(err_spanwise_camber,w)=NaN;

spanwise_camber_f=NaN(size(spanwise_camber));

spanwise_camber_f(f_start:f_end,w)=filter_data(spanwise_camber(f_start:f_end,w),6*wb_freq_est,rec_freq);
% chord_length_ratio_f(:,w)=filter_data(chord_length_ratio(:,w),fp.wing_tip_filter_freq,rec_freq);

% get rid of clear errors before filtering
mid_wing_pitch_temp=wing_pitch_const(:,w)+0.5*wing_pitch_grad(:,w)+0.5.^2*wing_pitch_grad_sq(:,w);

% return
 err_init=unique([find(mid_wing_pitch_temp<-180);...
                find(mid_wing_pitch_temp>20); ...
                find(wing_pitch_const(:,w)<-180);...
                find(wing_pitch_const(:,w)>20); ...
                find(wing_pitch_grad(:,w)<-300);...
                find(wing_pitch_grad(:,w)>300); ...
                find(chord_length_ratio(:,w)<0.7); ...
                find(chord_length_ratio(:,w)>1.4)]);

% err_init=unique([find(mid_wing_pitch_temp<-45);...
%                 find(mid_wing_pitch_temp>220); ...
%                 find(wing_pitch_const(:,w)<-100);...
%                 find(wing_pitch_const(:,w)>220); ...
%                 find(wing_pitch_grad(:,w)<-300);...
%                 find(wing_pitch_grad(:,w)>300); ...
%                 find(chord_length_ratio(:,w)<0.7); ...
%                 find(chord_length_ratio(:,w)>1.4)]);

wing_pitch_const(err_init,w)=NaN;
wing_pitch_grad(err_init,w)=NaN;
wing_pitch_grad_sq(err_init,w)=NaN;

wing_pitch_const_f_temp=NaN(size(spanwise_camber));
wing_pitch_grad_f_temp=NaN(size(spanwise_camber));
wing_pitch_grad_sq_f_temp=NaN(size(spanwise_camber));


wing_pitch_const_f_temp(f_start:f_end)=filter_data(wing_pitch_const(f_start:f_end,w),6*wb_freq_est,rec_freq)';
wing_pitch_grad_f_temp(f_start:f_end)=filter_data(wing_pitch_grad(f_start:f_end,w),6*wb_freq_est,rec_freq)';
wing_pitch_grad_sq_f_temp(f_start:f_end)=filter_data(wing_pitch_grad_sq(f_start:f_end,w),6*wb_freq_est,rec_freq)';

% wing_pitch_const_f_temp=filter_data(wing_pitch_const(:,w),fp.wing_pitch_filter_freq,rec_freq)';
% wing_pitch_grad_f_temp=filter_data(wing_pitch_grad(:,w),fp.wing_pitch_filter_freq,rec_freq)';
% wing_pitch_grad_sq_f_temp=filter_data(wing_pitch_grad_sq(:,w),fp.wing_pitch_filter_freq,rec_freq)';

prox_wing_pitch=wing_pitch_const(:,w)+0.2*wing_pitch_grad(:,w)+0.2.^2*wing_pitch_grad_sq(:,w);
prox_wing_pitch_f_temp=wing_pitch_const_f_temp+0.2*wing_pitch_grad_f_temp+0.2.^2*wing_pitch_grad_sq_f_temp;

mid_wing_pitch=wing_pitch_const(:,w)+0.5*wing_pitch_grad(:,w)+0.5.^2*wing_pitch_grad_sq(:,w);
mid_wing_pitch_f_temp=wing_pitch_const_f_temp+0.5*wing_pitch_grad_f_temp+0.5.^2*wing_pitch_grad_sq_f_temp;

dist_wing_pitch=wing_pitch_const(:,w)+0.8*wing_pitch_grad(:,w)+0.8.^2*wing_pitch_grad_sq(:,w);
dist_wing_pitch_f_temp=wing_pitch_const_f_temp+0.8*wing_pitch_grad_f_temp+0.8.^2*wing_pitch_grad_sq_f_temp;

res_prox_wing=abs(prox_wing_pitch_f_temp-prox_wing_pitch);
res_mid_wing=abs(mid_wing_pitch_f_temp-mid_wing_pitch);
res_dist_wing=abs(dist_wing_pitch_f_temp-dist_wing_pitch);

% if w==2
%     return
% end
xi=(1:size(mid_wing_pitch,1))';
x=xi;
x(isnan(mid_wing_pitch))=[];

mid_wing_pitch2=mid_wing_pitch;
mid_wing_pitch2(isnan(mid_wing_pitch))=[];

mid_wing_pitch2 = makima(x,mid_wing_pitch2,xi);
% mid_wing_pitch2=interp1(x,mid_wing_pitch2,xi,'spline');

% plot(prox_wing_pitch_f_temp,'.-'); hold on
% plot(mid_wing_pitch_f_temp,'.-'); hold on
% plot(dist_wing_pitch_f_temp,'.-'); hold on

err_all=unique([find(prox_wing_pitch_f_temp<-200); ...
                find(mid_wing_pitch_f_temp<-200); ...
                find(dist_wing_pitch_f_temp<-200); ...
                find(prox_wing_pitch_f_temp>20); ...
                find(mid_wing_pitch_f_temp>20); ...
                find(dist_wing_pitch_f_temp>20); ...
                find(res_prox_wing>40); ...
                find(res_mid_wing>40); ...
                find(res_dist_wing>40); ...
                find(chord_length_ratio(:,w)<0.7); ...
                find(chord_length_ratio(:,w)>1.4)]);

% err_all=unique([find(prox_wing_pitch_f_temp<-45); ...
%                 find(mid_wing_pitch_f_temp<-45); ...
%                 find(dist_wing_pitch_f_temp<-45); ...
%                 find(prox_wing_pitch_f_temp>220); ...
%                 find(mid_wing_pitch_f_temp>220); ...
%                 find(dist_wing_pitch_f_temp>220); ...
%                 find(res_prox_wing>40); ...
%                 find(res_mid_wing>40); ...
%                 find(res_dist_wing>40); ...
%                 find(chord_length_ratio(:,w)<0.7); ...
%                 find(chord_length_ratio(:,w)>1.4)]);
            
wing_pitch_grad(err_all,w)=NaN;
wing_pitch_const(err_all,w)=NaN;
wing_pitch_grad_sq(err_all,w)=NaN;

wing_pitch_const(wing_pitch_const==0)=NaN;
wing_pitch_grad(wing_pitch_grad==0)=NaN;

% wing_pitch_const_f(:,w)=filter_data(wing_pitch_const(:,w),fp.wing_pitch_filter_freq,rec_freq);
% wing_pitch_grad_f(:,w)=filter_data(wing_pitch_grad(:,w),fp.wing_pitch_filter_freq,rec_freq);
% wing_pitch_grad_sq_f(:,w)=filter_data(wing_pitch_grad_sq(:,w),fp.wing_pitch_filter_freq,rec_freq);

wing_pitch_const_f=NaN(size(spanwise_camber));
wing_pitch_const_vel=NaN(size(spanwise_camber));
wing_pitch_const_acc=NaN(size(spanwise_camber));

wing_pitch_grad_f=NaN(size(spanwise_camber));
wing_pitch_grad_vel=NaN(size(spanwise_camber));
wing_pitch_grad_acc=NaN(size(spanwise_camber));

wing_pitch_grad_sq_f=NaN(size(spanwise_camber));

[wing_pitch_const_f(f_start:f_end,w), wing_pitch_const_vel(f_start:f_end,w), wing_pitch_const_acc(f_start:f_end,w)]=filter_data(wing_pitch_const(f_start:f_end,w),6*wb_freq_est,rec_freq);
[wing_pitch_grad_f(f_start:f_end,w), wing_pitch_grad_vel(f_start:f_end,w), wing_pitch_grad_acc(f_start:f_end,w)]=filter_data(wing_pitch_grad(f_start:f_end,w),6*wb_freq_est,rec_freq);
wing_pitch_grad_sq_f(f_start:f_end,w)=filter_data(wing_pitch_grad_sq(f_start:f_end,w),6*wb_freq_est,rec_freq);

chord_length_all=chord_length;
mid_chord=chord_length_all(:,find(logical(wing_yrange>45).*logical(wing_yrange<55)));
mid_chord_med=median(mid_chord(:),'omitnan');

plot(wing_pitch_const+0.5*wing_pitch_grad+0.5^2*wing_pitch_grad_sq,'k'); hold on
plot(wing_pitch_const_f+0.5*wing_pitch_grad_f+0.5^2*wing_pitch_grad_sq_f,'linewidth',1)
xlabel('Frames')
ylabel('Deg')
xlim([f_start f_end])

if ~exist('single_wing_filtered_points','dir')
    mkdir('single_wing_filtered_points')
end

save(fullfile('single_wing_filtered_points',[sequence_name '_filtered_outline.mat']),'*_f','wing_pitch_const','wing_pitch_grad','wing_pitch_grad_sq_f','mid_chord_med','wing_pitch_const_vel','wing_pitch_const_acc','wing_pitch_grad_vel','wing_pitch_grad_acc')
% return
