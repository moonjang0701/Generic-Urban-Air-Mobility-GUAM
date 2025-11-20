function [e_lateral] = compute_lateral_error(N_actual, E_actual, ref_traj)
%% COMPUTE_LATERAL_ERROR
% Compute lateral (cross-track) error relative to reference trajectory
%
% Inputs:
%   N_actual  - Actual North position time series (m), N×1
%   E_actual  - Actual East position time series (m), N×1
%   ref_traj  - Reference trajectory structure from generate_reference_trajectory
%
% Outputs:
%   e_lateral - Lateral error time series (m), N×1
%               Positive = right of track, Negative = left of track
%
% Description:
%   For a straight reference trajectory along +North axis (E_ref = 0),
%   the lateral error is simply the East component deviation.
%   
%   For general curved trajectories, this would require:
%   1. Find closest point on reference path for each actual position
%   2. Compute perpendicular distance to path
%   
%   Current implementation assumes straight North trajectory.
%
% Example:
%   e_lat = compute_lateral_error(N_sim, E_sim, ref_traj);
%
% Author: AI Assistant
% Date: 2025-01-18

    %% Extract reference trajectory info
    % For straight North trajectory, reference East = 0
    E_ref = 0;
    
    %% Compute lateral error
    % For straight trajectory along North axis:
    % Lateral error = actual East position - reference East position
    e_lateral = E_actual - E_ref;
    
    %% Alternative: General trajectory (commented for future use)
    % If trajectory is not straight, use this approach:
    %{
    N_time = length(N_actual);
    e_lateral = zeros(N_time, 1);
    
    for i = 1:N_time
        % Current position
        pos_current = [N_actual(i), E_actual(i)];
        
        % Find closest point on reference trajectory
        distances = sqrt((ref_traj.pos(:,1) - N_actual(i)).^2 + ...
                        (ref_traj.pos(:,2) - E_actual(i)).^2);
        [~, idx_closest] = min(distances);
        
        % Get reference position and heading at closest point
        if idx_closest == 1
            ref_pos = ref_traj.pos(1, 1:2);
            ref_heading = ref_traj.chi(1);
        elseif idx_closest == size(ref_traj.pos, 1)
            ref_pos = ref_traj.pos(end, 1:2);
            ref_heading = ref_traj.chi(end);
        else
            % Interpolate between waypoints
            ref_pos = ref_traj.pos(idx_closest, 1:2);
            ref_heading = ref_traj.chi(idx_closest);
        end
        
        % Compute vector from reference to actual
        delta = pos_current - ref_pos;
        
        % Decompose into along-track and cross-track components
        % Cross-track (lateral) = perpendicular to heading
        % Using rotation matrix: lateral = -delta_N * sin(chi) + delta_E * cos(chi)
        e_lateral(i) = -delta(1) * sin(ref_heading) + delta(2) * cos(ref_heading);
    end
    %}
    
end
