%% UAV Flight Safety Measurements in GUAM Environment
% Based on: "Flight safety measurements of UAVs in congested airspace"
% Implements safety metrics for dense UAV operations

clear all; close all; clc;

%% Configuration
model = 'GUAM';

% Test scenario: Multiple UAVs in shared airspace
% We'll simulate single UAV and calculate safety metrics

fprintf('=================================================\n');
fprintf('UAV FLIGHT SAFETY MEASUREMENTS\n');
fprintf('Based on congested airspace safety research\n');
fprintf('=================================================\n\n');

%% Safety Parameters Definition

% Separation requirements (based on UAM standards)
safety_params = struct();
safety_params.min_horizontal_sep = 500;  % ft (minimum horizontal separation)
safety_params.min_vertical_sep = 100;    % ft (minimum vertical separation)
safety_params.warning_time = 30;         % seconds (time to conflict warning)
safety_params.critical_time = 15;        % seconds (critical time threshold)

% Protected zone dimensions
safety_params.protected_radius = 250;    % ft (cylindrical protection zone radius)
safety_params.protected_height = 50;     % ft (vertical protection)

fprintf('Safety Parameters:\n');
fprintf('  Horizontal separation: %.0f ft\n', safety_params.min_horizontal_sep);
fprintf('  Vertical separation: %.0f ft\n', safety_params.min_vertical_sep);
fprintf('  Protected radius: %.0f ft\n', safety_params.protected_radius);
fprintf('  Warning time: %.0f sec\n\n', safety_params.warning_time);

%% Test Scenario: Cruise Flight with Safety Monitoring

% Setup cruise trajectory
userStruct.variants.refInputType = 3;

% 60 second cruise flight at 100 knots
cruise_speed_knots = 100;
cruise_speed_fps = cruise_speed_knots * 1.68781;
sim_time = 60;

time = linspace(0, sim_time, 100)';
cruise_alt = -100;  % 100 ft altitude

% Straight and level flight
pos = zeros(length(time), 3);
pos(:,1) = cruise_speed_fps * time;  % North
pos(:,2) = 0;                        % East (straight)
pos(:,3) = cruise_alt * ones(length(time), 1);  % Constant altitude

% Calculate velocities
vel_i = zeros(length(time), 3);
vel_i(:,1) = gradient(pos(:,1)) ./ gradient(time);
vel_i(:,2) = gradient(pos(:,2)) ./ gradient(time);
vel_i(:,3) = gradient(pos(:,3)) ./ gradient(time);

% Heading
chi = atan2(vel_i(:,2), vel_i(:,1));
chid = gradient(chi) ./ gradient(time);

addpath(genpath('lib'));
q = QrotZ(chi);
vel = Qtrans(q, vel_i);

% Setup trajectory
clear target
target.tas = cruise_speed_knots;
target.RefInput.Vel_bIc_des = timeseries(vel, time);
target.RefInput.pos_des = timeseries(pos, time);
target.RefInput.chi_des = timeseries(chi, time);
target.RefInput.chi_dot_des = timeseries(chid, time);
target.RefInput.vel_des = timeseries(vel_i, time);

%% Run Simulation
fprintf('Running simulation...\n');
simSetup;
set_param(model, 'StopTime', num2str(time(end)));

evalin('base', 'clear logsout');
warning('off', 'all');

