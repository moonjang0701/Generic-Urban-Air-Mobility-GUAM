function [ref_traj] = generate_reference_trajectory(length_m, altitude_ft, speed_kt, duration_s)
%% GENERATE_REFERENCE_TRAJECTORY
% Generate a straight-line reference trajectory for GUAM simulation
%
% Inputs:
%   length_m    - Trajectory length (meters)
%   altitude_ft - Flight altitude (feet)
%   speed_kt    - Ground speed (knots)
%   duration_s  - Total simulation duration (seconds)
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
%   Creates a straight 1D trajectory along +North axis at constant altitude
%   and constant ground speed. Compatible with GUAM RefInputEnum.TIMESERIES.
%
% Example:
%   ref_traj = generate_reference_trajectory(1000, 1000, 90, 30);
%
% Author: AI Assistant
% Date: 2025-01-18

    %% Unit conversions
    altitude_m = altitude_ft * 0.3048;      % ft to meters
    speed_ms = speed_kt * 0.514444;         % knots to m/s
    
    %% Calculate trajectory time
    nominal_time = length_m / speed_ms;     % Time to complete segment
    
    % Use at least 3 waypoints for smooth interpolation
    if duration_s < nominal_time
        duration_s = nominal_time * 1.5;    % Extend to allow completion
    end
    
    %% Define waypoints
    % Use 3-point definition for GUAM compatibility
    N_time = 3;
    time = linspace(0, nominal_time, N_time)';  % CRITICAL: Column vector
    
    % Position waypoints (NED frame)
    pos = zeros(N_time, 3);
    pos(:, 1) = linspace(0, length_m, N_time);  % North: 0 → length_m
    pos(:, 2) = 0;                               % East: 0 (straight)
    pos(:, 3) = -altitude_m;                     % Down: -altitude (NED convention)
    
    %% Heading and velocity
    % Heading along North axis
    heading_deg = 0;                        % North = 0°
    heading_rad = 0;                        % 0 radians
    chi = heading_rad * ones(N_time, 1);   % Constant heading (column)
    chi_dot = zeros(N_time, 1);            % No heading rate (column)
    
    %% Inertial velocity (NED frame)
    vel_i = zeros(3, N_time);  % 3×N matrix for STARS compatibility
    vel_i(1, :) = speed_ms;    % North velocity
    vel_i(2, :) = 0;           % East velocity
    vel_i(3, :) = 0;           % Down velocity (level flight)
    
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
    ref_traj.duration_s = duration_s;
    ref_traj.nominal_time_s = nominal_time;
    
end
