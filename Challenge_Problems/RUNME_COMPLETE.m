% RUNME_COMPLETE.m - Complete demonstration of Challenge Problem with visualization
% This script loads a trajectory and failure scenario, runs the simulation,
% and visualizes the results.
%
% Enhanced version of RUNME.m that actually runs the simulation and shows results!
%
% Usage:
%   1. cd Challenge_Problems
%   2. RUNME_COMPLETE
%
% Based on original RUNME.m by Michael J. Acheson, NASA LaRC

clear all; close all; clc;

fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  GUAM Challenge Problem Demo - Complete Version             ║\n');
fprintf('║  Trajectory + Failure Scenario Simulation                   ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

%% User Configuration
traj_run_num = 1;    % Select trajectory number (1-3000) - Changed from 3 to 1 (more stable)
fail_run_num = 1;    % Select failure number (1-3000)
ENABLE_FAILURE = true;  % Set to false to run without failure

fprintf('Configuration:\n');
fprintf('  Trajectory #%d\n', traj_run_num);
fprintf('  Failure Scenario #%d\n', fail_run_num);
fprintf('  Failure Enabled: %s\n\n', mat2str(ENABLE_FAILURE));

%% Setup GUAM Variants
fprintf('═══ Step 1: Setting up GUAM variants ═══\n');
userStruct.variants.refInputType = 4; % 4=Piecewise Bezier
userStruct.variants.fmType      = 2; % 2=Polynomial
userStruct.variants.propType    = 4; % 4=First order with fail
userStruct.variants.actType     = 4; % 4=First order with fail
fprintf('  ✓ Variants configured\n\n');

%% Load Trajectory Data
fprintf('═══ Step 2: Loading trajectory data ═══\n');
file_obj = matfile('./Data_Set_1.mat');

wptsX_cell = file_obj.own_traj(traj_run_num,1);
wptsY_cell = file_obj.own_traj(traj_run_num,2);
wptsZ_cell = file_obj.own_traj(traj_run_num,3);
time_wptsX_cell = file_obj.own_traj(traj_run_num,4);
time_wptsY_cell = file_obj.own_traj(traj_run_num,5);
time_wptsZ_cell = file_obj.own_traj(traj_run_num,6);

target.RefInput.Bezier.waypoints = {wptsX_cell{1}, wptsY_cell{1}, wptsZ_cell{1}};
target.RefInput.Bezier.time_wpts = {time_wptsX_cell{1}, time_wptsY_cell{1}, time_wptsZ_cell{1}};

% Set initial conditions
target.RefInput.Vel_bIc_des    = [wptsX_cell{1}(1,2) wptsY_cell{1}(1,2) wptsZ_cell{1}(1,2)];
target.RefInput.pos_des        = [wptsX_cell{1}(1,1) wptsY_cell{1}(1,1) wptsZ_cell{1}(1,1)];
target.RefInput.chi_des        = atan2(wptsY_cell{1}(1,2),wptsX_cell{1}(1,2));
target.RefInput.chi_dot_des    = 0;
target.RefInput.trajectory.refTime = [0 time_wptsX_cell{1}(end)];

fprintf('  ✓ Trajectory loaded (%.1f seconds)\n\n', time_wptsX_cell{1}(end));

%% Initialize GUAM
fprintf('═══ Step 3: Initializing GUAM ═══\n');
cd('../');
simSetup;
model = 'GUAM';
fprintf('  ✓ GUAM initialized\n\n');

%% Load and Apply Failure Scenario
if ENABLE_FAILURE
    fprintf('═══ Step 4: Loading failure scenario ═══\n');
    fail_obj = matfile('./Challenge_Problems/Data_Set_4.mat');
    
    % Surface failures
    SimPar.Value.Fail.Surfaces.FailInit     = fail_obj.Surf_FailInit_Array(:, fail_run_num);
    SimPar.Value.Fail.Surfaces.InitTime     = fail_obj.Surf_InitTime_Array(:, fail_run_num);
    SimPar.Value.Fail.Surfaces.StopTime     = fail_obj.Surf_StopTime_Array(:, fail_run_num);
    SimPar.Value.Fail.Surfaces.PreScale     = fail_obj.Surf_PreScale_Array(:, fail_run_num);
    SimPar.Value.Fail.Surfaces.PostScale    = fail_obj.Surf_PostScale_Array(:, fail_run_num);
    
    % Propeller failures
    SimPar.Value.Fail.Props.FailInit    = fail_obj.Prop_FailInit_Array(:, fail_run_num);
    SimPar.Value.Fail.Props.InitTime    = fail_obj.Prop_InitTime_Array(:, fail_run_num);
    SimPar.Value.Fail.Props.StopTime    = fail_obj.Prop_StopTime_Array(:, fail_run_num);
    SimPar.Value.Fail.Props.PreScale    = fail_obj.Prop_PreScale_Array(:, fail_run_num);
    SimPar.Value.Fail.Props.PostScale   = fail_obj.Prop_PostScale_Array(:, fail_run_num);
    
    % Print failure info
    surf_failures = find(SimPar.Value.Fail.Surfaces.FailInit > 0);
    prop_failures = find(SimPar.Value.Fail.Props.FailInit > 0);
    
    if ~isempty(surf_failures)
        fprintf('  Surface failures:\n');
        for i = 1:length(surf_failures)
            idx = surf_failures(i);
            fprintf('    Surface #%d: Type %d at t=%.1fs\n', ...
                idx, SimPar.Value.Fail.Surfaces.FailInit(idx), ...
                SimPar.Value.Fail.Surfaces.InitTime(idx));
        end
    end
    
    if ~isempty(prop_failures)
        fprintf('  Propeller failures:\n');
        for i = 1:length(prop_failures)
            idx = prop_failures(i);
            fprintf('    Prop #%d: Type %d at t=%.1fs\n', ...
                idx, SimPar.Value.Fail.Props.FailInit(idx), ...
                SimPar.Value.Fail.Props.InitTime(idx));
        end
    end
    
    fprintf('  ✓ Failure scenario configured\n\n');
else
    fprintf('═══ Step 4: Failure scenario disabled ═══\n\n');
end

%% Run Simulation
fprintf('═══ Step 5: Running simulation ═══\n');
fprintf('  This may take 30-60 seconds...\n');

try
    tic;
    sim(model);
    elapsed = toc;
    fprintf('  ✓ Simulation completed in %.1f seconds\n\n', elapsed);
catch ME
    fprintf('  ✗ Simulation failed: %s\n', ME.message);
    fprintf('  Note: Some failure scenarios cause departure from flight\n');
    fprintf('  Try a different trajectory/failure number\n');
    return;
end

%% Extract Results
fprintf('═══ Step 6: Extracting results ═══\n');

try
    logsout = evalin('base', 'logsout');
    
    % Extract position (NED)
    X_NED_data = logsout{1}.Values.X_NED;
    time = X_NED_data.Time;
    pos_NED = X_NED_data.Data;  % [North, East, Down] in feet
    
    % Extract velocity
    Vb_data = logsout{1}.Values.Vb;
    vel_body = Vb_data.Data;  % [u, v, w] in ft/s
    
    % Extract attitude
    Euler_data = logsout{1}.Values.Euler;
    euler = Euler_data.Data;  % [roll, pitch, yaw] in radians
    
    fprintf('  ✓ Extracted %d data points (%.1f seconds)\n\n', length(time), time(end));
    
catch ME
    fprintf('  ✗ Data extraction failed: %s\n', ME.message);
    return;
end

%% Visualize Results
fprintf('═══ Step 7: Generating plots ═══\n');

% Create timestamp for saving
timestamp = datestr(now, 'yyyymmdd_HHMMSS');

%% Figure 1: 3D Trajectory
fprintf('  Creating 3D trajectory plot...\n');
fig1 = figure('Name', '3D Trajectory', 'Position', [100, 100, 1000, 800]);

plot3(pos_NED(:,1), pos_NED(:,2), -pos_NED(:,3), 'b-', 'LineWidth', 2);
hold on;
plot3(pos_NED(1,1), pos_NED(1,2), -pos_NED(1,3), 'go', 'MarkerSize', 15, 'LineWidth', 3);
plot3(pos_NED(end,1), pos_NED(end,2), -pos_NED(end,3), 'ro', 'MarkerSize', 15, 'LineWidth', 3);

% Mark failure time if applicable
if ENABLE_FAILURE && ~isempty(surf_failures)
    fail_time = min(SimPar.Value.Fail.Surfaces.InitTime(surf_failures));
    [~, fail_idx] = min(abs(time - fail_time));
    plot3(pos_NED(fail_idx,1), pos_NED(fail_idx,2), -pos_NED(fail_idx,3), ...
          'rx', 'MarkerSize', 20, 'LineWidth', 4);
    legend('Trajectory', 'Start', 'End', 'Failure Point', 'Location', 'best');
else
    legend('Trajectory', 'Start', 'End', 'Location', 'best');
end

xlabel('North (ft)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('East (ft)', 'FontSize', 12, 'FontWeight', 'bold');
zlabel('Altitude (ft)', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('3D Flight Trajectory (Scenario #%d)', traj_run_num), ...
      'FontSize', 14, 'FontWeight', 'bold');
grid on;
axis equal;
view(45, 30);

saveas(fig1, sprintf('../Challenge_Problems/Trajectory_3D_%s.png', timestamp));

%% Figure 2: Position vs Time
fprintf('  Creating position time history...\n');
fig2 = figure('Name', 'Position vs Time', 'Position', [150, 150, 1200, 800]);

subplot(3,1,1);
plot(time, pos_NED(:,1), 'b-', 'LineWidth', 2);
ylabel('North (ft)', 'FontSize', 11, 'FontWeight', 'bold');
title('Position Components vs Time', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

subplot(3,1,2);
plot(time, pos_NED(:,2), 'r-', 'LineWidth', 2);
ylabel('East (ft)', 'FontSize', 11, 'FontWeight', 'bold');
grid on;

subplot(3,1,3);
plot(time, -pos_NED(:,3), 'g-', 'LineWidth', 2);
ylabel('Altitude (ft)', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('Time (s)', 'FontSize', 11, 'FontWeight', 'bold');
grid on;

% Mark failure time
if ENABLE_FAILURE && ~isempty(surf_failures)
    fail_time = min(SimPar.Value.Fail.Surfaces.InitTime(surf_failures));
    for i = 1:3
        subplot(3,1,i);
        hold on;
        xline(fail_time, 'r--', 'LineWidth', 2, 'Label', 'Failure');
    end
end

saveas(fig2, sprintf('../Challenge_Problems/Position_Time_%s.png', timestamp));

%% Figure 3: Attitude vs Time
fprintf('  Creating attitude time history...\n');
fig3 = figure('Name', 'Attitude vs Time', 'Position', [200, 200, 1200, 800]);

subplot(3,1,1);
plot(time, rad2deg(euler(:,1)), 'b-', 'LineWidth', 2);
ylabel('Roll (deg)', 'FontSize', 11, 'FontWeight', 'bold');
title('Attitude vs Time', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

subplot(3,1,2);
plot(time, rad2deg(euler(:,2)), 'r-', 'LineWidth', 2);
ylabel('Pitch (deg)', 'FontSize', 11, 'FontWeight', 'bold');
grid on;

subplot(3,1,3);
plot(time, rad2deg(euler(:,3)), 'g-', 'LineWidth', 2);
ylabel('Yaw (deg)', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('Time (s)', 'FontSize', 11, 'FontWeight', 'bold');
grid on;

% Mark failure time
if ENABLE_FAILURE && ~isempty(surf_failures)
    fail_time = min(SimPar.Value.Fail.Surfaces.InitTime(surf_failures));
    for i = 1:3
        subplot(3,1,i);
        hold on;
        xline(fail_time, 'r--', 'LineWidth', 2, 'Label', 'Failure');
    end
end

saveas(fig3, sprintf('../Challenge_Problems/Attitude_Time_%s.png', timestamp));

%% Figure 4: Velocity vs Time
fprintf('  Creating velocity time history...\n');
fig4 = figure('Name', 'Velocity vs Time', 'Position', [250, 250, 1200, 600]);

subplot(2,1,1);
ground_speed = sqrt(vel_body(:,1).^2 + vel_body(:,2).^2);
plot(time, ground_speed * 0.592484, 'b-', 'LineWidth', 2);  % ft/s to knots
ylabel('Ground Speed (knots)', 'FontSize', 11, 'FontWeight', 'bold');
title('Velocity vs Time', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

subplot(2,1,2);
plot(time, -vel_body(:,3), 'r-', 'LineWidth', 2);
ylabel('Vertical Speed (ft/s)', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('Time (s)', 'FontSize', 11, 'FontWeight', 'bold');
grid on;

% Mark failure time
if ENABLE_FAILURE && ~isempty(surf_failures)
    fail_time = min(SimPar.Value.Fail.Surfaces.InitTime(surf_failures));
    for i = 1:2
        subplot(2,1,i);
        hold on;
        xline(fail_time, 'r--', 'LineWidth', 2, 'Label', 'Failure');
    end
end

saveas(fig4, sprintf('../Challenge_Problems/Velocity_Time_%s.png', timestamp));

fprintf('  ✓ All plots saved\n\n');

%% Summary
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  Simulation Complete!                                        ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

fprintf('Results saved:\n');
fprintf('  • Trajectory_3D_%s.png\n', timestamp);
fprintf('  • Position_Time_%s.png\n', timestamp);
fprintf('  • Attitude_Time_%s.png\n', timestamp);
fprintf('  • Velocity_Time_%s.png\n', timestamp);
fprintf('\n');

fprintf('Simulation Statistics:\n');
fprintf('  Total time: %.1f seconds\n', time(end));
fprintf('  Final altitude: %.1f ft\n', -pos_NED(end,3));
fprintf('  Distance traveled: %.1f ft (%.2f nm)\n', ...
    sqrt(pos_NED(end,1)^2 + pos_NED(end,2)^2), ...
    sqrt(pos_NED(end,1)^2 + pos_NED(end,2)^2) / 6076.12);
fprintf('  Average ground speed: %.1f knots\n', mean(ground_speed) * 0.592484);

if ENABLE_FAILURE
    fprintf('\nFailure Information:\n');
    if ~isempty(surf_failures)
        fprintf('  Surface failures: %d\n', length(surf_failures));
        fprintf('  First failure at: %.1f seconds\n', ...
            min(SimPar.Value.Fail.Surfaces.InitTime(surf_failures)));
    end
    if ~isempty(prop_failures)
        fprintf('  Propeller failures: %d\n', length(prop_failures));
        fprintf('  First failure at: %.1f seconds\n', ...
            min(SimPar.Value.Fail.Props.InitTime(prop_failures)));
    end
end

fprintf('\n════════════════════════════════════════════════════════════════\n');
fprintf('To run a different scenario, edit traj_run_num and fail_run_num\n');
fprintf('at the top of this script (valid range: 1-3000)\n');
fprintf('════════════════════════════════════════════════════════════════\n');
