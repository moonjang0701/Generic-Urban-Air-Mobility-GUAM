function [TSE_results] = compute_TSE(trajectory_data, path_coords, varargin)
% COMPUTE_TSE - Compute Total System Error for UAM procedure design
%
% Total System Error (TSE) = sqrt(FTE² + NSE²)
% where:
%   FTE = Flight Technical Error (control/tracking error)
%   NSE = Navigation System Error (GNSS/sensor error)
%
% This function computes TSE distribution using Monte Carlo simulation
% to determine required corridor width and protection areas
%
% Inputs:
%   trajectory_data - Structure containing GUAM trajectory (truth data)
%   path_coords - Path coordinate system from traj_to_path_coords()
%
% Optional Name-Value Pairs:
%   'N_MC' - Number of Monte Carlo samples (default: 100)
%   'FTE_Model' - FTE model type: 'measured', 'gaussian' (default: 'measured')
%   'NSE_Model' - NSE model type: 'RNP', 'gaussian' (default: 'RNP')
%   'RNP_Value' - RNP value in NM (default: 0.3 for UAM)
%   'NSE_Sigma' - NSE standard deviation in m (default: from RNP)
%   'FTE_Sigma' - FTE standard deviation in m (default: computed from data)
%   'Wind_Model' - Add wind/turbulence: 'none', 'mild', 'moderate' (default: 'none')
%
% Outputs:
%   TSE_results - Structure containing TSE analysis
%       .TSE_distribution - TSE values over time and MC samples
%       .statistics - Statistical summaries (mean, std, 95%, 99%)
%       .corridor_width - Recommended corridor dimensions
%       .FTE_component - FTE time series and statistics
%       .NSE_component - NSE time series and statistics
%
% References:
%   ICAO Doc 9613 - Performance-based Navigation (PBN) Manual
%   FAA Order 8260.58 - RNP Authorization Required (AR) Procedures
%
% Author: UAM Procedure R&D Team
% Date: 2024-11-24
% Version: 1.0

%% Parse Inputs
p = inputParser;
addRequired(p, 'trajectory_data');
addRequired(p, 'path_coords');
addParameter(p, 'N_MC', 100, @isnumeric);
addParameter(p, 'FTE_Model', 'measured', @ischar);
addParameter(p, 'NSE_Model', 'RNP', @ischar);
addParameter(p, 'RNP_Value', 0.3, @isnumeric);
addParameter(p, 'NSE_Sigma', [], @isnumeric);
addParameter(p, 'FTE_Sigma', [], @isnumeric);
addParameter(p, 'Wind_Model', 'none', @ischar);
parse(p, trajectory_data, path_coords, varargin{:});

N_MC = p.Results.N_MC;
FTE_model = p.Results.FTE_Model;
NSE_model = p.Results.NSE_Model;
RNP_value = p.Results.RNP_Value;
NSE_sigma = p.Results.NSE_Sigma;
FTE_sigma = p.Results.FTE_Sigma;
wind_model = p.Results.Wind_Model;

%% Constants
NM_TO_M = 1852;  % Nautical miles to meters

%% Extract Data
time = path_coords.time;
s = path_coords.s;  % Along-track
e = path_coords.e;  % Cross-track (this is our FTE measurement)
h = path_coords.h;  % Height error

% Ensure column vectors
time = time(:);
s = s(:);
e = e(:);
h = h(:);

n_points = length(time);

