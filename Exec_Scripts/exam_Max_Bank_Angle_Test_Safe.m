%% Maximum Bank Angle Test - Safe Version with Assertion Handling
% This script tests bank angles incrementally and stops when limits are reached
% Uses conservative approach to find maximum safe bank angle

clear all; close all; clc;

%% Configuration
model = 'GUAM';
test_speeds_knots = [80, 100, 120];  % Cruise speeds to test (knots)
initial_bank = 10;  % Start with safe bank angle (degrees)
bank_increment = 5;  % Increment by 5 degrees
max_bank_test = 75;  % Maximum bank angle to attempt

% Convert speeds to ft/s
test_speeds_fps = test_speeds_knots * 1.68781;

% Results storage
all_results = {};
result_idx = 1;

% Create results directory
results_dir = './Bank_Angle_Test_Results';
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end

fprintf('=================================================\n');
fprintf('Maximum Bank Angle Test - Safe Version\n');
fprintf('=================================================\n');
fprintf('Configuration:\n');
fprintf('  Speeds: %s knots\n', num2str(test_speeds_knots));
fprintf('  Bank Range: %d° to %d° (increment: %d°)\n', ...
    initial_bank, max_bank_test, bank_increment);
fprintf('  Safety: Stops when RPM limits or stall detected\n');
fprintf('=================================================\n\n');

%% Disable Simulink Warnings for Assertions
warning('off', 'Simulink:blocks:AssertionAssert');

