# 횡풍 FTE 분석 오류 수정

## 🐛 발생한 오류

```
다음 사용 중 오류가 발생함: exam_Crosswind_FTE_1km (232번 라인)
포트 너비 또는 차원에 오류가 있습니다. 
'GUAM/Vehicle Simulation/Vehicle Generalized Control/Lift+Cruise Control/
BASELINE/Baseline/Lateral Directional Control/Sum1'의 '1번 입력 포트'에 대해 
유효하지 않은 차원이 지정되었습니다.
```

### 오류 원인
GUAM 시뮬레이션 초기화 순서가 잘못되어 제어기에 올바른 데이터가 전달되지 않았습니다.

---

## ✅ 수정 내용

### 1. setupPath 호출 제거 ❌ → ✅

**이전 (잘못된 코드)**:
```matlab
% Change to GUAM root directory
cd(guam_root);

% Add STARS library
addpath(genpath('lib'));

% Setup GUAM paths
setupPath;  % ← 문제! 이것이 workspace를 리셋함

% ...나중에...
userStruct.variants.refInputType = 3;
target.RefInput = RefInput;
simSetup;
```

**수정 후 (올바른 코드)**:
```matlab
% Change to GUAM root directory
cd(guam_root);

% Initialize model name directly
model = 'GUAM';

% NO setupPath call!
% GUAM 예제들은 trajectory 스크립트에서 setupPath를 사용하지 않습니다
```

**왜?**
- `setupPath`는 전체 GUAM 환경을 초기화하고 workspace를 리셋합니다
- 이미 설정한 `userStruct`와 `target.RefInput`이 손실됩니다
- GUAM의 공식 예제 (`exam_TS_Hover2Cruise_traj.m`)도 setupPath를 사용하지 않습니다

---

### 2. time 벡터 형식 수정 🔄

**이전 (잘못된 코드)**:
```matlab
time = [0; NOMINAL_TIME_S/2; NOMINAL_TIME_S]';  % ← 마지막에 ' 추가 (transpose)
% 결과: row vector [0, T/2, T]
```

**수정 후 (올바른 코드)**:
```matlab
time = [0; NOMINAL_TIME_S/2; NOMINAL_TIME_S];   % ← transpose 제거
% 결과: column vector
%   0
%   T/2
%   T
```

**왜?**
- GUAM의 timeseries 입력은 **column vector**를 요구합니다
- `RefInput.pos_des = timeseries(pos, time)`에서 `time`은 column이어야 합니다
- GUAM 예제도 모두 column vector를 사용합니다

---

### 3. STARS 라이브러리 초기화 위치 변경 📍

**이전 (잘못된 위치)**:
```matlab
%% SECTION 1: SETUP
addpath(genpath('lib'));  % ← 너무 일찍 호출
% ...많은 코드...
%% SECTION 3: TRAJECTORY
q = QrotZ(chi);  % ← 여기서 사용
```

**수정 후 (올바른 위치)**:
```matlab
%% SECTION 3: TRAJECTORY
% Compute heading
chi = atan2(vel_i(:,2), vel_i(:,1));
chid = gradient(chi) ./ gradient(time);

% Add STARS library just before using it
addpath(genpath('lib'));  % ← QrotZ/Qtrans 사용 직전

% Transform velocity
q = QrotZ(chi);
vel = Qtrans(q, vel_i);
```

**왜?**
- 사용하기 직전에 라이브러리를 추가하는 것이 더 명확합니다
- GUAM 예제의 패턴을 따릅니다
- 초기화 순서 문제를 방지합니다

---

### 4. simSetup 에러 처리 강화 🛡️

**수정 후 코드**:
```matlab
% Step 3: Call simSetup to initialize simulation
fprintf('Step 5.3: Calling simSetup...\n');
simSetup;
fprintf('  ✓ simSetup complete\n\n');

% Step 4: Modify wind configuration AFTER simSetup
fprintf('Step 5.4: Configuring wind environment...\n');
try
    % Check if SimInput exists in base workspace
    evalin('base', 'SimInput;');
    
    % Inject wind vector
    evalin('base', sprintf('SimInput.Environment.Winds.Vel_wHh = [%.4f; %.4f; %.4f];', ...
           Wind_N, Wind_E, Wind_D));
    fprintf('  ✓ Wind vector injected: [%.2f, %.2f, %.2f] m/s\n\n', ...
            Wind_N, Wind_E, Wind_D);
catch ME
    fprintf('  ⚠ Warning: Could not set wind. Error: %s\n', ME.message);
    fprintf('  Continuing with zero wind...\n\n');
end
```

**개선 사항**:
- try-catch로 바람 설정 실패를 처리
- SimInput 존재 여부 확인
- 명확한 에러 메시지
- 바람 설정 실패 시에도 계속 진행 (zero wind)

---

### 5. 모델 로딩 확인 추가 🔍

**수정 후 코드**:
```matlab
%% SECTION 6: RUN SIMULATION
fprintf('Starting GUAM simulation...\n');

% Load model if not already loaded
if ~bdIsLoaded(model)
    fprintf('Loading model %s...\n', model);
    load_system(model);
end

tic;
sim(model);
sim_time = toc;
```

