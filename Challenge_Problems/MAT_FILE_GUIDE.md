# MAT 파일 확인 방법 가이드

V2가 생성한 `.mat` 파일을 분석하는 완전한 가이드입니다.

---

## 📦 V2가 생성하는 MAT 파일

1. **sim_config_traj{N}_fail{M}_{timestamp}.mat** - 설정 정보
2. **sim_results_traj{N}_fail{M}_{timestamp}.mat** - 결과 데이터

---

## 🚀 방법 1: analyze_results.m 사용 (가장 쉬움!)

### 자동 분석 (최신 파일)
```matlab
>> cd Challenge_Problems
>> analyze_results

📂 자동 선택된 파일: sim_results_traj1_fail1_20251120_093015.mat

🔄 로딩 중: sim_results_traj1_fail1_20251120_093015.mat
✅ 로드 완료!

╔══════════════════════════════════════════════════════════════╗
║                    시뮬레이션 기본 정보                      ║
╚══════════════════════════════════════════════════════════════╝

📅 실행 시간: 2025-11-20 09:30:15
📍 궤적 번호: 1
💥 실패 시나리오: 1
⚙️  실패 활성화: true

╔══════════════════════════════════════════════════════════════╗
║                    시뮬레이션 결과                           ║
╚══════════════════════════════════════════════════════════════╝

❌ 상태: 실패
⏱️  실행 시간: 42.3초
⚠️  에러: KillifNotValidPropSpd at 725.265s

... (자세한 정보 계속 표시) ...
```

### 특정 파일 분석
```matlab
>> analyze_results('sim_results_traj5_fail10_20251120_100000.mat')
```

---

## 🔍 방법 2: load 명령어로 직접 확인

### 기본 로드
```matlab
% 파일 로드
>> load('sim_results_traj1_fail1_20251120_093015.mat')

% 로드된 변수 확인
>> whos
  Name         Size            Bytes  Class     Attributes
  results      1x1             12345  struct              

% 전체 구조 확인
>> results

results = 
  struct with fields:
           config: [1×1 struct]
       trajectory: [1×1 struct]
          failure: [1×1 struct]
       simulation: [1×1 struct]
             data: [1×1 struct]
```

### 구체적인 정보 접근
```matlab
% 설정 정보
>> results.config
ans = 
  struct with fields:
     traj_run_num: 1
     fail_run_num: 1
   enable_failure: 1
        timestamp: '2025-11-20 09:30:15'
   timestamp_file: '20251120_093015'
         variants: [1×1 struct]

% 시뮬레이션 결과
>> results.simulation
ans = 
  struct with fields:
         success: 0
    elapsed_time: 42.3000
           error: 'KillifNotValidPropSpd at 725.265s'

% 데이터 포인트 수
>> results.data.num_points
ans =
       7253

% 완료율
>> completion = 100 * results.data.sim_time_reached / results.trajectory.duration
completion =
   90.6500

% 최종 위치
>> results.data.pos_NED(end,:)
ans =
   52341.2000    -345.7000    -500.0000

% 최종 고도
>> altitude = -results.data.pos_NED(end,3)
altitude =
   500

% 최종 속도
>> results.data.vel_body(end,:)
ans =
   140.5000    -12.3000     5.7000
```

---

## 📊 방법 3: 변수에 할당 (깔끔한 방법)

```matlab
% 변수로 로드
>> data = load('sim_results_traj1_fail1_20251120_093015.mat');

% 이제 data.results로 접근
>> data.results.simulation.success
ans =
  logical
   0

>> data.results.simulation.error
ans =
    'KillifNotValidPropSpd at 725.265s'

% 시계열 데이터 플롯
>> plot(data.results.data.time, -data.results.data.pos_NED(:,3))
>> xlabel('Time (s)'); ylabel('Altitude (ft)'); title('Altitude vs Time');
```

---

## 🎨 방법 4: GUI 변수 탐색기 사용

```matlab
% 1. 파일 로드
>> load('sim_results_traj1_fail1_20251120_093015.mat')

% 2. MATLAB 윈도우에서:
%    - 상단 메뉴: View → Workspace (또는 Ctrl+Shift+W)
%    - 'results' 변수 더블클릭
%    - 구조체를 GUI에서 탐색
```

**GUI에서 볼 수 있는 것**:
- 각 필드를 클릭하여 하위 구조 탐색
- 배열 데이터를 표 형태로 확인
- 복사/붙여넣기 쉬움

---

## 🔬 방법 5: 실용적인 분석 예제

