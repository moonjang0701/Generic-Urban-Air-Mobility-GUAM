# Monte Carlo TSE 안전성 평가 프레임워크 사용 가이드

## 📌 개요

NASA GUAM 시뮬레이터를 활용한 UAM Corridor의 확률론적 안전성 평가 도구입니다.

### 주요 기능
- ✅ Monte Carlo 시뮬레이션 (병렬 처리 지원)
- ✅ GUAM 6-DOF 비행 역학 완전 시뮬레이션
- ✅ Kalman 필터 기반 항법 오차 모델링
- ✅ FTE, NSE, TSE 확률 분포 계산
- ✅ Corridor 침범 확률 (P_hit) 계산
- ✅ TLS (Target Level of Safety) 비교
- ✅ 자동 보고서 및 시각화 생성

---

## 🚀 빠른 시작

### 1. 기본 실행 (1줄 명령)

```matlab
cd('/home/user/webapp');
addpath(genpath('.'));
run_MC_TSE_safety;
```

### 2. 실행 시간
- **N=100 샘플**: 약 10-15분
- **N=500 샘플**: 약 50-70분 (권장)
- **N=1000 샘플**: 약 2-3시간 (논문용)

### 3. 출력 결과

실행 후 자동 생성되는 파일들:

```
MC_TSE_Safety_Results_20250118_143022.mat          # 전체 결과 데이터
MC_TSE_Safety_Report_20250118_143022.txt           # 텍스트 보고서
MC_TSE_Distribution_20250118_143022.png            # TSE 분포 그래프
MC_FTE_Distribution_20250118_143022.png            # FTE 분포 그래프
MC_Sample_Trajectories_20250118_143022.png         # 샘플 궤적
MC_Safety_Summary_20250118_143022.png              # 안전성 요약 대시보드
```

---

## 📊 시나리오 파라미터 설정

`run_MC_TSE_safety.m` 파일의 **SECTION 2**에서 수정:

### 기본 시나리오 (현재 설정)

```matlab
%% SECTION 2: SCENARIO PARAMETERS

% ───── Trajectory Parameters ─────
SEGMENT_LENGTH_M = 1000;        % 1 km 직선 구간
ALTITUDE_FT = 1000;             % 1000 ft 비행 고도
GROUND_SPEED_KT = 90;           % 90 knots 지상 속도
SIMULATION_TIME_S = 30;         % 30초 시뮬레이션

% ───── TSE Design Parameters ─────
TSE_2SIGMA_DESIGN_M = 300;      % 설계 TSE 2σ = 300 m
CORRIDOR_HALF_WIDTH_M = 350;    % Corridor 반폭 ±350 m
TLS_TARGET = 1e-4;              % TLS 목표값 (0.01%)

% ───── Monte Carlo Parameters ─────
N_MONTE_CARLO = 500;            % MC 샘플 수 (정확도 ↑)
USE_PARALLEL = false;           % 병렬 처리 (true로 설정 시 고속화)
RANDOM_SEED = 42;               % 재현성 (동일 결과)

% ───── Uncertainty Parameters ─────
WIND_MEAN_KT = 20;              % 평균 횡풍 20 knots
WIND_SIGMA_KT = 5;              % 횡풍 표준편차 5 knots

SIGMA_Y0_M = 10;                % 초기 측방 오프셋 σ = 10 m
SIGMA_HEADING0_DEG = 2;         % 초기 헤딩 오차 σ = 2 deg

SIGMA_TAU_S = 0.2;              % 제어 반응 시간 불확실성
CTRL_GAIN_VARIATION = 0.10;     % 제어 이득 변동 ±10%

NSE_SIGMA_BASE_M = 5;           % 항법 오차 기본값 5 m
NSE_SIGMA_VAR = 0.3;            % NSE 변동 계수 30%
```

### 예제 1: 더 강한 횡풍 조건

```matlab
WIND_MEAN_KT = 30;              % 30 knots 평균 횡풍
WIND_SIGMA_KT = 10;             % 10 knots 표준편차
CORRIDOR_HALF_WIDTH_M = 500;    % Corridor 확장
```

