

# 횡풍에 의한 항공기 위치 오차 (FTE) 분석 가이드

## 📌 개요

이 스크립트는 GUAM 시뮬레이터를 사용하여 횡풍(crosswind) 환경에서 항공기의 **Flight Technical Error (FTE)**를 계산합니다.

### FTE란?
- **Flight Technical Error (비행 기술 오차)**: 항공기가 의도한 경로에서 벗어난 정도
- 항공기 제어 시스템의 성능과 외부 교란(횡풍 등)에 대한 대응 능력을 평가
- 특히 **횡방향 오차(Cross-track error)**가 가장 중요한 지표

---

## 🚀 빠른 실행

### 기본 실행 (1km, 90노트, 20노트 횡풍)
```matlab
cd /home/user/webapp
run('Exec_Scripts/exam_Crosswind_FTE_1km.m')
```

**예상 시간**: 1-2분  
**결과**: `Crosswind_FTE_Results/` 폴더에 그래프와 데이터 생성

---

## 📊 시뮬레이션 설정

### 기본 비행 파라미터
| 파라미터 | 값 | 설명 |
|---------|-----|------|
| **비행 거리** | 1,000 m (1 km) | 직선 경로 |
| **대지 속도** | 90 knots (46.3 m/s) | 항공기 지면 속도 |
| **고도** | 1,000 ft (304.8 m) | 비행 고도 |
| **경로 방향** | 0° (North) | 북쪽 방향 |
| **횡풍** | 20 knots (10.3 m/s) | 경로에 수직 |
| **제어기** | GUAM Baseline (LQRi) | 기본 제어기 |

### 좌표계
- **NED 좌표계 사용**: North-East-Down
  - North (N): 북쪽 (+) / 남쪽 (-)
  - East (E): 동쪽 (+) / 서쪽 (-)
  - Down (D): 아래 (+) / 위 (-), 고도는 음수!

---

## 🔧 파라미터 변경 방법

스크립트 상단의 **USER CONFIGURABLE PARAMETERS** 섹션을 수정하세요:

```matlab
%% USER CONFIGURABLE PARAMETERS
% =========================================================================

% 비행 구간 파라미터
SEGMENT_LENGTH_M = 1000;        % 거리 (미터)
GROUND_SPEED_KT = 90;           % 대지 속도 (노트)
ALTITUDE_FT = 1000;             % 고도 (피트)
TRACK_HEADING_DEG = 0;          % 경로 방향 (0 = 북쪽)

% 바람 파라미터
CROSSWIND_KT = 20;              % 횡풍 크기 (노트)
CROSSWIND_DIR_DEG = 90;         % 횡풍 방향 (경로 기준, 90 = 수직)

% 시뮬레이션 파라미터
TIME_MARGIN_S = 10;             % 추가 시뮬레이션 시간 (초)
```

### 예제: 다른 조건으로 실행

#### 예제 1: 더 강한 횡풍 (30노트)
```matlab
CROSSWIND_KT = 30;  % 20 → 30 노트로 변경
```

#### 예제 2: 더 빠른 속도 (120노트)
```matlab
GROUND_SPEED_KT = 120;  % 90 → 120 노트로 변경
```

#### 예제 3: 더 높은 고도 (2000피트)
```matlab
ALTITUDE_FT = 2000;  % 1000 → 2000 피트로 변경
```

#### 예제 4: 동쪽 방향 비행
```matlab
TRACK_HEADING_DEG = 90;  % 0 → 90도 (동쪽)
```

---

## 📈 결과 해석

### 생성되는 파일들

실행 후 `Crosswind_FTE_Results/` 폴더에 다음 파일이 생성됩니다:

#### 1. Ground_Track.png
**2D 비행 경로 그래프**
- **검은 점선**: 의도한 직선 경로
- **파란 실선**: 실제 비행 경로
- **빨간 화살표**: 횡풍 방향과 크기
- **초록 원**: 시작점
- **빨간 사각형**: 종료점

