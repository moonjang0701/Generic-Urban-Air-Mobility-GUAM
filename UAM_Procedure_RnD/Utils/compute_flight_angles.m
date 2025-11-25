function [angles] = compute_flight_angles(trajectory_data)
% COMPUTE_FLIGHT_ANGLES - Compute flight path angles from GUAM trajectory
%
% This function computes climb/descent angles, bank angles, and other
% flight path geometry parameters for UAM procedure design
%
% Inputs:
%   trajectory_data - Structure containing GUAM trajectory
%       .pos.North (m), .pos.East (m), .pos.Down (m)
%       .vel.u_b (m/s), .vel.v_b (m/s), .vel.w_b (m/s)
%       .att.phi (rad), .att.theta (rad), .att.psi (rad)
%       .time (sec)
%
% Outputs:
%   angles - Structure containing flight angles
%       .flight_path_angle - γ, flight path angle (deg)
%       .climb_angle - positive γ values (deg)
%       .descent_angle - negative γ values (deg)
%       .bank_angle - φ (deg)
%       .pitch_angle - θ (deg)
%       .heading_angle - ψ (deg)
%       .turn_rate - dψ/dt (deg/s)
%       .statistics - Statistical summaries
%
% Flight Path Angle Definition:
%   γ = arctan(dh/ds)
%   where h is altitude and s is horizontal distance
%
% Author: UAM Procedure R&D Team
% Date: 2024-11-24
% Version: 1.0

%% Extract Trajectory Data
north = trajectory_data.pos.North;
east = trajectory_data.pos.East;
down = trajectory_data.pos.Down;
time = trajectory_data.time;

% Ensure column vectors
north = north(:);
east = east(:);
down = down(:);
time = time(:);

% Altitude (convert from Down)
alt = -down;

% Attitudes (if available)
if isfield(trajectory_data, 'att')
    phi = rad2deg(trajectory_data.att.phi);      % Roll/Bank angle
    theta = rad2deg(trajectory_data.att.theta);  % Pitch angle
    psi = rad2deg(trajectory_data.att.psi);      % Heading/Yaw angle
    has_attitudes = true;
else
    has_attitudes = false;
end

% Velocities (if available)
if isfield(trajectory_data, 'vel')
    if isfield(trajectory_data.vel, 'u_b')
        vx = trajectory_data.vel.u_b;
        vy = trajectory_data.vel.v_b;
        vz = trajectory_data.vel.w_b;
        has_velocities = true;
    elseif isfield(trajectory_data.vel, 'V_n')
        vx = trajectory_data.vel.V_n;
        vy = trajectory_data.vel.V_e;
        vz = trajectory_data.vel.V_d;
        has_velocities = true;
    else
        has_velocities = false;
    end
else
    has_velocities = false;
end

n_points = length(time);

%% Compute Position Derivatives
% Horizontal distances
dx = diff(north);
dy = diff(east);
dh = diff(alt);
dt = diff(time);

% Prevent division by zero
dt(dt < 1e-6) = 1e-6;

% Horizontal distance increments
ds = sqrt(dx.^2 + dy.^2);

% Rates
vn = [0; dx ./ dt];  % North velocity
ve = [0; dy ./ dt];  % East velocity
vh = [0; dh ./ dt];  % Vertical velocity

% Ground speed
V_ground = sqrt(vn.^2 + ve.^2);

%% Compute Flight Path Angle
% γ = arctan(vertical_velocity / horizontal_velocity)
% or γ = arctan(dh/ds)

gamma = zeros(n_points, 1);
for i = 2:n_points
    if V_ground(i) > 0.1  % Minimum ground speed threshold
        gamma(i) = atan2d(vh(i), V_ground(i));
    else
        gamma(i) = 0;
    end
end

% Separate climb and descent angles
climb_angle = gamma;
climb_angle(gamma <= 0) = NaN;

descent_angle = abs(gamma);
descent_angle(gamma >= 0) = NaN;

%% Compute Heading and Turn Rate
heading = atan2d(ve, vn);

% Unwrap heading to avoid 360° jumps
heading_unwrap = unwrap(heading * pi/180) * 180/pi;

% Turn rate (deg/s)
turn_rate = [0; diff(heading_unwrap) ./ dt];

%% Bank Angle (if attitudes available)
if has_attitudes
    bank_angle = phi;
