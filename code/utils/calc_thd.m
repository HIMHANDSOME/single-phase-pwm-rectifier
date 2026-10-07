function [thd_pct, f, mag, harmonics] = calc_thd(t, x, f_grid, n_harm)
%CALC_THD  计算信号的总谐波失真（Total Harmonic Distortion）。
% =========================================================================
% 定义：THD = sqrt(Σ I_h²，h=2..N) / I_1 × 100%
%       即所有高次谐波有效值平方和的平方根，除以基波幅值。
% 衡量输入电流偏离纯正弦的程度，本设计目标 THD<3%。
%
% 实现要点：
%   1) 仿真输出为变步长非均匀采样，FFT 要求等间隔采样，故先用 interp1 重采样
%      到 100kHz 均匀网格；
%   2) 加 Hanning 窗抑制频谱泄漏，并做幅值校正（除以 sum(win)/2）；
%   3) 在每个谐波频率 ±5Hz 邻域内取峰值作为该次谐波幅值，避免频率分辨率
%      不对齐导致的能量分散。
%
% 输入：
%   t       : 时间向量（s）
%   x       : 待分析信号（此处为输入电流 Is）
%   f_grid  : 基波频率（Hz）
%   n_harm  : 考虑的谐波次数（默认 50）
% 输出：
%   thd_pct  : THD 百分比
%   f, mag   : 完整单边 FFT 的频率轴与幅值（供画频谱图用）
%   harmonics: n_harm×3 矩阵 [谐波频率, 该次幅值, 该次/基波幅值比]
% =========================================================================

if nargin < 4 || isempty(n_harm); n_harm = 50; end   % 缺省取前 50 次谐波

% --- 取最后 10 个工频周期作为分析窗口（整数周期，频率分辨率 = f_grid/10）---
T_grid   = 1/f_grid;
T_window = 10 * T_grid;
t_end    = t(end);
t_start  = t_end - T_window;
mask = t >= t_start & t <= t_end;
t_w  = t(mask);
x_w  = x(mask);

% --- 重采样到均匀时间网格，便于做 FFT ---
fs   = 100e3;                       % 重采样频率 100kHz（远高于最高关注谐波）
t_u  = (t_start : 1/fs : t_end).';  % 均匀时间向量（列向量）
x_u  = interp1(t_w, x_w, t_u, 'linear', 'extrap');   % 线性插值重采样

% --- 加窗 + FFT + 幅值校正 ---
N    = numel(x_u);
win  = hanning(N);                  % Hanning 窗，降低频谱泄漏
X    = fft(x_u .* win);
X    = X / (sum(win)/2);            % 加窗后的幅值校正系数
mag  = abs(X(1:floor(N/2)+1));      % 单边幅值谱
f    = (0:floor(N/2)).' * fs / N;   % 对应频率轴

% --- 在各谐波频点附近搜峰，提取每次谐波幅值 ---
harmonics = zeros(n_harm, 3);
for h = 1:n_harm
    f_h = h * f_grid;               % 第 h 次谐波频率
    if f_h > f(end); break; end     % 超出 Nyquist 频率则停止
    idx = find(abs(f - f_h) < 5);   % 在 ±5Hz 邻域内查找频点
    if isempty(idx)
        amp_h = 0;
    else
        amp_h = max(mag(idx));      % 取邻域内的峰值作为该次谐波幅值
    end
    harmonics(h, 1) = f_h;
    harmonics(h, 2) = amp_h;
end

amp_1 = harmonics(1, 2);            % 基波（50Hz）幅值
if amp_1 < 1e-9
    thd_pct = NaN;                  % 基波近零时 THD 无意义
else
    harmonics(:, 3) = harmonics(:, 2) / amp_1;                    % 各次/基波比
    thd_pct = 100 * sqrt(sum(harmonics(2:end, 2).^2)) / amp_1;    % THD 公式
end
end
