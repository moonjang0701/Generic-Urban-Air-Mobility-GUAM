# GUAM 논문 vs 현재 실행 환경 비교 분석

## 📄 문서 개요

이 문서는 NASA에서 발표한 GUAM 논문 (SciTech25, "Generic Urban Air Mobility Simulation")에서 제시하는 GUAM 프레임워크의 목적 및 활용 방식과, 우리가 현재 구현한 횡풍 FTE 분석 환경의 차이점을 명확히 설명합니다.

**논문 정보**:
- 제목: Generic Urban Air Mobility Simulation
- 저자: Michael J. Acheson, Andrew Patterson, Irene M. Gregory (NASA Langley Research Center)
- 게재: AIAA SciTech 2025 Forum
- GitHub: https://github.com/nasa/Generic-Urban-Air-Mobility-GUAM

---

## 🎯 1. 목적 및 비전의 차이

### 📖 NASA 논문이 제시하는 GUAM의 목적

GUAM은 **자율 항공기(Autonomous UAM) 연구를 위한 공통 협업 플랫폼**으로 개발되었습니다.

**핵심 목표**:
1. **다양한 연구 분야 간 협업 촉진**
   - 제어 공학, 인지 시스템, 경로 계획, 장애물 회피, 고장 관리 등
   - 산업계, 학계, 정부 연구소 간 협력 기반 조성
   
2. **자율비행 알고리즘 성능 비교**
   - 동일한 시뮬레이션 환경과 데이터셋 사용
   - 논문 발표 및 인용을 통한 자율적 성능 평가
   
3. **UAM 자율성 연구의 장벽 극복**
   - 인지 능력 (상황 인식, 장애물 감지)
   - 실시간 궤적 재계획
   - 돌발 상황(고장, 장애물, 기상) 대응
   - 인간-기계 협업

**인용 원문**:
> "Our research team has developed a high-fidelity, open-source, six degree of freedom, rigid-body, non-linear transition vehicle framework known as the generic urban air mobility (GUAM) simulation... designed from its conception to provide a complete aerospace-focused architecture... that would obviate the need for users to spend valuable resources on the creation and development of a simulation."

### 🔧 우리의 현재 실행 환경의 목적

우리는 **비행 제어 성능 검증**을 위한 특정 분석을 수행했습니다.

**핵심 목표**:
1. **횡풍 조건에서의 경로 추적 정밀도 평가**
   - Flight Technical Error (FTE) 분석
   - 90노트 지상 속도, 20노트 횡풍 조건
   - 1km 직선 구간에서의 측방향 오차 측정

2. **GUAM Baseline 컨트롤러 성능 확인**
   - LQRi (Linear Quadratic Regulator with Integrator) 제어기
   - 횡풍 보정 능력 검증
   - 통계적 지표: 최대 오차, RMS, 95th percentile

3. **학술 연구 및 제어 시스템 이해**
   - 6-DOF 물리 시뮬레이션 검증
   - 실제 항공기 제어 문제 학습

---

## 📊 2. 데이터셋 및 시나리오의 차이

### 📖 NASA 논문: Challenge Problems 프레임워크

GUAM은 **4개의 대규모 데이터셋**을 제공하며, 각각 **3,000개의 시나리오**를 포함합니다.

#### **Dataset 1: Own-Ship Trajectories (자기 항공기 궤적)**
- **내용**: 3,000개의 완전한 비행 경로
  - 호버 이륙 → 터미널 구역 출발 → 상승-순항-하강 → 터미널 구역 도착
  - 랜덤한 속도, 고도, 상승률 분포
  
- **형식**: Bernstein 다항식 (3차)
  - 각 웨이포인트: 위치(x,y,z), 속도, 가속도, 시간
  - 동역학적으로 실현 가능한 궤적 (최대 뱅크각 30°, 연속적 가속도)

- **특징**:
  - `own_traj_orig`: 기본 비행 계획 (가속도=0)
  - `own_traj`: 동역학적 실현 가능 궤적 (조기 선회, 부드러운 롤 전환 포함)

**인용 원문**:
> "Data set one contains two sets of 3000 own-ship trajectories... The first... is a basic flight plan consisting of a series of waypoints... The second set... contains modified dynamically feasible trajectories..."

