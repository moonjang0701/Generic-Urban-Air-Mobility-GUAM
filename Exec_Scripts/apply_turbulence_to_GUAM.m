function apply_turbulence_to_GUAM(enable, intensity, random_seed)
%% APPLY_TURBULENCE_TO_GUAM
% Enable/disable and configure turbulence in GUAM simulation
%
% Inputs:
%   enable      - Boolean, true to enable turbulence, false to disable
%   intensity   - String, turbulence intensity level
%                 'Light'    - Calm to light turbulence
%                 'Moderate' - Moderate turbulence
%                 'Severe'   - Severe turbulence
%   random_seed - Integer, random seed for reproducibility (optional)
%
% Description:
%   Configures GUAM's built-in turbulence model (Dryden-type).
%   Turbulence is added to the simulation environment and affects
%   aircraft dynamics through aerodynamic forces.
%
% Usage:
%   % Enable light turbulence
%   apply_turbulence_to_GUAM(true, 'Light', 12345);
%
%   % Disable turbulence
%   apply_turbulence_to_GUAM(false, '', []);
%
% Author: AI Assistant
% Date: 2025-01-20

    if enable
        %% Enable turbulence
        evalin('base', 'SimIn.turbType = TurbulenceEnum.Enabled;');
        
        %% Set turbulence intensity
        % WindAt5kft parameter controls turbulence intensity
        % Based on MIL-F-8785C turbulence specifications
        switch lower(intensity)
            case 'light'
                wind_at_5kft = 15;  % m/s (light turbulence)
            case 'moderate'
                wind_at_5kft = 30;  % m/s (moderate turbulence)
            case 'severe'
                wind_at_5kft = 50;  % m/s (severe turbulence)
            otherwise
                warning('Unknown turbulence intensity "%s", using Light', intensity);
                wind_at_5kft = 15;  % default: light
        end
        
        evalin('base', sprintf('SimInput.Environment.Turbulence.WindAt5kft = %.1f;', wind_at_5kft));
        
        %% Set random seeds for reproducibility
        % GUAM uses 4 random seeds: [u_turb, v_turb, w_turb, p_gust]
        if nargin >= 3 && ~isempty(random_seed)
            seeds = random_seed + [0, 1, 2, 3];  % Offset for each component
            evalin('base', sprintf('SimInput.Environment.Turbulence.RandomSeeds = [%d, %d, %d, %d];', ...
                   seeds(1), seeds(2), seeds(3), seeds(4)));
        end
        
        fprintf('  Turbulence: ENABLED (%s, %.0f m/s at 5kft)\n', intensity, wind_at_5kft);
        
    else
        %% Disable turbulence
        evalin('base', 'SimIn.turbType = TurbulenceEnum.None;');
        fprintf('  Turbulence: DISABLED\n');
    end
end
