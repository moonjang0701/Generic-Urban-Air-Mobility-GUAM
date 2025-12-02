% RUN_ALL - Execute Complete UAM Procedure R&D Analysis
%
% This master script runs all phases of the UAM procedure design R&D:
%   Phase 0: Scenario classification and catalog creation
%   Phase 1: Baseline performance analysis (normal operations)
%   Phase 2: TSE analysis with Monte Carlo (requires GUAM simulations)
%   Phase 3: Abnormal scenario validation (requires GUAM simulations)
%   Phase 4: Final procedure design standards derivation
%
% Author: UAM Procedure R&D Team
% Date: 2024-11-24
% Version: 1.0

clear; clc; close all;

fprintf('\n');
fprintf('╔═══════════════════════════════════════════════════════════════╗\n');
fprintf('║                                                               ║\n');
fprintf('║        UAM PROCEDURE R&D - COMPLETE ANALYSIS SUITE           ║\n');
fprintf('║        GUAM-Based Procedure Design Standards                 ║\n');
fprintf('║                                                               ║\n');
fprintf('╚═══════════════════════════════════════════════════════════════╝\n');
fprintf('\n');

%% Configuration
config = struct();
config.run_phase0 = true;   % Scenario classification
config.run_phase1 = true;   % Baseline analysis
config.run_phase2 = false;  % TSE analysis (requires GUAM sims)
config.run_phase3 = false;  % Abnormal analysis (requires GUAM sims)
config.run_phase4 = false;  % Standards derivation
config.pause_between_phases = true;

% Track timing
phase_times = zeros(5, 1);
total_start = tic;

%% Phase 0: Scenario Classification
if config.run_phase0
    fprintf('\n');
    fprintf('═══════════════════════════════════════════════════════════════\n');
    fprintf('  STARTING PHASE 0: SCENARIO CLASSIFICATION\n');
    fprintf('═══════════════════════════════════════════════════════════════\n\n');
    
    phase_start = tic;
    
    try
        cd Phase0_Setup
        run_phase0
        cd ..
        
        phase_times(1) = toc(phase_start);
        fprintf('\n✅ Phase 0 completed in %.1f seconds\n', phase_times(1));
    catch ME
        fprintf('\n❌ Phase 0 failed: %s\n', ME.message);
        fprintf('Error in: %s (line %d)\n', ME.stack(1).file, ME.stack(1).line);
        cd ..
        return;
    end
    
    if config.pause_between_phases
        fprintf('\nPress any key to continue to Phase 1...\n');
        pause;
    end
end

%% Phase 1: Baseline Performance Analysis
if config.run_phase1
    fprintf('\n');
    fprintf('═══════════════════════════════════════════════════════════════\n');
    fprintf('  STARTING PHASE 1: BASELINE ANALYSIS\n');
    fprintf('═══════════════════════════════════════════════════════════════\n\n');
    
    phase_start = tic;
    
    try
        cd Phase1_Baseline
        run_baseline_analysis
        cd ..
        
        phase_times(2) = toc(phase_start);
        fprintf('\n✅ Phase 1 completed in %.1f seconds\n', phase_times(2));
    catch ME
        fprintf('\n❌ Phase 1 failed: %s\n', ME.message);
        fprintf('Error in: %s (line %d)\n', ME.stack(1).file, ME.stack(1).line);
        cd ..
        return;
    end
    
    if config.pause_between_phases
        fprintf('\nPress any key to continue to Phase 2...\n');
        pause;
    end
end

%% Phase 2: TSE Analysis
if config.run_phase2
    fprintf('\n');
    fprintf('═══════════════════════════════════════════════════════════════\n');
    fprintf('  STARTING PHASE 2: TSE ANALYSIS\n');
    fprintf('═══════════════════════════════════════════════════════════════\n\n');
    
    fprintf('⚠️  Phase 2 requires GUAM simulations and is not yet implemented.\n');
    fprintf('   This phase will be completed in future work.\n\n');
    
    % Placeholder for Phase 2
    % cd Phase2_TSE_Analysis
    % run_tse_analysis
    % cd ..
    
    if config.pause_between_phases
        fprintf('\nPress any key to continue to Phase 3...\n');
        pause;
    end
end

