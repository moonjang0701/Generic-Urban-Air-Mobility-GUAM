# GUAM 내부 검증 방법론 (실용적 접근)
# GUAM Internal Validation Methodology (Practical Approach)

## 🎯 현실적인 검증 전략

당신의 지적이 정확합니다. NASA Joby 실제 비행 데이터를 받기는 매우 어렵고, 설령 받더라도 GUAM의 Generic 기체 사양과 Joby의 실제 기체 사양이 달라서 직접 비교가 불가능합니다.

**대신 우리가 실제로 할 수 있는 검증**은:
1. **GUAM Challenge Problems (3000개 시나리오)**의 내부 일관성 검증
2. **GUAM 시뮬레이션 자체의 물리적 타당성** 검증
3. **UAM Procedure Design에 필요한 파라미터 민감도 분석**

---

## 📊 우리가 실제로 가진 데이터

### GUAM Challenge Problems Dataset

```
Challenge_Problems/
├── Data_Set_1.mat (23 MB)  - 3000개 own-ship Bezier 궤적
├── Data_Set_2.mat (215 KB) - 3000개 stationary obstacles
├── Data_Set_3.mat (7.1 MB) - 3000개 moving obstacles  
├── Data_Set_4.mat (344 KB) - 3000개 failure scenarios
```

**각 "run"은 서로 연관됨**:
- Run 1: own_traj[1] + stat_obj[1] + mov_obj[1] + failure[1]
- Run 2: own_traj[2] + stat_obj[2] + mov_obj[2] + failure[2]
- ... (3000 runs total)

### GUAM 시뮬레이션 출력 (SimOut)

**GUAM을 실행하면 얻을 수 있는 데이터**:
```matlab
SimOut.VehStates
├── PositionNED: [N×3] - North, East, Down (ft)
├── VelocityBody: [N×3] - u, v, w (ft/s)  
├── VelocityNED: [N×3] - Vn, Ve, Vd (ft/s)
├── EulerAngles: [N×3] - Roll, Pitch, Yaw (rad)
├── AngularRates: [N×3] - p, q, r (rad/s)
├── Accelerations: [N×3] - ax, ay, az (ft/s²)
└── Time: [N×1] - seconds

SimOut.PropStates
├── RPM: [N×6] - 각 프로펠러 RPM
├── NacelleAngle: [N×6] - 각 나셀 각도 (rad)
├── BladePitch: [N×6] - 각 블레이드 피치 (rad)
└── Thrust: [N×6] - 각 프로펠러 추력 (lbf)

SimOut.ControlInputs
├── Commands: 제어 명령
└── Actuator: 액츄에이터 상태
```

---

## 🔬 실용적 검증 방법론 (3단계)

### **Phase 1: GUAM 내부 일관성 검증**

**목표**: GUAM Challenge Problems 입력 궤적과 실제 시뮬레이션 출력이 일치하는가?

#### 1.1 궤적 추종 정확도 (Trajectory Tracking Accuracy)

```matlab
% Validation Method:
% 1. Load Challenge Problem trajectory (Bezier waypoints)
load('Data_Set_1.mat', 'own_traj');
run_num = 1;
waypoints = own_traj{run_num, 1};  % Bezier waypoints

% 2. Run GUAM simulation with this trajectory
guam_output = run_GUAM_with_trajectory(waypoints, run_num);

% 3. Compare commanded vs achieved trajectory
commanded_path = bezier_to_path(waypoints);
achieved_path = guam_output.PositionNED;

% 4. Compute tracking error
tracking_error = compute_path_deviation(commanded_path, achieved_path);
```

**검증 메트릭**:
- **Cross-Track Error (XTE)**: 명령된 경로로부터의 수직 거리
  - ✅ Good: XTE_rms < 20 ft (약 6m)
  - ⚠️ Acceptable: XTE_rms < 50 ft
  
