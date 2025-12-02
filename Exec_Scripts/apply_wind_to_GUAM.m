function SimIn = apply_wind_to_GUAM(SimIn, wind_speed_kt, wind_dir_deg)
%% APPLY_WIND_TO_GUAM
% Inject wind vector into GUAM simulation environment
%
% Inputs:
%   SimIn - GUAM SimIn structure
%   wind_speed_kt - Wind speed in knots
%   wind_dir_deg - Wind direction in degrees (0=North, 90=East, meteorological convention)
%
% Outputs:
%   SimIn - Updated SimIn structure with wind applied
%
% Description:
%   Sets the wind velocity vector in GUAM's SimIn structure.
%   Must be called AFTER simSetup and BEFORE sim(model).
%
% Example:
%   SimIn = apply_wind_to_GUAM(SimIn, 20, 90);  % 20 kt wind from East
%
% Author: AI Assistant
% Date: 2025-12-02

    % Convert knots to m/s
    wind_speed_ms = wind_speed_kt * 0.514444;
    
    % Convert meteorological wind direction to NED components
    % Meteorological: direction wind is coming FROM
    % NED: positive North, positive East
    wind_from_rad = deg2rad(wind_dir_deg);
    
    % Wind velocity components (NED frame)
    % Wind blows FROM direction, so negate
    wind_N = -wind_speed_ms * cos(wind_from_rad);
    wind_E = -wind_speed_ms * sin(wind_from_rad);
    wind_D = 0;  % No vertical wind component
    
    % Inject into SimIn structure
    try
        if isfield(SimIn, 'Environment') && isfield(SimIn.Environment, 'Winds')
            SimIn.Environment.Winds.Vel_wHh = [wind_N; wind_E; wind_D];
        else
            % Initialize if doesn't exist
            SimIn.Environment.Winds.Vel_wHh = [wind_N; wind_E; wind_D];
        end
    catch ME
        warning('Failed to inject wind: %s', ME.message);
    end
    
end