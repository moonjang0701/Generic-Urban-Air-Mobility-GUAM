function apply_turbulence_to_GUAM(enable, intensity, random_seed)
%% APPLY_TURBULENCE_TO_GUAM
% Enable/disable and configure turbulence in GUAM simulation
%
% Inputs:
%   enable - Boolean, true to enable turbulence, false to disable
%   intensity - String: 'Light', 'Moderate', 'Severe' (or empty if disabled)
%   random_seed - Integer for reproducibility (or empty if disabled)
%
% Description:
%   Configures Dryden turbulence model in GUAM's SimInput structure.
%   Must be called AFTER simSetup and BEFORE sim(model).
%
% Turbulence Intensity Mapping:
%   'Light': WindAt5kft = 15 m/s
%   'Moderate': WindAt5kft = 30 m/s
%   'Severe': WindAt5kft = 50 m/s
%
% Example:
%   apply_turbulence_to_GUAM(true, 'Moderate', 12345);
%   apply_turbulence_to_GUAM(false, '', []);
%
% Author: AI Assistant
% Date: 2025-12-02

    if ~enable
        % Disable turbulence
        try
            evalin('base', 'SimIn.turbType = 0;');  % 0 = No turbulence
        catch
            warning('Failed to disable turbulence in GUAM');
        end
        return;
    end
    
    % Enable turbulence
    try
        evalin('base', 'SimIn.turbType = 1;');  % 1 = Dryden turbulence
        
        % Map intensity to WindAt5kft value
        switch intensity
            case 'Light'
                wind_at_5kft = 15;
            case 'Moderate'
                wind_at_5kft = 30;
            case 'Severe'
                wind_at_5kft = 50;
            otherwise
                wind_at_5kft = 15;  % Default to Light
                warning('Unknown turbulence intensity "%s", defaulting to Light', intensity);
        end
        
        evalin('base', sprintf('SimInput.Environment.Turbulence.WindAt5kft = %.1f;', wind_at_5kft));
        
        % Set random seeds for reproducibility (4 seeds required)
        if ~isempty(random_seed)
            seed1 = random_seed;
            seed2 = random_seed + 1000;
            seed3 = random_seed + 2000;
            seed4 = random_seed + 3000;
            evalin('base', sprintf('SimInput.Environment.Turbulence.RandomSeeds = [%d, %d, %d, %d];', ...
                seed1, seed2, seed3, seed4));
        end
        
    catch ME
        warning('Failed to configure turbulence in GUAM: %s', ME.message);
    end
    
end