- **Altitude Tracking Error**: 고도 추종 오차
  - ✅ Good: Alt_error_rms < 10 ft
  
- **Speed Tracking Error**: 속도 추종 오차
  - ✅ Good: Speed_error_rms < 5 ft/s (약 1.5 m/s)

**의미**: 
- 이 검증은 **GUAM의 제어 시스템이 명령된 궤적을 얼마나 정확히 따르는가**를 평가
- 실제 eVTOL도 명령된 궤적을 완벽히 따르지 못하므로, 이 오차는 **Flight Technical Error (FTE)**의 일부

#### 1.2 물리 법칙 준수 검증

```matlab
% Energy Conservation Check
KE = 0.5 * mass * V^2;  % Kinetic energy
PE = mass * g * altitude;  % Potential energy
Work = integral(Thrust * V, dt);  % Work done by propulsion

% Energy balance (accounting for drag losses)
energy_balance = (KE_final + PE_final) - (KE_initial + PE_initial) - Work;
% Should be close to zero (within numerical error)
```

**검증 메트릭**:
- **Energy Conservation**: 에너지 보존 법칙 만족 여부
- **Momentum Conservation**: 운동량 보존 (외력 없을 때)
- **Trim Validation**: 정상 비행 조건에서 힘/모멘트 균형

---

### **Phase 2: Monte Carlo 변동성 분석**

**목표**: 동일 궤적에 대해 환경 조건을 변화시켰을 때 결과가 합리적으로 변하는가?

#### 2.1 바람 민감도 분석

```matlab
% Same trajectory, different wind conditions
base_trajectory = own_traj{1, 1};

wind_scenarios = [
    0,  0,  0;   % No wind
    10, 0,  0;   % 10 kt headwind
    -10, 0, 0;   % 10 kt tailwind  
    0,  10, 0;   % 10 kt crosswind (right)
    0, -10, 0;   % 10 kt crosswind (left)
];

for i = 1:size(wind_scenarios, 1)
    SimPar.wind = wind_scenarios(i, :);
    output(i) = run_GUAM_simulation(base_trajectory);
end

% Analyze wind impact
ground_track_deviation = compare_ground_tracks(output);
airspeed_vs_groundspeed = compare_speeds(output);
```

**예상 결과**:
- Headwind → 비행 시간 증가, 지상 속도 감소
- Tailwind → 비행 시간 감소, 지상 속도 증가
- Crosswind → 궤적 drift, crab angle 발생

**의미**: 
- GUAM이 물리적으로 합리적인 바람 효과를 재현하는지 확인
- **Navigation System Error (NSE)** 모델링에 필요한 바람 영향 정량화

#### 2.2 초기 조건 민감도 분석

```matlab
% Perturb initial conditions
IC_nominal = get_initial_conditions(own_traj{1, 1});

% Add small perturbations
perturbations = [
    [10, 0, 0];    % +10 ft North
    [0, 10, 0];    % +10 ft East
    [0, 0, -5];    % +5 ft Up
    [0, 0, 0];     % Nominal
];

for i = 1:size(perturbations, 1)
    IC_perturbed = IC_nominal + perturbations(i, :);
    output(i) = run_GUAM_simulation(IC_perturbed);
end

% Check if small input changes → small output changes (stability)
output_sensitivity = compute_sensitivity(output);
```

**검증 메트릭**:
- **Lyapunov Stability**: 작은 초기 조건 변화 → 작은 출력 변화
- **Bounded Response**: 출력이 발산하지 않음

---

### **Phase 3: 비교 시뮬레이션 검증 (Self-Consistency)**

**목표**: 동일한 궤적을 여러 번 실행했을 때 결과가 일관성 있는가?

#### 3.1 반복 실행 일관성 (Repeatability)

