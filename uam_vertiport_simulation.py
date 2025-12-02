#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
UAM 버티포트 공역 시뮬레이션 (TSE 안전성 평가)

목적:
- 도심 UAM 버티포트 주변 원형 공역에서 이착륙 교통량에 따른 안전성 평가
- TSE(Total System Error) 300m 보호범위 위반 여부 체크
- 고도 범위(300~600m) 유지 여부 체크
- GUAM 시뮬레이터 연동을 위한 인터페이스 구조

작성자: AI Senior Developer
날짜: 2025-12-02
"""

import numpy as np
import matplotlib.pyplot as plt
from dataclasses import dataclass
from typing import Tuple, List, Dict
import warnings
warnings.filterwarnings('ignore')


# ============================================================================
# 데이터 구조
# ============================================================================

@dataclass
class Movement:
    """단일 이착륙 movement 정보"""
    mov_id: int              # movement ID
    mov_type: str            # 'arrival' or 'departure'
    t_start: float           # 시작 시간 [s]
    theta: float             # 진입/이탈 방향 [rad]
    x_boundary: float        # 경계점 x 좌표 [m]
    y_boundary: float        # 경계점 y 좌표 [m]


@dataclass
class Trajectory:
    """궤적 데이터"""
    t: np.ndarray           # 시간 벡터 [s]
    x_nom: np.ndarray       # nominal x 좌표 [m]
    y_nom: np.ndarray       # nominal y 좌표 [m]
    h_nom: np.ndarray       # nominal 고도 [m]
    x_real: np.ndarray = None  # 실제 x 좌표 (난류 포함) [m]
    y_real: np.ndarray = None  # 실제 y 좌표 (난류 포함) [m]
    h_real: np.ndarray = None  # 실제 고도 (난류 포함) [m]


@dataclass
class WindParams:
    """바람/난류 파라미터"""
    W_mean_x: float         # 평균 횡풍 [m/s]
    W_mean_y: float         # 평균 종풍 [m/s]
    sigma_gust: float       # 난류 표준편차 [m/s]
    tau_turb: float         # 난류 시상수 [s] (OU process)


@dataclass
class SafetyCheck:
    """안전성 체크 결과"""
    is_safe: bool           # 안전 여부
    max_lateral_tse: float  # 최대 수평 TSE [m]
    max_vertical_dev: float # 최대 고도 이탈 [m]
    violation_time: float   # 위반 발생 시간 [s] (없으면 -1)


# ============================================================================
# 1. 교통(이착륙) 생성 로직
# ============================================================================

def generate_movements(lambda_mvh: float, 
                      T_sim: float, 
                      R: float,
                      arrival_ratio: float = 0.5,
                      use_poisson: bool = False) -> List[Movement]:
    """
    이착륙 movements 생성
    
    Parameters:
    -----------
    lambda_mvh : float
        교통량 [movements/hour]
    T_sim : float
        총 시뮬레이션 시간 [s]
    R : float
        공역 반지름 [m]
    arrival_ratio : float
        도착편 비율 (기본값: 0.5)
    use_poisson : bool
        Poisson process 사용 여부 (기본값: False, Uniform 분포 사용)
    
    Returns:
    --------
    movements : List[Movement]
        생성된 movements 리스트
    """
    # 총 movements 수 계산
    N_total = int(np.round(lambda_mvh * T_sim / 3600.0))
    
    if N_total == 0:
        return []
    
    # 도착/출발 분할
    N_arrivals = int(np.floor(N_total * arrival_ratio))
    N_departures = N_total - N_arrivals
    
    movements = []
    mov_id = 0
    
    # 도착편 생성
    for _ in range(N_arrivals):
        if use_poisson:
            # Poisson process (exponential inter-arrival time)
            if mov_id == 0:
                t_start = np.random.exponential(3600.0 / lambda_mvh)
            else:
                t_start = movements[-1].t_start + np.random.exponential(3600.0 / lambda_mvh)
        else:
            # Uniform distribution
            t_start = np.random.uniform(0, T_sim)
        
        theta = np.random.uniform(0, 2 * np.pi)
        x_boundary = R * np.cos(theta)
        y_boundary = R * np.sin(theta)
        
        movements.append(Movement(
            mov_id=mov_id,
            mov_type='arrival',
            t_start=t_start,
            theta=theta,
            x_boundary=x_boundary,
            y_boundary=y_boundary
        ))
        mov_id += 1
    
    # 출발편 생성
    for _ in range(N_departures):
        if use_poisson:
            if mov_id == 0:
                t_start = np.random.exponential(3600.0 / lambda_mvh)
            else:
                t_start = movements[-1].t_start + np.random.exponential(3600.0 / lambda_mvh)
        else:
            t_start = np.random.uniform(0, T_sim)
        
        theta = np.random.uniform(0, 2 * np.pi)
        x_boundary = R * np.cos(theta)
        y_boundary = R * np.sin(theta)
        
        movements.append(Movement(
            mov_id=mov_id,
            mov_type='departure',
            t_start=t_start,
            theta=theta,
            x_boundary=x_boundary,
            y_boundary=y_boundary
        ))
        mov_id += 1
    
    # 시간 순으로 정렬
    movements.sort(key=lambda m: m.t_start)
    
    return movements


# ============================================================================
# 2. 기준 궤적(Nominal Trajectory) 생성
# ============================================================================

def generate_nominal_trajectory(movement: Movement,
                               R: float,
                               V_mean: float,
                               dt: float,
                               h_min: float = 300.0,
                               h_max: float = 600.0,
                               use_GUAM: bool = False) -> Trajectory:
    """
    기준 궤적 생성 (이상적인 궤적)
    
    ※ 향후 GUAM 시뮬레이터 연동 시, 이 함수를 GUAM API 호출로 교체할 예정.
    ※ use_GUAM=True일 때는 GUAM에서 동역학 응답 기반 궤적을 받아올 수 있음.
    
    Parameters:
    -----------
    movement : Movement
        이착륙 movement 정보
    R : float
        공역 반지름 [m]
    V_mean : float
        평균 지상 속도 [m/s]
    dt : float
        시간 step [s]
    h_min, h_max : float
        고도 범위 [m]
    use_GUAM : bool
        GUAM 시뮬레이터 사용 여부 (기본값: False)
    
    Returns:
    --------
    trajectory : Trajectory
        생성된 nominal 궤적
    """
    
    if use_GUAM:
        # ====================================================================
        # [GUAM 연동 인터페이스]
        # ====================================================================
        # 여기에 GUAM 연동 코드를 넣으면 됩니다.
        # 
        # 예상 인터페이스:
        #   traj_data = GUAM_API.get_trajectory(
        #       vehicle_type='eVTOL',
        #       movement_type=movement.mov_type,
        #       start_point=(movement.x_boundary, movement.y_boundary, h_min/h_max),
        #       end_point=(0, 0, h_max/h_min),
        #       dt=dt
        #   )
        #   
        #   return Trajectory(
        #       t=traj_data['time'],
        #       x_nom=traj_data['x'],
        #       y_nom=traj_data['y'],
        #       h_nom=traj_data['altitude']
        #   )
        # ====================================================================
        raise NotImplementedError("GUAM 연동 기능은 아직 구현되지 않았습니다.")
    
    # 현재 구현: 단순 선형 궤적
    T_leg = R / V_mean  # 비행 시간 [s]
    n_steps = int(np.ceil(T_leg / dt)) + 1
    t = np.linspace(0, T_leg, n_steps)
    
    if movement.mov_type == 'arrival':
        # 경계 → 버티포트 (0, 0)
        x_start, y_start = movement.x_boundary, movement.y_boundary
        x_end, y_end = 0.0, 0.0
        
        # 고도 프로파일: h_max → h_min (선형 강하)
        h_nom = np.linspace(h_max, h_min, n_steps)
    else:  # 'departure'
        # 버티포트 (0, 0) → 경계
        x_start, y_start = 0.0, 0.0
        x_end, y_end = movement.x_boundary, movement.y_boundary
        
        # 고도 프로파일: h_min → h_max (선형 상승)
        h_nom = np.linspace(h_min, h_max, n_steps)
    
    # 선형 보간
    x_nom = x_start + (x_end - x_start) * (t / T_leg)
    y_nom = y_start + (y_end - y_start) * (t / T_leg)
    
    return Trajectory(
        t=t,
        x_nom=x_nom,
        y_nom=y_nom,
        h_nom=h_nom
    )


# ============================================================================
# 3. 바람/난류 파라미터 샘플링
# ============================================================================

def sample_wind_and_turbulence_params(W_max: float,
                                     sigma_gust_max: float,
                                     tau_turb: float = 10.0) -> WindParams:
    """
    바람/난류 파라미터 랜덤 샘플링
    
    Parameters:
    -----------
    W_max : float
        최대 평균 풍속 [m/s]
    sigma_gust_max : float
        최대 난류 표준편차 [m/s]
    tau_turb : float
        난류 시상수 [s] (Ornstein-Uhlenbeck process)
    
    Returns:
    --------
    wind_params : WindParams
        샘플링된 바람/난류 파라미터
    """
    W_mean_x = np.random.uniform(-W_max, W_max)
    W_mean_y = np.random.uniform(-W_max, W_max)
    sigma_gust = np.random.uniform(0, sigma_gust_max)
    
    return WindParams(
        W_mean_x=W_mean_x,
        W_mean_y=W_mean_y,
        sigma_gust=sigma_gust,
        tau_turb=tau_turb
    )


# ============================================================================
# 4. 난류/바람 적용 + TSE 안전성 체크
# ============================================================================

def generate_OU_process(n_steps: int, dt: float, sigma: float, tau: float) -> np.ndarray:
    """
    Ornstein-Uhlenbeck (OU) process 생성 (1차 Markov 난류 모델)
    
    dX = -X/tau * dt + sigma * sqrt(2/tau) * dW
    
    Parameters:
    -----------
    n_steps : int
        시간 step 수
    dt : float
        시간 간격 [s]
    sigma : float
        평형 상태 표준편차
    tau : float
        시상수 [s]
    
    Returns:
    --------
    X : np.ndarray
        OU process 시계열
    """
    X = np.zeros(n_steps)
    for i in range(1, n_steps):
        dW = np.random.randn() * np.sqrt(dt)
        X[i] = X[i-1] - (X[i-1] / tau) * dt + sigma * np.sqrt(2.0 / tau) * dW
    return X


def apply_disturbances_and_check_TSE(nom_traj: Trajectory,
                                     wind_params: WindParams,
                                     dt: float,
                                     tse_limit: float = 300.0,
                                     h_min: float = 300.0,
                                     h_max: float = 600.0,
                                     use_GUAM_TSE: bool = False) -> Tuple[Trajectory, SafetyCheck]:
    """
    난류/바람 외란 적용 및 TSE 안전성 체크
    
    ※ 향후 GUAM 시뮬레이터 연동 시, GUAM에서 직접 계산된 TSE와 실제 궤적을
    ※ 받아와서 사용할 수 있도록 인터페이스 설계됨.
    ※ use_GUAM_TSE=True일 때는 GUAM 출력 데이터를 직접 사용.
    
    Parameters:
    -----------
    nom_traj : Trajectory
        Nominal 궤적
    wind_params : WindParams
        바람/난류 파라미터
    dt : float
        시간 step [s]
    tse_limit : float
        수평 TSE 한계값 [m]
    h_min, h_max : float
        고도 범위 [m]
    use_GUAM_TSE : bool
        GUAM TSE 데이터 사용 여부 (기본값: False)
    
    Returns:
    --------
    real_traj : Trajectory
        실제 궤적 (난류 포함)
    safety_check : SafetyCheck
        안전성 체크 결과
    """
    
    if use_GUAM_TSE:
        # ====================================================================
        # [GUAM TSE 연동 인터페이스]
        # ====================================================================
        # GUAM에서 직접 계산된 TSE와 실제 궤적을 받아올 수 있습니다.
        # 
        # 예상 인터페이스:
        #   guam_tse_data = GUAM_API.get_TSE_data(
        #       trajectory_id=nom_traj.id,
        #       wind_condition=wind_params,
        #       turbulence_model='moderate'
        #   )
        #   
        #   x_real = guam_tse_data['x_actual']
        #   y_real = guam_tse_data['y_actual']
        #   h_real = guam_tse_data['h_actual']
        #   tse_values = guam_tse_data['lateral_TSE']
        # ====================================================================
        raise NotImplementedError("GUAM TSE 연동 기능은 아직 구현되지 않았습니다.")
    
    # 현재 구현: 단순 난류 모델
    n_steps = len(nom_traj.t)
    
    # OU process로 난류 생성 (x, y, h 각각 독립적)
    gust_x = generate_OU_process(n_steps, dt, wind_params.sigma_gust, wind_params.tau_turb)
    gust_y = generate_OU_process(n_steps, dt, wind_params.sigma_gust, wind_params.tau_turb)
    gust_h = generate_OU_process(n_steps, dt, wind_params.sigma_gust * 0.5, wind_params.tau_turb)
    
    # 바람에 의한 누적 drift (적분 효과)
    # 단순화: 평균 바람이 시간에 따라 누적 이동을 일으킴
    wind_drift_x = wind_params.W_mean_x * nom_traj.t
    wind_drift_y = wind_params.W_mean_y * nom_traj.t
    
    # 제어 오차 추가 (작은 랜덤 노이즈)
    control_error_x = np.random.randn(n_steps) * 5.0  # ±5m 정도의 제어 오차
    control_error_y = np.random.randn(n_steps) * 5.0
    control_error_h = np.random.randn(n_steps) * 2.0  # ±2m 정도의 고도 제어 오차
    
    # 실제 궤적 = nominal + 외란
    x_real = nom_traj.x_nom + wind_drift_x + gust_x + control_error_x
    y_real = nom_traj.y_nom + wind_drift_y + gust_y + control_error_y
    h_real = nom_traj.h_nom + gust_h + control_error_h
    
    # TSE 계산 (수평 거리)
    lateral_tse = np.sqrt((x_real - nom_traj.x_nom)**2 + (y_real - nom_traj.y_nom)**2)
    max_lateral_tse = np.max(lateral_tse)
    
    # 고도 이탈 계산
    vertical_dev_low = np.maximum(0, h_min - h_real)  # 하한선 위반
    vertical_dev_high = np.maximum(0, h_real - h_max)  # 상한선 위반
    vertical_dev = np.maximum(vertical_dev_low, vertical_dev_high)
    max_vertical_dev = np.max(vertical_dev)
    
    # 안전성 판단
    lateral_violation = np.any(lateral_tse > tse_limit)
    vertical_violation = np.any((h_real < h_min) | (h_real > h_max))
    is_safe = not (lateral_violation or vertical_violation)
    
    # 위반 발생 시간 찾기
    violation_time = -1.0
    if not is_safe:
        if lateral_violation:
            violation_idx = np.where(lateral_tse > tse_limit)[0][0]
            violation_time = nom_traj.t[violation_idx]
        elif vertical_violation:
            violation_idx = np.where((h_real < h_min) | (h_real > h_max))[0][0]
            violation_time = nom_traj.t[violation_idx]
    
    real_traj = Trajectory(
        t=nom_traj.t,
        x_nom=nom_traj.x_nom,
        y_nom=nom_traj.y_nom,
        h_nom=nom_traj.h_nom,
        x_real=x_real,
        y_real=y_real,
        h_real=h_real
    )
    
    safety_check = SafetyCheck(
        is_safe=is_safe,
        max_lateral_tse=max_lateral_tse,
        max_vertical_dev=max_vertical_dev,
        violation_time=violation_time
    )
    
    return real_traj, safety_check


# ============================================================================
# 5. 단일 시뮬레이션 실행 (R, λ 조합)
# ============================================================================

def run_simulation_for_R_lambda(R: float,
                                lambda_mvh: float,
                                V_mean: float,
                                W_max: float,
                                sigma_gust_max: float,
                                tse_limit: float,
                                h_min: float,
                                h_max: float,
                                dt: float,
                                T_sim: float,
                                N_mc: int,
                                verbose: bool = False) -> Dict:
    """
    단일 (R, λ) 조합에 대한 Monte Carlo 시뮬레이션 실행
    
    Parameters:
    -----------
    R : float
        공역 반지름 [m]
    lambda_mvh : float
        교통량 [movements/hour]
    V_mean : float
        평균 속도 [m/s]
    W_max : float
        최대 평균 풍속 [m/s]
    sigma_gust_max : float
        최대 난류 표준편차 [m/s]
    tse_limit : float
        TSE 한계값 [m]
    h_min, h_max : float
        고도 범위 [m]
    dt : float
        시간 step [s]
    T_sim : float
        시뮬레이션 시간 [s]
    N_mc : int
        Monte Carlo 반복 횟수
    verbose : bool
        진행 상황 출력 여부
    
    Returns:
    --------
    results : Dict
        시뮬레이션 결과
    """
    
    total_flights = 0
    unsafe_flights = 0
    all_max_tse = []
    all_max_vdev = []
    
    for mc_iter in range(N_mc):
        if verbose and (mc_iter + 1) % 10 == 0:
            print(f"  MC iteration {mc_iter + 1}/{N_mc}")
        
        # movements 생성
        movements = generate_movements(lambda_mvh, T_sim, R)
        
        if len(movements) == 0:
            continue
        
        # 각 movement에 대해 궤적 생성 및 안전성 체크
        for movement in movements:
            total_flights += 1
            
            # Nominal 궤적 생성
            nom_traj = generate_nominal_trajectory(
                movement=movement,
                R=R,
                V_mean=V_mean,
                dt=dt,
                h_min=h_min,
                h_max=h_max,
                use_GUAM=False
            )
            
            # 바람/난류 파라미터 샘플링
            wind_params = sample_wind_and_turbulence_params(
                W_max=W_max,
                sigma_gust_max=sigma_gust_max
            )
            
            # 외란 적용 및 TSE 체크
            real_traj, safety_check = apply_disturbances_and_check_TSE(
                nom_traj=nom_traj,
                wind_params=wind_params,
                dt=dt,
                tse_limit=tse_limit,
                h_min=h_min,
                h_max=h_max,
                use_GUAM_TSE=False
            )
            
            # 통계 수집
            all_max_tse.append(safety_check.max_lateral_tse)
            all_max_vdev.append(safety_check.max_vertical_dev)
            
            if not safety_check.is_safe:
                unsafe_flights += 1
    
    # 결과 집계
    if total_flights > 0:
        P_TSE_violation = unsafe_flights / total_flights
        mean_max_tse = np.mean(all_max_tse)
        std_max_tse = np.std(all_max_tse)
        mean_max_vdev = np.mean(all_max_vdev)
    else:
        P_TSE_violation = 0.0
        mean_max_tse = 0.0
        std_max_tse = 0.0
        mean_max_vdev = 0.0
    
    results = {
        'R': R,
        'lambda': lambda_mvh,
        'total_flights': total_flights,
        'unsafe_flights': unsafe_flights,
        'P_TSE_violation': P_TSE_violation,
        'P_safe': 1.0 - P_TSE_violation,
        'mean_max_tse': mean_max_tse,
        'std_max_tse': std_max_tse,
        'mean_max_vdev': mean_max_vdev,
        'all_max_tse': all_max_tse,
        'all_max_vdev': all_max_vdev
    }
    
    return results


# ============================================================================
# 6. 전체 시뮬레이션 실행 (여러 R, λ 조합)
# ============================================================================

def run_full_simulation(R_list: List[float],
                       lambda_list: List[float],
                       V_mean: float,
                       W_max: float,
                       sigma_gust_max: float,
                       tse_limit: float,
                       h_min: float,
                       h_max: float,
                       dt: float,
                       T_sim: float,
                       N_mc: int,
                       verbose: bool = True) -> List[Dict]:
    """
    여러 (R, λ) 조합에 대한 전체 시뮬레이션 실행
    
    Parameters:
    -----------
    R_list : List[float]
        시험할 공역 반지름 리스트 [m]
    lambda_list : List[float]
        시험할 교통량 리스트 [movements/hour]
    ... (나머지 파라미터는 run_simulation_for_R_lambda와 동일)
    
    Returns:
    --------
    all_results : List[Dict]
        모든 조합에 대한 시뮬레이션 결과 리스트
    """
    
    all_results = []
    total_combinations = len(R_list) * len(lambda_list)
    current = 0
    
    for R in R_list:
        for lambda_mvh in lambda_list:
            current += 1
            if verbose:
                print(f"\n[{current}/{total_combinations}] R={R}m, λ={lambda_mvh} mvh/hr")
            
            results = run_simulation_for_R_lambda(
                R=R,
                lambda_mvh=lambda_mvh,
                V_mean=V_mean,
                W_max=W_max,
                sigma_gust_max=sigma_gust_max,
                tse_limit=tse_limit,
                h_min=h_min,
                h_max=h_max,
                dt=dt,
                T_sim=T_sim,
                N_mc=N_mc,
                verbose=verbose
            )
            
            all_results.append(results)
            
            if verbose:
                print(f"  Total flights: {results['total_flights']}")
                print(f"  Unsafe flights: {results['unsafe_flights']}")
                print(f"  P(TSE violation): {results['P_TSE_violation']:.4f}")
                print(f"  P(safe): {results['P_safe']:.4f}")
    
    return all_results


# ============================================================================
# 7. 결과 시각화
# ============================================================================

def plot_results(all_results: List[Dict], 
                R_list: List[float], 
                lambda_list: List[float],
                save_path: str = None):
    """
    시뮬레이션 결과 시각화
    
    Parameters:
    -----------
    all_results : List[Dict]
        시뮬레이션 결과 리스트
    R_list : List[float]
        공역 반지름 리스트 [m]
    lambda_list : List[float]
        교통량 리스트 [movements/hour]
    save_path : str, optional
        저장 경로 (None이면 화면에만 표시)
    """
    
    # 결과를 2D 배열로 변환
    n_R = len(R_list)
    n_lambda = len(lambda_list)
    
    P_violation_matrix = np.zeros((n_R, n_lambda))
    P_safe_matrix = np.zeros((n_R, n_lambda))
    
    idx = 0
    for i, R in enumerate(R_list):
        for j, lam in enumerate(lambda_list):
            P_violation_matrix[i, j] = all_results[idx]['P_TSE_violation']
            P_safe_matrix[i, j] = all_results[idx]['P_safe']
            idx += 1
    
    # 플롯 생성
    fig, axes = plt.subplots(1, 2, figsize=(14, 5))
    
    # 1. TSE Violation 확률 히트맵
    im1 = axes[0].imshow(P_violation_matrix, cmap='hot', aspect='auto', origin='lower')
    axes[0].set_xticks(range(n_lambda))
    axes[0].set_yticks(range(n_R))
    axes[0].set_xticklabels([f'{lam:.0f}' for lam in lambda_list])
    axes[0].set_yticklabels([f'{R:.0f}' for R in R_list])
    axes[0].set_xlabel('Traffic Rate λ [movements/hour]', fontsize=12)
    axes[0].set_ylabel('Airspace Radius R [m]', fontsize=12)
    axes[0].set_title('P(TSE Violation)', fontsize=14, fontweight='bold')
    
    # 값 표시
    for i in range(n_R):
        for j in range(n_lambda):
            text = axes[0].text(j, i, f'{P_violation_matrix[i, j]:.3f}',
                              ha="center", va="center", color="white", fontsize=9)
    
    cbar1 = plt.colorbar(im1, ax=axes[0])
    cbar1.set_label('Violation Probability', fontsize=11)
    
    # 2. 안전 확률 히트맵
    im2 = axes[1].imshow(P_safe_matrix, cmap='RdYlGn', aspect='auto', origin='lower', vmin=0, vmax=1)
    axes[1].set_xticks(range(n_lambda))
    axes[1].set_yticks(range(n_R))
    axes[1].set_xticklabels([f'{lam:.0f}' for lam in lambda_list])
    axes[1].set_yticklabels([f'{R:.0f}' for R in R_list])
    axes[1].set_xlabel('Traffic Rate λ [movements/hour]', fontsize=12)
    axes[1].set_ylabel('Airspace Radius R [m]', fontsize=12)
    axes[1].set_title('P(Safe Flight)', fontsize=14, fontweight='bold')
    
    # 값 표시
    for i in range(n_R):
        for j in range(n_lambda):
            text = axes[1].text(j, i, f'{P_safe_matrix[i, j]:.3f}',
                              ha="center", va="center", color="black", fontsize=9)
    
    cbar2 = plt.colorbar(im2, ax=axes[1])
    cbar2.set_label('Safety Probability', fontsize=11)
    
    plt.tight_layout()
    
    if save_path:
        plt.savefig(save_path, dpi=300, bbox_inches='tight')
        print(f"\n그래프가 저장되었습니다: {save_path}")
    
    plt.show()


def plot_tse_distribution(all_results: List[Dict], 
                         R_list: List[float], 
                         lambda_list: List[float],
                         save_path: str = None):
    """
    TSE 분포 시각화
    
    Parameters:
    -----------
    all_results : List[Dict]
        시뮬레이션 결과 리스트
    R_list : List[float]
        공역 반지름 리스트 [m]
    lambda_list : List[float]
        교통량 리스트 [movements/hour]
    save_path : str, optional
        저장 경로
    """
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    # 각 조합별로 TSE 분포 플롯
    for result in all_results:
        R = result['R']
        lam = result['lambda']
        tse_values = result['all_max_tse']
        
        if len(tse_values) > 0:
            label = f"R={R:.0f}m, λ={lam:.0f}"
            ax.hist(tse_values, bins=30, alpha=0.5, label=label, density=True)
    
    # TSE 한계선 표시
    ax.axvline(x=300, color='red', linestyle='--', linewidth=2, label='TSE Limit (300m)')
    
    ax.set_xlabel('Maximum Lateral TSE [m]', fontsize=12)
    ax.set_ylabel('Probability Density', fontsize=12)
    ax.set_title('Distribution of Maximum Lateral TSE', fontsize=14, fontweight='bold')
    ax.legend(fontsize=9)
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    
    if save_path:
        plt.savefig(save_path, dpi=300, bbox_inches='tight')
        print(f"TSE 분포 그래프가 저장되었습니다: {save_path}")
    
    plt.show()


# ============================================================================
# 8. 메인 실행 부분
# ============================================================================

def main():
    """
    메인 실행 함수
    """
    
    print("=" * 80)
    print("UAM 버티포트 공역 시뮬레이션 (TSE 안전성 평가)")
    print("=" * 80)
    
    # ========================================================================
    # 시뮬레이션 파라미터 설정
    # ========================================================================
    
    # 공역 파라미터
    R_list = [1000, 1500, 2000]  # 공역 반지름 [m]
    
    # 교통량 파라미터
    lambda_list = [10, 20, 30, 40]  # 교통량 [movements/hour]
    
    # 비행 파라미터
    V_mean = 50.0  # 평균 속도 [m/s]
    
    # 바람/난류 파라미터
    W_max = 8.0  # 최대 평균 풍속 [m/s]
    sigma_gust_max = 5.0  # 최대 난류 표준편차 [m/s]
    
    # 안전성 기준
    tse_limit = 300.0  # TSE 한계값 [m]
    h_min = 300.0  # 최소 고도 [m]
    h_max = 600.0  # 최대 고도 [m]
    
    # 시뮬레이션 설정
    dt = 1.0  # 시간 step [s]
    T_sim = 8 * 3600  # 총 시뮬레이션 시간 [s] (8시간)
    N_mc = 100  # Monte Carlo 반복 횟수
    
    # ========================================================================
    # 시뮬레이션 실행
    # ========================================================================
    
    print("\n[시뮬레이션 파라미터]")
    print(f"  공역 반지름 R: {R_list} m")
    print(f"  교통량 λ: {lambda_list} movements/hour")
    print(f"  평균 속도: {V_mean} m/s")
    print(f"  최대 풍속: {W_max} m/s")
    print(f"  최대 난류 σ: {sigma_gust_max} m/s")
    print(f"  TSE 한계: {tse_limit} m")
    print(f"  고도 범위: {h_min}~{h_max} m")
    print(f"  시뮬레이션 시간: {T_sim/3600:.1f} hours")
    print(f"  Monte Carlo 반복: {N_mc}")
    print(f"  시간 step: {dt} s")
    
    all_results = run_full_simulation(
        R_list=R_list,
        lambda_list=lambda_list,
        V_mean=V_mean,
        W_max=W_max,
        sigma_gust_max=sigma_gust_max,
        tse_limit=tse_limit,
        h_min=h_min,
        h_max=h_max,
        dt=dt,
        T_sim=T_sim,
        N_mc=N_mc,
        verbose=True
    )
    
    # ========================================================================
    # 결과 출력
    # ========================================================================
    
    print("\n" + "=" * 80)
    print("시뮬레이션 결과 요약")
    print("=" * 80)
    print(f"{'R [m]':<10} {'λ [mvh/h]':<12} {'Total':<10} {'Unsafe':<10} {'P(viol)':<12} {'P(safe)':<12}")
    print("-" * 80)
    
    for result in all_results:
        print(f"{result['R']:<10.0f} {result['lambda']:<12.0f} "
              f"{result['total_flights']:<10} {result['unsafe_flights']:<10} "
              f"{result['P_TSE_violation']:<12.4f} {result['P_safe']:<12.4f}")
    
    # ========================================================================
    # 결과 시각화
    # ========================================================================
    
    print("\n결과 시각화 중...")
    
    plot_results(all_results, R_list, lambda_list, 
                save_path='/home/user/webapp/simulation_results.png')
    
    plot_tse_distribution(all_results, R_list, lambda_list,
                         save_path='/home/user/webapp/tse_distribution.png')
    
    print("\n시뮬레이션 완료!")
    print("=" * 80)


if __name__ == "__main__":
    main()
