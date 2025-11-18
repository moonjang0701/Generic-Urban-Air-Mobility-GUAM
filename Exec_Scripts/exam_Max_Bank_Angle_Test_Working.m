%% Maximum Bank Angle Test - Working Version
% Uses exact GUAM workflow pattern

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
fprintf('Maximum Bank Angle Test - Working Version\n');
fprintf('=================================================\n');
fprintf('Speeds: %s knots\n', num2str(test_speeds_knots));
fprintf('Bank Range: %d° to %d° (step: %d°)\n', ...
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
    fprintf('║  TESTING AT %.0f KNOTS                            ║\n', cruise_speed_knots);
    fprintf('╚══════════════════════════════════════════════════╝\n\n');
    
    current_bank = initial_bank;
    max_safe_bank = 0;
    continue_testing = true;
    
    while continue_testing && current_bank <= max_bank_test
        bank_angle_deg = current_bank;
        bank_angle_rad = bank_angle_deg * pi/180;
        
        fprintf('Test %.0f kts / %.0f° ... ', cruise_speed_knots, bank_angle_deg);
        
        try
            %% Calculate Turn Parameters
            g = 32.174;
            load_factor = 1 / cos(bank_angle_rad);
            turn_radius = cruise_speed^2 / (g * tan(bank_angle_rad));
            turn_rate = g * tan(bank_angle_rad) / cruise_speed;
            turn_period = 2*pi / turn_rate;
            
            sim_time = min(turn_period * 1.2, 60);
            
            %% Setup Trajectory - EXACTLY like GUAM examples
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
            
            % Clear any previous target
            clear target
            
            % Setup trajectory - match bus structure exactly
            target.RefInput.Vel_bIc_des = timeseries(vel, time);
            target.RefInput.pos_des = timeseries(pos, time);
            target.RefInput.chi_des = timeseries(chi, time);
            target.RefInput.chi_dot_des = timeseries(chid, time);
            target.RefInput.vel_des = timeseries(vel_i, time);
            
            %% Run setup - this creates SimIn structure
            simSetup;
            
            %% Set simulation stop time in model configuration
            % This is the key difference!
            set_param(model, 'StopTime', num2str(time(end)));
            
            %% Clear previous logsout from base workspace
            evalin('base', 'clear logsout');
            
            %% Run simulation - EXACTLY like RUNME.m
            sim(model);
            
            %% Small pause to ensure logsout is written
            pause(0.2);
            
            %% Check logsout in base workspace
            if ~evalin('base', 'exist(''logsout'', ''var'')')
                error('logsout was not created after simulation');
            end
            
            %% Extract from base workspace - like simPlots_GUAM.m does
            SimOut = evalin('base', 'logsout{1}.Values');
            
            %% Extract data
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
            
            % Check RPM limits
            if rotor_rpm_max > 1550
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
            elseif alt_loss_rate < -8
                success = false;
                failure_reason = sprintf('Alt loss %.1f ft/s', alt_loss_rate);
                stop_testing = true;
            elseif any(isnan(V_tot)) || any(isinf(V_tot))
                success = false;
                failure_reason = 'Numerical instability';
                stop_testing = true;
            end
            
            %% Store Complete Results
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
            
            % Store time history for plotting
            result.t = t;
            result.pos = pos_actual;
            result.phi = phi;
            result.theta = theta_angle;
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
                fprintf('✓ OK (φ=%.1f°, n=%.2f, RPM=%.0f)\n', ...
                    bank_actual_mean, load_factor_actual_mean, rotor_rpm_max);
                max_safe_bank = bank_angle_deg;
                current_bank = current_bank + bank_increment;
            else
                fprintf('✗ FAIL: %s\n', failure_reason);
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
    
    fprintf('  → Max safe bank: %.0f°\n', max_safe_bank);
end

%% Generate Individual Test Plots
fprintf('\n=================================================\n');
fprintf('Generating plots...\n');

for i = 1:length(all_results)
    r = all_results{i};
    
    if r.success && isfield(r, 't')
        fig = figure('Position', [100, 100, 1400, 1000], 'Visible', 'off');
        
        % 3D Path
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
        legend('Desired', 'Actual');
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
        axis equal;
        
        % Bank Angle
        subplot(3, 3, 3);
        plot(r.t, r.phi * 180/pi, 'LineWidth', 2);
        hold on;
        yline(r.bank_angle_deg, 'r--', 'LineWidth', 1.5);
        yline(-r.bank_angle_deg, 'r--', 'LineWidth', 1.5);
        grid on;
        xlabel('Time [s]');
        ylabel('Bank Angle [deg]');
        title(sprintf('Bank (%.1f°)', r.bank_actual_mean));
        
        % Velocity
        subplot(3, 3, 4);
        plot(r.t, r.V_tot, 'LineWidth', 2);
        hold on;
        yline(r.speed_fps, 'r--', 'LineWidth', 1.5);
        grid on;
        xlabel('Time [s]');
        ylabel('Velocity [ft/s]');
        title(sprintf('Velocity (%.1f%% loss)', r.V_drop_percent));
        
        % Altitude
        subplot(3, 3, 5);
        plot(r.t, -r.pos(:,3), 'LineWidth', 2);
        hold on;
        yline(100, 'r--', 'LineWidth', 1.5);
        grid on;
        xlabel('Time [s]');
        ylabel('Altitude [ft]');
        title(sprintf('Altitude (%.1f ft change)', r.alt_change));
        
        % Load Factor
        subplot(3, 3, 6);
        n = 1 ./ cos(r.phi);
        plot(r.t, n, 'LineWidth', 2);
        hold on;
        yline(r.load_factor_theoretical, 'r--', 'LineWidth', 1.5);
        grid on;
        xlabel('Time [s]');
        ylabel('Load Factor [g]');
        title(sprintf('n = %.2f g', r.load_factor_actual_mean));
        
        % Control Surfaces
        subplot(3, 3, 7);
        plot(r.t, [r.dele r.dela r.delr] * 180/pi, 'LineWidth', 1.5);
        grid on;
        xlabel('Time [s]');
        ylabel('Deflection [deg]');
        title('Control Surfaces');
        legend('Elev', 'Ail', 'Rud');
        
        % Propeller RPM
        subplot(3, 3, 8);
        plot(r.t, r.prop_rpm(:,1:8), 'LineWidth', 1);
        hold on;
        plot(r.t, r.prop_rpm(:,9), 'k-', 'LineWidth', 2);
        yline(1600, 'r--', 'Limit', 'LineWidth', 1);
        grid on;
        xlabel('Time [s]');
        ylabel('RPM');
        title(sprintf('Props (max %.0f)', r.rotor_rpm_max));
        ylim([0, 1800]);
        
        % Power
        subplot(3, 3, 9);
        plot(r.t, r.total_power/1000, 'LineWidth', 2);
        grid on;
        xlabel('Time [s]');
        ylabel('Power [kW]');
        title(sprintf('Power (%.0f kW)', r.power_mean_kW));
        
        sgtitle(sprintf('Test %d: %.0f kts, %.0f° bank, n=%.2f g', ...
            r.test_num, r.speed_knots, r.bank_angle_deg, r.load_factor_theoretical), ...
            'FontSize', 14, 'FontWeight', 'bold');
        
        saveas(fig, sprintf('%s/Test_%03d_Speed%03d_Bank%02d.png', ...
            results_dir, r.test_num, r.speed_knots, r.bank_angle_deg));
        close(fig);
    end
end

%% Export CSV
fprintf('Exporting CSV...\n');

csv_file = sprintf('%s/Bank_Angle_Test_Results.csv', results_dir);
fid = fopen(csv_file, 'w');

fprintf(fid, 'Test,Speed_kts,Bank_deg,Load_Theory,Load_Actual,Bank_Actual,');
fprintf(fid, 'V_Drop_pct,Alt_Change_ft,Power_kW,Rotor_RPM,Success,Reason\n');

for i = 1:length(all_results)
    r = all_results{i};
    if r.success
        fprintf(fid, '%d,%.0f,%.0f,%.2f,%.2f,%.1f,%.1f,%.1f,%.0f,%.0f,TRUE,%s\n', ...
            r.test_num, r.speed_knots, r.bank_angle_deg, ...
            r.load_factor_theoretical, r.load_factor_actual_mean, ...
            r.bank_actual_mean, r.V_drop_percent, r.alt_change, ...
            r.power_mean_kW, r.rotor_rpm_max, r.failure_reason);
    else
        fprintf(fid, '%d,%.0f,%.0f,,,,,,,FALSE,%s\n', ...
            r.test_num, r.speed_knots, r.bank_angle_deg, ...
            strrep(r.failure_reason, ',', ';'));
    end
end

fclose(fid);

%% Summary
fprintf('\n=================================================\n');
fprintf('RESULTS SUMMARY\n');
fprintf('=================================================\n');

success_count = sum(cellfun(@(x) x.success, all_results));
fprintf('Total: %d, Success: %d, Failed: %d\n', ...
    length(all_results), success_count, length(all_results) - success_count);

fprintf('\n📊 MAXIMUM SAFE BANK ANGLES:\n');
fprintf('═══════════════════════════════════════════════\n');

for speed_idx = 1:length(test_speeds_knots)
    speed = test_speeds_knots(speed_idx);
    max_bank = 0;
    
    for i = 1:length(all_results)
        r = all_results{i};
        if r.speed_knots == speed && r.success
            max_bank = max(max_bank, r.bank_angle_deg);
        end
    end
    
    if max_bank > 0
        fprintf('  %.0f knots: %.0f°\n', speed, max_bank);
    else
        fprintf('  %.0f knots: No successful tests\n', speed);
    end
end

fprintf('═══════════════════════════════════════════════\n');
fprintf('\n✓ Results saved to: %s\n', results_dir);

warning('on', 'all');
