%% run_simulation.m  —  加载参数、配置求解器、运行仿真、保存结果
% =========================================================================
% 功能：读取 params_calc 生成的参数，调用 build_model 程序化重建 Simulink
%       模型，配置变步长刚性求解器 ode23tb 并执行 sim()，最后把记录的
%       Vs/Is/Vdc/Idc/Vdc_ref 五路信号提取保存为 simulation_results.mat。
% 前置：需先运行 params_calc（main.m 已保证顺序）。
% 输出：matlab/results/data/simulation_results.mat（含结构体 R）
% =========================================================================

clear; clc;

% --- 路径解析 ---
this_file = mfilename('fullpath');
[code_dir,~,~] = fileparts(this_file);
proj_dir  = fileparts(code_dir);
model_dir = fullfile(proj_dir, 'model');
data_dir  = fullfile(proj_dir, 'results', 'data');
if ~exist(data_dir,'dir'); mkdir(data_dir); end

mdl       = 'pwm_rectifier';                        % 模型名
mdl_path  = fullfile(model_dir, [mdl '.slx']);      % 模型文件路径
params_mat= fullfile(model_dir, 'pwm_rectifier_params.mat');
result_mat= fullfile(data_dir,  'simulation_results.mat');

% --- 确保模型存在；并且总是重建以反映最新参数 ---
if ~exist(mdl_path,'file')
    fprintf('[run_simulation] Model not found, calling build_model...\n');
    build_model;
end
% 每次都重建：保证 params_calc 改过的参数能真正生效（避免用到旧 .slx）。
fprintf('[run_simulation] Rebuilding model with current parameters...\n');
build_model;

% --- 把参数结构体 P 载入 base 工作区（Simulink 模块从 base 读取变量）---
S = load(params_mat,'P');
assignin('base','P',S.P);

% --- 加载模型 ---
addpath(model_dir);
if bdIsLoaded(mdl); close_system(mdl,0); end        % 若已打开先关闭，避免冲突
load_system(mdl_path);

% --- 配置求解器（即使 build_model 已设过，这里再确认一遍）---
% 选 ode23tb：含 IGBT 开关的电力电子电路是刚性系统（μs 级开关瞬态与 ms~100ms
% 级电感电容动态并存），ode23tb（TR-BDF2 隐式）比 ode45 更稳更快。
set_param(mdl, ...
    'Solver',     'ode23tb', ...
    'SolverType', 'Variable-step', ...
    'MaxStep',    '1e-5', ...                        % 最大步长 10μs，保证 PWM 不被跳过
    'RelTol',     '1e-3', ...
    'AbsTol',     '1e-4', ...
    'StopTime',   num2str(S.P.Tsim));                % 仿真总时长 0.6s

% --- 执行仿真 ---
fprintf('[run_simulation] Starting simulation (Tsim = %.2fs)...\n', S.P.Tsim);
t0 = tic;
simOut = sim(mdl, 'SimulationMode','normal','ReturnWorkspaceOutputs','on');
elapsed = toc(t0);
fprintf('[run_simulation] Sim done in %.2f s.\n', elapsed);

% --- 提取记录信号（To Workspace 以"含时间的结构体"格式保存）---
sigs = {'Vs','Is','Vdc','Idc','Vdc_ref'};
R = struct();
for k = 1:numel(sigs)
    try
        sv = simOut.get(sigs{k});                    % 取出对应信号对象
        R.(sigs{k}).time   = sv.time;                % 时间向量
        R.(sigs{k}).signal = squeeze(sv.signals.values);  % 数值（压成列向量）
    catch ME
        warning('Signal %s not retrievable: %s', sigs{k}, ME.message);
    end
end
R.P    = S.P;                                        % 一并保存参数，便于分析阶段引用
R.Tsim = S.P.Tsim;
R.sim_elapsed = elapsed;

% --- 保存结果（-v7.3 支持 >2GB 的大数据）---
save(result_mat,'R','-v7.3');
fprintf('[run_simulation] Results saved to: %s\n', result_mat);

% --- 快速合理性检查：打印各信号的点数与极值 ---
fprintf('-----------------------------------\n');
for k = 1:numel(sigs)
    if isfield(R,sigs{k})
        s = R.(sigs{k}).signal;
        fprintf('  %-8s: N=%d, min=%+.3f, max=%+.3f, mean=%+.3f\n', ...
            sigs{k}, numel(s), min(s), max(s), mean(s));
    end
end
fprintf('-----------------------------------\n');

% --- 关闭模型 ---
close_system(mdl,0);
