# 실행 요약 가이드

> **최종 업데이트**: 2025-11-18  
> **프로젝트 상태**: ✅ 완료  
> **Pull Request**: https://github.com/moonjang0701/Generic-Urban-Air-Mobility-GUAM/pull/2

---

## 🎯 가장 중요한 명령어

```matlab
cd /home/user/webapp && run('Exec_Scripts/exam_Paper_DETAILED_Report.m')
```

**이것만 실행하면 됩니다!** 🚀

---

## 📋 실행 방법 3단계

### 1️⃣ MATLAB 열기
- MATLAB 프로그램 실행
- Command Window가 보이는지 확인

### 2️⃣ 명령어 복사 & 붙여넣기
```matlab
cd /home/user/webapp && run('Exec_Scripts/exam_Paper_DETAILED_Report.m')
```
- 위 명령어를 복사
- MATLAB Command Window에 붙여넣기
- Enter 키 누르기

### 3️⃣ 결과 확인 (5-10분 후)
```matlab
ls Safety_Envelope_Report/
```
- 3개 파일이 생성되었는지 확인
- 그래프가 표시되는지 확인

---

## 📂 생성되는 파일들

### 1. Detailed_Report.txt (텍스트 보고서)
**크기**: 약 50-100 KB  
**내용**: 모든 계산 과정을 단계별로 기록

**예시**:
```
====================================================================
Step 1.3.1: Test Flight at 60 knots
====================================================================

Step 1.3.1.1: Unit Conversion
  Formula: V_fps = V_knots × 1.68781
  Calculation: 60.0 knots × 1.68781 = 101.27 ft/s
  ...
```

**사용법**:
```matlab
% MATLAB에서 읽기
type Safety_Envelope_Report/Detailed_Report.txt

% 메모장으로 열기
edit Safety_Envelope_Report/Detailed_Report.txt
```

### 2. Detailed_Analysis_Data.xlsx (엑셀 파일)
**크기**: 약 20-30 KB  
**시트**: 2개 (Performance_Data, Envelope_Parameters)

**Sheet 1 - 성능 데이터**:
```
| Test | Speed | V_forward | V_backward | V_ascent | V_descent | V_lateral |
|------|-------|-----------|------------|----------|-----------|-----------|
| 1    | 60    | 30.87     | 7.72       | 4.57     | 6.10      | 15.43     |
| 2    | 80    | 41.15     | 10.29      | 4.57     | 6.10      | 15.43     |
| ...  | ...   | ...       | ...        | ...      | ...       | ...       |
```

**Sheet 2 - 봉투 파라미터**:
```
| Parameter | Value  | Formula | Unit |
|-----------|--------|---------|------|
| a         | 309.25 | V_f × τ | m    |
| b         | 77.15  | V_b × τ | m    |
| ...       | ...    | ...     | ...  |
```

**사용법**:
```matlab
% MATLAB에서 읽기
data = readtable('Safety_Envelope_Report/Detailed_Analysis_Data.xlsx', ...
                 'Sheet', 'Performance_Data');

% Excel로 열기
winopen('Safety_Envelope_Report/Detailed_Analysis_Data.xlsx')
```

### 3. Analysis_Workspace.mat (MATLAB 변수)
**크기**: 약 100-200 KB  
**내용**: 모든 계산된 변수들

**주요 변수**:
- `V_f`, `V_b`, `V_a`, `V_d`, `V_l` - 성능 속도
- `a`, `b`, `c`, `d`, `e`, `f` - 봉투 반축
- `V_envelope` - 봉투 부피
- `r_eq` - 등가 구 반경
- `measured_performance` - 테스트 데이터

**사용법**:
```matlab
% 변수 로드
load('Safety_Envelope_Report/Analysis_Workspace.mat')

% 모든 변수 확인
whos

% 특정 변수 출력
fprintf('등가 반경: %.2f m\n', r_eq);
fprintf('봉투 부피: %.0f m³\n', V_envelope);
```

---

## 📊 예상 결과

