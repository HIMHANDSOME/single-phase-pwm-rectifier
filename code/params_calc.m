%% params_calc.m  —  单相 PWM 整流器参数计算
% =========================================================================
% 功能：把课程设计的"指标级"要求（220V→400V、5kW、PF/THD/η 目标）逐步换算成
%       "可仿真"的电路参数（L、C、R）、控制器参数（PI 增益、滤波/限幅）、采样
%       周期与仿真时序，统一打包进结构体 P 并保存为 pwm_rectifier_params.mat，
%       供 build_model / run_simulation 读取。
% 输出：matlab/model/pwm_rectifier_params.mat（含结构体 P）
%       同时在命令行打印一张格式化的参数汇总表。
% =========================================================================

clear; clc;

%% 1. 工程路径（相对本脚本自动解析，换机器无需改路径）
this_file = mfilename('fullpath');
[code_dir,~,~] = fileparts(this_file);
proj_dir  = fileparts(code_dir);              % matlab/ 根目录
model_dir = fullfile(proj_dir, 'model');      % 模型与参数 .mat 存放处
data_dir  = fullfile(proj_dir, 'results', 'data');
if ~exist(model_dir, 'dir'); mkdir(model_dir); end
if ~exist(data_dir,  'dir'); mkdir(data_dir);  end

%% 2. 设计指标（由课程设计任务书给定，固定不变）
P.Vs_rms = 220;                 % 电网电压有效值 [V]
P.f      = 50;                  % 电网频率 [Hz]
P.Vdc    = 400;                 % 直流母线给定电压 [V]
P.Po     = 5000;                % 额定输出功率 [W]
P.Idc_max= 12.5;                % 最大输出电流 [A]（= Po/Vdc）
P.PF_min = 0.99;                % 功率因数目标
P.THD_max= 0.03;                % 输入电流 THD 目标
P.eta_min= 0.94;                % 转换效率目标

%% 3. 由指标推导的电气量
P.Vsm   = sqrt(2) * P.Vs_rms;                   % 电网电压峰值 ≈ 311V
P.w     = 2*pi*P.f;                             % 角频率 ω = 2πf
P.eta_est = 0.95;                               % 选型用的预估效率
P.Pin   = P.Po / P.eta_est;                     % 输入有功功率 ≈ 5263W
P.Is_rms= P.Pin / P.Vs_rms;                     % 输入电流有效值 ≈ 23.9A
P.Is_pk = sqrt(2) * P.Is_rms;                   % 输入电流峰值 ≈ 33.8A
P.R_load= P.Vdc^2 / P.Po;                       % 等效负载电阻 = Vdc²/Po = 32Ω
P.m_idx = P.Vsm / P.Vdc;                        % 稳态调制比 ≈ 311/400 ≈ 0.78

%% 4. 开关频率与采样周期
P.fsw      = 10e3;                              % 开关（载波）频率 10kHz
P.Ts_power = 2e-6;                              % SPWM 块采样周期 2μs（= 50× 过采样 fsw）
P.Ts_ctrl  = 1e-4;                              % 控制器采样周期 100μs（= 1/fsw）
% 说明：SPWM 与控制器分两个采样率运行，快块 2μs 保证载波离散化精度，
%       控制器 100μs 降低计算量，二者解耦避免混叠破坏 PWM 波形。

%% 5. 输入电感 L 设计（电流纹波 ≤ 峰值的 20%）
P.dI_ratio = 0.20;                              % 允许的电流纹波比例
P.dI_max   = P.dI_ratio * P.Is_pk;              % 允许的最大纹波 ≈ 6.77A
% 双极性 SPWM 下的电感最小值约束：L >= Vdc / (4·fsw·ΔiL)
P.L_min    = P.Vdc / (4 * P.fsw * P.dI_max);    % ≈ 1.48mH
P.L        = 5e-3;                              % 实选 5mH（留裕量进一步压低 PWM 纹波）
P.RL       = 0.10;                              % 电感寄生电阻 [Ω]（建模损耗用）

