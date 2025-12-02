%% Vertiport Airspace Throughput Safety Assessment (Monte Carlo + GUAM)
% ========================================================================
% Purpose: Evaluate vertiport airspace safety with target throughput
%          using real GUAM simulations for each flight with random 
%          wind/turbulence conditions
%
% Key Approach:
% - Target throughput: 150 movements/hour (arrivals + departures)
% - Each flight: Run actual GUAM simulation with randomized wind/turbulence
% - Extract real TSE from GUAM trajectory output
% - Check: Does TSE exceed 300m limit? Does altitude stay in 300-600m?
%
% Author: AI Assistant
% Date: 2025-12-02
% ========================================================================

clear all; close all; clc;

fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  Vertiport Airspace Throughput Safety Assessment            ║\n');
fprintf('║  Target: 150 movements/hour | TSE Limit: 300m               ║\n');
fprintf('║  Using NASA GUAM + Random Wind/Turbulence per Flight        ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════════
%% SECTION 1: INITIALIZATION
%% ═══════════════════════════════════════════════════════════════

fprintf('═══ SECTION 1: Initialization ═══\n\n');

% Navigate to GUAM root
script_dir = fileparts(mfilename('fullpath'));
guam_root = fileparts(script_dir);
cd(guam_root);

fprintf('Working directory: %s\n', pwd);

% Add paths
addpath(genpath('lib'));
addpath(genpath('Exec_Scripts'));
addpath(genpath('Utilities'));
addpath(genpath('Bez_Functions'));

% Initialize GUAM
model = 'GUAM';
fprintf('Initializing GUAM model...\n');

%% ═══════════════════════════════════════════════════════════════
%% SECTION 2: SCENARIO PARAMETERS
%% ═══════════════════════════════════════════════════════════════

fprintf('\n═══ SECTION 2: Scenario Configuration ═══\n\n');

% ───── Vertiport Airspace Parameters ─────
R_AIRSPACE_M = [1000, 1500, 2000];  % Test multiple airspace radii [m]
ALTITUDE_MIN_M = 300;                % Minimum altitude [m]
ALTITUDE_MAX_M = 600;                % Maximum altitude [m]
OPERATION_HOURS = 8;                 % Operating hours (09:00-17:00)
OPERATION_TIME_S = OPERATION_HOURS * 3600;  % Total time [s]

% ───── Throughput Parameters ─────
TARGET_THROUGHPUT_MVH = 150;         % movements/hour (이착륙 합산)
ARRIVAL_RATIO = 0.5;                 % 도착:출발 = 1:1

% ───── Flight Parameters ─────
V_MEAN_MS = 50.0;                    % Average ground speed [m/s]
SIMULATION_BUFFER_S = 10;            % Buffer time for each flight

% ───── Safety Criteria ─────
TSE_LIMIT_M = 300;                   % Lateral TSE limit [m]

% ───── Monte Carlo Parameters ─────
N_MC_RUNS = 50;                      % Monte Carlo runs (빠른 테스트용, 나중에 100+)
RANDOM_SEED = 42;

% ───── Wind/Turbulence Parameters (randomized per flight) ─────
WIND_MAX_KT = 20;                    % Maximum wind speed [kt]
TURBULENCE_LEVELS = {'light', 'moderate', 'severe'};
TURBULENCE_PROB = [0.6, 0.3, 0.1];   % Probability distribution

fprintf('Scenario Parameters:\n');
fprintf('  Airspace Radii: %s m\n', mat2str(R_AIRSPACE_M));
fprintf('  Altitude Range: %.0f - %.0f m\n', ALTITUDE_MIN_M, ALTITUDE_MAX_M);
fprintf('  Operation Time: %.0f hours (%.0f seconds)\n', OPERATION_HOURS, OPERATION_TIME_S);
fprintf('  Target Throughput: %.0f movements/hour\n', TARGET_THROUGHPUT_MVH);
fprintf('  Expected Movements per 8h: %.0f\n', TARGET_THROUGHPUT_MVH * OPERATION_HOURS);
fprintf('  TSE Limit: %.0f m\n', TSE_LIMIT_M);
fprintf('  Monte Carlo Runs: %d\n', N_MC_RUNS);
fprintf('  Wind Range: 0 - %.0f kt (omnidirectional)\n', WIND_MAX_KT);
fprintf('  Turbulence: Light (%.0f%%), Moderate (%.0f%%), Severe (%.0f%%)\n\n', ...
    TURBULENCE_PROB(1)*100, TURBULENCE_PROB(2)*100, TURBULENCE_PROB(3)*100);

%% ═══════════════════════════════════════════════════════════════
%% SECTION 3: MAIN SIMULATION LOOP (R × MC)
%% ═══════════════════════════════════════════════════════════════

fprintf('═══ SECTION 3: Running Simulations ═══\n\n');

% Storage for all results
all_results = struct();

for R_idx = 1:length(R_AIRSPACE_M)
    R = R_AIRSPACE_M(R_idx);
    
    fprintf('╔══════════════════════════════════════════════════════════╗\n');
    fprintf('║  Testing Airspace Radius: R = %.0f m                     \n', R);
    fprintf('╚══════════════════════════════════════════════════════════╝\n\n');
    
    % Calculate flight time for this radius
    FLIGHT_TIME_S = R / V_MEAN_MS;
    TOTAL_SIM_TIME_S = FLIGHT_TIME_S + SIMULATION_BUFFER_S;
    
    fprintf('  Flight time per leg: %.1f s\n', FLIGHT_TIME_S);
    fprintf('  Simulation time: %.1f s\n\n', TOTAL_SIM_TIME_S);
    
    % Initialize results for this R
    results_R = struct();
    results_R.R = R;
    results_R.total_flights = 0;
    results_R.safe_flights = 0;
    results_R.unsafe_flights = 0;
    results_R.tse_violations = 0;
    results_R.altitude_violations = 0;
    results_R.max_tse_all = [];
    results_R.max_altitude_dev_all = [];
    
    % Monte Carlo loop
    rng(RANDOM_SEED);
    
    for mc_run = 1:N_MC_RUNS
        fprintf('  [MC %d/%d] ', mc_run, N_MC_RUNS);
        
        % Calculate number of movements for this MC run
        N_movements = round(TARGET_THROUGHPUT_MVH * OPERATION_HOURS);
        N_arrivals = round(N_movements * ARRIVAL_RATIO);
        N_departures = N_movements - N_arrivals;
        
        fprintf('Running %d movements (%d arr + %d dep)...\n', ...
            N_movements, N_arrivals, N_departures);
        
        % Generate movements (arrivals + departures)
        movements = [];
        for mov_idx = 1:N_movements
            mov = struct();
            mov.id = mov_idx;
            
            % Determine type
            if mov_idx <= N_arrivals
                mov.type = 'arrival';
            else
                mov.type = 'departure';
            end
            
            % Random entry/exit direction (0-360 deg)
            mov.theta_deg = rand() * 360;
            mov.theta_rad = deg2rad(mov.theta_deg);
            
            % Boundary point (NED frame)
            mov.x_boundary = R * cos(mov.theta_rad);  % North
            mov.y_boundary = R * sin(mov.theta_rad);  % East
            
            % Random start time within operation window
            mov.t_start = rand() * OPERATION_TIME_S;
            
            % Random wind for this flight
            mov.wind_speed_kt = rand() * WIND_MAX_KT;
            mov.wind_dir_deg = rand() * 360;
            
            % Random turbulence level
            turb_choice = randsample(1:3, 1, true, TURBULENCE_PROB);
            mov.turbulence = TURBULENCE_LEVELS{turb_choice};
            
            movements = [movements; mov];
        end
        
        % Sort by start time
        [~, sort_idx] = sort([movements.t_start]);
        movements = movements(sort_idx);
        
        % Run GUAM for each movement
        mc_safe_count = 0;
        mc_unsafe_count = 0;
        mc_tse_viol_count = 0;
        mc_alt_viol_count = 0;
        
        for mov_idx = 1:length(movements)
            mov = movements(mov_idx);
            
            % Progress indicator (every 50 flights)
            if mod(mov_idx, 50) == 0
                fprintf('    Flight %d/%d...\n', mov_idx, length(movements));
            end
            
            try
                % Run GUAM simulation for this single flight
                [is_safe, max_tse, max_alt_dev] = run_single_flight_GUAM(...
                    mov, R, ALTITUDE_MIN_M, ALTITUDE_MAX_M, ...
                    FLIGHT_TIME_S, TOTAL_SIM_TIME_S, TSE_LIMIT_M, model);
                
                % Record results
                results_R.total_flights = results_R.total_flights + 1;
                results_R.max_tse_all = [results_R.max_tse_all; max_tse];
                results_R.max_altitude_dev_all = [results_R.max_altitude_dev_all; max_alt_dev];
                
                if is_safe
                    mc_safe_count = mc_safe_count + 1;
                    results_R.safe_flights = results_R.safe_flights + 1;
                else
                    mc_unsafe_count = mc_unsafe_count + 1;
                    results_R.unsafe_flights = results_R.unsafe_flights + 1;
                    
                    % Check violation type
                    if max_tse > TSE_LIMIT_M
                        mc_tse_viol_count = mc_tse_viol_count + 1;
                        results_R.tse_violations = results_R.tse_violations + 1;
                    end
                    if max_alt_dev > 0
                        mc_alt_viol_count = mc_alt_viol_count + 1;
                        results_R.altitude_violations = results_R.altitude_violations + 1;
                    end
                end
                
            catch ME
                fprintf('      Warning: Flight %d failed: %s\n', mov_idx, ME.message);
                % Count as unsafe
                results_R.total_flights = results_R.total_flights + 1;
                results_R.unsafe_flights = results_R.unsafe_flights + 1;
                mc_unsafe_count = mc_unsafe_count + 1;
            end
        end
        
        fprintf('    MC %d Complete: %d safe, %d unsafe (TSE: %d, Alt: %d)\n', ...
            mc_run, mc_safe_count, mc_unsafe_count, mc_tse_viol_count, mc_alt_viol_count);
    end
    
    % Calculate safety probability for this R
    results_R.P_safe = results_R.safe_flights / results_R.total_flights;
    results_R.P_violation = results_R.unsafe_flights / results_R.total_flights;
    results_R.mean_max_tse = mean(results_R.max_tse_all);
    results_R.std_max_tse = std(results_R.max_tse_all);
    
    % Store results
    all_results.(sprintf('R_%d', R)) = results_R;
    
    fprintf('\n  Summary for R = %.0f m:\n', R);
    fprintf('    Total Flights: %d\n', results_R.total_flights);
    fprintf('    Safe Flights: %d (%.2f%%)\n', results_R.safe_flights, results_R.P_safe*100);
    fprintf('    Unsafe Flights: %d (%.2f%%)\n', results_R.unsafe_flights, results_R.P_violation*100);
    fprintf('    TSE Violations: %d\n', results_R.tse_violations);
    fprintf('    Altitude Violations: %d\n', results_R.altitude_violations);
    fprintf('    Mean Max TSE: %.2f m\n', results_R.mean_max_tse);
    fprintf('    Std Max TSE: %.2f m\n\n', results_R.std_max_tse);
end

%% ═══════════════════════════════════════════════════════════════
%% SECTION 4: RESULTS VISUALIZATION
%% ═══════════════════════════════════════════════════════════════

fprintf('═══ SECTION 4: Generating Results ═══\n\n');

% Extract data for plotting
R_values = R_AIRSPACE_M;
P_safe_values = zeros(size(R_values));
P_violation_values = zeros(size(R_values));
mean_tse_values = zeros(size(R_values));

for i = 1:length(R_values)
    R = R_values(i);
    res = all_results.(sprintf('R_%d', R));
    P_safe_values(i) = res.P_safe;
    P_violation_values(i) = res.P_violation;
    mean_tse_values(i) = res.mean_max_tse;
end

% Figure 1: Safety Probability vs Radius
fig1 = figure('Position', [100, 100, 800, 600]);
subplot(2,1,1);
bar(R_values, P_safe_values*100, 'FaceColor', [0.2 0.8 0.2]);
hold on;
yline(80, 'r--', 'LineWidth', 2, 'Label', '80% Target');
xlabel('Airspace Radius R [m]', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Safety Probability [%]', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('Safety Assessment (Throughput = %d mvh/h)', TARGET_THROUGHPUT_MVH), ...
    'FontSize', 14, 'FontWeight', 'bold');
grid on;
ylim([0 100]);

subplot(2,1,2);
bar(R_values, P_violation_values*100, 'FaceColor', [0.8 0.2 0.2]);
hold on;
yline(20, 'r--', 'LineWidth', 2, 'Label', '20% Threshold');
xlabel('Airspace Radius R [m]', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Violation Probability [%]', 'FontSize', 12, 'FontWeight', 'bold');
title('TSE/Altitude Violation Probability', 'FontSize', 14, 'FontWeight', 'bold');
grid on;
ylim([0 100]);

saveas(fig1, 'Vertiport_Safety_Assessment.png');
fprintf('Saved: Vertiport_Safety_Assessment.png\n');

% Figure 2: TSE Distribution for each R
fig2 = figure('Position', [150, 150, 1200, 400]);
for i = 1:length(R_values)
    R = R_values(i);
    res = all_results.(sprintf('R_%d', R));
    
    subplot(1, length(R_values), i);
    histogram(res.max_tse_all, 30, 'FaceColor', [0.3 0.6 0.9], 'EdgeColor', 'k');
    hold on;
    xline(TSE_LIMIT_M, 'r--', 'LineWidth', 2, 'Label', sprintf('Limit: %dm', TSE_LIMIT_M));
    xlabel('Max TSE [m]', 'FontSize', 11, 'FontWeight', 'bold');
    ylabel('Frequency', 'FontSize', 11, 'FontWeight', 'bold');
    title(sprintf('R = %d m', R), 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
end

saveas(fig2, 'Vertiport_TSE_Distributions.png');
fprintf('Saved: Vertiport_TSE_Distributions.png\n');

%% ═══════════════════════════════════════════════════════════════
%% SECTION 5: FINAL REPORT
%% ═══════════════════════════════════════════════════════════════

fprintf('\n═══ SECTION 5: Final Report ═══\n\n');

fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  VERTIPORT THROUGHPUT SAFETY ASSESSMENT COMPLETE            ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

fprintf('Target Throughput: %d movements/hour\n', TARGET_THROUGHPUT_MVH);
fprintf('TSE Limit: %d m\n', TSE_LIMIT_M);
fprintf('Altitude Range: %d - %d m\n\n', ALTITUDE_MIN_M, ALTITUDE_MAX_M);

fprintf('Results Summary:\n');
fprintf('%-10s %-15s %-15s %-15s %-15s\n', 'R [m]', 'Total Flights', 'Unsafe', 'P(viol)', 'Mean TSE [m]');
fprintf('%-10s %-15s %-15s %-15s %-15s\n', repmat('-', 1, 10), repmat('-', 1, 15), ...
    repmat('-', 1, 15), repmat('-', 1, 15), repmat('-', 1, 15));

for i = 1:length(R_values)
    R = R_values(i);
    res = all_results.(sprintf('R_%d', R));
    fprintf('%-10d %-15d %-15d %-15.4f %-15.2f\n', ...
        R, res.total_flights, res.unsafe_flights, res.P_violation, res.mean_max_tse);
end

fprintf('\n═══════════════════════════════════════════════════════════════\n');
fprintf('Simulation complete!\n');
fprintf('═══════════════════════════════════════════════════════════════\n');

%% ═══════════════════════════════════════════════════════════════
%% HELPER FUNCTION: Run Single Flight with GUAM
%% ═══════════════════════════════════════════════════════════════

function [is_safe, max_tse, max_altitude_dev] = run_single_flight_GUAM(...
    movement, R, h_min, h_max, flight_time_s, total_sim_time_s, tse_limit, model)
    % Run GUAM simulation for a single flight with wind/turbulence
    %
    % Returns:
    %   is_safe: boolean (true if within TSE and altitude limits)
    %   max_tse: maximum lateral TSE [m]
    %   max_altitude_dev: maximum altitude deviation from limits [m]
    
    global SimIn userStruct target
    
    % Create reference trajectory
    if strcmp(movement.type, 'arrival')
        % Arrival: boundary → vertiport (0,0)
        start_pos_NED = [movement.x_boundary, movement.y_boundary, -h_max];
        end_pos_NED = [0, 0, -h_min];
    else
        % Departure: vertiport (0,0) → boundary
        start_pos_NED = [0, 0, -h_min];
        end_pos_NED = [movement.x_boundary, movement.y_boundary, -h_max];
    end
    
    % Create simple straight-line Bezier trajectory
    % (Using minimal Bezier structure for GUAM)
    waypoints_pos = {[start_pos_NED; start_pos_NED], ...
                     [start_pos_NED; end_pos_NED], ...
                     [end_pos_NED; end_pos_NED]};
    waypoints_time = [0, flight_time_s];
    
    % Setup userStruct for GUAM
    userStruct = struct();
    userStruct.variants = struct();
    userStruct.variants.EnvironmentModel = 'IsaAtmosphere';
    userStruct.variants.TurbulenceModel = 'Dryden';
    userStruct.variants.WindModel = 'ConstantWind';
    userStruct.outputFname = '';
    userStruct.trajFile = '';
    
    % Setup target trajectory
    target = struct();
    target.RefInput = struct();
    target.RefInput.Bezier = struct();
    target.RefInput.Bezier.waypoints = waypoints_pos;
    target.RefInput.Bezier.time_wpts = waypoints_time;
    
    % Initial conditions from first waypoint
    [pos_i, vel_i, ~, chi, chid] = evalSegments(waypoints_pos{1}, waypoints_pos{2}, waypoints_pos{3}, ...
        waypoints_time(1), waypoints_time(2), waypoints_time(3), 0);
    
    Q_i2c = [cos(chi/2), 0*sin(chi/2), 0*sin(chi/2), sin(chi/2)]';
    target.RefInput.Vel_bIc_des = Qtrans(Q_i2c, vel_i);
    target.RefInput.pos_des = pos_i;
    target.RefInput.chi_des = chi;
    target.RefInput.chi_dot_des = chid;
    target.RefInput.trajectory.refTime = [0, flight_time_s];
    
    % Setup simulation
    simSetup;
    
    % Apply wind (using helper function)
    SimIn = apply_wind_to_GUAM(SimIn, movement.wind_speed_kt, movement.wind_dir_deg);
    
    % Apply turbulence (using helper function)
    SimIn = apply_turbulence_to_GUAM(SimIn, movement.turbulence);
    
    % Set simulation stop time
    SimIn.stopTime = total_sim_time_s;
    
    % Run GUAM simulation
    simOut = sim(model, 'ReturnWorkspaceOutputs', 'on', 'StopTime', num2str(total_sim_time_s));
    
    % Extract trajectory from logsout
    logsout = simOut.logsout;
    
    % Get position data (NED frame)
    pos_data = logsout.getElement('Pos_bIi').Values;
    time = pos_data.Time;
    pos_N = pos_data.Data(:,1);  % North
    pos_E = pos_data.Data(:,2);  % East
    pos_D = pos_data.Data(:,3);  % Down (negative altitude)
    altitude = -pos_D;           % Convert to altitude (positive up)
    
    % Compute reference trajectory (linear interpolation)
    ref_N = interp1([0, flight_time_s], [start_pos_NED(1), end_pos_NED(1)], time, 'linear', 'extrap');
    ref_E = interp1([0, flight_time_s], [start_pos_NED(2), end_pos_NED(2)], time, 'linear', 'extrap');
    
    % Compute lateral TSE (Euclidean distance from reference in NE plane)
    lateral_error = sqrt((pos_N - ref_N).^2 + (pos_E - ref_E).^2);
    max_tse = max(lateral_error);
    
    % Check altitude violations
    altitude_below = max(0, h_min - altitude);  % How much below minimum
    altitude_above = max(0, altitude - h_max);  % How much above maximum
    max_altitude_dev = max([altitude_below; altitude_above]);
    
    % Determine safety
    tse_safe = (max_tse <= tse_limit);
    altitude_safe = (max_altitude_dev == 0);
    is_safe = tse_safe && altitude_safe;
end
