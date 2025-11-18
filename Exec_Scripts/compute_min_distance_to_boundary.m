function [d_min] = compute_min_distance_to_boundary(E_actual, corridor_half_width)
%% COMPUTE_MIN_DISTANCE_TO_BOUNDARY
% Compute minimum distance from trajectory to corridor boundary
%
% Inputs:
%   E_actual           - Actual East position time series (m), N×1
%   corridor_half_width - Corridor half-width (m), scalar
%
% Outputs:
%   d_min - Minimum distance to boundary (m), scalar
%           Positive = inside corridor (safe)
%           Negative = outside corridor (infringement)
%           Zero = exactly at boundary
%
% Description:
%   For a straight corridor centered at E = 0 with width ±W:
%   - Left boundary at E = -W
%   - Right boundary at E = +W
%   
%   Distance to boundary = min(|E + W|, |E - W|)
%   = W - |E|  (distance to nearest boundary)
%   
%   If d_min < 0, the trajectory has exited the corridor.
%
% Example:
%   E = [-50; 0; 50; 100];
%   W = 75;
%   d_min = compute_min_distance_to_boundary(E, W);
%   % Result: 25 (min occurs at E=50 or E=-50)
%
% Author: AI Assistant
% Date: 2025-01-18

    %% Compute distance to each boundary
    % Distance to left boundary (E = -corridor_half_width)
    d_left = E_actual + corridor_half_width;
    
    % Distance to right boundary (E = +corridor_half_width)
    d_right = corridor_half_width - E_actual;
    
    %% Minimum distance is the closest boundary
    % Positive distance = inside corridor
    % Negative distance = outside corridor (infringement)
    d_to_boundary = min(d_left, d_right);
    
    %% Find global minimum over entire trajectory
    d_min = min(d_to_boundary);
    
    %% Alternative: Return distance vector for all time points
    % This would be useful for plotting distance evolution
    % Uncomment if needed:
    % d_min = d_to_boundary;
    
end
