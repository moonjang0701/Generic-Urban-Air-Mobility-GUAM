% RUNME_COMPLETE_V2.m - Robust version that saves results even on simulation failure
% This version captures ALL information regardless of simulation success/failure
%
% Key improvements over V1:
%   - Saves scenario configuration BEFORE simulation
%   - Captures partial simulation results on failure
%   - Generates comprehensive log file with failure analysis
%   - Creates plots from partial data if available
%
% Usage:
%   1. cd Challenge_Problems
%   2. RUNME_COMPLETE_V2
%
% Based on original RUNME.m by Michael J. Acheson, NASA LaRC

clear all; close all; clc;

fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  GUAM Challenge Problem Demo - V2 (Robust Logging)          ║\n');
fprintf('║  Captures results even on simulation failure                ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

%% User Configuration
traj_run_num = 1;    % Select trajectory number (1-3000)
fail_run_num = 1;    % Select failure number (1-3000)
ENABLE_FAILURE = true;  % Set to false to run without failure

% Create results structure to store everything
results = struct();
results.config.traj_run_num = traj_run_num;
results.config.fail_run_num = fail_run_num;
results.config.enable_failure = ENABLE_FAILURE;
results.config.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
results.config.timestamp_file = datestr(now, 'yyyymmdd_HHMMSS');

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

results.config.variants = userStruct.variants;
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

% Store trajectory info
results.trajectory.duration = time_wptsX_cell{1}(end);
results.trajectory.initial_pos = target.RefInput.pos_des;
results.trajectory.initial_vel = target.RefInput.Vel_bIc_des;
results.trajectory.num_waypoints = [size(wptsX_cell{1},1), size(wptsY_cell{1},1), size(wptsZ_cell{1},1)];

fprintf('  ✓ Trajectory loaded (%.1f seconds)\n', time_wptsX_cell{1}(end));
fprintf('  Initial position: [%.1f, %.1f, %.1f] ft\n', ...
    target.RefInput.pos_des(1), target.RefInput.pos_des(2), target.RefInput.pos_des(3));
fprintf('  Initial velocity: [%.1f, %.1f, %.1f] ft/s\n\n', ...
    target.RefInput.Vel_bIc_des(1), target.RefInput.Vel_bIc_des(2), target.RefInput.Vel_bIc_des(3));

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
    
    % Store failure configuration
    results.failure.surfaces = SimPar.Value.Fail.Surfaces;
    results.failure.props = SimPar.Value.Fail.Props;
    
    % Find and print active failures
    surf_failures = find(SimPar.Value.Fail.Surfaces.FailInit > 0);
    prop_failures = find(SimPar.Value.Fail.Props.FailInit > 0);
    
    results.failure.active_surface_failures = surf_failures;
    results.failure.active_prop_failures = prop_failures;
    
    if ~isempty(surf_failures)
        fprintf('  Surface failures:\n');
        for i = 1:length(surf_failures)
            idx = surf_failures(i);
            fprintf('    Surface #%d: Type %d at t=%.1fs (stop=%.1fs, PreScale=%.2f, PostScale=%.2f)\n', ...
                idx, SimPar.Value.Fail.Surfaces.FailInit(idx), ...
                SimPar.Value.Fail.Surfaces.InitTime(idx), ...
                SimPar.Value.Fail.Surfaces.StopTime(idx), ...
                SimPar.Value.Fail.Surfaces.PreScale(idx), ...
                SimPar.Value.Fail.Surfaces.PostScale(idx));
        end
    end
    
    if ~isempty(prop_failures)
        fprintf('  Propeller failures:\n');
        for i = 1:length(prop_failures)
            idx = prop_failures(i);
            fprintf('    Prop #%d: Type %d at t=%.1fs (stop=%.1fs, PreScale=%.2f, PostScale=%.2f)\n', ...
                idx, SimPar.Value.Fail.Props.FailInit(idx), ...
                SimPar.Value.Fail.Props.InitTime(idx), ...
                SimPar.Value.Fail.Props.StopTime(idx), ...
                SimPar.Value.Fail.Props.PreScale(idx), ...
                SimPar.Value.Fail.Props.PostScale(idx));
        end
    end
    
    fprintf('  ✓ Failure scenario configured\n\n');
else
    fprintf('═══ Step 4: Failure scenario disabled ═══\n\n');
    results.failure = struct();
end

%% Save Configuration (BEFORE simulation)
config_filename = sprintf('./Challenge_Problems/sim_config_traj%d_fail%d_%s.mat', ...
    traj_run_num, fail_run_num, results.config.timestamp_file);
save(config_filename, 'results', '-v7.3');
fprintf('💾 Configuration saved: %s\n\n', config_filename);

%% Run Simulation
fprintf('═══ Step 5: Running simulation ═══\n');
fprintf('  This may take 30-60 seconds...\n');

simulation_success = false;
simulation_error = '';

try
    tic;
    out = sim(model);
    elapsed = toc;
    simulation_success = true;
    results.simulation.success = true;
    results.simulation.elapsed_time = elapsed;
    results.simulation.error = '';
    fprintf('  ✅ Simulation completed successfully in %.1f seconds\n\n', elapsed);
catch ME
    elapsed = toc;
    simulation_success = false;
    simulation_error = ME.message;
    results.simulation.success = false;
    results.simulation.elapsed_time = elapsed;
    results.simulation.error = ME.message;
    results.simulation.identifier = ME.identifier;
    results.simulation.stack = ME.stack;
    
    fprintf('  ❌ Simulation failed after %.1f seconds\n', elapsed);
    fprintf('  Error: %s\n', ME.message);
    fprintf('  Attempting to extract partial results...\n\n');
end

%% Extract Results (works for both success and partial failure)
fprintf('═══ Step 6: Extracting results ═══\n');

data_extracted = false;

try
    % Try to get logsout from workspace
    if evalin('base', 'exist(''logsout'', ''var'')')
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
        
        results.data.time = time;
        results.data.pos_NED = pos_NED;
        results.data.vel_body = vel_body;
        results.data.euler = euler;
        results.data.num_points = length(time);
        results.data.sim_time_reached = time(end);
        
        data_extracted = true;
        
        if simulation_success
            fprintf('  ✅ Extracted %d data points (%.1f seconds)\n\n', length(time), time(end));
        else
            fprintf('  ⚠️  Extracted PARTIAL data: %d points (%.1f / %.1f seconds)\n', ...
                length(time), time(end), results.trajectory.duration);
            fprintf('  Simulation stopped at %.1f%% completion\n\n', ...
                100 * time(end) / results.trajectory.duration);
        end
        
    else
        fprintf('  ❌ No logsout variable found in workspace\n\n');
        results.data = struct();
    end
    
catch ME
    fprintf('  ❌ Data extraction failed: %s\n\n', ME.message);
    results.data = struct();
end

%% Generate Plots
% Define timestamp for use throughout (whether data extracted or not)
timestamp = results.config.timestamp_file;

if data_extracted
    fprintf('═══ Step 7: Generating plots ═══\n');
    
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
        if fail_time <= time(end)
            [~, fail_idx] = min(abs(time - fail_time));
            plot3(pos_NED(fail_idx,1), pos_NED(fail_idx,2), -pos_NED(fail_idx,3), ...
                  'mx', 'MarkerSize', 20, 'LineWidth', 4);
            legend_entries = {'Trajectory', 'Start', 'End', 'Failure Start'};
        else
            legend_entries = {'Trajectory', 'Start', 'End'};
        end
    else
        legend_entries = {'Trajectory', 'Start', 'End'};
    end
    
    legend(legend_entries, 'Location', 'best');
    
    xlabel('North (ft)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('East (ft)', 'FontSize', 12, 'FontWeight', 'bold');
    zlabel('Altitude (ft)', 'FontSize', 12, 'FontWeight', 'bold');
    
    if simulation_success
        title_str = sprintf('3D Flight Trajectory (Scenario #%d)', traj_run_num);
    else
        title_str = sprintf('3D Trajectory (Scenario #%d) - PARTIAL (%.1f/%.1f s)', ...
            traj_run_num, time(end), results.trajectory.duration);
    end
    title(title_str, 'FontSize', 14, 'FontWeight', 'bold');
    
    grid on;
    axis equal;
    view(45, 30);
    
    saveas(fig1, sprintf('./Challenge_Problems/Traj3D_T%d_F%d_%s.png', ...
        traj_run_num, fail_run_num, timestamp));
    
    %% Figure 2: Position vs Time
    fprintf('  Creating position time history...\n');
    fig2 = figure('Name', 'Position vs Time', 'Position', [150, 150, 1200, 800]);
    
    subplot(3,1,1);
    plot(time, pos_NED(:,1), 'b-', 'LineWidth', 2);
    ylabel('North (ft)', 'FontSize', 11, 'FontWeight', 'bold');
    if simulation_success
        title('Position Components vs Time', 'FontSize', 12, 'FontWeight', 'bold');
    else
        title('Position vs Time - PARTIAL DATA', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'r');
    end
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
        if fail_time <= time(end)
            for i = 1:3
                subplot(3,1,i);
                hold on;
                xline(fail_time, 'r--', 'LineWidth', 2, 'Label', 'Failure');
            end
        end
    end
    
    saveas(fig2, sprintf('./Challenge_Problems/Position_T%d_F%d_%s.png', ...
        traj_run_num, fail_run_num, timestamp));
    
    %% Figure 3: Attitude vs Time
    fprintf('  Creating attitude time history...\n');
    fig3 = figure('Name', 'Attitude vs Time', 'Position', [200, 200, 1200, 800]);
    
    subplot(3,1,1);
    plot(time, rad2deg(euler(:,1)), 'b-', 'LineWidth', 2);
    ylabel('Roll (deg)', 'FontSize', 11, 'FontWeight', 'bold');
    if simulation_success
        title('Attitude vs Time', 'FontSize', 12, 'FontWeight', 'bold');
    else
        title('Attitude vs Time - PARTIAL DATA', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'r');
    end
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
        if fail_time <= time(end)
            for i = 1:3
                subplot(3,1,i);
                hold on;
                xline(fail_time, 'r--', 'LineWidth', 2, 'Label', 'Failure');
            end
        end
    end
    
    saveas(fig3, sprintf('./Challenge_Problems/Attitude_T%d_F%d_%s.png', ...
        traj_run_num, fail_run_num, timestamp));
    
    %% Figure 4: Velocity vs Time
    fprintf('  Creating velocity time history...\n');
    fig4 = figure('Name', 'Velocity vs Time', 'Position', [250, 250, 1200, 600]);
    
    subplot(2,1,1);
    ground_speed = sqrt(vel_body(:,1).^2 + vel_body(:,2).^2);
    plot(time, ground_speed * 0.592484, 'b-', 'LineWidth', 2);  % ft/s to knots
    ylabel('Ground Speed (knots)', 'FontSize', 11, 'FontWeight', 'bold');
    if simulation_success
        title('Velocity vs Time', 'FontSize', 12, 'FontWeight', 'bold');
    else
        title('Velocity vs Time - PARTIAL DATA', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'r');
    end
    grid on;
    
    subplot(2,1,2);
    plot(time, -vel_body(:,3), 'r-', 'LineWidth', 2);
    ylabel('Vertical Speed (ft/s)', 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('Time (s)', 'FontSize', 11, 'FontWeight', 'bold');
    grid on;
    
    % Mark failure time
    if ENABLE_FAILURE && ~isempty(surf_failures)
        fail_time = min(SimPar.Value.Fail.Surfaces.InitTime(surf_failures));
        if fail_time <= time(end)
            for i = 1:2
                subplot(2,1,i);
                hold on;
                xline(fail_time, 'r--', 'LineWidth', 2, 'Label', 'Failure');
            end
        end
    end
    
    saveas(fig4, sprintf('./Challenge_Problems/Velocity_T%d_F%d_%s.png', ...
        traj_run_num, fail_run_num, timestamp));
    
    fprintf('  ✅ All plots saved\n\n');
else
    fprintf('═══ Step 7: Skipping plots (no data available) ═══\n\n');
end

%% Save Complete Results
result_filename = sprintf('./Challenge_Problems/sim_results_traj%d_fail%d_%s.mat', ...
    traj_run_num, fail_run_num, timestamp);
save(result_filename, 'results', '-v7.3');
fprintf('💾 Complete results saved: %s\n\n', result_filename);

%% Generate Text Report
report_filename = sprintf('./Challenge_Problems/sim_report_traj%d_fail%d_%s.txt', ...
    traj_run_num, fail_run_num, timestamp);
fid = fopen(report_filename, 'w');

fprintf(fid, '════════════════════════════════════════════════════════════════\n');
fprintf(fid, 'GUAM CHALLENGE PROBLEM SIMULATION REPORT\n');
fprintf(fid, '════════════════════════════════════════════════════════════════\n\n');

fprintf(fid, 'Generated: %s\n\n', results.config.timestamp);

fprintf(fid, '--- CONFIGURATION ---\n');
fprintf(fid, 'Trajectory Number: %d\n', traj_run_num);
fprintf(fid, 'Failure Scenario: %d\n', fail_run_num);
fprintf(fid, 'Failure Enabled: %s\n\n', mat2str(ENABLE_FAILURE));

fprintf(fid, '--- TRAJECTORY INFO ---\n');
fprintf(fid, 'Planned Duration: %.1f seconds\n', results.trajectory.duration);
fprintf(fid, 'Initial Position: [%.1f, %.1f, %.1f] ft (NED)\n', ...
    results.trajectory.initial_pos(1), results.trajectory.initial_pos(2), results.trajectory.initial_pos(3));
fprintf(fid, 'Initial Velocity: [%.1f, %.1f, %.1f] ft/s\n', ...
    results.trajectory.initial_vel(1), results.trajectory.initial_vel(2), results.trajectory.initial_vel(3));
fprintf(fid, 'Waypoints: X=%d, Y=%d, Z=%d\n\n', ...
    results.trajectory.num_waypoints(1), results.trajectory.num_waypoints(2), results.trajectory.num_waypoints(3));

if ENABLE_FAILURE
    fprintf(fid, '--- FAILURE SCENARIO ---\n');
    if ~isempty(surf_failures)
        fprintf(fid, 'Surface Failures: %d active\n', length(surf_failures));
        for i = 1:length(surf_failures)
            idx = surf_failures(i);
            fprintf(fid, '  Surface #%d:\n', idx);
            fprintf(fid, '    Type: %d\n', SimPar.Value.Fail.Surfaces.FailInit(idx));
            fprintf(fid, '    Start Time: %.1f s\n', SimPar.Value.Fail.Surfaces.InitTime(idx));
            fprintf(fid, '    Stop Time: %.1f s\n', SimPar.Value.Fail.Surfaces.StopTime(idx));
            fprintf(fid, '    PreScale: %.3f\n', SimPar.Value.Fail.Surfaces.PreScale(idx));
            fprintf(fid, '    PostScale: %.3f\n', SimPar.Value.Fail.Surfaces.PostScale(idx));
        end
    end
    if ~isempty(prop_failures)
        fprintf(fid, 'Propeller Failures: %d active\n', length(prop_failures));
        for i = 1:length(prop_failures)
            idx = prop_failures(i);
            fprintf(fid, '  Prop #%d:\n', idx);
            fprintf(fid, '    Type: %d\n', SimPar.Value.Fail.Props.FailInit(idx));
            fprintf(fid, '    Start Time: %.1f s\n', SimPar.Value.Fail.Props.InitTime(idx));
            fprintf(fid, '    Stop Time: %.1f s\n', SimPar.Value.Fail.Props.StopTime(idx));
            fprintf(fid, '    PreScale: %.3f\n', SimPar.Value.Fail.Props.PreScale(idx));
            fprintf(fid, '    PostScale: %.3f\n', SimPar.Value.Fail.Props.PostScale(idx));
        end
    end
    fprintf(fid, '\n');
end

fprintf(fid, '--- SIMULATION RESULT ---\n');
if simulation_success
    fprintf(fid, 'Status: ✅ SUCCESS\n');
    fprintf(fid, 'Execution Time: %.1f seconds\n\n', results.simulation.elapsed_time);
else
    fprintf(fid, 'Status: ❌ FAILED\n');
    fprintf(fid, 'Execution Time: %.1f seconds\n', results.simulation.elapsed_time);
    fprintf(fid, 'Error: %s\n\n', simulation_error);
end

if data_extracted
    fprintf(fid, '--- DATA SUMMARY ---\n');
    fprintf(fid, 'Data Points Captured: %d\n', results.data.num_points);
    fprintf(fid, 'Simulation Time Reached: %.1f / %.1f seconds (%.1f%%)\n', ...
        results.data.sim_time_reached, results.trajectory.duration, ...
        100 * results.data.sim_time_reached / results.trajectory.duration);
    fprintf(fid, 'Final Position: [%.1f, %.1f, %.1f] ft\n', ...
        pos_NED(end,1), pos_NED(end,2), pos_NED(end,3));
    fprintf(fid, 'Final Altitude: %.1f ft\n', -pos_NED(end,3));
    fprintf(fid, 'Distance Traveled: %.1f ft (%.3f nm)\n', ...
        sqrt(pos_NED(end,1)^2 + pos_NED(end,2)^2), ...
        sqrt(pos_NED(end,1)^2 + pos_NED(end,2)^2) / 6076.12);
    fprintf(fid, 'Average Ground Speed: %.1f knots\n', mean(ground_speed) * 0.592484);
    fprintf(fid, 'Final Attitude: Roll=%.1f°, Pitch=%.1f°, Yaw=%.1f°\n', ...
        rad2deg(euler(end,1)), rad2deg(euler(end,2)), rad2deg(euler(end,3)));
else
    fprintf(fid, '--- DATA SUMMARY ---\n');
    fprintf(fid, 'No data captured (simulation failed before generating output)\n');
end

fprintf(fid, '\n--- FILES GENERATED ---\n');
fprintf(fid, 'Configuration: %s\n', config_filename);
fprintf(fid, 'Results: %s\n', result_filename);
fprintf(fid, 'Report: %s\n', report_filename);
if data_extracted
    fprintf(fid, 'Plot 1: Traj3D_T%d_F%d_%s.png\n', traj_run_num, fail_run_num, timestamp);
    fprintf(fid, 'Plot 2: Position_T%d_F%d_%s.png\n', traj_run_num, fail_run_num, timestamp);
    fprintf(fid, 'Plot 3: Attitude_T%d_F%d_%s.png\n', traj_run_num, fail_run_num, timestamp);
    fprintf(fid, 'Plot 4: Velocity_T%d_F%d_%s.png\n', traj_run_num, fail_run_num, timestamp);
end

fprintf(fid, '\n════════════════════════════════════════════════════════════════\n');

fclose(fid);
fprintf('📄 Text report saved: %s\n\n', report_filename);

%% Final Summary to Console
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
if simulation_success
    fprintf('║  ✅ SIMULATION COMPLETED SUCCESSFULLY                        ║\n');
else
    fprintf('║  ⚠️  SIMULATION FAILED (Partial results captured)            ║\n');
end
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

fprintf('📦 Generated Files:\n');
fprintf('   • Configuration: %s\n', config_filename);
fprintf('   • Results Data: %s\n', result_filename);
fprintf('   • Text Report: %s\n', report_filename);
if data_extracted
    fprintf('   • 3D Trajectory Plot\n');
    fprintf('   • Position Time History\n');
    fprintf('   • Attitude Time History\n');
    fprintf('   • Velocity Time History\n');
end

fprintf('\n📊 Summary:\n');
if simulation_success
    fprintf('   Status: SUCCESS ✅\n');
    fprintf('   Duration: %.1f / %.1f seconds (100%%)\n', time(end), results.trajectory.duration);
else
    fprintf('   Status: FAILED ❌\n');
    if data_extracted
        fprintf('   Duration: %.1f / %.1f seconds (%.1f%% completed)\n', ...
            time(end), results.trajectory.duration, 100*time(end)/results.trajectory.duration);
    else
        fprintf('   No data captured\n');
    end
    fprintf('   Error: %s\n', simulation_error);
end

if ENABLE_FAILURE && data_extracted
    fprintf('\n💥 Failure Info:\n');
    if ~isempty(surf_failures)
        fail_time = min(SimPar.Value.Fail.Surfaces.InitTime(surf_failures));
        fprintf('   Surface failure at: %.1f seconds\n', fail_time);
        if fail_time <= time(end)
            fprintf('   Flight continued for: %.1f seconds after failure\n', time(end) - fail_time);
        end
    end
    if ~isempty(prop_failures)
        fail_time = min(SimPar.Value.Fail.Props.InitTime(prop_failures));
        fprintf('   Propeller failure at: %.1f seconds\n', fail_time);
        if fail_time <= time(end)
            fprintf('   Flight continued for: %.1f seconds after failure\n', time(end) - fail_time);
        end
    end
end

fprintf('\n════════════════════════════════════════════════════════════════\n');
fprintf('💡 TIP: All configuration and results are saved even on failure!\n');
fprintf('    Check the .mat and .txt files for detailed information.\n');
fprintf('════════════════════════════════════════════════════════════════\n');
