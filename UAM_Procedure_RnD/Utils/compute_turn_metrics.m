function [turn_metrics] = compute_turn_metrics(trajectory_data, varargin)
% COMPUTE_TURN_METRICS - Analyze turn performance and geometry
%
% This function analyzes turn segments in GUAM trajectory data to extract
% turn radius, bank angles, overshoot/undershoot, and protection area
% requirements for UAM procedure design
%
% Inputs:
%   trajectory_data - Structure containing GUAM trajectory
%       .pos.North (m), .pos.East (m), .pos.Down (m)
%       .att.phi (rad), .att.theta (rad), .att.psi (rad)
%       .time (sec)
%
% Optional Name-Value Pairs:
%   'TurnThreshold' - Minimum heading change to detect turn (deg, default: 5)
%   'BankThreshold' - Minimum bank angle to detect turn (deg, default: 5)
%
% Outputs:
%   turn_metrics - Structure containing turn analysis
%       .turns - Array of detected turn segments
%       .statistics - Overall turn statistics
%       .protection_area - Required protection area dimensions
%
% Author: UAM Procedure R&D Team
% Date: 2024-11-24
% Version: 1.0

%% Parse Inputs
p = inputParser;
addRequired(p, 'trajectory_data');
addParameter(p, 'TurnThreshold', 5, @isnumeric);
addParameter(p, 'BankThreshold', 5, @isnumeric);
parse(p, trajectory_data, varargin{:});

turn_threshold = p.Results.TurnThreshold;
bank_threshold = p.Results.BankThreshold;

%% Extract Trajectory Data
north = trajectory_data.pos.North;
east = trajectory_data.pos.East;
down = trajectory_data.pos.Down;
time = trajectory_data.time;

% Check for attitudes
if isfield(trajectory_data, 'att')
    phi = rad2deg(trajectory_data.att.phi);
    psi = rad2deg(trajectory_data.att.psi);
    has_attitudes = true;
else
    has_attitudes = false;
end

n_points = length(time);

%% Compute Heading and Ground Track
dx = diff(north);
dy = diff(east);
dt = diff(time);
dt(dt < 1e-6) = 1e-6;

% Ground speed
ds = sqrt(dx.^2 + dy.^2);
V_ground = [0; ds ./ dt];

% Heading from ground track
heading = atan2d(dy, dx);
heading = [heading(1); heading];  % Extend to match length

% Unwrap to avoid 360° jumps
heading_unwrap = unwrap(heading * pi/180) * 180/pi;

% Heading rate
heading_rate = [0; diff(heading_unwrap) ./ dt];

%% Detect Turn Segments
% A turn is detected when:
% 1. Heading rate exceeds threshold
% 2. Bank angle exceeds threshold (if available)

in_turn = false;
turn_start = [];
turn_end = [];
turn_segments = [];

for i = 2:n_points
    % Check if in turn
    is_turning = abs(heading_rate(i)) > turn_threshold/10;  % deg/s threshold
    
    if has_attitudes
        is_turning = is_turning || abs(phi(i)) > bank_threshold;
    end
    
    if is_turning && ~in_turn
        % Turn start
        turn_start = i;
        in_turn = true;
    elseif ~is_turning && in_turn
        % Turn end
        turn_end = i - 1;
        in_turn = false;
        
        % Store turn segment
        if turn_end > turn_start
            turn_segments = [turn_segments; turn_start, turn_end];
        end
    end
end

% Handle case where turn continues to end
if in_turn
    turn_segments = [turn_segments; turn_start, n_points];
end

n_turns = size(turn_segments, 1);

%% Analyze Each Turn
turns = struct();

