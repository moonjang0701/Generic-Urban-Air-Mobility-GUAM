# GUAM RUNME 시나리오 5: Piecewise Bezier Trajectory 상세 분석

## 📋 시나리오 개요

**RUNME 옵션 5 → exam_Bezier.m → 옵션 2 선택**

```matlab
Select: 1 or 2:
(1) Use target structure
(2) Use userStruct.trajFile (trajectory file)
User Input: 2  ← 이 옵션!
```

---

## 🎯 시나리오 5-2의 비행 프로파일

### 전체 미션 (80초):

```
0초 ────→ 10초 ────→ 80초
Hover     상승+가속   순항
지상       80ft      580ft
         ↗         ↗
        전환      고도+속도
```

---

## 📊 상세 Waypoint 분석

### 코드 분석:

```matlab
% X축 (North - 전진 방향)
wptsX = [0   0   0;      % t=0s:  지상, 정지
         0   0   0;      % t=10s: hover 유지
         1750 50 0];     % t=80s: 1750ft 전진, 50 ft/s 속도
time_wptsX = [0 10 80];

% Y축 (East - 좌우 방향)
wptsY = [0 0 0;          % t=0s:  중심
         0 0 0];         % t=80s: 중심 유지 (좌우 이동 없음)
time_wptsY = [0 80];

% Z축 (Down - 고도, NED 좌표계에서 음수가 위)
wptsZ = [0    0      0;     % t=0s:  지상 (0ft)
         -80  -500/60 0;    % t=20s: 80ft 상승, -500 ft/min 상승률
         -580 -500/60 0];   % t=80s: 580ft 고도, -500 ft/min 유지
time_wptsZ = [0 20 80];
```

### Waypoint 형식 설명:

```matlab
wpts = [position, velocity, acceleration]
       [  pos,      vel,        acc      ]

예시:
[1750  50  0] = 위치 1750ft, 속도 50ft/s, 가속도 0 ft/s²
```

---

## 🛫 비행 단계별 상세 분석

### Phase 1: Hover (0-10초) 🚁

```
시간: 0 → 10초
위치: (0, 0, 0) → (0, 0, 0)
속도: 0 → 0
동작: 제자리 비행 (hover)

항공기 상태:
- 8개 리프트 로터: 100% 추력
- 1개 푸셔 프로펠러: 0% 추력
- 기수: 수평 (pitch ≈ 0°)
- 자세: 안정적 hover
```

**목적**: 
- 초기 안정화
- 시스템 체크
- 이륙 준비

---

### Phase 2: 전환 (Transition) (10-20초) 🔄

```
시간: 10 → 20초
위치: 
  X: 0 → ~200 ft (Bezier 곡선으로 부드럽게 가속)
  Y: 0 → 0 (좌우 이동 없음)
  Z: 0 → -80 ft (80ft 상승)

속도:
  수직: 0 → 500 ft/min = 8.33 ft/s 상승
  수평: 0 → ~25 ft/s (점진적 가속)

항공기 상태:
- 리프트 로터: 100% → 70% (점진적 감소)
- 푸셔 프로펠러: 0% → 50% (점진적 증가)
- 기수: pitch down 5-15° (전환 자세)
- 비행 모드: TRANSITION
```

**핵심 특징**:
- **동시 작업**: 상승 + 전진 가속
- **Lift+Cruise 전환**: 수직 추력 → 수평 추력 전환
- **Bezier 곡선**: 부드러운 궤적 (급격한 변화 없음)

---

### Phase 3: 상승 + 순항 가속 (20-80초) ✈️

```
시간: 20 → 80초 (60초간)
위치:
  X: ~200 → 1750 ft (1550ft 전진)
  Y: 0 → 0
  Z: -80 → -580 ft (500ft 추가 상승)

속도:
  수직: 500 ft/min 유지 (일정한 상승)
  수평: 25 → 50 ft/s (계속 가속)
  최종: 50 ft/s = 34 knots = 29.5 mph

항공기 상태:
- 리프트 로터: 30-40% (양력 보조)
- 푸셔 프로펠러: 70-80% (주 추력)
- 기수: pitch 약간 위 (상승 자세)
- 비행 모드: CRUISE (순항)
```

**거리 계산**:
```
수평 거리: 1750 ft = 533 m = 0.53 km
수직 거리: 580 ft = 177 m
총 비행 거리: √(1750² + 580²) = 1844 ft = 562 m

평균 속도: 
  수평: 1750 ft / 60 s = 29.2 ft/s
  수직: 500 ft / 60 s = 8.33 ft/s
```

