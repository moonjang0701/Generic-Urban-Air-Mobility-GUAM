# UAM 절차설계 기준 R&D 시스템

## 🎯 프로젝트 목적

NASA GUAM 시뮬레이션을 활용하여 **Urban Air Mobility (UAM)용 절차설계 기준**을 정량적으로 도출하는 R&D 시스템입니다.

### 핵심 연구 질문

1. **UAM 이·착륙 각도 기준은?** → 상승각/강하각의 통계적 분포로부터 도출
2. **회랑(corridor) 폭은 얼마나?** → TSE 분석을 통한 95%/99% 포함 기준
3. **선회 보호공역은?** → 뱅크각 제한, 선회반경, lateral overshoot 분석
4. **비정상 상황 대응은?** → 고장/장애물 시나리오에서 안전마진 검증

---

## 🏗️ 시스템 구조

### Phase 0: 시나리오 분류 및 카탈로그 생성

**목표:** GUAM Challenge Problem 3000개 시나리오를 체계적으로 분류

**분류 기준:**
- 궤적 유형: 직선/완만한 선회/급격한 선회
- 수직 프로파일: 상승/수평/하강
- 절차 스타일: 접근/이륙/순항
- 고장 유무: 정상/비정상
- 장애물 유무: 없음/정적/동적

**출력:**
- `scenario_catalog.mat` - 3000개 시나리오 분류 데이터베이스
- 분포도 및 통계 리포트

---

### Phase 1: 정상 시나리오 기준선 확보

**목표:** 고장 없는 정상 운항에서 기체 성능 한계 파악

**분석 항목:**
- **상승각(Climb Angle):** 평균, 95백분위수, 최대값
- **강하각(Descent Angle):** 평균, 95백분위수, 최대값
- **뱅크각(Bank Angle):** 평균, 95백분위수, 최대값 → 승객 쾌적성 고려
- **선회반경(Turn Radius):** 최소값, 5/10백분위수 → 최소 설계 기준

**출력:**
- 기준선 통계표 (CSV)
- 분포 히스토그램
- 권장 설계 기준 초안

**예상 결과:**
```
권장 최대 상승각:  12° (95백분위수 기준)
권장 최대 강하각:   6° (95백분위수 기준)
권장 최대 뱅크각:  25° (쾌적성 한계)
최소 선회반경:    500m (10백분위수 기준)
```

---

### Phase 2: TSE 모델링 및 Monte Carlo 시뮬레이션

**목표:** Total System Error (TSE) 분포를 통한 회랑 폭 결정

#### TSE 정의

```
TSE = √(FTE² + NSE²)

FTE (Flight Technical Error):
  - 조종/제어 오차
  - GUAM 시뮬레이션에서 실제 궤적과 이상 경로의 차이로 측정

NSE (Navigation System Error):
  - GNSS/항법 오차
  - RNP 기반 모델 (예: RNP 0.3 → 2σ = 0.3NM = 556m)
```

#### Monte Carlo 방법

1. GUAM 궤적을 "진실(truth)" 경로로 사용
2. 경로 좌표계 변환: (along-track s, cross-track e, height h)
3. FTE: 측정된 추적 오차 + 추가 변동
4. NSE: RNP 기반 가우시안 노이즈
5. N=100~1000 샘플 실행
6. 95%/99% 포함 → 회랑 폭 도출

**출력:**
- Lateral TSE 95%/99% 분포
- Vertical TSE 95%/99% 분포
- 회랑 폭 권장값 (안전마진 포함)

**예상 결과:**
```
Lateral TSE (95%):  45m  →  회랑 폭: 108m (양쪽 + 20% 안전마진)
Vertical TSE (95%): 29m  →  고도 버퍼: ±35m
선회 구간 splay:    +50% →  회랑 폭: 162m (선회 시)
```

---

### Phase 3: 비정상 시나리오 검증

**목표:** 고장/장애물 상황에서 기준의 충분성 검증

**시나리오:**
- Effector failure (조종면/추진기 고장)
- Propulsor limiting (추진력 제한)
- Static obstacle (건물, 지형)
- Moving obstacle (타 항공기)

**분석:**
1. 고장 시나리오에서 GUAM 실행
2. TSE 재계산 (성능 저하 반영)
3. 최대 lateral/vertical deviation 측정
4. 기준 회랑 폭 내 포함 여부 확인

**검증 기준:**
- 95% 이상 시나리오가 회랑 내 포함
- 99% 시나리오가 회랑 + 추가 마진 내 포함
- Missed approach 성공률 >99%

