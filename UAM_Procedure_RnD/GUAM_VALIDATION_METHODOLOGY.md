# GUAM Validation Methodology: Real Flight Test Comparison

## 개요 / Overview

이 문서는 NASA의 **GUAM (Generic Urban Air Mobility)** 시뮬레이션 플랫폼과 **실제 Joby Aviation eVTOL 비행 시험 데이터**를 비교 검증하는 방법론을 제시합니다.

This document presents a methodology for validating NASA's **GUAM simulation platform** against **real Joby Aviation eVTOL flight test data** from NASA Langley's acoustic flight test campaign.

---

## 📋 목차 / Table of Contents

1. [비행 시험 데이터 개요](#1-비행-시험-데이터-개요)
2. [GUAM 시뮬레이션 능력](#2-guam-시뮬레이션-능력)
3. [검증 방법론](#3-검증-방법론)
4. [비교 메트릭](#4-비교-메트릭)
5. [데이터 처리 절차](#5-데이터-처리-절차)
6. [통계 검증 기법](#6-통계-검증-기법)
7. [구현 계획](#7-구현-계획)

---

## 1. 비행 시험 데이터 개요

### 1.1 Joby Aviation 항공기 사양

**출처**: NASA Langley Acoustic Flight Test (2023)

| 항목 | 사양 |
|------|------|
| **항공기 타입** | All-electric VTOL (eVTOL) |
| **추진 시스템** | 6개 틸팅 프로펠러 (distributed electric propulsion) |
| **승객 정원** | 조종사 1명 + 승객 4명 |
| **최대 항속거리** | 150 miles (241 km) |
| **프로펠러 배치** | 전방 4개 + 후방 2개 (모두 틸팅 가능) |
| **비행 모드** | VTOL → Transition → Cruise (wing-borne) |

### 1.2 NASA 비행 시험 조건

**시험 장소**: Joby Aviation Electric Flight Base, California  
**측정 시스템**: 58-channel distributed microphone array  
**시험 항목**: 31 unique conditions, 100+ test points

#### 주요 비행 프로파일:

| Condition Code | Flight Type | 속도 범위 | 경로각 γ | 가속도 a∞ | 측정 횟수 |
|----------------|-------------|----------|----------|----------|----------|
| **T1-T3** | Departure | varies | +3° to +5° | +0.05g to +0.2g | 7 runs |
| **A1-A4** | Approach | varies | -3° to -5° | -0.05g to -0.1g | 14 runs |
| **L2-L8** | Level Flyover | 50-110 kt | 0° | 0 g | 15 runs |
| **H2-H7** | Hover (HIGE/HOGE) | 0 kt | 0° | 0 g | 11 runs |

**핵심 측정 데이터**:
- 항공기 위치 (x, y, z) - 실시간 tracking
- 나셀 각도 (θN): 0° (cruise) ~ 90° (VTOL)
- 프로펠러 RPM (Ω): 각 6개 프로펠러별
- 블레이드 피치각 (θb): 각 6개 프로펠러별
- 대기 속도 (V∞): True airspeed
- 바람 속도/방향: LiDAR 측정 (지상~1000 ft AGL)

---

## 2. GUAM 시뮬레이션 능력

### 2.1 GUAM의 현재 시뮬레이션 능력

**GUAM (Generic Urban Air Mobility)**은 NASA Langley에서 개발한 고정밀도 eVTOL 시뮬레이션 플랫폼입니다.

**주요 기능**:
- ✅ 6-DOF (Degrees of Freedom) 비행 역학 시뮬레이션
- ✅ Distributed electric propulsion 모델링
- ✅ Tilting rotor/propeller dynamics
- ✅ Transition flight (VTOL ↔ Cruise) 시뮬레이션
- ✅ 바람/난류 환경 모델링
- ✅ Flight control system (FCS) 시뮬레이션
- ✅ 베지어 곡선 기반 궤적 생성

**시뮬레이션 출력**:
- 시간별 항공기 위치 (North, East, Down)
- 자세 (Roll, Pitch, Yaw)
- 속도 (V_x, V_y, V_z, V∞)
- 가속도 (a_x, a_y, a_z)
- 프로펌러 상태 (RPM, pitch, thrust)
- 나셀 각도 (각 틸팅 프로펠러별)

### 2.2 GUAM vs Joby 항공기 비교

| 특성 | GUAM | Joby (실제) | 비교 가능성 |
|------|------|-------------|------------|
| 프로펠러 개수 | 6개 (설정 가능) | 6개 | ✅ 동일 |
| 틸팅 메커니즘 | 시뮬레이션 | 실제 시스템 | ✅ 비교 가능 |
| 전기 추진 | 모델링 | 실제 | ✅ 비교 가능 |
| 비행 모드 | VTOL/Transition/Cruise | 동일 | ✅ 동일 |
| 제어 시스템 | Generic FCS | Joby proprietary | ⚠️ 근사 가능 |

**검증 범위**: GUAM이 Joby 항공기의 일반적인 비행 특성을 얼마나 정확히 재현하는가?

---

## 3. 검증 방법론

### 3.1 검증 접근법: Trajectory Matching

NASA 비행 시험 데이터와 GUAM 시뮬레이션을 비교하는 핵심 방법론은 **Trajectory Matching**입니다.

```
┌─────────────────────────────────────────────────────────────┐
│                  VALIDATION WORKFLOW                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. REAL FLIGHT TEST DATA (NASA)                            │
│     ├─ Flight Path: (x, y, z) vs time                       │
│     ├─ Vehicle State: V∞, γ, a∞, θN                        │
│     ├─ Propeller State: Ω, θb (6 propellers)               │
│     └─ Environmental: wind profile                          │
│                      ↓                                       │
│  2. EXTRACT INITIAL CONDITIONS                              │
│     ├─ Starting position, velocity, attitude                │
│     ├─ Target trajectory parameters                         │
│     └─ Environmental conditions                             │
│                      ↓                                       │
│  3. RUN GUAM SIMULATION                                     │
│     ├─ Configure same initial conditions                    │
│     ├─ Command same trajectory profile                      │
│     └─ Apply same environmental settings                    │
│                      ↓                                       │
│  4. COMPARE OUTPUTS                                         │
│     ├─ Trajectory deviation (position error)                │
│     ├─ State parameters (V∞, γ, a∞)                        │
│     ├─ Control inputs (θN, Ω, θb)                          │
│     └─ Time-domain alignment                                │
│                      ↓                                       │
│  5. QUANTIFY FIDELITY                                       │
│     ├─ RMS errors                                           │
│     ├─ Statistical metrics (mean, std, R²)                  │
│     └─ Visual overlays                                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 세부 검증 시나리오

#### Scenario 1: Departure Trajectory Validation
**목표**: GUAM이 Departure 궤적을 얼마나 정확히 재현하는가?

**비교 대상**: NASA Test Point T2 (γ=3°, a∞=0.1g)

1. **입력 설정**:
   ```matlab
   % From real flight test
   initial_position = [x0, y0, z0];  % Takeoff point
   target_gamma = 3.0;  % deg
   target_accel = 0.1;  % g
   wind_profile = load('NASA_wind_day2.mat');
   ```

2. **GUAM 시뮬레이션 실행**:
   ```matlab
   % Configure GUAM
   guam_config.trajectory_type = 'departure';
   guam_config.flight_path_angle = 3.0;
   guam_config.acceleration = 0.1;
   guam_config.wind = wind_profile;
   
   % Run simulation
   [guam_traj, guam_state] = run_GUAM_sim(guam_config);
   ```

3. **비교 메트릭 계산**:
   ```matlab
   % Position RMSE
   pos_error = sqrt(mean((real_pos - guam_pos).^2));
   
   % State parameter comparison
   gamma_error = mean(abs(real_gamma - guam_gamma));
   accel_error = mean(abs(real_accel - guam_accel));
   ```

#### Scenario 2: Level Flyover Validation
**목표**: 정상 비행(cruise) 상태의 정확도 검증

**비교 대상**: NASA Test Point L7 (V∞=100 kt, level flight)

#### Scenario 3: Approach Trajectory Validation
**목표**: Approach 궤적의 하강 각도 및 감속 정확도

**비교 대상**: NASA Test Point A3 (γ=-3°, a∞=-0.1g)

#### Scenario 4: Hover Validation
**목표**: 제자리 비행(HIGE/HOGE) 안정성 검증

**비교 대상**: NASA Test Point H6 (HOGE)

---

## 4. 비교 메트릭

### 4.1 Position/Trajectory Metrics

#### 4.1.1 3D Position RMSE
```matlab
% Root Mean Square Error in 3D space
RMSE_3D = sqrt(mean((x_real - x_guam).^2 + (y_real - y_guam).^2 + (z_real - z_guam).^2))
```

**허용 기준**: 
- ✅ Excellent: RMSE < 10 m (항공기 길이의 ~1-2배)
- ⚠️ Acceptable: RMSE < 50 m
- ❌ Poor: RMSE > 100 m

#### 4.1.2 Cross-Track Error
```matlab
% Lateral deviation from flight path
e_crosstrack = perpendicular_distance_to_path(real_traj, guam_traj)
```

#### 4.1.3 Altitude Error
```matlab
% Vertical position error
e_altitude = abs(z_real - z_guam)
```

### 4.2 State Parameter Metrics

#### 4.2.1 Flight Path Angle Error
```matlab
% Difference in climb/descent angle
Δγ = mean(abs(γ_real - γ_guam))  % degrees
```

**허용 기준**: Δγ < 1° (excellent), Δγ < 2° (acceptable)

#### 4.2.2 Airspeed Error
```matlab
% True airspeed deviation
ΔV∞ = mean(abs(V∞_real - V∞_guam))  % knots
```

**허용 기준**: ΔV∞ < 5 kt (excellent), ΔV∞ < 10 kt (acceptable)

#### 4.2.3 Acceleration Error
```matlab
% Longitudinal acceleration difference
Δa = mean(abs(a∞_real - a∞_guam))  % g
```

### 4.3 Control Input Metrics

#### 4.3.1 Nacelle Angle Comparison
```matlab
% Tilt angle tracking
ΔθN = mean(abs(θN_real - θN_guam))  % degrees
```

**의미**: Transition 동안 GUAM이 나셀 각도를 얼마나 정확히 예측하는가?

#### 4.3.2 Propeller RPM Comparison
```matlab
% Average RPM difference across 6 propellers
ΔΩ = mean(abs(Ω_real - Ω_guam))  % RPM
```

### 4.4 Statistical Validation Metrics

#### 4.4.1 Coefficient of Determination (R²)
```matlab
% How well GUAM predictions match real data
R2 = 1 - sum((real - guam).^2) / sum((real - mean(real)).^2)
```

**해석**:
- R² > 0.95: Excellent correlation
- R² > 0.85: Good correlation
- R² < 0.70: Poor correlation

#### 4.4.2 Normalized RMSE
```matlab
% RMSE normalized by data range
NRMSE = RMSE / (max(real) - min(real))
```

**허용 기준**: NRMSE < 0.1 (10%)

### 4.5 Time-Domain Correlation

#### 4.5.1 Dynamic Time Warping (DTW)
```matlab
% Measure similarity between time-series trajectories
dtw_distance = dtw(real_traj, guam_traj)
```

**용도**: 궤적 형상이 유사하지만 시간 축에서 약간 shifted된 경우 평가

---

## 5. 데이터 처리 절차

### 5.1 Real Flight Data Extraction

**입력**: NASA Acoustic Flight Test Dataset

#### Step 1: Load Flight Test Data
```matlab
% Load NASA flight test data
nasa_data = load('Joby_Flight_Test_Data.mat');

% Extract specific test point
test_point = 'T2';  % Departure, γ=3°, a∞=0.1g
run_number = 1;

% Time-series data
time = nasa_data.(test_point)(run_number).time;
position = nasa_data.(test_point)(run_number).position;  % [N, E, D]
velocity = nasa_data.(test_point)(run_number).velocity;  % [Vn, Ve, Vd]
attitude = nasa_data.(test_point)(run_number).attitude;  % [roll, pitch, yaw]
nacelle_angle = nasa_data.(test_point)(run_number).nacelle;  % θN [6×1]
rpm = nasa_data.(test_point)(run_number).rpm;  % Ω [6×1]
blade_pitch = nasa_data.(test_point)(run_number).blade_pitch;  % θb [6×1]
```

#### Step 2: Compute Derived Parameters
```matlab
% Flight path angle
gamma = atan2d(-velocity(:,3), sqrt(velocity(:,1).^2 + velocity(:,2).^2));

% True airspeed
V_infinity = sqrt(sum(velocity.^2, 2));

% Acceleration (based on true airspeed)
a_infinity = diff(V_infinity) ./ diff(time) / 9.81;  % in g
```

#### Step 3: Segment Event Window
```matlab
% Define valid event window (e.g., x = -800 ft to V∞ = 60 kt)
event_start_idx = find(position(:,1) >= -800, 1, 'first');
event_end_idx = find(V_infinity >= 60, 1, 'first');

% Extract event data
real_flight = struct();
real_flight.time = time(event_start_idx:event_end_idx);
real_flight.position = position(event_start_idx:event_end_idx, :);
real_flight.velocity = velocity(event_start_idx:event_end_idx, :);
% ... etc
```

### 5.2 GUAM Simulation Setup

#### Step 1: Extract Initial Conditions from Real Flight
```matlab
% Initial state from real flight test
IC = struct();
IC.position = real_flight.position(1, :);  % [N, E, D]
IC.velocity = real_flight.velocity(1, :);  % [Vn, Ve, Vd]
IC.attitude = real_flight.attitude(1, :);  % [φ, θ, ψ]
IC.nacelle_angle = mean(real_flight.nacelle_angle(1, :));  % Initial θN
```

#### Step 2: Define Target Trajectory
```matlab
% Target parameters (from NASA test point specification)
target = struct();
target.flight_path_angle = 3.0;  % deg
target.acceleration = 0.1;  % g
target.final_altitude = real_flight.position(end, 3);  % D (down)
target.duration = real_flight.time(end) - real_flight.time(1);  % sec
```

#### Step 3: Configure GUAM Environment
```matlab
% Environmental conditions
environment = struct();
environment.wind_north = interp1(wind_data.altitude, wind_data.north, IC.position(3));
environment.wind_east = interp1(wind_data.altitude, wind_data.east, IC.position(3));
environment.temperature = 20;  % °C (from NASA test day)
environment.pressure = 101325;  % Pa
```

#### Step 4: Run GUAM Simulation
```matlab
% GUAM simulation call (pseudocode)
guam_output = run_GUAM(IC, target, environment);

% Extract outputs
guam_flight = struct();
guam_flight.time = guam_output.time;
guam_flight.position = guam_output.position;
guam_flight.velocity = guam_output.velocity;
% ... etc
```

### 5.3 Data Alignment and Interpolation

#### Time Synchronization
```matlab
% Align time axes (both start at t=0)
real_flight.time = real_flight.time - real_flight.time(1);
guam_flight.time = guam_flight.time - guam_flight.time(1);

% Interpolate to common time vector
common_time = 0:0.1:min(real_flight.time(end), guam_flight.time(end));

real_interp.position = interp1(real_flight.time, real_flight.position, common_time);
guam_interp.position = interp1(guam_flight.time, guam_flight.position, common_time);
```

#### Spatial Registration
```matlab
% Align coordinate systems (if needed)
% Ensure both use same origin and axes convention (NED vs ENU)
```

---

## 6. 통계 검증 기법

### 6.1 Bland-Altman Analysis

**용도**: 두 측정 방법(Real vs GUAM) 간의 agreement 평가

```matlab
function bland_altman_plot(real, guam, param_name)
    % Mean of two methods
    mean_val = (real + guam) / 2;
    
    % Difference
    diff_val = real - guam;
    
    % Statistics
    mean_diff = mean(diff_val);
    std_diff = std(diff_val);
    
    % 95% limits of agreement
    upper_limit = mean_diff + 1.96 * std_diff;
    lower_limit = mean_diff - 1.96 * std_diff;
    
    % Plot
    figure;
    scatter(mean_val, diff_val, 'filled');
    hold on;
    yline(mean_diff, 'r--', 'Mean Difference');
    yline(upper_limit, 'b--', '+1.96 SD');
    yline(lower_limit, 'b--', '-1.96 SD');
    xlabel('Mean of Real and GUAM');
    ylabel('Difference (Real - GUAM)');
    title(['Bland-Altman Plot: ' param_name]);
    grid on;
end
```

### 6.2 Confidence Intervals

```matlab
% 95% confidence interval for RMSE
n = length(errors);
se = std(errors) / sqrt(n);  % Standard error
ci_95 = [mean(errors) - 1.96*se, mean(errors) + 1.96*se];
```

### 6.3 Hypothesis Testing

**Null Hypothesis (H₀)**: GUAM predictions are not significantly different from real flight

```matlab
% Paired t-test
[h, p] = ttest(real_data, guam_data);

if p < 0.05
    fprintf('Significant difference detected (p = %.4f)\n', p);
else
    fprintf('No significant difference (p = %.4f) - GUAM validated!\n', p);
end
```

---

## 7. 구현 계획

### 7.1 Phase 0: Data Preparation

**목표**: NASA 비행 시험 데이터를 MATLAB 형식으로 변환

```
Tasks:
□ NASA 데이터 파일 포맷 분석 (PDF에서 데이터 추출 불가 - NASA에 요청 필요)
□ 데이터 구조 정의 (struct 형식)
□ 시간별 궤적 데이터 구성
□ 프로펠러 상태 데이터 구성
□ 환경 데이터 (바람 프로파일) 구성
```

**예상 출력**:
```
NASA_Flight_Test_Data/
├── Departures/
│   ├── T1_run1.mat
│   ├── T2_run1.mat
│   └── ...
├── Approaches/
│   ├── A1_run1.mat
│   └── ...
├── Level_Flyovers/
│   ├── L7_run1.mat
│   └── ...
└── Hover/
    ├── H2_run1.mat
    └── ...
```

### 7.2 Phase 1: GUAM Configuration

**목표**: GUAM을 Joby 항공기 특성에 맞게 설정

```matlab
% Joby configuration for GUAM
joby_config = struct();
joby_config.num_propellers = 6;
joby_config.propeller_layout = [4, 2];  % 4 forward, 2 aft
joby_config.max_tilt_angle = 90;  % deg (full VTOL capability)
joby_config.mass = 2177;  % kg (example, actual TBD)
joby_config.wing_area = 10.7;  % m^2 (example)
% ... additional parameters
```

### 7.3 Phase 2: Validation Script Development

**파일**: `validate_GUAM_vs_NASA.m`

```matlab
function validation_results = validate_GUAM_vs_NASA(test_point_id)
% VALIDATE_GUAM_VS_NASA - Compare GUAM simulation with NASA flight test
%
% Inputs:
%   test_point_id - NASA test point code (e.g., 'T2', 'A3', 'L7')
%
% Outputs:
%   validation_results - Structure with comparison metrics

% Load real flight data
real_flight = load_NASA_data(test_point_id);

% Extract initial conditions
IC = extract_initial_conditions(real_flight);

% Run GUAM simulation
guam_flight = run_GUAM_simulation(IC, real_flight.target_params);

% Compute comparison metrics
metrics = compute_validation_metrics(real_flight, guam_flight);

% Generate plots
generate_comparison_plots(real_flight, guam_flight, test_point_id);

% Compile results
validation_results = struct();
validation_results.test_point = test_point_id;
validation_results.metrics = metrics;
validation_results.real_data = real_flight;
validation_results.guam_data = guam_flight;
validation_results.timestamp = datetime('now');

% Save results
save(sprintf('Validation_Results_%s.mat', test_point_id), 'validation_results');

end
```

### 7.4 Phase 3: Batch Validation

**목표**: 여러 test point에 대해 자동 검증 실행

```matlab
% Batch validation script
test_points = {'T1', 'T2', 'T3', 'A1', 'A3', 'A4', 'L2', 'L7', 'H6'};

summary_results = struct();
for i = 1:length(test_points)
    fprintf('Validating %s...\n', test_points{i});
    summary_results.(test_points{i}) = validate_GUAM_vs_NASA(test_points{i});
end

% Generate summary report
generate_validation_report(summary_results);
```

### 7.5 Phase 4: Report Generation

**출력 형식**:
1. **Technical Report (PDF)**
   - Executive Summary
   - Methodology
   - Results by Flight Condition
   - Statistical Analysis
   - Conclusions and Recommendations

2. **Visualization Dashboard (MATLAB App)**
   - Interactive 3D trajectory comparison
   - Time-series parameter plots
   - Error distribution histograms
   - Correlation scatter plots

---

## 8. 예상 결과 및 해석

### 8.1 Good Validation (GUAM is Accurate)

**지표**:
- Position RMSE < 20 m
- Flight path angle error < 1°
- Airspeed error < 5 kt
- R² > 0.90 for all key parameters

**해석**: GUAM은 Joby 항공기의 비행 특성을 높은 정확도로 재현함. UAM 절차 설계에 신뢰할 수 있음.

### 8.2 Moderate Validation (Acceptable with Caveats)

**지표**:
- Position RMSE 20-50 m
- Flight path angle error 1-2°
- Some systematic bias in control inputs

**해석**: GUAM은 전반적인 경향을 재현하나, 특정 영역(예: transition 구간)에서 정밀도 향상 필요.

### 8.3 Poor Validation (Needs Improvement)

**지표**:
- Position RMSE > 100 m
- Large deviations in state parameters
- R² < 0.70

**해석**: GUAM 모델 파라미터 재조정 또는 물리 모델 개선 필요.

---

## 9. 제한사항 및 고려사항

### 9.1 데이터 가용성

**문제**: NASA 논문에는 궤적 및 상태 데이터의 그래프만 포함되어 있고, 실제 시계열 수치 데이터는 공개되지 않음.

**해결 방안**:
1. **NASA에 데이터 요청**: AAM National Campaign은 public-private partnership이므로 연구 목적의 데이터 공유 가능성 있음
2. **Digital 그래프 데이터 추출**: PDF 그래프에서 WebPlotDigitizer 등을 이용해 근사 데이터 추출 (정확도 제한적)
3. **GUAM Challenge Problems 활용**: 현재 보유한 3000개 시나리오를 대안으로 사용

### 9.2 Proprietary Information

**Joby 항공기 사양**: 일부 성능 데이터는 기밀

**대응**: Generic eVTOL 파라미터 사용, 상대 비교에 집중

### 9.3 Environmental Factors

**바람 효과**: 실제 비행은 바람의 영향을 받았으나, GUAM 시뮬레이션에서 정확히 재현하기 어려움

**대응**: Wind-corrected parameters 사용 (V∞ 대신 ground speed)

---

## 10. 결론 및 권장사항

### 10.1 검증 방법론 요약

```
┌─────────────────────────────────────────────────────────────┐
│            GUAM VALIDATION METHODOLOGY                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  INPUT: NASA Joby Flight Test Data                         │
│   ↓                                                         │
│  PROCESS: Trajectory Matching & State Comparison           │
│   ↓                                                         │
│  OUTPUT: Quantitative Fidelity Metrics                     │
│   ↓                                                         │
│  CONCLUSION: GUAM Accuracy Assessment                      │
│                                                             │
│  KEY METRICS:                                               │
│  • Position RMSE (< 20 m excellent)                         │
│  • Flight path angle error (< 1° excellent)                 │
│  • Control input correlation (R² > 0.90)                    │
│                                                             │
│  APPLICATION:                                               │
│  → Validate UAM Procedure Design Standards                 │
│  → Quantify simulation uncertainty                         │
│  → Inform safety criteria derivation                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 10.2 다음 단계

1. **NASA 데이터 획득**: 실제 수치 데이터 요청
2. **GUAM 설정 최적화**: Joby 파라미터 반영
3. **검증 스크립트 개발**: `validate_GUAM_vs_NASA.m` 구현
4. **배치 실행 및 분석**: 여러 test point 비교
5. **검증 보고서 작성**: 결과 문서화

### 10.3 UAM Procedure R&D에 미치는 영향

**검증 완료 시 기대 효과**:
- ✅ GUAM 시뮬레이션 신뢰도 정량화
- ✅ TSE 모델링의 불확실성 경계 설정
- ✅ 절차 설계 기준의 신뢰 구간 제시
- ✅ 규제 당국(FAA)에 대한 과학적 근거 강화

---

## 참고문헌 / References

1. **Pascioni, K. A., et al.** (2023). "Acoustic Flight Test of the Joby Aviation Advanced Air Mobility Prototype Vehicle." NASA Langley Research Center Technical Paper.

2. **NASA Advanced Air Mobility Project** (2023). "AAM National Campaign." https://www.nasa.gov/aam

3. **GUAM User's Guide** (2022). NASA Langley Research Center.

4. **Challenge Problems Dataset** (2024). GUAM Verification and Validation Suite.

---

**문서 작성일**: 2024-11-25  
**작성자**: UAM Procedure R&D Team  
**버전**: 1.0

---

## 부록: 코드 예제

### A.1 Load NASA Data (Pseudocode)

```matlab
function flight_data = load_NASA_data(test_point_id)
    % Load specific test point from NASA dataset
    % NOTE: Actual implementation depends on NASA data format
    
    data_path = fullfile('NASA_Flight_Test_Data', [test_point_id '_run1.mat']);
    
    if ~exist(data_path, 'file')
        error('Test point data not found: %s', test_point_id);
    end
    
    raw_data = load(data_path);
    
    % Structure the data
    flight_data = struct();
    flight_data.time = raw_data.time;
    flight_data.position = raw_data.position;  % [N, E, D] in meters
    flight_data.velocity = raw_data.velocity;  % [Vn, Ve, Vd] in m/s
    flight_data.attitude = raw_data.attitude;  % [roll, pitch, yaw] in deg
    flight_data.nacelle_angle = raw_data.nacelle;
    flight_data.rpm = raw_data.rpm;
    flight_data.blade_pitch = raw_data.blade_pitch;
    
    % Compute derived parameters
    flight_data.V_infinity = sqrt(sum(flight_data.velocity.^2, 2));
    flight_data.gamma = atan2d(-flight_data.velocity(:,3), ...
        sqrt(flight_data.velocity(:,1).^2 + flight_data.velocity(:,2).^2));
end
```

### A.2 Compute Validation Metrics

```matlab
function metrics = compute_validation_metrics(real_flight, guam_flight)
    % Align time vectors
    common_time = intersect(real_flight.time, guam_flight.time);
    
    % Interpolate to common time
    real_pos = interp1(real_flight.time, real_flight.position, common_time);
    guam_pos = interp1(guam_flight.time, guam_flight.position, common_time);
    
    % Position RMSE
    metrics.position_rmse = sqrt(mean(sum((real_pos - guam_pos).^2, 2)));
    
    % Flight path angle error
    real_gamma = interp1(real_flight.time, real_flight.gamma, common_time);
    guam_gamma = interp1(guam_flight.time, guam_flight.gamma, common_time);
    metrics.gamma_error = mean(abs(real_gamma - guam_gamma));
    
    % Airspeed error
    real_V = interp1(real_flight.time, real_flight.V_infinity, common_time);
    guam_V = interp1(guam_flight.time, guam_flight.V_infinity, common_time);
    metrics.airspeed_error = mean(abs(real_V - guam_V));
    
    % R-squared correlation
    metrics.position_R2 = compute_R2(real_pos, guam_pos);
    metrics.gamma_R2 = compute_R2(real_gamma, guam_gamma);
    metrics.airspeed_R2 = compute_R2(real_V, guam_V);
end

function R2 = compute_R2(observed, predicted)
    SS_res = sum((observed - predicted).^2);
    SS_tot = sum((observed - mean(observed)).^2);
    R2 = 1 - SS_res / SS_tot;
end
```

---

**End of Document**