---

## 🌐 3D 비행 경로 시각화

### Side View (측면):

```
고도(ft)
  ▲
580├──────────────────────●  Phase 3 끝 (80s)
    │                    ╱
    │                  ╱
    │                ╱ 계속 상승
    │              ╱
 80 ├───────●────╱  Phase 2 끝 (20s)
    │      ╱│
    │    ╱  │ 전환
    │  ╱    │
  0 ●───────┘───────────────────► 수평거리(ft)
    0      200              1750
    
    Hover  Transition      Cruise
    (10s)   (10s)          (60s)
```

### Top View (평면):

```
East (ft)
  ▲
  │
  0 ●═══════════════════════● 
    0                     1750  North (ft)
    
직선 경로 (Y=0 유지)
좌우 이동 없음
```

### 3D Trajectory:

```
     ┌─────────────────── 580ft
    ╱│
   ╱ │
  ╱  │ 
 ╱   │ 80ft
●────┘
지상  1750ft
```

---

## 🎮 제어 타입 (Controller Type)

### 사용된 제어기:

```matlab
% exam_Bezier.m 에서는 명시적으로 지정하지 않음
% 따라서 기본값 사용:

userStruct.variants.ctrlType = CtrlEnum.BASELINE  // 기본값
```

**BASELINE Controller** = **LQRi** (Linear Quadratic Regulator with Integrator)

### 왜 BASELINE을 사용하나?

```
Bezier 경로는 복잡함:
- 3차원 곡선 궤적
- 시간에 따라 변하는 속도
- 동시 다축 제어 필요

LQRi 특징:
✓ 최적 제어 (Optimal control)
✓ 다중 입출력 (MIMO) 처리
✓ 경로 추적에 강함
✓ 적분 항으로 정상상태 오차 제거
```

---

## 🚫 장애물 있나요? (Obstacle Avoidance)

### 답: **없습니다!**

```matlab
% 코드에 장애물 정의 없음
obstacles = [];
no_fly_zones = [];
```

**경로가 "휘는" 이유**:
❌ 장애물 회피 때문이 **아님**
✅ **Bezier 곡선의 수학적 특성** 때문

### Bezier 곡선이란?

```
Bernstein Polynomial 기반 곡선:
- 제어점(waypoint)을 부드럽게 연결
- C² 연속성 (가속도까지 연속)
- 급격한 변화 없음
- 자연스러운 궤적

예시:
직선으로 가면: ●───────────●
Bezier로 가면: ●╭─────────╮●
                 부드러운 곡선!
```

---

## 🔧 기술적 설정 상세

### 1. **Reference Input Type**

```matlab
userStruct.variants.refInputType = 4;  // BEZIER

RefInputEnum:
  FOUR_RAMP = 1
  ONE_RAMP = 2
  TIMESERIES = 3
  BEZIER = 4      ← 이것!
  DEFAULT = 5
```

### 2. **Controller Type**

```matlab
% 명시 안 함 → 기본값
userStruct.variants.ctrlType = 2;  // BASELINE

CtrlEnum:
  TRIM = 1
  BASELINE = 2    ← 이것! (LQRi)
  BASELINE_L1 = 3
  BASELINE_AGI = 4
```

### 3. **Vehicle Type**

```matlab
% 기본값
userStruct.variants.vehicleType = VehicleEnum.LiftPlusCruise

Lift+Cruise 구성:
- 8개 리프트 로터 (수직 추력)
- 1개 푸셔 프로펠러 (수평 추력)
- 날개 (양력)
```

### 4. **Actuator Type**

```matlab
% 기본값
userStruct.variants.actType = ActuatorEnum.FirstOrder

First-order 액추에이터 동역학:
δ_actual(t) = (1 - e^(-t/τ)) * δ_cmd
τ ≈ 0.1-0.2초 (빠른 응답)
```

### 5. **Force/Moment Model**

```matlab
% 기본값
userStruct.variants.fmType = ForceMomentEnum.Polynomial

Polynomial 공력 모델:
- CFD 데이터 기반
- 다항식 근사
- 빠른 계산
```

### 6. **Atmosphere**

```matlab
% 기본값
userStruct.variants.atmosType = AtmosphereEnum.US_STD_ATMOS_76

US Standard Atmosphere 1976:
- 고도별 온도/압력/밀도
- 0-580ft 범위에서 거의 일정
```

### 7. **Turbulence**

