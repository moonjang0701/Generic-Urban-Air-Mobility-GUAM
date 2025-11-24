# UAM Procedure R&D - GUAM-Based Analysis System

## 📋 Overview

This project implements a comprehensive research and development system for **Urban Air Mobility (UAM) Procedure Design Standards** using NASA's Generic UAM Simulation (GUAM) platform.

### Research Objectives

Using GUAM Challenge Problem scenarios, this system:

1. **Establishes baseline performance criteria** (climb/descent angles, bank limits, turn radii)
2. **Computes Total System Error (TSE)** distributions for corridor width determination
3. **Validates procedures under abnormal conditions** (failures, obstacles)
4. **Derives quantitative design standards** for UAM procedure designers

### Key Innovation

Instead of relying on traditional fixed-wing aircraft standards, this R&D framework:

- ✅ Uses GUAM's high-fidelity eVTOL simulation as a "truth trajectory" source
- ✅ Models TSE = √(FTE² + NSE²) with Monte Carlo methods
- ✅ Analyzes 3000 diverse scenarios including failures and obstacles
- ✅ Produces data-driven, UAM-specific procedure design criteria

---

## 🏗️ Project Structure

```
UAM_Procedure_RnD/
│
├── Phase0_Setup/                      # Scenario classification
│   ├── scenario_classifier.m          # Main classifier function
│   └── run_phase0.m                   # Phase 0 execution script
│
├── Phase1_Baseline/                   # Normal operation analysis
│   └── run_baseline_analysis.m        # Baseline performance analysis
│
├── Phase2_TSE_Analysis/               # TSE computation & Monte Carlo
│   └── run_tse_analysis.m             # TSE analysis (to be implemented)
│
├── Phase3_Abnormal/                   # Failure scenario validation
│   └── run_abnormal_analysis.m        # Abnormal scenario analysis (TBI)
│
├── Phase4_Standards/                  # Final standards derivation
│   └── derive_design_standards.m      # Standards document generation (TBI)
│
├── Utils/                             # Common analysis functions
│   ├── traj_to_path_coords.m          # Path coordinate conversion
│   ├── compute_flight_angles.m        # Flight angle computation
│   ├── compute_turn_metrics.m         # Turn performance analysis
│   └── compute_TSE.m                  # TSE calculation with Monte Carlo
│
├── Results/                           # Output directory
│   ├── Data/                          # Analysis results (MAT, CSV)
│   ├── Figures/                       # Plots and visualizations
│   └── Reports/                       # Text reports and summaries
│
└── README.md                          # This file
```

---

## 🚀 Quick Start

### Prerequisites

- **MATLAB** R2020b or later (with Simulink for Phase 2+)
- **GUAM** v1.1 installed and configured
- **Challenge Problems** datasets (Data_Set_1.mat through Data_Set_4.mat)

### Step 1: Run Phase 0 (Scenario Classification)

```matlab
cd Phase0_Setup
run_phase0
```

**Output:**
- Scenario catalog (3000 runs classified)
- Distribution plots (trajectory types, vertical profiles, procedure styles)
- Summary statistics

**Time:** ~5-10 minutes

### Step 2: Run Phase 1 (Baseline Analysis)

```matlab
cd ../Phase1_Baseline
run_baseline_analysis
```

**Output:**
- Baseline performance statistics (climb/descent angles, bank angles, turn radii)
- Recommended design criteria for normal operations
- Distribution plots and CSV exports

**Time:** ~2-3 minutes (uses catalog data)

### Step 3: Run Phase 2 (TSE Analysis) - To Be Implemented

```matlab
cd ../Phase2_TSE_Analysis
run_tse_analysis
```

**Output:**
- TSE distributions (95%, 99% containment)
- Corridor width requirements
- Monte Carlo simulation results

**Time:** ~30-60 minutes (requires GUAM simulations)

### Step 4: Generate Final Standards - To Be Implemented

```matlab
cd ../Phase4_Standards
derive_design_standards
```

**Output:**
- Complete UAM procedure design standard document
- Tables with recommended values
- Justification and validation data

---

## 📊 Analysis Methodology