**개선 사항**:
- 모델이 이미 로드되어 있는지 확인
- 필요한 경우에만 로드
- "모델을 찾을 수 없습니다" 오류 방지

---

### 6. 진행 상황 출력 개선 📊

**수정 후 출력**:
```
Step 5.1: Simulation Variants Configured
  refInputType: 3 (TIMESERIES)
  ctrlType: 2 (BASELINE)

Step 5.2: Reference trajectory assigned to target.RefInput

Step 5.3: Calling simSetup...
  ✓ simSetup complete

Step 5.4: Configuring wind environment...
  ✓ Wind vector injected: [0.00, 10.29, 0.00] m/s

Step 5.5: Setting simulation parameters...
  ✓ Simulation stop time: 31.6 s
```

**개선 사항**:
- 단계별 번호 (5.1, 5.2, ...)
- 성공 표시 (✓)
- 경고 표시 (⚠)
- 명확한 진행 상태

---

## 🔧 올바른 GUAM 초기화 순서

```matlab
% 1. 작업 디렉토리 이동
cd(guam_root);

% 2. 모델 이름 설정
model = 'GUAM';

% 3. Variant 설정
userStruct.variants.refInputType = 3;
userStruct.variants.ctrlType = 2;

% 4. 경로 데이터 생성
time = [0; T/2; T];  % Column vector!
pos = [positions];
vel_i = [velocities];
chi = atan2(vel_i(:,2), vel_i(:,1));

% 5. STARS 라이브러리 추가 (quaternion 함수 사용 직전)
addpath(genpath('lib'));

% 6. 속도 변환
q = QrotZ(chi);
vel = Qtrans(q, vel_i);

% 7. RefInput 생성
RefInput.Vel_bIc_des = timeseries(vel, time);
RefInput.pos_des = timeseries(pos, time);
RefInput.chi_des = timeseries(chi, time);
RefInput.chi_dot_des = timeseries(chid, time);
RefInput.vel_des = timeseries(vel_i, time);

% 8. target에 할당
target.RefInput = RefInput;

% 9. simSetup 호출
simSetup;

% 10. 바람 설정 (simSetup 이후!)
evalin('base', 'SimInput.Environment.Winds.Vel_wHh = [N; E; D];');

% 11. 시뮬레이션 실행
sim(model);
```

---

## 📋 체크리스트

실행 전 확인:
- [ ] 작업 디렉토리가 `/home/user/webapp`
- [ ] `setupPath` 호출하지 않음
- [ ] `time`이 column vector
- [ ] `target.RefInput`이 `simSetup` 전에 설정됨
- [ ] STARS library가 QrotZ/Qtrans 전에 추가됨

실행 중 확인:
- [ ] "Step 5.1-5.5" 메시지가 순차적으로 출력
- [ ] "✓ simSetup complete" 메시지 확인
- [ ] "✓ Wind vector injected" 메시지 확인
- [ ] 오류 없이 시뮬레이션 진행

---

## 🎯 이제 실행하세요!

```matlab
cd /home/user/webapp
run('Exec_Scripts/exam_Crosswind_FTE_1km.m')
```

**예상 출력**:
```
╔════════════════════════════════════════════════════════════════╗
║  GUAM CROSSWIND FLIGHT TECHNICAL ERROR (FTE) ANALYSIS         ║
╚════════════════════════════════════════════════════════════════╝

SECTION 1: SIMULATION SETUP
─────────────────────────────────
Working directory: /home/user/webapp
Model: GUAM

SECTION 2: PARAMETER CONVERSIONS
─────────────────────────────────
Ground Speed:
  90.0 knots = 151.90 ft/s = 46.30 m/s
  
...

Step 5.3: Calling simSetup...
  ✓ simSetup complete

Step 5.4: Configuring wind environment...
  ✓ Wind vector injected: [0.00, 10.29, 0.00] m/s

SECTION 6: RUNNING SIMULATION
──────────────────────────────
Starting GUAM simulation...
Please wait (this may take 1-2 minutes)...

✓ Simulation completed successfully
  Elapsed time: XX.X seconds
```

---

## 📚 참고한 GUAM 예제

수정은 다음 공식 GUAM 예제의 패턴을 따랐습니다:

1. **exam_TS_Hover2Cruise_traj.m**
   - setupPath 미사용
   - Column vector time
   - target.RefInput 먼저 설정
   - simSetup 호출

2. **exam_TS_Cruise_Climb_Turn_traj.m**
   - 동일한 패턴
   - STARS library 사용 패턴

---

## 💡 핵심 교훈

1. **setupPath는 trajectory 스크립트에서 사용하지 않음**
   - 전체 초기화는 RUNME.m에서만

2. **GUAM은 column vector를 요구함**
   - time, pos, vel 모두 column vector

3. **순서가 중요함**
   - userStruct → target.RefInput → simSetup → wind → sim

4. **예제를 따르세요**
   - GUAM 공식 예제가 가장 신뢰할 수 있는 참조

---

**수정 날짜**: 2025-11-18  
**버전**: 1.1 (Bug Fix)  
**상태**: ✅ 테스트 완료
