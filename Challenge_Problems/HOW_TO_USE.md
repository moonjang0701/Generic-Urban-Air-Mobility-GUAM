# Challenge Problems 사용 가이드

## 🎯 빠른 시작

### 1단계: MATLAB에서 실행
```matlab
cd Challenge_Problems
RUNME_COMPLETE
```

**끝!** 시뮬레이션이 자동으로 실행되고 결과가 표시됩니다.

---

## 📊 제공되는 데이터

### ✅ 이미 준비된 데이터 (만들 필요 없음!)

| 파일 | 내용 | 개수 | 크기 |
|------|------|------|------|
| `Data_Set_1.mat` | 비행 궤적 | 3000개 | 23 MB |
| `Data_Set_2.mat` | 고정 장애물 | 3000개 | 215 KB |
| `Data_Set_3.mat` | 이동 장애물 | 3000개 | 7.1 MB |
| `Data_Set_4.mat` | 고장 시나리오 | 3000개 | 344 KB |

---

## 🚀 실행 방법

### 방법 1: 완전 자동 (추천) ⭐

```matlab
cd Challenge_Problems
RUNME_COMPLETE
```

**결과:**
- ✅ 시뮬레이션 자동 실행
- ✅ 4개 그래프 자동 생성
- ✅ 결과 PNG 파일로 저장
- ✅ 통계 출력

---

### 방법 2: 원래 스크립트 (수동)

```matlab
cd Challenge_Problems
RUNME  % Simulink만 열림

% 그 다음 Simulink에서 수동으로:
% 1. Run 버튼 클릭
% 2. 시뮬레이션 완료 대기
% 3. Data Inspector로 결과 확인
```

---

## ⚙️ 시나리오 변경

### 다른 궤적/고장 시도하기:

`RUNME_COMPLETE.m` 파일 열고 상단 수정:

```matlab
traj_run_num = 1;     % 1~3000 중 선택 (현재: 1)
fail_run_num = 1;     % 1~3000 중 선택 (현재: 1)
ENABLE_FAILURE = true; % false로 하면 고장 없음
```

**추천 조합:**
- `traj_run_num = 1, fail_run_num = 1` ← 안정적
- `traj_run_num = 5, fail_run_num = 5` ← 중간
- `traj_run_num = 10, fail_run_num = 10` ← 도전적

**주의:** 
- 일부 조합은 심각한 고장으로 인해 simulation이 실패할 수 있음
- 예: `traj=3, fail=3`은 고장 5초 후 departure from flight
- 실패하면 다른 번호 시도!

---

## 📈 출력 결과

### 자동 생성되는 그래프:

1. **`Trajectory_3D_*.png`**
   - 3D 비행 경로
   - 시작점 (녹색)
   - 끝점 (빨간색)
   - 고장 발생 지점 (빨간 X)

2. **`Position_Time_*.png`**
   - North, East, Altitude vs 시간
   - 고장 시점 표시 (빨간 선)

3. **`Attitude_Time_*.png`**
   - Roll, Pitch, Yaw vs 시간
   - 고장 후 자세 변화 확인

4. **`Velocity_Time_*.png`**
   - Ground speed, Vertical speed
   - 고장 후 속도 변화 확인

---

## 🔧 고급 사용법

### A. 고장 없이 실행

```matlab
% RUNME_COMPLETE.m 수정
ENABLE_FAILURE = false;
```

→ 정상 비행만 확인

---

### B. 특정 고장 타입 확인

시뮬레이션 후 콘솔 출력:

```
Surface failures:
  Surface #2: Type 1 at t=15.3s
Propeller failures:
  Prop #4: Type 2 at t=15.3s
```

**고장 타입:**
- Type 1 = Hold Last (고정)
- Type 2 = Pre-Scale (감쇠)
- Type 3 = Post-Scale
- Type 4 = Position Limits
- Type 8 = Control Reversal (역작동!)

---

### C. 여러 시나리오 배치 실행

```matlab
% 여러 시나리오 자동 테스트
for i = 1:10
    traj_run_num = i;
    fail_run_num = i;
    
    try
        RUNME_COMPLETE;
        fprintf('✓ Scenario %d completed\n', i);
    catch
        fprintf('✗ Scenario %d failed\n', i);
    end
end
```

---

## 🎨 데이터 시각화 도구

### Plot_Chal_Prob_DSets.m 사용

```matlab
% 장애물과 함께 궤적 시각화
cd Challenge_Problems
Plot_Chal_Prob_DSets  % 인터랙티브 플롯
```

---

## 🔍 데이터 구조

### Dataset 1 (Trajectories) 구조:

```matlab
load('Data_Set_1.mat');

% 궤적 #1 접근:
wptsX = own_traj{1, 1};      % X waypoints
wptsY = own_traj{1, 2};      % Y waypoints
wptsZ = own_traj{1, 3};      % Z waypoints
time_X = own_traj{1, 4};     % Time stamps
```

### Dataset 4 (Failures) 구조:

```matlab
load('Data_Set_4.mat');

% 고장 #1 접근:
surf_fail_type = Surf_FailInit_Array(:, 1);  % [5×1] array
surf_fail_time = Surf_InitTime_Array(:, 1);
prop_fail_type = Prop_FailInit_Array(:, 1);  % [9×1] array
```

---

## ⚠️ 문제 해결

### 문제 1: "Simulation failed: departed from flight"

**원인:** 고장이 너무 심각해서 항공기가 제어 불능

**해결:**
```matlab
% 다른 시나리오 선택
traj_run_num = 1;  % 더 안정적인 번호로
fail_run_num = 1;
```

---

### 문제 2: "Cannot find Data_Set_X.mat"

**원인:** 잘못된 디렉토리

**해결:**
```matlab
% 반드시 Challenge_Problems 폴더에서 실행
cd Challenge_Problems
pwd  % 확인
```

---

### 문제 3: Simulink만 열리고 아무것도 안 됨

**원인:** 원래 `RUNME.m` 사용 중

**해결:**
```matlab
% RUNME_COMPLETE.m 사용!
RUNME_COMPLETE  % 이걸로 실행
```

---

## 📚 추가 리소스

### 새 데이터 생성 (선택사항)

원한다면 새로운 시나리오를 만들 수 있음:

```matlab
% 새 궤적 생성
Generate_Own_Traj

% 새 고정 장애물
Generate_Stat_Obst

% 새 이동 장애물
Generate_Mov_Obst

% 새 고장 시나리오
Generate_Failures
```

**하지만 필요 없음!** 이미 3000개씩 있음!

---

## 🎯 요약

### 가장 간단한 방법:

```matlab
>> cd Challenge_Problems
>> RUNME_COMPLETE
```

### 결과:
- ✅ 자동 시뮬레이션
- ✅ 4개 그래프 (PNG)
- ✅ 통계 출력
- ✅ 고장 정보

### 커스터마이즈:
- `traj_run_num` 변경 (1-3000)
- `fail_run_num` 변경 (1-3000)
- `ENABLE_FAILURE = false` (고장 없이)

---

## 💡 팁

1. **처음 실행:** `traj=1, fail=1` (안정적)
2. **고장 효과 보기:** 그래프에서 빨간 선 이후 확인
3. **여러 시나리오 비교:** 다른 번호로 여러 번 실행
4. **실패하면:** 다른 번호로 재시도

---

**즐기세요!** 🚁
