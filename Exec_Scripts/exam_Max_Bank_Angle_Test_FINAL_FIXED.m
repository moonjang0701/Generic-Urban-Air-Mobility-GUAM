%% Maximum Bank Angle Test - FINAL FIXED VERSION
% Properly initializes from cruise trim conditions

clear all; close all; clc;

%% Configuration
model = 'GUAM';
test_speeds_knots = [80, 100, 120];
initial_bank = 10;
bank_increment = 5;
max_bank_test = 50;  % Reduced to avoid extreme angles

test_speeds_fps = test_speeds_knots * 1.68781;

all_results = {};
result_idx = 1;

results_dir = './Bank_Angle_Test_Results';
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end

fprintf('=================================================\n');
fprintf('Maximum Bank Angle Test - FINAL VERSION\n');
fprintf('=================================================\n');
fprintf('Speeds: %s knots\n', num2str(test_speeds_knots));
fprintf('Bank Range: %d°-%d° (step: %d°)\n', ...
    initial_bank, max_bank_test, bank_increment);
fprintf('=================================================\n\n');

%% Disable warnings
warning('off', 'Simulink:blocks:AssertionAssert');
warning('off', 'MATLAB:legend:IgnoringExtraEntries');

%% Main Test Loop
for speed_idx = 1:length(test_speeds_fps)
    cruise_speed = test_speeds_fps(speed_idx);
    cruise_speed_knots = test_speeds_knots(speed_idx);
    
    fprintf('\n╔══════════════════════════════════════════════════╗\n');
    fprintf('║  TESTING AT %.0f KNOTS (%.1f ft/s)            ║\n', ...
        cruise_speed_knots, cruise_speed);
    fprintf('╚══════════════════════════════════════════════════╝\n\n');
    
    current_bank = initial_bank;
    max_safe_bank = 0;
    continue_testing = true;
    
    while continue_testing && current_bank <= max_bank_test
        bank_angle_deg = current_bank;
        bank_angle_rad = bank_angle_deg * pi/180;
        
        fprintf('%.0f kts / %.0f° ... ', cruise_speed_knots, bank_angle_deg);
        
        try
            %% Calculate Turn Parameters
            g = 32.174;
            load_factor = 1 / cos(bank_angle_rad);
            turn_radius = cruise_speed^2 / (g * tan(bank_angle_rad));
            turn_rate = g * tan(bank_angle_rad) / cruise_speed;
            turn_period = 2*pi / turn_rate;
            
            % Simulation time: 1 complete turn
            sim_time = min(turn_period * 1.0, 50);
            
            %% Setup Trajectory with Cruise Initial Conditions
            userStruct.variants.refInputType = 3;
            
            % Time vector
            num_points = max(50, ceil(sim_time * 2));  % More points for smoother trajectory
            time = linspace(0, sim_time, num_points)';
            
            cruise_alt = -100;  % 100 ft altitude in NED
            
            % Circular trajectory
            theta = turn_rate * time;
            pos = zeros(num_points, 3);
            pos(:,1) = turn_radius * sin(theta);
            pos(:,2) = turn_radius * (1 - cos(theta));
            pos(:,3) = cruise_alt * ones(num_points, 1);
            
            % Velocities
            vel_i = zeros(num_points, 3);
            vel_i(:,1) = gradient(pos(:,1)) ./ gradient(time);
            vel_i(:,2) = gradient(pos(:,2)) ./ gradient(time);
            vel_i(:,3) = gradient(pos(:,3)) ./ gradient(time);
            
            % Heading
            chi = atan2(vel_i(:,2), vel_i(:,1));
            chid = gradient(chi) ./ gradient(time);
            
            addpath(genpath('lib'));
            
            q = QrotZ(chi);
            vel = Qtrans(q, vel_i);
            
            % Clear previous target
            clear target
            
            %% KEY FIX: Set cruise initial conditions
            % This tells GUAM to start in cruise, not hover!
            target.tas = cruise_speed_knots;  % Initial cruise speed (knots)
            target.gndtrack = chi(1) * 180/pi;  % Initial heading (degrees)
            target.gamma = 0;  % Level flight initially
            target.roll = 0;  % Start wings level
            target.pitch = 2;  % Small positive pitch for cruise (degrees)
            target.alpha = 2;  % Small angle of attack (degrees)
            
            % Setup trajectory
            target.RefInput.Vel_bIc_des = timeseries(vel, time);
            target.RefInput.pos_des = timeseries(pos, time);
            target.RefInput.chi_des = timeseries(chi, time);
            target.RefInput.chi_dot_des = timeseries(chid, time);
            target.RefInput.vel_des = timeseries(vel_i, time);
            
            %% Initialize simulation
            simSetup;
            
            %% Set stop time
            set_param(model, 'StopTime', num2str(time(end)));
            
            %% Clear previous logsout
            evalin('base', 'clear logsout');
            
            %% Run simulation
            lastwarn('');  % Clear warnings
            sim(model);
            [warnMsg, ~] = lastwarn;
            
            pause(0.2);
            
            %% Check for logsout
            if ~evalin('base', 'exist(''logsout'', ''var'')')
                error('logsout not created');
            end
            
            %% Extract results
            SimOut = evalin('base', 'logsout{1}.Values');
            
            t = SimOut.Time.Data;
            pos_actual = squeeze(SimOut.Vehicle.EOM.InertialData.Pos_bii.Data);
            phi = SimOut.Vehicle.Sensor.Euler.phi.Data;
            theta_angle = SimOut.Vehicle.Sensor.Euler.theta.Data;
            psi = SimOut.Vehicle.Sensor.Euler.psi.Data;
            V_tot = SimOut.Vehicle.Sensor.Vtot.Data;
            gamma = SimOut.Vehicle.Sensor.gamma.Data;
            
            prop_om = SimOut.Vehicle.PropAct.EngSpeed.Data;
            prop_rpm = prop_om * 60 / (2*pi);
            
            dele = SimOut.Vehicle.SurfAct.Position.Data(:,3);
            dela = SimOut.Vehicle.SurfAct.Position.Data(:,1);
            delr = SimOut.Vehicle.SurfAct.Position.Data(:,5);
            
            prop_torq = SimOut.Vehicle.FM.Propulsion.Mprop_r.Data;
            ftlbs2watts = 1.355817948;
            prop_power = abs(prop_torq .* prop_om) * ftlbs2watts;
            total_power = sum(prop_power, 2);
            
            %% Analyze Results
            % Skip first 2 seconds (transient)
            idx_steady = find(t > 2);
            if isempty(idx_steady)
                idx_steady = 1:length(t);
            end
            
            bank_actual_mean = mean(abs(phi(idx_steady))) * 180/pi;
            bank_actual_max = max(abs(phi(idx_steady))) * 180/pi;
            bank_actual_std = std(phi(idx_steady)) * 180/pi;
            
            load_factor_actual_mean = mean(1 ./ cos(phi(idx_steady)));
            load_factor_actual_max = max(1 ./ cos(phi(idx_steady)));
            
            V_mean = mean(V_tot(idx_steady));
            V_min = min(V_tot(idx_steady));
            V_drop = (cruise_speed - V_min) / cruise_speed * 100;
            
            alt_initial = -pos_actual(1,3);
            alt_final = -pos_actual(end,3);
            alt_change = alt_final - alt_initial;
            alt_loss_rate = alt_change / t(end);
            
            power_mean = mean(total_power(idx_steady)) / 1000;
            power_max = max(total_power(idx_steady)) / 1000;
            
            rotor_rpm_mean = mean(mean(prop_rpm(idx_steady,1:8)));
            rotor_rpm_max = max(max(prop_rpm(idx_steady,1:8)));
            pusher_rpm_mean = mean(prop_rpm(idx_steady,9));
            pusher_rpm_max = max(prop_rpm(idx_steady,9));
            
            %% Success Criteria
            success = true;
            failure_reason = 'None';
            stop_testing = false;
            
            % Check for assertion warnings
            if contains(warnMsg, 'Assertion') || contains(warnMsg, 'KillifNotValidPropSpd')
                success = false;
                failure_reason = 'Assertion/PropSpeed';
                stop_testing = true;
            elseif rotor_rpm_max > 1550
                success = false;
                failure_reason = sprintf('Rotor RPM %.0f', rotor_rpm_max);
                stop_testing = true;
            elseif pusher_rpm_max > 1950
                success = false;
                failure_reason = sprintf('Pusher RPM %.0f', pusher_rpm_max);
                stop_testing = true;
            elseif V_drop > 15
                success = false;
                failure_reason = sprintf('Speed loss %.1f%%', V_drop);
                stop_testing = true;
            elseif abs(alt_loss_rate) > 10
                success = false;
                failure_reason = sprintf('Alt rate %.1f', alt_loss_rate);
                stop_testing = true;
            elseif any(isnan(V_tot)) || any(isinf(V_tot))
                success = false;
                failure_reason = 'NaN/Inf';
                stop_testing = true;
            end
            
            %% Store Results
            result = struct();
            result.test_num = result_idx;
            result.speed_knots = cruise_speed_knots;
            result.speed_fps = cruise_speed;
            result.bank_angle_deg = bank_angle_deg;
            result.load_factor_theoretical = load_factor;
            result.load_factor_actual_mean = load_factor_actual_mean;
            result.bank_actual_mean = bank_actual_mean;
            result.bank_actual_std = bank_actual_std;
            result.V_mean = V_mean;
            result.V_drop_percent = V_drop;
            result.alt_change = alt_change;
            result.power_mean_kW = power_mean;
            result.rotor_rpm_max = rotor_rpm_max;
            result.pusher_rpm_max = pusher_rpm_max;
            result.success = success;
            result.failure_reason = failure_reason;
            
            % Store time history
            result.t = t;
            result.pos = pos_actual;
            result.phi = phi;
            result.V_tot = V_tot;
            result.prop_rpm = prop_rpm;
            result.total_power = total_power;
            result.pos_des = pos;
            
            all_results{result_idx} = result;
            result_idx = result_idx + 1;
            
            %% Print Summary
            if success
                fprintf('✓ (φ=%.1f°, n=%.2f, RPM=%.0f, V↓=%.1f%%)\n', ...
                    bank_actual_mean, load_factor_actual_mean, rotor_rpm_max, V_drop);
                max_safe_bank = bank_angle_deg;
                current_bank = current_bank + bank_increment;
            else
                fprintf('✗ %s\n', failure_reason);
                if stop_testing
                    continue_testing = false;
                end
            end
            
        catch ME
            fprintf('✗ ERROR: %s\n', ME.message);
            
            result = struct();
            result.test_num = result_idx;
            result.speed_knots = cruise_speed_knots;
            result.bank_angle_deg = bank_angle_deg;
            result.success = false;
            result.failure_reason = ME.message;
            all_results{result_idx} = result;
            result_idx = result_idx + 1;
            
            continue_testing = false;
        end
    end
    
    fprintf('  ▶ Max Safe Bank: %.0f°\n', max_safe_bank);
