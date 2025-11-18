# Crosswind FTE Analysis - Quick Start Guide

## 🚀 One-Line Execution

```matlab
cd /home/user/webapp && run('Exec_Scripts/exam_Crosswind_FTE_1km.m')
```

**Time**: 1-2 minutes  
**Output**: `Crosswind_FTE_Results/` folder with plots and data

---

## 📊 What This Does

Simulates a 1 km straight flight segment with crosswind and computes **Flight Technical Error (FTE)**:

| Parameter | Value | Description |
|-----------|-------|-------------|
| **Distance** | 1000 m (1 km) | Straight segment |
| **Ground Speed** | 90 knots (46.3 m/s) | Aircraft ground speed |
| **Altitude** | 1000 ft (304.8 m) | Flight altitude |
| **Track Heading** | 0° (North) | Flight direction |
| **Crosswind** | 20 knots (10.3 m/s) | Perpendicular to track |
| **Controller** | GUAM Baseline (LQRi) | Default controller |

---

## 📈 Output Files

### 1. Ground_Track.png
**2D flight path visualization**
- Black dashed line: Desired straight path
- Blue solid line: Actual flight path with crosswind
- Red arrow: Wind direction and magnitude
- Shows lateral deviation caused by crosswind

### 2. Lateral_FTE.png
**Lateral Flight Technical Error (FTE) time history**

**Top plot**: Lateral FTE vs time
- Positive: Right of desired path
- Negative: Left of desired path
- Red dashed lines: Maximum deviation

**Bottom plot**: Absolute FTE with statistics
- Green line: RMS (Root Mean Square) error
- Magenta line: 95th percentile

### 3. All_Errors.png
**Complete error analysis**
- Lateral error (cross-track) - **Most important for FTE**
- Longitudinal error (along-track)
- Altitude error (vertical)

### 4. Crosswind_FTE_Results.mat
**MATLAB data file** containing:
```matlab
load('Crosswind_FTE_Results/Crosswind_FTE_Results.mat');
results.statistics.lateral_max_m   % Maximum FTE
results.statistics.lateral_rms_m   % RMS FTE
results.statistics.lateral_95p_m   % 95th percentile FTE
```

### 5. Crosswind_FTE_Data.xlsx
**Excel spreadsheet** with time-series data:
- Time, actual position, reference position
- Lateral FTE, longitudinal error, altitude error

---

## 🔧 Customizing Parameters

Edit the **USER CONFIGURABLE PARAMETERS** section at the top of the script:

```matlab
%% USER CONFIGURABLE PARAMETERS

% Flight segment parameters
SEGMENT_LENGTH_M = 1000;        % Distance in meters
GROUND_SPEED_KT = 90;           % Ground speed in knots
ALTITUDE_FT = 1000;             % Altitude in feet
TRACK_HEADING_DEG = 0;          % Track heading (0 = North)

% Wind parameters
CROSSWIND_KT = 20;              % Crosswind magnitude in knots
CROSSWIND_DIR_DEG = 90;         % Crosswind direction (90 = perpendicular)

% Simulation parameters
TIME_MARGIN_S = 10;             % Extra simulation time
```

### Example Modifications

**Test stronger crosswind (30 kt)**:
```matlab
CROSSWIND_KT = 30;
```

**Test faster speed (120 kt)**:
```matlab
GROUND_SPEED_KT = 120;
```

**Test higher altitude (2000 ft)**:
```matlab
ALTITUDE_FT = 2000;
```

**Test eastward flight**:
```matlab
TRACK_HEADING_DEG = 90;  % East direction
```

---

## 📐 FTE Calculation Explained

### What is FTE?
**Flight Technical Error (FTE)** measures how well the aircraft tracks the desired path, accounting for:
- Controller performance
- Wind disturbances
- Aircraft dynamics

### Calculation Method

For a North-aligned track (heading = 0°):
```matlab
% Position errors in NED frame
dN = N_actual - N_ref;  % North error
dE = E_actual - E_ref;  % East error

% Track-aligned errors
e_lateral = dE;         % Cross-track error (FTE)
e_parallel = dN;        % Along-track error
```

