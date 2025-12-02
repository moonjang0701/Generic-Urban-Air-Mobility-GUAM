#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
커스텀 시뮬레이션 예제

simulation_config.py를 수정하지 않고, 코드에서 직접 파라미터를 설정하는 예제입니다.
"""

from uam_vertiport_simulation import (
    run_full_simulation, 
    plot_results, 
    plot_tse_distribution
)


def example_1_basic():
    """
    예제 1: 기본 시뮬레이션
    - 단일 공역 반지름 (1500m)
    - 적은 교통량 (10, 20 movements/hour)
    - 빠른 실행을 위해 N_mc=50
    """
    print("\n" + "=" * 80)
    print("예제 1: 기본 시뮬레이션 (빠른 실행)")
    print("=" * 80)
    
    results = run_full_simulation(
        R_list=[1500],              # 공역 반지름 1500m만 테스트
        lambda_list=[10, 20],       # 교통량 10, 20 mvh/h
        V_mean=50.0,                # 평균 속도 50 m/s
        W_max=5.0,                  # 최대 풍속 5 m/s (약한 바람)
        sigma_gust_max=3.0,         # 최대 난류 3 m/s (약한 난류)
        tse_limit=300.0,            # TSE 한계 300m
        h_min=300.0,                # 최소 고도 300m
        h_max=600.0,                # 최대 고도 600m
        dt=1.0,                     # 시간 step 1초
        T_sim=8*3600,               # 8시간
        N_mc=50,                    # Monte Carlo 50회 (빠른 실행)
        verbose=True
    )
    
    # 결과 출력
    print("\n결과:")
    for r in results:
        print(f"R={r['R']}m, λ={r['lambda']} mvh/h: "
              f"P(safe)={r['P_safe']:.4f}, "
              f"total={r['total_flights']}, "
              f"unsafe={r['unsafe_flights']}")
    
    return results


def example_2_wind_sensitivity():
    """
    예제 2: 바람 민감도 분석
    - 고정된 공역/교통량
    - 다양한 풍속 조건 비교
    """
    print("\n" + "=" * 80)
    print("예제 2: 바람 민감도 분석")
    print("=" * 80)
    
    wind_conditions = [
        ("약한 바람", 3.0, 2.0),
        ("보통 바람", 6.0, 4.0),
        ("강한 바람", 10.0, 6.0),
    ]
    
    all_results = []
    
    for condition_name, w_max, sigma_max in wind_conditions:
        print(f"\n[{condition_name}] W_max={w_max} m/s, σ={sigma_max} m/s")
        
        results = run_full_simulation(
            R_list=[1500],
            lambda_list=[20],
            V_mean=50.0,
            W_max=w_max,
            sigma_gust_max=sigma_max,
            tse_limit=300.0,
            h_min=300.0,
            h_max=600.0,
            dt=1.0,
            T_sim=8*3600,
            N_mc=50,
            verbose=False
        )
        
        all_results.append((condition_name, results[0]))
    
    # 비교 결과
    print("\n" + "=" * 80)
    print("바람 조건별 안전성 비교")
    print("=" * 80)
    print(f"{'조건':<15} {'W_max':<10} {'σ_max':<10} {'P(safe)':<12} {'P(violation)':<12}")
    print("-" * 80)
    
    for i, (condition_name, result) in enumerate(all_results):
        w_max, sigma_max = wind_conditions[i][1], wind_conditions[i][2]
        print(f"{condition_name:<15} {w_max:<10.1f} {sigma_max:<10.1f} "
              f"{result['P_safe']:<12.4f} {result['P_TSE_violation']:<12.4f}")
    
    return all_results


def example_3_airspace_size_optimization():
    """
    예제 3: 최적 공역 크기 탐색
    - 여러 공역 반지름 비교
    - 고정된 교통량
    """
    print("\n" + "=" * 80)
    print("예제 3: 최적 공역 크기 탐색")
    print("=" * 80)
    
    results = run_full_simulation(
        R_list=[800, 1000, 1200, 1500, 1800, 2000],  # 다양한 반지름
        lambda_list=[30],                             # 고정 교통량
        V_mean=50.0,
        W_max=6.0,
        sigma_gust_max=4.0,
        tse_limit=300.0,
        h_min=300.0,
        h_max=600.0,
        dt=1.0,
        T_sim=8*3600,
        N_mc=50,
        verbose=False
    )
    
    # 최적 반지름 찾기
    print("\n" + "=" * 80)
    print("공역 반지름별 안전성")
    print("=" * 80)
    print(f"{'R [m]':<10} {'P(safe)':<12} {'평균 TSE [m]':<15} {'평가'}")
    print("-" * 80)
    
    best_R = None
    best_P_safe = 0
    
    for r in results:
        evaluation = ""
        if r['P_safe'] >= 0.8:
            evaluation = "✓ 우수"
        elif r['P_safe'] >= 0.5:
            evaluation = "○ 보통"
        else:
            evaluation = "✗ 부족"
        
        print(f"{r['R']:<10.0f} {r['P_safe']:<12.4f} "
              f"{r['mean_max_tse']:<15.2f} {evaluation}")
        
        if r['P_safe'] > best_P_safe:
            best_P_safe = r['P_safe']
            best_R = r['R']
    
    print(f"\n최적 공역 반지름: R={best_R}m (P(safe)={best_P_safe:.4f})")
    
    return results


def example_4_high_traffic():
    """
    예제 4: 고밀도 교통 시나리오
    - 높은 교통량 테스트
    """
    print("\n" + "=" * 80)
    print("예제 4: 고밀도 교통 시나리오")
    print("=" * 80)
    
    results = run_full_simulation(
        R_list=[1500],
        lambda_list=[40, 60, 80, 100],  # 고밀도 교통
        V_mean=55.0,                     # 조금 더 빠른 속도
        W_max=5.0,
        sigma_gust_max=3.0,
        tse_limit=300.0,
        h_min=300.0,
        h_max=600.0,
        dt=1.0,
        T_sim=8*3600,
        N_mc=50,
        verbose=False
    )
    
    print("\n" + "=" * 80)
    print("고밀도 교통 안전성 평가")
    print("=" * 80)
    print(f"{'λ [mvh/h]':<12} {'총 비행':<12} {'Unsafe':<10} {'P(safe)':<12} {'용량 평가'}")
    print("-" * 80)
    
    for r in results:
        capacity_eval = ""
        if r['P_safe'] >= 0.8:
            capacity_eval = "충분한 용량"
        elif r['P_safe'] >= 0.5:
            capacity_eval = "제한적 용량"
        else:
            capacity_eval = "용량 초과"
        
        print(f"{r['lambda']:<12.0f} {r['total_flights']:<12} "
              f"{r['unsafe_flights']:<10} {r['P_safe']:<12.4f} {capacity_eval}")
    
    # 추정 용량 계산 (P(safe) >= 0.8 기준)
    safe_traffic_levels = [r['lambda'] for r in results if r['P_safe'] >= 0.8]
    if safe_traffic_levels:
        max_safe_lambda = max(safe_traffic_levels)
        print(f"\n추정 안전 용량: ~{max_safe_lambda} movements/hour")
        print(f"  (8시간 기준: ~{int(8*max_safe_lambda)} movements/day)")
    else:
        print("\n⚠ 모든 교통량 수준에서 안전성이 부족합니다.")
        print("  → 운용 파라미터를 조정하거나 공역 설계를 재검토하세요.")
    
    return results


def main():
    """
    메인 함수: 예제 선택 실행
    """
    print("=" * 80)
    print("UAM 버티포트 시뮬레이션 - 커스텀 예제")
    print("=" * 80)
    print("\n사용 가능한 예제:")
    print("  1. 기본 시뮬레이션 (빠른 실행)")
    print("  2. 바람 민감도 분석")
    print("  3. 최적 공역 크기 탐색")
    print("  4. 고밀도 교통 시나리오")
    print("  5. 모든 예제 실행")
    
    # 자동 실행 모드: 예제 1만 실행
    # 원하는 예제를 직접 호출하려면 아래 주석을 해제하세요
    
    print("\n자동 실행 모드: 예제 1 실행 중...")
    example_1_basic()
    
    # 다른 예제를 실행하려면 아래 주석을 해제하세요:
    # example_2_wind_sensitivity()
    # example_3_airspace_size_optimization()
    # example_4_high_traffic()
    
    print("\n" + "=" * 80)
    print("예제 실행 완료!")
    print("=" * 80)
    print("\n다른 예제를 실행하려면 코드를 수정하세요:")
    print("  - example_2_wind_sensitivity()")
    print("  - example_3_airspace_size_optimization()")
    print("  - example_4_high_traffic()")


if __name__ == "__main__":
    main()
