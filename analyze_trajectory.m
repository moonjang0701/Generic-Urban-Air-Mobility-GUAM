% Quick analysis of uploaded results
load('/home/user/uploaded_files/$RX597M5.mat');

fprintf('=== TRAJECTORY ANALYSIS ===\n\n');

% Check what variables are loaded
fprintf('Loaded variables:\n');
whos

fprintf('\n=== Reference Trajectory ===\n');
if exist('ref_traj', 'var')
    fprintf('Time range: %.2f to %.2f seconds\n', ref_traj.time(1), ref_traj.time(end));
    fprintf('Position range:\n');
    fprintf('  North: %.1f to %.1f m\n', min(ref_traj.pos(:,1)), max(ref_traj.pos(:,1)));
    fprintf('  East: %.1f to %.1f m\n', min(ref_traj.pos(:,2)), max(ref_traj.pos(:,2)));
    fprintf('  Down: %.1f to %.1f m\n', min(ref_traj.pos(:,3)), max(ref_traj.pos(:,3)));
end

fprintf('\n=== Sample Trajectories ===\n');
if exist('MC_results', 'var') && isfield(MC_results, 'trajectories')
    for i = 1:min(3, length(MC_results.trajectories))
        traj = MC_results.trajectories{i};
        if ~isempty(traj)
            fprintf('\nSample %d:\n', i);
            fprintf('  North: %.1f to %.1f m (range: %.1f m)\n', ...
                    min(traj.N), max(traj.N), max(traj.N) - min(traj.N));
            fprintf('  East: %.1f to %.1f m (range: %.1f m)\n', ...
                    min(traj.E), max(traj.E), max(traj.E) - min(traj.E));
            fprintf('  Max East deviation: %.1f m\n', max(abs(traj.E)));
            
            % Find where max deviation occurs
            [max_E, idx_max] = max(abs(traj.E));
            fprintf('  Max deviation at North = %.1f m\n', traj.N(idx_max));
        end
    end
end

fprintf('\n=== Wind Parameters ===\n');
if exist('MC_params', 'var')
    fprintf('Wind East (m/s): mean=%.2f, std=%.2f, range=[%.2f, %.2f]\n', ...
            mean(MC_params.wind_E_ms), std(MC_params.wind_E_ms), ...
            min(MC_params.wind_E_ms), max(MC_params.wind_E_ms));
end

fprintf('\n=== FTE Statistics ===\n');
if exist('FTE_stats', 'var')
    disp(FTE_stats);
end

