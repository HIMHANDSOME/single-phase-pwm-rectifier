%% main.m  —  单相 PWM 整流器仿真：一键运行总入口
% =========================================================================
% 功能：按"参数计算 → 建模并仿真 → 结果分析出图"的顺序，自动跑完整条流水线，
%       无需人工干预即可从零得到全部仿真波形与性能指标。
%
% 运行方式：
%   方式一（在 MATLAB 命令行）：
%       cd 'D:\Desktop\电力电子综合实验与设计\matlab'
%       addpath(genpath('code'))
%       main
%   方式二（在系统终端，无界面批处理）：
%       "D:\MATLAB 2024a\bin\matlab.exe" -batch "addpath(genpath('code')); main"
%
% 流水线三个阶段：
%   [1/3] params_calc    —— 计算并保存所有设计参数到 pwm_rectifier_params.mat
%   [2/3] run_simulation —— 调用 build_model 自动搭建 Simulink 模型并执行仿真
%   [3/3] analyze_results—— 读取仿真结果，计算 PF/THD/效率/纹波，输出 7 张图
%
% 依赖：MATLAB R2024a + Simulink + Simscape Electrical（Specialized Power Systems）
% =========================================================================

clear; clc;        % 清空工作区变量与命令行，保证每次运行环境干净一致

% --- 解析脚本所在目录，使脚本可在任意当前路径下被调用 ---
this_file = mfilename('fullpath');          % 当前脚本的完整路径（不含扩展名）
[code_dir,~,~] = fileparts(this_file);      % 取出 code/ 目录

% 将工具函数子目录 utils 加入搜索路径，否则 analyze_results 调用
% calc_pf / calc_thd / calc_efficiency 时会找不到函数。
addpath(fullfile(code_dir,'utils'));

fprintf('\n==============================================\n');
fprintf(' Single-Phase PWM Rectifier - Full Pipeline\n');
fprintf('==============================================\n');

% ---------- 阶段 1：参数计算 ----------
% 把课程设计指标（220V/400V/5kW 等）换算成可仿真的电路与控制参数，
% 结果存入结构体 P 并保存为 .mat，供后续阶段读取。
fprintf('\n[Step 1/3] Parameter calculation\n');
params_calc;

% ---------- 阶段 2：建模 + 仿真 ----------
% run_simulation 内部会先调用 build_model 程序化生成 .slx 模型，
% 再配置 ode23tb 求解器并执行 sim()，最后保存 simulation_results.mat。
fprintf('\n[Step 2/3] Build model & run simulation\n');
run_simulation;

% ---------- 阶段 3：结果分析 ----------
% 在稳态窗口内计算各项性能指标，并导出 7 张 PNG 波形图与 CSV 汇总表。
fprintf('\n[Step 3/3] Analyze results & generate figures\n');
analyze_results;

fprintf('\n==============================================\n');
fprintf(' Pipeline completed successfully.\n');
fprintf('==============================================\n');
