# 🚀 빠른 시작 가이드

## 📌 한 줄 요약
**MATLAB에서 이 명령어 하나만 실행하세요!**

```matlab
cd /home/user/webapp && run('Exec_Scripts/exam_Paper_DETAILED_Report.m')
```

---

## ⚡ 3단계로 시작하기

### 1️⃣ MATLAB 열고 디렉토리 이동
```matlab
cd /home/user/webapp
```

### 2️⃣ 스크립트 실행
```matlab
run('Exec_Scripts/exam_Paper_DETAILED_Report.m')
```

### 3️⃣ 결과 확인
```matlab
ls Safety_Envelope_Report/
```

**끝!** ✅

---

## 📂 어떤 결과가 나오나요?

실행하면 `Safety_Envelope_Report/` 폴더가 생성되고 3개 파일이 들어있습니다:

### 1. `Detailed_Report.txt` 📄
모든 계산 과정이 단계별로 기록됨:
```
====================================================================
Step 1.3.1: Test Flight at 60 knots
====================================================================

Step 1.3.1.1: Unit Conversion
  Formula: V_fps = V_knots × 1.68781
  Calculation: 60.0 knots × 1.68781 = 101.27 ft/s
  Formula: V_m/s = V_fps × 0.3048
  Calculation: 101.27 ft/s × 0.3048 = 30.87 m/s

Step 1.3.1.2: Simulation Setup
  Aircraft model: GUAM Lift+Cruise
  Input method: Timeseries (refInputType=3)
  ...
```

### 2. `Detailed_Analysis_Data.xlsx` 📊
엑셀 파일 (2개 시트):
- **Sheet 1 (Performance_Data)**: 4개 테스트 결과 표
- **Sheet 2 (Envelope_Parameters)**: 계산된 봉투 값들 + 공식

### 3. `Analysis_Workspace.mat` 💾
MATLAB 변수들 저장 (나중에 재사용 가능)

---

## 🎯 다른 실행 옵션들

### 옵션 A: 기본 구현 (빠름 2-3분)
```matlab
run('Exec_Scripts/exam_Paper_Safety_Envelope_Implementation.m')
```
**결과**: 3D 그래프 + 충돌 확률 맵

### 옵션 B: 올바른 5단계 흐름 (8-15분)
```matlab
run('Exec_Scripts/exam_Paper_CORRECT_Flow.m')
```
**결과**: 성능측정 → 봉투계산 → 경로계획 → 검증

### 옵션 C: 현실적 동적 시뮬레이션 (3-5분)
```matlab
run('Exec_Scripts/exam_Paper_Safety_Envelope_REALISTIC.m')
```
**결과**: 90초 비행 + 회전 + 시간변화 그래프

### 옵션 D: 상세 보고서 (5-10분) ⭐ **추천**
```matlab
run('Exec_Scripts/exam_Paper_DETAILED_Report.m')
```
**결과**: 모든 계산 + 공식 + 설명 + 엑셀

---

## ⚠️ 문제가 생기면?

### "simSetup를 찾을 수 없습니다"
```matlab
% 해결: 디렉토리 확인
pwd  % /home/user/webapp 인지 확인
cd /home/user/webapp  % 아니면 이동
```

### "QrotZ를 찾을 수 없습니다"
```matlab
% 해결: 라이브러리 경로 추가
addpath(genpath('lib'))
```

### 시뮬레이션이 멈춤
```matlab
% 해결: 초기화 후 재실행
clear all
close all
clc
run('Exec_Scripts/exam_Paper_DETAILED_Report.m')
```

---

## 📊 결과 확인 방법

### 텍스트 파일 보기
```matlab
type Safety_Envelope_Report/Detailed_Report.txt
```

### 엑셀 파일 열기
```matlab
winopen('Safety_Envelope_Report/Detailed_Analysis_Data.xlsx')
```

### MATLAB에서 데이터 읽기
```matlab
data = readtable('Safety_Envelope_Report/Detailed_Analysis_Data.xlsx');
disp(data)
```

### 저장된 변수 불러오기
```matlab
load('Safety_Envelope_Report/Analysis_Workspace.mat')
whos  % 모든 변수 확인
```

---

## 🎓 논문에 사용하려면?

### 주요 결과 추출
```matlab
% 1. 보고서 생성
run('Exec_Scripts/exam_Paper_DETAILED_Report.m')

% 2. 변수 로드
load('Safety_Envelope_Report/Analysis_Workspace.mat')

% 3. 주요 값 출력
fprintf('최대 전진 속도: %.2f m/s (%.1f knots)\n', V_f, V_f/0.514444);
fprintf('안전 봉투 반경: %.2f m\n', r_eq);
fprintf('봉투 부피: %.0f m³\n', V_envelope);
```

### 그래프 저장 (고해상도)
```matlab
saveas(gcf, 'Figure_for_Paper.png')  % PNG
saveas(gcf, 'Figure_for_Paper.eps')  % EPS (논문용)
```

---

## 📚 더 자세한 설명이 필요하면?

| 문서 | 내용 |
|------|------|
| `실행방법.md` | 완전한 실행 가이드 |
| `DETAILED_REPORT_GUIDE_KR.md` | 보고서 가이드 |
| `CORRECT_FLOW_KR.md` | 방법론 설명 |
| `PROJECT_COMPLETION_SUMMARY.md` | 전체 프로젝트 요약 |

---

## 💡 자주 하는 질문

**Q: 얼마나 걸리나요?**  
A: 5-10분 정도 (컴퓨터 성능에 따라)

**Q: 결과를 어디에 쓸 수 있나요?**  
A: 학술 논문, 기술 문서, 안전 인증 자료 등

**Q: 다른 속도로 테스트하려면?**  
A: 스크립트 내부의 `test_speeds` 변수를 수정하세요

**Q: 오류가 나면?**  
A: `ERROR_FIX_KR.md` 파일을 참고하세요

**Q: 계산 공식이 맞나요?**  
A: 네, 논문의 Eq. 1-23을 정확히 구현했습니다

---

## ✅ 체크리스트

실행 전:
- [ ] MATLAB 실행됨
- [ ] `/home/user/webapp` 디렉토리에 있음
- [ ] GUAM 파일들 존재 확인

실행 후:
- [ ] `Safety_Envelope_Report/` 폴더 생성됨
- [ ] 3개 파일 모두 생성됨
- [ ] 그래프가 표시됨
- [ ] 오류 없이 완료됨

---

## 🎯 한 줄 명령어 (복사해서 붙여넣기)

```matlab
cd /home/user/webapp && run('Exec_Scripts/exam_Paper_DETAILED_Report.m')
```

**이게 전부입니다!** 🎉

---

## 📞 도움이 필요하면?

1. `실행방법.md` - 상세한 실행 가이드
2. `ERROR_FIX_KR.md` - 오류 해결 방법
3. `PROJECT_COMPLETION_SUMMARY.md` - 전체 프로젝트 설명

**Pull Request**: https://github.com/moonjang0701/Generic-Urban-Air-Mobility-GUAM/pull/2

---

**마지막 업데이트**: 2025-11-18  
**버전**: 1.0  
**상태**: ✅ 테스트 완료