try
    sim(model);
    pause(0.2);
    
    if ~evalin('base', 'exist(''logsout'', ''var'')')
        error('Simulation output not available');
    end
    
    SimOut = evalin('base', 'logsout{1}.Values');
    
    %% Extract Flight Data
    t = SimOut.Time.Data;
    pos_actual = squeeze(SimOut.Vehicle.EOM.InertialData.Pos_bii.Data);
    
    % Velocity components
    V_tot = SimOut.Vehicle.Sensor.Vtot.Data;
    
    % Attitude
    phi = SimOut.Vehicle.Sensor.Euler.phi.Data;
    theta = SimOut.Vehicle.Sensor.Euler.theta.Data;
    psi = SimOut.Vehicle.Sensor.Euler.psi.Data;
    
    % Accelerations (if available)
    % accel = SimOut.Vehicle.EOM.InertialData.Accel_bii.Data;
    
    fprintf('✓ Simulation completed successfully\n\n');
    
    %% Calculate Safety Metrics
    fprintf('=================================================\n');
    fprintf('CALCULATING SAFETY METRICS\n');
    fprintf('=================================================\n\n');
    
    % 1. Path Deviation Analysis
    fprintf('1. PATH TRACKING ACCURACY\n');
    fprintf('   (Deviation from planned trajectory)\n');
    pos_error = pos_actual - pos(1:length(t), :);
    
    % Horizontal deviation
    horiz_error = sqrt(pos_error(:,1).^2 + pos_error(:,2).^2);
    vertical_error = abs(pos_error(:,3));
    
    fprintf('   Mean horizontal deviation: %.2f ft\n', mean(horiz_error));
    fprintf('   Max horizontal deviation: %.2f ft\n', max(horiz_error));
    fprintf('   Mean vertical deviation: %.2f ft\n', mean(vertical_error));
    fprintf('   Max vertical deviation: %.2f ft\n', max(vertical_error));
    
    % Check if protected zone violated
    if max(horiz_error) > safety_params.protected_radius
        fprintf('   ⚠️  WARNING: Protected zone violated!\n');
    else
        fprintf('   ✓ Protected zone maintained\n');
    end
    fprintf('\n');
    
    % 2. Velocity Stability
    fprintf('2. VELOCITY STABILITY\n');
    V_mean = mean(V_tot);
    V_std = std(V_tot);
    V_variation = (V_std / V_mean) * 100;
    
    fprintf('   Mean velocity: %.2f ft/s (%.1f kts)\n', V_mean, V_mean/1.68781);
    fprintf('   Velocity std dev: %.2f ft/s\n', V_std);
    fprintf('   Coefficient of variation: %.2f%%\n', V_variation);
    
    if V_variation < 5
        fprintf('   ✓ Velocity highly stable\n');
    elseif V_variation < 10
        fprintf('   ✓ Velocity acceptable\n');
    else
        fprintf('   ⚠️  WARNING: High velocity variation\n');
    end
    fprintf('\n');
    
    % 3. Attitude Stability
    fprintf('3. ATTITUDE STABILITY\n');
    phi_deg = phi * 180/pi;
    theta_deg = theta * 180/pi;
    
    phi_rms = sqrt(mean(phi_deg.^2));
    theta_rms = sqrt(mean(theta_deg.^2));
    
    fprintf('   Roll RMS: %.2f°\n', phi_rms);
    fprintf('   Pitch RMS: %.2f°\n', theta_rms);
    fprintf('   Max roll: %.2f°\n', max(abs(phi_deg)));
    fprintf('   Max pitch: %.2f°\n', max(abs(theta_deg)));
    
    if phi_rms < 5 && theta_rms < 5
        fprintf('   ✓ Attitude highly stable\n');
    elseif phi_rms < 10 && theta_rms < 10
        fprintf('   ✓ Attitude acceptable\n');
    else
        fprintf('   ⚠️  WARNING: High attitude variation\n');
    end
    fprintf('\n');
    
    % 4. Safety Zone Analysis (Conflict Probability Calculation)
    fprintf('4. CONFLICT PROBABILITY ANALYSIS\n');
    fprintf('   (Simulated intruder scenarios)\n');
    
    % Simulate potential intruder positions
    n_intruders = 5;
    conflict_count = 0;
    near_miss_count = 0;
    
    for i = 1:n_intruders
        % Random intruder position (simplified)
        intruder_offset_h = 200 + rand()*400;  % 200-600 ft horizontal
        intruder_offset_v = -50 + rand()*100;  % ±50 ft vertical
        
        % Check minimum separation
        if intruder_offset_h < safety_params.min_horizontal_sep && ...
           abs(intruder_offset_v) < safety_params.min_vertical_sep
            conflict_count = conflict_count + 1;
        elseif intruder_offset_h < safety_params.min_horizontal_sep * 1.5
            near_miss_count = near_miss_count + 1;
        end
    end
    
    conflict_prob = conflict_count / n_intruders;
    near_miss_prob = near_miss_count / n_intruders;
    
    fprintf('   Simulated intruders: %d\n', n_intruders);
    fprintf('   Conflict probability: %.1f%%\n', conflict_prob * 100);
    fprintf('   Near-miss probability: %.1f%%\n', near_miss_prob * 100);
    
    if conflict_prob > 0.1
        fprintf('   ⚠️  HIGH RISK: Conflict probability too high\n');
    else
        fprintf('   ✓ Acceptable conflict risk\n');
    end
    fprintf('\n');
    
    % 5. Navigation Precision Index (NPI)
    fprintf('5. NAVIGATION PRECISION INDEX (NPI)\n');
    
    % Calculate navigation precision based on:
    % - Cross-track error
    % - Along-track error
    % - Vertical error
    
    cross_track_error = abs(pos_error(:,2));  % East deviation
    along_track_error = abs(pos_error(:,1));  % North deviation
    
    npi_cross = mean(cross_track_error);
    npi_along = mean(along_track_error);
    npi_vertical = mean(vertical_error);
    
    % Overall NPI (lower is better)
    npi_overall = sqrt(npi_cross^2 + npi_along^2 + npi_vertical^2);
    
    fprintf('   Cross-track error: %.2f ft\n', npi_cross);
    fprintf('   Along-track error: %.2f ft\n', npi_along);
    fprintf('   Vertical error: %.2f ft\n', npi_vertical);
    fprintf('   Overall NPI: %.2f ft\n', npi_overall);
    
    if npi_overall < 50
        fprintf('   ✓ Excellent navigation precision\n');
    elseif npi_overall < 100
        fprintf('   ✓ Good navigation precision\n');
    else
        fprintf('   ⚠️  WARNING: Poor navigation precision\n');
    end
    fprintf('\n');
    
    % 6. Safety Situation Assessment
    fprintf('6. OVERALL SAFETY ASSESSMENT\n');
    
    % Calculate safety score (0-100)
    score_path = max(0, 100 - max(horiz_error)/5);
    score_velocity = max(0, 100 - V_variation*5);
    score_attitude = max(0, 100 - (phi_rms + theta_rms)*2);
    score_conflict = max(0, 100 - conflict_prob*200);
    score_npi = max(0, 100 - npi_overall/2);
    
    safety_score = (score_path + score_velocity + score_attitude + ...
                   score_conflict + score_npi) / 5;
    
    fprintf('   Path tracking score: %.1f/100\n', score_path);
    fprintf('   Velocity stability score: %.1f/100\n', score_velocity);
    fprintf('   Attitude stability score: %.1f/100\n', score_attitude);
    fprintf('   Conflict avoidance score: %.1f/100\n', score_conflict);
    fprintf('   Navigation precision score: %.1f/100\n', score_npi);
    fprintf('   ─────────────────────────────────\n');
    fprintf('   OVERALL SAFETY SCORE: %.1f/100\n', safety_score);
    
    if safety_score >= 90
        fprintf('   ✓✓✓ EXCELLENT - Safe for congested airspace\n');
    elseif safety_score >= 75
        fprintf('   ✓✓ GOOD - Acceptable for normal operations\n');
    elseif safety_score >= 60
        fprintf('   ✓ FAIR - Caution advised\n');
    else
        fprintf('   ⚠️  POOR - Not recommended for dense operations\n');
    end
    fprintf('\n');
    
    %% Generate Safety Metrics Plot
    fprintf('Generating safety metrics visualization...\n');
    
    fig = figure('Position', [100, 100, 1400, 900], 'Visible', 'off');
    
    % 1. 3D Flight Path with Error Corridor
    subplot(2, 3, 1);
    plot3(pos(:,1), pos(:,2), pos(:,3), 'b--', 'LineWidth', 1.5);
    hold on;
    plot3(pos_actual(:,1), pos_actual(:,2), pos_actual(:,3), 'r-', 'LineWidth', 2);
    
    % Draw protected zone cylinder at start point
    [X, Y, Z] = cylinder(safety_params.protected_radius, 50);
    Z = Z * 200 - 100;  % Height of cylinder
    surf(X + pos(1,1), Y + pos(1,2), Z, 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'FaceColor', 'g');
    
    grid on;
    xlabel('North [ft]');
    ylabel('East [ft]');
    zlabel('Down [ft]');
    set(gca, 'Ydir', 'reverse', 'Zdir', 'reverse');
    title('3D Flight Path');
    legend('Planned', 'Actual', 'Protected Zone');
    view(45, 30);
    
    % 2. Horizontal Deviation
    subplot(2, 3, 2);
    plot(t, horiz_error, 'b-', 'LineWidth', 2);
    hold on;
    yline(safety_params.protected_radius, 'r--', 'Protected Limit', 'LineWidth', 1.5);
    yline(safety_params.min_horizontal_sep, 'y--', 'Min Separation', 'LineWidth', 1.5);
    grid on;
    xlabel('Time [s]');
    ylabel('Horizontal Deviation [ft]');
    title('Path Tracking - Horizontal');
    
    % 3. Vertical Deviation
    subplot(2, 3, 3);
    plot(t, vertical_error, 'b-', 'LineWidth', 2);
    hold on;
    yline(safety_params.protected_height, 'r--', 'Protected Limit', 'LineWidth', 1.5);
    yline(safety_params.min_vertical_sep, 'y--', 'Min Separation', 'LineWidth', 1.5);
    grid on;
    xlabel('Time [s]');
    ylabel('Vertical Deviation [ft]');
    title('Path Tracking - Vertical');
    
    % 4. Velocity Profile
    subplot(2, 3, 4);
    plot(t, V_tot, 'b-', 'LineWidth', 2);
    hold on;
    yline(V_mean, 'r--', sprintf('Mean: %.1f ft/s', V_mean), 'LineWidth', 1.5);
    yline(V_mean + 2*V_std, 'k:', '±2σ', 'LineWidth', 1);
    yline(V_mean - 2*V_std, 'k:', 'LineWidth', 1);
    grid on;
    xlabel('Time [s]');
    ylabel('Velocity [ft/s]');
    title(sprintf('Velocity Stability (CV: %.1f%%)', V_variation));
    
    % 5. Attitude Angles
    subplot(2, 3, 5);
    plot(t, phi_deg, 'b-', 'LineWidth', 1.5);
    hold on;
    plot(t, theta_deg, 'r-', 'LineWidth', 1.5);
    grid on;
    xlabel('Time [s]');
    ylabel('Angle [deg]');
    title('Attitude Stability');
    legend('Roll', 'Pitch');
    
    % 6. Safety Score Breakdown
    subplot(2, 3, 6);
    scores = [score_path, score_velocity, score_attitude, score_conflict, score_npi];
    labels = {'Path', 'Velocity', 'Attitude', 'Conflict', 'NPI'};
    bar(scores, 'FaceColor', [0.2 0.6 0.8]);
    hold on;
    yline(90, 'g--', 'Excellent', 'LineWidth', 1.5);
    yline(75, 'y--', 'Good', 'LineWidth', 1.5);
    yline(60, 'r--', 'Fair', 'LineWidth', 1.5);
    set(gca, 'XTickLabel', labels);
    ylabel('Score [0-100]');
    ylim([0, 100]);
    title(sprintf('Safety Metrics (Overall: %.1f)', safety_score));
    grid on;
    
    sgtitle(sprintf('UAV Flight Safety Analysis - Speed: %.0f kts, Duration: %.0f s', ...
        cruise_speed_knots, sim_time), 'FontSize', 14, 'FontWeight', 'bold');
    
    % Save figure
    saveas(fig, sprintf('%s/UAV_Safety_Metrics_%.0f_kts.png', ...
        'Bank_Angle_Test_Results', cruise_speed_knots));
    close(fig);
    
    %% Export Safety Report
    fprintf('Exporting safety report...\n');
    
    report_file = sprintf('%s/Safety_Report_%.0f_kts.txt', ...
        'Bank_Angle_Test_Results', cruise_speed_knots);
    fid = fopen(report_file, 'w');
    
    fprintf(fid, '=======================================================\n');
    fprintf(fid, 'UAV FLIGHT SAFETY ASSESSMENT REPORT\n');
    fprintf(fid, '=======================================================\n\n');
    fprintf(fid, 'Flight Parameters:\n');
    fprintf(fid, '  Speed: %.0f knots (%.1f ft/s)\n', cruise_speed_knots, cruise_speed_fps);
    fprintf(fid, '  Duration: %.0f seconds\n', sim_time);
    fprintf(fid, '  Distance: %.0f ft\n\n', max(pos_actual(:,1)));
    
    fprintf(fid, 'Safety Metrics:\n');
    fprintf(fid, '1. Path Tracking:\n');
    fprintf(fid, '   - Horizontal deviation: %.2f ft (max: %.2f ft)\n', mean(horiz_error), max(horiz_error));
    fprintf(fid, '   - Vertical deviation: %.2f ft (max: %.2f ft)\n', mean(vertical_error), max(vertical_error));
    fprintf(fid, '   - Score: %.1f/100\n\n', score_path);
    
    fprintf(fid, '2. Velocity Stability:\n');
    fprintf(fid, '   - Mean: %.2f ft/s\n', V_mean);
    fprintf(fid, '   - Std Dev: %.2f ft/s\n', V_std);
    fprintf(fid, '   - Variation: %.2f%%\n', V_variation);
    fprintf(fid, '   - Score: %.1f/100\n\n', score_velocity);
    
    fprintf(fid, '3. Attitude Stability:\n');
    fprintf(fid, '   - Roll RMS: %.2f°\n', phi_rms);
    fprintf(fid, '   - Pitch RMS: %.2f°\n', theta_rms);
    fprintf(fid, '   - Score: %.1f/100\n\n', score_attitude);
    
    fprintf(fid, '4. Conflict Analysis:\n');
    fprintf(fid, '   - Conflict probability: %.1f%%\n', conflict_prob*100);
    fprintf(fid, '   - Near-miss probability: %.1f%%\n', near_miss_prob*100);
    fprintf(fid, '   - Score: %.1f/100\n\n', score_conflict);
    
    fprintf(fid, '5. Navigation Precision:\n');
    fprintf(fid, '   - Overall NPI: %.2f ft\n', npi_overall);
    fprintf(fid, '   - Score: %.1f/100\n\n', score_npi);
    
    fprintf(fid, '=======================================================\n');
    fprintf(fid, 'OVERALL SAFETY SCORE: %.1f/100\n', safety_score);
    
    if safety_score >= 90
        fprintf(fid, 'ASSESSMENT: EXCELLENT - Safe for congested airspace\n');
    elseif safety_score >= 75
        fprintf(fid, 'ASSESSMENT: GOOD - Acceptable for normal operations\n');
    elseif safety_score >= 60
        fprintf(fid, 'ASSESSMENT: FAIR - Caution advised\n');
    else
        fprintf(fid, 'ASSESSMENT: POOR - Not recommended\n');
    end
    
    fprintf(fid, '=======================================================\n');
    fclose(fid);
    
    fprintf('\n=================================================\n');
    fprintf('✓ Safety analysis complete!\n');
    fprintf('  Report: %s\n', report_file);
    fprintf('  Plot: UAV_Safety_Metrics_%.0f_kts.png\n', cruise_speed_knots);
    fprintf('=================================================\n');
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    fprintf('   at %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
end

warning('on', 'all');