#### **Dataset 2: Stationary Obstacles (정지 장애물)**
- **내용**: 3,000개의 무작위 배치 정지 장애물
  - 각 장애물은 대응하는 own-ship 궤적과 충돌 위험 보장
  - 구형 장애물 (랜덤한 위치, 크기, 충돌 시간)

- **데이터 구조**:
  - 장애물 중심 위치 (3D 벡터)
  - 반지름, 최소 수직 거리, 위험 시간
  - 대응하는 궤적 번호

**시각화 예시**: 논문 Figure 4 - 궤적 #1과 #5의 무작위 장애물

#### **Dataset 3: Moving Obstacles (이동 장애물)**
- **내용**: 3,000개의 이동 장애물 궤적
  - 선형 궤적 (랜덤 속도, 북쪽/동쪽/수직 성분)
  - 위험 시간에 정확한 충돌 위치 도달 보장

- **형식**: Bernstein 다항식으로 저장된 장애물 궤적

**인용 원문**:
> "The moving obstacle data... was produced by the script Generate_Mov_Obs.m. The obstacle itself is randomly created... an additional linear trajectory for the obstacle is created that ensures the obstacle reaches the correct position at the prescribed hazard time."

#### **Dataset 4: Effector Failures (조종면/추력 고장)**
- **내용**: 3,000개의 무작위 조종면/프로펠러 고장 시나리오
  - 고장 유형: Hold Last (고착), Scaling (출력 감소), Control Reversal (역전)
  - 무작위 고장 시작 시간 및 지속 시간 (최대 100초)

- **고장 적용 대상**:
  - NASA Lift+Cruise: 8개 리프트 로터(n1-n8), 1개 푸셔 프로펠러(n9), 좌우 에일러론, 좌우 엘리베이터, 러더

**NASA 항공기 조종면 번호 체계**: 논문 Figure 6

### 🔧 우리의 현재 환경: 단일 맞춤형 시나리오

**시나리오 규모**: **1개의 수동 생성 궤적**

- **궤적 정의**:
  ```matlab
  % 1km 직선 구간
  N_start = 0;        % 시작: 북쪽 0m
  N_end   = 1000;     % 종료: 북쪽 1000m
  E_coord = 0;        % 동쪽: 0m (일정)
  Alt     = -304.8;   % 고도: 1000ft (Down=-304.8m)
  ```

- **환경 조건**:
  - 90노트 지상 속도 (46.3 m/s)
  - 20노트 횡풍 (10.3 m/s, 동쪽에서 서쪽으로)
  - 약 21.6초 비행 시간

- **데이터 생성 방식**:
  - `timeseries` 객체로 수동 정의
  - 3개 웨이포인트: 시작, 중간, 종료
  - Bernstein 다항식 아님 (선형 보간)

**장애물**: 없음  
**고장 시나리오**: 없음  
**데이터셋 파일**: 사용하지 않음 (`Data_Set_1.mat` ~ `Data_Set_4.mat` 미사용)

---

## 🧠 3. 자율성(Autonomy) 연구 깊이의 차이

### 📖 NASA 논문: 지능형 돌발상황 관리 (ICM)

GUAM 논문은 **인간 조종사의 "Aviate - Navigate - Communicate" 원칙**을 자율 시스템으로 변환하는 것을 목표로 합니다.

#### **Aviate (비행 제어)**
- Robust & Adaptive Control (강건 적응 제어)
- Safety Certificates & Learning Control (안전 보증 학습)
- Fault Identification (고장 식별)
- Flight Envelope Estimation (비행 포락선 추정)

#### **Navigate (항법)**
- Collision Avoidance (충돌 회피)
- Pattern Entry (비통제 공항 교통 패턴 진입)
- Perception & Environment (인지 및 환경 인식)
- Long/Short/Contingency Planners (장기/단기/비상 경로 계획)
- Real-time Trajectory Replanning (실시간 궤적 재계획)

#### **Communicate (통신)**
- Algorithm-to-Algorithm Communication (비동기, 다중 시간 척도)
- Aircraft-to-Aircraft Systems
- External Aircraft (Datalink, Voice)
- System of System Communications

**인용 원문** (논문 Figure 1):
> "Autonomous Intelligent Contingency Management: Robust & Adaptive Control, Fault Identification & Flight Envelope Estimation, Collision Avoidance & Pattern Entry, Perception & Environment, Planners (Long, Short, Contingency Spectrum)..."

