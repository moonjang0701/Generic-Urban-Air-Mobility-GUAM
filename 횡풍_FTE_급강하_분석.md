# 25초 이후 급강하 현상 분석 및 해결

## 🐛 관찰된 현상

**증상**: 21.6초(1km 구간 완료) 이후, 약 25초 부근에서 위치 그래프가 급격히 하강

---

## 🔍 근본 원인

### 1. **경로 명령 시간 불일치**

```matlab
% 현재 설정:
NOMINAL_TIME_S = 21.6초    // 경로 명령 끝
TOTAL_TIME_S = 31.6초      // 시뮬레이션 끝
```

**문제**:
- 경로 명령은 21.6초까지만 정의됨
- 하지만 시뮬레이션은 31.6초까지 계속 실행됨
- **10초 동안 명령 공백!**

---

### 2. **Timeseries 외삽 동작**

```matlab
RefInput.pos_des = timeseries(pos, time)
// time = [0; 10.8; 21.6]
// pos  = [0; 500; 1000]

// t > 21.6초일 때:
pos_des(25) = ???
```

#### MATLAB Timeseries 동작:
```
기본 동작: 'hold' (마지막 값 유지)
pos_des(t > 21.6) = [1000, 0, -304.8]  // 고정!

하지만 항공기는:
- 관성으로 계속 전진 (1020m, 1030m, ...)
- 속도 유지 (46.3 m/s)
```

---

### 3. **제어기의 "잘못된" 반응**

```
t = 22초:
  pos_actual = 1020 m
  pos_des = 1000 m (고정)
  error = -20 m
  
  제어기 판단: "목표를 20m 넘어감! 감속해야 함!"
  
t = 23초:
  pos_actual = 1030 m
  pos_des = 1000 m
  error = -30 m
  
  제어기 판단: "더 멀어짐! 더 강하게 감속!"
  
t = 24-25초:
  제어기: "목표로 돌아가자!"
  
  제어 명령:
  1. Pitch down (기수 아래로)
  2. 추력 감소
  3. 속도 감속 시도
  
  결과:
  → 양력 손실 (속도 감소)
  → 추력 감소
  → 급강하 시작!
```

---

## 📊 물리적 메커니즘

### Lift+Cruise 항공기의 전진 비행:

```
양력 = 날개 양력 + 리프트 로터 잔여 추력
     = (1/2) * ρ * V² * S * C_L + T_lift_rotors

속도 감소 시:
V ↓ → 양력 ↓ (V² 항)

제어기가 감속 명령 시:
추력 ↓ + 양력 ↓ = 총 수직력 ↓
→ 고도 유지 불가
→ 하강 시작
```

### 시간별 분석:

```
0-21.6초: 정상 비행
  ✓ 경로 명령 활성
  ✓ 제어기 정상 동작
  ✓ 고도 유지

21.6-25초: 오버슈트
  ⚠ 관성으로 계속 전진
  ⚠ 목표는 고정 (1000m)
  ⚠ 제어기가 오차 감지
  
25-31.6초: 급강하
  ❌ 강한 감속 명령
  ❌ 양력 손실
  ❌ 고도 하강
  ❌ FTE 급증
```

---

## ✅ 해결 방법

### 방법 1: **경로를 시뮬레이션 끝까지 연장** (추천!)

```matlab
% 수정된 코드:
NOMINAL_TIME_S = 21.6;
TOTAL_TIME_S = 31.6;

% 4 waypoints로 확장:
time = [0; NOMINAL_TIME_S/2; NOMINAL_TIME_S; TOTAL_TIME_S];
%      0    10.8              21.6             31.6

pos = zeros(4, 3);
pos(:,1) = [0; 500; 1000; 1000 + GROUND_SPEED_MS*(TOTAL_TIME_S-NOMINAL_TIME_S)];
%           시작 중간 끝    계속 전진 (1463m)

vel_i = zeros(4, 3);
vel_i(:,1) = GROUND_SPEED_MS;  // 계속 46.3 m/s 유지
vel_i(:,2) = 0;
vel_i(:,3) = 0;
```

**효과**:
```
0-21.6초: 1km 구간 비행
21.6-31.6초: 추가 463m 전진
→ 경로 명령 지속적으로 제공
→ 제어기 혼란 없음
→ 급강하 방지
```

