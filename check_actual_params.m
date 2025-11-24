load('/home/user/uploaded_files/$RX597M5.mat');

fprintf('\n╔══════════════════════════════════════════════════════════╗\n');
fprintf('║  실제 시뮬레이션 파라미터 확인                           ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n\n');

fprintf('1. REFERENCE TRAJECTORY:\n');
fprintf('   시간: %.2f ~ %.2f 초\n', ref_traj.time(1), ref_traj.time(end));
fprintf('   North: %.1f ~ %.1f m\n', min(ref_traj.pos(:,1)), max(ref_traj.pos(:,1)));
fprintf('   East: %.1f ~ %.1f m\n', min(ref_traj.pos(:,2)), max(ref_traj.pos(:,2)));
fprintf('   Down: %.1f ~ %.1f m\n\n', min(ref_traj.pos(:,3)), max(ref_traj.pos(:,3)));

fprintf('2. ACTUAL TRAJECTORY (Sample 1):\n');
traj1 = MC_results.trajectories{1};
fprintf('   시뮬레이션 시간: %.2f 초\n', traj1.time(end));
fprintf('   최종 North: %.1f m\n', max(traj1.N));
fprintf('   최종 East: %.1f m\n', traj1.E(end));
fprintf('   평균 속도: %.2f m/s\n\n', max(traj1.N) / traj1.time(end));

fprintf('3. VELOCITY DATA:\n');
if isfield(ref_traj, 'vel_des')
    vel_data = ref_traj.vel_des.Data;
    if size(vel_data, 2) == 3
        vel_mag = sqrt(sum(vel_data.^2, 2));
        fprintf('   속도 범위: %.2f ~ %.2f m/s\n', min(vel_mag), max(vel_mag));
        fprintf('   평균 속도: %.2f m/s\n', mean(vel_mag));
    else
        fprintf('   속도 데이터: %.2f m/s\n', mean(vel_data));
    end
end

fprintf('\n4. 왜 500m에서 멈췄는가?\n');
fprintf('   이론: 30초 × 46.3 m/s = 1,389 m\n');
fprintf('   실제: %.2f초 × %.2f m/s = %.1f m\n', ...
        traj1.time(end), max(traj1.N)/traj1.time(end), max(traj1.N));
fprintf('\n   → 시뮬레이션 시간이 %.2f초로 설정되어 있었음!\n', traj1.time(end));
fprintf('   → 30초가 아니라 %.2f초만 돌렸기 때문!\n\n', traj1.time(end));

