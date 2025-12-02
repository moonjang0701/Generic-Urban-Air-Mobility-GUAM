# UAM 버티포트 시뮬레이션 사용 가이드

## 📁 파일 구조

```
/home/user/webapp/
├── uam_vertiport_simulation.py      # 핵심 시뮬레이션 라이브러리
├── simulation_config.py             # 파라미터 설정 파일
├── run_simulation.py                # 메인 실행 스크립트
├── example_custom_simulation.py     # 커스텀 예제 모음
├── README.md                        # 프로젝트 개요
├── USAGE_GUIDE.md                   # 이 파일 (사용 가이드)
├── simulation_results.png           # 안전성 히트맵 결과
└── tse_distribution.png             # TSE 분포 그래프
```

## 🚀 빠른 시작

### 방법 1: 기본 실행 (가장 간단)

설정 파일의 기본값으로 바로 실행:

```bash
python uam_vertiport_simulation.py
```

### 방법 2: 설정 파일 수정 후 실행 (권장)

1. `simulation_config.py` 파일을 열어서 원하는 파라미터 수정
2. 실행:

```bash
python run_simulation.py
```

### 방법 3: 커스텀 시뮬레이션 (고급)

예제 파일을 참고하여 직접 코드 작성:

```bash
python example_custom_simulation.py
```

## 📝 주요 파라미터 설정 가이드

### `simulation_config.py` 주요 파라미터

#### 1. 공역 설정

```python
# 테스트할 공역 반지름 리스트 [m]
R_LIST = [1000, 1500, 2000]

# 운용 고도 범위 [m]
H_MIN = 300.0  # 최소 고도
H_MAX = 600.0  # 최대 고도
```

**권장 값**:
- 도심 단거리: R = 1000~1500m
- 도심 중거리: R = 1500~2000m
- 교외 장거리: R = 2000~3000m

#### 2. 교통량 설정

```python
# 테스트할 교통량 리스트 [movements/hour]
LAMBDA_LIST = [10, 20, 30, 40]

# 도착/출발 비율
ARRIVAL_RATIO = 0.5  # 0.5 = 1:1 비율
```

**권장 값**:
- 저밀도: λ = 10~20 movements/hour
- 중밀도: λ = 20~40 movements/hour
- 고밀도: λ = 40~80 movements/hour

#### 3. 비행 파라미터

```python
# 평균 지상 속도 [m/s]
V_MEAN = 50.0  # ~180 km/h
```

**권장 값**:
- eVTOL 순항 속도: 40~60 m/s (144~216 km/h)

#### 4. 바람/난류 파라미터 ⚠️ 중요!

```python
# 최대 평균 풍속 [m/s]
W_MAX = 8.0

# 최대 난류 표준편차 [m/s]
SIGMA_GUST_MAX = 5.0

# 난류 시상수 [s]
TAU_TURB = 10.0
```

**권장 값** (기상 조건별):
- **맑은 날 (calm)**: W_MAX=3, SIGMA_GUST_MAX=2
- **보통 날 (moderate)**: W_MAX=6, SIGMA_GUST_MAX=4
- **바람 있는 날 (windy)**: W_MAX=10, SIGMA_GUST_MAX=6
- **강풍 (strong wind)**: W_MAX=15, SIGMA_GUST_MAX=8

⚠️ **현재 기본값(W_MAX=8, SIGMA_GUST_MAX=5)은 다소 높게 설정되어 있어 안전성이 낮게 나올 수 있습니다.**

#### 5. 안전성 기준

```python
# TSE 한계값 [m]
TSE_LIMIT = 300.0
```

**설명**:
- FAA 기준: 수평 TSE 300m 이내 유지 필요
- 고도 범위: H_MIN ~ H_MAX (예: 300~600m) 이내 유지 필요

#### 6. 시뮬레이션 설정

