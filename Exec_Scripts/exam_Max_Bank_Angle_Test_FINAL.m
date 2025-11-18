%% Maximum Bank Angle Test for UAM Aircraft
% This script tests the maximum safe bank angle at various cruise speeds
% Tests continue until stall or structural limits are reached
% Generates comprehensive graphs and CSV export for each test

clear all; close all; clc;

%% Configuration
model = 'GUAM';
test_speeds_knots = [80, 100, 120];  % Cruise speeds to test (knots)
bank_angles_deg = 15:5:75;  % Bank angles to test (degrees)

% Convert speeds to ft/s
test_speeds_fps = test_speeds_knots * 1.68781;  % 1 knot = 1.68781 ft/s

% Results storage
all_results = [];
result_idx = 1;

% Create results directory
results_dir = './Bank_Angle_Test_Results';
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end

fprintf('=================================================\n');
fprintf('Maximum Bank Angle Test for UAM Aircraft\n');
fprintf('=================================================\n');
fprintf('Test Configuration:\n');
fprintf('  Speeds: %s knots\n', num2str(test_speeds_knots));
fprintf('  Bank Angles: %d° to %d° (step: %d°)\n', ...
    bank_angles_deg(1), bank_angles_deg(end), bank_angles_deg(2)-bank_angles_deg(1));
fprintf('  Total Tests: %d\n', length(test_speeds_knots) * length(bank_angles_deg));
fprintf('=================================================\n\n');