for t = 1:n_turns
    idx_start = turn_segments(t, 1);
    idx_end = turn_segments(t, 2);
    idx_range = idx_start:idx_end;
    
    % Turn timing
    turns(t).time_start = time(idx_start);
    turns(t).time_end = time(idx_end);
    turns(t).duration = time(idx_end) - time(idx_start);
    
    % Turn geometry
    heading_change = heading_unwrap(idx_end) - heading_unwrap(idx_start);
    turns(t).heading_change = heading_change;  % degrees
    turns(t).turn_direction = sign(heading_change);  % +1 right, -1 left
    
    % Turn center and radius estimation
    % Use circle fitting for better accuracy
    x = north(idx_range);
    y = east(idx_range);
    
    if length(x) >= 3
        % Fit circle to turn points
        [xc, yc, R] = fit_circle(x, y);
        
        turns(t).center_north = xc;
        turns(t).center_east = yc;
        turns(t).radius = R;
    else
        % Not enough points, use simple estimate
        turns(t).center_north = mean(north(idx_range));
        turns(t).center_east = mean(east(idx_range));
        turns(t).radius = nan;
    end
    
    % Bank angle statistics
    if has_attitudes
        bank_in_turn = phi(idx_range);
        turns(t).bank_mean = mean(abs(bank_in_turn));
        turns(t).bank_max = max(abs(bank_in_turn));
        turns(t).bank_min = min(abs(bank_in_turn));
    else
        % Estimate bank from turn radius
        % tan(φ) = V²/(g*R)
        g = 9.81;
        V_avg = mean(V_ground(idx_range));
        
        if ~isnan(turns(t).radius) && turns(t).radius > 0
            bank_est = atan2d(V_avg^2, g * turns(t).radius);
            turns(t).bank_mean = bank_est;
            turns(t).bank_max = bank_est;
            turns(t).bank_min = bank_est;
        else
            turns(t).bank_mean = nan;
            turns(t).bank_max = nan;
            turns(t).bank_min = nan;
        end
    end
    
    % Turn rate
    turns(t).turn_rate_mean = abs(mean(heading_rate(idx_range)));
    turns(t).turn_rate_max = max(abs(heading_rate(idx_range)));
    
    % Ground speed during turn
    turns(t).speed_mean = mean(V_ground(idx_range));
    turns(t).speed_min = min(V_ground(idx_range));
    turns(t).speed_max = max(V_ground(idx_range));
    
    % Cross-track deviation (overshoot/undershoot)
    % Compute distance from ideal arc
    if ~isnan(turns(t).radius)
        dist_from_center = sqrt((x - xc).^2 + (y - yc).^2);
        deviation = dist_from_center - R;
        
        turns(t).cross_track_max = max(abs(deviation));
        turns(t).cross_track_rms = sqrt(mean(deviation.^2));
        turns(t).overshoot = max(deviation);
        turns(t).undershoot = abs(min(deviation));
    else
        turns(t).cross_track_max = nan;
        turns(t).cross_track_rms = nan;
        turns(t).overshoot = nan;
        turns(t).undershoot = nan;
    end
    
    % Position at turn entry and exit
    turns(t).entry.north = north(idx_start);
    turns(t).entry.east = east(idx_start);
    turns(t).entry.alt = -down(idx_start);
    turns(t).entry.heading = heading_unwrap(idx_start);
    
    turns(t).exit.north = north(idx_end);
    turns(t).exit.east = east(idx_end);
    turns(t).exit.alt = -down(idx_end);
    turns(t).exit.heading = heading_unwrap(idx_end);
end

