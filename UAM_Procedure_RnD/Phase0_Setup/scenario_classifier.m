function [scenario_catalog] = scenario_classifier(data_set_path)
% SCENARIO_CLASSIFIER - Classify GUAM Challenge Problem scenarios
%
% This function analyzes the GUAM Challenge Problem datasets and classifies
% each run into categories for UAM procedure design R&D
%
% Inputs:
%   data_set_path - Path to Challenge_Problems directory
%
% Outputs:
%   scenario_catalog - Structure containing classified scenarios
%
% Categories:
%   - Straight/Gentle turn/Sharp turn
%   - Climb/Level/Descent
%   - Normal/Abnormal (with failures)
%   - Terminal approach style
%   - Departure climb style
%   - En-route/corridor style
%
% Author: UAM Procedure R&D Team
% Date: 2024-11-24
% Version: 1.0

fprintf('\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  UAM Procedure R&D - Scenario Classification System\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

%% Load Challenge Problem Datasets
fprintf('Loading Challenge Problem datasets...\n');

% Load own trajectories
fprintf('  • Loading Data_Set_1.mat (Own Trajectories)...\n');
ds1_path = fullfile(data_set_path, 'Data_Set_1.mat');
if ~exist(ds1_path, 'file')
    error('Data_Set_1.mat not found. Please check path: %s', ds1_path);
end
ds1 = load(ds1_path);
n_runs = length(ds1.own_traj);
fprintf('    ✓ Loaded %d trajectory runs\n', n_runs);

% Load stationary obstacles
fprintf('  • Loading Data_Set_2.mat (Stationary Obstacles)...\n');
ds2_path = fullfile(data_set_path, 'Data_Set_2.mat');
if exist(ds2_path, 'file')
    ds2 = load(ds2_path);
    fprintf('    ✓ Loaded %d stationary obstacle scenarios\n', length(ds2.stat_obs));
else
    fprintf('    ⚠ Data_Set_2.mat not found, continuing without obstacles\n');
    ds2 = [];
end

% Load moving obstacles
fprintf('  • Loading Data_Set_3.mat (Moving Obstacles)...\n');
ds3_path = fullfile(data_set_path, 'Data_Set_3.mat');
if exist(ds3_path, 'file')
    ds3 = load(ds3_path);
    fprintf('    ✓ Loaded %d moving obstacle scenarios\n', length(ds3.mov_obs));
else
    fprintf('    ⚠ Data_Set_3.mat not found, continuing without moving obstacles\n');
    ds3 = [];
end

% Load failure scenarios
fprintf('  • Loading Data_Set_4.mat (Failures)...\n');
ds4_path = fullfile(data_set_path, 'Data_Set_4.mat');
if exist(ds4_path, 'file')
    ds4 = load(ds4_path);
    fprintf('    ✓ Loaded %d failure scenarios\n', length(ds4.failure));
else
    fprintf('    ⚠ Data_Set_4.mat not found, continuing without failures\n');
    ds4 = [];
end

fprintf('\n');

%% Initialize Catalog Structure
fprintf('Initializing scenario catalog...\n');

scenario_catalog = struct();
scenario_catalog.metadata.creation_date = datestr(now);
scenario_catalog.metadata.n_runs = n_runs;
scenario_catalog.metadata.data_path = data_set_path;

% Classification fields
scenario_catalog.runs = struct(...
    'run_id', cell(n_runs, 1), ...
    'trajectory_type', cell(n_runs, 1), ...     % straight/gentle_turn/sharp_turn
    'vertical_profile', cell(n_runs, 1), ...    % climb/level/descent/mixed
    'has_failure', cell(n_runs, 1), ...         % true/false
    'has_static_obstacle', cell(n_runs, 1), ... % true/false
    'has_moving_obstacle', cell(n_runs, 1), ... % true/false
    'procedure_style', cell(n_runs, 1), ...     % approach/departure/enroute
    'max_bank_angle', cell(n_runs, 1), ...      % degrees
    'max_climb_angle', cell(n_runs, 1), ...     % degrees
    'max_descent_angle', cell(n_runs, 1), ...   % degrees
    'min_turn_radius', cell(n_runs, 1), ...     % meters
    'total_distance', cell(n_runs, 1), ...      % meters
    'altitude_change', cell(n_runs, 1), ...     % meters
    'duration', cell(n_runs, 1) ...             % seconds
);

fprintf('  ✓ Catalog structure initialized\n\n');

%% Classify Each Run
fprintf('Classifying scenarios (this may take a few minutes)...\n');
fprintf('Progress: ');

for i = 1:n_runs
    % Progress indicator
    if mod(i, 100) == 0
        fprintf('%d/%d ', i, n_runs);
    end
    
    % Extract trajectory
    traj = ds1.own_traj{i};
    
    % Basic info
    scenario_catalog.runs(i).run_id = i;
    
    % Extract waypoints from Bezier curve
    if isfield(traj, 'waypoints') && ~isempty(traj.waypoints)
        wptsX = traj.waypoints{1};
        wptsY = traj.waypoints{2};
        wptsZ = traj.waypoints{3};
        
        % Convert to position vectors
        x = wptsX(:, 1);  % X positions
        y = wptsY(:, 1);  % Y positions
        z = wptsZ(:, 1);  % Z positions (altitude)
        
        % Check if we have enough points
        if length(x) < 2
            % Default values for insufficient data
            scenario_catalog.runs(i).trajectory_type = 'unknown';
            scenario_catalog.runs(i).vertical_profile = 'unknown';
            scenario_catalog.runs(i).procedure_style = 'unknown';
            scenario_catalog.runs(i).max_bank_angle = 0;
            scenario_catalog.runs(i).max_climb_angle = 0;
            scenario_catalog.runs(i).max_descent_angle = 0;
            scenario_catalog.runs(i).min_turn_radius = inf;
            scenario_catalog.runs(i).total_distance = 0;
            scenario_catalog.runs(i).altitude_change = 0;
            scenario_catalog.runs(i).duration = 0;
            continue;
        end
        
        % Calculate trajectory characteristics
        dx = diff(x);
        dy = diff(y);
        dz = diff(z);
        
        % Horizontal distances
        horiz_dist = sqrt(dx.^2 + dy.^2);
        total_dist = sum(horiz_dist);
        
        % Altitude change
        alt_change = z(end) - z(1);
        
        % Flight path angles (degrees)
        fpa = atan2d(dz, horiz_dist);
        max_climb = max(fpa(fpa > 0));
        max_descent = abs(min(fpa(fpa < 0)));
        
        if isempty(max_climb), max_climb = 0; end
        if isempty(max_descent), max_descent = 0; end
        
        % Heading changes (for turn analysis)
        heading = atan2d(dy, dx);
        dheading = diff(heading);
        
        % Normalize heading changes to [-180, 180]
        dheading(dheading > 180) = dheading(dheading > 180) - 360;
        dheading(dheading < -180) = dheading(dheading < -180) + 360;
        
        % Total turn angle
        total_turn = sum(abs(dheading));
        
        % Classify trajectory type based on turn severity
        if total_turn < 30
            traj_type = 'straight';
        elseif total_turn < 120
            traj_type = 'gentle_turn';
        else
            traj_type = 'sharp_turn';
        end
        
        % Classify vertical profile
        if abs(alt_change) < 50  % Less than 50m change
            vert_profile = 'level';
        elseif alt_change > 50
            vert_profile = 'climb';
        else
            vert_profile = 'descent';
        end
        
        % Classify procedure style (heuristic based on altitude change and distance)
        if alt_change < -100 && total_dist < 5000
            proc_style = 'approach';
        elseif alt_change > 100 && total_dist < 5000
            proc_style = 'departure';
        else
            proc_style = 'enroute';
        end
        
        % Estimate bank angle (simplified, assumes coordinated turn)
        % Bank angle ≈ atan(V²/(g*R)) where R is turn radius
        % For now, estimate from heading rate
        max_bank = 0;
        if max(abs(dheading)) > 5  % If there's significant turning
            % Rough estimate: bank = heading_rate * 10 (very simplified)
            max_bank = min(max(abs(dheading)) * 2, 45);  % Cap at 45 degrees
        end
        
        % Estimate minimum turn radius (simplified)
        if max(abs(dheading)) > 0
            % Rough estimate based on distance and heading change
            min_radius = 1000;  % Default large value
            for j = 1:length(dheading)
                if abs(dheading(j)) > 5
                    radius_est = horiz_dist(j) / (2 * sind(abs(dheading(j))/2));
                    min_radius = min(min_radius, radius_est);
                end
            end
        else
            min_radius = inf;
        end
        
        % Duration estimate (from time waypoints if available)
        if isfield(traj, 'time_wpts') && ~isempty(traj.time_wpts)
            time_wptsX = traj.time_wpts{1};
            if ~isempty(time_wptsX)
                duration = time_wptsX(end);
            else
                duration = 0;
            end
        else
            duration = 0;
        end
        
        % Store results
        scenario_catalog.runs(i).trajectory_type = traj_type;
        scenario_catalog.runs(i).vertical_profile = vert_profile;
        scenario_catalog.runs(i).procedure_style = proc_style;
        scenario_catalog.runs(i).max_bank_angle = max_bank;
        scenario_catalog.runs(i).max_climb_angle = max_climb;
        scenario_catalog.runs(i).max_descent_angle = max_descent;
        scenario_catalog.runs(i).min_turn_radius = min_radius;
        scenario_catalog.runs(i).total_distance = total_dist;
        scenario_catalog.runs(i).altitude_change = alt_change;
        scenario_catalog.runs(i).duration = duration;
        
    else
        % No trajectory data
        scenario_catalog.runs(i).trajectory_type = 'unknown';
        scenario_catalog.runs(i).vertical_profile = 'unknown';
        scenario_catalog.runs(i).procedure_style = 'unknown';
        scenario_catalog.runs(i).max_bank_angle = 0;
        scenario_catalog.runs(i).max_climb_angle = 0;
        scenario_catalog.runs(i).max_descent_angle = 0;
        scenario_catalog.runs(i).min_turn_radius = inf;
        scenario_catalog.runs(i).total_distance = 0;
        scenario_catalog.runs(i).altitude_change = 0;
        scenario_catalog.runs(i).duration = 0;
    end
    
    % Check for failures
    if ~isempty(ds4) && i <= length(ds4.failure)
        scenario_catalog.runs(i).has_failure = ~isempty(ds4.failure{i});
    else
        scenario_catalog.runs(i).has_failure = false;
    end
    
    % Check for obstacles
    if ~isempty(ds2) && i <= length(ds2.stat_obs)
        scenario_catalog.runs(i).has_static_obstacle = ~isempty(ds2.stat_obs{i});
    else
        scenario_catalog.runs(i).has_static_obstacle = false;
    end
    
    if ~isempty(ds3) && i <= length(ds3.mov_obs)
        scenario_catalog.runs(i).has_moving_obstacle = ~isempty(ds3.mov_obs{i});
    else
        scenario_catalog.runs(i).has_moving_obstacle = false;
    end
end

fprintf('\n  ✓ Classification complete!\n\n');

%% Generate Summary Statistics
fprintf('Generating summary statistics...\n');

% Trajectory type distribution
traj_types = {scenario_catalog.runs.trajectory_type};
scenario_catalog.statistics.trajectory_types = struct(...
    'straight', sum(strcmp(traj_types, 'straight')), ...
    'gentle_turn', sum(strcmp(traj_types, 'gentle_turn')), ...
    'sharp_turn', sum(strcmp(traj_types, 'sharp_turn')), ...
    'unknown', sum(strcmp(traj_types, 'unknown')) ...
);

% Vertical profile distribution
vert_profiles = {scenario_catalog.runs.vertical_profile};
scenario_catalog.statistics.vertical_profiles = struct(...
    'climb', sum(strcmp(vert_profiles, 'climb')), ...
    'level', sum(strcmp(vert_profiles, 'level')), ...
    'descent', sum(strcmp(vert_profiles, 'descent')), ...
    'unknown', sum(strcmp(vert_profiles, 'unknown')) ...
);

% Procedure style distribution
proc_styles = {scenario_catalog.runs.procedure_style};
scenario_catalog.statistics.procedure_styles = struct(...
    'approach', sum(strcmp(proc_styles, 'approach')), ...
    'departure', sum(strcmp(proc_styles, 'departure')), ...
    'enroute', sum(strcmp(proc_styles, 'enroute')), ...
    'unknown', sum(strcmp(proc_styles, 'unknown')) ...
);

% Failure statistics
has_failures = [scenario_catalog.runs.has_failure];
scenario_catalog.statistics.failures = struct(...
    'with_failure', sum(has_failures), ...
    'without_failure', sum(~has_failures) ...
);

% Obstacle statistics
has_static = [scenario_catalog.runs.has_static_obstacle];
has_moving = [scenario_catalog.runs.has_moving_obstacle];
scenario_catalog.statistics.obstacles = struct(...
    'with_static', sum(has_static), ...
    'with_moving', sum(has_moving), ...
    'with_any', sum(has_static | has_moving), ...
    'without_obstacles', sum(~has_static & ~has_moving) ...
);

fprintf('  ✓ Statistics generated\n\n');

%% Display Summary
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  SCENARIO CLASSIFICATION SUMMARY\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

fprintf('📊 Trajectory Types:\n');
fprintf('   • Straight:     %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.trajectory_types.straight, ...
    100*scenario_catalog.statistics.trajectory_types.straight/n_runs);
fprintf('   • Gentle Turn:  %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.trajectory_types.gentle_turn, ...
    100*scenario_catalog.statistics.trajectory_types.gentle_turn/n_runs);
fprintf('   • Sharp Turn:   %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.trajectory_types.sharp_turn, ...
    100*scenario_catalog.statistics.trajectory_types.sharp_turn/n_runs);
fprintf('   • Unknown:      %4d (%.1f%%)\n\n', ...
    scenario_catalog.statistics.trajectory_types.unknown, ...
    100*scenario_catalog.statistics.trajectory_types.unknown/n_runs);

fprintf('📈 Vertical Profiles:\n');
fprintf('   • Climb:        %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.vertical_profiles.climb, ...
    100*scenario_catalog.statistics.vertical_profiles.climb/n_runs);
fprintf('   • Level:        %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.vertical_profiles.level, ...
    100*scenario_catalog.statistics.vertical_profiles.level/n_runs);
fprintf('   • Descent:      %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.vertical_profiles.descent, ...
    100*scenario_catalog.statistics.vertical_profiles.descent/n_runs);
fprintf('   • Unknown:      %4d (%.1f%%)\n\n', ...
    scenario_catalog.statistics.vertical_profiles.unknown, ...
    100*scenario_catalog.statistics.vertical_profiles.unknown/n_runs);

fprintf('✈️  Procedure Styles:\n');
fprintf('   • Approach:     %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.procedure_styles.approach, ...
    100*scenario_catalog.statistics.procedure_styles.approach/n_runs);
fprintf('   • Departure:    %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.procedure_styles.departure, ...
    100*scenario_catalog.statistics.procedure_styles.departure/n_runs);
fprintf('   • En-route:     %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.procedure_styles.enroute, ...
    100*scenario_catalog.statistics.procedure_styles.enroute/n_runs);
fprintf('   • Unknown:      %4d (%.1f%%)\n\n', ...
    scenario_catalog.statistics.procedure_styles.unknown, ...
    100*scenario_catalog.statistics.procedure_styles.unknown/n_runs);

fprintf('⚠️  Failure Scenarios:\n');
fprintf('   • With Failure: %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.failures.with_failure, ...
    100*scenario_catalog.statistics.failures.with_failure/n_runs);
fprintf('   • Normal:       %4d (%.1f%%)\n\n', ...
    scenario_catalog.statistics.failures.without_failure, ...
    100*scenario_catalog.statistics.failures.without_failure/n_runs);

fprintf('🚧 Obstacle Scenarios:\n');
fprintf('   • Static:       %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.obstacles.with_static, ...
    100*scenario_catalog.statistics.obstacles.with_static/n_runs);
fprintf('   • Moving:       %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.obstacles.with_moving, ...
    100*scenario_catalog.statistics.obstacles.with_moving/n_runs);
fprintf('   • Any Obstacle: %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.obstacles.with_any, ...
    100*scenario_catalog.statistics.obstacles.with_any/n_runs);
fprintf('   • Clear:        %4d (%.1f%%)\n\n', ...
    scenario_catalog.statistics.obstacles.without_obstacles, ...
    100*scenario_catalog.statistics.obstacles.without_obstacles/n_runs);

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  Classification complete! Catalog ready for analysis.\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

end
