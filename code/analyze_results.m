%% analyze_results.m  —  读取仿真结果，计算性能指标，生成 7 张分析图
% =========================================================================
% 功能：载入 simulation_results.mat，在稳态窗口内计算 PF / THD / 效率 / 直流
%       纹波 / 启动时间，打印汇总并写入 CSV；再导出 7 张 PNG 波形图（启动、
%       稳态 V-I、电流 FFT、纹波、负载阶跃、指标对比、功率波形）。
% 前置：需先运行 run_simulation。依赖 utils 下的 calc_pf/calc_thd/calc_efficiency。
% 输出：results/figures/fig1~fig7.png、results/tables/performance_summary.csv
% =========================================================================

clear; clc;

% --- 路径解析 ---
this_file = mfilename('fullpath');
[code_dir,~,~] = fileparts(this_file);
proj_dir   = fileparts(code_dir);
data_dir   = fullfile(proj_dir, 'results', 'data');
fig_dir    = fullfile(proj_dir, 'results', 'figures');
table_dir  = fullfile(proj_dir, 'results', 'tables');
addpath(fullfile(code_dir, 'utils'));               % 加入指标计算函数路径
if ~exist(fig_dir,'dir');   mkdir(fig_dir);   end
if ~exist(table_dir,'dir'); mkdir(table_dir); end

% --- 载入仿真结果 ---
result_mat = fullfile(data_dir, 'simulation_results.mat');
S = load(result_mat); R = S.R;
P = R.P;                                            % 参数结构体

% 拆出五路信号（时间用 Vs 的时间轴作为公共时间）
t   = R.Vs.time;
Vs  = R.Vs.signal;
Is  = R.Is.signal;
Vdc = R.Vdc.signal;
Idc = R.Idc.signal;
Vdc_ref = R.Vdc_ref.signal;

%% 性能指标（在负载突变前的稳态窗口内计算）
% 窗口：软启动结束 +150ms（确保越过所有启动暂态）到 负载突卸前 5ms。
t_ss_end   = P.t_load_off - 0.005;
t_ss_start = max(P.t_softstart + 0.15, t_ss_end - 10/P.f);  % 至少留 10 个工频周期

mask_ss = t >= t_ss_start & t <= t_ss_end;          % 稳态窗口掩码
t_ss  = t(mask_ss);
Vs_ss = Vs(mask_ss);
Is_ss = Is(mask_ss);
Vdc_ss = Vdc(mask_ss);
Idc_ss = Idc(mask_ss);

% 调用工具函数计算三大核心指标
pf  = calc_pf(t_ss, Vs_ss, Is_ss, P.f);                                  % 功率因数
[thd, fft_freq, fft_mag, harmonics] = calc_thd(t_ss, Is_ss, P.f, 50);    % 电流 THD + 频谱
[eta, Pin_avg, Pout_avg] = calc_efficiency(t_ss, Vs_ss, Is_ss, Vdc_ss, Idc_ss, P.f);  % 效率

% 直流母线电压平均值与纹波
Vdc_avg = mean(Vdc_ss);
Vdc_pp  = max(Vdc_ss) - min(Vdc_ss);                % 峰峰值
Vdc_ripple_pct = 100 * Vdc_pp / Vdc_avg;            % 纹波率（%）

% 启动建立时间：Vdc 首次达到 400V 的 95%
target = 0.95 * P.Vdc;
idx_reach = find(Vdc >= target, 1, 'first');
if ~isempty(idx_reach); t_settle = t(idx_reach); else; t_settle = NaN; end

% 打印指标汇总
fprintf('=====================================================\n');
fprintf(' Performance Metrics (steady state %.3f~%.3fs)\n', t_ss_start, t_ss_end);
fprintf('=====================================================\n');
fprintf('  Vdc_avg         = %.2f V        (target %.0fV)\n',  Vdc_avg, P.Vdc);
fprintf('  Vdc ripple p-p  = %.2f V (%.3f%%)  (target <%.1f%%)\n', Vdc_pp, Vdc_ripple_pct, P.dV_ratio*100);
fprintf('  PF              = %.4f          (target >=%.2f)\n', pf, P.PF_min);
fprintf('  THD(Is)         = %.2f%%         (target <%.1f%%)\n', thd, P.THD_max*100);
fprintf('  Efficiency      = %.2f%% (Pout=%.1fW, Pin=%.1fW)  (target >%.0f%%)\n', ...
    eta*100, Pout_avg, Pin_avg, P.eta_min*100);
