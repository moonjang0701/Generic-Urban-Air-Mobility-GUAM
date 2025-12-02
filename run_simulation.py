#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
UAM 버티포트 시뮬레이션 실행 스크립트

simulation_config.py의 파라미터를 사용하여 시뮬레이션을 실행합니다.
"""

import sys
import os

# 설정 파일 import
import simulation_config as cfg
from uam_vertiport_simulation import run_full_simulation, plot_results, plot_tse_distribution


def main():
    """
    메인 실행 함수
    """
    
    print("=" * 80)
    print("UAM 버티포트 공역 시뮬레이션 (TSE 안전성 평가)")
    print("=" * 80)
    
    # ========================================================================
    # 1. 파라미터 검증
    # ========================================================================
    
    print("\n[1/4] 파라미터 검증 중...")
    try:
        cfg.validate_config()
        print("  ✓ 모든 파라미터가 유효합니다.")
    except ValueError as e:
        print(f"  ✗ 오류: {e}")
        sys.exit(1)
    
    # ========================================================================
    # 2. 시뮬레이션 파라미터 출력
    # ========================================================================
    
    print("\n[2/4] 시뮬레이션 파라미터")
    print(f"  공역 반지름 R: {cfg.R_LIST} m")
    print(f"  교통량 λ: {cfg.LAMBDA_LIST} movements/hour")
    print(f"  평균 속도: {cfg.V_MEAN} m/s")
    print(f"  최대 풍속: {cfg.W_MAX} m/s")
    print(f"  최대 난류 σ: {cfg.SIGMA_GUST_MAX} m/s")
    print(f"  난류 시상수 τ: {cfg.TAU_TURB} s")
    print(f"  TSE 한계: {cfg.TSE_LIMIT} m")
    print(f"  고도 범위: {cfg.H_MIN}~{cfg.H_MAX} m")
    print(f"  시뮬레이션 시간: {cfg.T_SIM/3600:.1f} hours")
    print(f"  Monte Carlo 반복: {cfg.N_MC}")
    print(f"  시간 step: {cfg.DT} s")
    print(f"  도착/출발 비율: {cfg.ARRIVAL_RATIO}")
    
    # 시뮬레이션 예상 총 비행 수 계산
    total_combinations = len(cfg.R_LIST) * len(cfg.LAMBDA_LIST)
    avg_lambda = sum(cfg.LAMBDA_LIST) / len(cfg.LAMBDA_LIST)
    expected_flights_per_mc = int(8 * avg_lambda)
    total_expected_flights = expected_flights_per_mc * cfg.N_MC * total_combinations
    
    print(f"\n  예상 총 시뮬레이션 조합: {total_combinations}")
    print(f"  예상 총 비행 수: ~{total_expected_flights:,}")
    print(f"  예상 실행 시간: ~{total_expected_flights * 0.001:.1f}초")
    
    # ========================================================================
    # 3. 시뮬레이션 실행
    # ========================================================================
    
    print("\n[3/4] 시뮬레이션 실행 중...")
    
    all_results = run_full_simulation(
        R_list=cfg.R_LIST,
        lambda_list=cfg.LAMBDA_LIST,
        V_mean=cfg.V_MEAN,
        W_max=cfg.W_MAX,
        sigma_gust_max=cfg.SIGMA_GUST_MAX,
        tse_limit=cfg.TSE_LIMIT,
        h_min=cfg.H_MIN,
        h_max=cfg.H_MAX,
        dt=cfg.DT,
        T_sim=cfg.T_SIM,
        N_mc=cfg.N_MC,
        verbose=cfg.VERBOSE
    )
    
    # ========================================================================
    # 4. 결과 출력 및 시각화
    # ========================================================================
    
    print("\n[4/4] 결과 요약 및 시각화")
    print("\n" + "=" * 80)
    print("시뮬레이션 결과 요약")
    print("=" * 80)
    print(f"{'R [m]':<10} {'λ [mvh/h]':<12} {'Total':<10} {'Unsafe':<10} {'P(viol)':<12} {'P(safe)':<12}")
    print("-" * 80)
    
    for result in all_results:
        print(f"{result['R']:<10.0f} {result['lambda']:<12.0f} "
              f"{result['total_flights']:<10} {result['unsafe_flights']:<10} "
              f"{result['P_TSE_violation']:<12.4f} {result['P_safe']:<12.4f}")
    
    # 추가 통계
    print("\n" + "=" * 80)
    print("추가 통계")
    print("=" * 80)
    
    # 공역 반지름별 평균 안전 확률
    print("\n[공역 반지름별 평균 안전 확률]")
    for R in cfg.R_LIST:
        R_results = [r for r in all_results if r['R'] == R]
        avg_P_safe = sum(r['P_safe'] for r in R_results) / len(R_results)
        print(f"  R={R}m: P(safe) = {avg_P_safe:.4f} ({avg_P_safe*100:.2f}%)")
    
    # 교통량별 평균 안전 확률
    print("\n[교통량별 평균 안전 확률]")
    for lam in cfg.LAMBDA_LIST:
        lam_results = [r for r in all_results if r['lambda'] == lam]
        avg_P_safe = sum(r['P_safe'] for r in lam_results) / len(lam_results)
        print(f"  λ={lam} mvh/h: P(safe) = {avg_P_safe:.4f} ({avg_P_safe*100:.2f}%)")
    
    # 전체 평균
    overall_avg_P_safe = sum(r['P_safe'] for r in all_results) / len(all_results)
    print(f"\n[전체 평균 안전 확률]")
    print(f"  P(safe) = {overall_avg_P_safe:.4f} ({overall_avg_P_safe*100:.2f}%)")
    
    # ========================================================================
    # 5. 그래프 저장
    # ========================================================================
    
    print("\n" + "=" * 80)
    print("결과 시각화")
    print("=" * 80)
    
    # 출력 경로 생성
    results_path = os.path.join(cfg.OUTPUT_DIR, cfg.PLOT_RESULTS_FILE)
    tse_dist_path = os.path.join(cfg.OUTPUT_DIR, cfg.PLOT_TSE_DIST_FILE)
    
    # 안전성 확률 히트맵
    print(f"\n그래프 생성 중...")
    plot_results(all_results, cfg.R_LIST, cfg.LAMBDA_LIST, save_path=results_path)
    
    # TSE 분포
    plot_tse_distribution(all_results, cfg.R_LIST, cfg.LAMBDA_LIST, save_path=tse_dist_path)
    
    print(f"\n✓ 그래프 저장 완료:")
    print(f"  - {results_path}")
    print(f"  - {tse_dist_path}")
    
    # ========================================================================
    # 6. 완료
    # ========================================================================
    
    print("\n" + "=" * 80)
    print("시뮬레이션 완료!")
    print("=" * 80)
    print(f"\n총 실행 시간: {cfg.N_MC * total_combinations} MC runs")
    print(f"총 비행 수: {sum(r['total_flights'] for r in all_results):,}")
    print(f"총 unsafe 비행: {sum(r['unsafe_flights'] for r in all_results):,}")
    
    # 권장 사항
    print("\n[권장 사항]")
    if overall_avg_P_safe < 0.5:
        print("  ⚠ 안전 확률이 50% 미만입니다.")
        print("  → 바람/난류 파라미터(W_MAX, SIGMA_GUST_MAX)를 낮춰보세요.")
        print("  → 또는 공역 반지름(R)을 줄이거나 속도(V_MEAN)를 높여보세요.")
    elif overall_avg_P_safe < 0.8:
        print("  ⚠ 안전 확률이 80% 미만입니다.")
        print("  → 운용 파라미터 최적화를 고려하세요.")
    else:
        print("  ✓ 안전 확률이 양호합니다.")
    
    if cfg.N_MC < 100:
        print("  ℹ Monte Carlo 반복 횟수가 적습니다.")
        print("  → 더 정확한 결과를 위해 N_MC를 100 이상으로 설정하세요.")
    
    print("\n다음 단계:")
    print("  1. simulation_config.py를 수정하여 파라미터 조정")
    print("  2. NASA GUAM 시뮬레이터 연동 준비")
    print("  3. 충돌/근접 위험(NMAC) 분석 모듈 추가")
    print("  4. 다층 공역 운용 전략 개발")
    
    print("\n" + "=" * 80)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n시뮬레이션이 사용자에 의해 중단되었습니다.")
        sys.exit(0)
    except Exception as e:
        print(f"\n\n오류 발생: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