%% 6. 直流母线电容 C 设计（纹波 ≤ Vdc 的 1%，针对 100Hz 二次脉动）
P.dV_ratio = 0.01;                              % 允许的电压纹波比例
P.dV_max   = P.dV_ratio * P.Vdc;                % 允许的最大纹波 = 4V
% 单相系统 2 倍工频（100Hz）脉动约束：C >= Po / (2π·2f·Vdc·ΔVdc)
P.C_min    = P.Po / (2*pi*2*P.f * P.Vdc * P.dV_max);   % ≈ 2487μF
P.C        = 6800e-6;                           % 实选 6800μF（含老化、ESR 裕量）
P.Vc_init  = round(P.Vsm);                      % 电容初值预置为电网峰值≈311V
% 说明：将电容初值预置为不控整流自然稳态值，模拟"预充电电阻"作用，
%       避免启动瞬间的浪涌电流与电压尖峰。

%% 7. 电流内环 PI（对称最优法给出解析参考值，实际用经验整定值）
P.T_sigma  = 1.5 * (1/P.fsw);                   % 小时间常数
P.Kp_i_so  = P.L / (2 * P.T_sigma);             % 对称最优解析 Kp（参考）
P.Ki_i_so  = P.Kp_i_so / (4 * P.T_sigma);       % 对称最优解析 Ki（参考）
% 实际取值：因单相系统含 100Hz 二次脉动，需大幅降低增益以保证稳定。
P.Kp_i = 2;                                     % 电流环比例增益
P.Ki_i = 2000;                                  % 电流环积分增益
P.I_limit = 0.95 * P.Vdc;                       % 电流环输出（调制电压）限幅 ≈ Vdc

%% 8. 电压外环 PI（配 100Hz 陷波/低通抑制纹波）
P.Kp_v   = 0.5;                                 % 电压环比例增益
P.Ki_v   = 10;                                  % 电压环积分增益
P.Im_lim = 35;                                  % 电流幅值给定限幅 [A]
P.notch_f= 2 * P.f;                             % 陷波频率 = 100Hz
P.notch_Q= 2;                                   % 陷波品质因数
% 陷波传递函数：H(s) = (s²+ωn²)/(s²+(ωn/Q)·s+ωn²)
P.notch_wn = 2*pi*P.notch_f;
% 说明：实际控制器代码中用的是一阶低通（截止 20Hz）抑制 100Hz 纹波，
%       此处陷波参数为备选方案保留。

%% 9. SOGI-PLL 参数（备选锁相环方案；本设计实际用开环同步未启用）
P.SOGI_k = sqrt(2);                             % SOGI 阻尼增益
P.PLL_Kp = 178;                                 % PLL 比例增益
P.PLL_Ki = 7900;                                % PLL 积分增益
P.PLL_w0 = 2*pi*P.f;                            % PLL 中心频率初值

%% 10. SPWM 参数
P.Tri_freq = P.fsw;                             % 三角载波频率 = 开关频率
P.Tri_amp  = 1.0;                               % 三角载波幅值，归一化到 [-1, 1]
P.Dead_time= 1e-6;                              % 死区时间 [s]（仿真取较小值）

%% 11. 仿真时序（总时长 0.6s，覆盖启动/稳态/两次负载突变）
P.Tsim       = 0.60;                            % 仿真总时长 [s]
P.t_softstart_begin = 0.03;                     % 0~此刻 Vdc_ref 维持 Vsm（电容预充电）
P.t_softstart= 0.15;                            % 软启动斜坡终点，Vdc_ref 升到 400V
P.t_load_off = 0.40;                            % 负载由 100%→50% 时刻
P.t_load_on  = 0.50;                            % 负载由 50%→100% 时刻
P.R_load_2   = 2 * P.R_load;                    % 半载电阻（两个 2R 并联=R）

%% 12. 器件选型汇总（写入报告用）
P.sel.IGBT_V = 1200;                            % IGBT 耐压等级 [V]（2 倍裕量）
P.sel.IGBT_I = 50;                              % IGBT 电流等级 [A]（1.4 倍裕量）
P.sel.IGBT_model = 'Infineon IKW40N120H3';      % 含反并联快恢复二极管
P.sel.Cap_V  = 450;                             % 直流电容耐压 [V]
P.sel.Cap_C  = 6800e-6;                         % 电容容量 [F]
P.sel.Cap_model = 'Nichicon LGU 6800uF/450V';
P.sel.L_core = 'Sendust (FeSiAl) toroid';       % 铁硅铝磁芯
P.sel.L_I    = 40;                              % 电感额定电流 [A]
P.sel.Snubber_R = 1e5;                          % IGBT 缓冲电阻 [Ω]
P.sel.Snubber_C = inf;                          % 缓冲电容（inf = 关闭）

