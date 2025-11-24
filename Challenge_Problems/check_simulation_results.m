% check_simulation_results.m
% 시뮬레이션 실패 후 결과 확인 스크립트

fprintf('\n=== Simulation Results Check ===\n\n');

% 1. 워크스페이스에 'out' 변수가 있는지 확인
if exist('out', 'var')
    fprintf('✅ ''out'' variable exists in workspace\n\n');
    
    % out 구조체 필드 확인
    fprintf('Fields in ''out'' structure:\n');
    disp(fieldnames(out));
    fprintf('\n');
    
    % 시뮬레이션 시간 확인
    if isfield(out, 'tout')
        fprintf('Simulation time range: %.3f to %.3f seconds\n', out.tout(1), out.tout(end));
        fprintf('Total simulation points: %d\n\n', length(out.tout));
    end
    
    % 위치 데이터 확인
    if isfield(out, 'logsout')
        fprintf('Checking logsout data...\n');
        try
            % Position 데이터 추출 시도
            pos_elem = out.logsout.getElement('VehStates');
            if ~isempty(pos_elem)
                veh_data = pos_elem.Values;
                if isfield(veh_data, 'PositionNED')
                    pos_ned = veh_data.PositionNED.Data;
                    fprintf('  Position NED data available: %d samples\n', size(pos_ned, 1));
                    fprintf('  Final position: [%.2f, %.2f, %.2f] ft\n', ...
                            pos_ned(end,1), pos_ned(end,2), pos_ned(end,3));
                end
                
                if isfield(veh_data, 'VelocityBody')
                    vel_body = veh_data.VelocityBody.Data;
                    fprintf('  Velocity data available: %d samples\n', size(vel_body, 1));
                    fprintf('  Final velocity: [%.2f, %.2f, %.2f] ft/s\n', ...
                            vel_body(end,1), vel_body(end,2), vel_body(end,3));
                end
                
                if isfield(veh_data, 'EulerAngles')
                    euler = veh_data.EulerAngles.Data;
                    fprintf('  Attitude data available: %d samples\n', size(euler, 1));
                    fprintf('  Final Euler angles: [%.2f, %.2f, %.2f] deg\n', ...
                            rad2deg(euler(end,1)), rad2deg(euler(end,2)), rad2deg(euler(end,3)));
                end
            end
        catch ME
            fprintf('  ⚠️ Error accessing logsout: %s\n', ME.message);
        end
        fprintf('\n');
    end
    
    % 에러/경고 메시지 확인
    if isfield(out, 'ErrorMessage')
        fprintf('❌ Error Message: %s\n\n', out.ErrorMessage);
    end
    
    % SimulationMetadata 확인
    if isfield(out, 'SimulationMetadata')
        fprintf('Simulation Metadata:\n');
        metadata = out.SimulationMetadata;
        if isfield(metadata, 'ExecutionInfo')
            exec_info = metadata.ExecutionInfo;
            fprintf('  Execution Status: %s\n', exec_info.Status);
            if isfield(exec_info, 'StopEvent')
                fprintf('  Stop Event: %s\n', exec_info.StopEvent);
            end
        end
        fprintf('\n');
    end
    
    % 그래프 생성 여부 확인
    fprintf('=== Attempting to create plots from available data ===\n');
    try
        % 간단한 위치 플롯 시도
        if isfield(out, 'logsout')
            pos_elem = out.logsout.getElement('VehStates');
            if ~isempty(pos_elem)
                veh_data = pos_elem.Values;
                if isfield(veh_data, 'PositionNED')
                    pos_ned = veh_data.PositionNED.Data;
                    time = veh_data.PositionNED.Time;
                    
                    figure('Name', 'Partial Simulation Results', 'Position', [100, 100, 1200, 800]);
                    
                    % 3D 궤적
                    subplot(2,2,1);
                    plot3(pos_ned(:,2), pos_ned(:,1), -pos_ned(:,3), 'b-', 'LineWidth', 2);
                    grid on;
                    xlabel('East (ft)');
                    ylabel('North (ft)');
                    zlabel('Up (ft)');
                    title('3D Trajectory (Before Failure)');
                    axis equal;
                    
                    % 위치 vs 시간
                    subplot(2,2,2);
                    plot(time, pos_ned(:,1), 'r-', 'DisplayName', 'North'); hold on;
                    plot(time, pos_ned(:,2), 'g-', 'DisplayName', 'East');
                    plot(time, -pos_ned(:,3), 'b-', 'DisplayName', 'Up');
                    grid on;
                    xlabel('Time (s)');
                    ylabel('Position (ft)');
                    title('Position vs Time');
                    legend('Location', 'best');
                    
                    % 속도 (있으면)
                    if isfield(veh_data, 'VelocityBody')
                        vel_body = veh_data.VelocityBody.Data;
                        vel_time = veh_data.VelocityBody.Time;
                        
                        subplot(2,2,3);
                        plot(vel_time, vel_body(:,1), 'r-', 'DisplayName', 'u'); hold on;
                        plot(vel_time, vel_body(:,2), 'g-', 'DisplayName', 'v');
                        plot(vel_time, vel_body(:,3), 'b-', 'DisplayName', 'w');
                        grid on;
                        xlabel('Time (s)');
                        ylabel('Velocity (ft/s)');
                        title('Body Velocity vs Time');
                        legend('Location', 'best');
                    end
                    
                    % 자세 (있으면)
                    if isfield(veh_data, 'EulerAngles')
                        euler = veh_data.EulerAngles.Data;
                        euler_time = veh_data.EulerAngles.Time;
                        
                        subplot(2,2,4);
                        plot(euler_time, rad2deg(euler(:,1)), 'r-', 'DisplayName', 'Roll'); hold on;
                        plot(euler_time, rad2deg(euler(:,2)), 'g-', 'DisplayName', 'Pitch');
                        plot(euler_time, rad2deg(euler(:,3)), 'b-', 'DisplayName', 'Yaw');
                        grid on;
                        xlabel('Time (s)');
                        ylabel('Angle (deg)');
                        title('Euler Angles vs Time');
                        legend('Location', 'best');
                    end
                    
                    % PNG 저장
                    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
                    filename = sprintf('partial_results_%s.png', timestamp);
                    saveas(gcf, filename);
                    fprintf('✅ Partial results plot saved: %s\n', filename);
                end
            end
        end
    catch ME
        fprintf('❌ Could not create plots: %s\n', ME.message);
    end
    
