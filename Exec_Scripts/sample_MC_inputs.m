function [MC_params] = sample_MC_inputs(N_samples, wind_mean_kt, wind_sigma_kt, ...
                                        sigma_y0_m, sigma_heading0_deg, ...
                                        sigma_tau_s, ctrl_gain_var, ...
                                        nse_sigma_base_m, nse_sigma_var)
%% SAMPLE_MC_INPUTS
% Generate Monte Carlo parameter samples for uncertainty propagation
%
% Inputs:
%   N_samples          - Number of Monte Carlo samples
%   wind_mean_kt       - Mean crosswind speed (knots)
%   wind_sigma_kt      - Crosswind standard deviation (knots)
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
%               .y0_m            - Initial lateral offset (m), N×1
%               .heading_err_deg - Initial heading error (degrees), N×1
%               .tau_s           - Response time (s), N×1
%               .gain_factor     - Controller gain multiplier, N×1
%               .nse_sigma_m     - Navigation error std dev (m), N×1
%
% Description:
%   Samples uncertainty parameters from appropriate probability distributions:
%   - Wind: Gaussian with specified mean and std dev (perpendicular to track)
%   - Initial states: Gaussian, zero-mean
%   - Controller params: Gaussian or uniform
%   - NSE: Scaled Gaussian
%
% Example:
%   params = sample_MC_inputs(500, 20, 5, 10, 2, 0.2, 0.1, 5, 0.3);
%
% Author: AI Assistant
% Date: 2025-01-18

    %% Preallocate output structure
    MC_params = struct();
    MC_params.wind_E_ms = zeros(N_samples, 1);
    MC_params.wind_N_ms = zeros(N_samples, 1);
    MC_params.wind_D_ms = zeros(N_samples, 1);
    MC_params.y0_m = zeros(N_samples, 1);
    MC_params.heading_err_deg = zeros(N_samples, 1);
    MC_params.tau_s = zeros(N_samples, 1);
    MC_params.gain_factor = zeros(N_samples, 1);
    MC_params.nse_sigma_m = zeros(N_samples, 1);
    
    %% Convert wind parameters
    wind_mean_ms = wind_mean_kt * 0.514444;    % knots to m/s
    wind_sigma_ms = wind_sigma_kt * 0.514444;
    
    %% Sample wind components
    % Crosswind is perpendicular to track (North direction)
    % For North heading, crosswind affects East component
    
    for i = 1:N_samples
        % Crosswind (East component) - Gaussian
        MC_params.wind_E_ms(i) = wind_mean_ms + wind_sigma_ms * randn();
        
        % Along-track wind (North component) - small random perturbation
        MC_params.wind_N_ms(i) = wind_sigma_ms * 0.2 * randn();
        
        % Vertical wind (Down component) - small random perturbation
        MC_params.wind_D_ms(i) = wind_sigma_ms * 0.1 * randn();
    end
    
    %% Sample initial state errors
    % Initial lateral offset - Gaussian, zero mean
    MC_params.y0_m = sigma_y0_m * randn(N_samples, 1);
    
    % Initial heading error - Gaussian, zero mean
    MC_params.heading_err_deg = sigma_heading0_deg * randn(N_samples, 1);
    
    %% Sample controller parameters
    % Response time - Gaussian (truncated to positive values)
    tau_base = 5.0;  % Nominal response time (seconds)
    for i = 1:N_samples
        tau_sample = tau_base + sigma_tau_s * randn();
        % Ensure positive and reasonable
        MC_params.tau_s(i) = max(0.5, min(10, tau_sample));
    end
    
    % Controller gain variation - Gaussian around 1.0
    % Factor of 1.0 = nominal, 1.1 = +10%, 0.9 = -10%
    for i = 1:N_samples
        gain_sample = 1.0 + ctrl_gain_var * randn();
        % Ensure reasonable range
        MC_params.gain_factor(i) = max(0.5, min(1.5, gain_sample));
    end
    
    %% Sample navigation sensor error (NSE)
    % NSE varies per run to model sensor uncertainty
    for i = 1:N_samples
        nse_factor = 1.0 + nse_sigma_var * randn();
        % Ensure positive
        nse_factor = max(0.3, min(2.0, nse_factor));
        MC_params.nse_sigma_m(i) = nse_sigma_base_m * nse_factor;
    end
    
    %% Add metadata
    MC_params.N_samples = N_samples;
    MC_params.wind_mean_ms = wind_mean_ms;
    MC_params.wind_sigma_ms = wind_sigma_ms;
    MC_params.sigma_y0_m = sigma_y0_m;
    MC_params.sigma_heading0_deg = sigma_heading0_deg;
    MC_params.nse_sigma_base_m = nse_sigma_base_m;
    
end