**출력:**
- 비정상 상황 안전마진 (추가 +X%)
- 고장별 회랑 폭 조정안
- 장애물 회피 최소 간격

---

### Phase 4: 절차설계 기준 환산 및 문서화

**목표:** 전체 분석을 종합하여 UAM 절차설계 표준 문서 작성

#### 문서 구성

**1. 이·착륙 각도 기준**
```
- 권장 최대 상승각: X° (근거: N개 시나리오 95백분위수)
- 권장 최대 강하각: Y° (근거: N개 시나리오 95백분위수)
- 절대 최대값: Z° (기체 성능 한계)
```

**2. 선회 및 뱅크 기준**
```
- 최소 선회반경: Rm (근거: 5백분위수, 안전마진 포함)
- 권장 선회반경: Rr (근거: 10백분위수)
- 최대 뱅크각: φ° (쾌적성 고려, 30° 이하 권장)
- 선회 구간 보호폭: W_turn = W_straight + splay
```

**3. 회랑 폭 및 보호공역**
```
- 직선 구간 회랑 폭: W meters (95% TSE 기준)
- 선회 구간 회랑 폭: W + ΔW meters (splay 추가)
- 수직 보호 버퍼: ±V meters (vertical TSE 기준)
- 장애물 최소 간격: D meters (충돌 회피)
```

**4. TSE 모델**
```
- FTE 구성: σ_FTE = X m (측정값)
- NSE 구성: RNP 0.3 기반, σ_NSE = Y m
- 바람/난류: 추가 σ_wind (mild/moderate)
- Monte Carlo 검증: N=1000 샘플
```

**5. 비정상 상황 기준**
```
- 단일 고장 시 추가 마진: +Z%
- 장애물 회피 시 최소 간격: D meters
- Missed approach 회랑 폭: W_MA meters
```

**6. 요약 테이블**

| 파라미터 | 권장값 | 최대/최소값 | 근거 |
|---------|--------|------------|------|
| 상승각 | 12° | 15° | 95%ile, 3000 scenarios |
| 강하각 | 6° | 8° | 95%ile, 3000 scenarios |
| 뱅크각 | 25° | 30° | 쾌적성 한계 |
| 선회반경 | 500m | 300m | 10%ile/5%ile |
| 회랑 폭 (직선) | 110m | - | TSE 95% + margin |
| 회랑 폭 (선회) | 165m | - | TSE 95% + splay |
| 고도 버퍼 | ±35m | - | TSE vertical 95% |

---

## 🔬 핵심 기술

### 1. 경로 좌표계 변환

GUAM NED 궤적 → (s, e, h) 좌표계

```matlab
% GUAM 출력: North, East, Down (m)
path_coords = traj_to_path_coords(trajectory_data);

% 출력:
%   s: along-track distance (경로를 따라 진행한 거리)
%   e: cross-track error (좌우 편차)
%   h: height error (고도 편차)
```

**용도:** TSE 계산의 기준, e가 lateral deviation

---

### 2. 비행 각도 계산

```matlab
angles = compute_flight_angles(trajectory_data);

% 출력:
%   flight_path_angle: γ = arctan(dh/ds)
%   climb_angle: 양의 γ 값
%   descent_angle: 음의 γ 값 (절댓값)
%   bank_angle: φ (자세 또는 추정)
%   turn_rate: dψ/dt (deg/s)
```

**용도:** 상승/강하각 통계, 뱅크 제한 분석

---

### 3. 선회 성능 분석

```matlab
turn_metrics = compute_turn_metrics(trajectory_data);

% 출력:
%   turns: 각 선회 구간 정보 (반경, 뱅크각, overshoot)
%   statistics: 전체 선회 통계
%   protection_area: 필요 보호폭 (lateral splay)
```

**알고리즘:**
- 선회 감지: heading rate 또는 bank angle 임계값
- 원 피팅: 선회 중심 및 반경 계산
- Cross-track deviation: 이상 원호와의 거리

**용도:** 최소 선회반경, 선회 구간 보호폭

---

### 4. TSE Monte Carlo 시뮬레이션

```matlab
TSE_results = compute_TSE(trajectory_data, path_coords, ...
    'N_MC', 100, ...
    'RNP_Value', 0.3, ...
    'FTE_Model', 'measured', ...
    'NSE_Model', 'RNP', ...
    'Wind_Model', 'none');

% 출력:
%   lateral.percentile_95: 95% lateral TSE
%   lateral.percentile_99: 99% lateral TSE
%   corridor_width.width_95: 권장 회랑 폭
%   recommended.corridor_width: 안전마진 포함
```

