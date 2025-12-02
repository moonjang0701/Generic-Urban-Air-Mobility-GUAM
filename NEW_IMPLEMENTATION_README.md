# UAM Vertiport Throughput Safety Assessment - NEW Implementation

**Date**: 2025-12-02  
**Status**: ✅ Ready for testing  
**Based on**: Official GUAM examples (RUNME.m, exam_Bezier.m)

## Overview

This is a **complete rewrite** of the vertiport airspace simulation, now correctly following the official GUAM example patterns from `RUNME.m` and `exam_Bezier.m`.

## What Changed

### ❌ Previous (WRONG) Approach
The previous implementation (`run_vertiport_throughput_MC.m`, `run_vertiport_throughput_MC_QUICK.m`) was based on custom Monte Carlo examples (`run_single_MC_simulation.m`) which used:
- ❌ `evalin('base', 'simSetup;')` - Not the official pattern
- ❌ `assignin('base', 'RefInput', RefInput)` - Unnecessary complexity  
- ❌ Custom helper functions with evalin - Not standard GUAM
- ❌ Complex workspace manipulation

**Result**: Array index errors, 100% unsafe flights

### ✅ Current (CORRECT) Approach
The new implementation follows the exact pattern from official GUAM examples:
- ✅ Global variables: `userStruct`, `target`, `RefInput`
- ✅ Direct calls: `simSetup;` and `sim(model);`
- ✅ Wind/turbulence via global `SimInput`/`SimIn` variables
- ✅ Results from global `logsout` variable
- ✅ Standard GUAM workflow

## Files

### Main Scripts

1. **`run_vertiport_MC_NEW_QUICK.m`** ⭐ RECOMMENDED FOR TESTING
   - Quick test with **5 flights only**
   - Fast execution (~5-10 minutes)
   - Perfect for debugging and validation
   
2. **`run_vertiport_MC_NEW.m`**
   - Full simulation: **150 flights × 5 MC runs = 750 flights**
   - Estimated time: 3-5 hours
   - Use after quick test succeeds

## How to Run

### Quick Test (Recommended First)

```matlab
% In MATLAB command window:
cd /home/user/webapp/Exec_Scripts
run_vertiport_MC_NEW_QUICK
```

**Expected output:**
```
=== UAM Vertiport Safety QUICK TEST ===
Test flights: 5
...
Flight 1/5: arrival, Wind=12.3kt@245deg, Turb=Moderate
  -> SAFE (TSE=145.2m, Alt OK) ✓
Flight 2/5: departure, Wind=8.7kt@89deg, Turb=Light
  -> UNSAFE (TSE=356.8m > 300m) ✗
...
========== QUICK TEST RESULTS ==========
Total flights: 5
Safe: 3 (60.0%)
Unsafe: 2 (40.0%)
...
```

### Full Simulation

```matlab
% After quick test succeeds:
cd /home/user/webapp/Exec_Scripts
run_vertiport_MC_NEW
```

## Simulation Parameters

### Target Scenario
- **Throughput**: 150 movements/hour
- **Duration**: 8 hours (09:00-17:00)
- **Total flights**: 1200 movements (600 arrivals + 600 departures)

### Vertiport Geometry
- **Radius**: 2000 m
- **Altitude range**: 300-600 m (UAM corridor)
- **TSE limit**: 300 m (horizontal protection)

### Flight Characteristics
- **Average speed**: 50 m/s ground speed
- **Trajectories**: Piecewise Bezier (3 waypoints)
- **Entry/exit**: Uniformly distributed on circle boundary

### Environmental Disturbances
- **Wind**: 0-20 knots, random direction (0-360°)
- **Turbulence**: Random intensity (Light/Moderate/Severe)
  - Light: WindAt5kft = 15 m/s
  - Moderate: WindAt5kft = 30 m/s
  - Severe: WindAt5kft = 50 m/s

### Safety Criteria
A flight is **SAFE** if:
1. Max TSE ≤ 300 m (lateral separation)
2. Altitude stays within 300-600 m (no violations)

A flight is **UNSAFE** if either condition is violated.

## Technical Implementation

### Pattern Validation

The implementation follows these official GUAM examples:

1. **exam_Bezier.m** → Bezier trajectory setup
   ```matlab
   target.RefInput.Bezier.waypoints = {wptsX, wptsY, wptsZ};
   target.RefInput.Bezier.time_wpts = {time_wptsX, time_wptsY, time_wptsZ};
   userStruct.trajFile = '';
   simSetup;
   ```

2. **exam_TS_Sinusoidal_traj.m** → RefInput structure
   ```matlab
   RefInput.Vel_bIc_des = ...
   RefInput.pos_des = ...
   target.RefInput = RefInput;
   ```

3. **RUNME.m** → Execution pattern
   ```matlab
   sim(model);
   simPlots_GUAM;  % Uses global logsout
   ```

### Workflow

