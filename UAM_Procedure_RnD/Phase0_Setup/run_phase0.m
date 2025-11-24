% RUN_PHASE0 - Initialize UAM Procedure R&D Project
%
% Phase 0: Setup and Scenario Classification
%
% This script:
%   1. Sets up the project environment
%   2. Classifies all GUAM Challenge Problem scenarios
%   3. Creates a searchable catalog for subsequent analysis phases
%   4. Generates summary statistics and visualizations
%
% Author: UAM Procedure R&D Team
% Date: 2024-11-24
% Version: 1.0

clear; clc; close all;

fprintf('\n');
fprintf('╔═══════════════════════════════════════════════════════════════╗\n');
fprintf('║                                                               ║\n');
fprintf('║   UAM PROCEDURE R&D - PHASE 0: PROJECT INITIALIZATION        ║\n');
fprintf('║   Scenario Classification and Catalog Creation               ║\n');
fprintf('║                                                               ║\n');
fprintf('╚═══════════════════════════════════════════════════════════════╝\n');
fprintf('\n');

%% Configuration
config = struct();
config.challenge_data_path = '../../Challenge_Problems';
config.results_path = '../Results';
config.generate_plots = true;
config.save_results = true;

%% Step 1: Verify Environment
fprintf('Step 1: Verifying project environment...\n');

% Check if Challenge_Problems directory exists
if ~exist(config.challenge_data_path, 'dir')
    error('Challenge_Problems directory not found at: %s', config.challenge_data_path);
end

% Check for Data_Set_1.mat
ds1_path = fullfile(config.challenge_data_path, 'Data_Set_1.mat');
if ~exist(ds1_path, 'file')
    error('Data_Set_1.mat not found. Please ensure GUAM Challenge Problems are downloaded.');
end

fprintf('  ✓ Environment verified\n');
fprintf('  ✓ Challenge Problems data found\n\n');

%% Step 2: Create Results Directory Structure
fprintf('Step 2: Creating results directory structure...\n');

dirs_to_create = {
    fullfile(config.results_path, 'Data');
    fullfile(config.results_path, 'Figures', 'Phase0_Setup');
    fullfile(config.results_path, 'Figures', 'Phase1_Baseline');
    fullfile(config.results_path, 'Figures', 'Phase2_TSE');
    fullfile(config.results_path, 'Figures', 'Phase3_Abnormal');
    fullfile(config.results_path, 'Reports');
};

for i = 1:length(dirs_to_create)
    if ~exist(dirs_to_create{i}, 'dir')
        mkdir(dirs_to_create{i});
    end
end

fprintf('  ✓ Directory structure created\n\n');

%% Step 3: Run Scenario Classifier
fprintf('Step 3: Running scenario classification...\n\n');

% Run the classifier
scenario_catalog = scenario_classifier(config.challenge_data_path);

fprintf('\n');

%% Step 4: Save Catalog
fprintf('Step 4: Saving scenario catalog...\n');

catalog_file = fullfile(config.results_path, 'Data', 'scenario_catalog.mat');
save(catalog_file, 'scenario_catalog', '-v7.3');

fprintf('  ✓ Catalog saved to: %s\n', catalog_file);
fprintf('  ✓ File size: %.1f MB\n\n', dir(catalog_file).bytes / 1e6);