else
    % Estimate bank angle from turn rate
    % For coordinated turn: tan(φ) = V * ω / g
    % where ω is turn rate in rad/s
    
    bank_angle = zeros(n_points, 1);
    g = 9.81;  % m/s²
    
    for i = 2:n_points
        if V_ground(i) > 1.0  % Minimum speed threshold
            omega = turn_rate(i) * pi/180;  % Convert to rad/s
            bank_angle(i) = atan2d(V_ground(i) * omega, g);
        end
    end
end

%% Pitch Angle (if attitudes available)
if has_attitudes
    pitch_angle = theta;
else
    % Estimate from flight path angle and angle of attack
    % Simplified: θ ≈ γ (assuming small angle of attack)
    pitch_angle = gamma;
end

%% Compute Statistics

% Flight path angle statistics
stats = struct();

% Overall
stats.gamma.mean = mean(gamma(~isnan(gamma)));
stats.gamma.std = std(gamma(~isnan(gamma)));
stats.gamma.max = max(gamma);
stats.gamma.min = min(gamma);

% Climb angle statistics
climb_data = climb_angle(~isnan(climb_angle));
if ~isempty(climb_data)
    stats.climb.mean = mean(climb_data);
    stats.climb.std = std(climb_data);
    stats.climb.max = max(climb_data);
    stats.climb.percentile_95 = prctile(climb_data, 95);
    stats.climb.percentile_99 = prctile(climb_data, 99);
else
    stats.climb.mean = 0;
    stats.climb.std = 0;
    stats.climb.max = 0;
    stats.climb.percentile_95 = 0;
    stats.climb.percentile_99 = 0;
end

% Descent angle statistics
descent_data = descent_angle(~isnan(descent_angle));
if ~isempty(descent_data)
    stats.descent.mean = mean(descent_data);
    stats.descent.std = std(descent_data);
    stats.descent.max = max(descent_data);
    stats.descent.percentile_95 = prctile(descent_data, 95);
    stats.descent.percentile_99 = prctile(descent_data, 99);
else
    stats.descent.mean = 0;
    stats.descent.std = 0;
    stats.descent.max = 0;
    stats.descent.percentile_95 = 0;
    stats.descent.percentile_99 = 0;
end

% Bank angle statistics
bank_data = bank_angle(~isnan(bank_angle));
if ~isempty(bank_data)
    stats.bank.mean = mean(abs(bank_data));
    stats.bank.std = std(bank_data);
    stats.bank.max = max(abs(bank_data));
    stats.bank.percentile_95 = prctile(abs(bank_data), 95);
    stats.bank.percentile_99 = prctile(abs(bank_data), 99);
else
    stats.bank.mean = 0;
    stats.bank.std = 0;
    stats.bank.max = 0;
    stats.bank.percentile_95 = 0;
    stats.bank.percentile_99 = 0;
end

% Turn rate statistics
turn_data = turn_rate(~isnan(turn_rate) & abs(turn_rate) > 0.1);
if ~isempty(turn_data)
    stats.turn_rate.mean = mean(abs(turn_data));
    stats.turn_rate.std = std(turn_data);
    stats.turn_rate.max = max(abs(turn_data));
else
    stats.turn_rate.mean = 0;
    stats.turn_rate.std = 0;
    stats.turn_rate.max = 0;
end

% Pitch angle statistics
if has_attitudes
    pitch_data = pitch_angle(~isnan(pitch_angle));
    if ~isempty(pitch_data)
        stats.pitch.mean = mean(pitch_data);
        stats.pitch.std = std(pitch_data);
        stats.pitch.max = max(abs(pitch_data));
    else
        stats.pitch.mean = 0;
        stats.pitch.std = 0;
        stats.pitch.max = 0;
    end
end

%% Package Output
angles = struct();

% Time series data
angles.time = time;
angles.flight_path_angle = gamma;
angles.climb_angle = climb_angle;
angles.descent_angle = descent_angle;
angles.bank_angle = bank_angle;
angles.pitch_angle = pitch_angle;

if has_attitudes
    angles.heading_angle = psi;
else
    angles.heading_angle = heading;
end

angles.turn_rate = turn_rate;

% Ground track data
angles.ground_speed = V_ground;
angles.vertical_speed = vh;
angles.heading = heading;

% Statistics
angles.statistics = stats;

% Metadata
angles.metadata.has_attitudes = has_attitudes;
angles.metadata.has_velocities = has_velocities;
angles.metadata.n_points = n_points;
angles.metadata.duration = time(end) - time(1);

end