**Monte Carlo 과정:**
1. 각 시간 스텝에서 NSE 샘플링 (가우시안)
2. FTE에 추가 변동 적용
3. TSE = √(FTE² + NSE²) 계산
4. N_MC 샘플에 대해 반복
5. 95%/99% 백분위수 추출

**용도:** 회랑 폭 정량화 (핵심!)

---

## 📊 예상 출력 예시

### Phase 1 출력 (Baseline)

```
📐 상승각 기준:
   권장 최대:  12° (95백분위수)
   절대 최대:  15° (관측 최대값)
   평균:       8.4°
   
📉 강하각 기준:
   권장 최대:   6° (95백분위수)
   절대 최대:   8° (관측 최대값)
   평균:       4.2°
   
🔄 뱅크각 기준:
   권장 최대:  25° (쾌적성 한계)
   절대 최대:  30° (성능 한계)
   평균:      18.3°
   
⭕ 선회반경 기준:
   최소 요구:  450m (5백분위수)
   권장 최소:  520m (10백분위수)
   평균:      780m
```

---

### Phase 2 출력 (TSE)

```
📊 TSE 분석 결과 (RNP 0.3, N_MC=100):

Lateral TSE:
  Mean:    32.4 m
  Std:     14.8 m
  95%:     45.2 m  ← 회랑 폭 설계 기준
  99%:     58.7 m

Vertical TSE:
  Mean:    21.6 m
  Std:      9.3 m
  95%:     28.7 m  ← 고도 버퍼 기준
  99%:     37.2 m

✅ 권장 회랑 폭:
   직선 구간: 108 m (2 × 45.2 × 1.2 safety factor)
   선회 구간: 162 m (직선 + 50% splay)
   고도 버퍼: ±35 m (vertical TSE 95% + margin)
```

---

### Phase 3 출력 (Abnormal)

```
⚠️ 비정상 시나리오 검증 결과:

정상 운항 (N=500):
  회랑 내 포함률: 98.2% ✅
  
단일 고장 (N=200):
  회랑 내 포함률: 93.5% ⚠️  (목표 95% 미달)
  추가 마진 필요: +15% → 회랑 폭 124m
  
장애물 회피 (N=150):
  최소 간격 유지: 96.7% ✅
  권장 최소 간격: 80m
  
결론:
  → 회랑 폭을 124m로 상향 조정
  → 고장 시 자동 회랑 확장 로직 필요
```

---

## 🎯 혁신성

### 1. 데이터 기반 접근

**기존 방식:**
- 고정익 항공기 기준 차용
- 경험적 안전마진 (예: "항상 5° 접근각")

**본 R&D:**
- GUAM 시뮬레이션 3000 시나리오 분석
- 통계적 백분위수 기준 (95%/99%)
- UAM eVTOL 특성 반영

---

### 2. TSE 통합 분석

**기존 방식:**
- TSE는 비행시험으로만 측정
- 비용과 시간 과다 소요

**본 R&D:**
- GUAM + Monte Carlo로 TSE 분포 예측
- 수천 번 시나리오를 수 시간 내 분석
- 절차 설계 단계에서 TSE 고려

---

### 3. 비정상 상황 통합

**기존 방식:**
- 절차 설계 → 안전성 평가 (별도)

**본 R&D:**
- 절차 설계 단계부터 고장 시나리오 반영
- 고장 포함 TSE 분석
- 본질적으로 robust한 절차

---

## 📁 디렉토리 구조

```
UAM_Procedure_RnD/
├── Phase0_Setup/
│   ├── scenario_classifier.m       # 시나리오 분류 함수
│   └── run_phase0.m                # Phase 0 실행 스크립트
│
├── Phase1_Baseline/
│   └── run_baseline_analysis.m     # Phase 1 실행 스크립트
│
├── Phase2_TSE_Analysis/
│   └── run_tse_analysis.m          # Phase 2 실행 스크립트 (TBI)
│
├── Phase3_Abnormal/
│   └── run_abnormal_analysis.m     # Phase 3 실행 스크립트 (TBI)
│
├── Phase4_Standards/
│   └── derive_design_standards.m   # Phase 4 실행 스크립트 (TBI)
│
├── Utils/
│   ├── traj_to_path_coords.m       # 경로 좌표계 변환
│   ├── compute_flight_angles.m     # 비행각 계산
│   ├── compute_turn_metrics.m      # 선회 분석
│   └── compute_TSE.m               # TSE 계산 (Monte Carlo)
│
├── Results/
│   ├── Data/                       # MAT, CSV 결과
│   ├── Figures/                    # 플롯 및 시각화
│   └── Reports/                    # 텍스트 리포트
│
├── README.md                        # 영문 상세 설명서
├── PROJECT_OVERVIEW_KR.md           # 한글 개요 (본 문서)
└── RUN_ALL.m                        # 전체 실행 마스터 스크립트
```