end

%% Generate Summary Plot
fprintf('\n=================================================\n');
fprintf('Generating summary plot...\n');

fig = figure('Position', [100, 100, 1400, 800], 'Visible', 'off');

colors = {'b-o', 'r-s', 'g-d'};

for speed_idx = 1:length(test_speeds_knots)
    speed = test_speeds_knots(speed_idx);
    
    % Extract successful tests at this speed
    speed_data = [];
    for i = 1:length(all_results)
        r = all_results{i};
        if r.speed_knots == speed && r.success
            speed_data = [speed_data; r.bank_angle_deg, r.load_factor_actual_mean, ...
                r.V_drop_percent, r.power_mean_kW, r.rotor_rpm_max];
        end
    end
    
    if ~isempty(speed_data)
        % Load Factor
        subplot(2, 3, 1);
        plot(speed_data(:,1), speed_data(:,2), colors{speed_idx}, ...
            'LineWidth', 2, 'MarkerSize', 8);
        hold on; grid on;
        xlabel('Bank Angle [deg]');
        ylabel('Load Factor [g]');
        title('Load Factor');
        
        % Speed Loss
        subplot(2, 3, 2);
        plot(speed_data(:,1), speed_data(:,3), colors{speed_idx}, ...
            'LineWidth', 2, 'MarkerSize', 8);
        hold on; grid on;
        xlabel('Bank Angle [deg]');
        ylabel('Speed Loss [%]');
        title('Speed Loss');
        
        % Power
        subplot(2, 3, 3);
        plot(speed_data(:,1), speed_data(:,4), colors{speed_idx}, ...
            'LineWidth', 2, 'MarkerSize', 8);
        hold on; grid on;
        xlabel('Bank Angle [deg]');
        ylabel('Power [kW]');
        title('Power Required');
        
        % RPM
        subplot(2, 3, 4);
        plot(speed_data(:,1), speed_data(:,5), colors{speed_idx}, ...
            'LineWidth', 2, 'MarkerSize', 8);
        hold on; grid on;
        xlabel('Bank Angle [deg]');
        ylabel('Max Rotor RPM');
        title('Rotor Speed');
        yline(1600, 'r--', 'Limit');
        
        % Load vs RPM
        subplot(2, 3, 5);
        plot(speed_data(:,2), speed_data(:,5), colors{speed_idx}, ...
            'LineWidth', 2, 'MarkerSize', 8);
        hold on; grid on;
        xlabel('Load Factor [g]');
        ylabel('Max Rotor RPM');
        title('RPM vs Load Factor');
        yline(1600, 'r--', 'Limit');
    end