```python
# 시간 step [s]
DT = 1.0

# 총 시뮬레이션 시간 [s]
T_SIM = 8 * 3600  # 8시간

# Monte Carlo 반복 횟수
N_MC = 100
```

**권장 값**:
- **빠른 테스트**: N_MC = 50, DT = 2.0
- **일반 분석**: N_MC = 100, DT = 1.0
- **정밀 분석**: N_MC = 500~1000, DT = 0.5

## 📊 결과 해석

### 출력 파라미터

| 파라미터 | 의미 | 목표값 |
|---------|------|-------|
| `P(safe)` | 안전한 비행 비율 | ≥ 0.8 (80%) |
| `P(violation)` | TSE/고도 위반 비율 | ≤ 0.2 (20%) |
| `total_flights` | 총 시뮬레이션 비행 수 | - |
| `unsafe_flights` | 위반 발생 비행 수 | 최소화 |
| `mean_max_tse` | 평균 최대 TSE [m] | ≤ 300m |

### 시각화 결과

#### 1. `simulation_results.png`
- **좌측 히트맵**: TSE Violation 확률 (낮을수록 좋음)
- **우측 히트맵**: Safe Flight 확률 (높을수록 좋음)

**색상 해석**:
- 🟢 녹색 (P(safe) > 0.8): 안전한 운용 가능
- 🟡 노란색 (0.5 < P(safe) < 0.8): 제한적 운용 가능
- 🔴 빨간색 (P(safe) < 0.5): 운용 부적합

#### 2. `tse_distribution.png`
- 각 조건별 최대 TSE 분포
- 빨간 점선: TSE 한계선 (300m)
- 분포가 한계선 왼쪽에 집중: 안전
- 분포가 한계선 오른쪽으로 확장: 위험

## 🔧 문제 해결

### 문제 1: 안전성이 너무 낮음 (P(safe) < 0.5)

**원인**: 바람/난류 파라미터가 과도하게 설정됨

**해결책**:
```python
# simulation_config.py 수정
W_MAX = 5.0              # 8.0 → 5.0
SIGMA_GUST_MAX = 3.0     # 5.0 → 3.0
```

### 문제 2: 시뮬레이션이 너무 느림

**원인**: Monte Carlo 반복 횟수나 조합이 많음

**해결책**:
```python
# simulation_config.py 수정
N_MC = 50                # 100 → 50
R_LIST = [1500]          # 하나만 테스트
LAMBDA_LIST = [20, 30]   # 적은 수로 제한
```

### 문제 3: 메모리 부족

**원인**: 너무 많은 데이터 저장

**해결책**:
```python
# DT를 늘려서 저장 데이터 수 감소
DT = 2.0  # 1.0 → 2.0
```

### 문제 4: TSE 분포가 이상함

**원인**: 바람 모델 파라미터 설정 오류

**해결책**:
```python
# 난류 시상수 조정
TAU_TURB = 15.0  # 10.0 → 15.0 (더 완만한 변화)
```

## 🎯 실전 사용 예제

### 예제 1: 맑은 날 운용 시뮬레이션

```python
# simulation_config.py
W_MAX = 3.0
SIGMA_GUST_MAX = 2.0
R_LIST = [1500]
LAMBDA_LIST = [20, 30, 40]
N_MC = 100
```

```bash
python run_simulation.py
```

**기대 결과**: P(safe) > 0.8

### 예제 2: 최적 공역 반지름 찾기

```python
# simulation_config.py
W_MAX = 6.0
SIGMA_GUST_MAX = 4.0
R_LIST = [800, 1000, 1200, 1500, 1800, 2000]
LAMBDA_LIST = [30]
N_MC = 100
```

```bash
python run_simulation.py
```

**분석**: 어느 R에서 P(safe)가 최대인지 확인

### 예제 3: 용량 분석

```python
# simulation_config.py
W_MAX = 5.0
SIGMA_GUST_MAX = 3.0
R_LIST = [1500]
LAMBDA_LIST = [10, 20, 30, 40, 50, 60, 80, 100]
N_MC = 100
```