---

### 방법 2: **시뮬레이션 시간을 경로 시간과 일치**

```matlab
% 수정된 코드:
NOMINAL_TIME_S = 21.6;
TOTAL_TIME_S = NOMINAL_TIME_S + 2;  // 2초만 여유

time = [0; NOMINAL_TIME_S/2; NOMINAL_TIME_S];
// 21.6초 이후 빠르게 종료
```

**효과**:
```
급강하가 일어나기 전에 시뮬레이션 종료
→ 문제 회피
```

**단점**:
- FTE 통계가 짧은 구간에만 적용
- 실제 문제 해결은 아님

---

### 방법 3: **Hover로 전환** (현실적)

```matlab
% 4 waypoints:
time = [0; NOMINAL_TIME_S/2; NOMINAL_TIME_S; TOTAL_TIME_S];

pos(:,1) = [0; 500; 1000; 1000];  // 끝점에서 정지
pos(:,2) = [0; 0; 0; 0];
pos(:,3) = [-304.8; -304.8; -304.8; -304.8];

vel_i(1:3, 1) = GROUND_SPEED_MS;  // 전진
vel_i(4, 1) = 0;                  // 정지 (hover)
```

**효과**:
```
21.6초에 도착 후 제자리 비행 (hover)
→ 현실적인 시나리오
→ 급강하 방지
```

---

### 방법 4: **감속 구간 추가** (가장 현실적!)

```matlab
% 5 waypoints:
DECEL_TIME_S = 5;  // 5초 감속

time = [0; 
        NOMINAL_TIME_S/2; 
        NOMINAL_TIME_S; 
        NOMINAL_TIME_S + DECEL_TIME_S;
        TOTAL_TIME_S];

pos(:,1) = [0; 500; 1000; 1100; 1100];  // 100m 더 전진 후 hover

vel_i(1:3, 1) = GROUND_SPEED_MS;  // 전진
vel_i(4, 1) = 0;                  // 감속 완료
vel_i(5, 1) = 0;                  // hover 유지
```

**효과**:
```
21.6초: 1km 도달
21.6-26.6초: 100m 더 가면서 감속 (46.3 → 0 m/s)
26.6-31.6초: 제자리 비행
→ 가장 현실적
→ 부드러운 전환
→ 급강하 없음
```

---

## 🔧 권장 수정 코드

### 파일: `exam_Crosswind_FTE_1km.m`

```matlab
%% SECTION 3: DEFINE REFERENCE TRAJECTORY (수정 버전)

% Calculate times
NOMINAL_TIME_S = SEGMENT_LENGTH_M / GROUND_SPEED_MS;  // 21.6s
DECEL_TIME_S = 5;  // 5초 감속 구간
HOVER_TIME_S = TOTAL_TIME_S - NOMINAL_TIME_S - DECEL_TIME_S;  // 5초 hover

% 5 waypoints for complete flight profile:
time = [0; 
        NOMINAL_TIME_S/2; 
        NOMINAL_TIME_S; 
        NOMINAL_TIME_S + DECEL_TIME_S;
        TOTAL_TIME_S];
%      [0; 10.8; 21.6; 26.6; 31.6]

N_time = length(time);

% Position waypoints (NED)
pos = zeros(N_time, 3);
DECEL_DIST = GROUND_SPEED_MS * DECEL_TIME_S / 2;  // 평균 속도로 거리 계산
pos(:,1) = [N_start; 
            (N_start+N_end)/2; 
            N_end; 
            N_end + DECEL_DIST;  // 감속하면서 조금 더 전진
            N_end + DECEL_DIST]; // hover 위치
pos(:,2) = [E_start; (E_start+E_end)/2; E_end; E_end; E_end];  // East 유지
pos(:,3) = [D_start; (D_start+D_end)/2; D_end; D_end; D_end];  // 고도 유지

% Velocity waypoints (inertial frame)
vel_i = zeros(N_time, 3);
vel_i(1:3, 1) = GROUND_SPEED_MS;  // 전진 비행
vel_i(4, 1) = 0;                  // 감속 완료
vel_i(5, 1) = 0;                  // hover
vel_i(:, 2) = 0;                  // East velocity
vel_i(:, 3) = 0;                  // Down velocity

fprintf('Complete Flight Profile:\n');
fprintf('  0-%.1f s:     Forward flight at %.1f m/s\n', NOMINAL_TIME_S, GROUND_SPEED_MS);
fprintf('  %.1f-%.1f s: Deceleration phase\n', NOMINAL_TIME_S, NOMINAL_TIME_S+DECEL_TIME_S);
fprintf('  %.1f-%.1f s: Hover\n\n', NOMINAL_TIME_S+DECEL_TIME_S, TOTAL_TIME_S);
```

