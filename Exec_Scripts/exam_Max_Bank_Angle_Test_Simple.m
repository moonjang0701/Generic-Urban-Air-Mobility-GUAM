%% Maximum Bank Angle Test - Simplified Version
% Uses GUAM's standard workflow: setup -> open model -> manual run

clear all; close all; clc;

%% Instructions
fprintf('=================================================\n');
fprintf('BANK ANGLE TEST - INTERACTIVE VERSION\n');
fprintf('=================================================\n');
fprintf('This script will prepare each test configuration.\n');
fprintf('After setup, you will manually click "Run" in Simulink.\n');
fprintf('=================================================\n\n');

%% Configuration
model = 'GUAM';
test_configs = [
    % Speed(kts), Bank(deg)
    80, 10;
    80, 15;
    80, 20;
    80, 25;
    80, 30;
    100, 10;
    100, 15;
    100, 20;
    100, 25;
    100, 30;
    100, 35;
    120, 10;
    120, 15;
    120, 20;
    120, 25;
    120, 30;
    120, 35;
    120, 40;
];

n_tests = size(test_configs, 1);

% Results storage
results_dir = './Bank_Angle_Test_Results';
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end

fprintf('Total tests to run: %d\n\n', n_tests);
response = input('Press ENTER to start, or type "quit" to cancel: ', 's');
if strcmpi(response, 'quit')
    fprintf('Cancelled.\n');
    return;
end

%% Run Tests
all_results = {};

