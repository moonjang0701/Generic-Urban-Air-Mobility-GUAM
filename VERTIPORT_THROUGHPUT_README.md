# Vertiport Airspace Throughput Safety Assessment

## 개요

버티포트 공역에서 **목표 처리량 150 movements/hour**를 처리할 때의 안전성을 평가합니다.

### 핵심 특징

✅ **실제 GUAM 시뮬레이션 사용**  
- 각 비행마다 NASA GUAM 6-DOF 시뮬레이터를 실제로 실행
- 단순 모델이 아닌, 실제 기체 동역학 응답 사용

✅ **랜덤 바람/난류 조건**  
- 비행마다 다른 바람 속도/방향 (0-20 knots, omnidirectional)
- 난류 강도 (light/moderate/severe)를 확률적으로 샘플링

✅ **TSE 자동 계산**  
- GUAM 출력에서 실제 궤적 추출
- 기준 궤적 대비 lateral TSE 계산
- 300m 한계 초과 여부 자동 체크

✅ **고도 범위 체크**  
- 300m ~ 600m 고도 범위 유지 여부 확인
- 위반 시 unsafe로 분류

## 🚀 빠른 시작

### 방법 1: Quick Test (5~10분)

```matlab
cd /home/user/webapp/Exec_Scripts
run_vertiport_throughput_MC_QUICK
```

**Quick Test 설정**:
- 공역 반지름: 1500m (고정)
- Monte Carlo: 5회 반복
- 운용 시간: 1시간 (150 movements)
- 총 비행: ~750회 (5 MC × 150 mvh)

### 방법 2: Full Simulation (1~2시간)

```matlab
cd /home/user/webapp/Exec_Scripts
run_vertiport_throughput_MC
```

**Full Simulation 설정**:
- 공역 반지름: 1000m, 1500m, 2000m
- Monte Carlo: 50회 반복
- 운용 시간: 8시간 (1200 movements)
- 총 비행: ~180,000회 (3 radii × 50 MC × 1200 mvh)

## 📊 결과 예시

### Quick Test 예상 결과

```
╔══════════════════════════════════════════════════════════════╗
║  QUICK TEST RESULTS                                          ║
╚══════════════════════════════════════════════════════════════╝

Total Flights: 750
Safe Flights: 525 (70.00%)
Unsafe Flights: 225 (30.00%)
  - TSE Violations: 180
  - Altitude Violations: 45

TSE Statistics:
  Mean Max TSE: 245.32 m
  Std Max TSE: 85.67 m
  Max TSE: 487.23 m
  Min TSE: 82.14 m
```

### 출력 그래프

- `Quick_Test_TSE_Distribution.png`: TSE 분포 히스토그램
- `Vertiport_Safety_Assessment.png`: 공역 반지름별 안전성 비교 (Full Simulation)
- `Vertiport_TSE_Distributions.png`: R별 TSE 분포 (Full Simulation)

## 🔧 파라미터 수정

### Quick Test 수정 (`run_vertiport_throughput_MC_QUICK.m`)

```matlab
% Line 22-34: 주요 파라미터
R_AIRSPACE_M = 1500;              % 공역 반지름 [m]
N_MC_RUNS = 5;                    % Monte Carlo 반복 (5 → 20)
TARGET_THROUGHPUT_MVH = 150;      % 목표 처리량 [movements/hour]
OPERATION_HOURS = 1;              % 운용 시간 [hours] (1 → 4)
TSE_LIMIT_M = 300;                % TSE 한계 [m]
WIND_MAX_KT = 20;                 % 최대 풍속 [knots]
```

### Full Simulation 수정 (`run_vertiport_throughput_MC.m`)

```matlab
% Line 30-33: 공역 설정
R_AIRSPACE_M = [1000, 1500, 2000];  % 테스트할 반지름들 [m]

% Line 37-38: 처리량
TARGET_THROUGHPUT_MVH = 150;        % 목표 처리량
ARRIVAL_RATIO = 0.5;                % 도착:출발 비율 (0.5 = 1:1)

% Line 49-50: Monte Carlo
N_MC_RUNS = 50;                     % 반복 횟수 (50 → 100)
```

## 📈 처리량 시나리오 테스트

### 시나리오 1: 저밀도 (50 mvh/h)

```matlab
TARGET_THROUGHPUT_MVH = 50;
```

### 시나리오 2: 중밀도 (100 mvh/h)

```matlab
TARGET_THROUGHPUT_MVH = 100;
```

### 시나리오 3: 고밀도 (150 mvh/h) ← 기본값

```matlab
TARGET_THROUGHPUT_MVH = 150;
```

### 시나리오 4: 초고밀도 (200 mvh/h)

```matlab
TARGET_THROUGHPUT_MVH = 200;
```

## 🎯 안전성 판단 기준

### TSE (Total System Error)

- **한계값**: 300m (lateral)
- **측정**: GUAM 실제 궤적 vs 기준 직선 궤적
- **위반**: max(TSE) > 300m