fprintf('  Vdc settle time = %.3fs (to 95%% of 400V)\n', t_settle);
fprintf('=====================================================\n');

%% 保存指标表（CSV，供报告引用）
T = table( ...
    Vdc_avg, Vdc_pp, Vdc_ripple_pct, pf, thd, eta*100, ...
    Pin_avg, Pout_avg, t_settle, ...
    'VariableNames', {'Vdc_avg_V','Vdc_pp_V','Vdc_ripple_pct','PF','THD_pct','Eta_pct', ...
                       'Pin_W','Pout_W','SettleTime_s'});
writetable(T, fullfile(table_dir, 'performance_summary.csv'));
fprintf('  Summary saved to %s\n', fullfile(table_dir,'performance_summary.csv'));

%% 全局画图样式（白底、Times New Roman、统一线宽）
set(0,'DefaultFigureColor','w');
set(0,'DefaultAxesFontSize',11);
set(0,'DefaultAxesFontName','Times New Roman');
set(0,'DefaultLineLineWidth',1.2);

%% --- 图 1：启动过程（0~0.25s）：Vdc 跟踪、Is、Vs ---
f1 = figure('Position',[100 100 900 600],'Visible','off');
subplot(3,1,1);
plot(t, Vdc, 'b', t, Vdc_ref, 'r--');               % 实测 Vdc vs 给定 Vdc_ref
xlim([0 0.25]); ylim([0 450]); grid on;
ylabel('V_{dc} (V)'); title('Startup: DC bus voltage tracking');
legend('V_{dc}','V_{dc,ref}','Location','SouthEast');

subplot(3,1,2);
plot(t, Is, 'b'); xlim([0 0.25]); grid on;
ylabel('I_s (A)'); title('Startup: Input current');

subplot(3,1,3);
plot(t, Vs, 'b'); xlim([0 0.25]); grid on;
ylabel('V_s (V)'); xlabel('Time (s)'); title('Grid voltage');
exportgraphics(f1, fullfile(fig_dir,'fig1_startup.png'),'Resolution',150);
close(f1);

%% --- 图 2：稳态 V-I（负载突变前最后 4 个工频周期）---
t_show_end = P.t_load_off - 0.005;
t_show_start = t_show_end - 4/P.f;
mask2 = t >= t_show_start & t <= t_show_end;
f2 = figure('Position',[100 100 900 500],'Visible','off');
yyaxis left;  plot(t(mask2), Vs(mask2), 'b','LineWidth',1.2); ylabel('V_s (V)');
ylim([-400 400]);
yyaxis right; plot(t(mask2), Is(mask2), 'r','LineWidth',1.2); ylabel('I_s (A)');
ylim([-50 50]);
xlim([t_show_start t_show_end]); grid on;
xlabel('Time (s)');
title(sprintf('Steady-state V_s vs I_s   (PF = %.4f)', pf));   % Vs 与 Is 同相 → PF≈1
legend('V_s','I_s','Location','NorthEast');
exportgraphics(f2, fullfile(fig_dir,'fig2_steady_vi.png'),'Resolution',150);
close(f2);

%% --- 图 3：输入电流 FFT 频谱 ---
f3 = figure('Position',[100 100 900 500],'Visible','off');
stem(fft_freq, fft_mag, 'Marker','none','LineWidth',1.0);
xlim([0 2500]); grid on;
xlabel('Frequency (Hz)'); ylabel('|I_s(f)| (A)');
title(sprintf('Input current FFT spectrum   (THD = %.2f%%)', thd));
% 标注基波（50Hz）峰值
hold on;
plot(P.f, harmonics(1,2), 'r*','MarkerSize',10);
text(P.f+50, harmonics(1,2), sprintf('  50 Hz: %.2f A', harmonics(1,2)),'Color','r');
hold off;
exportgraphics(f3, fullfile(fig_dir,'fig3_current_fft.png'),'Resolution',150);
close(f3);

