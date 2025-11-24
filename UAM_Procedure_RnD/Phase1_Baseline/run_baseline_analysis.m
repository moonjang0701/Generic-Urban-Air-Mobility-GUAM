% RUN_BASELINE_ANALYSIS - Phase 1: Baseline Performance Analysis
%
% This script analyzes normal (no-failure) scenarios from GUAM Challenge
% Problems to establish baseline UAM procedure design criteria
%
% Analysis includes:
%   1. Climb/descent angle statistics
%   2. Turn radius and bank angle requirements
%   3. Corridor width requirements (without TSE)
%   4. Performance limitations
%
% Outputs:
%   - Baseline performance statistics
%   - Recommended procedure design parameters
%   - Visualization plots
%
% Author: UAM Procedure R&D Team
% Date: 2024-11-24
% Version: 1.0

clear; clc; close all;

%% Setup Paths
% Add necessary paths
addpath(genpath('../Utils'));
addpath(genpath('../../Challenge_Problems'));
addpath(genpath('../../'));

fprintf('\n');
fprintf('╔═══════════════════════════════════════════════════════════════╗\n');
fprintf('║                                                               ║\n');
fprintf('║   UAM PROCEDURE R&D - PHASE 1: BASELINE ANALYSIS             ║\n');
fprintf('║   Establishing Normal Operation Performance Criteria         ║\n');
fprintf('║                                                               ║\n');
fprintf('╚═══════════════════════════════════════════════════════════════╝\n');
fprintf('\n');

%% Configuration
config = struct();
config.challenge_data_path = '../../Challenge_Problems';
config.results_path = '../Results';
config.n_scenarios_to_analyze = 50;  % Analyze first 50 normal scenarios
config.save_results = true;
config.generate_plots = true;

%% Step 1: Load or Create Scenario Catalog
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  Step 1: Loading Scenario Catalog\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

catalog_file = fullfile(config.results_path, 'Data', 'scenario_catalog.mat');

if exist(catalog_file, 'file')
    fprintf('Loading existing scenario catalog...\n');
    load(catalog_file, 'scenario_catalog');
    fprintf('  ✓ Catalog loaded (%d scenarios)\n\n', scenario_catalog.metadata.n_runs);
else
    fprintf('Scenario catalog not found. Please run Phase 0 first.\n');
    fprintf('Creating catalog now...\n\n');
    
    % Create results directory if needed
    if ~exist(fullfile(config.results_path, 'Data'), 'dir')
        mkdir(fullfile(config.results_path, 'Data'));
    end
    
    % Run scenario classifier
    cd('../Phase0_Setup');
    scenario_catalog = scenario_classifier(config.challenge_data_path);
    cd('../Phase1_Baseline');
    
    % Save catalog
    save(catalog_file, 'scenario_catalog');
    fprintf('  ✓ Catalog created and saved\n\n');
end

%% Step 2: Select Normal (No-Failure) Scenarios
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  Step 2: Selecting Normal Operation Scenarios\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

% Find scenarios without failures
normal_idx = find([scenario_catalog.runs.has_failure] == false);
n_normal = length(normal_idx);

fprintf('Found %d normal (no-failure) scenarios\n', n_normal);

% Select subset for detailed analysis
if n_normal > config.n_scenarios_to_analyze
    % Stratified sampling: get mix of trajectory types
    selected_scenarios = select_stratified_sample(scenario_catalog, normal_idx, ...
        config.n_scenarios_to_analyze);
else
    selected_scenarios = normal_idx;
end

fprintf('Selected %d scenarios for detailed analysis\n', length(selected_scenarios));
fprintf('  • Approach style:  %d\n', sum(strcmp({scenario_catalog.runs(selected_scenarios).procedure_style}, 'approach')));
fprintf('  • Departure style: %d\n', sum(strcmp({scenario_catalog.runs(selected_scenarios).procedure_style}, 'departure')));
fprintf('  • En-route style:  %d\n\n', sum(strcmp({scenario_catalog.runs(selected_scenarios).procedure_style}, 'enroute')));

