%% UAM Vertiport Throughput Safety Assessment using NASA GUAM
% This script evaluates vertiport airspace safety under target throughput
% of 150 movements/hour using actual GUAM simulation with random wind/turbulence
%
% Based on RUNME.m and exam_Bezier.m pattern
% Author: AI Assistant
% Date: 2025-12-02

clear all;
close all;
clc;

%% Add necessary paths
addpath('./Exec_Scripts/');
addpath('./Bez_Functions/');
addpath(genpath('lib'));

%% Simulation Parameters
model = 'GUAM';
userStruct.variants.refInputType = 4; % Piecewise Bezier

% Vertiport parameters
R_vertiport_m = 2000;  % Vertiport radius [m]
h_min_m = 300;         % Minimum altitude [m]
h_max_m = 600;         % Maximum altitude [m]
tse_limit_m = 300;     % TSE protection limit [m]

% Traffic parameters
lambda_mvh_per_hour = 150;  % Target throughput [movements/hour]
sim_duration_hours = 8;     % 09:00-17:00
N_total = round(sim_duration_hours * lambda_mvh_per_hour);
N_arrivals = round(N_total / 2);
N_departures = N_total - N_arrivals;

% Flight parameters
V_mean_ms = 50.0;      % Average ground speed [m/s]

% Wind/turbulence ranges
wind_speed_max_kt = 20;  % Max wind speed [knots]
turb_types = {'Light', 'Moderate', 'Severe'};

% Monte Carlo
N_mc = 5;  % Number of MC runs

fprintf('=== UAM Vertiport Throughput Safety Assessment ===\n');
fprintf('Target throughput: %d movements/hour\n', lambda_mvh_per_hour);
fprintf('Total flights: %d (%d arrivals + %d departures)\n', N_total, N_arrivals, N_departures);
fprintf('Vertiport radius: %.0f m\n', R_vertiport_m);
fprintf('Altitude range: %.0f-%.0f m\n', h_min_m, h_max_m);
fprintf('TSE limit: %.0f m\n', tse_limit_m);
fprintf('Monte Carlo runs: %d\n\n', N_mc);

%% Unit conversions
ft2m = 0.3048;
m2ft = 1 / ft2m;

%% Generate movements
movements = [];
fprintf('Generating %d movements...\n', N_total);

% Arrivals
for i = 1:N_arrivals
    movement = struct();
    movement.type = 'arrival';
    movement.target_time = rand() * (sim_duration_hours * 3600);  % [s]
    
    % Entry point on circle boundary
    entry_angle = rand() * 2 * pi;
    movement.entry_N = R_vertiport_m * cos(entry_angle);
    movement.entry_E = R_vertiport_m * sin(entry_angle);
    movement.entry_alt = h_min_m + rand() * (h_max_m - h_min_m);
    
    % Exit at vertiport center
    movement.exit_N = 0;
    movement.exit_E = 0;
    movement.exit_alt = 0;  % Landing
    
    movements = [movements; movement];
end

% Departures
for i = 1:N_departures
    movement = struct();
    movement.type = 'departure';
    movement.target_time = rand() * (sim_duration_hours * 3600);  % [s]
    
    % Entry at vertiport center
    movement.entry_N = 0;
    movement.entry_E = 0;
    movement.entry_alt = 0;  % Takeoff
    
    % Exit point on circle boundary
    exit_angle = rand() * 2 * pi;
    movement.exit_N = R_vertiport_m * cos(exit_angle);
    movement.exit_E = R_vertiport_m * sin(exit_angle);
    movement.exit_alt = h_min_m + rand() * (h_max_m - h_min_m);
    
    movements = [movements; movement];
end

% Sort by target time
[~, sort_idx] = sort([movements.target_time]);
movements = movements(sort_idx);

fprintf('Generated %d movements (sorted by time)\n\n', length(movements));

%% Monte Carlo Simulation
results = [];