#### **Challenge Problem 복잡도 조합**

연구자들은 데이터셋을 **조합**하여 난이도를 점진적으로 높일 수 있습니다:

1. **기본**: 3,000개 궤적 추적만
2. **+바람**: 난기류 추가
3. **+모델 불확실성**: 설계 모델과 비행 모델을 다르게 설정
4. **+정지 장애물**: Dataset 2 추가
5. **+이동 장애물**: Dataset 3 추가
6. **+조종면 고장**: Dataset 4 추가

**논문의 실험 예시** (Section IV):
- Figure 7: 5개 궤적의 4D RMS 추적 오차, 시간 제약 완화 효과
- Figure 8: Bernstein 다항식 기반 충돌 회피 (좌회피 vs 우회피 비교)

### 🔧 우리의 현재 환경: 제어 성능 검증

**자율성 수준**: **Level 1 - 기본 경로 추적**

우리는 **가장 기본적인 자율 비행 작업**인 "주어진 경로를 정확히 따라가기"만 수행합니다.

- **제어기**: NASA Baseline LQRi (GUAM 기본 제공)
- **입력**: 수동 정의 직선 궤적 + 일정한 횡풍
- **출력**: 측방향 FTE (Lateral Error)
- **통계**: 최대 오차, RMS, 95th percentile

**구현한 기능**:
- ✅ 6-DOF 물리 시뮬레이션
- ✅ 횡풍 주입 (`SimInput.Environment.Winds`)
- ✅ 경로 추적 오차 계산 (NED 좌표계)
- ✅ 통계적 성능 지표

**구현하지 않은 기능**:
- ❌ 장애물 감지 및 회피
- ❌ 실시간 궤적 재계획
- ❌ 고장 시나리오 대응
- ❌ 인지 시스템 (Perception)
- ❌ 의사결정 알고리즘 (Cognitive Architecture)
- ❌ 시각화 (UnrealEngine, AirSim)
- ❌ Challenge Problems 데이터셋 활용

---

## 🛠️ 4. 기술 스택의 차이

### 📖 NASA 논문: GUAM v1.1 및 v2.0

#### **GUAM v1.1 (현재 오픈소스 버전, 우리가 사용 중)**
- Matlab® / Simulink® 기반
- C/C++ 자동 코드 생성 가능
- 6-DOF 강체 비선형 동역학
- 두 가지 공기역학 모델:
  - Polynomial aero-propulsive model (다항식 모델, CFD 기반)
  - Strip theory model (스트립 이론 모델)
- RSLQR (Robust Servomechanism LQR) 통합 제어기
- US Standard Atmosphere 1976
- Challenge Problems 데이터셋 포함

#### **GUAM v2.0 (출시 대기 중, NASA 승인 심사 중)**
- **고품질 시각화**: Unreal Engine v5 통합
- **인지 아키텍처**: 기본 의사결정 시스템 포함
- **Python® 지원**: 외부 알고리즘 통합
- **ROS2 인터페이스**: Matlab® 툴박스 불필요 (S-Function 사용)
- **향후 Challenge Problems**:
  - 비통제 공항 교통 패턴 진입
  - 장애물 충돌 회피 (고품질 시각화)

**인용 원문**:
> "GUAM v2.0 is pending NASA software release approval. This updated simulation will support high-fidelity visualization, provide a basic cognitive architecture, provide simplified ROS2 interface... and support external Python® algorithms."

### 🔧 우리의 현재 환경: GUAM v1.1 기본 기능만 사용

- **버전**: GUAM v1.1 (GitHub 오픈소스)
- **사용 컴포넌트**:
  - 6-DOF 시뮬레이션 엔진
  - Baseline LQRi 제어기 (`CtrlEnum.BASELINE = 2`)
  - Timeseries 궤적 입력 (`RefInputEnum.TIMESERIES = 3`)
  - STARS 라이브러리 (쿼터니언 함수: `QrotZ`, `Qtrans`)
  - 바람 주입 기능