```matlab
% Run same scenario N times
N_runs = 10;
run_id = 1;

for i = 1:N_runs
    output{i} = run_GUAM_simulation(own_traj{run_id, 1});
end

% Compute statistics across runs
mean_trajectory = mean_of_trajectories(output);
std_trajectory = std_of_trajectories(output);

% Check if variation is small (deterministic simulation)
max_variation = max(std_trajectory);
```

**예상 결과**:
- Deterministic simulation → **variation ≈ 0** (numerical precision만 차이)
- Stochastic simulation → small variation from random seeds

**의미**: GUAM이 동일 입력에 대해 일관된 출력을 생성하는지 확인

#### 3.2 궤적 복잡도별 성능 비교

```matlab
% Categorize Challenge Problem trajectories by complexity
categories = classify_trajectories(own_traj);

% Simple: straight or gentle turns
% Medium: moderate turns, climb/descent
% Complex: sharp turns, aggressive maneuvers

% Compute tracking error for each category
for category = {'simple', 'medium', 'complex'}
    runs = categories.(category);
    errors.(category) = [];
    
    for run_id = runs
        output = run_GUAM_simulation(own_traj{run_id, 1});
        errors.(category) = [errors.(category); compute_tracking_error(output)];
    end
end

% Expected: Complex trajectories → larger tracking errors
```

**검증 메트릭**:
- **Error Scaling**: 궤적 복잡도 ∝ 추종 오차
- **Saturation Limits**: 액츄에이터 포화 시 성능 저하

---

## 📈 실용적 검증 메트릭 정의

### Metric 1: Trajectory Fidelity Index (TFI)

```matlab
% Measures how well GUAM follows commanded trajectory
TFI = 1 - (RMS_tracking_error / reference_path_length)

% TFI = 1.0 → perfect tracking
% TFI = 0.9 → 10% error relative to path length
```

**허용 기준**:
- TFI > 0.95: Excellent
- TFI > 0.85: Good
- TFI < 0.70: Poor

### Metric 2: Physical Consistency Score (PCS)

```matlab
% Checks if simulation obeys physics laws
checks = [
    check_energy_conservation(),
    check_momentum_conservation(),
    check_max_acceleration_limits(),
    check_propeller_thrust_realistic(),
    check_nacelle_angle_constraints()
];

PCS = sum(checks) / length(checks);  % 0 to 1 score
```

**허용 기준**:
- PCS = 1.0: All physics checks passed
- PCS < 0.8: Physical inconsistencies detected

### Metric 3: Controller Performance Index (CPI)

```matlab
% Evaluates control system quality
settling_time = time_to_reach_commanded_state();
overshoot = max_deviation_from_commanded();
steady_state_error = final_error_from_commanded();

CPI = f(settling_time, overshoot, steady_state_error);
```

**허용 기준**:
- Settling time < 10 seconds
- Overshoot < 10%
- Steady-state error < 2%

---

## 🛠️ 구현 계획

### Step 1: Validation Framework 구축

**파일**: `validate_GUAM_internal.m`

```matlab
function results = validate_GUAM_internal(run_ids, validation_type)
% VALIDATE_GUAM_INTERNAL - Internal consistency validation of GUAM
%
% Inputs:
%   run_ids - Array of Challenge Problem run numbers to validate (e.g., 1:100)
%   validation_type - 'tracking', 'physics', 'sensitivity', 'all'
%
% Outputs:
%   results - Structure with validation metrics

% Load Challenge Problems
load('Challenge_Problems/Data_Set_1.mat', 'own_traj');

% Initialize results
results = struct();
results.run_ids = run_ids;
results.n_runs = length(run_ids);
results.metrics = [];

% Loop through runs
for i = 1:length(run_ids)
    run_id = run_ids(i);
    fprintf('Validating run %d/%d...\n', i, length(run_ids));
    
    % Extract trajectory
    trajectory = own_traj{run_id, 1};
    
    % Run GUAM simulation
    guam_output = run_GUAM_with_bezier(trajectory, run_id);
    
    % Compute validation metrics based on type
    switch validation_type
        case 'tracking'
            metrics = compute_tracking_metrics(trajectory, guam_output);
        case 'physics'
            metrics = compute_physics_metrics(guam_output);
        case 'sensitivity'
            metrics = compute_sensitivity_metrics(trajectory, run_id);
        case 'all'
            metrics.tracking = compute_tracking_metrics(trajectory, guam_output);
            metrics.physics = compute_physics_metrics(guam_output);
            metrics.sensitivity = compute_sensitivity_metrics(trajectory, run_id);
    end
    
    % Store results
    results.metrics = [results.metrics; metrics];
end

% Aggregate statistics
results.summary = compute_summary_statistics(results.metrics);

% Save results
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
save(sprintf('Validation_Internal_%s.mat', timestamp), 'results');

% Generate report
generate_validation_report(results);

end
```

