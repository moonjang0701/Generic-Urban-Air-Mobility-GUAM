# RUNME_COMPLETE_V2 개선사항

## 🎯 핵심 개선: 실패해도 모든 정보 저장!

### 문제점 (V1)
```matlab
try
    sim(model);
    % 성공하면 여기서 계속
catch ME
    fprintf('Simulation failed\n');
    return;  % ❌ 여기서 종료! 아무것도 저장 안 됨!
end
```

### 해결책 (V2)
```matlab
% 1. 시뮬레이션 전에 설정 저장
save('config.mat', 'results');

% 2. 시뮬레이션 실행 (성공/실패 상관없이 계속)
try
    out = sim(model);
    simulation_success = true;
catch ME
    simulation_success = false;
    simulation_error = ME.message;
    % ✅ 계속 진행! (return 없음)
end

% 3. 부분 데이터라도 추출
if exist('logsout', 'var')
    % 실패했어도 여기까지의 데이터 저장
end

% 4. 최종 결과 저장 (성공/실패 정보 포함)
save('results.mat', 'results');
```

---

## 📦 V2가 저장하는 정보

### 1. **설정 파일** (시뮬레이션 시작 전 저장)
파일명: `sim_config_traj{N}_fail{M}_{timestamp}.mat`

```matlab
results.config = struct(
    'traj_run_num', 1,
    'fail_run_num', 1,
    'enable_failure', true,
    'timestamp', '2025-11-20 09:30:00',
    'variants', {...}
);

results.trajectory = struct(
    'duration', 800.0,
    'initial_pos', [0, 0, 0],
    'initial_vel', [145, 0, 0],
    'num_waypoints', [3, 2, 3]
);

results.failure = struct(
    'surfaces', {...},  % 모든 실패 설정
    'props', {...},
    'active_surface_failures', [1, 3],
    'active_prop_failures', []
);
```

### 2. **결과 파일** (시뮬레이션 후 저장)
파일명: `sim_results_traj{N}_fail{M}_{timestamp}.mat`

```matlab
results.simulation = struct(
    'success', false,  % or true
    'elapsed_time', 42.3,
    'error', 'KillifNotValidPropSpd at 725.265s'
);

results.data = struct(
    'time', [0, 0.1, 0.2, ..., 725.2],  % 실제 기록된 시간
    'pos_NED', [...],
    'vel_body', [...],
    'euler', [...],
    'num_points', 7253,
    'sim_time_reached', 725.2  % 여기까지만 시뮬레이션됨
);
```

### 3. **텍스트 보고서** (사람이 읽기 쉬운 형식)
파일명: `sim_report_traj{N}_fail{M}_{timestamp}.txt`

```
════════════════════════════════════════════════════════════════
GUAM CHALLENGE PROBLEM SIMULATION REPORT
════════════════════════════════════════════════════════════════

Generated: 2025-11-20 09:30:15

--- CONFIGURATION ---
Trajectory Number: 1
Failure Scenario: 1
Failure Enabled: true

--- TRAJECTORY INFO ---
Planned Duration: 800.0 seconds
Initial Position: [0.0, 0.0, 0.0] ft (NED)
Initial Velocity: [145.0, 0.0, 0.0] ft/s
Waypoints: X=3, Y=2, Z=3

--- FAILURE SCENARIO ---
Surface Failures: 2 active
  Surface #1:
    Type: 3
    Start Time: 700.0 s
    Stop Time: Inf s
    PreScale: 0.500
    PostScale: 1.000
  Surface #3:
    Type: 1
    Start Time: 710.0 s
    Stop Time: 750.0 s
    PreScale: 0.000
    PostScale: 1.000

--- SIMULATION RESULT ---
Status: ❌ FAILED
Execution Time: 42.3 seconds
Error: 시간 725.265에 'GUAM/.../KillifNotValidPropSpd'에서 어설션 감지

--- DATA SUMMARY ---
Data Points Captured: 7253
Simulation Time Reached: 725.2 / 800.0 seconds (90.7%)
Final Position: [52341.2, -345.7, -500.0] ft
Final Altitude: 500.0 ft
Distance Traveled: 52342.3 ft (8.614 nm)
Average Ground Speed: 85.3 knots
Final Attitude: Roll=-12.3°, Pitch=5.7°, Yaw=2.1°

--- FILES GENERATED ---
Configuration: sim_config_traj1_fail1_20251120_093015.mat
Results: sim_results_traj1_fail1_20251120_093015.mat
Report: sim_report_traj1_fail1_20251120_093015.txt
Plot 1: Traj3D_T1_F1_20251120_093015.png
Plot 2: Position_T1_F1_20251120_093015.png
Plot 3: Attitude_T1_F1_20251120_093015.png
Plot 4: Velocity_T1_F1_20251120_093015.png

════════════════════════════════════════════════════════════════
```

### 4. **그래프 파일** (부분 데이터라도 생성)
- `Traj3D_T{N}_F{M}_{timestamp}.png` - 3D 궤적 (빨간 점 = 실패 지점)
- `Position_T{N}_F{M}_{timestamp}.png` - 위치 vs 시간 (빨간 선 = 실패 시작)
- `Attitude_T{N}_F{M}_{timestamp}.png` - 자세 vs 시간
- `Velocity_T{N}_F{M}_{timestamp}.png` - 속도 vs 시간

---

## 🔍 실패 분석 예시

