%% Maximum Bank Angle Test - Fixed Version with Model Loading
% This version explicitly loads and compiles the model before simulation

clear all; close all; clc;

%% Configuration
model = 'GUAM';
test_speeds_knots = [80, 100, 120];
initial_bank = 10;
bank_increment = 5;
max_bank_test = 75;

test_speeds_fps = test_speeds_knots * 1.68781;

all_results = {};
result_idx = 1;

results_dir = './Bank_Angle_Test_Results';
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end

fprintf('=================================================\n');
fprintf('Maximum Bank Angle Test - Fixed Version\n');
fprintf('=================================================\n');
fprintf('Configuration:\n');
fprintf('  Speeds: %s knots\n', num2str(test_speeds_knots));
fprintf('  Bank Range: %d° to %d° (increment: %d°)\n', ...
    initial_bank, max_bank_test, bank_increment);
fprintf('=================================================\n\n');

%% Disable Simulink Warnings
warning('off', 'Simulink:blocks:AssertionAssert');
warning('off', 'MATLAB:legend:IgnoringExtraEntries');

%% Main Test Loop
for speed_idx = 1:length(test_speeds_fps)
    cruise_speed = test_speeds_fps(speed_idx);
    cruise_speed_knots = test_speeds_knots(speed_idx);
    
    fprintf('\n╔══════════════════════════════════════════════════╗\n');
    fprintf('║  TESTING AT %.0f KNOTS (%.1f ft/s)               ║\n', ...
        cruise_speed_knots, cruise_speed);
    fprintf('╚══════════════════════════════════════════════════╝\n\n');
    
    current_bank = initial_bank;
    max_safe_bank = 0;
    continue_testing = true;
    
    while continue_testing && current_bank <= max_bank_test
        bank_angle_deg = current_bank;
        bank_angle_rad = bank_angle_deg * pi/180;
        
        fprintf('Testing Bank Angle: %.0f° ... ', bank_angle_deg);
        
        try
            %% Calculate Turn Parameters
            g = 32.174;
            load_factor = 1 / cos(bank_angle_rad);
            turn_radius = cruise_speed^2 / (g * tan(bank_angle_rad));
            turn_rate = g * tan(bank_angle_rad) / cruise_speed;
            turn_period = 2*pi / turn_rate;
            
            sim_time = min(turn_period * 1.2, 60);
            
            %% Setup Trajectory
            userStruct.variants.refInputType = 3;
            
            num_points = max(50, ceil(sim_time));
            time = linspace(0, sim_time, num_points)';
            
            cruise_alt = -100;
            
            theta = turn_rate * time;
            pos = zeros(num_points, 3);
            pos(:,1) = turn_radius * sin(theta);
            pos(:,2) = turn_radius * (1 - cos(theta));
            pos(:,3) = cruise_alt * ones(num_points, 1);
            
            vel_i = zeros(num_points, 3);
            vel_i(:,1) = gradient(pos(:,1)) ./ gradient(time);
            vel_i(:,2) = gradient(pos(:,2)) ./ gradient(time);
            vel_i(:,3) = gradient(pos(:,3)) ./ gradient(time);
            
            chi = atan2(vel_i(:,2), vel_i(:,1));
            chid = gradient(chi) ./ gradient(time);
            
            addpath(genpath('lib'));
            
            q = QrotZ(chi);
            vel = Qtrans(q, vel_i);
            
            clear target
            target.RefInput.Vel_bIc_des = timeseries(vel, time);
            target.RefInput.pos_des = timeseries(pos, time);
            target.RefInput.chi_des = timeseries(chi, time);
            target.RefInput.chi_dot_des = timeseries(chid, time);
            target.RefInput.vel_des = timeseries(vel_i, time);
            
            %% Initialize Simulation
            simSetup;
            
            %% CRITICAL: Load and compile model before simulation
            % This ensures logsout is properly configured
            if speed_idx == 1 && current_bank == initial_bank
                % Only load once at the start
                fprintf('\n[Loading and compiling model...] ');
                load_system(model);
                
                % Set the model to log output
                set_param(model, 'SignalLogging', 'on');
                set_param(model, 'SignalLoggingName', 'logsout');
                
                fprintf('Done.\n');
                fprintf('Testing Bank Angle: %.0f° ... ', bank_angle_deg);
            end
            
            %% Clear previous logsout
            if evalin('base', 'exist(''logsout'', ''var'')')
                evalin('base', 'clear logsout');
            end
            
            %% Run Simulation
            lastwarn('');
            
            % Use sim command with model name
            simOut = sim(model, 'StopTime', num2str(time(end)), ...
                         'SaveOutput', 'on', ...
                         'OutputSaveName', 'logsout');
            
            % Check for warnings
            [warnMsg, warnId] = lastwarn;
            has_warning = ~isempty(warnMsg);
            
            pause(0.2);  % Give MATLAB time to create logsout
            
            %% Extract Results from base workspace
            if evalin('base', 'exist(''logsout'', ''var'')')
                % Get logsout from base workspace
                logsout_data = evalin('base', 'logsout');
                SimOut = logsout_data{1}.Values;
            else
                error('logsout not created in base workspace');
            end
            
            % Extract time series data
            t = SimOut.Time.Data;
            
            pos_actual = squeeze(SimOut.Vehicle.EOM.InertialData.Pos_bii.Data);
            phi = SimOut.Vehicle.Sensor.Euler.phi.Data;
            theta_euler = SimOut.Vehicle.Sensor.Euler.theta.Data;
            psi = SimOut.Vehicle.Sensor.Euler.psi.Data;
            V_tot = SimOut.Vehicle.Sensor.Vtot.Data;
            gamma = SimOut.Vehicle.Sensor.gamma.Data;
            
            prop_om = SimOut.Vehicle.PropAct.EngSpeed.Data;
            prop_rpm = prop_om * 60 / (2*pi);
            
            dele = SimOut.Vehicle.SurfAct.Position.Data(:,3);
            dela = SimOut.Vehicle.SurfAct.Position.Data(:,1);
            delr = SimOut.Vehicle.SurfAct.Position.Data(:,5);
            
            prop_torq = SimOut.Vehicle.FM.Propulsion.Mprop_r.Data;
            prop_thrust = SimOut.Vehicle.FM.Propulsion.Fprop_r.Data;
            
            ftlbs2watts = 1.355817948;
            prop_power = abs(prop_torq .* prop_om) * ftlbs2watts;
            total_power = sum(prop_power, 2);
            
            %% Analyze Results
            bank_actual_mean = mean(abs(phi)) * 180/pi;
            bank_actual_max = max(abs(phi)) * 180/pi;
            bank_actual_std = std(phi) * 180/pi;
            
            load_factor_actual_mean = mean(1 ./ cos(phi));
            load_factor_actual_max = max(1 ./ cos(phi));
            
            V_mean = mean(V_tot);
            V_min = min(V_tot);
            V_drop = (cruise_speed - V_min) / cruise_speed * 100;
            
            alt_initial = -pos_actual(1,3);
            alt_final = -pos_actual(end,3);
            alt_change = alt_final - alt_initial;
            alt_loss_rate = alt_change / t(end);
            
            power_mean = mean(total_power) / 1000;
            power_max = max(total_power) / 1000;
            
            rotor_rpm_mean = mean(mean(prop_rpm(:,1:8)));
            rotor_rpm_max = max(max(prop_rpm(:,1:8)));
            pusher_rpm_mean = mean(prop_rpm(:,9));
            pusher_rpm_max = max(prop_rpm(:,9));
            
            %% Check Success Criteria
            success = true;
            failure_reason = 'None';
            stop_testing = false;
            
            if rotor_rpm_max > 1550
                success = false;
                failure_reason = sprintf('Rotor RPM limit (%.0f RPM)', rotor_rpm_max);
                stop_testing = true;
            elseif pusher_rpm_max > 1950
                success = false;
                failure_reason = sprintf('Pusher RPM limit (%.0f RPM)', pusher_rpm_max);
                stop_testing = true;
            elseif V_drop > 15
                success = false;
                failure_reason = sprintf('Speed loss %.1f%%', V_drop);
                stop_testing = true;
            elseif alt_loss_rate < -8
                success = false;
                failure_reason = sprintf('Altitude loss %.1f ft/s', alt_loss_rate);
                stop_testing = true;
            elseif any(isnan(V_tot)) || any(isinf(V_tot))
                success = false;
                failure_reason = 'Numerical instability';
                stop_testing = true;
            elseif has_warning && contains(warnMsg, 'Assertion')
                success = false;
                failure_reason = 'Assertion warning';
                stop_testing = true;
            end
            
            %% Store Results
            result = struct();
            result.test_num = result_idx;
            result.speed_knots = cruise_speed_knots;
            result.speed_fps = cruise_speed;
            result.bank_angle_deg = bank_angle_deg;
            result.bank_angle_rad = bank_angle_rad;
            result.load_factor_theoretical = load_factor;
            result.load_factor_actual_mean = load_factor_actual_mean;
            result.load_factor_actual_max = load_factor_actual_max;
            result.turn_radius_theoretical = turn_radius;
            result.sim_time = sim_time;
            result.bank_actual_mean = bank_actual_mean;
            result.bank_actual_max = bank_actual_max;
            result.bank_actual_std = bank_actual_std;
            result.V_mean = V_mean;
            result.V_min = V_min;
            result.V_drop_percent = V_drop;
            result.alt_change = alt_change;
            result.alt_loss_rate = alt_loss_rate;
            result.power_mean_kW = power_mean;
            result.power_max_kW = power_max;
            result.rotor_rpm_mean = rotor_rpm_mean;
            result.rotor_rpm_max = rotor_rpm_max;
            result.pusher_rpm_mean = pusher_rpm_mean;
            result.pusher_rpm_max = pusher_rpm_max;
            result.success = success;
            result.failure_reason = failure_reason;
            
            result.t = t;
            result.pos = pos_actual;
            result.phi = phi;
            result.theta = theta_euler;
            result.psi = psi;
            result.V_tot = V_tot;
            result.gamma = gamma;
            result.dele = dele;
            result.dela = dela;
            result.delr = delr;
            result.prop_rpm = prop_rpm;
            result.total_power = total_power;
            result.pos_des = pos;
            
            all_results{result_idx} = result;
            result_idx = result_idx + 1;
            
            %% Print Results
            if success
                fprintf('✓ PASS\n');
                fprintf('    Bank: %.1f° (±%.1f°), Load: %.2f g\n', ...
                    bank_actual_mean, bank_actual_std, load_factor_actual_mean);
                fprintf('    Rotor RPM: %.0f, Speed Loss: %.1f%%\n', ...
                    rotor_rpm_max, V_drop);
                
                max_safe_bank = bank_angle_deg;
                current_bank = current_bank + bank_increment;
            else
                fprintf('✗ FAIL: %s\n', failure_reason);
                
                if stop_testing
                    fprintf('    ⚠ Limit reached, stopping tests at this speed\n');
                    continue_testing = false;
                end
            end
            
        catch ME
            fprintf('✗ ERROR: %s\n', ME.message);
            fprintf('    Stack: %s\n', ME.stack(1).name);
            
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
    
    fprintf('\n');
    fprintf('═══════════════════════════════════════════════════\n');
    fprintf('  ✓ Max Safe Bank Angle at %.0f kts: %.0f°\n', ...
        cruise_speed_knots, max_safe_bank);
    fprintf('═══════════════════════════════════════════════════\n');
