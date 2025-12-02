# 버그 수정 요약

## 문제

모든 비행이 다음 에러로 실패:
```
FAILED: 인덱스가 배열 요소 개수를 초과합니다. 인덱스는 2을(를) 초과해서는 안 됩니다.
```

## 원인

GUAM의 `logsout` 출력 구조를 잘못 파싱:

**❌ 잘못된 코드:**
```matlab
logsout = simOut.logsout;
pos_data = logsout.getElement('Pos_bIi').Values;  % ← 이 방식은 작동 안 함!
```

**✅ 올바른 코드:**
```matlab
logsout = evalin('base', 'logsout');
X_NED_data = logsout{1}.Values.X_NED;  % ← GUAM 표준 방식
```

## 해결 방법

### 1. `logsout` 구조 이해

GUAM은 `logsout`을 **cell array**로 반환:
- `logsout{1}`: 첫 번째 로깅 그룹
- `logsout{1}.Values`: 실제 데이터 구조체
- `logsout{1}.Values.X_NED`: 위치 데이터 (timeseries)

### 2. 데이터 추출 방법

```matlab
% GUAM 실행
sim(model);  % simOut 없이 직접 실행

% Base workspace에서 logsout 가져오기
logsout = evalin('base', 'logsout');

% 위치 데이터 추출 (feet 단위!)
X_NED_data = logsout{1}.Values.X_NED;
time = X_NED_data.Time;
pos_NED_ft = X_NED_data.Data;  % [North, East, Down] in feet

% Feet → Meters 변환
ft2m = 0.3048;
pos_N = pos_NED_ft(:,1) * ft2m;
pos_E = pos_NED_ft(:,2) * ft2m;
pos_D = pos_NED_ft(:,3) * ft2m;
altitude = -pos_D;  % Down → Altitude (양수 = 위로)
```

### 3. 다른 데이터 추출

```matlab
% 속도 (body frame, feet/s)
Vb_data = logsout{1}.Values.Vb;
vel_body = Vb_data.Data;  % [u, v, w]

% 자세 (Euler angles, radians)
Euler_data = logsout{1}.Values.Euler;
euler = Euler_data.Data;  % [roll, pitch, yaw]
```

## 수정된 파일

1. **`Exec_Scripts/run_vertiport_throughput_MC_QUICK.m`**
   - Line 197-208: logsout 파싱 수정
   - feet → meters 변환 추가

2. **`Exec_Scripts/run_vertiport_throughput_MC.m`**
   - Line 180-193: logsout 파싱 수정
   - feet → meters 변환 추가

3. **`Exec_Scripts/debug_GUAM_output.m`** (새 파일)
   - GUAM 출력 구조 디버깅 도구
   - logsout의 모든 요소 이름 출력
   - 위치 데이터 추출 테스트

## 테스트

수정 후 다시 실행:

```matlab
cd /home/user/webapp/Exec_Scripts
run_vertiport_throughput_MC_QUICK
```

**예상 결과**:
- ✅ 비행이 정상적으로 실행됨
- ✅ TSE 계산 성공
- ✅ 안전성 판단 가능

## 추가 주의사항

### 1. 단위 변환

GUAM은 **feet/slug** 단위계를 사용:
- 거리: feet → meters (×0.3048)
- 속도: feet/s → m/s (×0.3048)
- 각도: radians (변환 불필요)

### 2. NED 좌표계

GUAM은 **NED (North-East-Down)** 좌표계 사용:
- North: +X (앞)
- East: +Y (오른쪽)
- Down: +Z (아래)

**Altitude = -Down** (음수 → 양수로 변환)

### 3. logsout 접근 방법

두 가지 접근 방법:

**방법 1: Base workspace** (✅ 권장)
```matlab
sim(model);
logsout = evalin('base', 'logsout');
```

**방법 2: simOut 반환값** (❌ 작동 안 함)
```matlab
simOut = sim(model, 'ReturnWorkspaceOutputs', 'on');
logsout = simOut.logsout;  % ← 구조가 다름!
```

→ **방법 1 사용 필수!**

## 참고 파일

GUAM 기존 예제에서 logsout 사용 패턴:
- `Exec_Scripts/exam_Paper_Safety_Envelope_Implementation.m` (Line 92-95)
- `Exec_Scripts/run_single_MC_simulation.m` (Line 89-90)
- `Exec_Scripts/Exec_Demo_Animate_SimOut.m` (Line 44)

## Git 커밋

```bash
commit 3ba2130
Fix GUAM logsout parsing: use logsout{1}.Values.X_NED

- Changed from logsout.getElement('Pos_bIi') to logsout{1}.Values.X_NED
- Following GUAM standard output structure from existing examples
- Added unit conversion from feet to meters (GUAM outputs in feet)
- Added debug_GUAM_output.m for troubleshooting output structure
```

---

**문제 해결됨!** 이제 시뮬레이션이 정상적으로 작동할 것입니다. 🎉