### Phase 0: Scenario Classification

**Objective:** Create searchable catalog of 3000 GUAM Challenge Problem scenarios

**Classification Dimensions:**
- **Trajectory Type:** Straight / Gentle Turn / Sharp Turn
- **Vertical Profile:** Climb / Level / Descent
- **Procedure Style:** Approach / Departure / En-route
- **Failure Status:** Normal / With Failure
- **Obstacle Presence:** Clear / Static Obstacle / Moving Obstacle

**Estimated Metrics:**
- Bank angles
- Climb/descent angles
- Turn radii
- Distance and duration

**Output:** `scenario_catalog.mat` with full classification metadata

---

### Phase 1: Baseline Performance (Normal Operations)

**Objective:** Establish baseline performance without TSE or failures

**Analysis:**
1. Select stratified sample of normal scenarios
2. Extract performance metrics from catalog
3. Compute statistical distributions
4. Derive recommended limits

**Key Metrics:**
- **Climb Angle:** Mean, 95th percentile, max → Recommended limit
- **Descent Angle:** Mean, 95th percentile, max → Recommended limit
- **Bank Angle:** Mean, 95th percentile, max → Comfort/capability limits
- **Turn Radius:** Min, 5th/10th percentiles → Minimum required radius

**Output:** Baseline design criteria (foundation for TSE analysis)

---

### Phase 2: Total System Error (TSE) Analysis

**Objective:** Compute TSE distributions to determine corridor width

**TSE Model:**
```
TSE = √(FTE² + NSE²)

where:
  FTE = Flight Technical Error (control/tracking)
  NSE = Navigation System Error (GNSS/RNP-based)
```

**Method:**
1. Use GUAM trajectory as "truth" (centerline)
2. Compute path coordinates (along-track s, cross-track e, height h)
3. Model FTE from measured tracking error
4. Model NSE from RNP specification (e.g., RNP 0.3 → σ = 278m)
5. Run Monte Carlo simulations (100-1000 samples)
6. Compute 95%/99% containment → Corridor width

**Parameters:**
- `N_MC`: Number of Monte Carlo samples (default: 100)
- `RNP_Value`: RNP specification in NM (default: 0.3)
- `FTE_Sigma`: FTE standard deviation (computed from data)
- `Wind_Model`: 'none' / 'mild' / 'moderate'

**Output:**
- Lateral TSE 95%/99% → Corridor width recommendation
- Vertical TSE 95%/99% → Altitude buffer recommendation
- Turn splay factors for curved segments

**Example Result:**
```
Lateral TSE (95%):  45.2 m  →  Corridor width: 108 m (with 20% margin)
Vertical TSE (95%): 28.7 m  →  Altitude buffer: ±35 m
```

---

### Phase 3: Abnormal Scenario Validation

**Objective:** Validate procedures under failures and obstacles

**Scenarios:**
- Effector failures (control surface, propulsor)
- Static obstacles (buildings, terrain)
- Moving obstacles (other aircraft)

**Analysis:**
1. Run GUAM with failure scenarios
2. Compute TSE under degraded performance
3. Measure maximum lateral/vertical deviations
4. Check if baseline corridor width is sufficient

**Validation Metrics:**
- Percentage of scenarios contained within corridor (target: >95%)
- Maximum deviation beyond corridor → Additional margin needed
- Missed approach success rate

**Output:** Safety margins and adjustments for abnormal conditions

---

### Phase 4: Design Standards Derivation

**Objective:** Compile all analysis into UAM procedure design standard

**Document Sections:**

1. **Introduction & Scope**
   - UAM-specific requirements
   - Differences from fixed-wing standards

2. **Climb/Descent Criteria**
   - Recommended maximum climb angle: X°
   - Recommended maximum descent angle: Y°
   - Rationale: Based on N scenarios, 95th percentile

3. **Turn and Bank Criteria**
   - Minimum turn radius: R meters
   - Maximum bank angle: φ degrees
   - Turn protection area: Width calculation

4. **Corridor Width and Protection Areas**
   - Straight segments: W_straight meters
   - Turn segments: W_turn = W_straight + splay
   - Vertical buffers: ±V meters