end

% Add legend
for i = 1:5
    subplot(2, 3, i);
    legend(arrayfun(@(x) sprintf('%.0f kts', x), test_speeds_knots, ...
        'UniformOutput', false), 'Location', 'best');
end

sgtitle('Bank Angle Test Summary', 'FontSize', 16, 'FontWeight', 'bold');
saveas(fig, sprintf('%s/Summary.png', results_dir));
close(fig);

%% Export CSV
fprintf('Exporting CSV...\n');

fid = fopen(sprintf('%s/Results.csv', results_dir), 'w');
fprintf(fid, 'Test,Speed_kts,Bank_deg,Load_Theory,Load_Actual,Bank_Actual,V_Drop,Power_kW,Rotor_RPM,Success,Reason\n');

for i = 1:length(all_results)
    r = all_results{i};
    if r.success
        fprintf(fid, '%d,%.0f,%.0f,%.2f,%.2f,%.1f,%.1f,%.0f,%.0f,TRUE,%s\n', ...
            r.test_num, r.speed_knots, r.bank_angle_deg, ...
            r.load_factor_theoretical, r.load_factor_actual_mean, ...
            r.bank_actual_mean, r.V_drop_percent, r.power_mean_kW, ...
            r.rotor_rpm_max, r.failure_reason);
    else
        fprintf(fid, '%d,%.0f,%.0f,,,,,,,FALSE,%s\n', ...
            r.test_num, r.speed_knots, r.bank_angle_deg, ...
            strrep(r.failure_reason, ',', ';'));
    end
end
fclose(fid);

%% Final Summary
fprintf('\n=================================================\n');
fprintf('RESULTS\n');
fprintf('=================================================\n');

success_count = sum(cellfun(@(x) x.success, all_results));
fprintf('Total: %d | Success: %d | Failed: %d\n\n', ...
    length(all_results), success_count, length(all_results) - success_count);

fprintf('📊 MAXIMUM SAFE BANK ANGLES:\n');
fprintf('═════════════════════════════════════════\n');

for speed_idx = 1:length(test_speeds_knots)
    speed = test_speeds_knots(speed_idx);
    max_bank = 0;
    max_load = 0;
    
    for i = 1:length(all_results)
        r = all_results{i};
        if r.speed_knots == speed && r.success && r.bank_angle_deg > max_bank
            max_bank = r.bank_angle_deg;
            max_load = r.load_factor_actual_mean;
        end
    end
    
    if max_bank > 0
        fprintf('  %.0f knots: %.0f° (n = %.2f g)\n', speed, max_bank, max_load);
    else
        fprintf('  %.0f knots: All tests failed\n', speed);
    end
end

fprintf('═════════════════════════════════════════\n');
fprintf('\n✓ Complete! Results: %s/\n', results_dir);

warning('on', 'all');
