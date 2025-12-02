# UAM 버티포트 공역 시뮬레이션 (TSE 안전성 평가)

## 개요

도심 UAM(Urban Air Mobility) 버티포트 주변 원형 공역에서 이착륙 교통량에 따른 안전성을 평가하는 fast-time 시뮬레이터입니다.

### 주요 기능

1. **교통량 시뮬레이션**: 주어진 교통량(λ movements/hour)에 따라 이착륙 movements 생성
2. **궤적 생성**: 각 항공기에 대한 nominal trajectory 생성 (GUAM 연동 준비)
3. **난류/바람 모델링**: 랜덤 바람 및 난류 효과를 Ornstein-Uhlenbeck 프로세스로 모델링
4. **TSE 안전성 평가**: 
   - 수평 TSE 300m 한계 위반 여부 체크
   - 고도 범위(300~600m) 유지 여부 체크
5. **Monte Carlo 시뮬레이션**: 통계적 신뢰도 확보를 위한 반복 실행

## NASA GUAM 연동 구조

본 코드는 **NASA GUAM(Generic Urban Air Mobility) 시뮬레이터**와의 연동을 염두에 두고 설계되었습니다.

### GUAM 연동 예정 부분

#### 1. 궤적 생성 (`generate_nominal_trajectory` 함수)
```python
def generate_nominal_trajectory(movement, R, V_mean, dt, use_GUAM=False):
    if use_GUAM:
        # GUAM API 호출로 교체 예정
        # traj_data = GUAM_API.get_trajectory(...)
        # return Trajectory(t=traj_data['time'], x_nom=traj_data['x'], ...)
        pass
    else:
        # 현재: 단순 선형 궤적
        ...
```

#### 2. TSE 계산 (`apply_disturbances_and_check_TSE` 함수)
```python
def apply_disturbances_and_check_TSE(nom_traj, wind_params, use_GUAM_TSE=False):
    if use_GUAM_TSE:
        # GUAM에서 직접 계산된 TSE 데이터 사용
        # guam_tse_data = GUAM_API.get_TSE_data(...)
        # x_real = guam_tse_data['x_actual']
        # tse_values = guam_tse_data['lateral_TSE']
        pass
    else:
        # 현재: 단순 난류 모델
        ...
```

### GUAM 연동 시 기대되는 개선사항

- ✅ 실제 eVTOL 기체 동역학 응답 반영
- ✅ 정밀한 제어 시스템 모델링
- ✅ 실제 기상 조건 기반 TSE 계산
- ✅ 3D 궤적 최적화 및 충돌 회피

## 설치 및 실행

### 필요 라이브러리

```bash
pip install numpy matplotlib
```

### 실행 방법

```bash
python uam_vertiport_simulation.py
```

## 시뮬레이션 파라미터

### 공역 설정
- **R_list**: 공역 반지름 [m] - 예: `[1000, 1500, 2000]`
- **h_min, h_max**: 고도 범위 [m] - 300~600m

### 교통량 설정
- **lambda_list**: 교통량 [movements/hour] - 예: `[10, 20, 30, 40]`
- **arrival_ratio**: 도착/출발 비율 - 기본값 0.5 (1:1)

### 비행 파라미터
- **V_mean**: 평균 지상 속도 [m/s] - 기본값 50 m/s
- **dt**: 시간 step [s] - 기본값 1.0초

### 바람/난류 파라미터
- **W_max**: 최대 평균 풍속 [m/s] - 기본값 8.0 m/s
- **sigma_gust_max**: 최대 난류 표준편차 [m/s] - 기본값 5.0 m/s
- **tau_turb**: 난류 시상수 [s] - 기본값 10.0초 (OU process)

### 안전성 기준
- **tse_limit**: 수평 TSE 한계값 [m] - 기본값 300m
- **h_min, h_max**: 허용 고도 범위 [m] - 300~600m

### 시뮬레이션 설정
- **T_sim**: 총 시뮬레이션 시간 [s] - 기본값 28,800초 (8시간)
- **N_mc**: Monte Carlo 반복 횟수 - 기본값 100