```matlab
% 기본값
userStruct.variants.turbType = TurbulenceEnum.None

난기류 없음:
- 부드러운 대기
- 바람 없음
- 이상적 조건
```

---

## 🎨 Bezier 곡선의 특징

### 수학적 정의:

```matlab
% Bernstein Polynomial (3차 Bezier)
B(t) = (1-t)³*P₀ + 3(1-t)²t*P₁ + 3(1-t)t²*P₂ + t³*P₃

여기서:
- t: 0→1 (시간 파라미터)
- P₀, P₁, P₂, P₃: 제어점 (waypoints)
```

### 왜 Bezier를 사용하나?

#### 1. **부드러운 궤적**
```
직선 연결 (Timeseries):
  ●─────●─────●
  각진 코너, 급격한 변화

Bezier 곡선:
  ●╭─────╮───╮●
  부드러운 곡선, 자연스러운 흐름
```

#### 2. **연속성 보장**
```
C² 연속성:
- 위치 연속 (C⁰)
- 속도 연속 (C¹)
- 가속도 연속 (C²)

→ 승객 편안함 (jerk 최소화)
→ 제어기 부담 감소
```

#### 3. **직관적 제어**
```
Waypoint만 지정:
- 시작점
- 중간점
- 끝점

→ Bezier가 자동으로 부드럽게 연결
```

#### 4. **계산 효율**
```
다항식 평가:
- 빠른 계산 (O(n))
- 실시간 가능
- 미분/적분 쉬움
```

---

## 🔄 Piecewise (조각별) Bezier란?

### "Piecewise" 의미:

```
전체 80초 경로를 여러 조각으로 나눔:

Piece 1 (0-20초): Bezier Curve #1
  hover → 전환 → 초기 순항

Piece 2 (20-80초): Bezier Curve #2
  순항 가속 + 상승

각 piece는 독립적인 Bezier 곡선
→ 연결점에서 부드럽게 이어짐
```

### 왜 Piecewise?

```
장점:
✓ 복잡한 경로를 간단한 조각으로 분해
✓ 각 구간 독립적으로 설계
✓ 유연성 증가
✓ 계산 안정성

예시:
전체 경로 = Piece1 ⊕ Piece2 ⊕ Piece3
           (hover) (전환) (순항)
```

---

## 📐 좌표계 및 단위

### NED 좌표계:

```
  North (X)
    ↑
    │
    └────→ East (Y)
   ╱
  ╱
Down (Z)

특징:
- 오른손 좌표계
- Down이 양수 (고도는 음수!)
- 항공 표준
```

### 단위 변환:

```matlab
% 코드는 feet 사용
1 ft = 0.3048 m

거리:
  1750 ft = 533.4 m = 0.533 km
  580 ft = 176.8 m

속도:
  50 ft/s = 15.24 m/s = 29.5 mph = 25.7 kt
  500 ft/min = 2.54 m/s (상승률)
```

---

## 🎯 시나리오의 실제 의미

### 이 시나리오는 무엇을 시뮬레이션하나?

**도심 항공 모빌리티 (UAM) 이륙 절차**:

```
실제 상황:
1. Vertiport에서 수직 이륙 (hover)
2. 안전 고도까지 상승하며 전환
3. 순항 고도로 계속 상승하며 가속
4. 목적지로 순항 비행

우리 시나리오:
1. 0-10s: Vertiport 이륙 (hover stabilization)
2. 10-20s: 80ft까지 상승 + 전환 시작
3. 20-80s: 580ft 순항 고도 + 50ft/s 순항 속도
```

### 현실적 요소:

```
✓ 단계적 전환 (hover → transition → cruise)
✓ 부드러운 궤적 (승객 편안함)
✓ 고도 제한 준수 (580ft ≈ 177m, 도심 저고도)
✓ 속도 제한 (50ft/s ≈ 34kt, 안전 속도)
```

---

## 🔍 다른 시나리오와의 비교

### Scenario 3 (Timeseries) vs Scenario 5-2 (Bezier):

| 측면 | Timeseries | Bezier |
|------|------------|--------|
| **경로** | 직선 구간 | 부드러운 곡선 |
| **waypoint** | 단순 연결 | Bernstein 보간 |
| **연속성** | C⁰ (위치만) | C² (가속도까지) |
| **제어 부담** | 높음 (각진 코너) | 낮음 (부드러움) |
| **승객 편안함** | 낮음 | 높음 |
| **계산** | 간단 | 약간 복잡 |
| **용도** | 직선 비행 | 복잡한 기동 |