%% Main Test Loop
for speed_idx = 1:length(test_speeds_fps)
    cruise_speed = test_speeds_fps(speed_idx);
    cruise_speed_knots = test_speeds_knots(speed_idx);
    
    fprintf('\n╔══════════════════════════════════════════════════╗\n');
    fprintf('║  TESTING AT %.0f KNOTS (%.1f ft/s)               ║\n', ...
        cruise_speed_knots, cruise_speed);
    fprintf('╚══════════════════════════════════════════════════╝\n\n');
    
    for bank_idx = 1:length(bank_angles_deg)
        bank_angle_deg = bank_angles_deg(bank_idx);
        bank_angle_rad = bank_angle_deg * pi/180;
        
        test_num = (speed_idx-1)*length(bank_angles_deg) + bank_idx;
        
        fprintf('Test %d/%d: Speed=%.0f kts, Bank=%.0f° ... ', ...
            test_num, length(test_speeds_knots)*length(bank_angles_deg), ...
            cruise_speed_knots, bank_angle_deg);
        
        try
            %% Calculate Turn Parameters
            g = 32.174;  % ft/s^2
            load_factor = 1 / cos(bank_angle_rad);
            turn_radius = cruise_speed^2 / (g * tan(bank_angle_rad));
            turn_rate = g * tan(bank_angle_rad) / cruise_speed;  % rad/s
            turn_period = 2*pi / turn_rate;  % seconds for complete circle
            
            % Set simulation time (1.5 complete turns for stability)
            sim_time = min(turn_period * 1.5, 120);  % Cap at 120 seconds
            
            %% Setup Trajectory
            % Use timeseries input
            userStruct.variants.refInputType = 3;
            
            % Generate circular trajectory
            num_points = max(50, ceil(sim_time));  % At least 50 points
            time = linspace(0, sim_time, num_points)';
            
            % Initial cruise position
            cruise_alt = -100;  % -100 ft in NED (100 ft altitude)
            
            % Circular path coordinates (NED frame)
            theta = turn_rate * time;  % Angular position
            pos = zeros(num_points, 3);
            pos(:,1) = turn_radius * sin(theta);  % North
            pos(:,2) = turn_radius * (1 - cos(theta));  % East
            pos(:,3) = cruise_alt * ones(num_points, 1);  % Down (constant altitude)
            
            % Calculate velocities using gradient
            vel_i = zeros(num_points, 3);
            vel_i(:,1) = gradient(pos(:,1)) ./ gradient(time);
            vel_i(:,2) = gradient(pos(:,2)) ./ gradient(time);
            vel_i(:,3) = gradient(pos(:,3)) ./ gradient(time);
            
            % Calculate heading (course angle)
            chi = atan2(vel_i(:,2), vel_i(:,1));
            chid = gradient(chi) ./ gradient(time);
            
            % Add library for quaternion functions
            addpath(genpath('lib'));
            
            % Convert velocity to heading frame
            q = QrotZ(chi);
            vel = Qtrans(q, vel_i);
            
            % Setup trajectory structure
            clear target
            target.RefInput.Vel_bIc_des = timeseries(vel, time);
            target.RefInput.pos_des = timeseries(pos, time);
            target.RefInput.chi_des = timeseries(chi, time);
            target.RefInput.chi_dot_des = timeseries(chid, time);
            target.RefInput.vel_des = timeseries(vel_i, time);
            
            %% Initialize Simulation
            simSetup;
            
            %% Run Simulation
            % Clear previous logsout if exists
            if exist('logsout', 'var')
                clear logsout
            end
            
            % Run simulation - logsout will be created automatically
            sim(model, 'StopTime', num2str(time(end)));
            
            %% Extract Results
            % Wait a moment for logsout to be available
            pause(0.1);
            
            % Check if logsout was created
            if ~exist('logsout', 'var')
                error('logsout variable not created by simulation');
            end
            
            % Extract simulation output
            SimOut = logsout{1}.Values;
            
            % Extract time series data
            t = SimOut.Time.Data;
            
            % Position data (NED)
            pos_actual = squeeze(SimOut.Vehicle.EOM.InertialData.Pos_bii.Data);
            
            % Attitude data
            phi = SimOut.Vehicle.Sensor.Euler.phi.Data;  % Roll (bank angle)
            theta = SimOut.Vehicle.Sensor.Euler.theta.Data;  % Pitch
            psi = SimOut.Vehicle.Sensor.Euler.psi.Data;  % Yaw
            
            % Velocity data
            V_tot = SimOut.Vehicle.Sensor.Vtot.Data;  % Total velocity
            gamma = SimOut.Vehicle.Sensor.gamma.Data;  % Flight path angle
            
            % Propeller speeds (RPM)
            prop_om = SimOut.Vehicle.PropAct.EngSpeed.Data;
            prop_rpm = prop_om * 60 / (2*pi);
            
            % Control surfaces
            dele = SimOut.Vehicle.SurfAct.Position.Data(:,3);  % Elevator
            dela = SimOut.Vehicle.SurfAct.Position.Data(:,1);  % Aileron
            delr = SimOut.Vehicle.SurfAct.Position.Data(:,5);  % Rudder
            
            % Propulsion data
            prop_torq = SimOut.Vehicle.FM.Propulsion.Mprop_r.Data;
            prop_thrust = SimOut.Vehicle.FM.Propulsion.Fprop_r.Data;
            
            % Calculate power (convert ft-lb/s to watts)
            ftlbs2watts = 1.355817948;
            prop_power = abs(prop_torq .* prop_om) * ftlbs2watts;
            total_power = sum(prop_power, 2);
            
            %% Analyze Results
            % Calculate actual bank angle statistics
            bank_actual_mean = mean(abs(phi)) * 180/pi;
            bank_actual_max = max(abs(phi)) * 180/pi;
            bank_actual_std = std(phi) * 180/pi;
            
            % Calculate actual load factor
            load_factor_actual_mean = mean(1 ./ cos(phi));
            load_factor_actual_max = max(1 ./ cos(phi));
            
            % Velocity statistics
            V_mean = mean(V_tot);
            V_min = min(V_tot);
            V_drop = (cruise_speed - V_min) / cruise_speed * 100;  % % drop
            
            % Altitude change
            alt_initial = -pos_actual(1,3);
            alt_final = -pos_actual(end,3);
            alt_change = alt_final - alt_initial;
            alt_loss_rate = alt_change / t(end);  % ft/s
            
            % Turn radius calculation from actual path
            turn_center_x = mean(pos_actual(:,1));
            turn_center_y = mean(pos_actual(:,2));
            radius_actual = mean(sqrt((pos_actual(:,1) - turn_center_x).^2 + ...
                                     (pos_actual(:,2) - turn_center_y).^2));
            
            % Power statistics
            power_mean = mean(total_power) / 1000;  % kW
            power_max = max(total_power) / 1000;
            
            % Rotor speeds
            rotor_rpm_mean = mean(mean(prop_rpm(:,1:8)));
            rotor_rpm_max = max(max(prop_rpm(:,1:8)));
            pusher_rpm_mean = mean(prop_rpm(:,9));
            pusher_rpm_max = max(prop_rpm(:,9));
            
            % Success criteria
            success = true;
            failure_reason = 'None';
            
            % Check for failures
            if V_drop > 10  % >10% speed loss
                success = false;
                failure_reason = sprintf('Speed loss %.1f%%', V_drop);
            elseif alt_loss_rate < -5  % Losing altitude faster than 5 ft/s
                success = false;
                failure_reason = sprintf('Altitude loss %.1f ft/s', alt_loss_rate);
            elseif any(isnan(V_tot)) || any(isinf(V_tot))
                success = false;
                failure_reason = 'Numerical instability';
            end
            
            %% Store Results
            result = struct();
            result.test_num = test_num;
            result.speed_knots = cruise_speed_knots;
            result.speed_fps = cruise_speed;
            result.bank_angle_deg = bank_angle_deg;
            result.bank_angle_rad = bank_angle_rad;
            result.load_factor_theoretical = load_factor;
            result.load_factor_actual_mean = load_factor_actual_mean;
            result.load_factor_actual_max = load_factor_actual_max;
            result.turn_radius_theoretical = turn_radius;
            result.turn_radius_actual = radius_actual;
            result.turn_rate = turn_rate * 180/pi;  % deg/s
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
            
            % Store full time history for plotting
            result.t = t;
            result.pos = pos_actual;
            result.phi = phi;
            result.theta = theta;
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
            
            %% Print Summary
            if success
                fprintf('✓ SUCCESS\n');
                fprintf('    Actual Bank: %.1f° (±%.1f°), Load Factor: %.2f\n', ...
                    bank_actual_mean, bank_actual_std, load_factor_actual_mean);
                fprintf('    Speed: %.1f ft/s (%.1f%% loss), Alt Change: %.1f ft\n', ...
                    V_mean, V_drop, alt_change);
                fprintf('    Power: %.0f kW (avg), Turn Radius: %.0f ft\n', ...
                    power_mean, radius_actual);
            else
                fprintf('✗ FAILED: %s\n', failure_reason);
            end
            
            %% Generate Individual Test Plots
            fig = figure('Position', [100, 100, 1400, 1000], 'Visible', 'off');
            
            % 3D Trajectory
            subplot(3, 3, 1);
            plot3(pos(:,1), pos(:,2), pos(:,3), 'b--', 'LineWidth', 1.5);
            hold on;
            plot3(pos_actual(:,1), pos_actual(:,2), pos_actual(:,3), 'r-', 'LineWidth', 2);
            plot3(pos(:,1), pos(:,2), zeros(size(pos(:,3))), 'b:', 'LineWidth', 1);
            plot3(pos_actual(:,1), pos_actual(:,2), zeros(size(pos_actual(:,3))), 'r:', 'LineWidth', 1);
            grid on;
            xlabel('North [ft]');
            ylabel('East [ft]');
            zlabel('Height [ft]');
            set(gca, 'Ydir', 'reverse', 'Zdir', 'reverse');
            title('3D Flight Path');
            legend('Desired', 'Actual', 'Location', 'best');
            view(30, 30);
            
            % Ground Track
            subplot(3, 3, 2);
            plot(pos(:,2), pos(:,1), 'b--', 'LineWidth', 1.5);
            hold on;
            plot(pos_actual(:,2), pos_actual(:,1), 'r-', 'LineWidth', 2);
            grid on;
            xlabel('East [ft]');
            ylabel('North [ft]');
            title('Ground Track (Top View)');
            legend('Desired', 'Actual', 'Location', 'best');
            axis equal;
            
            % Bank Angle
            subplot(3, 3, 3);
            plot(t, phi * 180/pi, 'LineWidth', 2);
            hold on;
            yline(bank_angle_deg, 'r--', 'Commanded', 'LineWidth', 1.5);
            yline(-bank_angle_deg, 'r--', 'LineWidth', 1.5);
            grid on;
            xlabel('Time [s]');
            ylabel('Bank Angle [deg]');
            title(sprintf('Bank Angle (Mean: %.1f°)', bank_actual_mean));
            
            % Velocity
            subplot(3, 3, 4);
            plot(t, V_tot, 'LineWidth', 2);
            hold on;
            yline(cruise_speed, 'r--', 'Commanded', 'LineWidth', 1.5);
            grid on;
            xlabel('Time [s]');
            ylabel('Velocity [ft/s]');
            title(sprintf('Total Velocity (Loss: %.1f%%)', V_drop));
            
            % Altitude
            subplot(3, 3, 5);
            plot(t, -pos_actual(:,3), 'LineWidth', 2);
            hold on;
            yline(-cruise_alt, 'r--', 'Commanded', 'LineWidth', 1.5);
            grid on;
            xlabel('Time [s]');
            ylabel('Altitude [ft]');
            title(sprintf('Altitude (Change: %.1f ft)', alt_change));
            
            % Load Factor
            subplot(3, 3, 6);
            n = 1 ./ cos(phi);
            plot(t, n, 'LineWidth', 2);
            hold on;
            yline(load_factor, 'r--', 'Theoretical', 'LineWidth', 1.5);
            grid on;
            xlabel('Time [s]');
            ylabel('Load Factor [g]');
            title(sprintf('Load Factor (Mean: %.2f g)', load_factor_actual_mean));
            
            % Control Surfaces
            subplot(3, 3, 7);
            plot(t, [dele dela delr] * 180/pi, 'LineWidth', 1.5);
            grid on;
            xlabel('Time [s]');
            ylabel('Deflection [deg]');
            title('Control Surfaces');
            legend('Elevator', 'Aileron', 'Rudder', 'Location', 'best');
            
            % Propeller Speeds
            subplot(3, 3, 8);
            plot(t, prop_rpm(:,1:8), 'LineWidth', 1);
            hold on;
            plot(t, prop_rpm(:,9), 'k-', 'LineWidth', 2);
            grid on;
            xlabel('Time [s]');
            ylabel('RPM');
            title('Propeller Speeds');
            legend([repmat({'Rotor'}, 1, 8), {'Pusher'}], 'Location', 'best', 'NumColumns', 3);
            ylim([0, max(max(prop_rpm))*1.1]);
            
            % Total Power
            subplot(3, 3, 9);
            plot(t, total_power/1000, 'LineWidth', 2);
            grid on;
            xlabel('Time [s]');
            ylabel('Power [kW]');
            title(sprintf('Total Power (Mean: %.0f kW)', power_mean));
            
            % Overall title
            sgtitle(sprintf('Test %d: Speed=%.0f kts, Bank=%.0f°, n=%.2f g - %s', ...
                test_num, cruise_speed_knots, bank_angle_deg, load_factor, ...
                result.failure_reason), ...
                'FontSize', 14, 'FontWeight', 'bold');
            
            % Save figure
            saveas(fig, sprintf('%s/Test_%02d_Speed%03d_Bank%02d.png', ...
                results_dir, test_num, cruise_speed_knots, bank_angle_deg));
            close(fig);
            
        catch ME
            fprintf('✗ ERROR: %s\n', ME.message);
            
            % Store error result
            result = struct();
            result.test_num = test_num;
            result.speed_knots = cruise_speed_knots;
            result.bank_angle_deg = bank_angle_deg;
            result.success = false;
            result.failure_reason = ME.message;
            all_results{result_idx} = result;
            result_idx = result_idx + 1;
        end
    end
