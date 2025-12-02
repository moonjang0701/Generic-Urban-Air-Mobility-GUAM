%% UAM Vertiport Throughput Safety Assessment - QUICK TEST
% Quick version with only 5 flights for debugging
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

% Flight parameters
V_mean_ms = 50.0;      % Average ground speed [m/s]

% Wind/turbulence ranges
wind_speed_max_kt = 20;  % Max wind speed [knots]
turb_types = {'Light', 'Moderate', 'Severe'};

% QUICK TEST: Only 5 flights
N_flights = 5;

fprintf('=== UAM Vertiport Safety QUICK TEST ===\n');
fprintf('Test flights: %d\n', N_flights);
fprintf('Vertiport radius: %.0f m\n', R_vertiport_m);
fprintf('Altitude range: %.0f-%.0f m\n', h_min_m, h_max_m);
fprintf('TSE limit: %.0f m\n\n', tse_limit_m);

%% Unit conversions
ft2m = 0.3048;
m2ft = 1 / ft2m;

%% Generate test movements
movements = [];
fprintf('Generating %d test flights...\n', N_flights);

for i = 1:N_flights
    movement = struct();
    
    if mod(i, 2) == 1
        % Arrival
        movement.type = 'arrival';
        entry_angle = rand() * 2 * pi;
        movement.entry_N = R_vertiport_m * cos(entry_angle);
        movement.entry_E = R_vertiport_m * sin(entry_angle);
        movement.entry_alt = h_min_m + rand() * (h_max_m - h_min_m);
        movement.exit_N = 0;
        movement.exit_E = 0;
        movement.exit_alt = 0;
    else
        % Departure
        movement.type = 'departure';
        movement.entry_N = 0;
        movement.entry_E = 0;
        movement.entry_alt = 0;
        exit_angle = rand() * 2 * pi;
        movement.exit_N = R_vertiport_m * cos(exit_angle);
        movement.exit_E = R_vertiport_m * sin(exit_angle);
        movement.exit_alt = h_min_m + rand() * (h_max_m - h_min_m);
    end
    
    movements = [movements; movement];
end

fprintf('Generated %d test movements\n\n', length(movements));

%% Run test flights
safe_count = 0;
unsafe_count = 0;
max_tse_list = [];

