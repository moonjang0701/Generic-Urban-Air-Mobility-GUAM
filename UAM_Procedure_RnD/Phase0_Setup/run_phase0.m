% RUN_PHASE0 - Execute Phase 0: Scenario Classification
%
% This script runs the scenario classification process for GUAM Challenge
% Problem datasets and saves the results for downstream analysis.
%
% Inputs: None (uses relative path to Challenge_Problems)
% Outputs: Saves scenario_catalog.mat to ../results/
%
% Author: UAM Procedure R&D Team
% Date: 2024-11-25
% Version: 1.0

%% Setup paths
% Get the Challenge_Problems directory path
uam_root = fileparts(pwd);  % Go up from Phase0_Setup to UAM_Procedure_RnD
repo_root = fileparts(uam_root);  % Go up to webapp
challenge_problems_path = fullfile(repo_root, 'Challenge_Problems');

% Verify Challenge_Problems exists
if ~exist(challenge_problems_path, 'dir')
    error('Challenge_Problems directory not found at: %s', challenge_problems_path);
end

% Create results directory if needed
results_dir = fullfile(uam_root, 'results');
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
    fprintf('Created results directory: %s\n', results_dir);
end

%% Run Scenario Classification
fprintf('Starting scenario classification...\n');
fprintf('Challenge Problems path: %s\n\n', challenge_problems_path);

% Call the scenario classifier function
scenario_catalog = scenario_classifier(challenge_problems_path);

%% Save Results
output_file = fullfile(results_dir, 'Phase0_scenario_catalog.mat');
save(output_file, 'scenario_catalog', '-v7.3');

fprintf('\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  Phase 0 Complete - Scenario Catalog Saved\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('Output file: %s\n', output_file);
fprintf('Total scenarios classified: %d\n', length(scenario_catalog.runs));
fprintf('\n');

% Display summary statistics
fprintf('Classification Summary:\n');
fprintf('  • Normal scenarios: %d\n', sum([scenario_catalog.runs.is_normal]));
fprintf('  • Abnormal scenarios: %d\n', sum(~[scenario_catalog.runs.is_normal]));

% Count trajectory types
traj_types = {scenario_catalog.runs.trajectory_type};
fprintf('  • Straight trajectories: %d\n', sum(strcmp(traj_types, 'straight')));
fprintf('  • Gentle turns: %d\n', sum(strcmp(traj_types, 'gentle_turn')));
fprintf('  • Sharp turns: %d\n', sum(strcmp(traj_types, 'sharp_turn')));

% Count vertical profiles
vert_profiles = {scenario_catalog.runs.vertical_profile};
fprintf('  • Climb: %d\n', sum(strcmp(vert_profiles, 'climb')));
fprintf('  • Level: %d\n', sum(strcmp(vert_profiles, 'level')));
fprintf('  • Descent: %d\n', sum(strcmp(vert_profiles, 'descent')));
fprintf('  • Mixed: %d\n', sum(strcmp(vert_profiles, 'mixed')));

fprintf('\n');
