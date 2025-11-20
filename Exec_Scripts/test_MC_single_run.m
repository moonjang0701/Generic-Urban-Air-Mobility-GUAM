%% Test Single Monte Carlo Run
% Quick test to verify a single simulation works
% Use this to debug before running full Monte Carlo

clear all; close all; clc;

fprintf('═══════════════════════════════════════\n');
fprintf('  Single Monte Carlo Simulation Test\n');
fprintf('═══════════════════════════════════════\n\n');

%% Setup
cd(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath('lib'));
addpath(genpath('Exec_Scripts'));
addpath(genpath('Models'));
addpath(genpath('Utilities'));

fprintf('Working directory: %s\n', pwd);

%% Initialize GUAM
fprintf('Initializing GUAM...\n');
model = 'GUAM';
simSetup;
fprintf('  ✓ simSetup complete\n\n');

%% Generate reference trajectory
fprintf('Generating reference trajectory...\n');
ref_traj = generate_reference_trajectory(1000, 1000, 90, 30);
fprintf('  ✓ Trajectory generated\n\n');

%% Sample MC parameters (just 1 sample)
fprintf('Sampling MC parameters...\n');
MC_params = sample_MC_inputs(1, 20, 5, 10, 2, 0.2, 0.10, 5, 0.3);
fprintf('  ✓ Parameters sampled\n');
fprintf('    Wind E: %.2f m/s\n', MC_params.wind_E_ms(1));
fprintf('    Initial offset: %.2f m\n', MC_params.y0_m(1));
fprintf('    Heading error: %.2f deg\n\n', MC_params.heading_err_deg(1));

%% Run single simulation
fprintf('Running single GUAM simulation...\n');
fprintf('This may take 5-10 minutes...\n\n');

try
    % Extract parameters
    wind_E = MC_params.wind_E_ms(1);
    wind_N = MC_params.wind_N_ms(1);
    wind_D = MC_params.wind_D_ms(1);
    y0 = MC_params.y0_m(1);
    heading_err = MC_params.heading_err_deg(1);
    nse_sigma = MC_params.nse_sigma_m(1);
    
    fprintf('  Parameters extracted\n');
    
    % Configure GUAM
    evalin('base', 'userStruct.variants.refInputType = 3;');
    evalin('base', 'userStruct.variants.ctrlType = 2;');
    
    fprintf('  Variants configured\n');
    
    % Apply initial conditions
    ref_pos_modified = ref_traj.pos;
    ref_pos_modified(:, 2) = ref_pos_modified(:, 2) + y0;
    ref_chi_modified = ref_traj.chi + deg2rad(heading_err);
    
    fprintf('  Initial conditions applied\n');
    
    % Create RefInput
    RefInput.Vel_bIc_des = ref_traj.Vel_bIc_des;
    RefInput.pos_des = timeseries(ref_pos_modified, ref_traj.time);
    RefInput.chi_des = timeseries(ref_chi_modified, ref_traj.time);
    RefInput.chi_dot_des = ref_traj.chi_dot_des;
    RefInput.vel_des = ref_traj.vel_des;
    
    fprintf('  RefInput created\n');
    
    % Assign to base workspace
    assignin('base', 'RefInput', RefInput);
    evalin('base', 'target.RefInput = RefInput;');
    
    fprintf('  RefInput assigned to base\n');
    fprintf('  Running simSetup...\n');
    
    evalin('base', 'simSetup;');
    
    fprintf('  ✓ simSetup complete\n');
    
    % Apply wind
    apply_wind_to_GUAM(wind_N, wind_E, wind_D);
    
    fprintf('  Wind applied\n');
    
    % Run simulation
    evalin('base', sprintf('SimIn.StopTime = %.6f;', ref_traj.time(end)));
    
    fprintf('  Starting simulation...\n');
    tic;
    evalin('base', sprintf('sim(''%s'');', model));
    sim_time = toc;
    
    fprintf('  ✓ Simulation complete (%.1f seconds)\n\n', sim_time);
    
    % Extract results
    logsout = evalin('base', 'logsout');
    SimOut = logsout{1}.Values;
    
    % Extract time (from top-level Time field)
    time_sim = SimOut.Time.Data;
    
    % Extract position data (from Sensor.Pos_bIi - NED inertial position)
    pos_data = SimOut.Vehicle.Sensor.Pos_bIi.Data;
    N_actual = pos_data(:,1);  % North
    E_actual = pos_data(:,2);  % East  
    D_actual = pos_data(:,3);  % Down
    
    fprintf('  Results extracted\n');
    fprintf('    Time points: %d\n', length(time_sim));
    fprintf('    N range: [%.1f, %.1f] m\n', min(N_actual), max(N_actual));
    fprintf('    E range: [%.1f, %.1f] m\n', min(E_actual), max(E_actual));
    fprintf('    D range: [%.1f, %.1f] m\n\n', min(D_actual), max(D_actual));
    
    % Compute errors
    e_lateral = compute_lateral_error(N_actual, E_actual, ref_traj);
    nse = nse_sigma * randn(size(e_lateral));
    tse = compute_TSE(e_lateral, nse);
    d_min = compute_min_distance_to_boundary(E_actual, 350);
    
    fprintf('  Errors computed\n');
    fprintf('    Max lateral FTE: %.2f m\n', max(abs(e_lateral)));
    fprintf('    RMS lateral FTE: %.2f m\n', sqrt(mean(e_lateral.^2)));
    fprintf('    Max TSE: %.2f m\n', max(abs(tse)));
    fprintf('    Min distance to boundary: %.2f m\n\n', d_min);
    
    % Plot trajectory
    figure('Name', 'Test Trajectory', 'Position', [100 100 800 600]);
    plot(ref_traj.pos(:,1), ref_traj.pos(:,2), 'k--', 'LineWidth', 2, 'DisplayName', 'Reference');
    hold on;
    plot(N_actual, E_actual, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Actual');
    plot(ref_traj.pos(:,1), ref_traj.pos(:,2) + 350, 'r--', 'LineWidth', 1, 'DisplayName', 'Corridor');
    plot(ref_traj.pos(:,1), ref_traj.pos(:,2) - 350, 'r--', 'LineWidth', 1);
    xlabel('North (m)');
    ylabel('East (m)');
    title('Single Simulation Test');
    legend('Location', 'best');
    grid on;
    axis equal;
    
    fprintf('╔═══════════════════════════════════════╗\n');
    fprintf('║  ✓ TEST SUCCESSFUL                    ║\n');
    fprintf('║  Monte Carlo framework is working!    ║\n');
    fprintf('╚═══════════════════════════════════════╝\n\n');
    
    fprintf('Now you can run:\n');
    fprintf('  run_MC_TSE_safety_QUICK_TEST;  (10 samples)\n');
    fprintf('  run_MC_TSE_safety;              (500 samples)\n\n');
    
catch ME
    fprintf('\n╔═══════════════════════════════════════╗\n');
    fprintf('║  ✗ TEST FAILED                        ║\n');
    fprintf('╚═══════════════════════════════════════╝\n\n');
    fprintf('Error: %s\n', ME.message);
    fprintf('File: %s\n', ME.stack(1).file);
    fprintf('Line: %d\n\n', ME.stack(1).line);
    
    fprintf('Debug information:\n');
    fprintf('  Check that all helper functions are in path\n');
    fprintf('  Check that GUAM model loads correctly\n');
    fprintf('  Check simSetup output for errors\n\n');
    
    rethrow(ME);
end
