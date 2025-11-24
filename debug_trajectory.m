% Load and analyze trajectory
load('/home/user/uploaded_files/$RX597M5.mat');

fprintf('\n╔═══════════════════════════════════════════════════════════╗\n');
fprintf('║  TRAJECTORY DEBUG ANALYSIS                                ║\n');
fprintf('╚═══════════════════════════════════════════════════════════╝\n\n');

%% 1. Reference Trajectory Analysis
fprintf('1. REFERENCE TRAJECTORY:\n');
fprintf('   Length: %d points\n', length(ref_traj.time));
fprintf('   Time: %.2f to %.2f sec\n', ref_traj.time(1), ref_traj.time(end));
fprintf('   Position range:\n');
fprintf('     North: %.1f to %.1f m\n', min(ref_traj.pos(:,1)), max(ref_traj.pos(:,1)));
fprintf('     East:  %.1f to %.1f m\n', min(ref_traj.pos(:,2)), max(ref_traj.pos(:,2)));
fprintf('     Down:  %.1f to %.1f m\n\n', min(ref_traj.pos(:,3)), max(ref_traj.pos(:,3)));

%% 2. Check if trajectory is straight
East_variation = max(ref_traj.pos(:,2)) - min(ref_traj.pos(:,2));
fprintf('2. IS IT REALLY STRAIGHT?\n');
fprintf('   East variation in ref: %.6f m\n', East_variation);
if East_variation < 0.001
    fprintf('   → YES, perfectly straight!\n\n');
else
    fprintf('   → NO, has curvature!\n\n');
end

%% 3. Velocity profile
if isfield(ref_traj, 'vel_des')
    fprintf('3. VELOCITY PROFILE:\n');
    vel_ts = ref_traj.vel_des;
    vel_data = vel_ts.Data;
    fprintf('   Min: %.2f m/s\n', min(vel_data));
    fprintf('   Max: %.2f m/s\n', max(vel_data));
    fprintf('   Mean: %.2f m/s\n', mean(vel_data));
    fprintf('   Std: %.2f m/s\n\n', std(vel_data));
    
    % Check for speed changes
    if std(vel_data) > 1.0
        fprintf('   → Speed VARIES significantly!\n\n');
    else
        fprintf('   → Speed is constant\n\n');
    end
end

%% 4. Heading analysis
if isfield(ref_traj, 'chi')
    fprintf('4. HEADING ANALYSIS:\n');
    heading_deg = rad2deg(ref_traj.chi);
    fprintf('   Min: %.2f deg\n', min(heading_deg));
    fprintf('   Max: %.2f deg\n', max(heading_deg));
    fprintf('   Mean: %.2f deg\n', mean(heading_deg));
    fprintf('   Std: %.2f deg\n\n', std(heading_deg));
end

%% 5. Actual trajectory analysis
fprintf('5. ACTUAL TRAJECTORIES (Sample 1):\n');
traj1 = MC_results.trajectories{1};
fprintf('   North: %.1f to %.1f m (range: %.1f)\n', ...
        min(traj1.N), max(traj1.N), max(traj1.N)-min(traj1.N));
fprintf('   East: %.1f to %.1f m (range: %.1f)\n', ...
        min(traj1.E), max(traj1.E), max(traj1.E)-min(traj1.E));

% Find peak deviation location
[max_E, idx_max] = max(abs(traj1.E));
fprintf('   Max East deviation: %.1f m at North = %.1f m\n\n', max_E, traj1.N(idx_max));

%% 6. Time series analysis
fprintf('6. WHEN DOES MAX DEVIATION OCCUR?\n');
for i = 1:min(3, length(MC_results.trajectories))
    traj = MC_results.trajectories{i};
    [max_E, idx_max] = max(abs(traj.E));
    time_at_max = traj.time(idx_max);
    north_at_max = traj.N(idx_max);
    fprintf('   Sample %d: Max FTE at t=%.2f s, North=%.1f m, East=%.1f m\n', ...
            i, time_at_max, north_at_max, traj.E(idx_max));
end
fprintf('\n');

%% 7. East position time series
fprintf('7. EAST POSITION vs TIME (Sample 1):\n');
fprintf('   Time    North    East\n');
fprintf('   -----   ------   -----\n');
for i = 1:5:length(traj1.time)
    fprintf('   %5.1f   %6.1f   %5.1f\n', traj1.time(i), traj1.N(i), traj1.E(i));
end
fprintf('   ...\n');
idx_peak = find(abs(traj1.E) == max(abs(traj1.E)));
fprintf('   %5.1f   %6.1f   %5.1f  ← PEAK\n', ...
        traj1.time(idx_peak), traj1.N(idx_peak), traj1.E(idx_peak));
fprintf('\n');

fprintf('═══════════════════════════════════════════════════════════\n');
fprintf('Analysis complete!\n');