end

%% Generate Summary Plots
fprintf('\n=================================================\n');
fprintf('Generating Summary Plots...\n');
fprintf('=================================================\n');

% Extract successful tests for summary
n_results = length(all_results);
summary_data = zeros(n_results, 20);
for i = 1:n_results
    r = all_results{i};
    if r.success
        summary_data(i,:) = [r.speed_knots, r.bank_angle_deg, r.load_factor_theoretical, ...
            r.load_factor_actual_mean, r.bank_actual_mean, r.V_drop_percent, ...
            r.alt_change, r.alt_loss_rate, r.power_mean_kW, r.turn_radius_actual, ...
            r.rotor_rpm_max, r.pusher_rpm_max, r.turn_rate, ...
            r.load_factor_actual_max, r.bank_actual_max, r.bank_actual_std, ...
            r.power_max_kW, r.V_mean, r.V_min, 1];
    else
        summary_data(i,1:2) = [r.speed_knots, r.bank_angle_deg];
        summary_data(i,20) = 0;  % Failed
    end
end

% Summary plots by speed
fig_summary = figure('Position', [100, 100, 1600, 1000], 'Visible', 'off');

colors = {'b-o', 'r-s', 'g-d'};
for speed_idx = 1:length(test_speeds_knots)
    speed = test_speeds_knots(speed_idx);
    idx = summary_data(:,1) == speed & summary_data(:,20) == 1;
    
    if sum(idx) > 0
        data = summary_data(idx,:);
        
        % Bank angle vs Load factor
        subplot(2, 3, 1);
        plot(data(:,2), data(:,3), colors{speed_idx}, 'LineWidth', 2, 'MarkerSize', 8);
        hold on;
        grid on;
        xlabel('Bank Angle [deg]');
        ylabel('Load Factor [g]');
        title('Theoretical Load Factor vs Bank Angle');
        
        % Bank angle vs Actual load factor
        subplot(2, 3, 2);
        plot(data(:,2), data(:,4), colors{speed_idx}, 'LineWidth', 2, 'MarkerSize', 8);
        hold on;
        grid on;
        xlabel('Bank Angle [deg]');
        ylabel('Actual Load Factor [g]');
        title('Measured Load Factor vs Bank Angle');
        
        % Bank angle vs Speed loss
        subplot(2, 3, 3);
        plot(data(:,2), data(:,6), colors{speed_idx}, 'LineWidth', 2, 'MarkerSize', 8);
        hold on;
        grid on;
        xlabel('Bank Angle [deg]');
        ylabel('Speed Loss [%]');
        title('Speed Loss vs Bank Angle');
        
        % Bank angle vs Altitude change
        subplot(2, 3, 4);
        plot(data(:,2), data(:,7), colors{speed_idx}, 'LineWidth', 2, 'MarkerSize', 8);
        hold on;
        grid on;
        xlabel('Bank Angle [deg]');
        ylabel('Altitude Change [ft]');
        title('Altitude Change vs Bank Angle');
        
        % Bank angle vs Power
        subplot(2, 3, 5);
        plot(data(:,2), data(:,9), colors{speed_idx}, 'LineWidth', 2, 'MarkerSize', 8);
        hold on;
        grid on;
        xlabel('Bank Angle [deg]');
        ylabel('Mean Power [kW]');
        title('Power Required vs Bank Angle');
        
        % Bank angle vs Turn radius
        subplot(2, 3, 6);
        plot(data(:,2), data(:,10), colors{speed_idx}, 'LineWidth', 2, 'MarkerSize', 8);
        hold on;
        grid on;
        xlabel('Bank Angle [deg]');
        ylabel('Turn Radius [ft]');
        title('Turn Radius vs Bank Angle');
    end