### 예제 1: 모든 결과 파일 요약
```matlab
% 모든 결과 파일 찾기
files = dir('sim_results_*.mat');

% 요약 테이블 생성
summary = table();
for i = 1:length(files)
    data = load(files(i).name);
    r = data.results;
    
    summary.Filename{i} = files(i).name;
    summary.Trajectory(i) = r.config.traj_run_num;
    summary.Failure(i) = r.config.fail_run_num;
    summary.Success(i) = r.simulation.success;
    
    if isfield(r, 'data') && ~isempty(fieldnames(r.data))
        summary.Completion(i) = r.data.sim_time_reached / r.trajectory.duration * 100;
    else
        summary.Completion(i) = 0;
    end
    
    summary.Error{i} = r.simulation.error;
end

% 테이블 표시
disp(summary);

% 성공률
success_rate = sum(summary.Success) / height(summary) * 100;
fprintf('전체 성공률: %.1f%%\n', success_rate);

% 평균 완료율
avg_completion = mean(summary.Completion);
fprintf('평균 완료율: %.1f%%\n', avg_completion);
```

### 예제 2: 실패 지점 분석
```matlab
data = load('sim_results_traj1_fail1_20251120_093015.mat');
results = data.results;

if isfield(results.failure, 'active_surface_failures') && ...
   ~isempty(results.failure.active_surface_failures)
    
    surf_idx = results.failure.active_surface_failures;
    fail_time = min(results.failure.surfaces.InitTime(surf_idx));
    
    fprintf('실패 시작 시간: %.1f초\n', fail_time);
    
    % 실패 시점의 데이터 찾기
    [~, idx] = min(abs(results.data.time - fail_time));
    
    fprintf('실패 시점 상태:\n');
    fprintf('  위치: [%.1f, %.1f, %.1f] ft\n', results.data.pos_NED(idx,:));
    fprintf('  속도: [%.1f, %.1f, %.1f] ft/s\n', results.data.vel_body(idx,:));
    fprintf('  자세: Roll=%.1f°, Pitch=%.1f°, Yaw=%.1f°\n', ...
        rad2deg(results.data.euler(idx,1)), ...
        rad2deg(results.data.euler(idx,2)), ...
        rad2deg(results.data.euler(idx,3)));
    
    % 실패 전후 비교
    pre_idx = max(1, idx-50);
    post_idx = min(length(results.data.time), idx+50);
    
    figure;
    subplot(2,1,1);
    plot(results.data.time(pre_idx:post_idx), -results.data.pos_NED(pre_idx:post_idx,3), 'b-', 'LineWidth', 2);
    hold on;
    xline(fail_time, 'r--', 'LineWidth', 2, 'Label', '실패');
    ylabel('Altitude (ft)'); xlabel('Time (s)');
    title('실패 전후 고도 변화');
    grid on;
    
    subplot(2,1,2);
    roll = rad2deg(results.data.euler(pre_idx:post_idx,1));
    plot(results.data.time(pre_idx:post_idx), roll, 'b-', 'LineWidth', 2);
    hold on;
    xline(fail_time, 'r--', 'LineWidth', 2, 'Label', '실패');
    ylabel('Roll (deg)'); xlabel('Time (s)');
    title('실패 전후 Roll 변화');
    grid on;
end
```

### 예제 3: 배치 분석 - 어떤 실패 유형이 가장 치명적인가?
```matlab
files = dir('sim_results_*.mat');
stats = struct();

for i = 1:length(files)
    data = load(files(i).name);
    r = data.results;
    
    stats(i).traj = r.config.traj_run_num;
    stats(i).fail = r.config.fail_run_num;
    stats(i).success = r.simulation.success;
    stats(i).error = r.simulation.error;
    
    if isfield(r, 'data') && ~isempty(fieldnames(r.data))
        stats(i).completion = r.data.sim_time_reached / r.trajectory.duration;
    else
        stats(i).completion = 0;
    end
    
    % 실패 유형 추출
    if isfield(r.failure, 'active_surface_failures')
        surf_idx = r.failure.active_surface_failures;
        if ~isempty(surf_idx)
            stats(i).surf_fail_types = r.failure.surfaces.FailInit(surf_idx);
            stats(i).surf_fail_time = min(r.failure.surfaces.InitTime(surf_idx));
        else
            stats(i).surf_fail_types = [];
            stats(i).surf_fail_time = inf;
        end
    end
end

% 실패 유형별 성공률
unique_types = unique([stats.surf_fail_types]);
for type = unique_types
    mask = arrayfun(@(s) any(s.surf_fail_types == type), stats);
    success_rate = sum([stats(mask).success]) / sum(mask) * 100;
    avg_completion = mean([stats(mask).completion]) * 100;
    
    fprintf('실패 유형 %d:\n', type);
    fprintf('  성공률: %.1f%%\n', success_rate);
    fprintf('  평균 완료율: %.1f%%\n', avg_completion);
    fprintf('  발생 횟수: %d\n\n', sum(mask));
end
```

