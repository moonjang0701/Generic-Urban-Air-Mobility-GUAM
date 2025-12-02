function SimIn = apply_turbulence_to_GUAM(SimIn, intensity_str)
%% APPLY_TURBULENCE_TO_GUAM
% Enable and configure turbulence in GUAM simulation
%
% Inputs:
%   SimIn - GUAM SimIn structure
%   intensity_str - String, turbulence intensity level
%                   'light'    - Calm to light turbulence
%                   'moderate' - Moderate turbulence
%                   'severe'   - Severe turbulence
%
% Outputs:
%   SimIn - Updated SimIn structure with turbulence configured
%
% Description:
%   Configures GUAM's built-in turbulence model (Dryden-type).
%   Turbulence is added to the simulation environment and affects
%   aircraft dynamics through aerodynamic forces.
%
% Usage:
%   SimIn = apply_turbulence_to_GUAM(SimIn, 'light');
%   SimIn = apply_turbulence_to_GUAM(SimIn, 'moderate');
%
% Author: AI Assistant
% Date: 2025-12-02

    % Enable turbulence
    try
        SimIn.turbType = TurbulenceEnum.Enabled;
    catch
        % If enum not available, use numeric value (1 = Enabled)
        SimIn.turbType = 1;
    end
    
    % Set turbulence intensity
    % WindAt5kft parameter controls turbulence intensity
    % Based on MIL-F-8785C turbulence specifications
    switch lower(intensity_str)
        case 'light'
            wind_at_5kft = 15;  % m/s (light turbulence)
        case 'moderate'
            wind_at_5kft = 30;  % m/s (moderate turbulence)
        case 'severe'
            wind_at_5kft = 50;  % m/s (severe turbulence)
        otherwise
            warning('Unknown turbulence intensity "%s", using Light', intensity_str);
            wind_at_5kft = 15;  % default: light
    end
    
    % Apply to SimIn structure
    if ~isfield(SimIn, 'Environment')
        SimIn.Environment = struct();
    end
    if ~isfield(SimIn.Environment, 'Turbulence')
        SimIn.Environment.Turbulence = struct();
    end
    
    SimIn.Environment.Turbulence.WindAt5kft = wind_at_5kft;
    
    % Set random seeds for this run (use current time for randomness)
    rng_state = rng;
    base_seed = rng_state.Seed;
    seeds = base_seed + [0, 1, 2, 3];  % Offset for each component
    SimIn.Environment.Turbulence.RandomSeeds = seeds;
    
end
