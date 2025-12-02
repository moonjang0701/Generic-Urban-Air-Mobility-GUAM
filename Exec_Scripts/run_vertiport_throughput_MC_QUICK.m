%% Vertiport Throughput Safety Assessment - QUICK TEST VERSION
% ========================================================================
% Quick test version with reduced parameters for fast validation
% ========================================================================

clear all; close all; clc;

fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  Vertiport Throughput Safety Assessment - QUICK TEST        ║\n');
fprintf('║  Target: 150 movements/hour | TSE Limit: 300m               ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════════
%% QUICK TEST PARAMETERS (Reduced for speed)
%% ═══════════════════════════════════════════════════════════════

% Test only ONE radius
R_AIRSPACE_M = 1500;  % meters

% Reduce Monte Carlo runs
N_MC_RUNS = 5;  % 5 runs instead of 50+

% Reduce movements per run
TARGET_THROUGHPUT_MVH = 150;
OPERATION_HOURS = 1;  % 1 hour instead of 8 (test subset)

% Other parameters (same as full version)
ALTITUDE_MIN_M = 300;
ALTITUDE_MAX_M = 600;
TSE_LIMIT_M = 300;
V_MEAN_MS = 50.0;
ARRIVAL_RATIO = 0.5;
WIND_MAX_KT = 20;
TURBULENCE_LEVELS = {'light', 'moderate', 'severe'};
TURBULENCE_PROB = [0.6, 0.3, 0.1];
RANDOM_SEED = 42;

fprintf('QUICK TEST Configuration:\n');
fprintf('  Airspace Radius: %.0f m\n', R_AIRSPACE_M);
fprintf('  MC Runs: %d\n', N_MC_RUNS);
fprintf('  Operation Time: %.0f hour\n', OPERATION_HOURS);
fprintf('  Expected Movements: %.0f\n', TARGET_THROUGHPUT_MVH * OPERATION_HOURS);
fprintf('  TSE Limit: %.0f m\n\n', TSE_LIMIT_M);

%% ═══════════════════════════════════════════════════════════════
%% INITIALIZATION
%% ═══════════════════════════════════════════════════════════════

fprintf('Initializing GUAM...\n');

script_dir = fileparts(mfilename('fullpath'));
guam_root = fileparts(script_dir);
cd(guam_root);

addpath(genpath('lib'));
addpath(genpath('Exec_Scripts'));
addpath(genpath('Utilities'));
addpath(genpath('Bez_Functions'));

model = 'GUAM';

fprintf('  ✓ GUAM initialized\n\n');

%% ═══════════════════════════════════════════════════════════════
%% SIMULATION LOOP
%% ═══════════════════════════════════════════════════════════════

fprintf('Running simulations...\n\n');

% Calculate flight parameters
R = R_AIRSPACE_M;
FLIGHT_TIME_S = R / V_MEAN_MS;
TOTAL_SIM_TIME_S = FLIGHT_TIME_S + 10;
OPERATION_TIME_S = OPERATION_HOURS * 3600;

fprintf('Flight time: %.1f s\n', FLIGHT_TIME_S);
fprintf('Simulation time: %.1f s\n\n', TOTAL_SIM_TIME_S);

% Initialize results
total_flights = 0;
safe_flights = 0;
unsafe_flights = 0;
tse_violations = 0;
altitude_violations = 0;
max_tse_all = [];
max_altitude_dev_all = [];

% Monte Carlo loop
rng(RANDOM_SEED);

for mc_run = 1:N_MC_RUNS
    fprintf('[MC %d/%d] ', mc_run, N_MC_RUNS);
    
    % Generate movements
    N_movements = round(TARGET_THROUGHPUT_MVH * OPERATION_HOURS);
    N_arrivals = round(N_movements * ARRIVAL_RATIO);
    N_departures = N_movements - N_arrivals;
    
    fprintf('Running %d movements (%d arr + %d dep)...\n', ...
        N_movements, N_arrivals, N_departures);
    
    % Create movement list
    movements = [];
    for mov_idx = 1:N_movements
        mov = struct();
        mov.id = mov_idx;
        
        if mov_idx <= N_arrivals
            mov.type = 'arrival';
        else
            mov.type = 'departure';
        end
        
        mov.theta_deg = rand() * 360;
        mov.theta_rad = deg2rad(mov.theta_deg);
        mov.x_boundary = R * cos(mov.theta_rad);
        mov.y_boundary = R * sin(mov.theta_rad);
        mov.t_start = rand() * OPERATION_TIME_S;
        mov.wind_speed_kt = rand() * WIND_MAX_KT;
        mov.wind_dir_deg = rand() * 360;
        
        turb_choice = randsample(1:3, 1, true, TURBULENCE_PROB);
        mov.turbulence = TURBULENCE_LEVELS{turb_choice};
        
        movements = [movements; mov];
    end
    
    [~, sort_idx] = sort([movements.t_start]);
    movements = movements(sort_idx);
    
    % Run each flight
    mc_safe = 0;
    mc_unsafe = 0;
    
    for mov_idx = 1:length(movements)
        mov = movements(mov_idx);
        
        fprintf('  Flight %d/%d: %s, wind=%.1fkt@%.0f°, turb=%s ... ', ...
            mov_idx, length(movements), mov.type, ...
            mov.wind_speed_kt, mov.wind_dir_deg, mov.turbulence);
        
        try
            [is_safe, max_tse, max_alt_dev] = run_single_flight_GUAM_simple(...
                mov, R, ALTITUDE_MIN_M, ALTITUDE_MAX_M, ...
                FLIGHT_TIME_S, TOTAL_SIM_TIME_S, TSE_LIMIT_M, model);
            
            total_flights = total_flights + 1;
            max_tse_all = [max_tse_all; max_tse];
            max_altitude_dev_all = [max_altitude_dev_all; max_alt_dev];
            
            if is_safe
                mc_safe = mc_safe + 1;
                safe_flights = safe_flights + 1;
                fprintf('SAFE (TSE=%.1fm)\n', max_tse);
            else
                mc_unsafe = mc_unsafe + 1;
                unsafe_flights = unsafe_flights + 1;
                fprintf('UNSAFE (TSE=%.1fm, Alt dev=%.1fm)\n', max_tse, max_alt_dev);
                
                if max_tse > TSE_LIMIT_M
                    tse_violations = tse_violations + 1;
                end
                if max_alt_dev > 0
                    altitude_violations = altitude_violations + 1;
                end
            end
            
        catch ME
            fprintf('FAILED: %s\n', ME.message);
            total_flights = total_flights + 1;
            unsafe_flights = unsafe_flights + 1;
            mc_unsafe = mc_unsafe + 1;
        end
    end
    
    fprintf('  MC %d Summary: %d safe, %d unsafe\n\n', mc_run, mc_safe, mc_unsafe);
end

%% ═══════════════════════════════════════════════════════════════
%% RESULTS
%% ═══════════════════════════════════════════════════════════════

fprintf('\n╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  QUICK TEST RESULTS                                          ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

P_safe = safe_flights / total_flights;
P_violation = unsafe_flights / total_flights;
mean_max_tse = mean(max_tse_all);
std_max_tse = std(max_tse_all);

fprintf('Total Flights: %d\n', total_flights);
fprintf('Safe Flights: %d (%.2f%%)\n', safe_flights, P_safe*100);
fprintf('Unsafe Flights: %d (%.2f%%)\n', unsafe_flights, P_violation*100);
fprintf('  - TSE Violations: %d\n', tse_violations);
fprintf('  - Altitude Violations: %d\n', altitude_violations);
fprintf('\n');
fprintf('TSE Statistics:\n');
fprintf('  Mean Max TSE: %.2f m\n', mean_max_tse);
fprintf('  Std Max TSE: %.2f m\n', std_max_tse);
fprintf('  Max TSE: %.2f m\n', max(max_tse_all));
fprintf('  Min TSE: %.2f m\n\n', min(max_tse_all));

% Simple plot
figure('Position', [100, 100, 800, 400]);
histogram(max_tse_all, 20, 'FaceColor', [0.3 0.6 0.9], 'EdgeColor', 'k');
hold on;
xline(TSE_LIMIT_M, 'r--', 'LineWidth', 2, 'Label', sprintf('Limit: %dm', TSE_LIMIT_M));
xlabel('Max TSE [m]', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Frequency', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('Quick Test: TSE Distribution (R=%.0fm, N=%d)', R, total_flights), ...
    'FontSize', 14, 'FontWeight', 'bold');
grid on;

saveas(gcf, 'Quick_Test_TSE_Distribution.png');
fprintf('Saved: Quick_Test_TSE_Distribution.png\n\n');

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('Quick test complete!\n');
fprintf('═══════════════════════════════════════════════════════════════\n');

%% ═══════════════════════════════════════════════════════════════
%% SIMPLIFIED HELPER FUNCTION
%% ═══════════════════════════════════════════════════════════════

function [is_safe, max_tse, max_altitude_dev] = run_single_flight_GUAM_simple(...
    movement, R, h_min, h_max, flight_time_s, total_sim_time_s, tse_limit, model)
    
    global SimIn userStruct target
    
    % Define trajectory
    if strcmp(movement.type, 'arrival')
        start_pos_NED = [movement.x_boundary, movement.y_boundary, -h_max];
        end_pos_NED = [0, 0, -h_min];
    else
        start_pos_NED = [0, 0, -h_min];
        end_pos_NED = [movement.x_boundary, movement.y_boundary, -h_max];
    end
    
    % Create Bezier waypoints
    waypoints_pos = {[start_pos_NED; start_pos_NED], ...
                     [start_pos_NED; end_pos_NED], ...
                     [end_pos_NED; end_pos_NED]};
    waypoints_time = [0, flight_time_s];
    
    % Setup userStruct
    userStruct = struct();
    userStruct.variants = struct();
    userStruct.variants.EnvironmentModel = 'IsaAtmosphere';
    userStruct.variants.TurbulenceModel = 'Dryden';
    userStruct.variants.WindModel = 'ConstantWind';
    userStruct.outputFname = '';
    userStruct.trajFile = '';
    
    % Setup target
    target = struct();
    target.RefInput = struct();
    target.RefInput.Bezier = struct();
    target.RefInput.Bezier.waypoints = waypoints_pos;
    target.RefInput.Bezier.time_wpts = waypoints_time;
    
    % Initial conditions
    [pos_i, vel_i, ~, chi, chid] = evalSegments(waypoints_pos{1}, waypoints_pos{2}, waypoints_pos{3}, ...
        waypoints_time(1), waypoints_time(2), waypoints_time(3), 0);
    
    Q_i2c = [cos(chi/2), 0*sin(chi/2), 0*sin(chi/2), sin(chi/2)]';
    target.RefInput.Vel_bIc_des = Qtrans(Q_i2c, vel_i);
    target.RefInput.pos_des = pos_i;
    target.RefInput.chi_des = chi;
    target.RefInput.chi_dot_des = chid;
    target.RefInput.trajectory.refTime = [0, flight_time_s];
    
    % Run simSetup
    simSetup;
    
    % Apply wind
    SimIn = apply_wind_to_GUAM(SimIn, movement.wind_speed_kt, movement.wind_dir_deg);
    
    % Apply turbulence
    SimIn = apply_turbulence_to_GUAM(SimIn, movement.turbulence);
    
    % Set stop time
    SimIn.stopTime = total_sim_time_s;
    
    % Run GUAM
    sim(model);
    
    % Extract data from base workspace
    logsout = evalin('base', 'logsout');
    
    % Get position data (X_NED = [North, East, Down] in feet)
    X_NED_data = logsout{1}.Values.X_NED;
    time = X_NED_data.Time;
    pos_NED_ft = X_NED_data.Data;  % [N, E, D] in feet
    
    % Convert feet to meters
    ft2m = 0.3048;
    pos_N = pos_NED_ft(:,1) * ft2m;
    pos_E = pos_NED_ft(:,2) * ft2m;
    pos_D = pos_NED_ft(:,3) * ft2m;
    altitude = -pos_D;
    
    % Reference trajectory
    ref_N = interp1([0, flight_time_s], [start_pos_NED(1), end_pos_NED(1)], time, 'linear', 'extrap');
    ref_E = interp1([0, flight_time_s], [start_pos_NED(2), end_pos_NED(2)], time, 'linear', 'extrap');
    
    % Compute TSE
    lateral_error = sqrt((pos_N - ref_N).^2 + (pos_E - ref_E).^2);
    max_tse = max(lateral_error);
    
    % Altitude violations
    altitude_below = max(0, h_min - altitude);
    altitude_above = max(0, altitude - h_max);
    max_altitude_dev = max([altitude_below; altitude_above]);
    
    % Safety check
    tse_safe = (max_tse <= tse_limit);
    altitude_safe = (max_altitude_dev == 0);
    is_safe = tse_safe && altitude_safe;
end