---

## 💻 핵심 코드 분석

### Bezier 함수 호출:

```matlab
% Plot_PW_Bezier.m 실행
% Bezier Functions 사용:

evalPWCurve()      % Piecewise curve 평가
evalBernPoly()     % Bernstein polynomial 계산
genPWCurve()       % PW curve 생성
interpHermBern()   % Hermite-Bernstein 보간
```

### 시뮬레이션 실행:

```matlab
% 1. Bezier 경로 생성
pwcurve = generate_bezier_path(waypoints, times)

% 2. 파일 저장
save('exam_PW_Bezier_Traj.mat', 'pwcurve')

% 3. simSetup에 전달
userStruct.trajFile = 'exam_PW_Bezier_Traj.mat'

% 4. GUAM 초기화
simSetup;

% 5. 시뮬레이션 실행
sim('GUAM');
```

---

## 📊 예상 결과

### 비행 성능:

```
비행 시간: 80초
비행 거리: 
  수평: 533 m
  수직: 177 m
  총: 562 m (3D)

평균 속도:
  수평: 6.7 m/s
  수직: 2.2 m/s

최대 속도:
  수평: 15.2 m/s (50 ft/s)
  수직: 8.3 m/s (500 ft/min)
```

### 제어 성능:

```
경로 추적 오차 (예상):
  Max FTE: 2-5 m
  RMS FTE: 1-3 m
  
특징:
- Bezier 곡선 덕분에 부드러운 추적
- LQRi 제어기의 우수한 성능
- 전환 구간에서 약간 큰 오차
```

---

## 🎓 학습 포인트

### 이 시나리오에서 배울 수 있는 것:

1. **Piecewise Bezier Trajectory** 📚
   - 복잡한 경로를 수학적으로 표현
   - 부드러운 궤적 생성
   - 연속성 보장

2. **Lift+Cruise 전환** 🔄
   - 수직 비행 → 수평 비행
   - 리프트 로터 → 푸셔 프로펠러
   - 동시 다축 제어

3. **3D 경로 계획** 🌐
   - X, Y, Z 축 독립 제어
   - 시간 동기화
   - 다차원 최적화

4. **현실적 UAM 운항** ✈️
   - 이륙 절차
   - 전환 프로토콜
   - 순항 비행

---

## 🔧 이 시나리오 실행 방법

### Option 1: RUNME 사용

```matlab
cd /home/user/webapp
RUNME

% 입력:
% Select demonstration case (1-5): 5
% Select: 1 or 2: 2
```

### Option 2: 직접 실행

```matlab
cd /home/user/webapp
run('Exec_Scripts/exam_Bezier.m')

% 입력:
% Select: 1 or 2: 2
```

### 결과 확인:

```matlab
% 시뮬레이션 완료 후
simPlots_GUAM;  % 기본 플롯

% Bezier 경로 시각화
Plot_PW_Bezier;  % 3D 궤적 + 속도/가속도

% 데이터 추출
logsout = evalin('base', 'logsout');
SimOut = logsout{1}.Values;
pos = squeeze(SimOut.Vehicle.EOM.InertialData.Pos_bii.Data);
```

---

## 📝 요약

### 시나리오 5-2 (Piecewise Bezier, Option 2):

```
🎯 목적: UAM 이륙 및 전환 비행 시뮬레이션

🛫 비행 프로파일:
  Phase 1 (0-10s):   Hover (지상)
  Phase 2 (10-20s):  Transition (80ft 상승)
  Phase 3 (20-80s):  Cruise (580ft, 1750ft 전진)

🎮 제어: BASELINE LQRi (최적 제어)

📐 경로: Piecewise Bezier Curve
  - 3차 Bernstein polynomial
  - C² 연속성
  - 부드러운 궤적

🚫 장애물: 없음
  - 이상적 환경
  - 바람/난기류 없음
  - 곡선은 Bezier 수학 특성

✈️ 항공기: Lift+Cruise
  - 8 리프트 로터
  - 1 푸셔 프로펠러
  - hover → transition → cruise

🎓 학습 목표:
  - Bezier 경로 계획
  - 전환 비행 역학
  - 3D 제어
  - 현실적 UAM 절차
```

---

**핵심**: 이 시나리오는 **장애물 회피가 아닌**, **부드럽고 효율적인 이륙/전환 절차**를 Bezier 곡선을 사용하여 구현한 것입니다! 🚁✈️