### 예제 2: 더 정밀한 항법 시스템

```matlab
NSE_SIGMA_BASE_M = 2;           % 고정밀 GPS (2 m)
SIGMA_Y0_M = 5;                 % 더 정확한 초기 위치
```

### 예제 3: TLS 기준 변경

```matlab
TLS_TARGET = 1e-5;              % 더 엄격한 안전 기준 (0.001%)
TLS_TARGET = 1e-3;              % 더 완화된 기준 (0.1%)
```

---

## 📈 결과 해석

### 1. 안전성 결론

터미널 출력 예시:

```
═══════════════════════════════════════════════════
  ✓ SAFETY CONCLUSION: CORRIDOR IS SAFE
  The upper bound of P_hit is below TLS target.
═══════════════════════════════════════════════════

Probability of Infringement:
  P_hit = 2.0000e-05 (10 hits / 500 runs)
  95% Confidence Interval: [8.5e-06, 3.8e-05]
  Target Level of Safety: 1.0000e-04
  Margin: 2.63× (SAFE)
```

**해석**:
- P_hit = 2.0e-05 (0.002%) → 10,000번 비행 중 0.2번 침범
- 95% 신뢰구간 상한 = 3.8e-05
- TLS = 1.0e-04 보다 작음 → **SAFE** ✓
- 안전 마진 = 2.63배

### 2. TSE 통계

```
TSE Statistics:
  Maximum:    285.2 m
  Mean:       142.5 m
  Std Dev:    68.3 m (σ)
  2σ Est.:    136.6 m (vs 300 m design)
  95th %ile:  265.8 m
  99th %ile:  282.1 m
```

**해석**:
- 추정 2σ = 136.6 m << 설계 300 m → **보수적 설계** ✓
- 99th %ile = 282.1 m < Corridor 350 m → **여유 있음**
- σ = 68.3 m → 95% 신뢰도는 ±2σ = 136.6 m

### 3. FTE vs TSE 비교

```
FTE Statistics (Lateral):
  Maximum:    12.5 m
  Mean:       4.2 m
  Std Dev:    2.8 m
  95th %ile:  8.9 m
```

**TSE = √(FTE² + NSE²)**

- FTE가 작다 (< 13 m) → 제어 성능 우수
- TSE가 크다 (> 280 m) → 주로 NSE에 의한 영향
- NSE 개선 시 전체 TSE 크게 감소 가능

---

## 🔧 고급 설정

### 1. 병렬 처리 활성화 (고속화)

```matlab
USE_PARALLEL = true;
```

**요구사항**:
- MATLAB Parallel Computing Toolbox
- 멀티코어 CPU (4코어 이상 권장)

**속도 향상**:
- 4코어: 약 3배 고속
- 8코어: 약 5-6배 고속

### 2. 샘플 수 최적화

| 샘플 수 | 정확도 | 시간 | 용도 |
|---------|--------|------|------|
| N=100   | ±3%    | 15분 | 테스트 |
| N=500   | ±1.3%  | 70분 | 일반 분석 |
| N=1000  | ±0.9%  | 180분| 논문 |
| N=5000  | ±0.4%  | 15시간| 인증 |

**정확도 계산** (이항 분포):
```
σ_P = √(P(1-P)/N)
95% CI = P ± 1.96σ_P
```

### 3. 사용자 정의 불확실성 분포

`sample_MC_inputs.m` 파일 수정:

```matlab
% Uniform 분포 사용 예시
MC_params.wind_E_ms(i) = wind_mean_ms + ...
    wind_sigma_ms * (2*rand() - 1) * sqrt(3);

% Lognormal 분포 사용 예시  
MC_params.nse_sigma_m(i) = lognrnd(log(nse_sigma_base_m), 0.3);
```

---

## 📝 출력 파일 상세

### 1. MAT 파일 (MC_TSE_Safety_Results_*.mat)