end

% Add legends to all subplots
for i = 1:6
    subplot(2, 3, i);
    legend(arrayfun(@(x) sprintf('%.0f kts', x), test_speeds_knots, 'UniformOutput', false), ...
        'Location', 'best');
end

sgtitle('Summary: Bank Angle Test Results', 'FontSize', 16, 'FontWeight', 'bold');
saveas(fig_summary, sprintf('%s/Summary_All_Tests.png', results_dir));
close(fig_summary);

%% Export Results to CSV
fprintf('Exporting results to CSV...\n');

% Create CSV file
csv_filename = sprintf('%s/Bank_Angle_Test_Results.csv', results_dir);
fid = fopen(csv_filename, 'w');

% Write header
fprintf(fid, 'Test_Num,Speed_knots,Bank_Angle_deg,Load_Factor_Theory,Load_Factor_Actual_Mean,Load_Factor_Actual_Max,');
fprintf(fid, 'Bank_Actual_Mean,Bank_Actual_Max,Bank_Actual_Std,V_Mean_fps,V_Min_fps,V_Drop_Percent,');
fprintf(fid, 'Alt_Change_ft,Alt_Loss_Rate_fps,Turn_Radius_Theory_ft,Turn_Radius_Actual_ft,Turn_Rate_degps,');
fprintf(fid, 'Power_Mean_kW,Power_Max_kW,Rotor_RPM_Mean,Rotor_RPM_Max,Pusher_RPM_Mean,Pusher_RPM_Max,');
fprintf(fid, 'Success,Failure_Reason\n');