end

%% Generate Plots (same as before, omitted for brevity)
% [Previous plotting code here...]

%% Export to CSV
fprintf('\nExporting to CSV...\n');

csv_filename = sprintf('%s/Bank_Angle_Test_Results.csv', results_dir);
fid = fopen(csv_filename, 'w');

fprintf(fid, 'Test_Num,Speed_knots,Bank_Angle_deg,Load_Factor_Theory,Load_Factor_Actual,');
fprintf(fid, 'Bank_Actual_Mean,V_Drop_Percent,Alt_Change_ft,Power_Mean_kW,');
fprintf(fid, 'Rotor_RPM_Max,Pusher_RPM_Max,Success,Failure_Reason\n');

for i = 1:length(all_results)
    r = all_results{i};
    fprintf(fid, '%d,%.1f,%.1f,', r.test_num, r.speed_knots, r.bank_angle_deg);
    
    if r.success
        fprintf(fid, '%.3f,%.3f,%.2f,%.2f,%.2f,%.1f,%.0f,%.0f,TRUE,%s\n', ...
            r.load_factor_theoretical, r.load_factor_actual_mean, ...
            r.bank_actual_mean, r.V_drop_percent, r.alt_change, ...
            r.power_mean_kW, r.rotor_rpm_max, r.pusher_rpm_max, r.failure_reason);
    else
        if isfield(r, 'rotor_rpm_max')
            fprintf(fid, ',,,,,,%.0f,%.0f,FALSE,%s\n', ...
                r.rotor_rpm_max, r.pusher_rpm_max, strrep(r.failure_reason, ',', ';'));
        else
            fprintf(fid, ',,,,,,,,FALSE,%s\n', strrep(r.failure_reason, ',', ';'));
        end
    end
