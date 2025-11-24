% analyze_results.m
% V2 결과 파일(.mat)을 분석하는 유틸리티 스크립트

function analyze_results(filename)
% 사용법:
%   analyze_results('sim_results_traj1_fail1_20251120_093015.mat')
%
% 인자가 없으면 가장 최근 파일을 자동으로 찾음

    if nargin < 1
        % 가장 최근 결과 파일 찾기
        files = dir('sim_results_*.mat');
        if isempty(files)
            error('No sim_results_*.mat files found in current directory');
        end
        [~, idx] = max([files.datenum]);
        filename = files(idx).name;
        fprintf('📂 자동 선택된 파일: %s\n\n', filename);
    end
    
    % 파일 로드
    fprintf('🔄 로딩 중: %s\n', filename);
    data = load(filename);
    results = data.results;
    fprintf('✅ 로드 완료!\n\n');
    
    %% 1. 기본 정보
    fprintf('╔══════════════════════════════════════════════════════════════╗\n');
    fprintf('║                    시뮬레이션 기본 정보                      ║\n');
    fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');
    
    fprintf('📅 실행 시간: %s\n', results.config.timestamp);
    fprintf('📍 궤적 번호: %d\n', results.config.traj_run_num);
    fprintf('💥 실패 시나리오: %d\n', results.config.fail_run_num);
    fprintf('⚙️  실패 활성화: %s\n\n', mat2str(results.config.enable_failure));
    
    %% 2. 시뮬레이션 결과
    fprintf('╔══════════════════════════════════════════════════════════════╗\n');
    fprintf('║                    시뮬레이션 결과                           ║\n');
    fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');
    
    if results.simulation.success
        fprintf('✅ 상태: 성공\n');
        fprintf('⏱️  실행 시간: %.1f초\n', results.simulation.elapsed_time);
    else
        fprintf('❌ 상태: 실패\n');
        fprintf('⏱️  실행 시간: %.1f초\n', results.simulation.elapsed_time);
        fprintf('⚠️  에러: %s\n', results.simulation.error);
    end
    fprintf('\n');
    
    %% 3. 궤적 정보
    fprintf('╔══════════════════════════════════════════════════════════════╗\n');
    fprintf('║                    궤적 정보                                 ║\n');
    fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');
    
    fprintf('⏱️  계획된 시간: %.1f초\n', results.trajectory.duration);
    fprintf('📍 초기 위치 (NED): [%.1f, %.1f, %.1f] ft\n', ...
        results.trajectory.initial_pos(1), ...
        results.trajectory.initial_pos(2), ...
        results.trajectory.initial_pos(3));
    fprintf('🚀 초기 속도: [%.1f, %.1f, %.1f] ft/s\n', ...
        results.trajectory.initial_vel(1), ...
        results.trajectory.initial_vel(2), ...
        results.trajectory.initial_vel(3));
    fprintf('🎯 웨이포인트: X=%d, Y=%d, Z=%d\n\n', ...
        results.trajectory.num_waypoints(1), ...
        results.trajectory.num_waypoints(2), ...
        results.trajectory.num_waypoints(3));
    
    %% 4. 실패 시나리오 (있으면)
    if results.config.enable_failure && ~isempty(fieldnames(results.failure))
        fprintf('╔══════════════════════════════════════════════════════════════╗\n');
        fprintf('║                    실패 시나리오                             ║\n');
        fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');
        
        if isfield(results.failure, 'active_surface_failures') && ...
           ~isempty(results.failure.active_surface_failures)
            surf_failures = results.failure.active_surface_failures;
            fprintf('🛬 표면 제어 실패: %d개\n', length(surf_failures));
            for i = 1:length(surf_failures)
                idx = surf_failures(i);
                fprintf('   Surface #%d:\n', idx);
                fprintf('      Type: %d\n', results.failure.surfaces.FailInit(idx));
                fprintf('      시작: %.1f초\n', results.failure.surfaces.InitTime(idx));
                fprintf('      종료: %.1f초\n', results.failure.surfaces.StopTime(idx));
                fprintf('      PreScale: %.3f\n', results.failure.surfaces.PreScale(idx));
                fprintf('      PostScale: %.3f\n', results.failure.surfaces.PostScale(idx));
            end
            fprintf('\n');
        end
        
        if isfield(results.failure, 'active_prop_failures') && ...
           ~isempty(results.failure.active_prop_failures)
            prop_failures = results.failure.active_prop_failures;
            fprintf('🚁 프로펠러 실패: %d개\n', length(prop_failures));
            for i = 1:length(prop_failures)
                idx = prop_failures(i);
                fprintf('   Prop #%d:\n', idx);
                fprintf('      Type: %d\n', results.failure.props.FailInit(idx));
                fprintf('      시작: %.1f초\n', results.failure.props.InitTime(idx));
                fprintf('      종료: %.1f초\n', results.failure.props.StopTime(idx));
                fprintf('      PreScale: %.3f\n', results.failure.props.PreScale(idx));
                fprintf('      PostScale: %.3f\n', results.failure.props.PostScale(idx));
            end
            fprintf('\n');
        end
    end
    
    %% 5. 데이터 요약 (있으면)
    if isfield(results, 'data') && ~isempty(fieldnames(results.data))
        fprintf('╔══════════════════════════════════════════════════════════════╗\n');
        fprintf('║                    데이터 요약                               ║\n');
        fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');
        
        fprintf('📊 데이터 포인트: %d개\n', results.data.num_points);
        fprintf('⏱️  시뮬레이션 시간: %.1f / %.1f초 (%.1f%%)\n', ...
            results.data.sim_time_reached, ...
            results.trajectory.duration, ...
            100 * results.data.sim_time_reached / results.trajectory.duration);
        
        % 최종 상태
        fprintf('\n📍 최종 위치 (NED): [%.1f, %.1f, %.1f] ft\n', ...
            results.data.pos_NED(end,1), ...
            results.data.pos_NED(end,2), ...
            results.data.pos_NED(end,3));
        fprintf('🛫 최종 고도: %.1f ft\n', -results.data.pos_NED(end,3));
        
        % 이동 거리
        distance_ft = sqrt(results.data.pos_NED(end,1)^2 + results.data.pos_NED(end,2)^2);
        distance_nm = distance_ft / 6076.12;
        fprintf('📏 이동 거리: %.1f ft (%.3f nm)\n', distance_ft, distance_nm);
        
        % 평균 속도
        ground_speed = sqrt(results.data.vel_body(:,1).^2 + results.data.vel_body(:,2).^2);
        avg_speed_fps = mean(ground_speed);
        avg_speed_knots = avg_speed_fps * 0.592484;
        fprintf('🚀 평균 속도: %.1f ft/s (%.1f knots)\n', avg_speed_fps, avg_speed_knots);
        
        % 최종 자세
        fprintf('🎯 최종 자세:\n');
        fprintf('   Roll:  %.1f°\n', rad2deg(results.data.euler(end,1)));
        fprintf('   Pitch: %.1f°\n', rad2deg(results.data.euler(end,2)));
        fprintf('   Yaw:   %.1f°\n', rad2deg(results.data.euler(end,3)));
        fprintf('\n');
        
        %% 6. 실패 후 비행 시간 (해당되면)
        if results.config.enable_failure && isfield(results.failure, 'active_surface_failures')
            if ~isempty(results.failure.active_surface_failures)
                surf_failures = results.failure.active_surface_failures;
                first_fail_time = min(results.failure.surfaces.InitTime(surf_failures));
                if first_fail_time <= results.data.sim_time_reached
                    time_after_failure = results.data.sim_time_reached - first_fail_time;
                    fprintf('💥 실패 후 비행 시간: %.1f초\n', time_after_failure);
                    fprintf('   (실패 시작: %.1f초, 종료: %.1f초)\n\n', ...
                        first_fail_time, results.data.sim_time_reached);
                end
            end
            if ~isempty(results.failure.active_prop_failures)
                prop_failures = results.failure.active_prop_failures;
                first_fail_time = min(results.failure.props.InitTime(prop_failures));
                if first_fail_time <= results.data.sim_time_reached
                    time_after_failure = results.data.sim_time_reached - first_fail_time;
                    fprintf('💥 프로펠러 실패 후 비행 시간: %.1f초\n', time_after_failure);
                    fprintf('   (실패 시작: %.1f초, 종료: %.1f초)\n\n', ...
                        first_fail_time, results.data.sim_time_reached);
                end
            end
        end
    else
        fprintf('╔══════════════════════════════════════════════════════════════╗\n');
        fprintf('║                    데이터 없음                               ║\n');
        fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');
        fprintf('⚠️  시뮬레이션이 데이터를 생성하기 전에 실패했습니다.\n\n');
    end
    
    %% 7. 빠른 플롯 생성 옵션
    fprintf('╔══════════════════════════════════════════════════════════════╗\n');
    fprintf('║                    추가 작업                                 ║\n');
    fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');
    
    if isfield(results, 'data') && ~isempty(fieldnames(results.data))
        fprintf('📊 빠른 플롯 생성:\n');
        fprintf('   >> plot_trajectory(results)   %% 3D 궤적\n');
        fprintf('   >> plot_position(results)     %% 위치 vs 시간\n');
        fprintf('   >> plot_attitude(results)     %% 자세 vs 시간\n');
        fprintf('   >> plot_velocity(results)     %% 속도 vs 시간\n');
        fprintf('\n');
        
        fprintf('🔍 데이터 탐색:\n');
        fprintf('   >> results.data.time         %% 시간 배열\n');
        fprintf('   >> results.data.pos_NED      %% 위치 [N,E,D]\n');
        fprintf('   >> results.data.vel_body     %% 속도 [u,v,w]\n');
        fprintf('   >> results.data.euler        %% 자세 [roll,pitch,yaw]\n');
        fprintf('\n');
    end
    
    fprintf('💡 팁: 결과를 워크스페이스에 저장하려면:\n');
    fprintf('   >> my_results = load(''%s'');\n', filename);
    fprintf('   >> my_results.results.data.pos_NED(end,:)\n\n');
    
    fprintf('════════════════════════════════════════════════════════════════\n');