### 고도 범위

- **허용 범위**: 300m ~ 600m
- **측정**: GUAM 출력 고도 (altitude = -Down)
- **위반**: altitude < 300m OR altitude > 600m

### 안전 확률 목표

- **P(safe) ≥ 80%**: 안전한 운용 가능
- **P(safe) 50~80%**: 제한적 운용
- **P(safe) < 50%**: 운용 부적합

## 🔬 GUAM 연동 상세

### 각 비행마다 실행되는 과정

1. **궤적 생성**
   - 도착: boundary(R, θ) → vertiport(0,0)
   - 출발: vertiport(0,0) → boundary(R, θ)
   - Bezier 곡선으로 waypoint 생성

2. **바람/난류 적용**
   ```matlab
   SimIn = apply_wind_to_GUAM(SimIn, wind_speed_kt, wind_dir_deg);
   SimIn = apply_turbulence_to_GUAM(SimIn, turbulence_level);
   ```

3. **GUAM 실행**
   ```matlab
   simOut = sim('GUAM', 'ReturnWorkspaceOutputs', 'on', ...
                'StopTime', num2str(total_sim_time_s));
   ```

4. **TSE 계산**
   ```matlab
   logsout = simOut.logsout;
   pos_data = logsout.getElement('Pos_bIi').Values;
   lateral_error = sqrt((pos_N - ref_N).^2 + (pos_E - ref_E).^2);
   max_tse = max(lateral_error);
   ```

5. **안전성 판단**
   ```matlab
   is_safe = (max_tse <= 300) && (altitude in [300, 600]);
   ```

## ⚠️ 주의사항

### 1. MATLAB 환경 필요

- MATLAB R2020b 이상 권장
- Simulink 필수
- Aerospace Blockset 권장

### 2. 실행 시간

- Quick Test: ~5-10분
- Full Simulation: ~1-2시간 (시스템 성능에 따라 다름)

### 3. GUAM 초기화 필수

스크립트는 자동으로 GUAM을 초기화하지만, 문제 발생 시:

```matlab
cd /home/user/webapp
setupPath
simSetup
```

### 4. 메모리 사용

- Full Simulation은 많은 메모리 사용 (~4GB+)
- 메모리 부족 시 N_MC_RUNS 감소 권장

## 🐛 문제 해결

### 문제 1: GUAM 초기화 실패

```
Error: Undefined function or variable 'SimIn'
```

**해결**:
```matlab
cd /home/user/webapp
simSetup
run_vertiport_throughput_MC_QUICK
```

### 문제 2: evalSegments 함수 없음

```
Error: Undefined function 'evalSegments'
```

**해결**:
```matlab
addpath(genpath('Bez_Functions'));
```

### 문제 3: 시뮬레이션 너무 느림

**해결 1**: Quick Test 사용
```matlab
run_vertiport_throughput_MC_QUICK
```

**해결 2**: 파라미터 축소
```matlab
N_MC_RUNS = 10;        % 50 → 10
OPERATION_HOURS = 2;   % 8 → 2
```

### 문제 4: 일부 비행 실패 (PropSpeed assertion)

이는 정상입니다. 극단적 바람/난류 조건에서 일부 비행이 실패할 수 있으며, 자동으로 "unsafe"로 처리됩니다.

## 📚 참고 파일

- `run_vertiport_throughput_MC.m`: Full simulation (메인)
- `run_vertiport_throughput_MC_QUICK.m`: Quick test (빠른 검증)
- `apply_wind_to_GUAM.m`: 바람 적용 헬퍼 함수
- `apply_turbulence_to_GUAM.m`: 난류 적용 헬퍼 함수
- `run_MC_TSE_safety.m`: 기존 corridor 안전성 평가 (참고용)

## 🎓 이론 배경

### TSE (Total System Error)

TSE = √(FTE² + NSE² + PDE²)

- **FTE (Flight Technical Error)**: 조종 오차
- **NSE (Navigation System Error)**: 항법 시스템 오차
- **PDE (Path Definition Error)**: 경로 정의 오차

본 시뮬레이션에서는 GUAM이 FTE를 자동으로 계산하고, NSE는 Kalman filter로 모델링됩니다.

### Monte Carlo 방법론

각 비행마다 다음을 랜덤 샘플링:
1. 진입/이탈 방향 θ ~ Uniform(0, 2π)
2. 바람 속도 ~ Uniform(0, WIND_MAX_KT)
3. 바람 방향 ~ Uniform(0, 360°)
4. 난류 강도 ~ Categorical(light, moderate, severe)

→ N_MC × N_movements 회 반복으로 통계적 신뢰도 확보

## 📞 지원

문제 발생 시:
1. Quick Test부터 시작
2. 콘솔 출력 확인
3. GUAM 초기화 상태 점검
4. 파라미터 축소 테스트

---

**작성일**: 2025-12-02  
**버전**: 1.0  
**GUAM Version**: NASA Generic Urban Air Mobility Simulator