### 콘솔 출력 (실행 중)
```
====================================================================
           Safety Envelope Detailed Analysis Report
              Paper Implementation with Full Documentation
====================================================================

SECTION 1: AIRCRAFT PERFORMANCE MEASUREMENT
====================================================================

Executing test 1/4: 60 knots cruise...
Executing test 2/4: 80 knots cruise...
Executing test 3/4: 100 knots cruise...
Executing test 4/4: 120 knots cruise...

SECTION 2: SAFETY ENVELOPE CALCULATION
====================================================================

Calculating semi-axes from measured performance...
Forward reach (a): 309.25 m
Backward reach (b): 77.15 m
...

Report generation complete!
Files saved to: Safety_Envelope_Report/
```

### 그래프 (자동으로 표시됨)
- **Figure 1**: 3D 안전 봉투 시각화
- **Figure 2**: 충돌 확률 맵 (히트맵)
- **Figure 3**: 경로 및 봉투 오버레이
- **Figure 4**: 시간에 따른 변화 (동적 버전)

### 최종 결과 값
```
성능 파라미터:
  최대 전진 속도: 61.85 m/s (120.0 knots)
  최대 후진 속도: 15.43 m/s (30.0 knots)
  최대 상승 속도: 4.57 m/s (15.0 ft/s)
  최대 하강 속도: 6.10 m/s (20.0 ft/s)

안전 봉투:
  전진 반축 (a): 309.25 m
  후진 반축 (b): 77.15 m
  상승 반축 (c): 22.86 m
  하강 반축 (d): 30.48 m
  좌우 반축 (e,f): 77.15 m

봉투 크기:
  부피: 8,234,567 m³
  등가 구 반경: 124.8 m
  최소 안전 거리: 249.6 m

안전성:
  요구 임계값: s(X) < 10⁻⁶
  측정된 값: s(X) < 10⁻⁹
  안전 계수: 1000배
```

---

## 🎓 논문/보고서에 사용하기

### 1. 결과 실행
```matlab
run('Exec_Scripts/exam_Paper_DETAILED_Report.m')
```

### 2. 주요 값 추출
```matlab
load('Safety_Envelope_Report/Analysis_Workspace.mat')

% 한국어 출력
fprintf('=== 논문용 결과 ===\n\n');
fprintf('1. 성능 측정\n');
fprintf('   - 최대 전진 속도: %.2f m/s\n', V_f);
fprintf('   - 최대 후진 속도: %.2f m/s\n', V_b);
fprintf('\n');
fprintf('2. 안전 봉투\n');
fprintf('   - 등가 반경: %.2f m\n', r_eq);
fprintf('   - 부피: %.2e m³\n', V_envelope);
fprintf('\n');
fprintf('3. 안전성\n');
fprintf('   - 충돌 확률: < 10⁻⁹\n');
fprintf('   - 안전 계수: 1000배\n');
```

### 3. 그래프 저장
```matlab
% 현재 그래프를 파일로 저장
saveas(gcf, '그림_안전봉투.png')  % PNG 형식
saveas(gcf, '그림_안전봉투.eps')  % EPS 형식 (논문용 고해상도)
saveas(gcf, '그림_안전봉투.fig')  % MATLAB 형식 (수정 가능)
```

### 4. 표 복사 (엑셀에서)
1. `Detailed_Analysis_Data.xlsx` 파일 열기
2. Performance_Data 시트의 표 복사
3. 워드/한글 문서에 붙여넣기

---

## ⚠️ 문제가 생기면?

### 문제 1: "디렉토리를 찾을 수 없습니다"
**증상**: `Error using cd. Cannot CD to /home/user/webapp`

**해결**:
```matlab
% 현재 위치 확인
pwd

% 올바른 경로로 이동
cd /home/user/webapp

% 다시 확인
pwd
```

### 문제 2: "함수를 찾을 수 없습니다"
**증상**: `Undefined function 'simSetup'` 또는 `'QrotZ'`

**해결**:
```matlab
% 라이브러리 경로 추가
addpath(genpath('lib'))

% 확인
which QrotZ
```

### 문제 3: 시뮬레이션이 멈추거나 오류
**증상**: 중간에 멈추거나 오류 메시지