%% --- 图 4：直流母线纹波放大 ---
f4 = figure('Position',[100 100 900 500],'Visible','off');
plot(t_ss, Vdc_ss, 'b', 'LineWidth',1.2);
yline(Vdc_avg, 'r--', sprintf('avg = %.2fV', Vdc_avg));   % 标出平均值
xlim([t_ss(1) t_ss(end)]); grid on;
xlabel('Time (s)'); ylabel('V_{dc} (V)');
title(sprintf('DC bus ripple: \\DeltaV_{pp} = %.2f V (%.3f%%)', Vdc_pp, Vdc_ripple_pct));
exportgraphics(f4, fullfile(fig_dir,'fig4_dc_ripple.png'),'Resolution',150);
close(f4);

%% --- 图 5：负载阶跃响应（0.38~0.55s 附近）---
t_step_s = P.t_load_off - 0.02;
t_step_e = P.t_load_on  + 0.05;
mask5 = t >= t_step_s & t <= t_step_e;
f5 = figure('Position',[100 100 900 600],'Visible','off');
subplot(2,1,1);
plot(t(mask5), Vdc(mask5), 'b'); grid on;
xlim([t_step_s t_step_e]);
xline(P.t_load_off,'r--','100%->50% load');         % 突卸 50% 时刻
xline(P.t_load_on, 'g--','50%->100% load');         % 突加回 100% 时刻
ylabel('V_{dc} (V)'); title('Load step response: V_{dc}');

subplot(2,1,2);
plot(t(mask5), Is(mask5), 'b'); grid on;
xlim([t_step_s t_step_e]);
xline(P.t_load_off,'r--');
xline(P.t_load_on, 'g--');
ylabel('I_s (A)'); xlabel('Time (s)'); title('Load step response: I_s');
exportgraphics(f5, fullfile(fig_dir,'fig5_load_step.png'),'Resolution',150);
close(f5);

%% --- 图 6：性能指标对比柱状图（实测 vs 目标）---
f6 = figure('Position',[100 100 900 500],'Visible','off');
% 四项指标统一换算成"越大越好、满分100%"的形式便于并排比较
metrics  = [pf,       1-thd/100,  eta,      1-Vdc_ripple_pct/100];
targets  = [P.PF_min, 1-P.THD_max,P.eta_min,1-P.dV_ratio];
labels   = {'PF','1-THD','\eta','1-\Delta V_{dc}/V_{dc}'};

bar([metrics; targets]'*100);
set(gca,'XTickLabel',labels);
ylabel('Value (%)'); ylim([85 102]); grid on;
legend('Measured','Target','Location','SouthWest');
title('Performance summary: measured vs target');
% 在每根"实测"柱顶标注数值
for i=1:numel(metrics)
    text(i-0.15, metrics(i)*100+0.5, sprintf('%.2f%%', metrics(i)*100),'FontSize',9);
end
exportgraphics(f6, fullfile(fig_dir,'fig6_performance.png'),'Resolution',150);
close(f6);

%% --- 图 7：功率波形（瞬时与平均）---
f7 = figure('Position',[100 100 900 500],'Visible','off');
P_in = Vs_ss .* Is_ss;                              % 输入瞬时功率（含 100Hz 脉动）
plot(t_ss, P_in, 'b'); hold on;
yline(Pin_avg, 'r--', sprintf('Pin avg = %.1f W', Pin_avg),'LabelHorizontalAlignment','left');
yline(Pout_avg,'g--', sprintf('Pout avg = %.1f W', Pout_avg),'LabelHorizontalAlignment','right');
xlim([t_ss(1) t_ss(end)]); grid on;
xlabel('Time (s)'); ylabel('Power (W)');
title(sprintf('Instantaneous and average power   (\\eta = %.2f%%)', eta*100));
legend('P_{in}(t)','P_{in,avg}','P_{out,avg}','Location','NorthEast');
exportgraphics(f7, fullfile(fig_dir,'fig7_power.png'),'Resolution',150);
close(f7);

fprintf('\n[analyze_results] All 7 figures saved to: %s\n', fig_dir);
fprintf('Figures:\n');
ds = dir(fullfile(fig_dir,'*.png'));
for k=1:numel(ds); fprintf('  %s (%.1f KB)\n', ds(k).name, ds(k).bytes/1024); end