### Step 2: Helper Functions 구현

**파일**: `compute_tracking_metrics.m`

```matlab
function metrics = compute_tracking_metrics(commanded_traj, actual_output)
% Compute trajectory tracking metrics

% Convert Bezier waypoints to continuous path
commanded_path = bezier_waypoints_to_path(commanded_traj);

% Extract actual flown path
actual_path = actual_output.VehStates.PositionNED;

% Interpolate to same time vector
common_time = intersect(commanded_path.time, actual_path.time);
cmd_interp = interp1(commanded_path.time, commanded_path.position, common_time);
act_interp = interp1(actual_path.time, actual_path.position, common_time);

% Compute errors
position_error = act_interp - cmd_interp;

% Cross-track error (perpendicular to path)
xte = compute_cross_track_error(cmd_interp, act_interp);

% Metrics
metrics = struct();
metrics.xte_rms = sqrt(mean(xte.^2));
metrics.xte_max = max(abs(xte));
metrics.xte_95 = prctile(abs(xte), 95);

metrics.along_track_error_rms = sqrt(mean(position_error(:,1).^2));
metrics.altitude_error_rms = sqrt(mean(position_error(:,3).^2));

metrics.trajectory_fidelity_index = compute_TFI(xte, commanded_path);

end
```

### Step 3: Batch Validation 실행

```matlab
% Validate first 100 Challenge Problem scenarios
run_ids = 1:100;

% Run all validation types
results_tracking = validate_GUAM_internal(run_ids, 'tracking');
results_physics = validate_GUAM_internal(run_ids, 'physics');

% Analyze results
fprintf('\n=== GUAM Internal Validation Summary ===\n');
fprintf('Trajectory Fidelity Index: %.3f ± %.3f\n', ...
    mean([results_tracking.metrics.trajectory_fidelity_index]), ...
    std([results_tracking.metrics.trajectory_fidelity_index]));

fprintf('Cross-Track Error (RMS): %.2f ± %.2f ft\n', ...
    mean([results_tracking.metrics.xte_rms]), ...
    std([results_tracking.metrics.xte_rms]));

fprintf('Physical Consistency Score: %.3f\n', ...
    mean([results_physics.metrics.physical_consistency_score]));
```

---

## 🎯 UAM Procedure Design에 활용

### Application 1: FTE (Flight Technical Error) 통계 추출

```matlab
% GUAM 추종 오차를 FTE 분포로 사용
FTE_data = [results_tracking.metrics.xte_rms];

% Fit distribution
pd = fitdist(FTE_data, 'Normal');
FTE_mean = pd.mu;
FTE_std = pd.sigma;

% Use in TSE calculation
NSE_std = 278;  % meters (from RNP 0.3)
FTE_std_m = FTE_std * 0.3048;  % ft to m

TSE_std = sqrt(FTE_std_m^2 + NSE_std^2);

fprintf('Total System Error (1-sigma): %.2f m\n', TSE_std);
fprintf('95%% containment radius: %.2f m\n', 1.96 * TSE_std);
```

### Application 2: 경로 복잡도별 보호 구역 크기