---

## 💡 자주 사용하는 명령어 모음

```matlab
% === 빠른 확인 ===
data = load('sim_results_*.mat');
data.results.simulation           % 성공/실패
data.results.data.sim_time_reached % 도달 시간

% === 그래프 ===
% 3D 궤적
plot3(data.results.data.pos_NED(:,1), ...
      data.results.data.pos_NED(:,2), ...
     -data.results.data.pos_NED(:,3));

% 고도 vs 시간
plot(data.results.data.time, -data.results.data.pos_NED(:,3));

% 속도 vs 시간
vel = data.results.data.vel_body;
ground_speed = sqrt(vel(:,1).^2 + vel(:,2).^2) * 0.592484; % knots
plot(data.results.data.time, ground_speed);

% === 통계 ===
% 평균 고도
mean(-data.results.data.pos_NED(:,3))

% 최대/최소 Roll
max(abs(rad2deg(data.results.data.euler(:,1))))

% 이동 거리
sqrt(sum(data.results.data.pos_NED(end,1:2).^2)) / 6076.12  % nm
```

---

## 📝 구조체 전체 구조

```
results
├── config
│   ├── traj_run_num: 궤적 번호
│   ├── fail_run_num: 실패 시나리오 번호
│   ├── enable_failure: 실패 활성화 여부
│   ├── timestamp: 실행 시각 (문자열)
│   ├── timestamp_file: 파일명용 타임스탬프
│   └── variants: GUAM 변형 설정
│
├── trajectory
│   ├── duration: 계획 시간
│   ├── initial_pos: 초기 위치 [N,E,D]
│   ├── initial_vel: 초기 속도 [u,v,w]
│   └── num_waypoints: 웨이포인트 개수 [X,Y,Z]
│
├── failure (enable_failure=true일 때)
│   ├── surfaces: 표면 제어 실패 파라미터
│   ├── props: 프로펠러 실패 파라미터
│   ├── active_surface_failures: 활성 표면 실패 인덱스
│   └── active_prop_failures: 활성 프로펠러 실패 인덱스
│
├── simulation
│   ├── success: 성공 여부 (true/false)
│   ├── elapsed_time: 실행 시간 (초)
│   ├── error: 에러 메시지 (실패 시)
│   ├── identifier: 에러 식별자 (실패 시)
│   └── stack: 에러 스택 (실패 시)
│
└── data (데이터 추출 성공 시)
    ├── time: 시간 배열 [Nx1]
    ├── pos_NED: 위치 [Nx3] (North, East, Down) ft
    ├── vel_body: 속도 [Nx3] (u, v, w) ft/s
    ├── euler: 자세 [Nx3] (roll, pitch, yaw) rad
    ├── num_points: 데이터 포인트 수
    └── sim_time_reached: 도달한 시뮬레이션 시간
```

---

## 🎯 권장 워크플로우

### 1. 단일 시뮬레이션 분석
```matlab
>> cd Challenge_Problems
>> analyze_results  % 자동으로 최신 파일 분석
```

### 2. 커스텀 플롯
```matlab
>> data = load('sim_results_*.mat');
>> results = data.results;
>> plot_trajectory(results)
>> plot_attitude(results)
```

### 3. 배치 분석
```matlab
>> files = dir('sim_results_*.mat');
>> for i = 1:length(files)
       data = load(files(i).name);
       % 분석 로직...
   end
```

---

## ❓ 문제 해결

### Q: "변수를 찾을 수 없습니다"
```matlab
% 잘못된 방법:
>> load sim_results_traj1_fail1_20251120_093015.mat
>> results.data  % ❌ 에러!

% 올바른 방법:
>> load('sim_results_traj1_fail1_20251120_093015.mat')  % 따옴표!
>> results.data  % ✅ 작동
```

### Q: "데이터가 너무 커서 메모리 부족"
```matlab
% matfile 사용 (부분 로드)
>> m = matfile('sim_results_traj1_fail1_20251120_093015.mat');
>> m.results.simulation  % 이 부분만 로드
>> m.results.data.time(1:1000)  % 처음 1000개만
```

### Q: "여러 파일을 한번에 비교하고 싶어요"
```matlab
>> analyze_results('sim_results_traj1_fail1_*.mat')
>> analyze_results('sim_results_traj2_fail1_*.mat')
% 또는 배치 분석 예제 3 참조
```

---

## 🚀 다음 단계

- `analyze_results.m` 스크립트를 커스터마이즈
- 배치 분석 스크립트 작성
- Monte Carlo 통계 분석
- TSE (Total System Error) 계산
