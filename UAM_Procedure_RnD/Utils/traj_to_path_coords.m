function [path_coords] = traj_to_path_coords(trajectory_data, varargin)
% TRAJ_TO_PATH_COORDS - Convert GUAM trajectory to path coordinate system
%
% This function converts GUAM simulation trajectory data to a path-following
% coordinate system (along-track, cross-track, height) for procedure analysis
%
% Inputs:
%   trajectory_data - Structure containing GUAM trajectory
%       .pos.North (m)
%       .pos.East (m)
%       .pos.Down (m)
%       .time (sec)
%
% Optional Name-Value Pairs:
%   'CenterlineMethod' - Method for computing centerline (default: 'smooth')
%                        Options: 'smooth', 'waypoints', 'linear'
%   'SmoothingParam' - Smoothing parameter for spline (default: 0.95)
%
% Outputs:
%   path_coords - Structure containing path coordinates
%       .s - Along-track distance (m)
%       .e - Cross-track error (m)
%       .h - Height above centerline (m)
%       .time - Time vector (sec)
%       .centerline.x - Centerline North positions (m)
%       .centerline.y - Centerline East positions (m)
%       .centerline.z - Centerline altitude (m)
%       .centerline.s - Along-track distance of centerline (m)
%       .lateral_deviation_max - Maximum lateral deviation (m)
%       .lateral_deviation_rms - RMS lateral deviation (m)
%
% Example:
%   path_coords = traj_to_path_coords(SimOut.NED);
%   path_coords = traj_to_path_coords(SimOut.NED, 'CenterlineMethod', 'waypoints');
%
% Author: UAM Procedure R&D Team
% Date: 2024-11-24
% Version: 1.0

%% Parse Inputs
p = inputParser;
addRequired(p, 'trajectory_data');
addParameter(p, 'CenterlineMethod', 'smooth', @ischar);
addParameter(p, 'SmoothingParam', 0.95, @isnumeric);
parse(p, trajectory_data, varargin{:});

method = p.Results.CenterlineMethod;
smooth_param = p.Results.SmoothingParam;

%% Extract Trajectory Data
% Position data (NED frame)
north = trajectory_data.pos.North;
east = trajectory_data.pos.East;
down = trajectory_data.pos.Down;
time = trajectory_data.time;

% Ensure column vectors
north = north(:);
east = east(:);
down = down(:);
time = time(:);

% Convert Down to altitude (h = -Down)
alt = -down;

% Number of points
n_points = length(time);

%% Compute Centerline
switch lower(method)
    case 'smooth'
        % Use smoothing spline to create centerline
        
        % Compute cumulative path distance for parameterization
        dx = diff(north);
        dy = diff(east);
        ds = sqrt(dx.^2 + dy.^2);
        s_raw = [0; cumsum(ds)];
        
        % Fit smoothing splines
        if n_points > 3
            % Try to use csaps (Curve Fitting Toolbox)
            % If not available, use smoothing filter
            if exist('csaps', 'file') == 2
                centerline_x = csaps(s_raw, north, smooth_param, s_raw);
                centerline_y = csaps(s_raw, east, smooth_param, s_raw);
                centerline_z = csaps(s_raw, alt, smooth_param, s_raw);
            else
                % Fallback: use moving average filter
                window_size = max(3, round(n_points * (1 - smooth_param)));
                if mod(window_size, 2) == 0
                    window_size = window_size + 1; % Make it odd
                end
                centerline_x = smooth(north, window_size, 'moving');
                centerline_y = smooth(east, window_size, 'moving');
                centerline_z = smooth(alt, window_size, 'moving');
            end
        else
            % Not enough points for smoothing, use linear
            centerline_x = north;
            centerline_y = east;
            centerline_z = alt;
        end
        
    case 'waypoints'
        % Use waypoints if provided (not implemented yet)
        % For now, fall back to linear
        centerline_x = north;
        centerline_y = east;
        centerline_z = alt;
        
    case 'linear'
        % Use actual trajectory as centerline
        centerline_x = north;
        centerline_y = east;
        centerline_z = alt;
        
    otherwise
        error('Unknown centerline method: %s', method);
end

%% Compute Path Coordinates

% Along-track distance
dx = diff(centerline_x);
dy = diff(centerline_y);
ds = sqrt(dx.^2 + dy.^2);
s = [0; cumsum(ds)];

% Cross-track error (perpendicular distance to centerline)
e = zeros(n_points, 1);

for i = 1:n_points
    % Find nearest segment on centerline
    if i == 1
        % First point
        e(i) = 0;
    elseif i == n_points
        % Last point
        e(i) = 0;
    else
        % Compute perpendicular distance to line segment
        % Use previous and next points to define local tangent
        
        % Local tangent vector
        if i > 1 && i < n_points
            tx = centerline_x(i+1) - centerline_x(i-1);
            ty = centerline_y(i+1) - centerline_y(i-1);
        else
            tx = dx(min(i, length(dx)));
            ty = dy(min(i, length(dy)));
        end
        
        % Normalize
        t_mag = sqrt(tx^2 + ty^2);
        if t_mag > 1e-6
            tx = tx / t_mag;
            ty = ty / t_mag;
        end
        
        % Vector from centerline to actual position
        rx = north(i) - centerline_x(i);
        ry = east(i) - centerline_y(i);
        
        % Cross-track error is perpendicular component
        % Using 2D cross product: e = r × t (scalar in 2D)
        e(i) = rx * (-ty) + ry * tx;
    end
end

% Height error (vertical deviation from centerline)
h = alt - centerline_z;

%% Compute Statistics
lateral_dev_max = max(abs(e));
lateral_dev_rms = sqrt(mean(e.^2));
vertical_dev_max = max(abs(h));
vertical_dev_rms = sqrt(mean(h.^2));

%% Package Output
path_coords = struct();

% Path coordinates
path_coords.s = s;                  % Along-track distance (m)
path_coords.e = e;                  % Cross-track error (m)
path_coords.h = h;                  % Height error (m)
path_coords.time = time;            % Time vector (sec)

% Centerline
path_coords.centerline.x = centerline_x;
path_coords.centerline.y = centerline_y;
path_coords.centerline.z = centerline_z;
path_coords.centerline.s = s;

% Original trajectory
path_coords.original.north = north;
path_coords.original.east = east;
path_coords.original.alt = alt;

% Statistics
path_coords.statistics.lateral_deviation_max = lateral_dev_max;
path_coords.statistics.lateral_deviation_rms = lateral_dev_rms;
path_coords.statistics.vertical_deviation_max = vertical_dev_max;
path_coords.statistics.vertical_deviation_rms = vertical_dev_rms;
path_coords.statistics.total_distance = s(end);
path_coords.statistics.altitude_change = alt(end) - alt(1);

% Metadata
path_coords.metadata.centerline_method = method;
path_coords.metadata.smoothing_param = smooth_param;
path_coords.metadata.n_points = n_points;

end