%% Step 3: Run GUAM Simulations and Analyze
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  Step 3: Running GUAM Simulations\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

fprintf('Note: This step requires MATLAB/Simulink and may take time.\n');
fprintf('For demonstration, we will analyze catalog data.\n\n');

% Initialize results structure
baseline_results = struct();
baseline_results.config = config;
baseline_results.scenarios = selected_scenarios;
baseline_results.n_analyzed = length(selected_scenarios);

% Preallocate arrays for aggregate statistics
all_climb_angles = [];
all_descent_angles = [];
all_bank_angles = [];
all_turn_radii = [];
all_lateral_deviations = [];
all_vertical_deviations = [];

%% Step 4: Analyze Each Scenario (Using Catalog Data)
fprintf('Analyzing scenario characteristics...\n');
fprintf('Progress: ');

for i = 1:length(selected_scenarios)
    if mod(i, 10) == 0
        fprintf('%d/%d ', i, length(selected_scenarios));
    end
    
    run_id = selected_scenarios(i);
    run = scenario_catalog.runs(run_id);
    
    % Extract performance metrics from catalog
    if ~strcmp(run.trajectory_type, 'unknown')
        % Climb/descent angles
        if run.max_climb_angle > 0
            all_climb_angles = [all_climb_angles; run.max_climb_angle];
        end
        if run.max_descent_angle > 0
            all_descent_angles = [all_descent_angles; run.max_descent_angle];
        end
        
        % Bank angle
        if run.max_bank_angle > 0 && run.max_bank_angle < 90
            all_bank_angles = [all_bank_angles; run.max_bank_angle];
        end
        
        % Turn radius
        if isfinite(run.min_turn_radius) && run.min_turn_radius > 0
            all_turn_radii = [all_turn_radii; run.min_turn_radius];
        end
    end
end

fprintf('\n  ✓ Analysis complete\n\n');

%% Step 5: Compute Aggregate Statistics
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  Step 5: Computing Baseline Statistics\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

% Climb angle statistics
if ~isempty(all_climb_angles)
    stats.climb_angle.mean = mean(all_climb_angles);
    stats.climb_angle.std = std(all_climb_angles);
    stats.climb_angle.max = max(all_climb_angles);
    stats.climb_angle.percentile_95 = prctile(all_climb_angles, 95);
    stats.climb_angle.percentile_99 = prctile(all_climb_angles, 99);
    stats.climb_angle.n_samples = length(all_climb_angles);
else
    stats.climb_angle = struct('mean', 0, 'std', 0, 'max', 0, ...
        'percentile_95', 0, 'percentile_99', 0, 'n_samples', 0);
end

% Descent angle statistics
if ~isempty(all_descent_angles)
    stats.descent_angle.mean = mean(all_descent_angles);
    stats.descent_angle.std = std(all_descent_angles);
    stats.descent_angle.max = max(all_descent_angles);
    stats.descent_angle.percentile_95 = prctile(all_descent_angles, 95);
    stats.descent_angle.percentile_99 = prctile(all_descent_angles, 99);
    stats.descent_angle.n_samples = length(all_descent_angles);
else
    stats.descent_angle = struct('mean', 0, 'std', 0, 'max', 0, ...
        'percentile_95', 0, 'percentile_99', 0, 'n_samples', 0);
end

% Bank angle statistics
if ~isempty(all_bank_angles)
    stats.bank_angle.mean = mean(all_bank_angles);
    stats.bank_angle.std = std(all_bank_angles);
    stats.bank_angle.max = max(all_bank_angles);
    stats.bank_angle.percentile_95 = prctile(all_bank_angles, 95);
    stats.bank_angle.percentile_99 = prctile(all_bank_angles, 99);
    stats.bank_angle.n_samples = length(all_bank_angles);
else
    stats.bank_angle = struct('mean', 0, 'std', 0, 'max', 0, ...
        'percentile_95', 0, 'percentile_99', 0, 'n_samples', 0);
end