## 출력 결과

### 1. 콘솔 출력
```
R [m]      λ [mvh/h]    Total      Unsafe     P(viol)      P(safe)     
--------------------------------------------------------------------------------
1000       10           8000       5974       0.7468       0.2532      
1000       20           16000      12080      0.7550       0.2450      
...
```

### 2. 시각화 결과

#### simulation_results.png
- **좌측**: TSE Violation 확률 히트맵
- **우측**: Safe Flight 확률 히트맵
- x축: 교통량 λ [movements/hour]
- y축: 공역 반지름 R [m]

#### tse_distribution.png
- 각 (R, λ) 조합별 최대 lateral TSE 분포
- TSE 한계선(300m) 표시

## 주요 결과 해석

### 시뮬레이션 결과 (예시)

1. **공역 반지름 영향**:
   - R=1000m: P(safe) ≈ 25%
   - R=1500m: P(safe) ≈ 24%
   - R=2000m: P(safe) ≈ 17%
   - → 반지름이 클수록 비행 시간이 길어져 TSE 누적 증가

2. **교통량 영향**:
   - λ=10~40 movements/hour 범위에서 P(safe)는 비교적 일정
   - → 현재 모델에서는 교통량보다 비행 거리가 더 큰 영향

3. **개선 필요 사항**:
   - 바람/난류 파라미터 조정 필요 (현재 설정이 과도할 수 있음)
   - GUAM 연동 시 더 현실적인 제어 응답 반영 필요
   - 다층 공역 운용 전략 고려

## 코드 구조

```
uam_vertiport_simulation.py
│
├── 데이터 구조 (dataclass)
│   ├── Movement: 단일 이착륙 정보
│   ├── Trajectory: 궤적 데이터
│   ├── WindParams: 바람/난류 파라미터
│   └── SafetyCheck: 안전성 체크 결과
│
├── 1. 교통 생성 로직
│   └── generate_movements(): 이착륙 movements 생성
│
├── 2. 궤적 생성
│   └── generate_nominal_trajectory(): 기준 궤적 생성 (GUAM 연동 준비)
│
├── 3. 바람/난류 모델
│   ├── sample_wind_and_turbulence_params(): 파라미터 샘플링
│   ├── generate_OU_process(): OU process 생성
│   └── apply_disturbances_and_check_TSE(): 외란 적용 및 TSE 체크
│
├── 4. 시뮬레이션 실행
│   ├── run_simulation_for_R_lambda(): 단일 (R, λ) 조합 시뮬레이션
│   └── run_full_simulation(): 전체 조합 시뮬레이션
│
├── 5. 결과 시각화
│   ├── plot_results(): 안전성 확률 히트맵
│   └── plot_tse_distribution(): TSE 분포 플롯
│
└── main(): 메인 실행 함수
```

## 향후 개선 계획

### Phase 1: GUAM 연동
- [ ] GUAM API 인터페이스 구현
- [ ] 실제 eVTOL 동역학 모델 적용
- [ ] GUAM TSE 데이터 직접 활용

### Phase 2: 고급 기능
- [ ] 항공기 간 충돌/근접 위험(NMAC) 분석
- [ ] 다층 공역 운용 (300~450m, 450~600m 분리)
- [ ] Poisson process 기반 교통 생성
- [ ] 실시간 공역 용량 분석

### Phase 3: 최적화
- [ ] 교통 흐름 최적화 알고리즘
- [ ] 동적 공역 관리 전략
- [ ] 기상 조건별 운용 제한 분석

## 참고 문헌

- NASA GUAM (Generic Urban Air Mobility) Simulator
- FAA TSE (Total System Error) Standards
- Urban Air Mobility Concept of Operations

## 라이선스

본 코드는 연구 목적으로 작성되었습니다.

## 작성자

AI Senior Developer (Aviation Traffic Simulation Specialist)

날짜: 2025-12-02
