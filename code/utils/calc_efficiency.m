function [eta, Pin_avg, Pout_avg] = calc_efficiency(t, vs, is, vdc, idc, f_grid)
%CALC_EFFICIENCY  计算整流器转换效率 η。
% =========================================================================
% 定义：η = 输出有功功率 / 输入有功功率 = mean(Vdc·Idc) / mean(Vs·Is)
% 输入侧功率取交流瞬时功率 Vs·Is 的均值（含 100Hz 脉动，需对整数周期取平均）；
% 输出侧功率取直流侧 Vdc·Idc 的均值。两者之差即为电路损耗（开关损耗 + 导通损耗
% + 电感电阻损耗等）。本设计目标 η>94%。
%
% 输入：
%   t       : 时间向量（s）
%   vs, is  : 电网电压、输入电流
%   vdc, idc: 直流母线电压、负载电流
%   f_grid  : 电网频率（Hz）
% 输出：
%   eta      : 效率（小数，如 0.959 表示 95.9%）
%   Pin_avg  : 平均输入功率（W）
%   Pout_avg : 平均输出功率（W）
% =========================================================================

T_grid = 1/f_grid;          % 工频周期
T_window = 5 * T_grid;      % 取最后 5 个整工频周期，消除 100Hz 脉动的平均误差
t_end = t(end);
t_start = t_end - T_window;
mask = t >= t_start & t <= t_end;

Pin  = vs(mask) .* is(mask);    % 输入瞬时功率序列
Pout = vdc(mask) .* idc(mask);  % 输出瞬时功率序列

Pin_avg  = mean(Pin);           % 平均输入功率
Pout_avg = mean(Pout);          % 平均输出功率

if abs(Pin_avg) < 1e-6
    eta = NaN;                  % 输入功率近零时效率无意义
else
    eta = Pout_avg / Pin_avg;
end
end