else
    fprintf('❌ ''out'' variable NOT found in workspace\n');
    fprintf('   The simulation may have failed before generating output.\n\n');
end

% 2. 다른 관련 변수들 확인
fprintf('\n=== Other Workspace Variables ===\n');
vars_to_check = {'SimIn', 'SimPar', 'target', 'traj_run_num', 'fail_run_num'};
for i = 1:length(vars_to_check)
    if evalin('base', sprintf('exist(''%s'', ''var'')', vars_to_check{i}))
        fprintf('✅ ''%s'' exists\n', vars_to_check{i});
    else
        fprintf('❌ ''%s'' not found\n', vars_to_check{i});
    end
end

fprintf('\n=== Explanation ===\n');
fprintf('에러 메시지: "KillifNotValidPropSpd" at time 725.265s\n');
fprintf('의미: 프로펠러 속도가 유효하지 않은 범위로 벗어남\n');
fprintf('원인: 실패 시나리오가 비행 이탈(departure from flight)을 유발\n');
fprintf('해결: 다른 궤적/실패 번호를 시도하거나 ENABLE_FAILURE=0으로 설정\n\n');
fprintf('결과 확인:\n');
fprintf('  1. 위에서 생성된 partial_results_*.png 파일 확인\n');
fprintf('  2. 워크스페이스에서 ''out'' 변수 직접 탐색\n');
fprintf('  3. 더 안정적인 시나리오로 재실행 권장\n\n');