% Write data
for i = 1:length(all_results)
    r = all_results{i};
    fprintf(fid, '%d,%.1f,%.1f,', r.test_num, r.speed_knots, r.bank_angle_deg);
    
    if r.success
        fprintf(fid, '%.3f,%.3f,%.3f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.1f,%.1f,%.3f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,', ...
            r.load_factor_theoretical, r.load_factor_actual_mean, r.load_factor_actual_max, ...
            r.bank_actual_mean, r.bank_actual_max, r.bank_actual_std, ...
            r.V_mean, r.V_min, r.V_drop_percent, ...
            r.alt_change, r.alt_loss_rate, ...
            r.turn_radius_theoretical, r.turn_radius_actual, r.turn_rate, ...
            r.power_mean_kW, r.power_max_kW, ...
            r.rotor_rpm_mean, r.rotor_rpm_max, r.pusher_rpm_mean, r.pusher_rpm_max);
        fprintf(fid, 'TRUE,%s\n', r.failure_reason);
    else
        fprintf(fid, ',,,,,,,,,,,,,,,,,,,FALSE,%s\n', strrep(r.failure_reason, ',', ';'));
    end
end

fclose(fid);

fprintf('CSV file saved: %s\n', csv_filename);

%% Final Summary
fprintf('\n=================================================\n');
fprintf('TEST COMPLETE\n');
fprintf('=================================================\n');
fprintf('Total Tests: %d\n', length(all_results));
fprintf('Successful: %d\n', sum(summary_data(:,20) == 1));
fprintf('Failed: %d\n', sum(summary_data(:,20) == 0));
fprintf('\nResults Directory: %s\n', results_dir);
fprintf('  - Individual test plots: Test_XX_SpeedXXX_BankXX.png\n');
fprintf('  - Summary plot: Summary_All_Tests.png\n');
fprintf('  - CSV data: Bank_Angle_Test_Results.csv\n');
fprintf('=================================================\n');

% Display maximum safe bank angles
fprintf('\nMaximum Safe Bank Angles:\n');
for speed_idx = 1:length(test_speeds_knots)
    speed = test_speeds_knots(speed_idx);
    idx = summary_data(:,1) == speed & summary_data(:,20) == 1;
    if sum(idx) > 0
        max_bank = max(summary_data(idx, 2));
        max_load = summary_data(summary_data(:,1)==speed & summary_data(:,2)==max_bank, 4);
        fprintf('  %.0f knots: %.0f° (Load Factor: %.2f g)\n', speed, max_bank, max_load);
    end
end

fprintf('\n✓ All plots and data exported successfully!\n');
