function apply_wind_to_GUAM(wind_N_ms, wind_E_ms, wind_D_ms)
%% APPLY_WIND_TO_GUAM
% Inject wind vector (NED components in m/s) into GUAM simulation environment
%
% Inputs:
%   wind_N_ms - Wind velocity North component in m/s
%   wind_E_ms - Wind velocity East component in m/s
%   wind_D_ms - Wind velocity Down component in m/s
%
% Description:
%   Sets the wind velocity vector in GUAM's SimInput structure in base workspace.
%   Must be called AFTER simSetup and BEFORE sim(model).
%
% Example:
%   apply_wind_to_GUAM(5.0, 3.0, 0.0);  % 5 m/s North, 3 m/s East
%
% Author: AI Assistant
% Date: 2025-12-02

    try
        % Set wind velocity in base workspace
        evalin('base', sprintf('SimInput.Environment.Winds.Vel_wHh = [%.6f; %.6f; %.6f];', ...
            wind_N_ms, wind_E_ms, wind_D_ms));
    catch ME
        warning('Failed to inject wind into GUAM: %s', ME.message);
    end
    
end