%% Main Test Loop
for speed_idx = 1:length(test_speeds_fps)
    cruise_speed = test_speeds_fps(speed_idx);
    cruise_speed_knots = test_speeds_knots(speed_idx);
    
    fprintf('\n╔══════════════════════════════════════════════════╗\n');
    fprintf('║  TESTING AT %.0f KNOTS (%.1f ft/s)               ║\n', ...
        cruise_speed_knots, cruise_speed);
    fprintf('╚══════════════════════════════════════════════════╝\n\n');
    
    % Test incrementally until failure
    current_bank = initial_bank;
    max_safe_bank = 0;
    continue_testing = true;
    
    while continue_testing && current_bank <= max_bank_test
        bank_angle_deg = current_bank;
        bank_angle_rad = bank_angle_deg * pi/180;
        
        fprintf('Testing Bank Angle: %.0f° ... ', bank_angle_deg);
        
        try
            %% Calculate Turn Parameters
            g = 32.174;  % ft/s^2
            load_factor = 1 / cos(bank_angle_rad);
            turn_radius = cruise_speed^2 / (g * tan(bank_angle_rad));
            turn_rate = g * tan(bank_angle_rad) / cruise_speed;  % rad/s
            turn_period = 2*pi / turn_rate;
            
            % Shorter simulation for testing (1 complete turn)
            sim_time = min(turn_period * 1.2, 60);  % Cap at 60 seconds
            
            %% Setup Trajectory
            userStruct.variants.refInputType = 3;
            
            % Generate circular trajectory
            num_points = max(50, ceil(sim_time));
            time = linspace(0, sim_time, num_points)';
            
            cruise_alt = -100;  % -100 ft in NED
            
            % Circular path (NED)
            theta = turn_rate * time;
            pos = zeros(num_points, 3);
            pos(:,1) = turn_radius * sin(theta);  % North
            pos(:,2) = turn_radius * (1 - cos(theta));  % East
            pos(:,3) = cruise_alt * ones(num_points, 1);  % Down
            
            % Calculate velocities
            vel_i = zeros(num_points, 3);
            vel_i(:,1) = gradient(pos(:,1)) ./ gradient(time);
            vel_i(:,2) = gradient(pos(:,2)) ./ gradient(time);
            vel_i(:,3) = gradient(pos(:,3)) ./ gradient(time);
            
            % Calculate heading
            chi = atan2(vel_i(:,2), vel_i(:,1));
            chid = gradient(chi) ./ gradient(time);
            
            % Add library
            addpath(genpath('lib'));
            
            % Convert to heading frame
            q = QrotZ(chi);
            vel = Qtrans(q, vel_i);
            
            % Setup trajectory
            clear target
            target.RefInput.Vel_bIc_des = timeseries(vel, time);
            target.RefInput.pos_des = timeseries(pos, time);
            target.RefInput.chi_des = timeseries(chi, time);
            target.RefInput.chi_dot_des = timeseries(chid, time);
            target.RefInput.vel_des = timeseries(vel_i, time);
            
            %% Initialize and Run Simulation
            simSetup;
            
            % Clear previous logsout
            if exist('logsout', 'var')
                clear logsout
            end
            
            % Capture warnings during simulation
            lastwarn('');  % Clear last warning
            
            % Run simulation
            sim(model, 'StopTime', num2str(time(end)));
            
            % Check for warnings
            [warnMsg, warnId] = lastwarn;
            has_warning = ~isempty(warnMsg);
            
            pause(0.1);
            
            % Check if logsout exists
            if ~exist('logsout', 'var')
                error('logsout not created');
            end
            
            % Extract results
            SimOut = logsout{1}.Values;
            t = SimOut.Time.Data;
            
            % Extract data
            pos_actual = squeeze(SimOut.Vehicle.EOM.InertialData.Pos_bii.Data);
            phi = SimOut.Vehicle.Sensor.Euler.phi.Data;
            theta = SimOut.Vehicle.Sensor.Euler.theta.Data;
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
            
            % Check RPM limits (main concern)
            if rotor_rpm_max > 1550  % Approaching 1600 RPM limit
                success = false;
                failure_reason = sprintf('Rotor RPM limit (%.0f RPM)', rotor_rpm_max);
                stop_testing = true;
            elseif pusher_rpm_max > 1950  % Approaching 2000 RPM limit
                success = false;
                failure_reason = sprintf('Pusher RPM limit (%.0f RPM)', pusher_rpm_max);
                stop_testing = true;
            elseif V_drop > 15  % Excessive speed loss
                success = false;
                failure_reason = sprintf('Speed loss %.1f%%', V_drop);
                stop_testing = true;
            elseif alt_loss_rate < -8  % Excessive altitude loss
                success = false;
                failure_reason = sprintf('Altitude loss %.1f ft/s', alt_loss_rate);
                stop_testing = true;
            elseif any(isnan(V_tot)) || any(isinf(V_tot))
                success = false;
                failure_reason = 'Numerical instability';
                stop_testing = true;
            elseif has_warning && contains(warnMsg, 'Assertion')
                success = false;
                failure_reason = 'Assertion warning detected';
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
            
            % Store time history
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
            
            %% Print Results
            if success
                fprintf('✓ PASS\n');
                fprintf('    Bank: %.1f° (±%.1f°), Load: %.2f g\n', ...
                    bank_actual_mean, bank_actual_std, load_factor_actual_mean);
                fprintf('    Rotor RPM: %.0f (max), Speed Loss: %.1f%%\n', ...
                    rotor_rpm_max, V_drop);
                fprintf('    Power: %.0f kW, Alt Change: %.1f ft\n', ...
                    power_mean, alt_change);
                
                % Update max safe bank angle
                max_safe_bank = bank_angle_deg;
                
                % Increment for next test
                current_bank = current_bank + bank_increment;
            else
                fprintf('✗ FAIL: %s\n', failure_reason);
                fprintf('    Rotor RPM: %.0f, Pusher RPM: %.0f\n', ...
                    rotor_rpm_max, pusher_rpm_max);
                
                if stop_testing
                    fprintf('    ⚠ Stopping tests at this speed (limit reached)\n');
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
            
            % Stop testing at this speed if error occurs
            continue_testing = false;
        end
    end
    
    % Print maximum safe bank angle for this speed
    fprintf('\n');
    fprintf('═══════════════════════════════════════════════════\n');
    fprintf('  ✓ Maximum Safe Bank Angle at %.0f knots: %.0f°\n', ...
        cruise_speed_knots, max_safe_bank);
    fprintf('═══════════════════════════════════════════════════\n');
end

%% Re-enable warnings
warning('on', 'Simulink:blocks:AssertionAssert');

%% Generate Plots for Successful Tests
fprintf('\n=================================================\n');
fprintf('Generating Plots...\n');
fprintf('=================================================\n');

