%% Monte Carlo TSE Safety Assessment for UAM Corridor
% =====================================================
% Purpose: Evaluate corridor safety using probabilistic Monte Carlo simulation
%          with GUAM 6-DOF simulation, Kalman filtering, and TSE modeling
%
% Author: AI Assistant
% Date: 2025-01-18
%
% Main Goal:
% ----------
% Compute probability of corridor infringement P_hit = N_hit / N_total
% Compare with Target Level of Safety (TLS = 1e-4)
% Provide safety conclusion: SAFE or NOT SAFE
%
% Outputs:
% --------
% 1. P_hit probability estimate
% 2. TSE distribution (histogram, CDF)
% 3. FTE and NSE statistics
% 4. Trajectory plots (sample runs)
% 5. Safety conclusion report
%
% =====================================================

clear all; close all; clc;

fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  Monte Carlo TSE Safety Assessment for UAM Corridor         ║\n');
fprintf('║  Using NASA GUAM + Kalman Filter + Probabilistic Modeling   ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════════
%% SECTION 1: INITIALIZATION AND SETUP
%% ═══════════════════════════════════════════════════════════════

fprintf('═══ SECTION 1: Initialization ═══\n\n');

% Navigate to GUAM root
script_dir = fileparts(mfilename('fullpath'));
guam_root = fileparts(script_dir);
cd(guam_root);

fprintf('Working directory: %s\n', pwd);
fprintf('Adding STARS library...\n');
addpath(genpath('lib'));

% Initialize GUAM
model = 'GUAM';
fprintf('Initializing GUAM model...\n\n');

%% ═══════════════════════════════════════════════════════════════
%% SECTION 2: SCENARIO PARAMETERS (USER CONFIGURABLE)
%% ═══════════════════════════════════════════════════════════════

fprintf('═══ SECTION 2: Scenario Configuration ═══\n\n');

% ───── Trajectory Parameters ─────
SEGMENT_LENGTH_M = 1000;        % 1 km straight segment
ALTITUDE_FT = 1000;             % Flight altitude
GROUND_SPEED_KT = 90;           % Ground speed
SIMULATION_TIME_S = 30;         % Total simulation time

% ───── TSE Design Parameters ─────
TSE_2SIGMA_DESIGN_M = 300;      % Design lateral TSE (2σ = 300 m)
CORRIDOR_HALF_WIDTH_M = 350;    % Corridor half-width (buffer beyond TSE)
TLS_TARGET = 1e-4;              % Target Level of Safety (0.01%)

% ───── Monte Carlo Parameters ─────
N_MONTE_CARLO = 500;            % Number of MC samples (increase for accuracy)
USE_PARALLEL = false;           % Set true for parfor speedup
RANDOM_SEED = 42;               % For reproducibility

% ───── Uncertainty Parameters ─────
% Crosswind uncertainty
WIND_MEAN_KT = 20;              % Mean crosswind (perpendicular to track)
WIND_SIGMA_KT = 5;              % Crosswind standard deviation

% Initial state uncertainties
SIGMA_Y0_M = 10;                % Initial lateral offset uncertainty
SIGMA_HEADING0_DEG = 2;         % Initial heading error uncertainty

% Controller uncertainties
SIGMA_TAU_S = 0.2;              % Response time uncertainty
CTRL_GAIN_VARIATION = 0.10;     % ±10% gain variation

% Navigation sensor noise (for Kalman Filter)
NSE_SIGMA_BASE_M = 5;           % Base navigation system error (1σ)
NSE_SIGMA_VAR = 0.3;            % Variation factor for NSE per run

fprintf('Scenario Parameters:\n');
fprintf('  Trajectory: %.0f m straight segment at %.0f ft, %.0f kt\n', ...
    SEGMENT_LENGTH_M, ALTITUDE_FT, GROUND_SPEED_KT);
fprintf('  TSE Design: 2σ = %.0f m lateral\n', TSE_2SIGMA_DESIGN_M);
fprintf('  Corridor width: ±%.0f m\n', CORRIDOR_HALF_WIDTH_M);
fprintf('  Target Level of Safety: %.1e\n', TLS_TARGET);
fprintf('  Monte Carlo samples: %d\n', N_MONTE_CARLO);
fprintf('  Parallel computing: %s\n\n', mat2str(USE_PARALLEL));

fprintf('Uncertainty Parameters:\n');
fprintf('  Crosswind: %.0f ± %.0f kt\n', WIND_MEAN_KT, WIND_SIGMA_KT);
fprintf('  Initial lateral offset: σ = %.1f m\n', SIGMA_Y0_M);
fprintf('  Initial heading error: σ = %.1f deg\n', SIGMA_HEADING0_DEG);
fprintf('  NSE (navigation): σ = %.1f m\n', NSE_SIGMA_BASE_M);
fprintf('  Controller gain variation: ±%.0f%%\n\n', CTRL_GAIN_VARIATION*100);

%% ═══════════════════════════════════════════════════════════════
%% SECTION 3: GENERATE REFERENCE TRAJECTORY
%% ═══════════════════════════════════════════════════════════════

fprintf('═══ SECTION 3: Reference Trajectory ═══\n\n');

[ref_traj] = generate_reference_trajectory(SEGMENT_LENGTH_M, ALTITUDE_FT, ...
                                           GROUND_SPEED_KT, SIMULATION_TIME_S);

fprintf('Reference trajectory generated:\n');
fprintf('  Duration: %.1f s\n', ref_traj.time(end));
fprintf('  Distance: %.1f m\n', ref_traj.pos(end,1));
fprintf('  Ground speed: %.2f m/s\n', ref_traj.vel_ms);
fprintf('  Heading: %.1f deg (North)\n\n', ref_traj.heading_deg);

%% ═══════════════════════════════════════════════════════════════
%% SECTION 4: GENERATE MONTE CARLO SAMPLES
%% ═══════════════════════════════════════════════════════════════

fprintf('═══ SECTION 4: Monte Carlo Sampling ═══\n\n');

rng(RANDOM_SEED);  % Set random seed for reproducibility

% Generate all MC samples at once
MC_params = sample_MC_inputs(N_MONTE_CARLO, WIND_MEAN_KT, WIND_SIGMA_KT, ...
                             SIGMA_Y0_M, SIGMA_HEADING0_DEG, SIGMA_TAU_S, ...
                             CTRL_GAIN_VARIATION, NSE_SIGMA_BASE_M, NSE_SIGMA_VAR);

fprintf('Generated %d Monte Carlo parameter sets\n', N_MONTE_CARLO);
fprintf('  Crosswind range: [%.2f, %.2f] m/s\n', min(MC_params.wind_E_ms), max(MC_params.wind_E_ms));
fprintf('  Initial offset range: [%.2f, %.2f] m\n', min(MC_params.y0_m), max(MC_params.y0_m));
fprintf('  Heading error range: [%.2f, %.2f] deg\n', min(MC_params.heading_err_deg), max(MC_params.heading_err_deg));
fprintf('  NSE sigma range: [%.2f, %.2f] m\n\n', min(MC_params.nse_sigma_m), max(MC_params.nse_sigma_m));

%% ═══════════════════════════════════════════════════════════════
%% SECTION 5: MONTE CARLO SIMULATION LOOP
%% ═══════════════════════════════════════════════════════════════

fprintf('═══ SECTION 5: Running Monte Carlo Simulations ═══\n\n');
fprintf('This may take several minutes...\n');
fprintf('Progress: ');

% Preallocate results storage
MC_results = struct();
MC_results.max_lateral_FTE = zeros(N_MONTE_CARLO, 1);
MC_results.rms_lateral_FTE = zeros(N_MONTE_CARLO, 1);
MC_results.max_TSE = zeros(N_MONTE_CARLO, 1);
MC_results.rms_TSE = zeros(N_MONTE_CARLO, 1);
MC_results.min_distance_to_boundary = zeros(N_MONTE_CARLO, 1);
MC_results.is_hit = false(N_MONTE_CARLO, 1);
MC_results.trajectories = cell(N_MONTE_CARLO, 1);
MC_results.success = true(N_MONTE_CARLO, 1);

% Progress bar setup
progress_step = max(1, floor(N_MONTE_CARLO / 20));

% Main Monte Carlo loop
if USE_PARALLEL
    % Parallel execution
    parfor i = 1:N_MONTE_CARLO
        MC_results_i = run_single_MC_simulation(i, MC_params, ref_traj, ...
                                                 CORRIDOR_HALF_WIDTH_M, model);
        % Store results (requires special handling for parfor)
        MC_results.max_lateral_FTE(i) = MC_results_i.max_lateral_FTE;
        MC_results.rms_lateral_FTE(i) = MC_results_i.rms_lateral_FTE;
        MC_results.max_TSE(i) = MC_results_i.max_TSE;
        MC_results.rms_TSE(i) = MC_results_i.rms_TSE;
        MC_results.min_distance_to_boundary(i) = MC_results_i.min_distance_to_boundary;
        MC_results.is_hit(i) = MC_results_i.is_hit;
        MC_results.trajectories{i} = MC_results_i.trajectory;
        MC_results.success(i) = MC_results_i.success;
    end
else
    % Serial execution with progress bar
    for i = 1:N_MONTE_CARLO
        % Run single simulation
        MC_results_i = run_single_MC_simulation(i, MC_params, ref_traj, ...
                                                 CORRIDOR_HALF_WIDTH_M, model);
        
        % Store results
        MC_results.max_lateral_FTE(i) = MC_results_i.max_lateral_FTE;
        MC_results.rms_lateral_FTE(i) = MC_results_i.rms_lateral_FTE;
        MC_results.max_TSE(i) = MC_results_i.max_TSE;
        MC_results.rms_TSE(i) = MC_results_i.rms_TSE;
        MC_results.min_distance_to_boundary(i) = MC_results_i.min_distance_to_boundary;
        MC_results.is_hit(i) = MC_results_i.is_hit;
        MC_results.trajectories{i} = MC_results_i.trajectory;
        MC_results.success(i) = MC_results_i.success;
        
        % Progress indicator
        if mod(i, progress_step) == 0
            fprintf('.');
        end
    end
end

fprintf(' DONE!\n\n');

% Count successful runs
N_success = sum(MC_results.success);
N_failed = N_MONTE_CARLO - N_success;

fprintf('Simulation Summary:\n');
fprintf('  Total runs: %d\n', N_MONTE_CARLO);
fprintf('  Successful: %d (%.1f%%)\n', N_success, 100*N_success/N_MONTE_CARLO);
fprintf('  Failed: %d\n\n', N_failed);

%% ═══════════════════════════════════════════════════════════════
%% SECTION 6: SAFETY EVALUATION
%% ═══════════════════════════════════════════════════════════════

fprintf('═══ SECTION 6: Safety Evaluation ═══\n\n');

% Use only successful runs for safety analysis
valid_idx = MC_results.success;
N_valid = sum(valid_idx);

% Compute probability of infringement
N_hits = sum(MC_results.is_hit(valid_idx));
P_hit = N_hits / N_valid;

% Confidence interval (binomial proportion)
alpha = 0.05;  % 95% confidence
z_alpha = norminv(1 - alpha/2);
P_hit_lower = max(0, P_hit - z_alpha * sqrt(P_hit*(1-P_hit)/N_valid));
P_hit_upper = min(1, P_hit + z_alpha * sqrt(P_hit*(1-P_hit)/N_valid));

% Safety conclusion
is_safe = (P_hit_upper < TLS_TARGET);

fprintf('Probability of Infringement:\n');
fprintf('  P_hit = %.4e (%d hits / %d runs)\n', P_hit, N_hits, N_valid);
fprintf('  95%% Confidence Interval: [%.4e, %.4e]\n', P_hit_lower, P_hit_upper);
fprintf('  Target Level of Safety: %.4e\n', TLS_TARGET);
fprintf('  Margin: %.2f× %s\n', TLS_TARGET / P_hit_upper, ...
        iif(is_safe, '(SAFE)', '(UNSAFE)'));
fprintf('\n');

fprintf('═══════════════════════════════════════════════════\n');
if is_safe
    fprintf('  ✓ SAFETY CONCLUSION: CORRIDOR IS SAFE\n');
    fprintf('  The upper bound of P_hit is below TLS target.\n');
else
    fprintf('  ✗ SAFETY CONCLUSION: CORRIDOR IS NOT SAFE\n');
    fprintf('  The upper bound of P_hit exceeds TLS target.\n');
    fprintf('  Recommend: Widen corridor or reduce TSE design.\n');
end
fprintf('═══════════════════════════════════════════════════\n\n');

%% ═══════════════════════════════════════════════════════════════
%% SECTION 7: STATISTICAL ANALYSIS
%% ═══════════════════════════════════════════════════════════════

fprintf('═══ SECTION 7: Statistical Analysis ═══\n\n');

% FTE statistics (lateral)
FTE_stats.max = max(MC_results.max_lateral_FTE(valid_idx));
FTE_stats.mean = mean(MC_results.max_lateral_FTE(valid_idx));
FTE_stats.std = std(MC_results.max_lateral_FTE(valid_idx));
FTE_stats.p95 = prctile(MC_results.max_lateral_FTE(valid_idx), 95);
FTE_stats.p99 = prctile(MC_results.max_lateral_FTE(valid_idx), 99);

% TSE statistics
TSE_stats.max = max(MC_results.max_TSE(valid_idx));
TSE_stats.mean = mean(MC_results.max_TSE(valid_idx));
TSE_stats.std = std(MC_results.max_TSE(valid_idx));
TSE_stats.p95 = prctile(MC_results.max_TSE(valid_idx), 95);
TSE_stats.p99 = prctile(MC_results.max_TSE(valid_idx), 99);
TSE_stats.sigma_estimated = TSE_stats.std;
TSE_stats.two_sigma_estimated = 2 * TSE_stats.sigma_estimated;

% Distance to boundary
Dist_stats.min = min(MC_results.min_distance_to_boundary(valid_idx));
Dist_stats.mean = mean(MC_results.min_distance_to_boundary(valid_idx));
Dist_stats.std = std(MC_results.min_distance_to_boundary(valid_idx));
Dist_stats.p5 = prctile(MC_results.min_distance_to_boundary(valid_idx), 5);

fprintf('FTE Statistics (Lateral):\n');
fprintf('  Maximum:    %.2f m\n', FTE_stats.max);
fprintf('  Mean:       %.2f m\n', FTE_stats.mean);
fprintf('  Std Dev:    %.2f m\n', FTE_stats.std);
fprintf('  95th %%ile:  %.2f m\n', FTE_stats.p95);
fprintf('  99th %%ile:  %.2f m\n\n', FTE_stats.p99);

fprintf('TSE Statistics:\n');
fprintf('  Maximum:    %.2f m\n', TSE_stats.max);
fprintf('  Mean:       %.2f m\n', TSE_stats.mean);
fprintf('  Std Dev:    %.2f m (σ)\n', TSE_stats.std);
fprintf('  2σ Est.:    %.2f m (vs %.0f m design)\n', TSE_stats.two_sigma_estimated, TSE_2SIGMA_DESIGN_M);
fprintf('  95th %%ile:  %.2f m\n', TSE_stats.p95);
fprintf('  99th %%ile:  %.2f m\n\n', TSE_stats.p99);

fprintf('Distance to Boundary:\n');
fprintf('  Minimum:    %.2f m\n', Dist_stats.min);
fprintf('  Mean:       %.2f m\n', Dist_stats.mean);
fprintf('  Std Dev:    %.2f m\n', Dist_stats.std);
fprintf('  5th %%ile:   %.2f m\n\n', Dist_stats.p5);

%% ═══════════════════════════════════════════════════════════════
%% SECTION 8: VISUALIZATION
%% ═══════════════════════════════════════════════════════════════

fprintf('═══ SECTION 8: Generating Plots ═══\n\n');

% Create timestamp for output files
timestamp = datestr(now, 'yyyymmdd_HHMMSS');

%% Figure 1: TSE Distribution
fprintf('Creating Figure 1: TSE Distribution...\n');
fig1 = figure('Name', 'TSE Distribution', 'Position', [100, 100, 1200, 500]);

subplot(1, 2, 1);
histogram(MC_results.max_TSE(valid_idx), 30, 'Normalization', 'probability', ...
          'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'k');
hold on;
xline(TSE_2SIGMA_DESIGN_M, 'r--', 'LineWidth', 2, 'Label', 'Design 2σ');
xline(TSE_stats.two_sigma_estimated, 'b--', 'LineWidth', 2, 'Label', 'Estimated 2σ');
xline(TSE_stats.p95, 'g--', 'LineWidth', 1.5, 'Label', '95th %ile');
xlabel('Maximum TSE (m)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Probability', 'FontSize', 11, 'FontWeight', 'bold');
title('TSE Distribution (Histogram)', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'northeast');
grid on;

subplot(1, 2, 2);
[f, x] = ecdf(MC_results.max_TSE(valid_idx));
plot(x, f, 'b-', 'LineWidth', 2);
hold on;
xline(TSE_2SIGMA_DESIGN_M, 'r--', 'LineWidth', 2, 'Label', 'Design 2σ');
xline(TSE_stats.two_sigma_estimated, 'b--', 'LineWidth', 2, 'Label', 'Estimated 2σ');
yline(0.95, 'g--', 'LineWidth', 1.5, 'Label', '95% CDF');
xlabel('Maximum TSE (m)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Cumulative Probability', 'FontSize', 11, 'FontWeight', 'bold');
title('TSE Cumulative Distribution (CDF)', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'southeast');
grid on;
ylim([0 1]);

saveas(fig1, sprintf('MC_TSE_Distribution_%s.png', timestamp));
fprintf('  Saved: MC_TSE_Distribution_%s.png\n', timestamp);

%% Figure 2: FTE Distribution
fprintf('Creating Figure 2: FTE Distribution...\n');
fig2 = figure('Name', 'FTE Distribution', 'Position', [150, 150, 1200, 500]);

subplot(1, 2, 1);
histogram(MC_results.max_lateral_FTE(valid_idx), 30, 'Normalization', 'probability', ...
          'FaceColor', [0.8 0.4 0.2], 'EdgeColor', 'k');
hold on;
xline(FTE_stats.mean, 'b--', 'LineWidth', 2, 'Label', 'Mean');
xline(FTE_stats.p95, 'r--', 'LineWidth', 2, 'Label', '95th %ile');
xlabel('Maximum Lateral FTE (m)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Probability', 'FontSize', 11, 'FontWeight', 'bold');
title('FTE Distribution (Histogram)', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'northeast');
grid on;

subplot(1, 2, 2);
[f, x] = ecdf(MC_results.max_lateral_FTE(valid_idx));
plot(x, f, 'r-', 'LineWidth', 2);
hold on;
xline(FTE_stats.p95, 'r--', 'LineWidth', 2, 'Label', '95th %ile');
yline(0.95, 'g--', 'LineWidth', 1.5, 'Label', '95% CDF');
xlabel('Maximum Lateral FTE (m)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Cumulative Probability', 'FontSize', 11, 'FontWeight', 'bold');
title('FTE Cumulative Distribution (CDF)', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'southeast');
grid on;
ylim([0 1]);

saveas(fig2, sprintf('MC_FTE_Distribution_%s.png', timestamp));
fprintf('  Saved: MC_FTE_Distribution_%s.png\n', timestamp);

%% Figure 3: Sample Trajectories
fprintf('Creating Figure 3: Sample Trajectories...\n');
fig3 = figure('Name', 'Sample Trajectories', 'Position', [200, 200, 1000, 800]);

% Select representative samples
n_samples = min(10, N_valid);
sample_idx = find(valid_idx);
sample_idx = sample_idx(round(linspace(1, length(sample_idx), n_samples)));

% Plot reference and corridor boundaries
plot(ref_traj.pos(:,1), ref_traj.pos(:,2), 'k--', 'LineWidth', 3, 'DisplayName', 'Reference');
hold on;
plot(ref_traj.pos(:,1), ref_traj.pos(:,2) + CORRIDOR_HALF_WIDTH_M, 'r--', ...
     'LineWidth', 2, 'DisplayName', 'Corridor Boundary');
plot(ref_traj.pos(:,1), ref_traj.pos(:,2) - CORRIDOR_HALF_WIDTH_M, 'r--', ...
     'LineWidth', 2, 'HandleVisibility', 'off');

% Plot sample trajectories
colors = lines(n_samples);
for i = 1:n_samples
    idx = sample_idx(i);
    traj = MC_results.trajectories{idx};
    if ~isempty(traj)
        if MC_results.is_hit(idx)
            plot(traj.N, traj.E, 'Color', [1 0 0 0.5], 'LineWidth', 1.5, ...
                 'HandleVisibility', iif(i==1, 'on', 'off'), 'DisplayName', 'Hit');
        else
            plot(traj.N, traj.E, 'Color', [colors(i,:) 0.4], 'LineWidth', 1, ...
                 'HandleVisibility', iif(i==1, 'on', 'off'), 'DisplayName', 'Safe');
        end
    end
end

xlabel('North (m)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('East (m)', 'FontSize', 11, 'FontWeight', 'bold');
title(sprintf('Sample Trajectories (N=%d, %d hits)', n_samples, sum(MC_results.is_hit(sample_idx))), ...
      'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'best');
grid on;
axis equal;

saveas(fig3, sprintf('MC_Sample_Trajectories_%s.png', timestamp));
fprintf('  Saved: MC_Sample_Trajectories_%s.png\n', timestamp);

%% Figure 4: Safety Summary
fprintf('Creating Figure 4: Safety Summary Dashboard...\n');
fig4 = figure('Name', 'Safety Summary', 'Position', [250, 250, 1000, 600]);

% Subplot 1: P_hit comparison
subplot(2, 2, 1);
bar_data = [P_hit; TLS_TARGET];
bar_handle = bar(bar_data, 'FaceColor', 'flat');
bar_handle.CData(1,:) = iif(is_safe, [0.2 0.8 0.2], [0.8 0.2 0.2]);
bar_handle.CData(2,:) = [0.5 0.5 0.5];
set(gca, 'XTickLabel', {'Observed P_{hit}', 'TLS Target'});
ylabel('Probability', 'FontSize', 10, 'FontWeight', 'bold');
title('Infringement Probability vs TLS', 'FontSize', 11, 'FontWeight', 'bold');
grid on;
set(gca, 'YScale', 'log');

% Subplot 2: Distance to boundary CDF
subplot(2, 2, 2);
[f, x] = ecdf(MC_results.min_distance_to_boundary(valid_idx));
plot(x, f, 'b-', 'LineWidth', 2);
hold on;
xline(0, 'r--', 'LineWidth', 2, 'Label', 'Boundary');
xlabel('Min Distance to Boundary (m)', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('CDF', 'FontSize', 10, 'FontWeight', 'bold');
title('Distance to Boundary Distribution', 'FontSize', 11, 'FontWeight', 'bold');
legend('Location', 'southeast');
grid on;

% Subplot 3: TSE vs Design
subplot(2, 2, 3);
boxplot([MC_results.max_TSE(valid_idx), repmat(TSE_2SIGMA_DESIGN_M, sum(valid_idx), 1)], ...
        'Labels', {'Observed TSE', 'Design 2σ'});
ylabel('TSE (m)', 'FontSize', 10, 'FontWeight', 'bold');
title('TSE Comparison', 'FontSize', 11, 'FontWeight', 'bold');
grid on;

% Subplot 4: Safety conclusion text
subplot(2, 2, 4);
axis off;
text_str = {
    sprintf('\\bf\\fontsize{14}SAFETY CONCLUSION');
    '';
    sprintf('\\fontsize{12}%s', iif(is_safe, '✓ CORRIDOR IS SAFE', '✗ CORRIDOR IS NOT SAFE'));
    '';
    sprintf('\\fontsize{10}P_{hit} = %.2e', P_hit);
    sprintf('95%% CI: [%.2e, %.2e]', P_hit_lower, P_hit_upper);
    sprintf('TLS Target = %.2e', TLS_TARGET);
    '';
    sprintf('Margin: %.2f×', TLS_TARGET / P_hit_upper);
    '';
    sprintf('Total Runs: %d', N_valid);
    sprintf('Infringements: %d', N_hits);
};
text(0.1, 0.5, text_str, 'VerticalAlignment', 'middle', 'FontSize', 10, ...
     'Interpreter', 'tex', 'BackgroundColor', iif(is_safe, [0.9 1 0.9], [1 0.9 0.9]));

saveas(fig4, sprintf('MC_Safety_Summary_%s.png', timestamp));
fprintf('  Saved: MC_Safety_Summary_%s.png\n', timestamp);

%% ═══════════════════════════════════════════════════════════════
%% SECTION 9: SAVE RESULTS
%% ═══════════════════════════════════════════════════════════════

fprintf('\n═══ SECTION 9: Saving Results ═══\n\n');

% Save all results to MAT file
results_file = sprintf('MC_TSE_Safety_Results_%s.mat', timestamp);
save(results_file, 'MC_results', 'MC_params', 'ref_traj', ...
     'FTE_stats', 'TSE_stats', 'Dist_stats', ...
     'P_hit', 'P_hit_lower', 'P_hit_upper', 'is_safe', ...
     'N_MONTE_CARLO', 'N_valid', 'N_hits', 'TLS_TARGET', ...
     'TSE_2SIGMA_DESIGN_M', 'CORRIDOR_HALF_WIDTH_M');

fprintf('Saved results to: %s\n', results_file);

% Generate text report
report_file = sprintf('MC_TSE_Safety_Report_%s.txt', timestamp);
fid = fopen(report_file, 'w');

fprintf(fid, '╔══════════════════════════════════════════════════════════════╗\n');
fprintf(fid, '║  Monte Carlo TSE Safety Assessment Report                   ║\n');
fprintf(fid, '║  Generated: %s                                  ║\n', datestr(now));
fprintf(fid, '╚══════════════════════════════════════════════════════════════╝\n\n');

fprintf(fid, '═══ SCENARIO PARAMETERS ═══\n\n');
fprintf(fid, 'Trajectory:\n');
fprintf(fid, '  Length: %.0f m\n', SEGMENT_LENGTH_M);
fprintf(fid, '  Altitude: %.0f ft\n', ALTITUDE_FT);
fprintf(fid, '  Ground Speed: %.0f kt\n', GROUND_SPEED_KT);
fprintf(fid, '  Duration: %.0f s\n\n', SIMULATION_TIME_S);

fprintf(fid, 'TSE Design:\n');
fprintf(fid, '  2σ Design: %.0f m\n', TSE_2SIGMA_DESIGN_M);
fprintf(fid, '  Corridor Width: ±%.0f m\n\n', CORRIDOR_HALF_WIDTH_M);

fprintf(fid, 'Monte Carlo:\n');
fprintf(fid, '  Total Runs: %d\n', N_MONTE_CARLO);
fprintf(fid, '  Successful: %d\n', N_valid);
fprintf(fid, '  Failed: %d\n\n', N_failed);

fprintf(fid, '═══ SAFETY RESULTS ═══\n\n');
fprintf(fid, 'Probability of Infringement:\n');
fprintf(fid, '  P_hit = %.4e (%d / %d)\n', P_hit, N_hits, N_valid);
fprintf(fid, '  95%% Confidence Interval: [%.4e, %.4e]\n\n', P_hit_lower, P_hit_upper);

fprintf(fid, 'Target Level of Safety:\n');
fprintf(fid, '  TLS = %.4e\n', TLS_TARGET);
fprintf(fid, '  Margin: %.2fx\n\n', TLS_TARGET / P_hit_upper);

fprintf(fid, 'CONCLUSION:\n');
if is_safe
    fprintf(fid, '  ✓ CORRIDOR IS SAFE\n');
    fprintf(fid, '  Upper bound of P_hit is below TLS target.\n\n');
else
    fprintf(fid, '  ✗ CORRIDOR IS NOT SAFE\n');
    fprintf(fid, '  Upper bound of P_hit exceeds TLS target.\n');
    fprintf(fid, '  RECOMMENDATION: Widen corridor or reduce operational TSE.\n\n');
end

fprintf(fid, '═══ STATISTICS ═══\n\n');
fprintf(fid, 'FTE (Lateral):\n');
fprintf(fid, '  Max: %.2f m\n', FTE_stats.max);
fprintf(fid, '  Mean: %.2f m\n', FTE_stats.mean);
fprintf(fid, '  Std: %.2f m\n', FTE_stats.std);
fprintf(fid, '  95th %%ile: %.2f m\n\n', FTE_stats.p95);

fprintf(fid, 'TSE:\n');
fprintf(fid, '  Max: %.2f m\n', TSE_stats.max);
fprintf(fid, '  Mean: %.2f m\n', TSE_stats.mean);
fprintf(fid, '  Std (σ): %.2f m\n', TSE_stats.std);
fprintf(fid, '  2σ Estimated: %.2f m (Design: %.0f m)\n', ...
        TSE_stats.two_sigma_estimated, TSE_2SIGMA_DESIGN_M);
fprintf(fid, '  95th %%ile: %.2f m\n\n', TSE_stats.p95);

fprintf(fid, 'Distance to Boundary:\n');
fprintf(fid, '  Min: %.2f m\n', Dist_stats.min);
fprintf(fid, '  Mean: %.2f m\n', Dist_stats.mean);
fprintf(fid, '  5th %%ile: %.2f m\n\n', Dist_stats.p5);

fprintf(fid, '════════════════════════════════════════════════════════\n');
fprintf(fid, 'End of Report\n');

fclose(fid);

fprintf('Saved report to: %s\n\n', report_file);

%% ═══════════════════════════════════════════════════════════════
%% SECTION 10: FINAL SUMMARY
%% ═══════════════════════════════════════════════════════════════

fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  MONTE CARLO TSE SAFETY ASSESSMENT COMPLETE                 ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

fprintf('Files Generated:\n');
fprintf('  • %s\n', results_file);
fprintf('  • %s\n', report_file);
fprintf('  • MC_TSE_Distribution_%s.png\n', timestamp);
fprintf('  • MC_FTE_Distribution_%s.png\n', timestamp);
fprintf('  • MC_Sample_Trajectories_%s.png\n', timestamp);
fprintf('  • MC_Safety_Summary_%s.png\n\n', timestamp);

fprintf('Key Results:\n');
fprintf('  P_hit = %.4e (95%% CI: [%.4e, %.4e])\n', P_hit, P_hit_lower, P_hit_upper);
fprintf('  TLS Target = %.4e\n', TLS_TARGET);
fprintf('  Safety: %s\n\n', iif(is_safe, 'SAFE ✓', 'NOT SAFE ✗'));

fprintf('═════════════════════════════════════════════════════════════\n');

%% ═══════════════════════════════════════════════════════════════
%% HELPER FUNCTION: iif (inline if)
%% ═══════════════════════════════════════════════════════════════
function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end

%% ═══════════════════════════════════════════════════════════════
%% NESTED FUNCTION: run_single_MC_simulation
%% ═══════════════════════════════════════════════════════════════
function result = run_single_MC_simulation(run_id, MC_params, ref_traj, ...
                                            corridor_width, model_name)
    % Initialize result structure
    result = struct();
    result.success = false;
    result.max_lateral_FTE = NaN;
    result.rms_lateral_FTE = NaN;
    result.max_TSE = NaN;
    result.rms_TSE = NaN;
    result.min_distance_to_boundary = NaN;
    result.is_hit = false;
    result.trajectory = [];
    
    try
        % Extract parameters for this run
        wind_E = MC_params.wind_E_ms(run_id);
        wind_N = MC_params.wind_N_ms(run_id);
        wind_D = MC_params.wind_D_ms(run_id);
        y0 = MC_params.y0_m(run_id);
        heading_err = MC_params.heading_err_deg(run_id);
        nse_sigma = MC_params.nse_sigma_m(run_id);
        
        % Setup GUAM simulation
        simSetup;
        
        % Configure for BASELINE controller and TIMESERIES reference
        userStruct.variants.refInputType = 3;  % TIMESERIES
        userStruct.variants.ctrlType = 2;      % BASELINE
        
        % Apply initial conditions
        ref_pos_modified = ref_traj.pos;
        ref_pos_modified(:, 2) = ref_pos_modified(:, 2) + y0;  % Lateral offset
        
        % Modify heading
        ref_chi_modified = ref_traj.chi + deg2rad(heading_err);
        
        % Create RefInput structure
        RefInput.Vel_bIc_des = ref_traj.Vel_bIc_des;
        RefInput.pos_des = timeseries(ref_pos_modified, ref_traj.time);
        RefInput.chi_des = timeseries(ref_chi_modified, ref_traj.time);
        RefInput.chi_dot_des = ref_traj.chi_dot_des;
        RefInput.vel_des = ref_traj.vel_des;
        
        target.RefInput = RefInput;
        simSetup;
        
        % Apply wind disturbance
        apply_wind_to_GUAM(wind_N, wind_E, wind_D);
        
        % Run simulation
        SimIn.StopTime = ref_traj.time(end);
        sim(model_name);
        
        % Extract results
        logsout = evalin('base', 'logsout');
        SimOut = logsout{1}.Values;
        
        % Get actual trajectory
        time_sim = SimOut.Vehicle.Sensor.time.Data;
        N_actual = SimOut.Vehicle.Sensor.North.Data;
        E_actual = SimOut.Vehicle.Sensor.East.Data;
        D_actual = SimOut.Vehicle.Sensor.Down.Data;
        
        % Compute lateral error (FTE)
        e_lateral = compute_lateral_error(N_actual, E_actual, ref_traj);
        
        % Add navigation sensor error (NSE)
        nse = nse_sigma * randn(size(e_lateral));
        
        % Compute TSE
        tse = compute_TSE(e_lateral, nse);
        
        % Compute distance to boundary
        d_min = compute_min_distance_to_boundary(E_actual, corridor_width);
        
        % Store results
        result.max_lateral_FTE = max(abs(e_lateral));
        result.rms_lateral_FTE = sqrt(mean(e_lateral.^2));
        result.max_TSE = max(abs(tse));
        result.rms_TSE = sqrt(mean(tse.^2));
        result.min_distance_to_boundary = d_min;
        result.is_hit = (d_min < 0);
        result.trajectory.N = N_actual;
        result.trajectory.E = E_actual;
        result.trajectory.D = D_actual;
        result.trajectory.time = time_sim;
        result.success = true;
        
    catch ME
        % Simulation failed
        result.success = false;
    end
end