**해석**:
- 실제 경로가 의도한 경로에서 얼마나 벗어났는지 시각적으로 확인
- 횡풍에 의해 경로가 동쪽(또는 서쪽)으로 편향됨

#### 2. Lateral_FTE.png
**횡방향 FTE 시간 이력**

**상단 그래프** (Lateral FTE):
- X축: 시간 (초)
- Y축: 횡방향 오차 (미터)
- 양수: 의도한 경로의 오른쪽
- 음수: 의도한 경로의 왼쪽

**하단 그래프** (Absolute FTE):
- X축: 시간 (초)
- Y축: 절대 횡방향 오차 (미터)
- **초록 점선**: RMS (평균 제곱근 오차)
- **자주색 점선**: 95th percentile (상위 5% 제외)

**해석**:
- FTE가 0에 가까울수록 제어 성능이 우수
- RMS 값이 작을수록 전반적인 추적 성능이 좋음
- 95th percentile은 대부분의 경우 발생하는 최대 오차

#### 3. All_Errors.png
**모든 오차 성분**

**3개 그래프**:
1. **횡방향 오차** (Cross-track): FTE
2. **종방향 오차** (Along-track): 경로를 따른 앞/뒤 오차
3. **수직 오차** (Altitude): 고도 유지 오차

**해석**:
- 횡방향이 가장 중요 (횡풍의 직접적 영향)
- 종방향: 속도 제어 성능
- 수직: 고도 유지 성능

#### 4. Crosswind_FTE_Results.mat
**MATLAB 데이터 파일**

```matlab
% 로드 방법
load('Crosswind_FTE_Results/Crosswind_FTE_Results.mat');

% 사용 가능한 데이터
results.parameters       % 시뮬레이션 설정값
results.time            % 시간 배열
results.position_actual % 실제 위치 [N, E, D]
results.position_ref    % 기준 위치 [N, E, D]
results.errors.lateral  % 횡방향 오차
results.statistics      % 통계값
```

#### 5. Crosswind_FTE_Data.xlsx
**Excel 데이터 파일**

| 열 이름 | 설명 |
|---------|------|
| Time_s | 시간 (초) |
| N_actual_m | 실제 북쪽 위치 (m) |
| E_actual_m | 실제 동쪽 위치 (m) |
| D_actual_m | 실제 고도 (m, 음수) |
| N_ref_m | 기준 북쪽 위치 (m) |
| E_ref_m | 기준 동쪽 위치 (m) |
| D_ref_m | 기준 고도 (m, 음수) |
| Lateral_FTE_m | 횡방향 FTE (m) |
| Longitudinal_Error_m | 종방향 오차 (m) |
| Altitude_Error_m | 고도 오차 (m) |

---

## 📐 FTE 계산 원리

### 좌표 변환

#### 1. 의도한 경로가 북쪽 방향 (Heading = 0°)인 경우
```matlab
% 간단한 계산
e_lateral = E_actual - E_ref      % 횡방향 오차 = 동쪽 오차
e_parallel = N_actual - N_ref     % 종방향 오차 = 북쪽 오차
```

#### 2. 일반적인 경우 (임의의 heading)
```matlab
% 경로 정렬 좌표계로 회전
chi_ref = atan2(E_vel, N_vel);    % 경로 방향각

% 위치 오차
dN = N_actual - N_ref;
dE = E_actual - E_ref;

% 경로 정렬 좌표계로 변환
e_parallel =  cos(chi_ref) * dN + sin(chi_ref) * dE;  % 종방향
e_lateral  = -sin(chi_ref) * dN + cos(chi_ref) * dE;  % 횡방향 (FTE)
```

### FTE 통계 지표

#### 1. 최대 절대 오차 (Maximum)
```matlab
max_FTE = max(abs(e_lateral))
```
- 의미: 경로에서 가장 많이 벗어난 거리
- 용도: 최악의 경우 평가

#### 2. RMS 오차 (Root Mean Square)
```matlab
rms_FTE = sqrt(mean(e_lateral.^2))
```
- 의미: 전체 비행 구간의 평균적인 오차
- 용도: 제어기 전반적 성능 평가