for i = 1:length(all_results)
    r = all_results{i};
    
    if r.success && isfield(r, 't')
        fprintf('Generating plot for Test %d (%.0f kts, %.0f°)...\n', ...
            r.test_num, r.speed_knots, r.bank_angle_deg);
        
        fig = figure('Position', [100, 100, 1400, 1000], 'Visible', 'off');
        
        % 3D Trajectory
        subplot(3, 3, 1);
        plot3(r.pos_des(:,1), r.pos_des(:,2), r.pos_des(:,3), 'b--', 'LineWidth', 1.5);
        hold on;
        plot3(r.pos(:,1), r.pos(:,2), r.pos(:,3), 'r-', 'LineWidth', 2);
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
        plot(r.pos_des(:,2), r.pos_des(:,1), 'b--', 'LineWidth', 1.5);
        hold on;
        plot(r.pos(:,2), r.pos(:,1), 'r-', 'LineWidth', 2);
        grid on;
        xlabel('East [ft]');
        ylabel('North [ft]');
        title('Ground Track');
        legend('Desired', 'Actual');
        axis equal;
        
        % Bank Angle
        subplot(3, 3, 3);
        plot(r.t, r.phi * 180/pi, 'LineWidth', 2);
        hold on;
        yline(r.bank_angle_deg, 'r--', 'Commanded', 'LineWidth', 1.5);
        yline(-r.bank_angle_deg, 'r--', 'LineWidth', 1.5);
        grid on;
        xlabel('Time [s]');
        ylabel('Bank Angle [deg]');
        title(sprintf('Bank Angle (Mean: %.1f°)', r.bank_actual_mean));
        
        % Velocity
        subplot(3, 3, 4);
        plot(r.t, r.V_tot, 'LineWidth', 2);
        hold on;
        yline(r.speed_fps, 'r--', 'Commanded', 'LineWidth', 1.5);
        grid on;
        xlabel('Time [s]');
        ylabel('Velocity [ft/s]');
        title(sprintf('Velocity (Loss: %.1f%%)', r.V_drop_percent));
        
        % Altitude
        subplot(3, 3, 5);
        plot(r.t, -r.pos(:,3), 'LineWidth', 2);
        hold on;
        yline(100, 'r--', 'Commanded', 'LineWidth', 1.5);
        grid on;
        xlabel('Time [s]');
        ylabel('Altitude [ft]');
        title(sprintf('Altitude (Change: %.1f ft)', r.alt_change));
        
        % Load Factor
        subplot(3, 3, 6);
        n = 1 ./ cos(r.phi);
        plot(r.t, n, 'LineWidth', 2);
        hold on;
        yline(r.load_factor_theoretical, 'r--', 'Theoretical', 'LineWidth', 1.5);
        grid on;
        xlabel('Time [s]');
        ylabel('Load Factor [g]');
        title(sprintf('Load Factor (%.2f g)', r.load_factor_actual_mean));
        
        % Control Surfaces
        subplot(3, 3, 7);
        plot(r.t, [r.dele r.dela r.delr] * 180/pi, 'LineWidth', 1.5);
        grid on;
        xlabel('Time [s]');
        ylabel('Deflection [deg]');
        title('Control Surfaces');
        legend('Elevator', 'Aileron', 'Rudder');
        
        % Propeller Speeds
        subplot(3, 3, 8);
        plot(r.t, r.prop_rpm(:,1:8), 'LineWidth', 1);
        hold on;
        plot(r.t, r.prop_rpm(:,9), 'k-', 'LineWidth', 2);
        yline(1600, 'r--', 'Rotor Limit', 'LineWidth', 1);
        yline(2000, 'm--', 'Pusher Limit', 'LineWidth', 1);
        grid on;
        xlabel('Time [s]');
        ylabel('RPM');
        title(sprintf('Propeller Speeds (Max: %.0f RPM)', r.rotor_rpm_max));
        ylim([0, 2100]);
        
        % Total Power
        subplot(3, 3, 9);
        plot(r.t, r.total_power/1000, 'LineWidth', 2);
        grid on;
        xlabel('Time [s]');
        ylabel('Power [kW]');
        title(sprintf('Total Power (%.0f kW)', r.power_mean_kW));
        
        sgtitle(sprintf('Test %d: %.0f kts, %.0f° Bank, n=%.2f g - SUCCESS', ...
            r.test_num, r.speed_knots, r.bank_angle_deg, r.load_factor_theoretical), ...
            'FontSize', 14, 'FontWeight', 'bold');
        
        saveas(fig, sprintf('%s/Test_%03d_Speed%03d_Bank%02d.png', ...
            results_dir, r.test_num, r.speed_knots, r.bank_angle_deg));
        close(fig);
    end
end

%% Generate Summary Plot
fprintf('Generating summary plot...\n');

fig_summary = figure('Position', [100, 100, 1600, 1000], 'Visible', 'off');

colors = {'b-o', 'r-s', 'g-d'};
markers = {'o', 's', 'd'};