- **사용하지 않는 컴포넌트**:
  - Challenge Problems 폴더
  - Dataset 생성 스크립트 (`Generate_Own_Traj.m` 등)
  - RSLQR 제어기 (논문에서 사용)
  - Strip theory 모델 (기본 polynomial 모델 사용)
  - 장애물 회피 알고리즘
  - 고장 시뮬레이션 기능
  - 시각화 툴

---

## 📈 5. 성능 메트릭의 차이

### 📖 NASA 논문: 다층적 성능 메트릭

논문은 **자율 알고리즘 비교를 위한 정량적 메트릭**을 제안합니다.

#### **궤적 추적 성능** (Figure 7)
1. **4D RMS Error**: 위치 + 시간 오차 (||pos_Baseline - pos_Simulated||₂)
2. **3D RMS Error**: 위치만 오차 (시간 ±2초 범위 내 최소 오차)
3. **Phase-specific Metrics**: 비행 단계별 가중치 (정밀 착륙 vs 순항)

**효과 분석**:
- 시간 제약 제거 시 RMS 오차 10-25ft 감소 (Figure 7d)
- 비행 단계별 오차 변화 추적 (이륙, 선회, 하강)

#### **충돌 회피 성능** (Figure 8)
1. **최소 분리 거리**: 안전 거리 유지 여부
2. **회피 기동 적극성**: 원래 궤적과의 Euclidean 거리
   - 좌회피 vs 우회피 비교
   - "더 쉬운" 회피 궤적 선택 기준
3. **속도 프로파일 부드러움**: 가속도 연속성 (Figure 8c)

#### **통계적 비교**
- 평균 4D RMS 오차 및 표준편차
- 개별 비행 간 비교
- 전체 비행 세트 간 비교 (연구자 간 성능 비교 가능)

**인용 원문**:
> "The goals of creating and defining performance metrics for autonomy are three fold. First they should measure what is important during a particular phase of flight... Second... enable a quantitative means of comparing performance between controllers, algorithms... Lastly performance metrics are likely to be used in real-time or near real-time by autonomy algorithms as an aid in cognitive decision processing."

### 🔧 우리의 현재 환경: FTE 기본 통계

**메트릭 범위**: **측방향 오차(Lateral FTE)만 분석**

- **측정 항목**:
  - 최대 오차 (Max Lateral Error)
  - RMS 오차 (Root Mean Square)
  - 95th percentile 오차
  - 오차 시계열 플롯

- **계산 방법**:
  ```matlab
  % 트랙 정렬 좌표계 변환
  vel_track_N = cos(chi);
  vel_track_E = sin(chi);
  
  % 수직 벡터 (측방향)
  perp_N = -sin(chi);
  perp_E =  cos(chi);
  
  % 측방향 오차
  lateral_error = (pos_N_actual - pos_N_des) * perp_N + ...
                  (pos_E_actual - pos_E_des) * perp_E;
  ```

- **결과 예시** (우리의 시뮬레이션):
  - 최대 오차: ~2-3m
  - RMS 오차: ~1.5m
  - 95th percentile: ~2.5m

**구현하지 않은 메트릭**:
- ❌ 4D RMS (시간 포함)
- ❌ 비행 단계별 가중치
- ❌ 종방향 오차 (Along-track Error)
- ❌ 회피 기동 평가
- ❌ 다중 시나리오 통계 (우리는 1개만 실행)

---

## 🎓 6. 연구 커뮤니티 협업 관점의 차이

### 📖 NASA 논문: 오픈 협업 생태계

GUAM의 **핵심 철학**은 **다양한 연구 그룹 간 협업**입니다.

#### **협업 촉진 메커니즘**
1. **공통 프레임워크**: 모든 연구자가 동일한 시뮬레이션 사용
2. **공개 데이터셋**: 3,000 시나리오 × 4 데이터셋 제공
3. **성능 비교 가능성**: 동일한 메트릭으로 알고리즘 비교
4. **GitHub 기반 공유**: Forks, Issues, Pull Requests
5. **논문 인용 기반 평가**: 자율적 성능 랭킹 (대회 심사 없음)

**인용 원문**:
> "It was recognized by our research team that the diverse array of research fields, coupled with the limited budgets, staffs, and expertise, necessitate collaboration and cooperation between research groups if the goal of full autonomous transition vehicle operations is to be achieved."

