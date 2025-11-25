% RUN_BASELINE_ANALYSIS - Execute Phase 1: Baseline Performance Analysis
%
% This script analyzes normal operation scenarios from the classified catalog
% to derive baseline performance metrics for UAM procedure design.
%
% Metrics computed:
%   - Climb/descent angle distributions
%   - Turn radius distributions
%   - Bank angle distributions
%   - Velocity profiles
%   - Acceleration limits
%
% Inputs: Reads Phase0_scenario_catalog.mat from ../results/
% Outputs: Saves baseline_metrics.mat to ../results/
%
% Author: UAM Procedure R&D Team
% Date: 2024-11-25
% Version: 1.0

fprintf('\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  UAM Procedure R&D - Baseline Performance Analysis\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

%% Load Phase 0 Results
uam_root = fileparts(pwd);  % Go up from Phase1_Baseline to UAM_Procedure_RnD
results_dir = fullfile(uam_root, 'results');

catalog_file = fullfile(results_dir, 'Phase0_scenario_catalog.mat');
if ~exist(catalog_file, 'file')
    error('Phase 0 results not found. Please run Phase 0 first.\nExpected: %s', catalog_file);
end

fprintf('Loading Phase 0 scenario catalog...\n');
load(catalog_file, 'scenario_catalog');
fprintf('  ✓ Loaded catalog with %d scenarios\n\n', length(scenario_catalog.runs));

%% Filter Normal Scenarios
fprintf('Filtering normal operation scenarios...\n');
normal_mask = [scenario_catalog.runs.is_normal];
normal_scenarios = scenario_catalog.runs(normal_mask);
n_normal = length(normal_scenarios);
fprintf('  ✓ Found %d normal scenarios (%.1f%%)\n\n', n_normal, 100*n_normal/length(scenario_catalog.runs));

if n_normal == 0
    error('No normal scenarios found in catalog. Cannot proceed with baseline analysis.');
end

%% Initialize Baseline Metrics Structure
baseline_metrics = struct();
baseline_metrics.n_scenarios = n_normal;
baseline_metrics.timestamp = datetime('now');

%% Extract Climb/Descent Angles
fprintf('Analyzing climb and descent angles...\n');

climb_angles = [];
descent_angles = [];

for i = 1:n_normal
    if ~isempty(normal_scenarios(i).max_climb_angle)
        climb_angles = [climb_angles; normal_scenarios(i).max_climb_angle];
    end
    if ~isempty(normal_scenarios(i).max_descent_angle)
        descent_angles = [descent_angles; abs(normal_scenarios(i).max_descent_angle)];
    end
end

baseline_metrics.climb_angles = struct();
if ~isempty(climb_angles)
    baseline_metrics.climb_angles.mean = mean(climb_angles);
    baseline_metrics.climb_angles.median = median(climb_angles);
    baseline_metrics.climb_angles.std = std(climb_angles);
    baseline_metrics.climb_angles.p95 = prctile(climb_angles, 95);
    baseline_metrics.climb_angles.p99 = prctile(climb_angles, 99);
    baseline_metrics.climb_angles.max = max(climb_angles);
    baseline_metrics.climb_angles.data = climb_angles;
    
    fprintf('  Climb Angles:\n');
    fprintf('    Mean: %.2f°, Median: %.2f°, Std: %.2f°\n', ...
        baseline_metrics.climb_angles.mean, ...
        baseline_metrics.climb_angles.median, ...
        baseline_metrics.climb_angles.std);
    fprintf('    95th%%: %.2f°, 99th%%: %.2f°, Max: %.2f°\n', ...
        baseline_metrics.climb_angles.p95, ...
        baseline_metrics.climb_angles.p99, ...
        baseline_metrics.climb_angles.max);
end

baseline_metrics.descent_angles = struct();
if ~isempty(descent_angles)
    baseline_metrics.descent_angles.mean = mean(descent_angles);
    baseline_metrics.descent_angles.median = median(descent_angles);
    baseline_metrics.descent_angles.std = std(descent_angles);
    baseline_metrics.descent_angles.p95 = prctile(descent_angles, 95);
    baseline_metrics.descent_angles.p99 = prctile(descent_angles, 99);
    baseline_metrics.descent_angles.max = max(descent_angles);
    baseline_metrics.descent_angles.data = descent_angles;
    
    fprintf('  Descent Angles:\n');
    fprintf('    Mean: %.2f°, Median: %.2f°, Std: %.2f°\n', ...
        baseline_metrics.descent_angles.mean, ...
        baseline_metrics.descent_angles.median, ...
        baseline_metrics.descent_angles.std);
    fprintf('    95th%%: %.2f°, 99th%%: %.2f°, Max: %.2f°\n', ...
        baseline_metrics.descent_angles.p95, ...
        baseline_metrics.descent_angles.p99, ...
        baseline_metrics.descent_angles.max);
end

fprintf('\n');

%% Extract Duration Statistics
fprintf('Analyzing scenario durations...\n');

durations = [normal_scenarios.duration];
durations = durations(durations > 0);  % Remove invalid durations

baseline_metrics.durations = struct();
if ~isempty(durations)
    baseline_metrics.durations.mean = mean(durations);
    baseline_metrics.durations.median = median(durations);
    baseline_metrics.durations.std = std(durations);
    baseline_metrics.durations.min = min(durations);
    baseline_metrics.durations.max = max(durations);
    baseline_metrics.durations.data = durations;
    
    fprintf('  Scenario Durations:\n');
    fprintf('    Mean: %.1f s, Median: %.1f s, Std: %.1f s\n', ...
        baseline_metrics.durations.mean, ...
        baseline_metrics.durations.median, ...
        baseline_metrics.durations.std);
    fprintf('    Range: [%.1f, %.1f] s\n', ...
        baseline_metrics.durations.min, ...
        baseline_metrics.durations.max);
end

fprintf('\n');

%% Extract Distance Statistics
fprintf('Analyzing trajectory distances...\n');

distances = [normal_scenarios.total_distance];
distances = distances(distances > 0);  % Remove invalid distances

baseline_metrics.distances = struct();
if ~isempty(distances)
    baseline_metrics.distances.mean = mean(distances);
    baseline_metrics.distances.median = median(distances);
    baseline_metrics.distances.std = std(distances);
    baseline_metrics.distances.min = min(distances);
    baseline_metrics.distances.max = max(distances);
    baseline_metrics.distances.data = distances;
    
    fprintf('  Trajectory Distances:\n');
    fprintf('    Mean: %.1f m, Median: %.1f m, Std: %.1f m\n', ...
        baseline_metrics.distances.mean, ...
        baseline_metrics.distances.median, ...
        baseline_metrics.distances.std);
    fprintf('    Range: [%.1f, %.1f] m\n', ...
        baseline_metrics.distances.min, ...
        baseline_metrics.distances.max);
end

fprintf('\n');

%% Save Results
output_file = fullfile(results_dir, 'Phase1_baseline_metrics.mat');
save(output_file, 'baseline_metrics', '-v7.3');

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  Phase 1 Complete - Baseline Metrics Saved\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('Output file: %s\n', output_file);
fprintf('Normal scenarios analyzed: %d\n', n_normal);
fprintf('\n');

fprintf('Summary of Baseline Performance:\n');
if ~isempty(climb_angles)
    fprintf('  • Typical climb angle: %.2f° (95th%%: %.2f°)\n', ...
        baseline_metrics.climb_angles.median, baseline_metrics.climb_angles.p95);
end
if ~isempty(descent_angles)
    fprintf('  • Typical descent angle: %.2f° (95th%%: %.2f°)\n', ...
        baseline_metrics.descent_angles.median, baseline_metrics.descent_angles.p95);
end
if ~isempty(durations)
    fprintf('  • Typical duration: %.1f s (range: %.1f-%.1f s)\n', ...
        baseline_metrics.durations.median, ...
        baseline_metrics.durations.min, ...
        baseline_metrics.durations.max);
end
if ~isempty(distances)
    fprintf('  • Typical distance: %.1f m (range: %.1f-%.1f m)\n', ...
        baseline_metrics.distances.median, ...
        baseline_metrics.distances.min, ...
        baseline_metrics.distances.max);
end

fprintf('\n');
fprintf('💡 Note: Phase 1 provides statistical baseline metrics.\n');
fprintf('   For detailed TSE analysis, Phase 2 requires GUAM simulations.\n');
fprintf('\n');