% Turn radius statistics
if ~isempty(all_turn_radii)
    stats.turn_radius.mean = mean(all_turn_radii);
    stats.turn_radius.std = std(all_turn_radii);
    stats.turn_radius.min = min(all_turn_radii);
    stats.turn_radius.percentile_05 = prctile(all_turn_radii, 5);
    stats.turn_radius.percentile_10 = prctile(all_turn_radii, 10);
    stats.turn_radius.n_samples = length(all_turn_radii);
else
    stats.turn_radius = struct('mean', 0, 'std', 0, 'min', 0, ...
        'percentile_05', 0, 'percentile_10', 0, 'n_samples', 0);
end

baseline_results.statistics = stats;

%% Step 6: Derive Baseline Design Criteria
fprintf('Deriving baseline design criteria...\n\n');

criteria = struct();

% Climb/descent angle criteria
criteria.climb_angle.recommended_max = ceil(stats.climb_angle.percentile_95);
criteria.climb_angle.absolute_max = ceil(stats.climb_angle.max);
criteria.climb_angle.rationale = 'Based on 95th percentile of observed performance';

criteria.descent_angle.recommended_max = ceil(stats.descent_angle.percentile_95);
criteria.descent_angle.absolute_max = ceil(stats.descent_angle.max);
criteria.descent_angle.rationale = 'Based on 95th percentile of observed performance';

% Bank angle criteria
criteria.bank_angle.recommended_max = min(30, ceil(stats.bank_angle.percentile_95 / 5) * 5);
criteria.bank_angle.absolute_max = min(35, ceil(stats.bank_angle.max / 5) * 5);
criteria.bank_angle.rationale = 'Rounded to nearest 5 degrees, capped at 30° for comfort';

% Turn radius criteria
if stats.turn_radius.min > 0
    criteria.turn_radius.minimum = floor(stats.turn_radius.percentile_05 / 50) * 50;
    criteria.turn_radius.recommended = floor(stats.turn_radius.percentile_10 / 50) * 50;
    criteria.turn_radius.rationale = 'Based on 5th percentile, rounded down for safety';
else
    criteria.turn_radius.minimum = 300;
    criteria.turn_radius.recommended = 500;
    criteria.turn_radius.rationale = 'Default values (insufficient data)';
end

% Corridor width (preliminary, without TSE)
criteria.corridor_width.straight = 100;  % meters (placeholder)
criteria.corridor_width.turn = 150;  % meters (placeholder)
criteria.corridor_width.rationale = 'Preliminary values, will be refined with TSE analysis';

baseline_results.criteria = criteria;

%% Step 7: Display Results
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  BASELINE DESIGN CRITERIA (Normal Operations)\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

fprintf('📐 CLIMB ANGLE CRITERIA:\n');
fprintf('   Recommended Maximum:  %d° (95th percentile)\n', criteria.climb_angle.recommended_max);
fprintf('   Absolute Maximum:     %d° (observed max)\n', criteria.climb_angle.absolute_max);
fprintf('   Mean:                 %.1f°\n', stats.climb_angle.mean);
fprintf('   Samples analyzed:     %d\n\n', stats.climb_angle.n_samples);

fprintf('📉 DESCENT ANGLE CRITERIA:\n');
fprintf('   Recommended Maximum:  %d° (95th percentile)\n', criteria.descent_angle.recommended_max);
fprintf('   Absolute Maximum:     %d° (observed max)\n', criteria.descent_angle.absolute_max);
fprintf('   Mean:                 %.1f°\n', stats.descent_angle.mean);
fprintf('   Samples analyzed:     %d\n\n', stats.descent_angle.n_samples);

fprintf('🔄 BANK ANGLE CRITERIA:\n');
fprintf('   Recommended Maximum:  %d° (95th percentile, comfort limit)\n', criteria.bank_angle.recommended_max);
fprintf('   Absolute Maximum:     %d° (capability limit)\n', criteria.bank_angle.absolute_max);
fprintf('   Mean:                 %.1f°\n', stats.bank_angle.mean);
fprintf('   Samples analyzed:     %d\n\n', stats.bank_angle.n_samples);

