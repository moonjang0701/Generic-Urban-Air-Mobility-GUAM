function [MC_params] = sample_MC_inputs(N_samples, wind_max_kt, ...\n                                        sigma_y0_m, sigma_heading0_deg, ...\n                                        sigma_tau_s, ctrl_gain_var, ...\n                                        nse_sigma_base_m, nse_sigma_var)
%% SAMPLE_MC_INPUTS
% Generate Monte Carlo parameter samples for uncertainty propagation
%
% Inputs:
%   N_samples          - Number of Monte Carlo samples
%   wind_max_kt        - Maximum wind speed (knots) - uniformly distributed 0 to max
%   sigma_y0_m         - Initial lateral offset std dev (m)
%   sigma_heading0_deg - Initial heading error std dev (degrees)
%   sigma_tau_s        - Response time std dev (seconds)
%   ctrl_gain_var      - Controller gain variation (fraction, e.g., 0.1 for ±10%)
%   nse_sigma_base_m   - Base navigation system error (m)
%   nse_sigma_var      - NSE variation factor (fraction)
%
% Outputs:
%   MC_params - Structure containing N_samples of each parameter:
%               .wind_E_ms       - East wind component (m/s), N×1
%               .wind_N_ms       - North wind component (m/s), N×1
%               .wind_D_ms       - Down wind component (m/s), N×1
%               .wind_speed_ms   - Wind speed magnitude (m/s), N×1
%               .wind_dir_deg    - Wind direction (degrees), N×1
%               .y0_m            - Initial lateral offset (m), N×1
%               .heading_err_deg - Initial heading error (degrees), N×1
%               .tau_s           - Response time (s), N×1
%               .gain_factor     - Controller gain multiplier, N×1
%               .nse_sigma_m     - Navigation error std dev (m), N×1
%
% Description:
%   Samples uncertainty parameters from appropriate probability distributions:
%   - Wind: UNIFORM magnitude 0-max_kt, UNIFORM direction 0-360°
%   - Initial states: Gaussian, zero-mean
%   - Controller params: Gaussian or uniform
%   - NSE: Scaled Gaussian
%
% Example:
%   params = sample_MC_inputs(500, 20, 10, 2, 0.2, 0.1, 5, 0.3);
%
% Author: AI Assistant
% Date: 2025-01-20

    %% Preallocate output structure
    MC_params = struct();
    MC_params.wind_E_ms = zeros(N_samples, 1);
    MC_params.wind_N_ms = zeros(N_samples, 1);
    MC_params.wind_D_ms = zeros(N_samples, 1);
    MC_params.wind_speed_ms = zeros(N_samples, 1);
    MC_params.wind_dir_deg = zeros(N_samples, 1);
    MC_params.y0_m = zeros(N_samples, 1);
    MC_params.heading_err_deg = zeros(N_samples, 1);
    MC_params.tau_s = zeros(N_samples, 1);
    MC_params.gain_factor = zeros(N_samples, 1);
    MC_params.nse_sigma_m = zeros(N_samples, 1);
    
    %% Convert wind parameters
    wind_max_ms = wind_max_kt * 0.514444;    % knots to m/s
    
    %% Sample wind components - RANDOM DIRECTION, RANDOM MAGNITUDE
    % Wind can come from ANY direction (0-360 degrees)
    % Wind speed is uniformly distributed from 0 to max
    
    for idx = 1:N_samples
        % Random wind speed: uniform distribution [0, max]
        wind_speed = wind_max_ms * rand();  % 0 to wind_max_ms
        
        % Random wind direction: uniform distribution [0, 360) degrees
        % Direction is "coming from" (meteorological convention)
        wind_dir_deg = 360 * rand();  % 0 to 360 degrees
        wind_dir_rad = deg2rad(wind_dir_deg);
        
        % Convert to NED components
        % Wind "from" North (0°) means blowing towards South (negative North component)
        % Wind "from" East (90°) means blowing towards West (negative East component)
        MC_params.wind_N_ms(idx) = -wind_speed * cos(wind_dir_rad);  % North component
        MC_params.wind_E_ms(idx) = -wind_speed * sin(wind_dir_rad);  % East component
        MC_params.wind_D_ms(idx) = 0;  % No vertical wind for simplicity
        
        % Store magnitude and direction for reference
        MC_params.wind_speed_ms(idx) = wind_speed;
        MC_params.wind_dir_deg(idx) = wind_dir_deg;
    end
    
    %% Sample initial state errors
    % Initial lateral offset - Gaussian, zero mean
    MC_params.y0_m = sigma_y0_m * randn(N_samples, 1);
    
    % Initial heading error - Gaussian, zero mean
    MC_params.heading_err_deg = sigma_heading0_deg * randn(N_samples, 1);
    
    %% Sample controller parameters
    % Response time - Gaussian
    MC_params.tau_s = sigma_tau_s * randn(N_samples, 1);
    
    % Controller gain variation - uniform ±variation
    MC_params.gain_factor = 1 + ctrl_gain_var * (2*rand(N_samples, 1) - 1);
    
    %% Sample navigation sensor error
    % NSE with variation - base ± variation
    MC_params.nse_sigma_m = nse_sigma_base_m * (1 + nse_sigma_var * randn(N_samples, 1));
    
    % Ensure positive values
    MC_params.nse_sigma_m = max(MC_params.nse_sigma_m, 0.1);  % Minimum 0.1m
    MC_params.gain_factor = max(MC_params.gain_factor, 0.5);  % Minimum 50% gain
    
    %% Print statistics
    fprintf('  Wind samples generated:\n');
    fprintf('    Speed range: %.2f to %.2f m/s (%.1f to %.1f kt)\n', ...
            min(MC_params.wind_speed_ms), max(MC_params.wind_speed_ms), ...
            min(MC_params.wind_speed_ms)/0.514444, max(MC_params.wind_speed_ms)/0.514444);
    fprintf('    Direction range: %.1f to %.1f deg\n', ...
            min(MC_params.wind_dir_deg), max(MC_params.wind_dir_deg));
    fprintf('    North component: %.2f to %.2f m/s\n', ...
            min(MC_params.wind_N_ms), max(MC_params.wind_N_ms));
    fprintf('    East component: %.2f to %.2f m/s\n', ...
            min(MC_params.wind_E_ms), max(MC_params.wind_E_ms));
    
end
