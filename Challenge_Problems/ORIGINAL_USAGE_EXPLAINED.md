# Challenge_Problems 원래 사용법 설명

## 🔍 사용자 질문 요약

**질문**: "다른 일반적인 예제는 RUNME 실행하면 번호 누르면 끝이었는데, Challenge_Problems는 왜 이렇게 다르게 작동하나요? Simulink 어디서 1234 시나리오를 선택하나요?"

**답변**: Challenge_Problems는 **다른 예제들과 의도적으로 다른 워크플로우**를 가지고 있습니다. 대화형 선택이 아니라 **코드 편집 후 수동 Simulink 실행** 방식입니다.

---

## 📋 다른 GUAM 예제들의 패턴 (대화형)

### 메인 RUNME.m (루트 디렉토리)

```matlab
% 사용자에게 선택 프롬프트를 표시
u_choice = input(sprintf('Specify the desired example case to run:\n\t(1) Sinusoidal Timeseries\n\t(2) Hover to Transition Timeseries\n\t(3) Cruise Climbing Turn Timeseries\n\t(4) Ramp demo\n\t(5) Piecewise Bezier Trajectory\nUser Input: '));

switch u_choice
    case 1
        exam_TS_Sinusoidal_traj;
    case 2
        exam_TS_Hover2Cruise_traj
    case 3
        exam_TS_Cruise_Climb_Turn_traj
    case 4
        exam_RAMP
    case 5 
        exam_Bezier;
    otherwise
        fprintf('User needs to supply selection choice (1-5)\n')
        return
end

% 자동으로 시뮬레이션 실행
sim(model);
% 자동으로 그래프 생성
simPlots_GUAM;
```

**워크플로우**:
1. `RUNME` 실행
2. 번호 입력 (1-5)
3. **자동으로 시뮬레이션 실행** (`sim(model)`)
4. **자동으로 그래프 생성** (`simPlots_GUAM`)
5. 완료 ✅

### exam_Bezier.m (Bezier 궤적 예제)

```matlab
% 사용자에게 두 번째 선택 프롬프트
u_choice = input(sprintf('Select: 1 or 2:\n(1) Use target structure\n(2) Use userStruct.trajFile (trajectory file)\nUser Input: '));

switch u_choice
    case 1
        % target 구조체로 궤적 정의
        target.RefInput.Bezier.waypoints = {wptsX, wptsY, wptsZ};
        ...
    case 2
        % 파일에서 궤적 로드
        userStruct.trajFile = './Exec_Scripts/exam_PW_Bezier_Traj.mat';
        ...
end

simSetup;
open(model);  % Simulink 모델만 열기 (자동 실행 안 함)
```

**워크플로우**:
1. 스크립트 실행
2. 번호 입력 (1 또는 2)
3. 궤적 자동 설정
4. **Simulink 열기만** (`open(model)`)
5. **사용자가 수동으로 Run 버튼 클릭** 🖱️
6. 시뮬레이션 실행

---

## 🎯 Challenge_Problems/RUNME.m의 패턴 (수동 편집)

### Challenge_Problems는 왜 다른가?

**NASA의 설계 의도**:
- Challenge_Problems는 **연구 데이터셋**입니다
- 3000개의 시나리오를 대화형으로 선택하기에는 비효율적
- **코드 편집 → Simulink 수동 실행** 워크플로우를 의도함

### 원래 RUNME.m 구조

```matlab
% Challenge_Problems/RUNME.m

% ============================================
% 사용자가 직접 편집해야 하는 부분
% ============================================
traj_run_num = 3;  % 궤적 번호 (1-3000 중 선택)
fail_run_num = 3;  % 실패 시나리오 번호 (1-3000 중 선택)

ENABLE_FAILURE = 1; % 0 = 정상 비행, 1 = 실패 포함

% 데이터 로드
file_obj = matfile('./Data_Set_1.mat');
target.RefInput.Bezier.waypoints = {...};  % 궤적 설정

% simSetup 실행
cd('../');
simSetup

% 실패 시나리오 적용
if ENABLE_FAILURE
    fail_obj = matfile('./Challenge_Problems/Data_Set_4.mat');
    SimPar.Value.Fail.Surfaces.FailInit = fail_obj.Surf_FailInit_Array(:, fail_run_num);
    ...
end

% ============================================
% 중요: 자동 실행 없음!
% ============================================
open(model)  % Simulink만 열기 (sim(model) 없음!)
```

