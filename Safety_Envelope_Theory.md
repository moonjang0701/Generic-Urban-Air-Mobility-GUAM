# 공역 안전 봉투 (Airspace Safety Envelope) 이론

## 1. 안전 봉투 개념

### 정의:
**안전 봉투(Safety Envelope)**는 UAV 주변의 3차원 보호 공간으로, 다른 항공기와의 최소 안전 거리를 보장하는 가상의 경계입니다.

```
        ╔═══════════════════╗
        ║                   ║  ← 상부 경계 (Upper Bound)
        ║                   ║
        ║       UAV         ║
        ║        •          ║
        ║                   ║
        ║                   ║  ← 하부 경계 (Lower Bound)
        ╚═══════════════════╝
    ↑                           ↑
수평 경계               수평 경계
(Horizontal)           (Horizontal)
```

## 2. 봉투 크기 결정 요소

### 2.1 정적 요소 (Static Factors)
1. **기체 크기** (Aircraft Dimensions)
   - 날개폭, 길이, 높이
   
2. **센서 오차** (Sensor Uncertainty)
   - GPS 정확도: ±3-10m
   - 고도계 오차: ±1-5m
   - 자세 센서 오차: ±0.5-2°

3. **통신 지연** (Communication Latency)
   - C2 링크 지연: 100-500ms
   - 의사결정 시간: 1-3초

### 2.2 동적 요소 (Dynamic Factors)
1. **속도** (Velocity)
   - 고속일수록 큰 봉투 필요
   - V [m/s] → Safety Distance = V × Reaction_Time

2. **기동성** (Maneuverability)
   - 최대 선회율
   - 최대 상승/하강률

3. **환경 조건** (Environmental Conditions)
   - 바람 속도/방향
   - 난류 강도
   - 가시거리

## 3. 안전 봉투 수학 모델

### 3.1 원통형 보호 구역 (Cylindrical Protected Zone)
```
Horizontal Radius (R_h):
R_h = R_base + V × T_react + σ_pos

Vertical Height (H_v):
H_v = H_base + |V_z| × T_react + σ_alt

여기서:
  R_base = 기본 수평 반경 (예: 150-300 ft)
  H_base = 기본 수직 거리 (예: 50-100 ft)
  V = 수평 속도
  V_z = 수직 속도
  T_react = 반응 시간 (예: 5-10 sec)
  σ_pos = 위치 불확실성 (예: 30-50 ft)
  σ_alt = 고도 불확실성 (예: 10-20 ft)
```

### 3.2 타원체 안전 봉투 (Ellipsoidal Safety Envelope)
더 정교한 모델:
```
(x/a)² + (y/b)² + (z/c)² ≤ 1

여기서:
  a = 전방 반경 (Forward)
  b = 측방 반경 (Lateral)
  c = 수직 반경 (Vertical)
  
전방 반경이 가장 큼 (속도 방향):
  a = R_h + V × T_react
  b = R_h
  c = H_v
```

## 4. 충돌 확률 계산

### 4.1 기하학적 충돌 확률 (Geometric Collision Probability)
```
P_conflict = P(d < d_min)

여기서:
  d = 두 UAV 간 거리
  d_min = 최소 안전 거리
  
d = √[(x₁-x₂)² + (y₁-y₂)² + (z₁-z₂)²]
d_min = R_h1 + R_h2 (수평) 및 H_v1 + H_v2 (수직)
```

### 4.2 시간 기반 충돌 확률 (Time-based Collision Probability)
```
CPA (Closest Point of Approach):
  
t_cpa = -[(Δr · Δv)] / |Δv|²

여기서:
  Δr = r₂ - r₁ (상대 위치 벡터)
  Δv = v₂ - v₁ (상대 속도 벡터)
  
d_min = |Δr + Δv × t_cpa|

If t_cpa > 0 and d_min < d_safe:
  → 충돌 가능성 있음
```