#### 3. 95th Percentile
```matlab
p95_FTE = prctile(abs(e_lateral), 95)
```
- 의미: 상위 5%를 제외한 최대 오차
- 용도: 통계적 안전 마진 평가

---

## 🔬 기술적 세부사항

### GUAM 설정

#### RefInput 구조
```matlab
RefInput.Vel_bIc_des  = timeseries(vel, time);   % 기체 좌표계 속도
RefInput.pos_des      = timeseries(pos, time);   % NED 위치
RefInput.chi_des      = timeseries(chi, time);   % 헤딩각
RefInput.chi_dot_des  = timeseries(chid, time);  % 헤딩 변화율
RefInput.vel_des      = timeseries(vel_i, time); % 관성 속도
```

#### Variant 설정
```matlab
userStruct.variants.refInputType = 3;  % TIMESERIES
userStruct.variants.ctrlType = 2;      % BASELINE
```

#### 바람 설정
```matlab
% NED 좌표계에서 바람 벡터
SimInput.Environment.Winds.Vel_wHh = [Wind_N; Wind_E; Wind_D];
```

### 데이터 추출
```matlab
% logsout에서 위치 데이터 추출
logsout = evalin('base', 'logsout');
SimOut = logsout{1}.Values;
pos_data = squeeze(SimOut.Vehicle.EOM.InertialData.Pos_bii.Data);
```

---

## 📊 예상 결과

### 전형적인 FTE 값 (20노트 횡풍, 90노트 속도)

| 지표 | 예상 범위 | 의미 |
|------|-----------|------|
| **Maximum FTE** | 2-5 m | 최대 편차 |
| **RMS FTE** | 1-3 m | 평균 편차 |
| **95th Percentile** | 2-4 m | 통계적 최대값 |

### 결과에 영향을 주는 요인

1. **횡풍 크기** ↑ → FTE ↑
   - 횡풍이 강할수록 경로 유지가 어려움

2. **비행 속도** ↑ → FTE ↓ (일반적으로)
   - 속도가 빠를수록 바람의 상대적 영향 감소

3. **제어기 성능**
   - Baseline LQRi 제어기의 게인 스케줄링 성능

4. **고도**
   - 고도가 높을수록 대기 밀도 감소, 제어 효과 변화

---

## 🎓 학술/기술 활용

### 논문 작성

#### 방법론 서술
```
본 연구에서는 NASA GUAM 시뮬레이터를 활용하여 횡풍 환경에서의
항공기 비행 기술 오차(FTE)를 정량적으로 평가하였다. 1 km 직선
경로에서 90 knots의 대지 속도와 20 knots의 횡풍 조건 하에
GUAM Baseline LQRi 제어기의 성능을 분석하였다.
```

#### 결과 제시
```
시뮬레이션 결과, 횡방향 FTE는 최대 X.XX m, RMS X.XX m로 측정되었으며,
95th percentile은 X.XX m로 나타났다. 이는 Required Navigation
Performance (RNP) X.XX 기준을 만족하는 수치이다.
```

### 기술 보고서

#### 표 작성
| 횡풍 (kt) | 최대 FTE (m) | RMS FTE (m) | 95% FTE (m) |
|-----------|--------------|-------------|-------------|
| 10        | X.XX         | X.XX        | X.XX        |
| 20        | X.XX         | X.XX        | X.XX        |
| 30        | X.XX         | X.XX        | X.XX        |

#### 그래프 인용
- Figure 1: Ground track showing actual vs desired path
- Figure 2: Lateral FTE time history with statistical markers

---

## ⚠️ 문제 해결

### 문제 1: "simSetup를 찾을 수 없습니다"
```matlab
% 해결: 작업 디렉토리 확인
pwd  % /home/user/webapp 인지 확인
cd /home/user/webapp
```

### 문제 2: "QrotZ를 찾을 수 없습니다"
```matlab
% 해결: STARS 라이브러리 경로 추가
addpath(genpath('lib'))
```