---

## 📊 예상 결과 (수정 후)

### Ground Track:
```
North (m)
  ▲
1116├─────────────────────┐ Hover
    │                     │
1100├──────────────┐      │ Decel
    │              │      │
1000├──────┐       │      │ Main segment
    │      │       │      │
 500├──┐   │       │      │
    │  │   │       │      │
   0└──┴───┴───────┴──────┴───► Time (s)
      0  10.8  21.6  26.6  31.6
```

### Lateral FTE:
```
    ▲
  3 ├─╮             ┌─┐
    │ ╰─╮         ╭─╯ ╰─╮
  0 ├───╰─────────╯─────╰───
    │
 -3 ├
    └─────────────────────► Time (s)
      0   10  20   26   31
      
정상 FTE 유지 (급강하 없음!)
```

---

## 💡 왜 이런 일이 일어났나?

### 설계 의도:
```
원래 의도: 1km 구간의 FTE만 측정
실제 구현: 1km 후에도 시뮬레이션 계속 실행
```

### 교훈:
```
Timeseries 경로 입력 사용 시:
✓ 경로 시간 ≥ 시뮬레이션 시간
✓ 또는 적절한 종료 절차 (감속 → hover)
✓ 명령 공백 방지
```

---

## 🎯 어떤 방법을 선택할까?

### 당신의 목적에 따라:

#### 목적: **1km 구간의 FTE만 측정**
→ **방법 2**: 시뮬 시간을 23초로 단축
```matlab
TOTAL_TIME_S = NOMINAL_TIME_S + 2;
```

#### 목적: **전체 비행 프로파일 분석**
→ **방법 4**: 감속 + hover 추가 (가장 추천!)
```matlab
5 waypoints with decel phase
```

#### 목적: **간단한 수정**
→ **방법 1**: 경로 연장
```matlab
계속 직진하도록 waypoint 추가
```

---

## 📝 수정 스크립트

아래 명령으로 수정된 버전을 생성할 수 있습니다:

```matlab
% 원본 백업
copyfile('Exec_Scripts/exam_Crosswind_FTE_1km.m', ...
         'Exec_Scripts/exam_Crosswind_FTE_1km_backup.m');

% 수정된 버전 생성
% (위의 권장 수정 코드 적용)
```

---

## ✅ 검증 방법

수정 후 확인사항:

```matlab
% 시뮬레이션 실행 후:
load('Crosswind_FTE_Results/Crosswind_FTE_Results.mat');

% 1. 고도 확인
figure;
plot(results.time, -results.position_actual(:,3));
ylabel('Altitude (m)');
xlabel('Time (s)');
title('Altitude Profile');
% 급강하 없어야 함!

% 2. 속도 확인
V = sqrt(sum(diff(results.position_actual).^2, 2)) ./ diff(results.time);
figure;
plot(results.time(1:end-1), V);
ylabel('Velocity (m/s)');
xlabel('Time (s)');
title('Velocity Profile');
% 부드러운 감속 곡선이어야 함

% 3. FTE 확인
figure;
plot(results.time, results.errors.lateral);
ylabel('Lateral FTE (m)');
xlabel('Time (s)');
title('Lateral FTE (No Dive)');
% 25초 이후 이상 없어야 함
```

---

## 🎓 핵심 교훈

1. **Timeseries 경로는 시뮬 끝까지 정의해야 함**
2. **명령 공백은 제어기 혼란을 유발함**
3. **현실적인 비행은 감속/hover 절차 포함**
4. **관성을 고려한 경로 설계 필요**

---

**요약**: 25초 급강하는 **경로 명령 종료 후 제어기가 "목표로 돌아가려는" 시도** 때문입니다. 경로를 시뮬레이션 끝까지 연장하거나 적절한 감속/hover 절차를 추가하면 해결됩니다! 🎯