## 5. 안전 상황 지수 (Safety Situation Index)

### 5.1 공간 안전도 (Spatial Safety)
```
S_spatial = 1 - exp(-λ × d_min / d_safe)

여기서:
  λ = 민감도 파라미터 (예: 2-5)
  d_min = 최소 거리
  d_safe = 안전 거리
  
S_spatial ∈ [0, 1]
  0 = 매우 위험
  1 = 매우 안전
```

### 5.2 시간 안전도 (Temporal Safety)
```
S_temporal = 1 - exp(-t_cpa / t_safe)

여기서:
  t_cpa = 최근접점까지 시간
  t_safe = 안전 시간 여유 (예: 30 sec)
```

### 5.3 종합 안전도 (Overall Safety)
```
S_overall = w₁×S_spatial + w₂×S_temporal + w₃×S_trajectory + w₄×S_operational

여기서:
  w₁, w₂, w₃, w₄ = 가중치 (합=1)
  S_trajectory = 경로 안전도
  S_operational = 운용 안전도
```

## 6. 밀집 공역 안전 평가

### 6.1 공역 밀도 (Airspace Density)
```
ρ = N / V_airspace

여기서:
  N = UAV 대수
  V_airspace = 공역 부피 (ft³ 또는 m³)
  
밀도 등급:
  ρ < 0.001 UAV/km³ : Low density
  0.001 ≤ ρ < 0.01  : Medium density
  ρ ≥ 0.01          : High density (congested)
```

### 6.2 안전 용량 (Safety Capacity)
```
C_safe = V_airspace / (V_envelope × N_max)

여기서:
  V_envelope = 평균 안전 봉투 부피
  N_max = 최대 허용 UAV 수
```

## 7. 실시간 안전 모니터링

### 7.1 위험 레벨 분류
```
Level 1 (Green):  d > 2 × d_safe, t_cpa > 60 sec
Level 2 (Yellow): d_safe < d ≤ 2×d_safe, 30 < t_cpa ≤ 60
Level 3 (Orange): 0.5×d_safe < d ≤ d_safe, 15 < t_cpa ≤ 30
Level 4 (Red):    d ≤ 0.5×d_safe, t_cpa ≤ 15

→ Level 4 도달 시 즉시 회피 기동 필요
```

## 8. GUAM에서의 구현 전략

### 8.1 단일 UAV 안전 평가
1. 설정된 궤적 추종 정확도
2. 봉투 내 위치 유지 능력
3. 외부 교란에 대한 복원력

### 8.2 다중 UAV 시뮬레이션 (향후)
1. 상대 거리 계산
2. CPA 분석
3. 충돌 회피 기동

### 8.3 측정 지표
- **Envelope Violation Rate**: 봉투 침범 빈도
- **Position Uncertainty**: 위치 불확실성
- **Safety Margin**: 안전 여유도
- **Conflict Probability**: 충돌 확률

## 9. 참고 기준

### FAA (Federal Aviation Administration)
- 유인기 대 유인기: 500 ft 수평, 1000 ft 수직
- UAV 운용: 최소 500 ft (Part 107)

### EASA (European Aviation Safety Agency)
- SORA (Specific Operations Risk Assessment)
- SAIL (Specific Assurance and Integrity Level)

### ICAO (International Civil Aviation Organization)
- RPAS Manual Doc 10019
- Collision Avoidance Systems

## 10. 실제 적용 사례

### Urban Air Mobility (UAM)
- NASA UAM Grand Challenge
- 밀집 도심 환경: 100-200 ft 수평, 50 ft 수직
- 고밀도 운용: 1-2 km³ 당 10-50대

### Package Delivery
- Amazon Prime Air: 400 ft 고도 이하
- 안전 거리: 300 ft 수평

### Swarm Operations
- 군집 비행: 개체 간 50-100 ft
- 동적 봉투 조정 필요
