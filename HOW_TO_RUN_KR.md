# 실행 방법 - 안전 봉투 구현

## 📍 중요: 실행 위치

### ✅ 올바른 방법 (2가지)

#### 방법 1: GUAM 루트에서 실행 (추천)
```matlab
% MATLAB에서:
cd /home/user/webapp           % GUAM 루트로 이동
run('Exec_Scripts/exam_Paper_Safety_Envelope_Implementation.m')
```

#### 방법 2: Exec_Scripts 폴더에서 실행
```matlab
% MATLAB에서:
cd /home/user/webapp/Exec_Scripts
exam_Paper_Safety_Envelope_Implementation
```

**스크립트가 자동으로 GUAM 루트로 이동**합니다!

---

## 🔧 스크립트 동작 원리

### 자동 경로 설정
스크립트 시작 부분에서:
```matlab
% 현재 스크립트 위치 찾기
script_dir = fileparts(mfilename('fullpath'));

% GUAM 루트로 이동 (상위 폴더)
guam_root = fileparts(script_dir);
cd(guam_root);

% simSetup.m을 찾을 수 있게 됨
simSetup;
```

### 왜 이렇게 하나요?

**GUAM 구조**:
```
/home/user/webapp/           ← GUAM 루트 (simSetup.m 여기 있음)
├── simSetup.m              ← 필수 파일
├── GUAM.slx                ← Simulink 모델
├── simInit.m
├── vehicles/
└── Exec_Scripts/           ← 실행 스크립트 폴더
    └── exam_Paper_Safety_Envelope_Implementation.m
```

**문제**:
- `simSetup.m`은 GUAM 루트에 있음
- 우리 스크립트는 `Exec_Scripts/` 폴더에 있음
- MATLAB은 현재 폴더에서 파일을 찾음

**해결**:
- 스크립트가 자동으로 GUAM 루트로 이동
- `simSetup` 호출 가능
- 시뮬레이션 실행 가능

---

## 📁 결과 파일 저장 위치

### 모든 파일은 **GUAM 루트**에 저장됨:

```
/home/user/webapp/
├── Safety_Envelope_Results.csv    ← 계산 결과
├── Safety_Envelope_Results.mat    ← MATLAB 워크스페이스
├── simSetup.m
└── Exec_Scripts/
    └── exam_Paper_Safety_Envelope_Implementation.m
```

### 파일 확인:
```matlab
% MATLAB에서:
ls /home/user/webapp/Safety_Envelope_Results.*
```

또는 Linux에서:
```bash
cd /home/user/webapp
ls -lh Safety_Envelope_Results.*
```

---

## 🚀 완전한 실행 예시

### 터미널에서 MATLAB 시작:
```bash
cd /home/user/webapp
matlab -nodesktop -nosplash
```

### MATLAB 명령창에서:
```matlab
% 방법 1: 직접 실행
run('Exec_Scripts/exam_Paper_Safety_Envelope_Implementation.m')

% 방법 2: 폴더 이동 후 실행
cd Exec_Scripts
exam_Paper_Safety_Envelope_Implementation

% 작업 디렉토리 확인
pwd
% 출력: /home/user/webapp  ← 자동으로 이동됨

% 결과 파일 확인
dir('Safety_Envelope_Results.*')
```

---

## 🔍 실행 중 출력 확인

### 첫 줄에서 위치 확인:
```
═══════════════════════════════════════════════════════════════
  Safety Envelope Implementation (Paper-Based)
  Chinese Journal of Aeronautics, 2016
═══════════════════════════════════════════════════════════════

  Working directory: /home/user/webapp    ← 이 줄 확인!

╔═══════════════════════════════════════════════════════════╗
║  Testing Cruise Speed: 80 knots (135.0 ft/s)              
╚═══════════════════════════════════════════════════════════╝
```

**"Working directory: /home/user/webapp"**가 보이면 정상입니다!

---

## ❌ 문제 해결

### 문제 1: "Undefined function or variable 'simSetup'"

**원인**: 스크립트가 GUAM 루트를 찾지 못함

**해결**:
```matlab
% GUAM 루트로 수동 이동
cd /home/user/webapp
pwd  % 확인

% 다시 실행
run('Exec_Scripts/exam_Paper_Safety_Envelope_Implementation.m')
```

### 문제 2: "Cannot open model 'GUAM'"

**원인**: Simulink 모델을 찾지 못함

**해결**:
```matlab
% GUAM 루트에 있는지 확인
pwd
% 출력이 /home/user/webapp이어야 함

% 모델 파일 확인
ls GUAM.slx

% 없으면 GUAM 루트로 이동
cd /home/user/webapp
```

### 문제 3: 결과 파일을 찾을 수 없음

**확인**:
```matlab
% 현재 작업 디렉토리
pwd

% GUAM 루트에서 찾기
cd /home/user/webapp
dir('Safety_Envelope_Results.*')

% 파일이 있으면:
% Safety_Envelope_Results.csv
% Safety_Envelope_Results.mat
```

---

## 📝 다른 GUAM 스크립트와의 차이

### 기존 GUAM 예제들:
```
/home/user/webapp/Exec_Scripts/
├── exam_Hover.m
├── exam_Cruise.m
└── exam_TS_Cruise_Climb_Turn_traj.m
```

**이 스크립트들의 실행 방법**:
```matlab
% GUAM 루트에서 실행해야 함
cd /home/user/webapp
run('Exec_Scripts/exam_Hover.m')
```

### 우리 스크립트:
```
/home/user/webapp/Exec_Scripts/
└── exam_Paper_Safety_Envelope_Implementation.m
```

**장점: 어디서든 실행 가능!**
```matlab
% Exec_Scripts 폴더에서 실행해도 됨
cd /home/user/webapp/Exec_Scripts
exam_Paper_Safety_Envelope_Implementation
% → 자동으로 GUAM 루트로 이동됨

% 또는 GUAM 루트에서 실행
cd /home/user/webapp
run('Exec_Scripts/exam_Paper_Safety_Envelope_Implementation.m')
```

---

## 💡 왜 Exec_Scripts 폴더를 사용하나요?

### GUAM의 표준 구조:
- **루트 폴더**: 핵심 파일 (simSetup.m, GUAM.slx 등)
- **Exec_Scripts/**: 실행 스크립트 모음
- **vehicles/**: 항공기 설정
- **utilities/**: 유틸리티 함수

### 장점:
1. ✅ 깔끔한 구조 유지
2. ✅ 다른 GUAM 예제와 일관성
3. ✅ 여러 테스트 스크립트 관리 용이
4. ✅ GUAM 핵심 파일과 분리

---

## 🎯 요약

### ✅ 실행 방법 (2가지 모두 OK):

1. **GUAM 루트에서**:
   ```matlab
   cd /home/user/webapp
   run('Exec_Scripts/exam_Paper_Safety_Envelope_Implementation.m')
   ```

2. **Exec_Scripts 폴더에서**:
   ```matlab
   cd /home/user/webapp/Exec_Scripts
   exam_Paper_Safety_Envelope_Implementation
   ```

### ✅ 스크립트가 자동으로:
- GUAM 루트로 이동
- simSetup 실행
- 시뮬레이션 수행
- 결과를 GUAM 루트에 저장

### ✅ 결과 파일 위치:
```
/home/user/webapp/
├── Safety_Envelope_Results.csv
└── Safety_Envelope_Results.mat
```

### ✅ 확인:
```matlab
pwd  % /home/user/webapp 출력되어야 함
ls Safety_Envelope_Results.*  % 파일 목록 확인
```

---

**이제 어디서든 실행 가능합니다!** 🚀