for test_idx = 1:n_tests
    cruise_speed_knots = test_configs(test_idx, 1);
    bank_angle_deg = test_configs(test_idx, 2);
    
    cruise_speed = cruise_speed_knots * 1.68781;  % Convert to ft/s
    bank_angle_rad = bank_angle_deg * pi/180;
    
    fprintf('\n\n');
    fprintf('═══════════════════════════════════════════════════\n');
    fprintf('TEST %d/%d\n', test_idx, n_tests);
    fprintf('═══════════════════════════════════════════════════\n');
    fprintf('Speed: %.0f knots (%.1f ft/s)\n', cruise_speed_knots, cruise_speed);
    fprintf('Bank Angle: %.0f degrees\n', bank_angle_deg);
    fprintf('═══════════════════════════════════════════════════\n\n');
    
    try
        %% Calculate Turn Parameters
        g = 32.174;
        load_factor = 1 / cos(bank_angle_rad);
        turn_radius = cruise_speed^2 / (g * tan(bank_angle_rad));
        turn_rate = g * tan(bank_angle_rad) / cruise_speed;
        turn_period = 2*pi / turn_rate;
        
        sim_time = min(turn_period * 1.2, 60);
        
        fprintf('Expected:\n');
        fprintf('  Load Factor: %.2f g\n', load_factor);
        fprintf('  Turn Radius: %.0f ft\n', turn_radius);
        fprintf('  Turn Period: %.1f sec\n', turn_period);
        fprintf('  Simulation Time: %.1f sec\n\n', sim_time);
        
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
        
        %% Initialize
        fprintf('Initializing simulation...\n');
        simSetup;
        
        %% Open model
        fprintf('Opening Simulink model...\n');
        open_system(model);
        
        fprintf('\n');
        fprintf('╔══════════════════════════════════════════════════╗\n');
        fprintf('║  READY TO RUN                                    ║\n');
        fprintf('║                                                  ║\n');
        fprintf('║  Please click the "Run" button in Simulink      ║\n');
        fprintf('║  or press Ctrl+T                                ║\n');
        fprintf('╚══════════════════════════════════════════════════╝\n');
        fprintf('\n');
        
        % Wait for user to run simulation
        input('Press ENTER after simulation completes: ', 's');
        
        %% Check if logsout exists
        if ~evalin('base', 'exist(''logsout'', ''var'')')
            error('logsout variable not found. Did you run the simulation?');
        end
        
        %% Extract Results
        fprintf('Extracting results...\n');
        logsout_data = evalin('base', 'logsout');
        SimOut = logsout_data{1}.Values;
        
        t = SimOut.Time.Data;
        pos_actual = squeeze(SimOut.Vehicle.EOM.InertialData.Pos_bii.Data);
        phi = SimOut.Vehicle.Sensor.Euler.phi.Data;
        V_tot = SimOut.Vehicle.Sensor.Vtot.Data;
        
        prop_om = SimOut.Vehicle.PropAct.EngSpeed.Data;
        prop_rpm = prop_om * 60 / (2*pi);
        
        %% Analyze
        bank_actual_mean = mean(abs(phi)) * 180/pi;
        load_factor_actual = mean(1 ./ cos(phi));
        V_mean = mean(V_tot);
        V_drop = (cruise_speed - min(V_tot)) / cruise_speed * 100;
        rotor_rpm_max = max(max(prop_rpm(:,1:8)));
        
        fprintf('\nResults:\n');
        fprintf('  Actual Bank: %.1f°\n', bank_actual_mean);
        fprintf('  Load Factor: %.2f g\n', load_factor_actual);
        fprintf('  Speed Loss: %.1f%%\n', V_drop);
        fprintf('  Max Rotor RPM: %.0f\n', rotor_rpm_max);
        
        % Store result
        result = struct();
        result.test_num = test_idx;
        result.speed_knots = cruise_speed_knots;
        result.bank_angle_deg = bank_angle_deg;
        result.bank_actual_mean = bank_actual_mean;
        result.load_factor_actual = load_factor_actual;
        result.V_drop_percent = V_drop;
        result.rotor_rpm_max = rotor_rpm_max;
        result.success = (rotor_rpm_max < 1550) && (V_drop < 15);
        
        all_results{test_idx} = result;
        
        if result.success
            fprintf('✓ TEST PASSED\n');
        else
            fprintf('✗ TEST FAILED\n');
            if rotor_rpm_max >= 1550
                fprintf('  Reason: RPM limit exceeded\n');
            end
            if V_drop >= 15
                fprintf('  Reason: Excessive speed loss\n');
            end
        end
        
        % Save data for this test
        save(sprintf('%s/Test_%02d_Data.mat', results_dir, test_idx), ...
             'SimOut', 'result', 'pos', 'time');
        
    catch ME
        fprintf('✗ ERROR: %s\n', ME.message);
        result = struct();
        result.test_num = test_idx;
        result.speed_knots = cruise_speed_knots;
        result.bank_angle_deg = bank_angle_deg;
        result.success = false;
        result.error = ME.message;
        all_results{test_idx} = result;
    end
    
    % Ask to continue
    if test_idx < n_tests
        fprintf('\n');
        response = input('Continue to next test? (ENTER=yes, "quit"=stop): ', 's');
        if strcmpi(response, 'quit')
            fprintf('Stopping tests.\n');
            break;
        end
    end
end

%% Export Results
fprintf('\n\nExporting results to CSV...\n');
csv_filename = sprintf('%s/Bank_Angle_Test_Results.csv', results_dir);
fid = fopen(csv_filename, 'w');

fprintf(fid, 'Test_Num,Speed_knots,Bank_Angle_deg,Bank_Actual,Load_Factor,');
fprintf(fid, 'V_Drop_Percent,Rotor_RPM_Max,Success\n');

for i = 1:length(all_results)
    r = all_results{i};
    if r.success
        fprintf(fid, '%d,%.1f,%.1f,%.1f,%.2f,%.1f,%.0f,TRUE\n', ...
            r.test_num, r.speed_knots, r.bank_angle_deg, ...
            r.bank_actual_mean, r.load_factor_actual, ...
            r.V_drop_percent, r.rotor_rpm_max);
    else
        fprintf(fid, '%d,%.1f,%.1f,,,,,FALSE\n', ...
            r.test_num, r.speed_knots, r.bank_angle_deg);
    end
end

fclose(fid);

fprintf('CSV saved: %s\n', csv_filename);
fprintf('\n✓ All tests complete!\n');
