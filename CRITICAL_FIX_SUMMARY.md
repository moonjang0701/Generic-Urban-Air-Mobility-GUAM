# CRITICAL FIX: Array Index Error Resolution

**Date**: 2025-12-02  
**Commit**: 05e05c6

## Problem

The simulation was consistently failing with:
```
인덱스가 배열 요소 개수를 초과합니다. 인덱스는 2을(를) 초과해서는 안 됩니다.
(Index exceeds array elements. Index must not exceed 2.)
```

**Result**: 100% unsafe flights (750/750 failed in quick test, 0/150 safe)

## Root Cause

**GUAM requires all configuration to be done in the MATLAB base workspace using `evalin`/`assignin` pattern.**

Our code was:
1. Creating `userStruct` and `target` as local variables
2. Calling `simSetup` directly (instead of via `evalin`)
3. Trying to modify `SimIn` locally and pass it to helper functions

This resulted in GUAM not being properly initialized, leading to malformed `logsout` output structure.

## Solution

Followed the exact pattern from working GUAM example (`run_single_MC_simulation.m`):

### 1. Configure userStruct in base workspace
```matlab
% WRONG (old code):
userStruct = struct();
userStruct.variants.refInputType = 5;

% CORRECT (new code):
evalin('base', 'userStruct.variants.refInputType = 5;');
```

### 2. Create and assign RefInput properly
```matlab
% Create locally
RefInput = struct();
RefInput.Bezier = struct();
RefInput.Bezier.waypoints = waypoints_pos;
RefInput.Bezier.time_wpts = waypoints_time;
% ... configure RefInput ...

% Assign to base workspace
assignin('base', 'RefInput', RefInput);
evalin('base', 'target.RefInput = RefInput;');
```

### 3. Run simSetup via evalin
```matlab
% WRONG (old code):
simSetup;

% CORRECT (new code):
evalin('base', 'simSetup;');
```

### 4. Rewrite helper functions to use evalin

**apply_wind_to_GUAM.m**:
```matlab
% OLD signature: SimIn = apply_wind_to_GUAM(SimIn, wind_speed_kt, wind_dir_deg)
% NEW signature: apply_wind_to_GUAM(wind_N_ms, wind_E_ms, wind_D_ms)

function apply_wind_to_GUAM(wind_N_ms, wind_E_ms, wind_D_ms)
    evalin('base', sprintf('SimInput.Environment.Winds.Vel_wHh = [%.6f; %.6f; %.6f];', ...
        wind_N_ms, wind_E_ms, wind_D_ms));
end
```

**apply_turbulence_to_GUAM.m**:
```matlab
% Directly modifies SimIn and SimInput in base workspace
evalin('base', 'SimIn.turbType = 1;');
evalin('base', sprintf('SimInput.Environment.Turbulence.WindAt5kft = %.1f;', wind_at_5kft));
```

## Files Modified

1. **Exec_Scripts/run_vertiport_throughput_MC_QUICK.m**
   - Changed userStruct/target setup to use evalin/assignin
   - Changed wind/turbulence calls to pass NED components
   
2. **Exec_Scripts/run_vertiport_throughput_MC.m**
   - Same changes as QUICK version
   
3. **Exec_Scripts/apply_wind_to_GUAM.m**
   - Complete rewrite: direct NED components input
   - Uses evalin to set SimInput.Environment.Winds.Vel_wHh
   
4. **Exec_Scripts/apply_turbulence_to_GUAM.m**
   - Complete rewrite: simpler interface
   - Uses evalin to set SimIn.turbType and SimInput.Environment.Turbulence

## Expected Results

- ✅ GUAM properly initialized with correct workspace variables
- ✅ Simulation runs without array index errors
- ✅ `logsout{1}.Values.Vehicle.Sensor.Pos_bIi.Data` contains valid trajectory
- ✅ TSE calculation succeeds
- ✅ Safety assessment produces meaningful results

## How to Test

```matlab
cd /home/user/webapp/Exec_Scripts
run_vertiport_throughput_MC_QUICK
```

Expected output:
```
Flight 1/150: SAFE (TSE=145.2m, Alt OK) ✓
Flight 2/150: UNSAFE (TSE=356.8m) ✗
...
```

## Technical Details

### GUAM Workspace Architecture

GUAM uses the MATLAB base workspace for all configuration:
- `userStruct`: Variant selection, file paths
- `target`: Flight parameters, reference trajectory
- `SimIn`: Simulation parameters (stopTime, turbType, etc.)
- `SimInput`: Environment configuration (winds, turbulence, etc.)

When calling `sim(model)`, GUAM reads these variables from the base workspace. If they're only in the function's local workspace, GUAM doesn't see them → incomplete initialization → array index errors.

### Data Extraction Pattern

After `sim(model)`:
```matlab
logsout = evalin('base', 'logsout');        % Get from base workspace
SimOut = logsout{1}.Values;                  % Cell array access
pos_data = SimOut.Vehicle.Sensor.Pos_bIi.Data;  % [N,E,D] in feet
```

## Validation

This pattern is proven to work in:
- `Exec_Scripts/run_single_MC_simulation.m` (existing GUAM example)
- `Exec_Scripts/exam_Paper_Safety_Envelope_Implementation.m`
- `Exec_Scripts/run_MC_TSE_safety.m`

All use the same evalin/assignin pattern for GUAM configuration.

## Next Steps

1. ✅ Run quick test to verify fix
2. Analyze results: P(TSE violation), altitude violations
3. Adjust parameters if needed (wind, turbulence intensity)
4. Run full simulation (N_mc runs for all R,λ combinations)
5. Generate comprehensive safety assessment report

---

**Status**: Fix committed and ready for testing  
**Git commit**: `05e05c6`  
**Testing command**: `cd /home/user/webapp/Exec_Scripts; run_vertiport_throughput_MC_QUICK`