```bash
python run_simulation.py
```

**분석**: P(safe) ≥ 0.8을 만족하는 최대 λ 확인

### 예제 4: 프로그래밍 방식

`example_custom_simulation.py` 참고:

```python
from uam_vertiport_simulation import run_full_simulation

results = run_full_simulation(
    R_list=[1500],
    lambda_list=[20, 30],
    V_mean=50.0,
    W_max=5.0,
    sigma_gust_max=3.0,
    tse_limit=300.0,
    h_min=300.0,
    h_max=600.0,
    dt=1.0,
    T_sim=8*3600,
    N_mc=100,
    verbose=True
)

# 결과 분석
for r in results:
    print(f"R={r['R']}, λ={r['lambda']}: P(safe)={r['P_safe']:.3f}")
```

## 🔬 NASA GUAM 연동 준비

현재 코드는 GUAM 연동을 위한 인터페이스가 준비되어 있습니다.

### 연동 포인트 1: 궤적 생성

`uam_vertiport_simulation.py`, `generate_nominal_trajectory()` 함수:

```python
if use_GUAM:
    # 여기에 GUAM API 호출 코드 추가
    traj_data = GUAM_API.get_trajectory(...)
    return Trajectory(
        t=traj_data['time'],
        x_nom=traj_data['x'],
        y_nom=traj_data['y'],
        h_nom=traj_data['altitude']
    )
```

### 연동 포인트 2: TSE 계산

`apply_disturbances_and_check_TSE()` 함수:

```python
if use_GUAM_TSE:
    # GUAM에서 TSE 데이터 직접 사용
    guam_tse_data = GUAM_API.get_TSE_data(...)
    x_real = guam_tse_data['x_actual']
    y_real = guam_tse_data['y_actual']
    tse_values = guam_tse_data['lateral_TSE']
```

### 연동 활성화

```python
# simulation_config.py
USE_GUAM = True
USE_GUAM_TSE = True
GUAM_API_ENDPOINT = "http://your-guam-server:8080/api"
```

## 📚 추가 자료

- **README.md**: 프로젝트 개요 및 기술 문서
- **Paper_Methodology_Analysis.md**: 연구 방법론 분석
- **IMPLEMENTATION_SUMMARY_KR.md**: 구현 요약

## 💡 팁

1. **처음 사용**: 기본값으로 실행 → 결과 확인 → 파라미터 조정
2. **빠른 테스트**: N_MC=50, 적은 조합으로 시작
3. **정밀 분석**: N_MC=500+, 많은 조합 테스트
4. **바람 영향 확인**: W_MAX를 3→6→10으로 변경하며 비교
5. **용량 분석**: λ를 넓은 범위로 설정 (10~100)

## ❓ 자주 묻는 질문 (FAQ)

**Q1: 시뮬레이션이 얼마나 걸리나요?**
- 기본 설정 (3 R × 4 λ × 100 MC): ~2분
- N_MC=1000: ~20분

**Q2: 어떤 Python 버전이 필요한가요?**
- Python 3.7 이상 권장

**Q3: 실제 UAM 운용에 사용할 수 있나요?**
- 현재는 프로토타입. GUAM 연동 후 실사용 가능.

**Q4: TSE 한계를 바꿀 수 있나요?**
- 네, `TSE_LIMIT` 파라미터를 수정하세요.

**Q5: 충돌 분석도 가능한가요?**
- 향후 버전에서 NMAC 분석 추가 예정.

## 📞 지원

문제가 발생하면:
1. `simulation_config.py` 파라미터 확인
2. `python simulation_config.py` 실행하여 검증
3. 오류 메시지 확인

---

**작성일**: 2025-12-02  
**버전**: 1.0.0  
**작성자**: AI Senior Developer (Aviation Traffic Simulation)
