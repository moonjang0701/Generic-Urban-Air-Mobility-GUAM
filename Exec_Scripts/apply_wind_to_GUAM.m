function apply_wind_to_GUAM(wind_N, wind_E, wind_D)
%% APPLY_WIND_TO_GUAM
% Inject wind vector into GUAM simulation environment
%
% Inputs:
%   wind_N - North wind component (m/s)
%   wind_E - East wind component (m/s)
%   wind_D - Down wind component (m/s)
%
% Description:
%   Sets the wind velocity vector in GUAM's base workspace.
%   Must be called AFTER simSetup and BEFORE sim(model).
%
% Example:
%   apply_wind_to_GUAM(0, 10.29, 0);  % 20 kt crosswind (East)
%
% Author: AI Assistant
% Date: 2025-01-18

    %% Construct wind velocity vector (NED frame)
    wind_vec = [wind_N; wind_E; wind_D];
    
    %% Inject into GUAM base workspace
    % SimInput.Environment.Winds.Vel_wHh is the wind velocity field
    try
        evalin('base', sprintf('SimInput.Environment.Winds.Vel_wHh = [%.6f; %.6f; %.6f];', ...
               wind_N, wind_E, wind_D));
    catch ME
        warning('Failed to inject wind: %s', ME.message);
    end
    
end