end

fclose(fid);

%% Final Summary
fprintf('\n=================================================\n');
fprintf('TEST COMPLETE\n');
fprintf('=================================================\n');

successful_count = 0;
for i = 1:length(all_results)
    if all_results{i}.success
        successful_count = successful_count + 1;
    end
end

fprintf('Total Tests: %d\n', length(all_results));
fprintf('Successful: %d\n', successful_count);
fprintf('Failed: %d\n', length(all_results) - successful_count);

fprintf('\n📊 MAXIMUM SAFE BANK ANGLES:\n');
fprintf('═══════════════════════════════════════════════════\n');
for speed_idx = 1:length(test_speeds_knots)
    speed = test_speeds_knots(speed_idx);
    max_bank = 0;
    
    for i = 1:length(all_results)
        r = all_results{i};
        if r.speed_knots == speed && r.success && r.bank_angle_deg > max_bank
            max_bank = r.bank_angle_deg;
        end
    end
    
    if max_bank > 0
        fprintf('  %.0f knots: %.0f°\n', speed, max_bank);
    else
        fprintf('  %.0f knots: No successful tests\n', speed);
    end
end
fprintf('═══════════════════════════════════════════════════\n');

warning('on', 'Simulink:blocks:AssertionAssert');
warning('on', 'MATLAB:legend:IgnoringExtraEntries');

fprintf('\n✓ Results saved to: %s\n', results_dir);