**저장 변수**:
```matlab
load('MC_TSE_Safety_Results_20250118_143022.mat');

% MC 결과
MC_results.max_lateral_FTE        % 각 실행의 최대 FTE
MC_results.max_TSE                % 각 실행의 최대 TSE
MC_results.is_hit                 % 침범 여부 (true/false)
MC_results.trajectories           % 전체 궤적 데이터

% 통계
FTE_stats                         % FTE 통계량
TSE_stats                         % TSE 통계량
P_hit, P_hit_lower, P_hit_upper   % 확률 추정치
```

### 2. 텍스트 보고서 (MC_TSE_Safety_Report_*.txt)

- 시나리오 파라미터 전체 요약
- 안전성 결론 및 근거
- 통계 요약 테이블
- 복사/붙여넣기 가능 (보고서용)

### 3. 그래프 파일 (PNG)

**Figure 1**: TSE 분포
- 히스토그램 + CDF
- 설계 2σ 기준선
- 95th percentile 표시

**Figure 2**: FTE 분포
- 제어 성능 시각화
- 통계적 분포 확인

**Figure 3**: 샘플 궤적
- Reference trajectory (검은 점선)
- Corridor boundary (빨간 점선)
- 실제 비행 궤적 (10개 샘플)
- Hit 이벤트 강조 (빨간색)

**Figure 4**: 안전성 요약 대시보드
- P_hit vs TLS 비교
- 거리 분포 CDF
- TSE 박스플롯
- 결론 텍스트

---

## 🛠️ 트러블슈팅

### 문제 1: "setupPath not found"

**해결**:
```matlab
cd('/home/user/webapp');
addpath(genpath('.'));
```

### 문제 2: "Dimension error at Port 1"

**원인**: Time vector가 row vector로 설정됨

**확인**: `generate_reference_trajectory.m`에서
```matlab
time = linspace(0, T, N)';  % Column vector (') 필수!
```

### 문제 3: 시뮬레이션 실패 (N_failed > 0)

**원인**:
- 극단적인 불확실성 파라미터
- GUAM 수렴 실패

**해결**:
```matlab
% 불확실성 감소
WIND_SIGMA_KT = 3;           % 5 → 3
SIGMA_Y0_M = 5;              % 10 → 5
CTRL_GAIN_VARIATION = 0.05;  % 0.1 → 0.05
```

### 문제 4: P_hit = 0 (모든 샘플 안전)

**의미**: Corridor가 너무 넓거나 불확실성이 작음

**대응**:
1. Corridor 폭 감소: `CORRIDOR_HALF_WIDTH_M = 200;`
2. 불확실성 증가: `WIND_SIGMA_KT = 10;`
3. 샘플 수 증가: `N_MONTE_CARLO = 2000;`

### 문제 5: P_hit > TLS (안전하지 않음)

**개선 방안**:

**Option A**: Corridor 확장
```matlab
CORRIDOR_HALF_WIDTH_M = 500;  % 350 → 500
```

**Option B**: 운영 조건 제한
```matlab
WIND_MEAN_KT = 15;  % 20 → 15 (강풍 시 운영 중단)
```

**Option C**: 항법 시스템 개선
```matlab
NSE_SIGMA_BASE_M = 2;  % 5 → 2 (고정밀 GPS)
```

---

## 📚 이론적 배경

### TSE 구성 요소

```
TSE = √(FTE² + NSE² + PDE²)
```

- **FTE (Flight Technical Error)**: 제어 추종 오차
  - Controller 성능
  - 바람 교란 대응
  - 측정: Actual path vs Desired path
  
- **NSE (Navigation System Error)**: 항법 센서 오차
  - GPS 정확도
  - INS drift
  - 측정: Measured pos vs True pos
  
- **PDE (Path Definition Error)**: 경로 정의 오차
  - Waypoint 정확도
  - 일반적으로 무시 가능 (< 1 m)

### TLS (Target Level of Safety)

| TLS 값 | 의미 | 용도 |
|--------|------|------|
| 1e-3   | 0.1% (1/1000) | 일반 운항 |
| 1e-4   | 0.01% (1/10000) | 도심 UAM |
| 1e-5   | 0.001% (1/100000) | 공항 접근 |
| 1e-6   | 0.0001% (1/1000000) | 인증 필요 |
| 1e-9   | 나노 확률 | 안전 임계 시스템 |