### 질문: "어떤 설정으로 실패했나?"
**답변**: `sim_config_*.mat` 또는 `sim_report_*.txt` 확인

```matlab
load('sim_config_traj1_fail1_20251120_093015.mat');
results.config
results.trajectory
results.failure
```

### 질문: "얼마나 실행되다가 실패했나?"
**답변**: `sim_results_*.mat` 또는 `sim_report_*.txt` 확인

```matlab
load('sim_results_traj1_fail1_20251120_093015.mat');
fprintf('Completed: %.1f%%\n', ...
    100 * results.data.sim_time_reached / results.trajectory.duration);
% Output: Completed: 90.7%
```

### 질문: "실패 직전 상태는?"
**답변**: `results.data` 확인

```matlab
load('sim_results_traj1_fail1_20251120_093015.mat');
idx = length(results.data.time);  % 마지막 데이터 포인트

fprintf('실패 시점:\n');
fprintf('  시간: %.1f s\n', results.data.time(idx));
fprintf('  위치: [%.1f, %.1f, %.1f] ft\n', ...
    results.data.pos_NED(idx,1), ...
    results.data.pos_NED(idx,2), ...
    results.data.pos_NED(idx,3));
fprintf('  속도: [%.1f, %.1f, %.1f] ft/s\n', ...
    results.data.vel_body(idx,1), ...
    results.data.vel_body(idx,2), ...
    results.data.vel_body(idx,3));
fprintf('  자세: Roll=%.1f°, Pitch=%.1f°, Yaw=%.1f°\n', ...
    rad2deg(results.data.euler(idx,1)), ...
    rad2deg(results.data.euler(idx,2)), ...
    rad2deg(results.data.euler(idx,3)));
```

### 질문: "그래프로 보고 싶은데?"
**답변**: PNG 파일들 확인

```matlab
% MATLAB에서 이미지 열기
imshow('Traj3D_T1_F1_20251120_093015.png');

% 또는 파일 탐색기에서 직접 열기
```

---

## 📊 배치 분석 예제

여러 시나리오를 돌린 후 통계 분석:

```matlab
% 100개 시나리오 실행 후 분석
results_summary = struct();

for traj_id = 1:10
    for fail_id = 1:10
        % 결과 파일 로드
        filename = sprintf('sim_results_traj%d_fail%d_*.mat', traj_id, fail_id);
        files = dir(filename);
        if ~isempty(files)
            data = load(files(1).name);
            
            % 통계 수집
            results_summary(traj_id, fail_id).success = data.results.simulation.success;
            results_summary(traj_id, fail_id).completion = ...
                data.results.data.sim_time_reached / data.results.trajectory.duration;
            results_summary(traj_id, fail_id).error = data.results.simulation.error;
        end
    end
end

% 성공률 계산
success_rate = sum([results_summary.success]) / numel(results_summary);
fprintf('전체 성공률: %.1f%%\n', success_rate * 100);

% 평균 완료율 계산
avg_completion = mean([results_summary.completion]);
fprintf('평균 완료율: %.1f%%\n', avg_completion * 100);

% 가장 흔한 에러 찾기
error_types = {results_summary.error};
unique_errors = unique(error_types);
for i = 1:length(unique_errors)
    count = sum(strcmp(error_types, unique_errors{i}));
    fprintf('에러 "%s": %d회 (%.1f%%)\n', ...
        unique_errors{i}, count, 100*count/numel(results_summary));
end
```

---

## 🚀 사용 방법

### 기본 실행
```matlab
>> cd Challenge_Problems
>> RUNME_COMPLETE_V2
```

### 설정 변경
```matlab
% RUNME_COMPLETE_V2.m 파일 열기
traj_run_num = 123;   % 궤적 번호 변경
fail_run_num = 456;   % 실패 시나리오 변경
ENABLE_FAILURE = false;  % 실패 없이 실행

% 저장 후 실행
>> RUNME_COMPLETE_V2
```

### 결과 확인
```matlab
% 최신 결과 파일 찾기
>> files = dir('sim_results_*.mat');
>> latest = files(end).name;
>> load(latest);

% 요약 출력
>> disp(results.simulation)
>> disp(results.data)
```

---

## 🆚 V1 vs V2 비교

| 기능 | V1 (RUNME_COMPLETE) | V2 (RUNME_COMPLETE_V2) |
|------|---------------------|------------------------|
| **실패 시 동작** | 즉시 종료 (return) | 계속 진행, 부분 데이터 저장 |
| **설정 저장** | ❌ 안 함 | ✅ 시뮬레이션 전 저장 |
| **부분 결과** | ❌ 없음 | ✅ 저장 및 시각화 |
| **텍스트 보고서** | ❌ 없음 | ✅ 자동 생성 |
| **실패 정보** | 콘솔에만 출력 | ✅ 파일에 저장 |
| **파일명** | 타임스탬프만 | ✅ 시나리오 번호 포함 |
| **배치 분석** | 어려움 | ✅ 쉬움 (구조화된 파일) |
| **그래프 제목** | 일반 | ✅ PARTIAL 표시 |

---

## 💡 핵심 철학

**"실패도 데이터다!"**

- 어떤 설정으로 실행했는지 → **항상 저장**
- 얼마나 실행되었는지 → **부분 데이터 저장**
- 왜 실패했는지 → **에러 메시지 저장**
- 실패 직전 상태는? → **그래프로 시각화**

→ **모든 실행이 의미 있는 정보를 남깁니다!**