for mc = 1:N_mc
    fprintf('\n========== Monte Carlo Run %d/%d ==========\n', mc, N_mc);
    
    mc_results = struct();
    mc_results.safe_count = 0;
    mc_results.unsafe_count = 0;
    mc_results.max_tse_list = [];
    mc_results.max_alt_dev_list = [];
    
    for flight_idx = 1:length(movements)
        movement = movements(flight_idx);
        
        % Random wind for this flight
        wind_speed_kt = rand() * wind_speed_max_kt;
        wind_dir_deg = rand() * 360;
        
        % Random turbulence
        turb_intensity = turb_types{randi(length(turb_types))};
        
        fprintf('Flight %d/%d: %s, Wind=%.1fkt@%.0fdeg, Turb=%s\n', ...
            flight_idx, length(movements), movement.type, wind_speed_kt, wind_dir_deg, turb_intensity);
        
        %% Setup trajectory using Bezier (following exam_Bezier.m pattern)
        
        % Start and end positions in NED (convert to feet for GUAM)
        start_N_ft = movement.entry_N * m2ft;
        start_E_ft = movement.entry_E * m2ft;
        start_D_ft = -movement.entry_alt * m2ft;  % NED: down is positive
        
        end_N_ft = movement.exit_N * m2ft;
        end_E_ft = movement.exit_E * m2ft;
        end_D_ft = -movement.exit_alt * m2ft;
        
        % Flight time
        dist_m = sqrt((movement.exit_N - movement.entry_N)^2 + ...
                      (movement.exit_E - movement.entry_E)^2);
        flight_time_s = max(dist_m / V_mean_ms, 10);  % Minimum 10s
        
        % Velocity (ft/s)
        vel_N_fts = (end_N_ft - start_N_ft) / flight_time_s;
        vel_E_fts = (end_E_ft - start_E_ft) / flight_time_s;
        vel_D_fts = (end_D_ft - start_D_ft) / flight_time_s;
        
        % Create Bezier waypoints (3 waypoints: start, mid, end)
        mid_time = flight_time_s / 2;
        
        % X (North) waypoints: [pos, vel, acc] for each waypoint
        wptsX = [start_N_ft, vel_N_fts, 0; 
                 start_N_ft + vel_N_fts * mid_time, vel_N_fts, 0;
                 end_N_ft, vel_N_fts, 0];
        time_wptsX = [0, mid_time, flight_time_s];
        
        % Y (East) waypoints
        wptsY = [start_E_ft, vel_E_fts, 0;
                 start_E_ft + vel_E_fts * mid_time, vel_E_fts, 0;
                 end_E_ft, vel_E_fts, 0];
        time_wptsY = [0, mid_time, flight_time_s];
        
        % Z (Down) waypoints
        wptsZ = [start_D_ft, vel_D_fts, 0;
                 start_D_ft + vel_D_fts * mid_time, vel_D_fts, 0;
                 end_D_ft, vel_D_fts, 0];
        time_wptsZ = [0, mid_time, flight_time_s];
        
        % Store in target structure (following exam_Bezier.m pattern)
        target.RefInput.Bezier.waypoints = {wptsX, wptsY, wptsZ};
        target.RefInput.Bezier.time_wpts = {time_wptsX, time_wptsY, time_wptsZ};
        
        % Initial conditions
        target.RefInput.Vel_bIc_des = [vel_N_fts; vel_E_fts; vel_D_fts];
        target.RefInput.pos_des = [start_N_ft; start_E_ft; start_D_ft];
        target.RefInput.chi_des = atan2(vel_E_fts, vel_N_fts);
        target.RefInput.chi_dot_des = 0;
        target.RefInput.trajectory.refTime = [0, flight_time_s];
        
        userStruct.trajFile = '';  % Use target structure, not file
        
        %% Setup simulation (following exam_Bezier.m → simSetup pattern)
        try
            simSetup;
            
            %% Apply wind (modify global SimInput variable created by simSetup)
            % Convert wind to NED components
            wind_speed_ms = wind_speed_kt * 0.514444;
            wind_from_rad = deg2rad(wind_dir_deg);
            wind_N_ms = -wind_speed_ms * cos(wind_from_rad);
            wind_E_ms = -wind_speed_ms * sin(wind_from_rad);
            wind_D_ms = 0;
            
            if exist('SimInput', 'var')
                SimInput.Environment.Winds.Vel_wHh = [wind_N_ms; wind_E_ms; wind_D_ms];
            end
            
            %% Apply turbulence (modify global SimIn variable)
            if exist('SimIn', 'var')
                SimIn.turbType = 1;  % 1 = Dryden turbulence
                
                % Map intensity
                switch turb_intensity
                    case 'Light'
                        SimInput.Environment.Turbulence.WindAt5kft = 15;
                    case 'Moderate'
                        SimInput.Environment.Turbulence.WindAt5kft = 30;
                    case 'Severe'
                        SimInput.Environment.Turbulence.WindAt5kft = 50;
                end
                
                % Random seeds
                turb_seed = randi([1000, 9999]);
                SimInput.Environment.Turbulence.RandomSeeds = [turb_seed, turb_seed+1000, turb_seed+2000, turb_seed+3000];
            end
            
            %% Run GUAM simulation (following RUNME.m pattern)
            sim(model);
            
            %% Extract results (following RUNME.m → simPlots_GUAM pattern)
            % logsout is global variable created by sim()
            if exist('logsout', 'var') && length(logsout) >= 1
                SimOut = logsout{1}.Values;
                
                % Extract position data
                time_sim = SimOut.Time.Data;
                pos_data_ft = SimOut.Vehicle.Sensor.Pos_bIi.Data;  % [N, E, D] in feet
                
                % Convert to meters
                pos_N_m = pos_data_ft(:,1) * ft2m;
                pos_E_m = pos_data_ft(:,2) * ft2m;
                pos_D_m = pos_data_ft(:,3) * ft2m;
                altitude_m = -pos_D_m;  % Altitude is negative of Down
                
                %% Compute TSE (lateral error from nominal)
                % Nominal trajectory (linear)
                ref_N_m = interp1([0, flight_time_s], [movement.entry_N, movement.exit_N], time_sim, 'linear', 'extrap');
                ref_E_m = interp1([0, flight_time_s], [movement.entry_E, movement.exit_E], time_sim, 'linear', 'extrap');
                
                lateral_error_m = sqrt((pos_N_m - ref_N_m).^2 + (pos_E_m - ref_E_m).^2);
                max_tse = max(lateral_error_m);
                
                %% Check altitude violations
                altitude_below = max(0, h_min_m - altitude_m);
                altitude_above = max(0, altitude_m - h_max_m);
                max_alt_dev = max([max(altitude_below); max(altitude_above)]);
                
                %% Safety check
                tse_safe = (max_tse <= tse_limit_m);
                alt_safe = (max_alt_dev == 0);
                is_safe = tse_safe && alt_safe;
                
                if is_safe
                    mc_results.safe_count = mc_results.safe_count + 1;
                    fprintf('  -> SAFE (TSE=%.1fm, Alt OK) ✓\n', max_tse);
                else
                    mc_results.unsafe_count = mc_results.unsafe_count + 1;
                    if ~tse_safe
                        fprintf('  -> UNSAFE (TSE=%.1fm > %.0fm) ✗\n', max_tse, tse_limit_m);
                    else
                        fprintf('  -> UNSAFE (Alt violation: %.1fm) ✗\n', max_alt_dev);
                    end
                end
                
                mc_results.max_tse_list = [mc_results.max_tse_list; max_tse];
                mc_results.max_alt_dev_list = [mc_results.max_alt_dev_list; max_alt_dev];
                
            else
                fprintf('  -> ERROR: logsout not available\n');
                mc_results.unsafe_count = mc_results.unsafe_count + 1;
                mc_results.max_tse_list = [mc_results.max_tse_list; NaN];
                mc_results.max_alt_dev_list = [mc_results.max_alt_dev_list; NaN];
            end
            
        catch ME
            fprintf('  -> SIMULATION FAILED: %s\n', ME.message);
            mc_results.unsafe_count = mc_results.unsafe_count + 1;
            mc_results.max_tse_list = [mc_results.max_tse_list; NaN];
            mc_results.max_alt_dev_list = [mc_results.max_alt_dev_list; NaN];
        end
        
    end
    
    % Store MC run results
    results = [results; mc_results];
    
    fprintf('\nMC Run %d Summary:\n', mc);
    fprintf('  Safe flights: %d/%d (%.1f%%)\n', mc_results.safe_count, length(movements), ...
        100 * mc_results.safe_count / length(movements));
    fprintf('  Mean Max TSE: %.1f m\n', nanmean(mc_results.max_tse_list));
    fprintf('  Max TSE: %.1f m\n', nanmax(mc_results.max_tse_list));
    
end

%% Final Results
fprintf('\n========== FINAL RESULTS ==========\n');
total_flights = N_mc * length(movements);
total_safe = sum([results.safe_count]);
total_unsafe = sum([results.unsafe_count]);
P_safe = total_safe / total_flights;
P_unsafe = total_unsafe / total_flights;

fprintf('Total flights simulated: %d\n', total_flights);
fprintf('Safe flights: %d (%.2f%%)\n', total_safe, P_safe * 100);
fprintf('Unsafe flights: %d (%.2f%%)\n', total_unsafe, P_unsafe * 100);
fprintf('P(TSE violation): %.4f\n', P_unsafe);

% TSE statistics
all_tse = [];
for i = 1:length(results)
    all_tse = [all_tse; results(i).max_tse_list];
end
fprintf('\nTSE Statistics:\n');
fprintf('  Mean: %.1f m\n', nanmean(all_tse));
fprintf('  Std: %.1f m\n', nanstd(all_tse));
fprintf('  Max: %.1f m\n', nanmax(all_tse));
fprintf('  95th percentile: %.1f m\n', prctile(all_tse, 95));

fprintf('\n========================================\n');
fprintf('Simulation completed successfully!\n');