5. **TSE Model and Assumptions**
   - FTE component: σ_FTE
   - NSE component: RNP-based, σ_NSE
   - Monte Carlo validation results

6. **Abnormal Conditions**
   - Additional margins for failures: +X%
   - Obstacle clearance requirements
   - Missed approach criteria

7. **Tables and Summary**
   - Quick reference table with all values
   - Comparison with ICAO/FAA standards

**Output:** Complete procedure design standard document (PDF/Word)

---

## 🔬 Technical Details

### TSE Computation Algorithm

```matlab
% 1. Convert trajectory to path coordinates
path_coords = traj_to_path_coords(trajectory_data);

% 2. Compute TSE with Monte Carlo
TSE_results = compute_TSE(trajectory_data, path_coords, ...
    'N_MC', 100, ...
    'NSE_Model', 'RNP', ...
    'RNP_Value', 0.3, ...
    'FTE_Model', 'measured');

% 3. Extract corridor width
corridor_width_95 = TSE_results.corridor_width.width_95;
corridor_width_99 = TSE_results.corridor_width.width_99;
```

### Flight Angle Computation

```matlab
% Compute all flight angles from trajectory
angles = compute_flight_angles(trajectory_data);

% Extract statistics
climb_mean = angles.statistics.climb.mean;
climb_95 = angles.statistics.climb.percentile_95;
descent_max = angles.statistics.descent.max;
bank_max = angles.statistics.bank.max;
```

### Turn Analysis

```matlab
% Analyze turn performance
turn_metrics = compute_turn_metrics(trajectory_data);

% Extract requirements
min_radius = turn_metrics.statistics.radius.min;
bank_limit = turn_metrics.protection_area.recommended_bank_limit;
lateral_splay = turn_metrics.protection_area.lateral_splay;
```

---

## 📈 Expected Results

### Baseline Criteria (Phase 1)

| Parameter | Expected Range | Recommended Value |
|-----------|----------------|-------------------|
| Max Climb Angle | 8-15° | 12° (95th %ile) |
| Max Descent Angle | 4-8° | 6° (95th %ile) |
| Max Bank Angle | 20-30° | 25° (comfort limit) |
| Min Turn Radius | 300-800m | 500m (10th %ile) |

### TSE-Based Corridor Width (Phase 2)

| Segment Type | TSE 95% | Corridor Width | Basis |
|--------------|---------|----------------|-------|
| Straight | 35-50m | 90-120m | 2×TSE + margin |
| Turn | 50-70m | 120-170m | 2×TSE + splay |
| Vertical Buffer | 25-40m | ±35m | TSE vertical |

### Validation Results (Phase 3)

| Condition | Containment Rate | Result |
|-----------|------------------|--------|
| Normal Operation | >98% | ✅ Pass |
| Single Failure | >95% | ✅ Pass (with margin) |
| Obstacle Avoidance | >95% | ✅ Pass |

---

## 🎯 Key Innovations

### 1. UAM-Specific TSE Model
- Traditional aviation: TSE from empirical flight test
- This R&D: TSE from GUAM simulation + Monte Carlo
- Advantage: Can test thousands of scenarios without flight test cost

### 2. Performance-Based Criteria
- Traditional: Fixed margins (e.g., always 5° approach angle)
- This R&D: Data-driven percentiles (e.g., 95th percentile observed)
- Advantage: Optimized for UAM performance envelope

### 3. Integrated Failure Analysis
- Traditional: Separate safety assessment
- This R&D: Failures built into procedure design from start
- Advantage: Procedures inherently robust to failures

### 4. Multi-Dimensional Classification
- Traditional: Generic scenarios
- This R&D: 3000 scenarios classified by type, profile, style
- Advantage: Targeted analysis for each procedure category

---

## 📁 Output Files

### Data Files (`.mat`)
- `scenario_catalog.mat` - Full scenario classification (Phase 0)
- `phase1_baseline_results.mat` - Baseline statistics (Phase 1)
- `phase2_tse_results.mat` - TSE distributions (Phase 2)
- `phase3_abnormal_results.mat` - Failure validation (Phase 3)