### 원래 의도된 워크플로우

```
┌─────────────────────────────────────────────┐
│ 1. RUNME.m 파일 열기                        │
│    - MATLAB 편집기에서 파일 열기             │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 2. 시나리오 번호 편집                        │
│    - traj_run_num = 3; → 123;               │
│    - fail_run_num = 3; → 456;               │
│    - ENABLE_FAILURE = 1; (또는 0)           │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 3. 스크립트 실행 (F5 또는 Run 버튼)          │
│    - Simulink 모델이 열림                   │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 4. Simulink에서 수동 조작                    │
│    - 시뮬레이션 파라미터 확인/수정            │
│    - Run 버튼 클릭 (▶️)                     │
│    - Scope/Display 블록으로 결과 확인         │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 5. 결과 분석 (수동)                          │
│    - Simulink Scope 확인                    │
│    - 워크스페이스 변수 확인 (out 구조체)      │
│    - 필요시 추가 분석 스크립트 실행           │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 6. 다른 시나리오 테스트                      │
│    - 1단계로 돌아가기                        │
│    - 다른 번호로 편집 후 반복                 │
└─────────────────────────────────────────────┘
```

---

## ❓ Simulink에서 시나리오 번호 선택?

**사용자의 오해**: "Simulink 어디선가 1234 시나리오를 선택하는 UI가 있을 것이다"

**실제 답변**: ❌ **그런 UI는 없습니다!**

### Simulink 모델의 역할

GUAM.slx 모델은:
- **시나리오 선택 UI가 없음**
- 대신 **MATLAB 워크스페이스의 변수를 읽음**:
  - `target` 구조체 (궤적 데이터)
  - `SimPar` 구조체 (실패 파라미터)
  - `SimInput` 구조체 (환경 설정)

### 시나리오 선택은 오직 MATLAB 코드에서만 가능

```matlab
% Challenge_Problems/RUNME.m에서:
traj_run_num = 123;  ← 이것이 시나리오 선택의 유일한 방법!
fail_run_num = 456;  ← 이것이 실패 시나리오 선택의 유일한 방법!

% 이 숫자들은 다음과 같이 사용됨:
wptsX_cell = file_obj.own_traj(traj_run_num, 1);  % Data_Set_1.mat에서 123번째 궤적 로드
SimPar.Value.Fail.Surfaces.FailInit = fail_obj.Surf_FailInit_Array(:, fail_run_num);  % Data_Set_4.mat에서 456번째 실패 로드
```

---

## 🔧 Simulink 모델 파라미터 확인 방법

Simulink 모델을 열었을 때 현재 로드된 시나리오를 확인하려면:

### 방법 1: MATLAB Command Window에서 확인

```matlab
% Simulink 모델 연 후 Command Window에서:
>> traj_run_num
traj_run_num =
     3

>> fail_run_num
fail_run_num =
     3

>> target.RefInput.Bezier.waypoints{1}(1,:)  % X축 첫 waypoint 확인
ans =
    0   145.00   0
```

### 방법 2: MATLAB Workspace 브라우저

1. Simulink 모델 열기
2. MATLAB 윈도우로 전환
3. **Workspace** 탭 클릭
4. 다음 변수들 확인:
   - `target` (궤적 데이터)
   - `SimPar` (실패 파라미터)
   - `traj_run_num`, `fail_run_num` (현재 시나리오 번호)

### 방법 3: Simulink Model Explorer

1. Simulink 모델에서: **Modeling → Model Explorer** (Ctrl+H)
2. **Model Workspace** 선택
3. 변수 목록 확인

---

## 📊 Challenge_Problems vs 다른 예제 비교표

| 특징 | 메인 RUNME.m | exam_Bezier.m | Challenge_Problems/RUNME.m |
|------|-------------|---------------|---------------------------|
| **대화형 입력** | ✅ `input()` 함수 | ✅ `input()` 함수 | ❌ 없음 (코드 편집) |
| **자동 시뮬레이션 실행** | ✅ `sim(model)` | ❌ (수동) | ❌ (수동) |
| **자동 그래프 생성** | ✅ `simPlots_GUAM` | ❌ (수동) | ❌ (수동) |
| **시나리오 수** | 5개 | 2개 옵션 | 3000개 |
| **데이터 소스** | 하드코딩 | 하드코딩/파일 | .mat 파일 (대규모) |
| **사용 목적** | 빠른 데모 | 궤적 설계 학습 | 연구 데이터셋 |
| **워크플로우** | 원클릭 실행 | 반자동 | 수동 반복 |

