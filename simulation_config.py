#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
시뮬레이션 파라미터 설정 파일

이 파일을 수정하여 시뮬레이션 파라미터를 쉽게 변경할 수 있습니다.
"""

# ============================================================================
# 공역 파라미터
# ============================================================================

# 공역 반지름 리스트 [m]
R_LIST = [1000, 1500, 2000]

# 고도 범위 [m]
H_MIN = 300.0  # 최소 고도
H_MAX = 600.0  # 최대 고도


# ============================================================================
# 교통량 파라미터
# ============================================================================

# 교통량 리스트 [movements/hour]
# movements = 이륙 + 착륙 합산
LAMBDA_LIST = [10, 20, 30, 40]

# 도착/출발 비율 (0.5 = 1:1)
ARRIVAL_RATIO = 0.5

# Poisson process 사용 여부
USE_POISSON = False  # False: Uniform 분포, True: Exponential inter-arrival


# ============================================================================
# 비행 파라미터
# ============================================================================

# 평균 지상 속도 [m/s]
V_MEAN = 50.0

# 평균 수평 속도 [m/s] (향후 GUAM 연동 시 사용)
V_HORIZONTAL = 50.0

# 평균 수직 속도 [m/s] (향후 GUAM 연동 시 사용)
V_VERTICAL = 3.0


# ============================================================================
# 바람/난류 파라미터
# ============================================================================

# 최대 평균 풍속 [m/s]
# 각 flight마다 Uniform(-W_MAX, W_MAX) 분포에서 샘플링
W_MAX = 8.0

# 최대 난류 표준편차 [m/s]
# 각 flight마다 Uniform(0, SIGMA_GUST_MAX) 분포에서 샘플링
SIGMA_GUST_MAX = 5.0

# 난류 시상수 [s] (Ornstein-Uhlenbeck process)
TAU_TURB = 10.0


# ============================================================================
# 안전성 기준
# ============================================================================

# 수평 TSE(Total System Error) 한계값 [m]
TSE_LIMIT = 300.0

# 보호 볼륨 반경 [m] (향후 충돌 분석 시 사용)
R_PV = 150.0


# ============================================================================
# 시뮬레이션 설정
# ============================================================================

# 시간 step [s]
DT = 1.0

# 총 시뮬레이션 시간 [s]
# 8시간 운용: 09:00~17:00
T_SIM = 8 * 3600  # 28,800초

# Monte Carlo 반복 횟수
# 값이 클수록 정확하지만 시간이 오래 걸림
N_MC = 100  # 권장: 100~1000


# ============================================================================
# GUAM 연동 설정 (향후 사용)
# ============================================================================

# GUAM 시뮬레이터 사용 여부
USE_GUAM = False

# GUAM TSE 데이터 직접 사용 여부
USE_GUAM_TSE = False

# GUAM API 엔드포인트 (향후 설정)
GUAM_API_ENDPOINT = "http://localhost:8080/guam/api"

# GUAM 기체 타입
GUAM_VEHICLE_TYPE = "eVTOL"


# ============================================================================
# 출력 설정
# ============================================================================

# 진행 상황 출력 여부
VERBOSE = True

# 결과 저장 경로
OUTPUT_DIR = "/home/user/webapp"

# 그래프 저장 파일명
PLOT_RESULTS_FILE = "simulation_results.png"
PLOT_TSE_DIST_FILE = "tse_distribution.png"

# 그래프 저장 DPI
PLOT_DPI = 300


# ============================================================================
# 고급 설정
# ============================================================================

# 다층 공역 사용 여부
USE_MULTILAYER = False

# 다층 공역 경계 [m] (USE_MULTILAYER=True일 때 사용)
LAYER_BOUNDARY = 450.0  # 300~450m (하층), 450~600m (상층)

# 충돌 분석 활성화 여부 (향후 구현)
ENABLE_COLLISION_CHECK = False

# 최소 분리 거리 [m] (ENABLE_COLLISION_CHECK=True일 때 사용)
MIN_SEPARATION = 500.0


# ============================================================================
# 파라미터 검증
# ============================================================================

def validate_config():
    """
    설정 파라미터 유효성 검사
    """
    errors = []
    
    # 공역 반지름 검사
    if not R_LIST or len(R_LIST) == 0:
        errors.append("R_LIST가 비어있습니다.")
    if any(r <= 0 for r in R_LIST):
        errors.append("R_LIST의 모든 값은 양수여야 합니다.")
    
    # 고도 범위 검사
    if H_MIN >= H_MAX:
        errors.append("H_MIN은 H_MAX보다 작아야 합니다.")
    if H_MIN < 0 or H_MAX < 0:
        errors.append("고도는 음수일 수 없습니다.")
    
    # 교통량 검사
    if not LAMBDA_LIST or len(LAMBDA_LIST) == 0:
        errors.append("LAMBDA_LIST가 비어있습니다.")
    if any(lam <= 0 for lam in LAMBDA_LIST):
        errors.append("LAMBDA_LIST의 모든 값은 양수여야 합니다.")
    
    # 속도 검사
    if V_MEAN <= 0:
        errors.append("V_MEAN은 양수여야 합니다.")
    
    # 바람 파라미터 검사
    if W_MAX < 0:
        errors.append("W_MAX는 음수일 수 없습니다.")
    if SIGMA_GUST_MAX < 0:
        errors.append("SIGMA_GUST_MAX는 음수일 수 없습니다.")
    if TAU_TURB <= 0:
        errors.append("TAU_TURB는 양수여야 합니다.")
    
    # TSE 한계 검사
    if TSE_LIMIT <= 0:
        errors.append("TSE_LIMIT는 양수여야 합니다.")
    
    # 시뮬레이션 설정 검사
    if DT <= 0:
        errors.append("DT는 양수여야 합니다.")
    if T_SIM <= 0:
        errors.append("T_SIM은 양수여야 합니다.")
    if N_MC <= 0:
        errors.append("N_MC는 양수여야 합니다.")
    
    # 도착/출발 비율 검사
    if not (0 <= ARRIVAL_RATIO <= 1):
        errors.append("ARRIVAL_RATIO는 0과 1 사이여야 합니다.")
    
    if errors:
        error_msg = "설정 파라미터 오류:\n" + "\n".join(f"  - {e}" for e in errors)
        raise ValueError(error_msg)
    
    return True


if __name__ == "__main__":
    # 파라미터 검증 테스트
    try:
        validate_config()
        print("✓ 모든 파라미터가 유효합니다.")
        print("\n현재 설정:")
        print(f"  공역 반지름: {R_LIST} m")
        print(f"  교통량: {LAMBDA_LIST} movements/hour")
        print(f"  평균 속도: {V_MEAN} m/s")
        print(f"  최대 풍속: {W_MAX} m/s")
        print(f"  난류 σ: {SIGMA_GUST_MAX} m/s")
        print(f"  TSE 한계: {TSE_LIMIT} m")
        print(f"  고도 범위: {H_MIN}~{H_MAX} m")
        print(f"  시뮬레이션 시간: {T_SIM/3600:.1f} hours")
        print(f"  Monte Carlo 반복: {N_MC}")
    except ValueError as e:
        print(f"✗ {e}")