%% Compute Overall Statistics
if n_turns > 0
    stats = struct();
    
    % Extract vectors for statistics
    radii = [turns.radius];
    radii = radii(~isnan(radii));
    
    bank_means = [turns.bank_mean];
    bank_means = bank_means(~isnan(bank_means));
    
    bank_maxs = [turns.bank_max];
    bank_maxs = bank_maxs(~isnan(bank_maxs));
    
    cross_track_maxs = [turns.cross_track_max];
    cross_track_maxs = cross_track_maxs(~isnan(cross_track_maxs));
    
    overshoots = [turns.overshoot];
    overshoots = overshoots(~isnan(overshoots));
    
    undershoots = [turns.undershoot];
    undershoots = undershoots(~isnan(undershoots));
    
    % Statistics
    stats.n_turns = n_turns;
    stats.n_right_turns = sum([turns.turn_direction] > 0);
    stats.n_left_turns = sum([turns.turn_direction] < 0);
    
    if ~isempty(radii)
        stats.radius.min = min(radii);
        stats.radius.mean = mean(radii);
        stats.radius.max = max(radii);
        stats.radius.std = std(radii);
    else
        stats.radius.min = nan;
        stats.radius.mean = nan;
        stats.radius.max = nan;
        stats.radius.std = nan;
    end
    
    if ~isempty(bank_means)
        stats.bank.mean = mean(bank_means);
        stats.bank.max = max(bank_maxs);
        stats.bank.std = std(bank_means);
        stats.bank.percentile_95 = prctile(bank_maxs, 95);
    else
        stats.bank.mean = nan;
        stats.bank.max = nan;
        stats.bank.std = nan;
        stats.bank.percentile_95 = nan;
    end
    
    if ~isempty(cross_track_maxs)
        stats.cross_track.max = max(cross_track_maxs);
        stats.cross_track.mean = mean(cross_track_maxs);
        stats.cross_track.percentile_95 = prctile(cross_track_maxs, 95);
    else
        stats.cross_track.max = nan;
        stats.cross_track.mean = nan;
        stats.cross_track.percentile_95 = nan;
    end
    
    if ~isempty(overshoots)
        stats.overshoot.max = max(overshoots);
        stats.overshoot.mean = mean(overshoots);
    else
        stats.overshoot.max = nan;
        stats.overshoot.mean = nan;
    end
    
    if ~isempty(undershoots)
        stats.undershoot.max = max(undershoots);
        stats.undershoot.mean = mean(undershoots);
    else
        stats.undershoot.max = nan;
        stats.undershoot.mean = nan;
    end
else
    stats = struct();
    stats.n_turns = 0;
    stats.message = 'No turns detected';
end

%% Compute Protection Area Requirements
% Based on maximum deviations observed

protection = struct();

if n_turns > 0 && ~isnan(stats.cross_track.max)
    % Lateral protection (splay) for turns
    protection.lateral_splay = stats.cross_track.percentile_95;
    
    % Turn area width (2 * radius + lateral margin)
    if ~isnan(stats.radius.min)
        protection.turn_area_width = 2 * stats.radius.min + 2 * protection.lateral_splay;
    else
        protection.turn_area_width = nan;
    end
    
    % Recommended minimum turn radius for procedure design
    protection.recommended_min_radius = stats.radius.min * 1.1;  % 10% margin
    
    % Recommended bank angle limit
    if ~isnan(stats.bank.percentile_95)
        protection.recommended_bank_limit = ceil(stats.bank.percentile_95 / 5) * 5;  % Round up to nearest 5°
    else
        protection.recommended_bank_limit = nan;
    end
else
    protection.lateral_splay = nan;
    protection.turn_area_width = nan;
    protection.recommended_min_radius = nan;
    protection.recommended_bank_limit = nan;
end

%% Package Output
turn_metrics = struct();
turn_metrics.turns = turns;
turn_metrics.statistics = stats;
turn_metrics.protection_area = protection;
turn_metrics.metadata.n_turns = n_turns;
turn_metrics.metadata.turn_threshold = turn_threshold;
turn_metrics.metadata.bank_threshold = bank_threshold;
turn_metrics.metadata.has_attitudes = has_attitudes;

end

%% Helper Function: Fit Circle to Points
function [xc, yc, R] = fit_circle(x, y)
% Fit circle to 2D points using algebraic method
% Minimizes sum of squared algebraic distances

n = length(x);

% Build system matrix
A = [2*x, 2*y, ones(n,1)];
b = x.^2 + y.^2;

% Solve least squares
params = A \ b;

xc = params(1);
yc = params(2);
R = sqrt(params(3) + xc^2 + yc^2);

end