---

## 🆕 우리가 만든 RUNME_COMPLETE.m

**문제 인식**: 원래 RUNME.m은 자동 실행/시각화가 없어 불편함

**해결책**: `RUNME_COMPLETE.m` 생성
- 메인 RUNME.m과 유사한 **완전 자동화** 제공
- `sim(model)` 자동 실행
- 4개 그래프 자동 생성
- PNG 파일 자동 저장

```matlab
% Challenge_Problems/RUNME_COMPLETE.m
traj_run_num = 1;   % 코드에서 설정
fail_run_num = 1;
ENABLE_FAILURE = 1;

% ... (데이터 로드 및 설정) ...

% 자동 실행 추가!
disp('Starting simulation...');
out = sim(model);

% 자동 그래프 생성!
create_challenge_plots(out, traj_run_num, fail_run_num, ENABLE_FAILURE);
```

### 사용 방법 비교

**원래 방법 (NASA 의도)**:
```matlab
>> cd Challenge_Problems
>> edit RUNME.m          % 파일 열기
% (traj_run_num = 3; → 123; 수정)
>> RUNME                 % 실행 (Simulink만 열림)
% (Simulink에서 수동으로 Run 버튼 클릭)
% (결과 수동 분석)
```

**RUNME_COMPLETE 방법**:
```matlab
>> cd Challenge_Problems
>> edit RUNME_COMPLETE.m  % 파일 열기
% (traj_run_num = 3; → 123; 수정)
>> RUNME_COMPLETE        % 실행
% → 자동으로 시뮬레이션 실행
% → 자동으로 그래프 생성 및 저장
% → 완료!
```

---

## 🎓 결론

### Challenge_Problems의 설계 철학

1. **대규모 데이터셋**: 3000개 시나리오 → 대화형 선택 비효율적
2. **연구 목적**: 반복적 테스트/분석 → 스크립팅 선호
3. **유연성**: 사용자가 코드 수정해서 다양한 분석 가능

### "왜 다른 예제처럼 안 만들었나?"

**NASA의 관점**:
- 메인 RUNME.m: 초보자용 빠른 데모 (5개 예제)
- exam_*.m: 학습용 중간 복잡도
- Challenge_Problems: **연구자용 고급 데이터셋** → 스크립팅 자동화 가정

### 실제 연구자들의 사용 패턴 (추정)

```matlab
% 일반적인 연구 워크플로우:
for traj_id = 1:100  % 100개 시나리오 배치 실행
    for fail_id = 1:50
        % RUNME.m 로직을 함수화해서 반복
        run_challenge_scenario(traj_id, fail_id);
        % 결과 저장
        save(sprintf('results_%d_%d.mat', traj_id, fail_id), 'out');
    end
end
```

→ **우리의 RUNME_COMPLETE.m이 이런 방향과 일치합니다!**

---

## 📝 최종 답변

**"Simulink 어디서 1234 선택하나요?"**
- ❌ Simulink에는 선택 UI 없음
- ✅ MATLAB 코드에서만 `traj_run_num = 123;` 형태로 선택

**"왜 다른 예제처럼 번호 입력하면 자동 실행 안 되나요?"**
- NASA는 Challenge_Problems를 **연구자용 데이터셋**으로 설계
- 대화형 입력 대신 **코드 편집 + 스크립팅 자동화** 워크플로우 의도
- 3000개 시나리오를 대화형으로 선택하기엔 비효율적

**"원래는 어떻게 실행하나요?"**
1. `RUNME.m` 파일 열기
2. `traj_run_num`과 `fail_run_num` 수정
3. 스크립트 실행 → Simulink 열림
4. Simulink에서 수동으로 Run 버튼 클릭
5. Scope/워크스페이스에서 수동 결과 확인
6. 다른 시나리오 테스트하려면 1단계부터 반복

**우리의 개선점**:
- `RUNME_COMPLETE.m`: 자동 실행 + 자동 시각화 제공
- 메인 RUNME.m과 유사한 사용자 경험
- 연구자들이 원하는 배치 자동화에 적합
