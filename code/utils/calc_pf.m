function pf = calc_pf(t, v, i, f_grid)
%CALC_PF  计算功率因数（Power Factor）。
% =========================================================================
% 定义：PF = 平均有功功率 / (电压有效值 × 电流有效值)
%            = mean(v.*i) / (rms(v) * rms(i))
% 该定义对任意波形都成立：当电压电流同相且均为正弦时 PF=1；存在相移或谐波时
% PF<1。本设计目标 PF≥0.99，即输入电流应几乎与电网电压同相且接近正弦。
%
% 输入：
%   t       : 时间向量（s），与 v、i 等长，可为非均匀采样
%   v, i    : 电压、电流采样向量
%   f_grid  : 电网频率（Hz），用于确定积分窗口长度
% 输出：
%   pf      : 功率因数，取值范围 [-1, 1]（负值表示功率反向流动）
% =========================================================================

T_grid = 1/f_grid;          % 工频周期（50Hz → 20ms）

% 取最后 5 个工频周期作为计算窗口：保证已进入稳态，且为整数个周期以减小
% 有功功率与有效值的积分截断误差。
T_window = 5 * T_grid;
t_end = t(end);
t_start = t_end - T_window;

mask = t >= t_start & t <= t_end;   % 落在窗口内的采样点
if ~any(mask)
    pf = NaN; return;               % 窗口内无数据则返回 NaN，避免后续除零
end
v_w = v(mask);  i_w = i(mask);

V_rms = sqrt(mean(v_w.^2));         % 电压有效值（均方根）
I_rms = sqrt(mean(i_w.^2));         % 电流有效值
P_avg = mean(v_w .* i_w);           % 平均有功功率 = 瞬时功率的均值

if V_rms < 1e-6 || I_rms < 1e-6
    pf = NaN;                        % 电压或电流近似为零时 PF 无意义
else
    pf = P_avg / (V_rms * I_rms);
end
end