For arbitrary heading angle `chi`:
```matlab
% Rotate to track-aligned coordinate system
e_parallel =  cos(chi) * dN + sin(chi) * dE;  % Longitudinal
e_lateral  = -sin(chi) * dN + cos(chi) * dE;  % Lateral (FTE)
```

### Key Statistics

**Maximum Absolute Error**:
```matlab
max_FTE = max(abs(e_lateral))
```
Worst-case deviation from desired path

**RMS Error**:
```matlab
rms_FTE = sqrt(mean(e_lateral.^2))
```
Overall tracking performance

**95th Percentile**:
```matlab
p95_FTE = prctile(abs(e_lateral), 95)
```
Statistical maximum (excludes top 5% outliers)

---

## 🎯 Expected Results

### Typical FTE Values (20 kt crosswind, 90 kt speed)

| Metric | Expected Range | Meaning |
|--------|----------------|---------|
| **Max FTE** | 2-5 m | Peak deviation |
| **RMS FTE** | 1-3 m | Average deviation |
| **95% FTE** | 2-4 m | Statistical maximum |

### Factors Affecting FTE

1. **Crosswind Strength** ↑ → FTE ↑
   - Stronger wind = harder to maintain track

2. **Flight Speed** ↑ → FTE ↓ (generally)
   - Faster aircraft = wind has less relative effect

3. **Controller Performance**
   - Baseline LQRi controller gain scheduling

4. **Altitude**
   - Higher altitude = lower air density = different control effectiveness

---

## 🔬 Technical Details

### GUAM Configuration

**Trajectory Input** (Timeseries):
```matlab
RefInput.Vel_bIc_des  = timeseries(vel, time);   % Velocity in heading frame
RefInput.pos_des      = timeseries(pos, time);   % Position in NED frame
RefInput.chi_des      = timeseries(chi, time);   % Heading angle
RefInput.chi_dot_des  = timeseries(chid, time);  % Heading rate
RefInput.vel_des      = timeseries(vel_i, time); % Velocity in inertial frame
```

**Variant Settings**:
```matlab
userStruct.variants.refInputType = 3;  % RefInputEnum.TIMESERIES
userStruct.variants.ctrlType = 2;      % CtrlEnum.BASELINE
```

**Wind Configuration**:
```matlab
SimInput.Environment.Winds.Vel_wHh = [Wind_N; Wind_E; Wind_D];
```

### Data Extraction
```matlab
logsout = evalin('base', 'logsout');
SimOut = logsout{1}.Values;
pos_data = squeeze(SimOut.Vehicle.EOM.InertialData.Pos_bii.Data);
time_sim = SimOut.Vehicle.EOM.InertialData.Pos_bii.Time;
```

---

## 🎓 Academic Usage

### For Research Papers

**Methodology Section**:
```
We employed NASA's Generic Urban Air Mobility (GUAM) simulation 
platform to evaluate Flight Technical Error (FTE) under crosswind 
conditions. A 1 km straight segment was flown at 90 knots ground 
speed with a 20 knot perpendicular crosswind at 1000 ft altitude. 
The baseline LQRi controller performance was analyzed using lateral 
FTE metrics.
```

**Results Section**:
```
Simulation results showed lateral FTE of X.XX m maximum, X.XX m RMS, 
and X.XX m at the 95th percentile. These values demonstrate 
compliance with Required Navigation Performance (RNP) X.XX criteria 
for urban air mobility operations.
```

### Creating Tables

| Crosswind (kt) | Max FTE (m) | RMS FTE (m) | 95% FTE (m) |
|----------------|-------------|-------------|-------------|
| 10             | X.XX        | X.XX        | X.XX        |
| 20             | X.XX        | X.XX        | X.XX        |
| 30             | X.XX        | X.XX        | X.XX        |

### Figure Captions

- **Figure 1**: Ground track comparison showing desired straight path and actual trajectory under 20 kt crosswind conditions
- **Figure 2**: Lateral Flight Technical Error (FTE) time history with statistical metrics (RMS and 95th percentile)

---

## 🔄 Batch Testing