%% 13. 保存到 .mat
mat_path = fullfile(model_dir, 'pwm_rectifier_params.mat');
save(mat_path, 'P');

%% 14. 命令行打印参数汇总表
fprintf('================================================================\n');
fprintf(' Single-Phase PWM Rectifier - Parameter Calculation Summary\n');
fprintf('================================================================\n');
fprintf(' [Spec]    Vs=%.0fV(RMS)/%.0fHz, Vdc=%.0fV, Po=%.0fW, Idc_max=%.1fA\n', ...
    P.Vs_rms, P.f, P.Vdc, P.Po, P.Idc_max);
fprintf(' [Spec]    PF>=%.2f, THD<%.0f%%, eta>%.0f%%\n', ...
    P.PF_min, P.THD_max*100, P.eta_min*100);
fprintf('----------------------------------------------------------------\n');
fprintf(' [Derived] Vsm=%.2fV, w=%.2frad/s, m=%.3f\n', P.Vsm, P.w, P.m_idx);
fprintf(' [Derived] Pin=%.1fW, Is_rms=%.2fA, Is_pk=%.2fA, R_load=%.2fOhm\n', ...
    P.Pin, P.Is_rms, P.Is_pk, P.R_load);
fprintf('----------------------------------------------------------------\n');
fprintf(' [Switch]  fsw=%.0fHz, Ts_power=%.1eus, Ts_ctrl=%.1eus\n', ...
    P.fsw, P.Ts_power*1e6, P.Ts_ctrl*1e6);
fprintf(' [L]       L_min=%.3fmH (calc) -> L=%.2fmH (selected), RL=%.2fOhm\n', ...
    P.L_min*1e3, P.L*1e3, P.RL);
fprintf(' [C]       C_min=%.0fuF (calc) -> C=%.0fuF (selected), Vc0=%.0fV\n', ...
    P.C_min*1e6, P.C*1e6, P.Vc_init);
fprintf('----------------------------------------------------------------\n');
fprintf(' [I-Loop]  Kp_i=%.2f, Ki_i=%.0f, limit=+/-%.0fV\n', P.Kp_i, P.Ki_i, P.I_limit);
fprintf(' [V-Loop]  Kp_v=%.2f, Ki_v=%.1f, Im_lim=+/-%.0fA, Notch=%.0fHz Q=%.0f\n', ...
    P.Kp_v, P.Ki_v, P.Im_lim, P.notch_f, P.notch_Q);
fprintf(' [PLL]     SOGI k=%.3f, Kp=%.0f, Ki=%.0f, w0=%.2frad/s\n', ...
    P.SOGI_k, P.PLL_Kp, P.PLL_Ki, P.PLL_w0);
fprintf(' [SPWM]    Carrier=%.0fHz, deadtime=%.1eus\n', P.Tri_freq, P.Dead_time*1e6);
fprintf('----------------------------------------------------------------\n');
fprintf(' [Devices] IGBT: %s (%dV/%dA)\n', P.sel.IGBT_model, P.sel.IGBT_V, P.sel.IGBT_I);
fprintf(' [Devices] Cap : %s\n', P.sel.Cap_model);
fprintf(' [Devices] L   : %s, %d A rating\n', P.sel.L_core, P.sel.L_I);
fprintf('----------------------------------------------------------------\n');
fprintf(' [Timing]  Tsim=%.2fs, softstart=%.2fs, load step 100%%->50%% @%.2fs, ->100%% @%.2fs\n', ...
    P.Tsim, P.t_softstart, P.t_load_off, P.t_load_on);
fprintf('================================================================\n');
fprintf(' Saved to: %s\n', mat_path);
fprintf('================================================================\n');

% 同时把 P 推送到 base 工作区，便于 build_model 直接引用变量
assignin('base', 'P', P);