---

## 🚀 사용 방법

### 빠른 시작 (Phase 0 + 1만 실행)

```matlab
% MATLAB 실행
cd UAM_Procedure_RnD

% 전체 파이프라인 실행 (Phase 0-1)
RUN_ALL

% 또는 개별 실행
cd Phase0_Setup
run_phase0

cd ../Phase1_Baseline
run_baseline_analysis
```

**소요 시간:**
- Phase 0: ~5-10분 (3000 시나리오 분류)
- Phase 1: ~2-3분 (통계 계산 및 플롯)

---

### 전체 실행 (Phase 2-4 포함, GUAM 필요)

```matlab
% RUN_ALL.m 설정 수정
config.run_phase2 = true;  % GUAM 시뮬레이션 필요
config.run_phase3 = true;  % GUAM 시뮬레이션 필요
config.run_phase4 = true;  % 최종 표준 문서 생성

RUN_ALL
```

**소요 시간:**
- Phase 2: ~30-60분 (Monte Carlo N=100, 50 시나리오)
- Phase 3: ~20-40분 (비정상 시나리오 50개)
- Phase 4: ~5분 (문서 생성)

---

## 📝 출력물

### 데이터 파일
- `scenario_catalog.mat` - 시나리오 분류 DB
- `phase1_baseline_results.mat` - 기준선 통계
- `phase1_baseline_results.csv` - CSV 내보내기

### 플롯
- `scenario_distribution_overview.png` - 시나리오 분포
- `flight_angle_distributions.png` - 각도 히스토그램
- `turn_radius_distribution.png` - 선회반경 분포

### 리포트
- `Phase0_Summary.txt` - 시나리오 분류 요약
- `UAM_Procedure_Design_Standard.pdf` - 최종 표준 문서 (Phase 4)

---

## 🔧 설정 변경

### TSE 파라미터 조정

`compute_TSE()` 호출 시:

```matlab
TSE_results = compute_TSE(trajectory_data, path_coords, ...
    'N_MC', 500, ...          % Monte Carlo 샘플 수 증가 → 정확도↑
    'RNP_Value', 0.1, ...     % 더 엄격한 RNP 기준
    'Wind_Model', 'moderate' % 중간 난류 추가
);
```

---

### 분석 시나리오 수 변경

`run_baseline_analysis.m`에서:

```matlab
config.n_scenarios_to_analyze = 100;  % 50 → 100으로 증가
```

---

## 🎓 이론적 배경

### TSE 공식 (ICAO Doc 9613 기반)

```
TSE² = FTE² + NSE²

FTE (Flight Technical Error):
  - 조종사/자동조종 제어 오차
  - 바람/난류 영향
  - 측정: 실제 궤적 - 이상 경로

NSE (Navigation System Error):
  - GNSS 오차
  - 항법 센서 오차
  - 모델: RNP 기반 (95% containment = 2σ)

RNP 0.3 의미:
  - 95% 확률로 계획 경로 ±0.3NM 이내
  - 1 NM = 1852m
  - σ = (0.3 × 1852) / 2 = 278m
```

---

### 회랑 폭 계산 로직

```
1. TSE 95백분위수 계산 (Monte Carlo)
   예: TSE_95 = 45m

2. 양쪽 보호공역 고려
   Width = 2 × TSE_95 = 90m

3. 안전마진 추가 (통상 20%)
   Width_safe = 90 × 1.2 = 108m

4. 선회 구간 splay 추가
   Width_turn = 108 × 1.5 = 162m
```

---

## ✅ 체크리스트

프로젝트 완료 확인:

- [x] Phase 0: 시나리오 분류 완료
- [x] Phase 1: 기준선 분석 완료
- [ ] Phase 2: TSE 분석 완료 (GUAM 필요)
- [ ] Phase 3: 비정상 검증 완료 (GUAM 필요)
- [ ] Phase 4: 최종 표준 문서 완료

출력물 확인:

- [x] 시나리오 카탈로그 생성
- [x] 기준선 통계 CSV
- [x] 분포 플롯 생성
- [ ] TSE 분포 플롯
- [ ] 최종 표준 PDF 문서

---

## 📞 문의

- **프로젝트 리드:** UAM Procedure R&D Team
- **GUAM 지원:** michael.j.acheson@nasa.gov
- **기술 지원:** GitHub Issues

---

**UAM 절차설계 기준 확립을 위한 데이터 기반 R&D 시스템!** 🚁✨