### CSV Files (`.csv`)
- `phase1_baseline_results.csv` - Baseline parameters table
- `tse_statistics.csv` - TSE summary statistics
- `corridor_width_requirements.csv` - Width recommendations

### Figures (`.png`, `.fig`)
- `scenario_distribution_overview.png` - Classification pie charts
- `flight_angle_distributions.png` - Angle histograms
- `turn_radius_distribution.png` - Turn performance
- `tse_distribution_plots.png` - TSE heat maps
- `corridor_width_visualization.png` - Protection area diagrams

### Reports (`.txt`, `.pdf`)
- `Phase0_Summary.txt` - Scenario catalog summary
- `UAM_Procedure_Design_Standard.pdf` - Final standard document

---

## 🔧 Configuration Options

### Global Settings

Edit `config` structure in each phase script:

```matlab
config.challenge_data_path = '../../Challenge_Problems';  % Data location
config.results_path = '../Results';                       % Output location
config.n_scenarios_to_analyze = 50;                       % Sample size
config.save_results = true;                               % Save outputs
config.generate_plots = true;                             % Create figures
```

### TSE Parameters

Adjust in `compute_TSE()` calls:

```matlab
TSE_results = compute_TSE(trajectory_data, path_coords, ...
    'N_MC', 100, ...              % Monte Carlo samples
    'RNP_Value', 0.3, ...         % RNP in nautical miles
    'FTE_Model', 'measured', ...  % 'measured' or 'gaussian'
    'NSE_Model', 'RNP', ...       % 'RNP' or 'gaussian'
    'Wind_Model', 'none');        % 'none', 'mild', 'moderate'
```

### Turn Detection Thresholds

Adjust in `compute_turn_metrics()` calls:

```matlab
turn_metrics = compute_turn_metrics(trajectory_data, ...
    'TurnThreshold', 5, ...       % Min heading change (deg)
    'BankThreshold', 5);          % Min bank angle (deg)
```

---

## 🐛 Troubleshooting

### Issue: "Data_Set_1.mat not found"
**Solution:** Ensure GUAM Challenge Problems are downloaded and path is correct

### Issue: "Out of memory during classification"
**Solution:** Process in batches, or increase MATLAB memory limit

### Issue: "GUAM simulation fails"
**Solution:** Phase 1 uses catalog data only. Phases 2-3 require Simulink.

### Issue: "Plots not appearing"
**Solution:** Check `config.generate_plots = true` and figure visibility

---

## 📚 References

### GUAM Documentation
- NASA GUAM GitHub: https://github.com/nasa/GUAM
- GUAM README.md (simulation details)
- Challenge_Problems/README.md (scenario details)

### Standards and Guidelines
- **ICAO Doc 9613:** Performance-based Navigation (PBN) Manual
- **FAA Order 8260.58:** RNP Authorization Required Procedures
- **RTCA DO-236:** Minimum Aviation System Performance Standards (MASPS)

### Research Papers
- Simmons et al., "Full-Envelope Aero-Propulsive Model Identification for Lift+Cruise"
- Cook & Hauser, "Strip Theory Approach to Dynamic Modeling of eVTOL"
- Xiang et al., "Flight safety measurements of UAVs in congested airspace"

---

## 👥 Contact & Support

**Project Lead:** UAM Procedure R&D Team  
**GUAM Support:** michael.j.acheson@nasa.gov  
**GitHub Issues:** [Submit issues here]

---

## 📝 License

This project uses NASA's GUAM simulation, which is subject to NASA Open Source Agreement.

See `license/` directory for full license text.

---

## ✅ Checklist for Complete Analysis

- [ ] Phase 0 Complete: Scenario catalog created
- [ ] Phase 1 Complete: Baseline criteria established
- [ ] Phase 2 Complete: TSE analysis with Monte Carlo
- [ ] Phase 3 Complete: Abnormal scenario validation
- [ ] Phase 4 Complete: Final standards document
- [ ] All figures generated and reviewed
- [ ] CSV data exported for external tools
- [ ] Results validated against known benchmarks

---

**Ready to establish UAM procedure design standards!** 🚁✨