fprintf('\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  Computing Total System Error (TSE)\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

%% 1. Flight Technical Error (FTE) Component

fprintf('Computing FTE (Flight Technical Error)...\n');

switch lower(FTE_model)
    case 'measured'
        % Use measured cross-track error as FTE
        FTE_lateral = abs(e);
        FTE_vertical = abs(h);
        
        % Compute statistics
        FTE_lat_mean = mean(FTE_lateral);
        FTE_lat_std = std(FTE_lateral);
        
        if isempty(FTE_sigma)
            FTE_sigma = FTE_lat_std;
        end
        
        fprintf('  • Using measured tracking error\n');
        fprintf('  • Lateral FTE mean: %.2f m\n', FTE_lat_mean);
        fprintf('  • Lateral FTE std:  %.2f m\n', FTE_lat_std);
        
    case 'gaussian'
        % Model FTE as Gaussian noise
        if isempty(FTE_sigma)
            % Estimate from data
            FTE_sigma = std(e);
        end
        
        FTE_lateral = abs(e);
        FTE_vertical = abs(h);
        
        fprintf('  • Using Gaussian FTE model\n');
        fprintf('  • FTE sigma: %.2f m\n', FTE_sigma);
        
    otherwise
        error('Unknown FTE model: %s', FTE_model);
end

%% 2. Navigation System Error (NSE) Component

fprintf('\nComputing NSE (Navigation System Error)...\n');

switch lower(NSE_model)
    case 'rnp'
        % RNP-based NSE model
        % RNP value defines 95% containment (2σ)
        % So σ = RNP / 2
        
        if isempty(NSE_sigma)
            NSE_sigma = (RNP_value * NM_TO_M) / 2;
        end
        
        fprintf('  • Using RNP %.2f model\n', RNP_value);
        fprintf('  • NSE sigma: %.2f m (95%% = %.2f m)\n', NSE_sigma, 2*NSE_sigma);
        
    case 'gaussian'
        % Direct Gaussian specification
        if isempty(NSE_sigma)
            NSE_sigma = 50;  % Default 50m
        end
        
        fprintf('  • Using Gaussian NSE model\n');
        fprintf('  • NSE sigma: %.2f m\n', NSE_sigma);
        
    otherwise
        error('Unknown NSE model: %s', NSE_model);
end

%% 3. Wind/Turbulence Model (Optional)

wind_sigma = 0;
switch lower(wind_model)
    case 'mild'
        wind_sigma = 10;  % 10m additional uncertainty
        fprintf('\nAdding mild wind/turbulence (σ = %.1f m)\n', wind_sigma);
    case 'moderate'
        wind_sigma = 20;  % 20m additional uncertainty
        fprintf('\nAdding moderate wind/turbulence (σ = %.1f m)\n', wind_sigma);
    case 'none'
        % No wind
    otherwise
        warning('Unknown wind model: %s, using none', wind_model);
end

%% 4. Monte Carlo Simulation

fprintf('\nRunning Monte Carlo simulation (%d samples)...\n', N_MC);
fprintf('Progress: ');

% Preallocate
TSE_lateral_MC = zeros(n_points, N_MC);
TSE_vertical_MC = zeros(n_points, N_MC);
FTE_MC = zeros(n_points, N_MC);
NSE_MC = zeros(n_points, N_MC);

for mc = 1:N_MC
    if mod(mc, 20) == 0
        fprintf('%d ', mc);
    end
    
    % Generate NSE samples (Gaussian, independent for each time point)
    NSE_lat = NSE_sigma * randn(n_points, 1);
    NSE_vert = NSE_sigma * randn(n_points, 1);
    
    % FTE: Use measured + additional Gaussian variation
    FTE_lat = FTE_lateral + FTE_sigma * randn(n_points, 1) * 0.2;  % 20% additional variation
    FTE_vert = FTE_vertical + FTE_sigma * randn(n_points, 1) * 0.2;
    
    % Wind component (if enabled)
    if wind_sigma > 0
        wind_lat = wind_sigma * randn(n_points, 1);
        wind_vert = wind_sigma * randn(n_points, 1) * 0.5;  % Less vertical wind
    else
        wind_lat = zeros(n_points, 1);
        wind_vert = zeros(n_points, 1);
    end
    
    % Total System Error: TSE = sqrt(FTE² + NSE² + Wind²)
    TSE_lat = sqrt(FTE_lat.^2 + NSE_lat.^2 + wind_lat.^2);
    TSE_vert = sqrt(FTE_vert.^2 + NSE_vert.^2 + wind_vert.^2);
    
    % Store results
    TSE_lateral_MC(:, mc) = TSE_lat;
    TSE_vertical_MC(:, mc) = TSE_vert;
    FTE_MC(:, mc) = FTE_lat;
    NSE_MC(:, mc) = abs(NSE_lat);
end

fprintf('\n  ✓ Monte Carlo simulation complete\n');

%% 5. Compute Statistics

fprintf('\nComputing TSE statistics...\n');

% Lateral TSE statistics (across all time and MC samples)
TSE_lat_all = TSE_lateral_MC(:);
TSE_lat_mean = mean(TSE_lat_all);
TSE_lat_std = std(TSE_lat_all);
TSE_lat_95 = prctile(TSE_lat_all, 95);
TSE_lat_99 = prctile(TSE_lat_all, 99);
TSE_lat_max = max(TSE_lat_all);

% Vertical TSE statistics
TSE_vert_all = TSE_vertical_MC(:);
TSE_vert_mean = mean(TSE_vert_all);
TSE_vert_std = std(TSE_vert_all);
TSE_vert_95 = prctile(TSE_vert_all, 95);
TSE_vert_99 = prctile(TSE_vert_all, 99);
TSE_vert_max = max(TSE_vert_all);

% Time-averaged TSE (mean across MC at each time point)
TSE_lat_time_mean = mean(TSE_lateral_MC, 2);
TSE_lat_time_95 = prctile(TSE_lateral_MC, 95, 2);
TSE_lat_time_99 = prctile(TSE_lateral_MC, 99, 2);

TSE_vert_time_mean = mean(TSE_vertical_MC, 2);
TSE_vert_time_95 = prctile(TSE_vertical_MC, 95, 2);
TSE_vert_time_99 = prctile(TSE_vertical_MC, 99, 2);

% Component statistics
FTE_all = FTE_MC(:);
NSE_all = NSE_MC(:);

FTE_mean = mean(abs(FTE_all));
FTE_std = std(FTE_all);
FTE_95 = prctile(abs(FTE_all), 95);

NSE_mean = mean(NSE_all);
NSE_std = std(NSE_all);
NSE_95 = prctile(NSE_all, 95);

fprintf('  ✓ Statistics computed\n');

%% 6. Determine Corridor Width Requirements

fprintf('\nDetermining corridor width requirements...\n');

% Lateral corridor width (for 95% and 99% containment)
% Width = 2 * TSE (one-sided protection on each side)
corridor_width_95 = 2 * TSE_lat_95;
corridor_width_99 = 2 * TSE_lat_99;

% Vertical protection (altitude buffer)
vertical_buffer_95 = 2 * TSE_vert_95;
vertical_buffer_99 = 2 * TSE_vert_99;

% For curved segments, add turn splay
% (This would be computed in conjunction with turn analysis)
turn_splay_95 = TSE_lat_95 * 1.5;  % Heuristic: 50% increase in turns

fprintf('  • Corridor width (95%% containment): %.1f m\n', corridor_width_95);
fprintf('  • Corridor width (99%% containment): %.1f m\n', corridor_width_99);
fprintf('  • Vertical buffer (95%%): %.1f m\n', vertical_buffer_95);
fprintf('  • Turn splay (95%%): %.1f m\n', turn_splay_95);

%% 7. Package Results

TSE_results = struct();

% TSE distributions
TSE_results.lateral.distribution = TSE_lateral_MC;
TSE_results.lateral.time_mean = TSE_lat_time_mean;
TSE_results.lateral.time_95 = TSE_lat_time_95;
TSE_results.lateral.time_99 = TSE_lat_time_99;

TSE_results.vertical.distribution = TSE_vertical_MC;
TSE_results.vertical.time_mean = TSE_vert_time_mean;
TSE_results.vertical.time_95 = TSE_vert_time_95;
TSE_results.vertical.time_99 = TSE_vert_time_99;

% Overall statistics
TSE_results.statistics.lateral.mean = TSE_lat_mean;
TSE_results.statistics.lateral.std = TSE_lat_std;
TSE_results.statistics.lateral.percentile_95 = TSE_lat_95;
TSE_results.statistics.lateral.percentile_99 = TSE_lat_99;
TSE_results.statistics.lateral.max = TSE_lat_max;

TSE_results.statistics.vertical.mean = TSE_vert_mean;
TSE_results.statistics.vertical.std = TSE_vert_std;
TSE_results.statistics.vertical.percentile_95 = TSE_vert_95;
TSE_results.statistics.vertical.percentile_99 = TSE_vert_99;
TSE_results.statistics.vertical.max = TSE_vert_max;

% Component statistics
TSE_results.components.FTE.mean = FTE_mean;
TSE_results.components.FTE.std = FTE_std;
TSE_results.components.FTE.percentile_95 = FTE_95;
TSE_results.components.FTE.sigma = FTE_sigma;

TSE_results.components.NSE.mean = NSE_mean;
TSE_results.components.NSE.std = NSE_std;
TSE_results.components.NSE.percentile_95 = NSE_95;
TSE_results.components.NSE.sigma = NSE_sigma;

% Corridor requirements
TSE_results.corridor_width.width_95 = corridor_width_95;
TSE_results.corridor_width.width_99 = corridor_width_99;
TSE_results.corridor_width.vertical_buffer_95 = vertical_buffer_95;
TSE_results.corridor_width.vertical_buffer_99 = vertical_buffer_99;
TSE_results.corridor_width.turn_splay_95 = turn_splay_95;

% Recommended values (with safety factors)
safety_factor = 1.2;  % 20% safety margin
TSE_results.recommended.corridor_width = corridor_width_95 * safety_factor;
TSE_results.recommended.vertical_buffer = vertical_buffer_95 * safety_factor;
TSE_results.recommended.containment_level = 0.95;

% Metadata
TSE_results.metadata.N_MC = N_MC;
TSE_results.metadata.n_points = n_points;
TSE_results.metadata.FTE_model = FTE_model;
TSE_results.metadata.NSE_model = NSE_model;
TSE_results.metadata.RNP_value = RNP_value;
TSE_results.metadata.wind_model = wind_model;
TSE_results.metadata.time = time;
TSE_results.metadata.along_track = s;

fprintf('\n═══════════════════════════════════════════════════════════════\n');
fprintf('  TSE Computation Complete\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

fprintf('📊 SUMMARY:\n');
fprintf('   Lateral TSE (95%%):  %.1f m\n', TSE_lat_95);
fprintf('   Lateral TSE (99%%):  %.1f m\n', TSE_lat_99);
fprintf('   Vertical TSE (95%%): %.1f m\n', TSE_vert_95);
fprintf('\n');
fprintf('   FTE Contribution:   %.1f m (σ)\n', FTE_sigma);
fprintf('   NSE Contribution:   %.1f m (σ)\n', NSE_sigma);
fprintf('\n');
fprintf('✅ RECOMMENDED CORRIDOR WIDTH: %.1f m (with safety margin)\n\n', ...
    TSE_results.recommended.corridor_width);

end
