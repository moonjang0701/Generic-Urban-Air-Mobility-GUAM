%% UAM Vertiport Airspace Throughput Safety Assessment
% Using NASA GUAM with Official Timeseries Trajectory Pattern
% Based on exam_TS_Sinusoidal_traj.m (official GUAM example)
%
% Target: 150 movements/hour throughput evaluation
% Method: Direct GUAM execution with random wind/turbulence per flight
% Output: P(TSE violation), P(altitude violation)

clear; clc; close all;

%% ========================================================================
%  SIMULATION PARAMETERS
%  ========================================================================
model = 'GUAM';
userStruct.variants.refInputType = 3;  % Timeseries (official pattern)

% Target throughput
lambda_target = 150;  % movements/hour
sim_duration_hours = 8;
N_flights = round(lambda_target * sim_duration_hours);  % 1200 flights

% Airspace parameters
R_vertiport = 2000;  % meters (vertiport radius)
h_min = 300;  % meters (minimum altitude)
h_max = 600;  % meters (maximum altitude)
tse_limit = 300;  % meters (TSE protection)

% Flight parameters
V_mean = 50;  % m/s (average ground speed)

% Wind parameters (random per flight)
W_MAX_KT = 20;  % knots (max wind speed)

% Turbulence intensities
turb_options = {'Light', 'Moderate', 'Severe'};

% Convert to feet (GUAM uses feet)
ft2m = 0.3048;
m2ft = 1 / ft2m;
h_min_ft = h_min * m2ft;
h_max_ft = h_max * m2ft;
R_vertiport_ft = R_vertiport * m2ft;

% Add required paths
addpath(genpath('lib'));
addpath('./Exec_Scripts/');

fprintf('=============================================================\n');
fprintf(' UAM VERTIPORT AIRSPACE THROUGHPUT SAFETY ASSESSMENT\n');
fprintf(' Using NASA GUAM (Official Timeseries Pattern)\n');
fprintf('=============================================================\n');
fprintf('Target Throughput: %d movements/hour\n', lambda_target);
fprintf('Simulation Duration: %.1f hours\n', sim_duration_hours);
fprintf('Total Flights: %d\n', N_flights);
fprintf('Vertiport Radius: %.0f m\n', R_vertiport);
fprintf('Altitude Range: %.0f - %.0f m\n', h_min, h_max);
fprintf('TSE Limit: %.0f m\n', tse_limit);
fprintf('Average Speed: %.1f m/s\n', V_mean);
fprintf('Max Wind: %.1f kt\n', W_MAX_KT);
fprintf('=============================================================\n\n');

%% ========================================================================
%  GENERATE FLIGHT MOVEMENTS
%  ========================================================================
fprintf('Generating %d flight movements...\n', N_flights);

movements = struct('type', {}, 'time', {}, 'angle', {}, ...
                   'wind_speed_kt', {}, 'wind_dir_deg', {}, ...
                   'turbulence', {});

for i = 1:N_flights
    % Alternate between arrival and departure
    if mod(i, 2) == 1
        movements(i).type = 'arrival';
    else
        movements(i).type = 'departure';
    end
    
    % Random time within 8 hours
    movements(i).time = rand() * sim_duration_hours * 3600;  % seconds
    
    % Random entry/exit angle (0-360 degrees)
    movements(i).angle = rand() * 360;
    
    % Random wind per flight
    movements(i).wind_speed_kt = rand() * W_MAX_KT;
    movements(i).wind_dir_deg = rand() * 360;
    
    % Random turbulence intensity
    movements(i).turbulence = turb_options{randi(length(turb_options))};
end

fprintf('Flight generation complete.\n\n');

%% ========================================================================
%  RUN MONTE CARLO SIMULATION
%  ========================================================================
fprintf('Starting GUAM Monte Carlo simulation...\n');
fprintf('-------------------------------------------------------------\n');

% Results storage
results = struct('flight_id', {}, 'type', {}, 'success', {}, ...
                 'max_tse_m', {}, 'altitude_ok', {}, 'safe', {});