%% Phase 3: Abnormal Scenario Validation
if config.run_phase3
    fprintf('\n');
    fprintf('═══════════════════════════════════════════════════════════════\n');
    fprintf('  STARTING PHASE 3: ABNORMAL SCENARIO VALIDATION\n');
    fprintf('═══════════════════════════════════════════════════════════════\n\n');
    
    fprintf('⚠️  Phase 3 requires GUAM simulations and is not yet implemented.\n');
    fprintf('   This phase will be completed in future work.\n\n');
    
    % Placeholder for Phase 3
    % cd Phase3_Abnormal
    % run_abnormal_analysis
    % cd ..
    
    if config.pause_between_phases
        fprintf('\nPress any key to continue to Phase 4...\n');
        pause;
    end
end

%% Phase 4: Standards Derivation
if config.run_phase4
    fprintf('\n');
    fprintf('═══════════════════════════════════════════════════════════════\n');
    fprintf('  STARTING PHASE 4: STANDARDS DERIVATION\n');
    fprintf('═══════════════════════════════════════════════════════════════\n\n');
    
    fprintf('⚠️  Phase 4 will compile all results into final standard.\n');
    fprintf('   This phase will be completed after Phases 2-3.\n\n');
    
    % Placeholder for Phase 4
    % cd Phase4_Standards
    % derive_design_standards
    % cd ..
end

%% Summary
total_time = toc(total_start);

fprintf('\n');
fprintf('╔═══════════════════════════════════════════════════════════════╗\n');
fprintf('║                                                               ║\n');
fprintf('║                  ANALYSIS COMPLETE                            ║\n');
fprintf('║                                                               ║\n');
fprintf('╚═══════════════════════════════════════════════════════════════╝\n\n');

fprintf('📊 EXECUTION SUMMARY:\n\n');

if config.run_phase0
    if phase_times(1) > 0
        status_icon = '✅';
    else
        status_icon = '⏭️';
    end
    fprintf('  Phase 0 (Classification):  %6.1f seconds  %s\n', ...
        phase_times(1), status_icon);
end
if config.run_phase1
    if phase_times(2) > 0
        status_icon = '✅';
    else
        status_icon = '⏭️';
    end
    fprintf('  Phase 1 (Baseline):        %6.1f seconds  %s\n', ...
        phase_times(2), status_icon);
end
if config.run_phase2
    fprintf('  Phase 2 (TSE):             %6s          %s\n', ...
        'N/A', '⚠️ ');
end
if config.run_phase3
    fprintf('  Phase 3 (Abnormal):        %6s          %s\n', ...
        'N/A', '⚠️ ');
end
if config.run_phase4
    fprintf('  Phase 4 (Standards):       %6s          %s\n', ...
        'N/A', '⚠️ ');
end

fprintf('\n  Total Execution Time:      %6.1f seconds\n', total_time);

fprintf('\n📁 OUTPUT LOCATIONS:\n');
fprintf('  • Results:  ./Results/Data/\n');
fprintf('  • Figures:  ./Results/Figures/\n');
fprintf('  • Reports:  ./Results/Reports/\n\n');

fprintf('📝 DELIVERABLES:\n');
if config.run_phase0
    fprintf('  ✅ Scenario catalog with 3000 classified runs\n');
    fprintf('  ✅ Classification distribution plots\n');
end
if config.run_phase1
    fprintf('  ✅ Baseline performance statistics\n');
    fprintf('  ✅ Recommended design criteria (preliminary)\n');
    fprintf('  ✅ Flight angle and turn radius distributions\n');
end

fprintf('\n🚀 NEXT STEPS:\n');
fprintf('  1. Review generated figures in Results/Figures/\n');
fprintf('  2. Check CSV data exports in Results/Data/\n');
fprintf('  3. Read summary reports in Results/Reports/\n');

if ~config.run_phase2
    fprintf('  4. Implement Phase 2 for TSE analysis with GUAM simulations\n');
end
if ~config.run_phase3
    fprintf('  5. Implement Phase 3 for abnormal scenario validation\n');
end
if ~config.run_phase4
    fprintf('  6. Complete Phase 4 to generate final standards document\n');
end

fprintf('\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  For questions or issues, see README.md\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

%% Open Results Directory (optional)
answer = input('Would you like to open the results directory? (y/n): ', 's');
if strcmpi(answer, 'y')
    if ispc
        winopen('Results');
    elseif ismac
        system('open Results');
    else
        system('xdg-open Results &');
    end
end

fprintf('\n✅ Analysis pipeline complete!\n\n');