end

%% Helper plotting functions
function plot_trajectory(results)
    if ~isfield(results, 'data') || isempty(fieldnames(results.data))
        error('No data available to plot');
    end
    
    pos_NED = results.data.pos_NED;
    
    figure('Name', '3D Trajectory Quick View');
    plot3(pos_NED(:,1), pos_NED(:,2), -pos_NED(:,3), 'b-', 'LineWidth', 2);
    hold on;
    plot3(pos_NED(1,1), pos_NED(1,2), -pos_NED(1,3), 'go', 'MarkerSize', 12, 'LineWidth', 2);
    plot3(pos_NED(end,1), pos_NED(end,2), -pos_NED(end,3), 'ro', 'MarkerSize', 12, 'LineWidth', 2);
    
    xlabel('North (ft)'); ylabel('East (ft)'); zlabel('Up (ft)');
    title(sprintf('Trajectory (T%d F%d)', ...
        results.config.traj_run_num, results.config.fail_run_num));
    legend('Path', 'Start', 'End');
    grid on; axis equal; view(45, 30);
end

function plot_position(results)
    if ~isfield(results, 'data') || isempty(fieldnames(results.data))
        error('No data available to plot');
    end
    
    time = results.data.time;
    pos = results.data.pos_NED;
    
    figure('Name', 'Position vs Time');
    subplot(3,1,1); plot(time, pos(:,1), 'b-', 'LineWidth', 1.5);
    ylabel('North (ft)'); grid on; title('Position Components');
    subplot(3,1,2); plot(time, pos(:,2), 'r-', 'LineWidth', 1.5);
    ylabel('East (ft)'); grid on;
    subplot(3,1,3); plot(time, -pos(:,3), 'g-', 'LineWidth', 1.5);
    ylabel('Altitude (ft)'); xlabel('Time (s)'); grid on;