for flight_idx = 1:length(movements)
    movement = movements(flight_idx);
    
    % Random wind
    wind_speed_kt = rand() * wind_speed_max_kt;
    wind_dir_deg = rand() * 360;
    
    % Random turbulence
    turb_intensity = turb_types{randi(length(turb_types))};
    
    fprintf('Flight %d/%d: %s, Wind=%.1fkt@%.0fdeg, Turb=%s\n', ...
        flight_idx, length(movements), movement.type, wind_speed_kt, wind_dir_deg, turb_intensity);
    
    %% Setup trajectory using Bezier
    
    % Start and end positions (convert to feet)
    start_N_ft = movement.entry_N * m2ft;
    start_E_ft = movement.entry_E * m2ft;
    start_D_ft = -movement.entry_alt * m2ft;
    
    end_N_ft = movement.exit_N * m2ft;
    end_E_ft = movement.exit_E * m2ft;
    end_D_ft = -movement.exit_alt * m2ft;
    
    % Flight time
    dist_m = sqrt((movement.exit_N - movement.entry_N)^2 + ...
                  (movement.exit_E - movement.entry_E)^2);
    flight_time_s = max(dist_m / V_mean_ms, 10);
    
    % Velocity (ft/s)
    vel_N_fts = (end_N_ft - start_N_ft) / flight_time_s;
    vel_E_fts = (end_E_ft - start_E_ft) / flight_time_s;
    vel_D_fts = (end_D_ft - start_D_ft) / flight_time_s;
    
    % Bezier waypoints (3 points)
    mid_time = flight_time_s / 2;
    
    wptsX = [start_N_ft, vel_N_fts, 0; 
             start_N_ft + vel_N_fts * mid_time, vel_N_fts, 0;
             end_N_ft, vel_N_fts, 0];
    time_wptsX = [0, mid_time, flight_time_s];
    
    wptsY = [start_E_ft, vel_E_fts, 0;
             start_E_ft + vel_E_fts * mid_time, vel_E_fts, 0;
             end_E_ft, vel_E_fts, 0];
    time_wptsY = [0, mid_time, flight_time_s];
    
    wptsZ = [start_D_ft, vel_D_fts, 0;
             start_D_ft + vel_D_fts * mid_time, vel_D_fts, 0;
             end_D_ft, vel_D_fts, 0];
    time_wptsZ = [0, mid_time, flight_time_s];
    
    % Store in target structure
    target.RefInput.Bezier.waypoints = {wptsX, wptsY, wptsZ};
    target.RefInput.Bezier.time_wpts = {time_wptsX, time_wptsY, time_wptsZ};
    
    % Initial conditions
    target.RefInput.Vel_bIc_des = [vel_N_fts; vel_E_fts; vel_D_fts];
    target.RefInput.pos_des = [start_N_ft; start_E_ft; start_D_ft];
    target.RefInput.chi_des = atan2(vel_E_fts, vel_N_fts);
    target.RefInput.chi_dot_des = 0;
    target.RefInput.trajectory.refTime = [0, flight_time_s];
    
    userStruct.trajFile = '';
    
    %% Run simulation
    try
        simSetup;
        
        % Apply wind
        wind_speed_ms = wind_speed_kt * 0.514444;
        wind_from_rad = deg2rad(wind_dir_deg);
        wind_N_ms = -wind_speed_ms * cos(wind_from_rad);
        wind_E_ms = -wind_speed_ms * sin(wind_from_rad);
        wind_D_ms = 0;
        
        if exist('SimInput', 'var')
            SimInput.Environment.Winds.Vel_wHh = [wind_N_ms; wind_E_ms; wind_D_ms];
        end
        
        % Apply turbulence
        if exist('SimIn', 'var')
            SimIn.turbType = 1;
            switch turb_intensity
                case 'Light'
                    SimInput.Environment.Turbulence.WindAt5kft = 15;
                case 'Moderate'
                    SimInput.Environment.Turbulence.WindAt5kft = 30;
                case 'Severe'
                    SimInput.Environment.Turbulence.WindAt5kft = 50;
            end
            turb_seed = randi([1000, 9999]);
            SimInput.Environment.Turbulence.RandomSeeds = [turb_seed, turb_seed+1000, turb_seed+2000, turb_seed+3000];
        end
        
        % Run GUAM
        sim(model);
        
        % Extract results
        if exist('logsout', 'var') && length(logsout) >= 1
            SimOut = logsout{1}.Values;
            
            time_sim = SimOut.Time.Data;
            pos_data_ft = SimOut.Vehicle.Sensor.Pos_bIi.Data;
            
            pos_N_m = pos_data_ft(:,1) * ft2m;
            pos_E_m = pos_data_ft(:,2) * ft2m;
            pos_D_m = pos_data_ft(:,3) * ft2m;
            altitude_m = -pos_D_m;
            
            % TSE
            ref_N_m = interp1([0, flight_time_s], [movement.entry_N, movement.exit_N], time_sim, 'linear', 'extrap');
            ref_E_m = interp1([0, flight_time_s], [movement.entry_E, movement.exit_E], time_sim, 'linear', 'extrap');
            lateral_error_m = sqrt((pos_N_m - ref_N_m).^2 + (pos_E_m - ref_E_m).^2);
            max_tse = max(lateral_error_m);
            
            % Altitude check
            altitude_below = max(0, h_min_m - altitude_m);
            altitude_above = max(0, altitude_m - h_max_m);
            max_alt_dev = max([max(altitude_below); max(altitude_above)]);
            
            % Safety
            tse_safe = (max_tse <= tse_limit_m);
            alt_safe = (max_alt_dev == 0);
            is_safe = tse_safe && alt_safe;
            
            if is_safe
                safe_count = safe_count + 1;
                fprintf('  -> SAFE (TSE=%.1fm, Alt OK) ✓\n', max_tse);
            else
                unsafe_count = unsafe_count + 1;
                if ~tse_safe
                    fprintf('  -> UNSAFE (TSE=%.1fm > %.0fm) ✗\n', max_tse, tse_limit_m);
                else
                    fprintf('  -> UNSAFE (Alt violation: %.1fm) ✗\n', max_alt_dev);
                end
            end
            
            max_tse_list = [max_tse_list; max_tse];
        else
            fprintf('  -> ERROR: logsout not available\n');
            unsafe_count = unsafe_count + 1;
        end
        
    catch ME
        fprintf('  -> SIMULATION FAILED: %s\n', ME.message);
        unsafe_count = unsafe_count + 1;
    end
end

%% Results
fprintf('\n========== QUICK TEST RESULTS ==========\n');
fprintf('Total flights: %d\n', N_flights);
fprintf('Safe: %d (%.1f%%)\n', safe_count, 100 * safe_count / N_flights);
fprintf('Unsafe: %d (%.1f%%)\n', unsafe_count, 100 * unsafe_count / N_flights);
if ~isempty(max_tse_list)
    fprintf('Mean Max TSE: %.1f m\n', mean(max_tse_list));
    fprintf('Max TSE: %.1f m\n', max(max_tse_list));
end
fprintf('========================================\n');