### 문제 3: 시뮬레이션이 오류로 중단
```matlab
% 해결: 워크스페이스 초기화
clear all
close all
clc
setupPath
```

### 문제 4: 결과가 이상함 (FTE가 너무 큼/작음)
**확인 사항**:
1. 단위 변환이 올바른지 확인 (knots → m/s)
2. NED 좌표계 부호 확인 (Down은 음수)
3. 바람 방향 설정 확인
4. 시뮬레이션 시간이 충분한지 확인

---

## 🔄 배치 실행 (여러 조건 테스트)

### 다양한 횡풍으로 테스트
```matlab
crosswind_values = [10, 20, 30, 40];  % knots
results_summary = [];

for i = 1:length(crosswind_values)
    % 파라미터 설정
    CROSSWIND_KT = crosswind_values(i);
    
    % 스크립트 실행
    run('Exec_Scripts/exam_Crosswind_FTE_1km.m');
    
    % 결과 저장
    results_summary(i,:) = [CROSSWIND_KT, max_lateral, rms_lateral, p95_lateral];
    
    % 폴더 이름 변경 (덮어쓰기 방지)
    movefile('Crosswind_FTE_Results', sprintf('Crosswind_FTE_Results_%dkt', CROSSWIND_KT));
end

% 결과 표시
results_table = array2table(results_summary, ...
    'VariableNames', {'Crosswind_kt', 'Max_FTE_m', 'RMS_FTE_m', 'P95_FTE_m'});
disp(results_table);
```

### 다양한 속도로 테스트
```matlab
ground_speeds = [60, 80, 100, 120];  % knots
% (위와 유사한 루프)
```

---

## 📚 추가 참고 자료

### GUAM 문서
- `README.md` - GUAM 전체 개요
- `Exec_Scripts/exam_TS_Hover2Cruise_traj.m` - Timeseries 입력 예제
- `setup/setupWinds.m` - 바람 설정 방법

### 관련 개념
- **RNP (Required Navigation Performance)**: 항법 성능 요구사항
- **FTE (Flight Technical Error)**: 비행 기술 오차
- **TSE (Total System Error)**: 전체 시스템 오차 (FTE + NSE + PDE)
- **LQRi Controller**: Linear Quadratic Regulator with Integrator

---

## 💡 팁

### 빠른 검증
```matlab
% 간단한 테스트 (짧은 거리)
SEGMENT_LENGTH_M = 500;  % 500m
TIME_MARGIN_S = 5;       % 짧은 시간
```

### 고해상도 그래프 저장
```matlab
% 스크립트 끝에 추가
set(gcf, 'PaperPositionMode', 'auto');
print('Ground_Track_HighRes', '-dpng', '-r300');  % 300 DPI
```

### 결과 비교
```matlab
% 두 개의 결과 로드
load('Crosswind_FTE_Results_20kt/Crosswind_FTE_Results.mat', 'results');
results_20kt = results;
load('Crosswind_FTE_Results_30kt/Crosswind_FTE_Results.mat', 'results');
results_30kt = results;

% 비교
fprintf('20kt: Max FTE = %.2f m\n', results_20kt.statistics.lateral_max_m);
fprintf('30kt: Max FTE = %.2f m\n', results_30kt.statistics.lateral_max_m);
```

---

## 📞 요약

### 가장 중요한 명령어
```matlab
cd /home/user/webapp && run('Exec_Scripts/exam_Crosswind_FTE_1km.m')
```

### 핵심 결과
- **Lateral_FTE.png**: 횡방향 오차 그래프 (가장 중요!)
- **Ground_Track.png**: 비행 경로 시각화
- **Crosswind_FTE_Data.xlsx**: 상세 데이터

### 주요 통계
- Maximum FTE: 최악의 경우
- RMS FTE: 평균 성능
- 95th Percentile: 통계적 안전 마진

---

**문서 버전**: 1.0  
**최종 업데이트**: 2025-11-18  
**작성자**: GUAM Safety Analysis Team