#### **산학연 협력 장벽 극복**
- **산업계**: 실제 비행체 접근성, IP 문제 해결 필요
- **학계**: 대규모 인력(대학원생), TRL 개발 부족
- **정부**: 기초 연구 및 장기 개발, 예산 지원

**GUAM의 해결책**:
- 오픈소스 (IP 문제 없음)
- 고품질 eVTOL 모델 (학계의 대형 플랫폼 접근성 제공)
- Challenge Problems (TRL 검증 도구)

#### **NASA TTT-RAM 커뮤니티 사이트**
- URL: https://nari.arc.nasa.gov/ttt-ram/community
- 자율 비행 Challenge Problems 공식 허브
- 연구자 간 협업 및 비교 플랫폼

### 🔧 우리의 현재 환경: 독립적 학습/분석

**목적**: **개인 학습 및 제어 시스템 이해**

- **협업 요소**: 없음
- **데이터 공유**: 없음 (맞춤형 1개 시나리오)
- **성능 비교**: 없음 (단일 실험)
- **커뮤니티 참여**: 없음

**학습 성과**:
- ✅ GUAM 시뮬레이션 구조 이해
- ✅ 6-DOF 비행 역학 검증
- ✅ Timeseries 궤적 입력 방법 습득
- ✅ FTE 분석 기법 확립
- ✅ LQRi 제어기 성능 확인

---

## 📋 7. 핵심 차이점 요약표

| **비교 항목** | **NASA 논문 (GUAM 비전)** | **우리의 현재 환경** |
|-------------|------------------------|------------------|
| **목적** | 자율비행 알고리즘 개발 및 비교 플랫폼 | 횡풍 조건 경로 추적 정밀도 분석 |
| **시나리오 규모** | 3,000개 × 4 데이터셋 (총 12,000개) | 1개 맞춤형 시나리오 |
| **궤적 형식** | Bernstein 다항식 (동역학적 실현 가능) | Timeseries (선형 보간) |
| **장애물** | 정지 3,000개 + 이동 3,000개 | 없음 |
| **고장 시나리오** | 3,000개 조종면/추력 고장 | 없음 |
| **자율성 수준** | Level 5 (ICM 전체 스펙트럼) | Level 1 (경로 추적만) |
| **제어기** | RSLQR (논문 실험) | Baseline LQRi (우리 실험) |
| **성능 메트릭** | 4D RMS, 3D RMS, 회피 기동 평가 | 측방향 FTE (max, RMS, 95th) |
| **시각화** | UnrealEngine (v2.0 예정) | 없음 (Matlab 플롯만) |
| **인지 시스템** | Cognitive Architecture (v2.0) | 없음 |
| **협업 목적** | 다중 연구 그룹 성능 비교 | 개인 학습/분석 |
| **사용 데이터셋** | `Challenge_Problems/*.mat` | 없음 |
| **Python/ROS2** | v2.0에서 지원 | 사용 안함 |
| **연구 범위** | Aviate + Navigate + Communicate | Aviate (경로 추적만) |

---

## 🚀 8. 우리 환경을 Challenge Problems로 확장하는 방법

현재 우리의 환경을 NASA가 제시한 Challenge Problems 수준으로 확장하려면 다음 단계를 따르면 됩니다.

### **Step 1: Challenge Problems 데이터 로드**

```matlab
% GUAM Challenge_Problems 폴더 경로
cd Challenge_Problems

% Dataset 1 로드 (3000 궤적)
load('Data_Set_1.mat');  % own_traj_orig, own_traj

% 특정 궤적 선택 (예: 10번째)
traj_idx = 10;
selected_traj = own_traj{traj_idx};

% Bernstein 다항식 구조 확인
% selected_traj.t    : 시간
% selected_traj.p    : 위치 [N; E; D]
% selected_traj.v    : 속도
% selected_traj.a    : 가속도
```

### **Step 2: 정지 장애물 추가**

```matlab
% Dataset 2 로드 (정지 장애물)
load('Data_Set_2.mat');  % stat_obs

% 10번째 궤적에 해당하는 장애물
obstacle = stat_obs{traj_idx};

% 장애물 정보
obs_center = obstacle.center;  % [N; E; D]
obs_radius = obstacle.radius;  % 반지름 (m)
hazard_time = obstacle.t_hazard;  % 위험 시간 (초)
```