```matlab
% Simple trajectories
simple_runs = find(trajectory_complexity < 0.3);
FTE_simple = mean([results_tracking.metrics(simple_runs).xte_95]);

% Complex trajectories  
complex_runs = find(trajectory_complexity > 0.7);
FTE_complex = mean([results_tracking.metrics(complex_runs).xte_95]);

% Protection area sizing
protection_simple = 1.96 * sqrt(FTE_simple^2 + NSE^2);
protection_complex = 1.96 * sqrt(FTE_complex^2 + NSE^2);

fprintf('Simple trajectory protection: %.2f m\n', protection_simple * 0.3048);
fprintf('Complex trajectory protection: %.2f m\n', protection_complex * 0.3048);
```

### Application 3: Transition 구간 안전 마진

```matlab
% Analyze tracking error during transition (nacelle angle changing)
transition_segments = identify_transition_segments(guam_output);

FTE_transition = [];
for seg = transition_segments
    error = compute_tracking_error_in_segment(guam_output, seg);
    FTE_transition = [FTE_transition; error];
end

% Transition requires larger protection
FTE_transition_95 = prctile(FTE_transition, 95);
safety_margin_transition = FTE_transition_95 / FTE_cruise_95;

fprintf('Transition safety margin multiplier: %.2f\n', safety_margin_transition);
% → Procedure design: Increase corridor width by this factor during transition
```

---

## 📊 예상 검증 결과

### 시나리오 1: Normal Scenarios (정상 비행)

**예상**:
- XTE_rms: 10-30 ft
- TFI: 0.90-0.95
- PCS: 1.0 (all physics checks pass)

**의미**: GUAM이 정상 비행 조건에서 합리적으로 동작

### 시나리오 2: Complex Maneuvers (복잡한 기동)

**예상**:
- XTE_rms: 30-60 ft
- TFI: 0.80-0.90  
- Controller saturation observed

**의미**: 급격한 기동 시 추종 오차 증가 (실제와 유사)

### 시나리오 3: Failure Scenarios (고장 시나리오)

**예상**:
- XTE_rms: 50-200 ft (depending on failure severity)
- TFI: 0.50-0.80
- Some physics checks may fail (intentional)

**의미**: 고장 시 성능 저하를 시뮬레이션 (비상 절차 설계에 활용)

---

## ✅ 핵심 정리

### 이 접근법의 장점:

1. **✅ 실행 가능**: 외부 데이터 필요 없음, GUAM Challenge Problems만 사용
2. **✅ 정량적**: 명확한 메트릭 (TFI, PCS, CPI)으로 수치화
3. **✅ 실용적**: UAM Procedure Design에 직접 활용 가능한 FTE/TSE 통계 추출
4. **✅ 반복 가능**: 3000개 시나리오로 통계적 신뢰도 확보

### 이 접근법의 한계:

1. **⚠️ 절대 정확도 불명**: 실제 비행과의 오차는 알 수 없음 (상대 비교만 가능)
2. **⚠️ GUAM 자체의 물리 모델 정확도**: 가정으로 받아들여야 함
3. **⚠️ Generic 기체**: 특정 실제 기체(Joby)와는 사양이 다름

### 결론:

**NASA에 실제 비행 데이터를 요청하는 대신**, 우리는:
- ✅ **GUAM 내부 일관성을 검증**하여 시뮬레이션이 물리적으로 타당한지 확인
- ✅ **3000개 Challenge Problems로 통계 분석**하여 FTE 분포를 추출
- ✅ **추출된 FTE를 UAM Procedure Design**에 활용 (TSE 계산, 보호 구역 크기 결정)

이것이 **현실적으로 가능하고, 과학적으로 타당하며, UAM R&D에 실질적으로 유용한** 접근법입니다.

---

**문서 작성일**: 2024-11-25  
**작성자**: UAM Procedure R&D Team  
**버전**: 1.0 (Practical Approach)