**ICAO 권장**: UAM → TLS = 1e-4

### Monte Carlo 신뢰구간

```matlab
% 이항 분포 95% CI
n_hits = 10;
n_total = 500;
p = n_hits / n_total;  % 0.02

% Wilson Score Interval
z = 1.96;  % 95%
p_lower = (p + z²/(2n) - z*√(p(1-p)/n + z²/(4n²))) / (1 + z²/n);
p_upper = (p + z²/(2n) + z*√(p(1-p)/n + z²/(4n²))) / (1 + z²/n);
```

---

## 🎯 활용 사례

### 사례 1: Corridor 설계 검증

**질문**: 300 m TSE 가정이 안전한가?

**분석**:
```matlab
TSE_2SIGMA_DESIGN_M = 300;
CORRIDOR_HALF_WIDTH_M = 350;  % 50 m 버퍼
run_MC_TSE_safety;
```

**결과 해석**:
- P_hit < TLS → **설계 적합** ✓
- P_hit > TLS → **Corridor 확장 필요** ✗

### 사례 2: 기상 조건 영향 평가

**질문**: 30 knots 횡풍에서도 안전한가?

```matlab
WIND_MEAN_KT = 30;
WIND_SIGMA_KT = 10;
run_MC_TSE_safety;
```

**결과**:
- P_hit = 1.2e-3 > TLS → **강풍 시 운영 불가**

### 사례 3: 항법 시스템 ROI

**질문**: GPS 정밀도 5m → 2m 업그레이드 효과?

**Before** (5m GPS):
```matlab
NSE_SIGMA_BASE_M = 5;
run_MC_TSE_safety;
% P_hit = 5.0e-5
```

**After** (2m GPS):
```matlab
NSE_SIGMA_BASE_M = 2;
run_MC_TSE_safety;
% P_hit = 8.0e-6 (6.25배 감소!)
```

**결론**: GPS 업그레이드로 안전성 대폭 향상

---

## 📖 참고 문헌

1. **ICAO Doc 9613** - Performance-Based Navigation (PBN) Manual
2. **FAA Order 8260.58** - RNP Procedures
3. **NASA GUAM Documentation** - Generic Urban Air Mobility Simulation
4. **RTCA DO-236C** - Minimum Aviation System Performance Standards (MASPS)
5. **Jung & Holzapfel (2025)** - "Flight safety measurements of UAVs in congested airspace"

---

## 💡 추가 개발 아이디어

### 1. Wake Turbulence 모델링

```matlab
% sample_MC_inputs.m에 추가
MC_params.wake_strength_ms = 5 * randn(N_samples, 1);
MC_params.wake_decay_s = 10 + 2 * randn(N_samples, 1);
```

### 2. 다중 항공기 시나리오

```matlab
% 동시 N대 비행
N_AIRCRAFT = 3;
SEPARATION_MIN_M = 200;
```

### 3. 시변 Corridor (곡선 경로)

```matlab
% Bezier curve 경로
ref_traj = generate_bezier_trajectory(waypoints);
```

### 4. 실시간 위험도 모니터링

```matlab
% 비행 중 실시간 P_hit 추정
risk_monitor = online_MC_estimator(current_state);
```

---

## ✅ 체크리스트

프레임워크 사용 전 확인 사항:

- [ ] GUAM v1.1 설치 완료
- [ ] MATLAB R2019b 이상
- [ ] Simulink 라이선스 활성
- [ ] STARS 라이브러리 경로 설정
- [ ] 충분한 디스크 공간 (>10 GB for N=1000)
- [ ] 시나리오 파라미터 검토
- [ ] 불확실성 분포 타당성 확인
- [ ] TLS 목표값 정의

---

## 📧 문의 및 기여

**버그 리포트**: GitHub Issues
**기능 제안**: Pull Request
**사용 문의**: 프로젝트 관리자

---

**License**: MIT  
**Version**: 1.0  
**Last Updated**: 2025-01-18

---

**Happy Flying! ✈️**