end

function plot_attitude(results)
    if ~isfield(results, 'data') || isempty(fieldnames(results.data))
        error('No data available to plot');
    end
    
    time = results.data.time;
    euler = results.data.euler;
    
    figure('Name', 'Attitude vs Time');
    subplot(3,1,1); plot(time, rad2deg(euler(:,1)), 'b-', 'LineWidth', 1.5);
    ylabel('Roll (deg)'); grid on; title('Attitude');
    subplot(3,1,2); plot(time, rad2deg(euler(:,2)), 'r-', 'LineWidth', 1.5);
    ylabel('Pitch (deg)'); grid on;
    subplot(3,1,3); plot(time, rad2deg(euler(:,3)), 'g-', 'LineWidth', 1.5);
    ylabel('Yaw (deg)'); xlabel('Time (s)'); grid on;
end

function plot_velocity(results)
    if ~isfield(results, 'data') || isempty(fieldnames(results.data))
        error('No data available to plot');
    end
    
    time = results.data.time;
    vel = results.data.vel_body;
    ground_speed = sqrt(vel(:,1).^2 + vel(:,2).^2) * 0.592484;  % to knots
    
    figure('Name', 'Velocity vs Time');
    subplot(2,1,1); plot(time, ground_speed, 'b-', 'LineWidth', 1.5);
    ylabel('Ground Speed (knots)'); grid on; title('Velocity');
    subplot(2,1,2); plot(time, -vel(:,3), 'r-', 'LineWidth', 1.5);
    ylabel('Vertical Speed (ft/s)'); xlabel('Time (s)'); grid on;
end
