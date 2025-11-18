%% Correct Paper Flow: Performance → Envelope → Safety Verification
% Paper: "Flight safety measurements of UAVs in congested airspace"
% 
% CORRECT FLOW (as in the paper):
% Step 1: Measure GUAM aircraft performance capabilities
% Step 2: Calculate safety envelope from measured performance
% Step 3: Define safe airspace considering envelope size
% Step 4: Verify safety using conflict probability s(X)
%
% This follows Section 2 & 4 of the paper exactly

clear all; close all; clc;

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  Correct Paper Flow Implementation\n');
fprintf('  Performance → Envelope → Safety Verification\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

%% Navigate to GUAM Root
script_dir = fileparts(mfilename('fullpath'));
guam_root = fileparts(script_dir);
cd(guam_root);
fprintf('  Working directory: %s\n\n', pwd);

%% STEP 1: Measure GUAM Aircraft Performance
fprintf('╔═══════════════════════════════════════════════════════════╗\n');
fprintf('║  STEP 1: Measure Aircraft Performance\n');
fprintf('╚═══════════════════════════════════════════════════════════╝\n\n');

fprintf('  Measuring maximum velocities in each direction...\n\n');

% Test scenarios to find maximum velocities
test_speeds = [60, 80, 100, 120];  % knots
measured_performance = struct();

for test_idx = 1:length(test_speeds)
    speed_knots = test_speeds(test_idx);
    speed_fps = speed_knots * 1.68781;
    speed_ms = speed_fps * 0.3048;
    
    fprintf('  Testing cruise at %d knots (%.1f m/s)...\n', speed_knots, speed_ms);
    
    % Simple hover to cruise test
    simSetup;
    model = 'GUAM';
    userStruct.variants.refInputType = 3;
    
    time = [0; 10; 20]';
    pos = [0, 0, -91.44; 0, 0, -91.44; speed_ms*10, 0, -91.44];
    vel_i = [0, 0, 0; speed_ms, 0, 0; speed_ms, 0, 0];
    chi = [0; 0; 0];
    chid = [0; 0; 0];
    
    addpath(genpath('lib'));
    q = QrotZ(chi);
    vel = Qtrans(q, vel_i);
    
    RefInput.Vel_bIc_des = timeseries(vel, time);
    RefInput.pos_des = timeseries(pos, time);
    RefInput.chi_des = timeseries(chi, time);
    RefInput.chi_dot_des = timeseries(chid, time);
    RefInput.vel_des = timeseries(vel_i, time);
    target.RefInput = RefInput;
    
    SimIn.StopTime = 20;
    
    try
        sim(model);
        
        % Extract achieved performance
        logsout = evalin('base', 'logsout');
        SimOut = logsout{1}.Values;
        
        V_achieved = SimOut.Vehicle.Sensor.Vtot.Data * 0.3048;  % m/s
        gamma_achieved = SimOut.Vehicle.Sensor.gamma.Data;
        
        % Store maximum achieved velocities
        measured_performance(test_idx).cruise_speed = speed_knots;
        measured_performance(test_idx).V_max_forward = max(V_achieved);
        measured_performance(test_idx).V_max_climb = max(V_achieved .* sin(gamma_achieved));
        measured_performance(test_idx).V_max_descent = max(-V_achieved .* sin(gamma_achieved));
        
        fprintf('    ✓ Achieved: V_forward=%.1f m/s\n', measured_performance(test_idx).V_max_forward);
        
    catch ME
        fprintf('    ✗ Test failed: %s\n', ME.message);
    end
end

% Determine aircraft capabilities from measurements
fprintf('\n  Aircraft Performance Capabilities (from GUAM measurements):\n');

V_f = max([measured_performance.V_max_forward]);  % Maximum forward
V_b = V_f * 0.2;  % Backward (estimated as 20% of forward for this aircraft)
V_a = mean([measured_performance.V_max_climb]);  % Vertical ascent
V_d = mean([measured_performance.V_max_descent]);  % Vertical descent  
V_l = V_f * 0.4;  % Lateral (estimated as 40% of forward)

fprintf('    V_f (max forward):    %.2f m/s\n', V_f);
fprintf('    V_b (max backward):   %.2f m/s\n', V_b);
fprintf('    V_a (max ascent):     %.2f m/s\n', V_a);
fprintf('    V_d (max descent):    %.2f m/s\n', V_d);
fprintf('    V_l (max lateral):    %.2f m/s\n', V_l);

%% STEP 2: Calculate Safety Envelope (Paper Eq. 1-5)
fprintf('\n╔═══════════════════════════════════════════════════════════╗\n');
fprintf('║  STEP 2: Calculate Safety Envelope\n');
fprintf('╚═══════════════════════════════════════════════════════════╝\n\n');

% Paper parameter
tau = 5.0;  % Response time (seconds)

fprintf('  Using response time τ = %.1f seconds\n\n', tau);

% Calculate envelope semi-axes (Paper Eq. 1-3)
a = V_f * tau;  % Forward reach
b = V_b * tau;  % Backward reach
c = V_a * tau;  % Ascent reach
d = V_d * tau;  % Descent reach
e = V_l * tau;  % Lateral reach (symmetric)
f = e;

fprintf('  Safety Envelope Dimensions (8-part ellipsoid):\n');
fprintf('    a (forward):      %.2f m\n', a);
fprintf('    b (backward):     %.2f m\n', b);
fprintf('    c (ascending):    %.2f m\n', c);
fprintf('    d (descending):   %.2f m\n', d);
fprintf('    e,f (lateral):    %.2f m\n\n', e);

% Calculate envelope volume (Paper Eq. 22)
V_envelope = (4*pi/3) * (1/8) * (a*c*e + a*d*e + b*c*e + b*d*e);
fprintf('  Envelope Volume: %.1f m³\n', V_envelope);

% Calculate equivalent radius (Paper Eq. 23)
r_eq = (3 * V_envelope / (4*pi))^(1/3);
fprintf('  Equivalent Radius r_eq: %.2f m\n\n', r_eq);

fprintf('  → This UAV needs %.2f m clearance in all directions\n', r_eq);
fprintf('  → Minimum safe separation: %.2f m (2 × r_eq)\n\n', 2*r_eq);

%% STEP 3: Define Safe Airspace Considering Envelope
fprintf('╔═══════════════════════════════════════════════════════════╗\n');
fprintf('║  STEP 3: Plan Safe Flight Considering Envelope Size\n');
fprintf('╚═══════════════════════════════════════════════════════════╝\n\n');

fprintf('  Scenario: Multiple UAVs in shared airspace\n\n');

% Define airspace boundaries
airspace_size = [1000, 1000, 200];  % [North, East, Altitude] in meters
fprintf('  Airspace size: %d × %d × %d m\n', airspace_size(1), airspace_size(2), airspace_size(3));

% Define obstacle positions (other UAVs or no-fly zones)
obstacles = [
    300, 0, -100;    % Obstacle 1
    600, 300, -100;  % Obstacle 2
    400, 500, -120   % Obstacle 3
];
num_obstacles = size(obstacles, 1);

fprintf('  Number of obstacles/other UAVs: %d\n', num_obstacles);
for i = 1:num_obstacles
    fprintf('    Obstacle %d: [%.0f, %.0f, %.0f] m\n', i, obstacles(i,1), obstacles(i,2), obstacles(i,3));
end

% Check safe separation from obstacles
fprintf('\n  Checking safe distances:\n');
min_safe_separation = 2 * r_eq;  % Two envelopes shouldn't overlap

safe_distances = zeros(num_obstacles, 1);
for i = 1:num_obstacles
    % Calculate minimum distance UAV must maintain
    safe_distances(i) = min_safe_separation;
    fprintf('    From obstacle %d: must maintain > %.1f m\n', i, safe_distances(i));
end

% Plan trajectory avoiding obstacles
fprintf('\n  Planning trajectory with safety margins...\n');

% Start and end points
start_pos = [0, 0, -100];  % Starting position
end_pos = [800, 600, -100];  % Destination

% Create waypoints avoiding obstacles
waypoints = [
    start_pos;
    150, 0, -100;      % WP1: Clear of obstacle 1
    450, 150, -100;    % WP2: Between obstacles
    600, 450, -100;    % WP3: Clear of obstacle 2
    end_pos
];

fprintf('  Generated %d waypoints:\n', size(waypoints, 1));
for i = 1:size(waypoints, 1)
    fprintf('    WP%d: [%.0f, %.0f, %.0f] m\n', i, waypoints(i,1), waypoints(i,2), waypoints(i,3));
end

% Verify all waypoints are safe
fprintf('\n  Verifying waypoint safety:\n');
all_safe = true;
for i = 1:size(waypoints, 1)
    wp = waypoints(i,:);
    for j = 1:num_obstacles
        obs = obstacles(j,:);
        distance = norm(wp - obs);
        is_safe = distance >= min_safe_separation;
        
        if ~is_safe
            fprintf('    ✗ WP%d too close to obstacle %d (%.1f m < %.1f m)\n', ...
                i, j, distance, min_safe_separation);
            all_safe = false;
        end
    end
end

if all_safe
    fprintf('    ✓ All waypoints maintain safe separation (> %.1f m)\n', min_safe_separation);
end

%% STEP 4: Calculate Conflict Probability Field s(X)
fprintf('\n╔═══════════════════════════════════════════════════════════╗\n');
fprintf('║  STEP 4: Calculate Safety Field s(X)\n');
fprintf('╚═══════════════════════════════════════════════════════════╝\n\n');

fprintf('  Computing conflict probability for each spatial point...\n');

% Paper parameters
sigma_v = 2.0;  % Velocity uncertainty (m/s)
Delta_t = 5.0;  % Prediction interval (s)

% Create 2D grid (horizontal plane at flight altitude)
grid_res = 50;
north_grid = linspace(0, airspace_size(1), grid_res);
east_grid = linspace(0, airspace_size(2), grid_res);
[N_grid, E_grid] = meshgrid(north_grid, east_grid);

% Calculate s(X) for each grid point
s_X = zeros(size(N_grid));

for i = 1:numel(N_grid)
    X_point = [N_grid(i); E_grid(i); -100];  % Point in space
    
    % For each obstacle (representing other UAVs with same envelope)
    min_dist_to_envelope = inf;
    
    for j = 1:num_obstacles
        X_obstacle = obstacles(j,:)';
        distance = norm(X_point - X_obstacle);
        
        % Check if point is inside any safety envelope
        if distance <= r_eq
            s_X(i) = 1.0;  % Definitely inside envelope
            break;
        else
            % Probability decreases with distance (Paper Eq. 7)
            % Using Brownian motion model
            sigma_spread = sigma_v * sqrt(Delta_t);
            z_score = (distance - r_eq) / sigma_spread;
            prob = 1 - normcdf(z_score);
            
            s_X(i) = max(s_X(i), prob);
        end
    end
end

fprintf('  ✓ Conflict probability field computed\n');
fprintf('    Maximum s(X): %.4f\n', max(s_X(:)));
fprintf('    Minimum s(X): %.4f\n', min(s_X(:)));

% Identify safe vs unsafe regions
safety_threshold = 0.01;  % 1% threshold
safe_area_percentage = 100 * sum(s_X(:) < safety_threshold) / numel(s_X);
fprintf('    Safe area (s(X) < %.2f): %.1f%%\n', safety_threshold, safe_area_percentage);

%% STEP 5: Verify Trajectory Safety
fprintf('\n╔═══════════════════════════════════════════════════════════╗\n');
fprintf('║  STEP 5: Verify Planned Trajectory Safety\n');
fprintf('╚═══════════════════════════════════════════════════════════╝\n\n');

fprintf('  Checking each waypoint against safety field...\n');

trajectory_safe = true;
max_conflict_prob = 0;

for i = 1:size(waypoints, 1)
    wp = waypoints(i,:);
    
    % Find closest grid point
    [~, n_idx] = min(abs(north_grid - wp(1)));
    [~, e_idx] = min(abs(east_grid - wp(2)));
    
    conflict_prob = s_X(e_idx, n_idx);
    max_conflict_prob = max(max_conflict_prob, conflict_prob);
    
    if conflict_prob > safety_threshold
        fprintf('    ✗ WP%d: s(X) = %.4f (UNSAFE!)\n', i, conflict_prob);
        trajectory_safe = false;
    else
        fprintf('    ✓ WP%d: s(X) = %.4f (safe)\n', i, conflict_prob);
    end
end

fprintf('\n  Trajectory Safety Assessment:\n');
if trajectory_safe
    fprintf('    ✓ SAFE: All waypoints have acceptable conflict probability\n');
    fprintf('    Maximum s(X) along path: %.4f (threshold: %.4f)\n', max_conflict_prob, safety_threshold);
else
    fprintf('    ✗ UNSAFE: Trajectory requires replanning\n');
end

%% Visualization
fprintf('\n╔═══════════════════════════════════════════════════════════╗\n');
fprintf('║  Generating Visualizations\n');
fprintf('╚═══════════════════════════════════════════════════════════╝\n\n');

%% Figure 1: Safety Envelope (3D)
fprintf('  Creating Figure 1: Safety Envelope...\n');
fig1 = figure('Name', 'Safety Envelope', 'Position', [100 100 800 600]);

% Generate envelope mesh at origin
[theta, phi] = meshgrid(linspace(0, 2*pi, 50), linspace(-pi/2, pi/2, 25));
env_x = zeros(size(theta));
env_y = zeros(size(theta));
env_z = zeros(size(theta));

for i = 1:numel(theta)
    cos_phi = cos(phi(i));
    ux = cos_phi * cos(theta(i));
    uy = cos_phi * sin(theta(i));
    uz = sin(phi(i));
    
    ax = (ux >= 0) * a + (ux < 0) * b;
    az = (uz >= 0) * c + (uz < 0) * d;
    ay = e;
    
    env_x(i) = ax * ux;
    env_y(i) = ay * uy;
    env_z(i) = az * uz;
end

surf(env_x, env_y, env_z, 'FaceAlpha', 0.3, 'EdgeColor', 'none', 'FaceColor', 'cyan');
hold on;

% Plot coordinate axes
quiver3(0, 0, 0, a, 0, 0, 'r', 'LineWidth', 2, 'MaxHeadSize', 0.5);
quiver3(0, 0, 0, 0, e, 0, 'g', 'LineWidth', 2, 'MaxHeadSize', 0.5);
quiver3(0, 0, 0, 0, 0, c, 'b', 'LineWidth', 2, 'MaxHeadSize', 0.5);
quiver3(0, 0, 0, -b, 0, 0, 'r--', 'LineWidth', 1.5);
quiver3(0, 0, 0, 0, 0, -d, 'b--', 'LineWidth', 1.5);

% Labels
text(a+5, 0, 0, sprintf('V_f×τ = %.1fm', a), 'FontSize', 10, 'Color', 'r', 'FontWeight', 'bold');
text(0, e+5, 0, sprintf('V_l×τ = %.1fm', e), 'FontSize', 10, 'Color', 'g', 'FontWeight', 'bold');
text(0, 0, c+5, sprintf('V_a×τ = %.1fm', c), 'FontSize', 10, 'Color', 'b', 'FontWeight', 'bold');

xlabel('North (m)'); ylabel('East (m)'); zlabel('Up (m)');
title(sprintf('Safety Envelope (τ=%.1fs, r_{eq}=%.1fm)', tau, r_eq), 'FontSize', 12, 'FontWeight', 'bold');
grid on; axis equal; view(45, 30);

fprintf('  ✓ Figure 1 completed\n');

%% Figure 2: Airspace Safety Field s(X)
fprintf('  Creating Figure 2: Airspace Safety Field...\n');
fig2 = figure('Name', 'Airspace Safety Field', 'Position', [100 100 1200 600]);

subplot(1, 2, 1);
contourf(N_grid, E_grid, s_X, 20);
colorbar;
caxis([0 1]);
colormap(jet);
hold on;

% Plot obstacles
for i = 1:num_obstacles
    plot(obstacles(i,1), obstacles(i,2), 'ko', 'MarkerSize', 15, 'MarkerFaceColor', 'k');
    % Plot envelope boundary
    theta_circle = linspace(0, 2*pi, 100);
    circle_x = obstacles(i,1) + r_eq * cos(theta_circle);
    circle_y = obstacles(i,2) + r_eq * sin(theta_circle);
    plot(circle_x, circle_y, 'k--', 'LineWidth', 2);
end

% Plot planned trajectory
plot(waypoints(:,1), waypoints(:,2), 'w-o', 'LineWidth', 3, 'MarkerSize', 10, 'MarkerFaceColor', 'w');

xlabel('North (m)'); ylabel('East (m)');
title('Conflict Probability Field s(X)');
axis equal; grid on;

subplot(1, 2, 2);
% 3D view
surf(N_grid, E_grid, s_X, 'EdgeColor', 'none');
colorbar;
caxis([0 1]);
colormap(jet);
hold on;

% Plot trajectory in 3D
plot3(waypoints(:,1), waypoints(:,2), zeros(size(waypoints,1),1), ...
    'w-o', 'LineWidth', 3, 'MarkerSize', 10, 'MarkerFaceColor', 'w');

xlabel('North (m)'); ylabel('East (m)'); zlabel('s(X)');
title('3D Safety Field');
view(45, 30);

fprintf('  ✓ Figure 2 completed\n');

%% Summary
fprintf('\n╔═══════════════════════════════════════════════════════════╗\n');
fprintf('║  SUMMARY - Paper-Correct Flow Complete\n');
fprintf('╚═══════════════════════════════════════════════════════════╝\n\n');

fprintf('Paper Flow Executed:\n');
fprintf('  ✓ Step 1: Measured aircraft performance\n');
fprintf('  ✓ Step 2: Calculated safety envelope from performance\n');
fprintf('  ✓ Step 3: Planned trajectory considering envelope size\n');
fprintf('  ✓ Step 4: Computed conflict probability field s(X)\n');
fprintf('  ✓ Step 5: Verified trajectory safety\n\n');

fprintf('Results:\n');
fprintf('  Safety Envelope: r_eq = %.2f m\n', r_eq);
fprintf('  Required Separation: %.2f m\n', 2*r_eq);
fprintf('  Safe Airspace: %.1f%%\n', safe_area_percentage);
if trajectory_safe
    fprintf('  Trajectory Status: SAFE\n');
else
    fprintf('  Trajectory Status: UNSAFE\n');
end
fprintf('  Max Conflict Prob: %.4f\n\n', max_conflict_prob);

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  Paper-Correct Implementation Complete!\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