### Test Multiple Crosswind Values
```matlab
crosswind_values = [10, 20, 30, 40];  % knots
results_summary = [];

for i = 1:length(crosswind_values)
    CROSSWIND_KT = crosswind_values(i);
    
    % Run simulation
    run('Exec_Scripts/exam_Crosswind_FTE_1km.m');
    
    % Store results
    results_summary(i,:) = [CROSSWIND_KT, max_lateral, rms_lateral, p95_lateral];
    
    % Rename output folder to avoid overwriting
    movefile('Crosswind_FTE_Results', ...
             sprintf('Crosswind_FTE_Results_%02dkt', CROSSWIND_KT));
end

% Display summary table
results_table = array2table(results_summary, ...
    'VariableNames', {'Crosswind_kt', 'Max_FTE_m', 'RMS_FTE_m', 'P95_FTE_m'});
disp(results_table);

% Save summary
writetable(results_table, 'FTE_Crosswind_Sensitivity.xlsx');
```

### Test Multiple Ground Speeds
```matlab
ground_speeds = [60, 80, 100, 120];  % knots
% (Similar loop structure)
```

---

## ⚠️ Troubleshooting

### Error: "Cannot find simSetup"
```matlab
% Solution: Check working directory
pwd  % Should be /home/user/webapp
cd /home/user/webapp
```

### Error: "Undefined function QrotZ"
```matlab
% Solution: Add STARS library path
addpath(genpath('lib'))
```

### Error: Simulation stops with error
```matlab
% Solution: Clear workspace and reinitialize
clear all
close all
clc
setupPath
```

### Results seem incorrect
**Check**:
1. Unit conversions (knots → m/s)
2. NED coordinate signs (Down is negative)
3. Wind direction setting
4. Simulation time is sufficient

---

## 💡 Tips

### Quick Test (Shorter Distance)
```matlab
SEGMENT_LENGTH_M = 500;  % 500 m instead of 1000 m
TIME_MARGIN_S = 5;       % Shorter simulation
```

### High-Resolution Plot Export
```matlab
% Add at end of script
set(gcf, 'PaperPositionMode', 'auto');
print('Ground_Track_HighRes', '-dpng', '-r300');  % 300 DPI
```

### Compare Multiple Results
```matlab
% Load results from different conditions
load('Crosswind_FTE_Results_20kt/Crosswind_FTE_Results.mat', 'results');
results_20kt = results;

load('Crosswind_FTE_Results_30kt/Crosswind_FTE_Results.mat', 'results');
results_30kt = results;

% Compare
fprintf('20 kt crosswind: Max FTE = %.2f m\n', ...
        results_20kt.statistics.lateral_max_m);
fprintf('30 kt crosswind: Max FTE = %.2f m\n', ...
        results_30kt.statistics.lateral_max_m);
```

---

## 📚 Additional Documentation

### GUAM Resources
- `README.md` - Main GUAM documentation
- `Exec_Scripts/exam_TS_Hover2Cruise_traj.m` - Timeseries input example
- `setup/setupWinds.m` - Wind configuration method

### Related Concepts
- **RNP (Required Navigation Performance)**: Navigation accuracy requirements
- **TSE (Total System Error)**: FTE + NSE + PDE
- **LQRi**: Linear Quadratic Regulator with Integrator
- **NED Frame**: North-East-Down coordinate system

---

## 📞 Summary

### One Command to Run Everything
```matlab
cd /home/user/webapp && run('Exec_Scripts/exam_Crosswind_FTE_1km.m')
```

### Most Important Outputs
- **Lateral_FTE.png**: Shows FTE time history (KEY RESULT)
- **Ground_Track.png**: Visualizes path deviation
- **Crosswind_FTE_Results.mat**: All data for further analysis

### Key Metrics
- **Maximum FTE**: Worst-case scenario
- **RMS FTE**: Overall performance
- **95th Percentile**: Statistical safety margin

---

**Version**: 1.0  
**Last Updated**: 2025-11-18  
**Author**: GUAM Safety Analysis Team

**Pull Request**: https://github.com/moonjang0701/Generic-Urban-Air-Mobility-GUAM/pull/2