%% Step 5: Generate Visualizations
if config.generate_plots
    fprintf('Step 5: Generating visualization plots...\n');
    
    fig_dir = fullfile(config.results_path, 'Figures', 'Phase0_Setup');
    
    % Plot 1: Scenario Distribution Overview
    fig1 = figure('Position', [100, 100, 1400, 800]);
    
    % Trajectory type distribution
    subplot(2, 3, 1);
    traj_types = scenario_catalog.statistics.trajectory_types;
    labels = {'Straight', 'Gentle Turn', 'Sharp Turn', 'Unknown'};
    values = [traj_types.straight, traj_types.gentle_turn, traj_types.sharp_turn, traj_types.unknown];
    pie(values, labels);
    title('Trajectory Types', 'FontSize', 12, 'FontWeight', 'bold');
    
    % Vertical profile distribution
    subplot(2, 3, 2);
    vert_profs = scenario_catalog.statistics.vertical_profiles;
    labels = {'Climb', 'Level', 'Descent', 'Unknown'};
    values = [vert_profs.climb, vert_profs.level, vert_profs.descent, vert_profs.unknown];
    pie(values, labels);
    title('Vertical Profiles', 'FontSize', 12, 'FontWeight', 'bold');
    
    % Procedure style distribution
    subplot(2, 3, 3);
    proc_styles = scenario_catalog.statistics.procedure_styles;
    labels = {'Approach', 'Departure', 'En-route', 'Unknown'};
    values = [proc_styles.approach, proc_styles.departure, proc_styles.enroute, proc_styles.unknown];
    pie(values, labels);
    title('Procedure Styles', 'FontSize', 12, 'FontWeight', 'bold');
    
    % Failure scenarios
    subplot(2, 3, 4);
    failures = scenario_catalog.statistics.failures;
    bar([failures.without_failure, failures.with_failure]);
    set(gca, 'XTickLabel', {'Normal', 'With Failure'});
    ylabel('Count');
    title('Failure Scenarios', 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    
    % Obstacle scenarios
    subplot(2, 3, 5);
    obstacles = scenario_catalog.statistics.obstacles;
    bar([obstacles.without_obstacles, obstacles.with_static, obstacles.with_moving, obstacles.with_any]);
    set(gca, 'XTickLabel', {'Clear', 'Static', 'Moving', 'Any'});
    ylabel('Count');
    title('Obstacle Scenarios', 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    
    % Combined classification
    subplot(2, 3, 6);
    n_total = scenario_catalog.metadata.n_runs;
    categories = {
        'Normal/Clear', ...
        'Normal/Obstacles', ...
        'Failure/Clear', ...
        'Failure/Obstacles'
    };
    counts = [
        sum([scenario_catalog.runs.has_failure] == false & ...
            [scenario_catalog.runs.has_static_obstacle] == false & ...
            [scenario_catalog.runs.has_moving_obstacle] == false), ...
        sum([scenario_catalog.runs.has_failure] == false & ...
            ([scenario_catalog.runs.has_static_obstacle] == true | ...
             [scenario_catalog.runs.has_moving_obstacle] == true)), ...
        sum([scenario_catalog.runs.has_failure] == true & ...
            [scenario_catalog.runs.has_static_obstacle] == false & ...
            [scenario_catalog.runs.has_moving_obstacle] == false), ...
        sum([scenario_catalog.runs.has_failure] == true & ...
            ([scenario_catalog.runs.has_static_obstacle] == true | ...
             [scenario_catalog.runs.has_moving_obstacle] == true))
    ];
    bar(counts);
    set(gca, 'XTickLabel', categories);
    xtickangle(45);
    ylabel('Count');
    title('Combined Classification', 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    
    sgtitle('UAM Scenario Catalog Overview', 'FontSize', 16, 'FontWeight', 'bold');
    
    saveas(fig1, fullfile(fig_dir, 'scenario_distribution_overview.png'));
    
    % Plot 2: Performance Metrics Distributions
    fig2 = figure('Position', [100, 100, 1400, 600]);
    
    % Extract valid data
    bank_angles = [scenario_catalog.runs.max_bank_angle];
    bank_angles = bank_angles(bank_angles > 0 & bank_angles < 90);
    
    climb_angles = [scenario_catalog.runs.max_climb_angle];
    climb_angles = climb_angles(climb_angles > 0);
    
    descent_angles = [scenario_catalog.runs.max_descent_angle];
    descent_angles = descent_angles(descent_angles > 0);
    
    turn_radii = [scenario_catalog.runs.min_turn_radius];
    turn_radii = turn_radii(isfinite(turn_radii) & turn_radii > 0 & turn_radii < 10000);
    
    % Plot distributions
    if ~isempty(bank_angles)
        subplot(2, 2, 1);
        histogram(bank_angles, 30, 'FaceColor', [0.4 0.8 0.4]);
        xlabel('Bank Angle (deg)');
        ylabel('Count');
        title(sprintf('Bank Angle Distribution (n=%d)', length(bank_angles)));
        grid on;
    end
    
    if ~isempty(climb_angles)
        subplot(2, 2, 2);
        histogram(climb_angles, 30, 'FaceColor', [0.2 0.6 0.9]);
        xlabel('Climb Angle (deg)');
        ylabel('Count');
        title(sprintf('Climb Angle Distribution (n=%d)', length(climb_angles)));
        grid on;
    end
    
    if ~isempty(descent_angles)
        subplot(2, 2, 3);
        histogram(descent_angles, 30, 'FaceColor', [0.9 0.4 0.2]);
        xlabel('Descent Angle (deg)');
        ylabel('Count');
        title(sprintf('Descent Angle Distribution (n=%d)', length(descent_angles)));
        grid on;
    end
    
    if ~isempty(turn_radii)
        subplot(2, 2, 4);
        histogram(turn_radii, 30, 'FaceColor', [0.7 0.3 0.8]);
        xlabel('Turn Radius (m)');
        ylabel('Count');
        title(sprintf('Turn Radius Distribution (n=%d)', length(turn_radii)));
        grid on;
    end
    
    sgtitle('Performance Metrics Distributions', 'FontSize', 16, 'FontWeight', 'bold');
    
    saveas(fig2, fullfile(fig_dir, 'performance_metrics_distributions.png'));
    
    fprintf('  ✓ Plots saved to: %s\n\n', fig_dir);
end

%% Step 6: Generate Summary Report
fprintf('Step 6: Generating summary report...\n');

report_file = fullfile(config.results_path, 'Reports', 'Phase0_Summary.txt');
fid = fopen(report_file, 'w');

fprintf(fid, '═══════════════════════════════════════════════════════════════\n');
fprintf(fid, '  UAM PROCEDURE R&D - PHASE 0 SUMMARY REPORT\n');
fprintf(fid, '  Generated: %s\n', datestr(now));
fprintf(fid, '═══════════════════════════════════════════════════════════════\n\n');

fprintf(fid, 'PROJECT CONFIGURATION:\n');
fprintf(fid, '  Data Source: %s\n', config.challenge_data_path);
fprintf(fid, '  Results Path: %s\n\n', config.results_path);

fprintf(fid, 'DATASET OVERVIEW:\n');
fprintf(fid, '  Total Scenarios: %d\n\n', scenario_catalog.metadata.n_runs);

fprintf(fid, 'TRAJECTORY TYPE DISTRIBUTION:\n');
fprintf(fid, '  Straight:     %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.trajectory_types.straight, ...
    100*scenario_catalog.statistics.trajectory_types.straight/scenario_catalog.metadata.n_runs);
fprintf(fid, '  Gentle Turn:  %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.trajectory_types.gentle_turn, ...
    100*scenario_catalog.statistics.trajectory_types.gentle_turn/scenario_catalog.metadata.n_runs);
fprintf(fid, '  Sharp Turn:   %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.trajectory_types.sharp_turn, ...
    100*scenario_catalog.statistics.trajectory_types.sharp_turn/scenario_catalog.metadata.n_runs);
fprintf(fid, '  Unknown:      %4d (%.1f%%)\n\n', ...
    scenario_catalog.statistics.trajectory_types.unknown, ...
    100*scenario_catalog.statistics.trajectory_types.unknown/scenario_catalog.metadata.n_runs);

fprintf(fid, 'VERTICAL PROFILE DISTRIBUTION:\n');
fprintf(fid, '  Climb:   %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.vertical_profiles.climb, ...
    100*scenario_catalog.statistics.vertical_profiles.climb/scenario_catalog.metadata.n_runs);
fprintf(fid, '  Level:   %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.vertical_profiles.level, ...
    100*scenario_catalog.statistics.vertical_profiles.level/scenario_catalog.metadata.n_runs);
fprintf(fid, '  Descent: %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.vertical_profiles.descent, ...
    100*scenario_catalog.statistics.vertical_profiles.descent/scenario_catalog.metadata.n_runs);
fprintf(fid, '  Unknown: %4d (%.1f%%)\n\n', ...
    scenario_catalog.statistics.vertical_profiles.unknown, ...
    100*scenario_catalog.statistics.vertical_profiles.unknown/scenario_catalog.metadata.n_runs);

fprintf(fid, 'PROCEDURE STYLE DISTRIBUTION:\n');
fprintf(fid, '  Approach:  %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.procedure_styles.approach, ...
    100*scenario_catalog.statistics.procedure_styles.approach/scenario_catalog.metadata.n_runs);
fprintf(fid, '  Departure: %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.procedure_styles.departure, ...
    100*scenario_catalog.statistics.procedure_styles.departure/scenario_catalog.metadata.n_runs);
fprintf(fid, '  En-route:  %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.procedure_styles.enroute, ...
    100*scenario_catalog.statistics.procedure_styles.enroute/scenario_catalog.metadata.n_runs);
fprintf(fid, '  Unknown:   %4d (%.1f%%)\n\n', ...
    scenario_catalog.statistics.procedure_styles.unknown, ...
    100*scenario_catalog.statistics.procedure_styles.unknown/scenario_catalog.metadata.n_runs);

fprintf(fid, 'FAILURE AND OBSTACLE SCENARIOS:\n');
fprintf(fid, '  Normal (no failure):  %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.failures.without_failure, ...
    100*scenario_catalog.statistics.failures.without_failure/scenario_catalog.metadata.n_runs);
fprintf(fid, '  With failure:         %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.failures.with_failure, ...
    100*scenario_catalog.statistics.failures.with_failure/scenario_catalog.metadata.n_runs);
fprintf(fid, '  With static obstacle: %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.obstacles.with_static, ...
    100*scenario_catalog.statistics.obstacles.with_static/scenario_catalog.metadata.n_runs);
fprintf(fid, '  With moving obstacle: %4d (%.1f%%)\n', ...
    scenario_catalog.statistics.obstacles.with_moving, ...
    100*scenario_catalog.statistics.obstacles.with_moving/scenario_catalog.metadata.n_runs);
fprintf(fid, '  Clear (no obstacles): %4d (%.1f%%)\n\n', ...
    scenario_catalog.statistics.obstacles.without_obstacles, ...
    100*scenario_catalog.statistics.obstacles.without_obstacles/scenario_catalog.metadata.n_runs);

fprintf(fid, '═══════════════════════════════════════════════════════════════\n');
fprintf(fid, 'NEXT STEPS:\n');
fprintf(fid, '  → Phase 1: Baseline performance analysis (normal scenarios)\n');
fprintf(fid, '  → Phase 2: TSE analysis with Monte Carlo\n');
fprintf(fid, '  → Phase 3: Abnormal scenario validation\n');
fprintf(fid, '  → Phase 4: Procedure design standards derivation\n');
fprintf(fid, '═══════════════════════════════════════════════════════════════\n');

fclose(fid);

fprintf('  ✓ Summary report saved to: %s\n\n', report_file);

%% Completion
fprintf('╔═══════════════════════════════════════════════════════════════╗\n');
fprintf('║                                                               ║\n');
fprintf('║   PHASE 0 COMPLETE                                            ║\n');
fprintf('║   Scenario catalog ready for analysis                        ║\n');
fprintf('║                                                               ║\n');
fprintf('╚═══════════════════════════════════════════════════════════════╝\n\n');

fprintf('Catalog Statistics:\n');
fprintf('  • Total scenarios:    %d\n', scenario_catalog.metadata.n_runs);
fprintf('  • Normal scenarios:   %d\n', scenario_catalog.statistics.failures.without_failure);
fprintf('  • Abnormal scenarios: %d\n', scenario_catalog.statistics.failures.with_failure);
fprintf('\n');

fprintf('Ready to proceed with:\n');
fprintf('  → Phase 1: Run phase1_baseline/run_baseline_analysis.m\n');
fprintf('  → Phase 2: Run phase2_tse_analysis/run_tse_analysis.m\n\n');