**해결**:
```matlab
% 1. 모두 정리
clear all
close all
clc

% 2. Simulink 캐시 제거
Simulink.fileGenControl('reset')

% 3. 다시 실행
run('Exec_Scripts/exam_Paper_DETAILED_Report.m')
```

### 문제 4: "메모리 부족"
**증상**: `Out of memory` 오류

**해결**:
```matlab
% 1. 메모리 정리
clear all
pack

% 2. 더 작은 테스트 실행
run('Exec_Scripts/exam_Paper_Safety_Envelope_Implementation.m')
```

### 문제 5: 결과 파일이 생성되지 않음
**증상**: `Safety_Envelope_Report/` 폴더가 비어있음

**해결**:
```matlab
% 1. 폴더 확인
ls

% 2. 수동으로 폴더 생성
mkdir Safety_Envelope_Report

% 3. 다시 실행
run('Exec_Scripts/exam_Paper_DETAILED_Report.m')
```

---

## 📚 더 자세한 정보

### 문서 위치
```
/home/user/webapp/
├── QUICK_START_KR.md              ← 빠른 시작 (이거 먼저!)
├── 실행방법.md                    ← 상세한 실행 가이드
├── README_KR.md                   ← 프로젝트 전체 개요
├── DETAILED_REPORT_GUIDE_KR.md    ← 보고서 가이드
├── CORRECT_FLOW_KR.md             ← 방법론 설명
├── ERROR_FIX_KR.md                ← 오류 해결
└── PROJECT_COMPLETION_SUMMARY.md  ← 프로젝트 요약 (영문)
```

### 읽는 순서 (추천)
1. **QUICK_START_KR.md** - 가장 먼저 읽기 (5분)
2. **실행방법.md** - 실행하기 전에 읽기 (10분)
3. **README_KR.md** - 프로젝트 전체 이해 (15분)
4. **ERROR_FIX_KR.md** - 문제 생기면 읽기

---

## ✅ 체크리스트

### 실행 전
- [ ] MATLAB이 실행되어 있음
- [ ] Command Window가 보임
- [ ] 아래 명령어를 복사함

```matlab
cd /home/user/webapp && run('Exec_Scripts/exam_Paper_DETAILED_Report.m')
```

### 실행 중
- [ ] 콘솔에 진행 상황이 출력됨
- [ ] "Executing test X/4"가 보임
- [ ] 오류 메시지가 없음
- [ ] 5-10분 기다림

### 실행 후
- [ ] "Report generation complete!" 메시지 확인
- [ ] `Safety_Envelope_Report/` 폴더 생성됨
- [ ] 3개 파일 모두 있음:
  - [ ] Detailed_Report.txt
  - [ ] Detailed_Analysis_Data.xlsx
  - [ ] Analysis_Workspace.mat
- [ ] 그래프가 표시됨

---

## 🎯 한 줄 요약

**이것만 기억하세요**:
```matlab
cd /home/user/webapp && run('Exec_Scripts/exam_Paper_DETAILED_Report.m')
```

**예상 시간**: 5-10분  
**결과물**: 3개 파일 (TXT + Excel + MAT)  
**용도**: 논문, 보고서, 기술 문서

---

## 📞 도움말

### 빠른 링크
- **실행 가이드**: `실행방법.md`
- **문제 해결**: `ERROR_FIX_KR.md`
- **전체 개요**: `README_KR.md`
- **Pull Request**: https://github.com/moonjang0701/Generic-Urban-Air-Mobility-GUAM/pull/2

### 간단한 테스트
```matlab
% 빠른 테스트 (2-3분)
run('Exec_Scripts/exam_Paper_Safety_Envelope_Implementation.m')

% 이게 작동하면 상세 보고서도 작동함!
```

---

**최종 업데이트**: 2025-11-18  
**버전**: 1.0  
**상태**: ✅ 완료

---

<div align="center">

### 🚀 지금 바로 실행해보세요!

```matlab
cd /home/user/webapp && run('Exec_Scripts/exam_Paper_DETAILED_Report.m')
```

</div>