```
1. Setup trajectory
   ↓
   userStruct.variants.refInputType = 4;  % Bezier
   target.RefInput.Bezier.waypoints = {...};
   ↓
2. Initialize GUAM
   ↓
   simSetup;  % Creates global SimInput, SimIn
   ↓
3. Apply disturbances
   ↓
   SimInput.Environment.Winds.Vel_wHh = [wind_N; wind_E; wind_D];
   SimInput.Environment.Turbulence.WindAt5kft = 30;
   SimIn.turbType = 1;
   ↓
4. Run simulation
   ↓
   sim(model);  % Creates global logsout
   ↓
5. Extract results
   ↓
   SimOut = logsout{1}.Values;
   pos_data = SimOut.Vehicle.Sensor.Pos_bIi.Data;
```

### Data Extraction

```matlab
% After sim(model):
logsout = logsout;  % Global variable
SimOut = logsout{1}.Values;  % Cell array access

% Position data (NED, in feet)
time = SimOut.Time.Data;
pos_ft = SimOut.Vehicle.Sensor.Pos_bIi.Data;  % [N, E, D]

% Convert to meters
pos_m = pos_ft * 0.3048;
altitude_m = -pos_m(:,3);  % Down is negative altitude
```

## Expected Results

Based on the wind/turbulence settings:
- **P(safe)**: ~30-50% (moderate wind, high turbulence)
- **Mean Max TSE**: ~200-300 m
- **Violations**: Mix of TSE and altitude violations

### Result Interpretation

Good scenario (safe operations):
- P(safe) > 90%
- Mean Max TSE < 150 m
- Few altitude violations

Current scenario (challenging):
- P(safe) ~ 30-50%
- Mean Max TSE ~ 200-300 m
- Shows need for stricter separation or reduced throughput

## Troubleshooting

### If simulation fails

1. **Check GUAM model**:
   ```matlab
   open('GUAM')
   % Verify model loads without errors
   ```

2. **Check paths**:
   ```matlab
   which simSetup
   which evalSegments
   which Qtrans
   ```

3. **Test basic GUAM example**:
   ```matlab
   RUNME  % Select option 5 (Bezier)
   ```

4. **Check workspace variables after simSetup**:
   ```matlab
   simSetup;
   whos SimInput SimIn target
   ```

### Common issues

- **"Undefined function 'simSetup'"**: Path not set correctly
  ```matlab
  addpath('./Exec_Scripts/');
  addpath('./Bez_Functions/');
  addpath(genpath('lib'));
  ```

- **"logsout not found"**: Simulation didn't run
  - Check model loads: `open('GUAM')`
  - Check SimIn.StopTime is set

- **"Array index out of bounds"**: This should not happen with new code
  - If it does, check GUAM model version compatibility

## Validation

To validate the implementation works correctly:

1. Run quick test: `run_vertiport_MC_NEW_QUICK`
2. Verify output shows:
   - ✓ Flights complete without errors
   - ✓ TSE values are calculated (not NaN)
   - ✓ Mix of SAFE and UNSAFE flights
   - ✓ Realistic TSE values (50-500 m range)

3. Check one flight manually:
   ```matlab
   % After running quick test:
   plot(time_sim, altitude_m)
   xlabel('Time (s)'); ylabel('Altitude (m)');
   title('Altitude profile');
   % Should show smooth altitude change from start to end
   ```

## Next Steps

1. ✅ Run `run_vertiport_MC_NEW_QUICK` to validate
2. Analyze quick test results
3. Adjust parameters if needed (wind, turbulence)
4. Run full simulation `run_vertiport_MC_NEW`
5. Generate comprehensive report with plots

## Comparison: OLD vs NEW

| Aspect | OLD (Wrong) | NEW (Correct) |
|--------|-------------|---------------|
| Base pattern | Custom MC example | Official GUAM examples |
| Workspace | evalin/assignin | Global variables |
| simSetup | `evalin('base', 'simSetup;')` | `simSetup;` |
| sim() | `evalin('base', 'sim(...)')` | `sim(model);` |
| Wind setup | Custom helper w/ evalin | Direct SimInput.Environment |
| Results | Complex extraction | Standard logsout access |
| Reliability | ❌ Array errors | ✅ Should work |

## Git History

```
d885466 - Rewrite using official GUAM pattern
05e05c6 - (OLD) CRITICAL FIX attempt with evalin
16ab692 - (OLD) Add simInit (wrong approach)
3ba2130 - (OLD) Fix logsout parsing (wrong pattern)
f6116fb - (OLD) Initial vertiport MC (wrong base)
```

The old approach was based on misunderstanding GUAM's architecture. The new approach follows the official pattern exactly.

---

**Status**: Ready for testing  
**Recommended**: Run `run_vertiport_MC_NEW_QUICK` first  
**Questions**: Check official examples in `Exec_Scripts/exam_*.m`