for speed_idx = 1:length(test_speeds_knots)
    speed = test_speeds_knots(speed_idx);
    
    % Extract data for this speed
    speed_results = {};
    for i = 1:length(all_results)
        if all_results{i}.speed_knots == speed && all_results{i}.success
            speed_results{end+1} = all_results{i};
        end
    end
    
    if ~isempty(speed_results)
        n_pts = length(speed_results);
        banks = zeros(n_pts, 1);
        loads = zeros(n_pts, 1);
        v_drops = zeros(n_pts, 1);
        powers = zeros(n_pts, 1);
        rpms = zeros(n_pts, 1);
        
        for j = 1:n_pts
            banks(j) = speed_results{j}.bank_angle_deg;
            loads(j) = speed_results{j}.load_factor_actual_mean;
            v_drops(j) = speed_results{j}.V_drop_percent;
            powers(j) = speed_results{j}.power_mean_kW;
            rpms(j) = speed_results{j}.rotor_rpm_max;
        end
        
        % Load Factor
        subplot(2, 3, 1);
        plot(banks, loads, colors{speed_idx}, 'LineWidth', 2, 'MarkerSize', 8);
        hold on;
        grid on;
        xlabel('Bank Angle [deg]');
        ylabel('Load Factor [g]');
        title('Load Factor vs Bank Angle');
        
        % Speed Loss
        subplot(2, 3, 2);
        plot(banks, v_drops, colors{speed_idx}, 'LineWidth', 2, 'MarkerSize', 8);
        hold on;
        grid on;
        xlabel('Bank Angle [deg]');
        ylabel('Speed Loss [%]');
        title('Speed Loss vs Bank Angle');
        
        % Power
        subplot(2, 3, 3);
        plot(banks, powers, colors{speed_idx}, 'LineWidth', 2, 'MarkerSize', 8);
        hold on;
        grid on;
        xlabel('Bank Angle [deg]');
        ylabel('Power [kW]');
        title('Power vs Bank Angle');
        
        % RPM
        subplot(2, 3, 4);
        plot(banks, rpms, colors{speed_idx}, 'LineWidth', 2, 'MarkerSize', 8);
        hold on;
        yline(1600, 'r--', 'Limit', 'LineWidth', 2);
        grid on;
        xlabel('Bank Angle [deg]');
        ylabel('Max Rotor RPM');
        title('Rotor RPM vs Bank Angle');
        
        % Load Factor vs RPM
        subplot(2, 3, 5);
        plot(loads, rpms, colors{speed_idx}, 'LineWidth', 2, 'MarkerSize', 8);
        hold on;
        yline(1600, 'r--', 'RPM Limit', 'LineWidth', 2);
        grid on;
        xlabel('Load Factor [g]');
        ylabel('Max Rotor RPM');
        title('RPM vs Load Factor');
        
        % Speed vs Max Bank
        subplot(2, 3, 6);
        plot(speed, max(banks), markers{speed_idx}, 'MarkerSize', 15, ...
            'LineWidth', 3, 'Color', colors{speed_idx}(1));
        hold on;
        text(speed, max(banks)+1, sprintf('%.0f°', max(banks)), ...
            'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
        grid on;
        xlabel('Cruise Speed [knots]');
        ylabel('Maximum Safe Bank Angle [deg]');
        title('Maximum Safe Bank Angle');
    end
end

% Add legends
for i = 1:5
    subplot(2, 3, i);
    legend(arrayfun(@(x) sprintf('%.0f kts', x), test_speeds_knots, 'UniformOutput', false), ...
        'Location', 'best');
end

subplot(2, 3, 6);
legend(arrayfun(@(x) sprintf('%.0f kts', x), test_speeds_knots, 'UniformOutput', false), ...
    'Location', 'best');
xlim([min(test_speeds_knots)-10, max(test_speeds_knots)+10]);

sgtitle('Bank Angle Test Summary', 'FontSize', 16, 'FontWeight', 'bold');
saveas(fig_summary, sprintf('%s/Summary_All_Speeds.png', results_dir));
close(fig_summary);

%% Export to CSV
fprintf('Exporting to CSV...\n');

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
fprintf('Total Tests: %d\n', length(all_results));

successful_count = 0;
for i = 1:length(all_results)
    if all_results{i}.success
        successful_count = successful_count + 1;
    end
end

fprintf('Successful: %d\n', successful_count);
fprintf('Failed: %d\n', length(all_results) - successful_count);
fprintf('\nResults saved to: %s\n', results_dir);
fprintf('=================================================\n');

fprintf('\n📊 MAXIMUM SAFE BANK ANGLES:\n');
fprintf('═══════════════════════════════════════════════════\n');
for speed_idx = 1:length(test_speeds_knots)
    speed = test_speeds_knots(speed_idx);
    max_bank = 0;
    max_load = 0;
    
    for i = 1:length(all_results)
        r = all_results{i};
        if r.speed_knots == speed && r.success && r.bank_angle_deg > max_bank
            max_bank = r.bank_angle_deg;
            if isfield(r, 'load_factor_actual_mean')
                max_load = r.load_factor_actual_mean;
            end
        end
    end
    
    if max_bank > 0
        fprintf('  %.0f knots: %.0f° (Load Factor: %.2f g)\n', speed, max_bank, max_load);
    else
        fprintf('  %.0f knots: No successful tests\n', speed);
    end
end
fprintf('═══════════════════════════════════════════════════\n');

fprintf('\n✓ All results exported successfully!\n');