### **Step 3: 이동 장애물 추가**

```matlab
% Dataset 3 로드 (이동 장애물)
load('Data_Set_3.mat');  % mov_obs

% 10번째 궤적에 해당하는 이동 장애물
moving_obstacle = mov_obs{traj_idx};

% 이동 장애물 궤적
obs_traj_t = moving_obstacle.traj.t;
obs_traj_p = moving_obstacle.traj.p;  % [N(t); E(t); D(t)]
```

### **Step 4: 조종면 고장 추가**

```matlab
% Dataset 4 로드 (고장 시나리오)
load('Data_Set_4.mat');  % failures

% 10번째 궤적에 해당하는 고장
failure_scenario = failures{traj_idx};

% 고장 정보
failure_type = failure_scenario.type;  % 'hold_last', 'scale', 'reversal'
failure_effector = failure_scenario.effector_num;  % 1~13 (Figure 6 참조)
failure_start = failure_scenario.t_start;  % 고장 시작 시간 (초)
failure_duration = failure_scenario.duration;  % 지속 시간 (초)

% GUAM 시뮬레이션에 적용
SimInput.Failures.Type = failure_type;
SimInput.Failures.Effector = failure_effector;
SimInput.Failures.Start = failure_start;
SimInput.Failures.Duration = failure_duration;
```

### **Step 5: 복잡도 점진적 증가**

#### **난이도 1: 궤적 추적만**
```matlab
% Challenge Problems 궤적만 사용
RefInput = convertBernsteinToTimeseries(selected_traj);
```

#### **난이도 2: 궤적 + 바람**
```matlab
% 난기류 추가
SimInput.Environment.Winds.Enable = 1;
SimInput.Environment.Winds.Turbulence = 'moderate';
```

#### **난이도 3: 궤적 + 바람 + 정지 장애물**
```matlab
% 충돌 회피 알고리즘 구현 필요
% 예: ORCA (Optimal Reciprocal Collision Avoidance, 논문 Figure 8)
```

#### **난이도 4: 궤적 + 바람 + 이동 장애물**
```matlab
% 실시간 회피 기동
% 논문 참조: Bernstein Polynomial ORCA [11]
```

#### **난이도 5: 궤적 + 바람 + 장애물 + 고장**
```matlab
% 지능형 돌발상황 관리 (ICM)
% Fault Identification + Replanning
```

### **Step 6: 성능 비교 (다중 시나리오)**

```matlab
% 3000개 궤적 모두 실행
results = cell(3000, 1);

for i = 1:3000
    traj = own_traj{i};
    % 시뮬레이션 실행
    results{i} = runGUAM(traj);
end

% 통계 분석
all_rms = cellfun(@(x) x.rms_error, results);
mean_rms = mean(all_rms);
std_rms = std(all_rms);

% 논문 Figure 7과 같은 플롯 생성
figure;
plot(1:3000, all_rms, 'b.');
xlabel('Trajectory Number');
ylabel('RMS Error (m)');
title('Tracking Performance Across 3000 Scenarios');
```

---

## 🔍 9. 주요 인사이트

### **1. GUAM은 "툴킷"이지 "단일 실험"이 아니다**

- 우리는 GUAM을 **단일 분석 도구**로 사용했습니다.
- NASA는 GUAM을 **연구 플랫폼**으로 설계했습니다.
  - 다양한 알고리즘을 "드롭인" 방식으로 테스트
  - 공통 메트릭으로 성능 비교
  - GitHub을 통한 협업 및 공유

### **2. 우리의 작은 FTE 값은 "문제"가 아니라 "성공"**

- **우리의 결과**: 측방향 오차 1-3m (20kt 횡풍)
- **해석**: NASA Baseline LQRi 제어기가 매우 우수함을 검증
- **논문의 실험**: 4D RMS 오차 20-80ft (6-24m) 범위 (Figure 7b)
  - 우리의 결과가 더 작은 이유: 단순 직선 vs 논문의 복잡한 상승-선회-하강

### **3. Challenge Problems는 "경쟁"이 아니라 "협업"**

- 전통적 AI 챌린지와 다름:
  - ❌ 리더보드 없음
  - ❌ 공식 심사 없음
  - ✅ 자율적 인용 기반 평가
  - ✅ GitHub 포크 및 협업
  - ✅ 컨퍼런스/저널 발표 중심

