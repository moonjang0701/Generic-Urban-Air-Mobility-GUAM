%% Realistic Safety Envelope Implementation - Dynamic Flight Analysis
% Paper: "Flight safety measurements of UAVs in congested airspace"
% This version shows REALISTIC flight behavior with:
% - Time-varying envelope based on actual flight state
% - Dynamic performance parameters from real flight data
% - Multiple snapshots showing envelope evolution
% - Bank angle variations and their effect on envelope

clear all; close all; clc;

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  REALISTIC Safety Envelope Implementation\n');
fprintf('  Dynamic Flight Analysis with Time-Varying Envelopes\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

%% Navigate to GUAM Root
script_dir = fileparts(mfilename('fullpath'));
guam_root = fileparts(script_dir);
cd(guam_root);
fprintf('  Working directory: %s\n\n', pwd);

%% Test Scenario: Cruise with Bank Angle Variations
fprintf('╔═══════════════════════════════════════════════════════════╗\n');
fprintf('║  Scenario: Cruise with Dynamic Maneuvers\n');
fprintf('╚═══════════════════════════════════════════════════════════╝\n\n');

simSetup;
model = 'GUAM';

%% Setup Dynamic Trajectory with Bank Angles
fprintf('  Setting up dynamic trajectory with maneuvers...\n');

userStruct.variants.refInputType = 3;

% Extended time with multiple phases
time = [0; 15; 30; 45; 60; 75; 90]';
N_time = length(time);

% Define trajectory with turns
% Phase 1: Straight north (0-15s)
% Phase 2: Turn right (15-30s)
% Phase 3: Straight east (30-45s)
% Phase 4: Turn right again (45-60s)
% Phase 5: Straight south (60-75s)
% Phase 6: Level out (75-90s)

cruise_speed_ms = 30;  % 30 m/s (~100 ft/s, ~60 knots)
altitude_m = -91.44;   % 300 ft

pos = zeros(N_time, 3);
vel_i = zeros(N_time, 3);
chi = zeros(N_time, 1);

% Positions
pos(1,:) = [0, 0, altitude_m];
pos(2,:) = [cruise_speed_ms*15, 0, altitude_m];
pos(3,:) = [cruise_speed_ms*15 + cruise_speed_ms*15*cos(pi/4), cruise_speed_ms*15*sin(pi/4), altitude_m];
pos(4,:) = [cruise_speed_ms*15 + cruise_speed_ms*15*cos(pi/4), cruise_speed_ms*30*sin(pi/4), altitude_m];
pos(5,:) = pos(4,:) + [cruise_speed_ms*15*cos(3*pi/4), cruise_speed_ms*15*sin(3*pi/4), 0];
pos(6,:) = pos(5,:) + [0, -cruise_speed_ms*15, 0];
pos(7,:) = pos(6,:) + [0, -cruise_speed_ms*15, 0];

% Velocities (inertial frame)
vel_i(1,:) = [cruise_speed_ms, 0, 0];  % North
vel_i(2,:) = [cruise_speed_ms, 0, 0];
vel_i(3,:) = [cruise_speed_ms*cos(pi/4), cruise_speed_ms*sin(pi/4), 0];  % NE
vel_i(4,:) = [0, cruise_speed_ms, 0];  % East
vel_i(5,:) = [cruise_speed_ms*cos(3*pi/4), cruise_speed_ms*sin(3*pi/4), 0];  % SE
vel_i(6,:) = [0, -cruise_speed_ms, 0];  % South
vel_i(7,:) = [0, -cruise_speed_ms, 0];

% Heading angles
chi = atan2(vel_i(:,2), vel_i(:,1));
chid = gradient(chi) ./ gradient(time);

% Convert to heading frame
addpath(genpath('lib'));
q = QrotZ(chi);
vel = Qtrans(q, vel_i);

% Setup RefInput
RefInput.Vel_bIc_des = timeseries(vel, time);
RefInput.pos_des = timeseries(pos, time);
RefInput.chi_des = timeseries(chi, time);
RefInput.chi_dot_des = timeseries(chid, time);
RefInput.vel_des = timeseries(vel_i, time);
target.RefInput = RefInput;

SimIn.StopTime = 90;

%% Run Simulation
fprintf('  Running GUAM simulation (90 seconds)...\n');
try
    sim(model);
    fprintf('  ✓ Simulation completed successfully\n');
catch ME
    fprintf('  ✗ Simulation failed: %s\n', ME.message);
    return;
end

%% Extract Detailed Flight Data
fprintf('  Extracting detailed flight data...\n');

try
    logsout = evalin('base', 'logsout');
    SimOut = logsout{1}.Values;
    
    % Time
    time_data = SimOut.Time.Data;
    
    % Position (NED)
    pos_NED_ft = squeeze(SimOut.Vehicle.EOM.InertialData.Pos_bii.Data);
    pos_NED_m = pos_NED_ft * 0.3048;
    
    % Velocity and angles
    V_total = SimOut.Vehicle.Sensor.Vtot.Data;  % ft/s
    V_total_ms = V_total * 0.3048;  % m/s
    gamma = SimOut.Vehicle.Sensor.gamma.Data;  % rad
    psi = SimOut.Vehicle.Sensor.Euler.psi.Data;  % rad
    theta = SimOut.Vehicle.Sensor.Euler.theta.Data;  % rad
    phi = SimOut.Vehicle.Sensor.Euler.phi.Data;  % rad (BANK ANGLE!)
    
    % Acceleration (numerical derivative)
    V_dot = gradient(V_total_ms) ./ gradient(time_data);
    
    fprintf('  ✓ Extracted %d data points\n', length(time_data));
    fprintf('    Speed range: %.1f - %.1f m/s\n', min(V_total_ms), max(V_total_ms));
    fprintf('    Bank angle range: %.1f - %.1f deg\n', rad2deg(min(phi)), rad2deg(max(phi)));
    fprintf('    Max acceleration: %.2f m/s²\n', max(abs(V_dot)));
    
catch ME
    fprintf('  ✗ Data extraction failed: %s\n', ME.message);
    return;
end

%% Calculate Time-Varying Performance Parameters
fprintf('\n  Calculating time-varying performance parameters...\n');

% Paper parameters
tau = 5.0;  % Response time
sigma_v = 2.0;  % Velocity uncertainty
Delta_t = 5.0;  % Prediction interval

% Estimate performance at each time step
% V_f depends on current speed and acceleration capability
V_f_array = V_total_ms + max(V_dot) * tau;  % Forward with acceleration
V_b_array = max(0.1, V_total_ms * 0.3);  % Backward (30% of forward)
V_a_array = ones(size(V_total_ms)) * 10.0;  % Vertical ascent (constant)
V_d_array = ones(size(V_total_ms)) * 15.0;  % Vertical descent (constant)
V_l_array = V_total_ms * 0.5;  % Lateral (50% of forward)

% Bank angle effect: lateral capability increases with bank
% During turns, lateral reach is greater
V_l_array = V_l_array .* (1 + 0.5*abs(sin(phi)));  % Up to 50% increase

fprintf('  ✓ Performance parameters calculated\n');
fprintf('    V_f range: %.1f - %.1f m/s\n', min(V_f_array), max(V_f_array));
fprintf('    V_l range: %.1f - %.1f m/s\n', min(V_l_array), max(V_l_array));

%% Select Key Time Points for Envelope Visualization
fprintf('\n  Selecting key time points for envelope snapshots...\n');

% Find interesting moments
[~, idx_max_bank] = max(abs(phi));
[~, idx_max_speed] = max(V_total_ms);
[~, idx_turn_start] = min(abs(time_data - 15));
[~, idx_straight] = min(abs(time_data - 40));

snapshot_indices = [10, idx_turn_start, idx_max_bank, idx_straight, length(time_data)-10];
snapshot_names = {'Initial Cruise', 'Turn Entry', 'Max Bank', 'Straight Flight', 'Final'};

fprintf('  Selected %d snapshot times\n', length(snapshot_indices));

%% Generate Safety Envelopes at Each Snapshot
fprintf('\n  Generating safety envelopes for snapshots...\n');

snapshots = struct();

for snap = 1:length(snapshot_indices)
    idx = snapshot_indices(snap);
    
    % Current state
    X_A = pos_NED_m(idx, :)';
    V_f = V_f_array(idx);
    V_b = V_b_array(idx);
    V_a = V_a_array(idx);
    V_d = V_d_array(idx);
    V_l = V_l_array(idx);
    current_speed = V_total_ms(idx);
    current_bank = rad2deg(phi(idx));
    
    % Envelope dimensions
    a = V_f * tau;
    b = V_b * tau;
    c = V_a * tau;
    d = V_d * tau;
    e = V_l * tau;
    f = e;
    
    % Volume and equivalent radius
    V_envelope = (4*pi/3) * (1/8) * (a*c*e + a*d*e + b*c*e + b*d*e);
    r_eq = (3 * V_envelope / (4*pi))^(1/3);
    
    % Generate mesh
    [theta_mesh, phi_mesh] = meshgrid(linspace(0, 2*pi, 50), linspace(-pi/2, pi/2, 25));
    env_x = zeros(size(theta_mesh));
    env_y = zeros(size(theta_mesh));
    env_z = zeros(size(theta_mesh));
    
    for i = 1:numel(theta_mesh)
        cos_phi = cos(phi_mesh(i));
        ux = cos_phi * cos(theta_mesh(i));
        uy = cos_phi * sin(theta_mesh(i));
        uz = sin(phi_mesh(i));
        
        ax = (ux >= 0) * a + (ux < 0) * b;
        az = (uz >= 0) * c + (uz < 0) * d;
        ay = e;
        
        env_x(i) = X_A(1) + ax * ux;
        env_y(i) = X_A(2) + ay * uy;
        env_z(i) = X_A(3) + az * uz;
    end
    
    % Store snapshot
    snapshots(snap).name = snapshot_names{snap};
    snapshots(snap).time = time_data(idx);
    snapshots(snap).position = X_A;
    snapshots(snap).speed = current_speed;
    snapshots(snap).bank_angle = current_bank;
    snapshots(snap).envelope_dims = [a, b, c, d, e, f];
    snapshots(snap).volume = V_envelope;
    snapshots(snap).r_eq = r_eq;
    snapshots(snap).mesh_x = env_x;
    snapshots(snap).mesh_y = env_y;
    snapshots(snap).mesh_z = env_z;
    
    fprintf('    Snapshot %d (%s): t=%.1fs, V=%.1f m/s, φ=%.1f°, r_eq=%.1fm\n', ...
        snap, snapshot_names{snap}, time_data(idx), current_speed, current_bank, r_eq);
end

%% Visualization
fprintf('\n╔═══════════════════════════════════════════════════════════╗\n');
fprintf('║  Generating Visualizations\n');
fprintf('╚═══════════════════════════════════════════════════════════╝\n\n');

%% Figure 1: Flight Trajectory with State Information
fprintf('  Creating Figure 1: Complete Flight Trajectory...\n');
fig1 = figure('Name', 'Flight Trajectory Analysis', 'Position', [100 100 1600 900]);

% 3D trajectory
subplot(2, 3, [1 4]);
plot3(pos_NED_m(:,1), pos_NED_m(:,2), -pos_NED_m(:,3), 'b-', 'LineWidth', 2);
hold on;
% Mark snapshots
for snap = 1:length(snapshots)
    plot3(snapshots(snap).position(1), snapshots(snap).position(2), ...
        -snapshots(snap).position(3), 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
    text(snapshots(snap).position(1), snapshots(snap).position(2), ...
        -snapshots(snap).position(3) + 20, sprintf('%d', snap), 'FontSize', 12, 'FontWeight', 'bold');
end
xlabel('North (m)'); ylabel('East (m)'); zlabel('Altitude (m)');
title('3D Flight Path with Snapshot Points');
grid on; axis equal; view(45, 30);

% Speed vs time
subplot(2, 3, 2);
plot(time_data, V_total_ms, 'b-', 'LineWidth', 2);
hold on;
for snap = 1:length(snapshots)
    plot(snapshots(snap).time, snapshots(snap).speed, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
end
xlabel('Time (s)'); ylabel('Speed (m/s)');
title('Airspeed vs Time');
grid on;

% Bank angle vs time
subplot(2, 3, 3);
plot(time_data, rad2deg(phi), 'r-', 'LineWidth', 2);
hold on;
for snap = 1:length(snapshots)
    plot(snapshots(snap).time, snapshots(snap).bank_angle, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
end
xlabel('Time (s)'); ylabel('Bank Angle (deg)');
title('Bank Angle vs Time');
grid on;

% Envelope size vs time
subplot(2, 3, 5);
r_eq_array = zeros(size(time_data));
for i = 1:length(time_data)
    a_t = V_f_array(i) * tau;
    c_t = V_a_array(i) * tau;
    d_t = V_d_array(i) * tau;
    e_t = V_l_array(i) * tau;
    V_env = (4*pi/3) * (1/8) * (a_t*c_t*e_t + a_t*d_t*e_t + V_b_array(i)*tau*c_t*e_t + V_b_array(i)*tau*d_t*e_t);
    r_eq_array(i) = (3 * V_env / (4*pi))^(1/3);
end
plot(time_data, r_eq_array, 'g-', 'LineWidth', 2);
hold on;
for snap = 1:length(snapshots)
    plot(snapshots(snap).time, snapshots(snap).r_eq, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
end
xlabel('Time (s)'); ylabel('Equiv. Radius (m)');
title('Safety Envelope Size vs Time');
grid on;

% Ground track
subplot(2, 3, 6);
plot(pos_NED_m(:,1), pos_NED_m(:,2), 'b-', 'LineWidth', 2);
hold on;
for snap = 1:length(snapshots)
    plot(snapshots(snap).position(1), snapshots(snap).position(2), ...
        'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
    text(snapshots(snap).position(1) + 20, snapshots(snap).position(2), ...
        sprintf('%d', snap), 'FontSize', 12, 'FontWeight', 'bold');
end
xlabel('North (m)'); ylabel('East (m)');
title('Ground Track');
axis equal; grid on;

sgtitle('Realistic Flight Analysis - Dynamic Maneuvers', 'FontSize', 14, 'FontWeight', 'bold');

fprintf('  ✓ Figure 1 completed\n');

%% Figure 2: Safety Envelope Evolution (Multiple Snapshots)
fprintf('  Creating Figure 2: Envelope Evolution...\n');
fig2 = figure('Name', 'Safety Envelope Evolution', 'Position', [100 100 1800 600]);

for snap = 1:min(5, length(snapshots))
    subplot(1, 5, snap);
    
    % Plot envelope
    surf(snapshots(snap).mesh_x, snapshots(snap).mesh_y, snapshots(snap).mesh_z, ...
        'FaceAlpha', 0.3, 'EdgeColor', 'none', 'FaceColor', 'cyan');
    hold on;
    
    % Plot UAV
    plot3(snapshots(snap).position(1), snapshots(snap).position(2), snapshots(snap).position(3), ...
        'ro', 'MarkerSize', 12, 'MarkerFaceColor', 'r');
    
    % Plot trajectory segment
    if snap > 1
        prev_pos = snapshots(snap-1).position;
        plot3([prev_pos(1), snapshots(snap).position(1)], ...
              [prev_pos(2), snapshots(snap).position(2)], ...
              [prev_pos(3), snapshots(snap).position(3)], ...
              'b-', 'LineWidth', 2);
    end
    
    xlabel('North (m)'); ylabel('East (m)'); zlabel('Down (m)');
    title(sprintf('%s\nt=%.1fs, φ=%.1f°\nr_{eq}=%.1fm', ...
        snapshots(snap).name, snapshots(snap).time, ...
        snapshots(snap).bank_angle, snapshots(snap).r_eq), 'FontSize', 10);
    grid on; axis equal; view(45, 30);
    set(gca, 'ZDir', 'reverse');
end

sgtitle('Safety Envelope Evolution During Flight', 'FontSize', 14, 'FontWeight', 'bold');

fprintf('  ✓ Figure 2 completed\n');

%% Export Results
fprintf('\n  Exporting results...\n');

csv_file = 'Realistic_Safety_Envelope_Results.csv';
fid = fopen(csv_file, 'w');
fprintf(fid, 'Snapshot,Time(s),Speed(m/s),BankAngle(deg),V_f(m/s),V_l(m/s),r_eq(m),Volume(m³)\n');
for snap = 1:length(snapshots)
    dims = snapshots(snap).envelope_dims;
    fprintf(fid, '%s,%.1f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n', ...
        snapshots(snap).name, snapshots(snap).time, snapshots(snap).speed, ...
        snapshots(snap).bank_angle, dims(1)/tau, dims(5)/tau, ...
        snapshots(snap).r_eq, snapshots(snap).volume);
end
fclose(fid);

fprintf('  ✓ Results exported to %s\n', csv_file);

%% Summary
fprintf('\n╔═══════════════════════════════════════════════════════════╗\n');
fprintf('║  SUMMARY - Realistic Dynamic Analysis\n');
fprintf('╚═══════════════════════════════════════════════════════════╝\n\n');

fprintf('Flight Statistics:\n');
fprintf('  Total flight time: %.1f seconds\n', time_data(end));
fprintf('  Speed range: %.1f - %.1f m/s\n', min(V_total_ms), max(V_total_ms));
fprintf('  Bank angle range: %.1f - %.1f deg\n', rad2deg(min(phi)), rad2deg(max(phi)));
fprintf('  Max turn rate: %.2f deg/s\n', max(abs(rad2deg(gradient(psi)./gradient(time_data)))));

fprintf('\nEnvelope Variation:\n');
fprintf('  r_eq range: %.1f - %.1f m\n', min(r_eq_array), max(r_eq_array));
fprintf('  r_eq change: %.1f%% during maneuvers\n', ...
    100*(max(r_eq_array) - min(r_eq_array))/mean(r_eq_array));

fprintf('\nSnapshot Details:\n');
for snap = 1:length(snapshots)
    fprintf('  %d. %s: r_eq=%.1fm, V=%.1f m/s, φ=%.1f°\n', ...
        snap, snapshots(snap).name, snapshots(snap).r_eq, ...
        snapshots(snap).speed, snapshots(snap).bank_angle);
end

fprintf('\n═══════════════════════════════════════════════════════════════\n');
fprintf('  Realistic Analysis Complete!\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