fprintf('⭕ TURN RADIUS CRITERIA:\n');
fprintf('   Minimum Required:     %d m (5th percentile)\n', criteria.turn_radius.minimum);
fprintf('   Recommended Minimum:  %d m (10th percentile)\n', criteria.turn_radius.recommended);
fprintf('   Mean:                 %.1f m\n', stats.turn_radius.mean);
fprintf('   Samples analyzed:     %d\n\n', stats.turn_radius.n_samples);

fprintf('═══════════════════════════════════════════════════════════════\n\n');

%% Step 8: Generate Plots
if config.generate_plots
    fprintf('Generating visualization plots...\n');
    
    % Create figures directory
    fig_dir = fullfile(config.results_path, 'Figures', 'Phase1_Baseline');
    if ~exist(fig_dir, 'dir')
        mkdir(fig_dir);
    end
    
    % Plot 1: Flight Angle Distributions
    if ~isempty(all_climb_angles) || ~isempty(all_descent_angles)
        fig1 = figure('Position', [100, 100, 1200, 400]);
        
        subplot(1, 3, 1);
        if ~isempty(all_climb_angles)
            histogram(all_climb_angles, 20, 'FaceColor', [0.2 0.6 0.9]);
            hold on;
            xline(stats.climb_angle.mean, 'r--', 'LineWidth', 2, 'DisplayName', 'Mean');
            xline(stats.climb_angle.percentile_95, 'r-', 'LineWidth', 2, 'DisplayName', '95%');
            legend('Location', 'best');
        end
        xlabel('Climb Angle (deg)');
        ylabel('Count');
        title('Climb Angle Distribution');
        grid on;
        
        subplot(1, 3, 2);
        if ~isempty(all_descent_angles)
            histogram(all_descent_angles, 20, 'FaceColor', [0.9 0.4 0.2]);
            hold on;
            xline(stats.descent_angle.mean, 'r--', 'LineWidth', 2, 'DisplayName', 'Mean');
            xline(stats.descent_angle.percentile_95, 'r-', 'LineWidth', 2, 'DisplayName', '95%');
            legend('Location', 'best');
        end
        xlabel('Descent Angle (deg)');
        ylabel('Count');
        title('Descent Angle Distribution');
        grid on;
        
        subplot(1, 3, 3);
        if ~isempty(all_bank_angles)
            histogram(all_bank_angles, 20, 'FaceColor', [0.4 0.8 0.4]);
            hold on;
            xline(stats.bank_angle.mean, 'r--', 'LineWidth', 2, 'DisplayName', 'Mean');
            xline(stats.bank_angle.percentile_95, 'r-', 'LineWidth', 2, 'DisplayName', '95%');
            legend('Location', 'best');
        end
        xlabel('Bank Angle (deg)');
        ylabel('Count');
        title('Bank Angle Distribution');
        grid on;
        
        sgtitle('UAM Baseline Flight Angle Distributions', 'FontSize', 14, 'FontWeight', 'bold');
        
        saveas(fig1, fullfile(fig_dir, 'flight_angle_distributions.png'));
    end
    
    % Plot 2: Turn Radius Distribution
    if ~isempty(all_turn_radii)
        fig2 = figure('Position', [100, 100, 800, 500]);
        
        histogram(all_turn_radii, 30, 'FaceColor', [0.7 0.3 0.8]);
        hold on;
        xline(stats.turn_radius.mean, 'r--', 'LineWidth', 2, 'DisplayName', 'Mean');
        xline(stats.turn_radius.percentile_05, 'r-', 'LineWidth', 2, 'DisplayName', '5th %ile');
        xline(stats.turn_radius.percentile_10, 'g-', 'LineWidth', 2, 'DisplayName', '10th %ile');
        legend('Location', 'best');
        xlabel('Turn Radius (m)');
        ylabel('Count');
        title('Turn Radius Distribution');
        grid on;
        
        saveas(fig2, fullfile(fig_dir, 'turn_radius_distribution.png'));
    end
    
    fprintf('  ✓ Plots saved to: %s\n\n', fig_dir);
end