### **4. GUAM v2.0가 해결할 부분**

- **현재 v1.1의 한계** (논문 Section V):
  - 시각화 부족 → Perception 연구 어려움
  - 인지 시스템 없음 → 의사결정 알고리즘 테스트 불가
  
- **v2.0의 개선** (출시 대기 중):
  - Unreal Engine 5: 고품질 센서 시뮬레이션
  - Cognitive Architecture: 의사결정 프레임워크
  - Python/ROS2: 머신러닝 커뮤니티 접근성

---

## 📚 10. 추천 다음 단계

### **학습 목적이라면**

1. **Challenge Problems 탐색**
   ```bash
   cd /path/to/GUAM/Challenge_Problems
   matlab -r Generate_Own_Traj  # 데이터 생성 과정 이해
   ```

2. **논문 실험 재현**
   - Figure 7: 궤적 1-5 추적 성능 비교
   - Figure 8: 충돌 회피 (좌 vs 우)

3. **제어기 비교**
   - Baseline LQRi (우리가 사용)
   - RSLQR (논문에서 사용)
   - 성능 차이 정량화

### **연구 목적이라면**

1. **자신의 알고리즘 통합**
   - 경로 계획기 (Path Planner)
   - 충돌 회피 (Collision Avoidance)
   - 고장 대응 (Fault Management)

2. **성능 벤치마킹**
   - 3,000 시나리오로 테스트
   - 논문 메트릭으로 비교
   - 결과를 GitHub에 공유

3. **NASA TTT-RAM 커뮤니티 참여**
   - https://nari.arc.nasa.gov/ttt-ram/community
   - 다른 연구 그룹과 협업
   - 논문 발표 및 인용

---

## 📖 참고문헌

### **NASA GUAM 논문**
```
Acheson, M. J., Patterson, A., Gregory, I. M., "Generic Urban Air Mobility 
Simulation," AIAA SciTech 2025 Forum.
```

### **GUAM GitHub**
```
https://github.com/nasa/Generic-Urban-Air-Mobility-GUAM
```

### **NASA TTT-RAM 사이트**
```
https://nari.arc.nasa.gov/ttt-ram/community
```

### **관련 논문 (논문 Reference [11])**
```
Houghton, M. D., et al., "Combined Bernstein Polynomial Collision Avoidance 
Differential Dynamic Programming for Trajectory Replanning and Collision 
Avoidance for UAM Vehicles," AIAA SciTech 2023 Forum, 2023.
```

---

## ✅ 결론

### **우리는 GUAM을 올바르게 사용했는가?**

**Yes!** 우리는 GUAM의 **기본 기능 (경로 추적)**을 성공적으로 검증했습니다.

- ✅ 6-DOF 물리 시뮬레이션 작동
- ✅ 횡풍 환경 구현
- ✅ FTE 분석 방법론 확립
- ✅ 제어기 성능 확인

### **NASA가 원하는 GUAM 활용은?**

NASA는 GUAM을 **자율 비행 연구의 공통 플랫폼**으로 사용하길 원합니다.

- 📊 3,000+ 시나리오로 알고리즘 테스트
- 🤝 다른 연구자와 성능 비교
- 🚁 장애물 회피, 고장 대응 등 고급 기능
- 🌐 오픈소스 협업 생태계 참여

### **우리의 다음 선택은?**

1. **현재 수준 유지**: 학습 목적으로 충분
   - FTE 분석 깊이 확장 (종방향 오차, 다른 바람 조건)
   - 다른 제어기 비교 (RSLQR)
   
2. **Challenge Problems 활용**: 연구 수준으로 확장
   - Dataset 1-4 탐색
   - 장애물 회피 구현
   - 3,000 시나리오 통계 분석

3. **GUAM v2.0 대기**: 최신 기능 활용
   - UnrealEngine 시각화
   - Python 알고리즘 통합
   - NASA 공식 Challenge Problems 참여

---

**문서 작성일**: 2025-11-18  
**GUAM 버전**: v1.1  
**분석 대상 논문**: "Generic Urban Air Mobility Simulation" (SciTech 2025)  
**우리의 구현**: `exam_Crosswind_FTE_1km.m` (횡풍 FTE 분석)
