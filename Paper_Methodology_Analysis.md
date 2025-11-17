# Flight Safety Measurements of UAVs - Methodology Analysis

**Paper**: "Flight safety measurements of UAVs in congested airspace"  
**Authors**: Xiang Jinwu, Liu Yang, Luo Zhangping (Beihang University)  
**Journal**: Chinese Journal of Aeronautics, 2016

---

## 1. Safety Envelope (안전 봉투) - Core Concept

### 1.1 Definition
The **safety envelope** E(X_A) is a performance-dependent 3D protected zone around UAV A that represents the space range the UAV can reach in a specified time frame τ (response time).

### 1.2 Mathematical Model

The safety envelope is composed of **eight one-eighth ellipsoids** with semi-axes determined by:

```
a = V_f × τ   (forward direction)
b = V_b × τ   (backward direction)  
c = V_a × τ   (vertical ascending)
d = V_d × τ   (vertical descending)
e = f = V_l × τ   (lateral directions, symmetric)
```

Where:
- **V_f**: Maximum forward velocity
- **V_b**: Maximum backward velocity
- **V_a**: Maximum vertical ascending velocity
- **V_d**: Maximum vertical descending velocity
- **V_l**: Maximum horizontal lateral velocity
- **τ**: Response time (safety parameter)

### 1.3 Envelope Equation

In inertial coordinate system O-xyz with UAV at position X_A = [x_A, y_A, z_A]^T:

**Safety Envelope Region**:
```
E(X_A) = { X ∈ ℝ³ | (X - X_A)^T M(X - X_A) ≤ 1 }
```

Where M is a piecewise matrix defined by four quadrants:

```
         ┌ M₁  if x ≥ x_A, z ≥ z_A
         │ M₂  if x ≥ x_A, z < z_A
M =     │ M₃  if x < x_A, z ≥ z_A
         └ M₄  if x < x_A, z < z_A
```

Each matrix M_i is diagonal 3×3 matrix:

```
M₁ = diag(1/a², 1/e², 1/c²)  (forward, ascending)
M₂ = diag(1/a², 1/e², 1/d²)  (forward, descending)
M₃ = diag(1/b², 1/e², 1/c²)  (backward, ascending)
M₄ = diag(1/b², 1/e², 1/d²)  (backward, descending)
```

### 1.4 Key Insight
**Unlike fixed-size protected zones**, the safety envelope is:
- **Performance-dependent**: Faster UAVs have larger envelopes
- **Time-dependent**: Size scales with response time τ
- **Asymmetric**: Different capabilities in different directions

---

## 2. Flight State Propagation (비행 상태 전파)

### 2.1 Nominal Trajectory with Uncertainty

UAV future position is modeled as:
```
X_A(t) = X_A(0) + ∫₀ᵗ v_A(τ) dτ + w_A(t)
```

Where:
- **X_A(0)**: Initial position at t=0
- **v_A(t)**: Nominal velocity profile
- **w_A(t)**: Brownian motion perturbation (uncertainty)

### 2.2 Brownian Motion Model

The perturbation w_A(t) is modeled as:
```
w_A(t) = σ_v × B̂(t)
```

Where:
- **B̂(t)**: 3D standard Brownian motion
- **σ_v**: Velocity uncertainty (standard deviation)
- **Covariance**: Σ(t) = σ_v² × t × Q

Direction dependency matrix Q:
```
Q = diag(1, k_c, k_c)
```
- k_c ≥ 1: Cross-track uncertainty ratio
- Along-track grows faster than cross-track

---

## 3. Conflict Probability (충돌 확률)

### 3.1 Definition

The **conflict probability** p_A(X) is the probability that a space point X enters the safety envelope E(X_A) during time interval [t₀, t₀ + Δt]:

```
p_A(X) = P{ X ∈ E(X_A) | t ∈ [t₀, t₀ + Δt] }
```

### 3.2 Equivalent Formulation

By relative motion transformation:
```
p_A(X) = P{ X_A ∈ E(X) | t ∈ [t₀, t₀ + Δt] }
```

Where E(X) is the envelope centered at point X moving at velocity -v_A.

### 3.3 Analytical Approximation Algorithm

The paper develops an **analytical approximation** to reduce computation:

#### Step 1: Transform to Relative Coordinates
```
ΔX(t) = X - X_A(t) = ΔX₀ + Δv·t - w_A(t)
```
Where:
- ΔX₀ = X - X_A(0)
- Δv = -v_A

#### Step 2: Coordinate Rotation
Transform to moving plane perpendicular to velocity vector.

#### Step 3: Equivalent Sphere Approximation
Replace the complex 8-part ellipsoid envelope with an **equivalent sphere** of radius r_eq:

```
Volume of E(X): V(E) = (4π/3) × (1/8) × (ace + ade + bce + bde)

Equivalent radius: r_eq = ³√(3V(E)/(4π))
```

#### Step 4: 2D Impact Probability
The 3D problem is reduced to 2D probability that Brownian motion hits a circle:

```
p_A(X) ≈ Φ(r_eq / √(σ_v² × Δt))
```

Where Φ is the cumulative normal distribution function.

---

## 4. Airspace Safety Situation (공역 안전 상황)

### 4.1 Multi-UAV Scenario

For N UAVs in the same airspace, the **airspace safety at point X** is:

```
s(X) = P{ X ∈ ⋃ᵢ₌₁ᴺ E(X_Aᵢ) | t ∈ [t₀, t₀ + Δt] }
```

This is the probability that point X enters **at least one** UAV safety envelope.

### 4.2 Safety Levels

- **s(X) = 0**: Point X is completely safe (no UAV can reach it)
- **0 < s(X) < threshold**: Moderate risk
- **s(X) > threshold**: High risk, dangerous for new UAVs
- **s(X) = 1**: Certainty of conflict

### 4.3 Safety Field Visualization

The function s(X) creates a **3D safety field** over the airspace, showing congestion levels.

---

## 5. Implementation for GUAM

### 5.1 Required Parameters

From GUAM Lift+Cruise aircraft:

**Flight Performance** (convert from ft/s to m/s):
```matlab
% From GUAM specifications
cruise_speed = 80:20:120; % knots
V_max = max(cruise_speed) * 0.5144; % m/s

% Estimate from aircraft capabilities
V_f = V_max;          % Forward velocity
V_b = 0.3 * V_max;    % Backward velocity (~30% of forward)
V_a = 10;             % Vertical ascent (m/s)
V_d = 15;             % Vertical descent (m/s)
V_l = 0.5 * V_max;    % Lateral velocity (~50% of forward)
```

**Response Time**:
```matlab
tau = 5;  % 5 seconds response time (paper uses 2-10s range)
```

**Uncertainty Parameters**:
```matlab
sigma_v = 2;   % Velocity uncertainty (m/s)
k_c = 2;       % Cross-track ratio
```

### 5.2 Algorithm Steps

1. **Extract trajectory from GUAM logsout**:
   - Position: logsout{X_NED}
   - Velocity: logsout{Vb}
   - Time: logsout{X_NED}.Time

2. **Calculate safety envelope at each time step**:
   - Compute semi-axes: a, b, c, d, e, f
   - Define 8-part ellipsoid using piecewise matrices M₁-M₄

3. **Compute conflict probability field**:
   - Define grid of spatial points
   - For each point, calculate p_A(X) using analytical approximation
   - Aggregate for multiple UAVs (if applicable)

4. **Visualize safety envelope**:
   - 3D plot of ellipsoid boundary
   - Contour plots of s(X) in horizontal/vertical planes
   - Time evolution animation

### 5.3 Key Formulas for Implementation

```matlab
% Safety envelope semi-axes
a = V_f * tau;
b = V_b * tau;
c = V_a * tau;
d = V_d * tau;
e = V_l * tau;
f = V_l * tau;

% Equivalent sphere radius
V_envelope = (4*pi/3) * (1/8) * (a*c*e + a*d*e + b*c*e + b*d*e);
r_eq = (3 * V_envelope / (4*pi))^(1/3);

% Conflict probability (simplified)
Delta_t = 5;  % Prediction interval
for each point X in grid:
    Delta_X = X - X_A;
    distance = norm(Delta_X);
    
    % Analytical approximation
    p_A(X) = normcdf(r_eq / sqrt(sigma_v^2 * Delta_t));
end
```

---

## 6. Expected Outputs

### 6.1 Visualizations

1. **3D Safety Envelope Plot**: 8-part ellipsoid around UAV
2. **Conflict Probability Field**: Heatmap of s(X) in airspace
3. **Time Evolution**: Animation of safety envelope during maneuvers
4. **Ground Track with Envelope**: 2D projection showing protected zone
5. **Safety Metrics Timeline**: s(X) variation during flight

### 6.2 Metrics

- **Envelope Volume**: Size of protected zone (m³)
- **Maximum Conflict Probability**: max(s(X)) in surrounding airspace
- **Safe Airspace Percentage**: Percentage of points with s(X) < threshold
- **Minimum Safe Distance**: Minimum distance to s(X) = 1 boundary

---

## 7. Differences from Generic Safety Metrics

**Generic Approach** (previous implementation):
- Fixed separation distances
- RMS errors and deviations
- Simple geometric checks

**Paper's Approach** (this implementation):
- Performance-dependent envelopes
- Probabilistic conflict assessment
- Brownian motion uncertainty model
- Analytical approximation for efficiency
- Spatially-distributed safety field

---

## 8. Validation Strategy

The paper includes two validation scenarios:

1. **Formation Flight**: 3 UAVs in formation
   - Monitor s(X) between UAVs
   - Verify safety margins maintained

2. **Trajectory Planning**: 1 UAV navigating through airspace with 5 existing UAVs
   - Path optimization to minimize s(X)
   - Conflict avoidance verification

For GUAM, we can validate by:
- Testing bank angle maneuvers at different speeds
- Calculating envelope size vs. performance
- Comparing safety metrics before/after maneuvers
- Verifying envelope doesn't overlap with obstacles/other UAVs

---

## 9. Next Steps

1. ✅ Extract paper methodology (COMPLETED)
2. ⏭️ Implement safety envelope calculation in MATLAB
3. ⏭️ Integrate with GUAM trajectory data
4. ⏭️ Generate 3D visualizations
5. ⏭️ Calculate conflict probability fields
6. ⏭️ Export results to CSV for analysis

---

**Key Insight**: The "봉투" (envelope) is NOT a fixed buffer zone, but a **performance-dependent, time-varying 3D region** calculated from the UAV's actual flight capabilities. This is the paper's main innovation over traditional protected zones.