%% Step 9: Save Results
if config.save_results
    fprintf('Saving results...\n');
    
    % Save to MAT file
    save(fullfile(config.results_path, 'Data', 'phase1_baseline_results.mat'), ...
        'baseline_results');
    
    % Save to CSV for external analysis
    export_baseline_to_csv(baseline_results, config.results_path);
    
    fprintf('  ✓ Results saved to: %s\n\n', config.results_path);
end

%% Summary
fprintf('╔═══════════════════════════════════════════════════════════════╗\n');
fprintf('║                                                               ║\n');
fprintf('║   PHASE 1 COMPLETE: Baseline Criteria Established            ║\n');
fprintf('║                                                               ║\n');
fprintf('╚═══════════════════════════════════════════════════════════════╝\n\n');

fprintf('Next Steps:\n');
fprintf('  → Phase 2: TSE Analysis with Monte Carlo simulations\n');
fprintf('  → Phase 3: Abnormal scenario validation\n');
fprintf('  → Phase 4: Final procedure design standards\n\n');

%% Helper Functions

function selected = select_stratified_sample(catalog, indices, n_target)
    % Select stratified sample maintaining distribution of procedure types
    
    % Get procedure styles for indices
    styles = {catalog.runs(indices).procedure_style};
    
    % Count each style
    approach_idx = indices(strcmp(styles, 'approach'));
    departure_idx = indices(strcmp(styles, 'departure'));
    enroute_idx = indices(strcmp(styles, 'enroute'));
    
    % Calculate proportions
    n_approach = round(n_target * length(approach_idx) / length(indices));
    n_departure = round(n_target * length(departure_idx) / length(indices));
    n_enroute = n_target - n_approach - n_departure;
    
    % Sample from each
    selected = [];
    if ~isempty(approach_idx)
        selected = [selected; approach_idx(randperm(length(approach_idx), min(n_approach, length(approach_idx))))];
    end
    if ~isempty(departure_idx)
        selected = [selected; departure_idx(randperm(length(departure_idx), min(n_departure, length(departure_idx))))];
    end
    if ~isempty(enroute_idx)
        selected = [selected; enroute_idx(randperm(length(enroute_idx), min(n_enroute, length(enroute_idx))))];
    end
end

function export_baseline_to_csv(results, results_path)
    % Export baseline results to CSV
    
    stats = results.statistics;
    criteria = results.criteria;
    
    % Create table
    param_names = {
        'Climb Angle Mean (deg)', ...
        'Climb Angle 95% (deg)', ...
        'Climb Angle Max (deg)', ...
        'Descent Angle Mean (deg)', ...
        'Descent Angle 95% (deg)', ...
        'Descent Angle Max (deg)', ...
        'Bank Angle Mean (deg)', ...
        'Bank Angle 95% (deg)', ...
        'Bank Angle Max (deg)', ...
        'Turn Radius Mean (m)', ...
        'Turn Radius Min (m)', ...
        'Turn Radius 5th %ile (m)', ...
        'Recommended Max Climb (deg)', ...
        'Recommended Max Descent (deg)', ...
        'Recommended Max Bank (deg)', ...
        'Minimum Turn Radius (m)'
    }';
    
    values = [
        stats.climb_angle.mean; ...
        stats.climb_angle.percentile_95; ...
        stats.climb_angle.max; ...
        stats.descent_angle.mean; ...
        stats.descent_angle.percentile_95; ...
        stats.descent_angle.max; ...
        stats.bank_angle.mean; ...
        stats.bank_angle.percentile_95; ...
        stats.bank_angle.max; ...
        stats.turn_radius.mean; ...
        stats.turn_radius.min; ...
        stats.turn_radius.percentile_05; ...
        criteria.climb_angle.recommended_max; ...
        criteria.descent_angle.recommended_max; ...
        criteria.bank_angle.recommended_max; ...
        criteria.turn_radius.minimum
    ];
    
    T = table(param_names, values, 'VariableNames', {'Parameter', 'Value'});
    
    csv_file = fullfile(results_path, 'Data', 'phase1_baseline_results.csv');
    writetable(T, csv_file);
end