n_safe = 0;
n_unsafe = 0;
n_failed = 0;

for i = 1:N_flights
    fprintf('Flight %d/%d: %s ', i, N_flights, upper(movements(i).type(1:3)));
    
    try
        % ====================================================================
        % SETUP TRAJECTORY (Official GUAM Timeseries Pattern)
        % ====================================================================
        
        % Boundary position
        angle_rad = deg2rad(movements(i).angle);
        x_boundary = R_vertiport_ft * cos(angle_rad);
        y_boundary = R_vertiport_ft * sin(angle_rad);
        
        % Define start and end positions (NED frame, in feet)
        if strcmp(movements(i).type, 'arrival')
            pos_start = [x_boundary; y_boundary; -h_max_ft];  % Start at boundary, high alt
            pos_end = [0; 0; -h_min_ft];  % End at vertiport, low alt
        else
            pos_start = [0; 0; -h_min_ft];  % Start at vertiport, low alt
            pos_end = [x_boundary; y_boundary; -h_max_ft];  % End at boundary, high alt
        end
        
        % Compute flight distance and time
        distance_ft = norm(pos_end - pos_start);
        V_mean_fts = V_mean * m2ft;  % m/s to ft/s
        flight_time_s = distance_ft / V_mean_fts;
        
        % Create time vector (1 Hz sampling)
        dt = 1.0;  % seconds
        time = (0:dt:flight_time_s)';
        N_time = length(time);
        
        % Linear interpolation for position trajectory
        pos = zeros(3, N_time)';
        for j = 1:N_time
            alpha = time(j) / flight_time_s;
            pos(j, :) = ((1 - alpha) * pos_start + alpha * pos_end)';
        end
        
        % Compute velocity (inertial frame)
        vel_i = zeros(3, N_time)';
        vel_i(:, 1) = gradient(pos(:, 1)) ./ gradient(time);
        vel_i(:, 2) = gradient(pos(:, 2)) ./ gradient(time);
        vel_i(:, 3) = gradient(pos(:, 3)) ./ gradient(time);
        
        % Compute heading
        chi = atan2(vel_i(:, 2), vel_i(:, 1));
        chid = gradient(chi) ./ gradient(time);
        
        % Compute velocity in heading frame
        q = QrotZ(chi);
        vel = Qtrans(q, vel_i);
        
        % Setup trajectory to match bus (OFFICIAL PATTERN)
        RefInput.Vel_bIc_des = timeseries(vel, time);
        RefInput.pos_des = timeseries(pos, time);
        RefInput.chi_des = timeseries(chi, time);
        RefInput.chi_dot_des = timeseries(chid, time);
        RefInput.vel_des = timeseries(vel_i, time);
        
        target.RefInput = RefInput;
        
        % ====================================================================
        % RUN SIMULATION (Official GUAM Pattern)
        % ====================================================================
        
        % Set initial conditions and add trajectory to SimInput
        simSetup;
        
        % Apply wind disturbance
        wind_speed_ms = movements(i).wind_speed_kt * 0.514444;
        wind_from_rad = deg2rad(movements(i).wind_dir_deg);
        wind_N_ms = -wind_speed_ms * cos(wind_from_rad);
        wind_E_ms = -wind_speed_ms * sin(wind_from_rad);
        wind_D_ms = 0;
        
        % Set wind in SimInput (must exist after simSetup)
        SimInput.Environment.Winds.Vel_wHh = [wind_N_ms; wind_E_ms; wind_D_ms];
        
        % Apply turbulence
        turb_intensity = movements(i).turbulence;
        switch turb_intensity
            case 'Light'
                SimIn.turbType = 1;
                SimInput.Environment.Turbulence.WindAt5kft = 15;
            case 'Moderate'
                SimIn.turbType = 1;
                SimInput.Environment.Turbulence.WindAt5kft = 30;
            case 'Severe'
                SimIn.turbType = 1;
                SimInput.Environment.Turbulence.WindAt5kft = 50;
            otherwise
                SimIn.turbType = 0;  % No turbulence
        end
        
        % Set random seeds for turbulence
        turb_seed = randi([1000, 9999]);
        SimInput.Environment.Turbulence.RandomSeeds = [turb_seed, turb_seed+1000, turb_seed+2000, turb_seed+3000];
        
        % Set stop time
        SimIn.StopTime = flight_time_s + 5;  % Add 5s buffer
        
        % Execute the model (OFFICIAL PATTERN)
        sim(model);
        
        % ====================================================================
        % EXTRACT RESULTS AND EVALUATE SAFETY
        % ====================================================================
        
        % Extract trajectory (standard GUAM output)
        SimOut = logsout{1}.Values;
        time_sim = SimOut.Time.Data;
        pos_actual_ft = SimOut.Vehicle.Sensor.Pos_bIi.Data;  % [N, E, D] in feet
        
        % Convert to meters
        pos_actual_m = pos_actual_ft * ft2m;
        N_actual = pos_actual_m(:, 1);
        E_actual = pos_actual_m(:, 2);
        D_actual = pos_actual_m(:, 3);
        altitude_m = -D_actual;
        
        % Reference trajectory (linear interpolation)
        pos_ref_ft = interp1(time, pos, time_sim, 'linear', 'extrap');
        pos_ref_m = pos_ref_ft * ft2m;
        N_ref = pos_ref_m(:, 1);
        E_ref = pos_ref_m(:, 2);
        
        % Compute TSE (lateral error)
        lateral_error = sqrt((N_actual - N_ref).^2 + (E_actual - E_ref).^2);
        max_tse = max(lateral_error);
        
        % Check altitude violations
        altitude_below = max(0, h_min - altitude_m);
        altitude_above = max(0, altitude_m - h_max);
        max_altitude_dev = max([altitude_below; altitude_above]);
        
        % Safety evaluation
        tse_ok = (max_tse <= tse_limit);
        altitude_ok = (max_altitude_dev == 0);
        is_safe = tse_ok && altitude_ok;
        
        % Store results
        results(i).flight_id = i;
        results(i).type = movements(i).type;
        results(i).success = true;
        results(i).max_tse_m = max_tse;
        results(i).altitude_ok = altitude_ok;
        results(i).safe = is_safe;
        
        % Update counters
        if is_safe
            n_safe = n_safe + 1;
            fprintf('SAFE (TSE=%.1fm) ✓\n', max_tse);
        else
            n_unsafe = n_unsafe + 1;
            if ~tse_ok
                fprintf('UNSAFE (TSE=%.1fm > %.0fm) ✗\n', max_tse, tse_limit);
            else
                fprintf('UNSAFE (Alt violation: %.1fm) ✗\n', max_altitude_dev);
            end
        end
        
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        n_failed = n_failed + 1;
        
        results(i).flight_id = i;
        results(i).type = movements(i).type;
        results(i).success = false;
        results(i).max_tse_m = NaN;
        results(i).altitude_ok = false;
        results(i).safe = false;
    end
end

%% ========================================================================
%  FINAL RESULTS
%  ========================================================================
fprintf('\n=============================================================\n');
fprintf(' SIMULATION COMPLETE\n');
fprintf('=============================================================\n');
fprintf('Total Flights:    %d\n', N_flights);
fprintf('Successful:       %d\n', N_flights - n_failed);
fprintf('Failed:           %d\n', n_failed);
fprintf('-------------------------------------------------------------\n');
fprintf('Safe Flights:     %d\n', n_safe);
fprintf('Unsafe Flights:   %d\n', n_unsafe);
fprintf('-------------------------------------------------------------\n');
fprintf('P(Safe):          %.4f\n', n_safe / N_flights);
fprintf('P(TSE Violation): %.4f\n', n_unsafe / N_flights);
fprintf('=============================================================\n');

% Save results
save('Vertiport_MC_Results_SIMPLE.mat', 'results', 'movements', ...
     'lambda_target', 'N_flights', 'n_safe', 'n_unsafe', 'n_failed');

fprintf('\nResults saved to: Vertiport_MC_Results_SIMPLE.mat\n');
