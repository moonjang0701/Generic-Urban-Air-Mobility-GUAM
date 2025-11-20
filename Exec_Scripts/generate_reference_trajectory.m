function [ref_traj] = generate_reference_trajectory(length_m, altitude_ft, speed_kt, duration_s)
%% GENERATE_REFERENCE_TRAJECTORY
% Generate a straight-line reference trajectory for STEADY CRUISE flight
%
% Inputs:
%   length_m    - Trajectory length (meters)
%   altitude_ft - Flight altitude (feet)
%   speed_kt    - Ground speed (knots)
%   duration_s  - Total simulation duration (seconds) [IGNORED - calculated from length/speed]
%
% Outputs:
%   ref_traj    - Structure containing:
%                 .time - Time vector (column)
%                 .pos  - Position [N, E, D] (m)
%                 .vel_ms - Velocity magnitude (m/s)
%                 .heading_deg - Heading (degrees)
%                 .chi - Heading (radians, column)
%                 .Vel_bIc_des - Body velocity timeseries
%                 .pos_des - Position timeseries
%                 .chi_des - Heading timeseries
%                 .chi_dot_des - Heading rate timeseries
%                 .vel_des - Inertial velocity timeseries
%
% Description:
%   Creates a straight trajectory for STEADY CRUISE flight (no hover, no acceleration).
%   Uses many waypoints to ensure smooth trajectory without artificial peaks.
%   Constant altitude, constant ground speed along +North axis.
%
% Example:
%   ref_traj = generate_reference_trajectory(10000, 1000, 90, 0);
%
% Author: AI Assistant
% Date: 2025-01-20

    %% Unit conversions
    altitude_m = altitude_ft * 0.3048;      % ft to meters
    speed_ms = speed_kt * 0.514444;         % knots to m/s
    
    %% Calculate trajectory time
    nominal_time = length_m / speed_ms;     % Time to complete segment
    
    %% Define waypoints - USE MANY POINTS for smooth cruise
    % For steady cruise, use at least 50 points to avoid artificial peaks
    N_time = max(50, ceil(nominal_time / 2));  % 1 point every 2 seconds minimum
    
    time = linspace(0, nominal_time, N_time)';  % Column vector
    
    % Position waypoints (NED frame)
    pos = zeros(N_time, 3);
    pos(:, 1) = linspace(0, length_m, N_time);  % North: 0 → length_m (linear)
    pos(:, 2) = 0;                               % East: 0 (perfectly straight)
    pos(:, 3) = -altitude_m;                     % Down: -altitude (constant, level flight)
    
    %% Heading and velocity - CONSTANT for steady cruise
    heading_deg = 0;                        % North = 0°
    heading_rad = 0;                        % 0 radians
    chi = heading_rad * ones(N_time, 1);   % Constant heading (column)
    chi_dot = zeros(N_time, 1);            % No heading rate (column)
    
    %% Inertial velocity (NED frame) - CONSTANT
    vel_i = zeros(3, N_time);  % 3×N matrix for STARS compatibility
    vel_i(1, :) = speed_ms;    % North velocity (constant)
    vel_i(2, :) = 0;           % East velocity (zero)
    vel_i(3, :) = 0;           % Down velocity (zero, level flight)
    
    %% Body velocity (using quaternion transformation)
    % Load STARS library for quaternion operations
    if ~exist('QrotZ', 'file')
        addpath(genpath('lib'));
    end
    
    % Rotation quaternion for heading
    q = QrotZ(chi);
    
    % Transform to body frame
    vel_body = Qtrans(q, vel_i);
    
    %% Create GUAM-compatible timeseries objects
    ref_traj = struct();
    
    % Time and basic parameters
    ref_traj.time = time;                   % Column vector
    ref_traj.pos = pos;                     % N×3 matrix
    ref_traj.vel_ms = speed_ms;             % Scalar
    ref_traj.heading_deg = heading_deg;     % Scalar
    ref_traj.chi = chi;                     % Column vector
    
    % GUAM RefInput structure fields
    ref_traj.Vel_bIc_des = timeseries(vel_body, time);
    ref_traj.pos_des = timeseries(pos, time);
    ref_traj.chi_des = timeseries(chi, time);
    ref_traj.chi_dot_des = timeseries(chi_dot, time);
    ref_traj.vel_des = timeseries(vel_i, time);
    
    %% Add metadata
    ref_traj.length_m = length_m;
    ref_traj.altitude_m = altitude_m;
    ref_traj.altitude_ft = altitude_ft;
    ref_traj.speed_ms = speed_ms;
    ref_traj.speed_kt = speed_kt;
    ref_traj.duration_s = nominal_time;  % Actual duration
    ref_traj.nominal_time_s = nominal_time;
    ref_traj.n_waypoints = N_time;
    
    fprintf('  Generated %d waypoints for smooth cruise\n', N_time);
    fprintf('  Trajectory: %.0f m in %.1f s at %.0f kt\n', length_m, nominal_time, speed_kt);
    
end
