# UAV Flight Safety Measurements in GUAM

## 📋 개요

이 스크립트는 **"Flight safety measurements of UAVs in congested airspace"** 논문의 개념을 GUAM 시뮬레이터에 적용하여 UAV 비행 안전성을 정량적으로 측정합니다.

## 🎯 측정 항목

### 1. **경로 추적 정확도 (Path Tracking Accuracy)**
- **수평 편차** (Horizontal Deviation)
- **수직 편차** (Vertical Deviation)
- **보호 구역 침범 여부**

### 2. **속도 안정성 (Velocity Stability)**
- 평균 속도
- 표준 편차
- 변동 계수 (CV)

### 3. **자세 안정성 (Attitude Stability)**
- Roll RMS
- Pitch RMS
- 최대 자세 변화

### 4. **충돌 확률 분석 (Conflict Probability)**
- 잠재적 침입자와의 최소 이격 거리
- 충돌 확률
- Near-miss 확률

### 5. **항법 정밀도 지수 (Navigation Precision Index, NPI)**
- Cross-track error
- Along-track error
- Vertical error
- Overall NPI

### 6. **종합 안전 평가 (Overall Safety Assessment)**
- 각 항목별 점수 (0-100)
- 종합 안전 점수
- 안전 등급 분류

## 🔧 안전 기준 (Safety Standards)

### 이격 거리 요구사항:
```matlab
최소 수평 이격: 500 ft
최소 수직 이격: 100 ft
보호 구역 반경: 250 ft
보호 구역 높이: ±50 ft
경고 시간: 30 sec
```

### 안전 등급:
- **90-100점**: EXCELLENT - 밀집 공역 운용 가능
- **75-89점**: GOOD - 일반 운용 가능
- **60-74점**: FAIR - 주의 필요
- **0-59점**: POOR - 권장하지 않음

## 🚀 사용 방법

### MATLAB에서 실행:

```matlab
cd('D:\Generic-Urban-Air-Mobility-GUAM-main')
exam_UAV_Safety_Metrics
```

### 출력 결과:

1. **콘솔 출력**:
   - 실시간 안전 지표
   - 각 항목별 평가
   - 종합 안전 점수

2. **그래프** (`UAV_Safety_Metrics_XXX_kts.png`):
   - 3D 비행 경로 (보호 구역 표시)
   - 수평/수직 편차
   - 속도 프로파일
   - 자세 변화
   - 안전 점수 breakdown

3. **리포트** (`Safety_Report_XXX_kts.txt`):
   - 종합 안전 평가 보고서
   - 모든 측정 지표 요약

## 📊 측정 지표 상세 설명

### 1. Path Tracking Score (경로 추적 점수)
```
Score = 100 - (max_horizontal_deviation / 5)
```
- 수평 편차가 클수록 점수 감소
- 보호 구역(250 ft) 이내 유지 시 높은 점수

### 2. Velocity Stability Score (속도 안정성 점수)
```
Score = 100 - (velocity_variation * 5)
```
- 변동 계수(CV)가 낮을수록 높은 점수
- CV < 5%: 매우 안정
- CV < 10%: 양호

### 3. Attitude Stability Score (자세 안정성 점수)
```
Score = 100 - ((roll_RMS + pitch_RMS) * 2)
```
- RMS 값이 작을수록 안정적
- RMS < 5°: 매우 안정
- RMS < 10°: 양호

### 4. Conflict Avoidance Score (충돌 회피 점수)
```
Score = 100 - (conflict_probability * 200)
```
- 충돌 확률이 낮을수록 높은 점수
- 시뮬레이션된 침입자 시나리오 기반

### 5. Navigation Precision Score (항법 정밀도 점수)
```
Score = 100 - (NPI_overall / 2)
NPI = √(cross_track² + along_track² + vertical²)
```
- NPI < 50 ft: 매우 정밀
- NPI < 100 ft: 양호

## 🎓 논문 기반 개념 매핑

| 논문 개념 | GUAM 구현 |
|----------|-----------|
| Airspace Safety Situation | Overall Safety Score (0-100) |
| Conflict Probability | 시뮬레이션 기반 충돌 확률 계산 |
| Flight Conflict Detection | 최소 이격 거리 모니터링 |
| Navigation Accuracy | Navigation Precision Index (NPI) |
| Protected Zone | 반경 250ft 원통형 보호 구역 |
| Separation Requirements | 수평 500ft / 수직 100ft |

## 🔬 고급 활용

### 다양한 시나리오 테스트:

#### 1. 속도별 안전성 비교:
```matlab
% 스크립트 내에서 수정:
cruise_speed_knots = 80;   % 또는 100, 120
```

#### 2. 선회 비행 안전성:
```matlab
% 원형 궤적으로 변경:
turn_radius = 1000;  % ft
turn_rate = cruise_speed_fps / turn_radius;
theta = turn_rate * time;
pos(:,1) = turn_radius * sin(theta);
pos(:,2) = turn_radius * (1 - cos(theta));
```

#### 3. 밀집 공역 시뮬레이션:
```matlab
% 침입자 수 증가:
n_intruders = 20;  % 기본값 5에서 증가
```

## 📈 예상 결과

### 정상 순항 비행 (100 knots):
```
Path Tracking Score: 95-100
Velocity Stability Score: 90-95
Attitude Stability Score: 85-95
Conflict Avoidance Score: 80-100
Navigation Precision Score: 90-100

Overall Safety Score: 88-98 (GOOD to EXCELLENT)
```

### 선회 비행:
```
Path Tracking Score: 85-95 (약간 낮음)
Velocity Stability Score: 80-90
Attitude Stability Score: 75-85 (뱅크각으로 인한 감소)

Overall Safety Score: 80-90 (GOOD)
```

## ⚠️ 주의사항

1. **단일 기체 시뮬레이션**: 현재는 1대의 UAV만 시뮬레이션. 실제 밀집 공역은 다중 기체 필요
2. **침입자 시뮬레이션**: 단순화된 시나리오. 실제로는 동적 침입자 필요
3. **날씨 조건**: 현재는 무풍 조건. 실제로는 난류, 바람 고려 필요
4. **센서 오차**: 이상적인 센서 가정. 실제로는 GPS 오차 등 고려

## 🔗 참고 자료

- 논문: "Flight safety measurements of UAVs in congested airspace"
- GUAM Documentation: `/home/user/webapp/README.md`
- NASA SACD: https://sacd.larc.nasa.gov/uam-refs/

## 📝 향후 개선 사항

1. **다중 기체 시뮬레이션**: 여러 UAV 동시 비행
2. **동적 충돌 회피**: 실시간 회피 기동
3. **날씨 영향**: 바람, 난류 효과 추가
4. **통신 지연**: C2 링크 지연 모델링
5. **배터리 제약**: 에너지 관리 통합

## 💡 문의

GUAM 관련 문의:
- Michael J. Acheson
- NASA Langley Research Center
- Email: michael.j.acheson@nasa.gov

스크립트 관련 문의:
- GUAM GitHub Issues 또는 토론 게시판
