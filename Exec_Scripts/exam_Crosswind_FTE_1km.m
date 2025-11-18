%% GUAM Crosswind Flight Technical Error (FTE) Analysis
% =========================================================================
% Purpose: Simulate a 1 km straight flight with 20 kt crosswind and compute
%          lateral Flight Technical Error (FTE) using GUAM baseline controller
%
% Flight Parameters:
%   - Distance: 1000 m (1 km) straight segment
%   - Ground speed: 90 knots (46.3 m/s)
%   - Altitude: 1000 ft (304.8 m)
%   - Crosswind: 20 knots (10.3 m/s) perpendicular to track
%   - Heading: 0 deg (North)
%   - Controller: GUAM Baseline (LQRi)
%
% Outputs:
%   - 2D ground track plot (desired vs actual)
%   - Lateral FTE vs time plot
%   - FTE statistics (max, RMS, 95th percentile)
%
% Author: GUAM Safety Analysis
% Date: 2025-11-18
% =========================================================================

clear all; close all; clc;

%% USER CONFIGURABLE PARAMETERS
% =========================================================================
% You can easily modify these parameters to test different scenarios

% Flight segment parameters
SEGMENT_LENGTH_M = 1000;        % Distance in meters (1 km)
GROUND_SPEED_KT = 90;           % Ground speed in knots
ALTITUDE_FT = 1000;             % Altitude in feet
TRACK_HEADING_DEG = 0;          % Track heading (0 = North)

% Wind parameters
CROSSWIND_KT = 20;              % Crosswind magnitude in knots
CROSSWIND_DIR_DEG = 90;         % Crosswind direction relative to track
                                % (90 = perpendicular from right)

% Simulation parameters
TIME_MARGIN_S = 10;             % Extra time beyond nominal segment time

% =========================================================================

fprintf('╔════════════════════════════════════════════════════════════════╗\n');
fprintf('║  GUAM CROSSWIND FLIGHT TECHNICAL ERROR (FTE) ANALYSIS         ║\n');
fprintf('╚════════════════════════════════════════════════════════════════╝\n\n');

%% SECTION 1: SETUP AND INITIALIZATION
fprintf('SECTION 1: SIMULATION SETUP\n');
fprintf('─────────────────────────────────\n\n');

% Change to GUAM root directory
script_dir = fileparts(mfilename('fullpath'));
guam_root = fileparts(script_dir);
cd(guam_root);
fprintf('Working directory: %s\n', pwd);

% Initialize GUAM model name
model = 'GUAM';
fprintf('Model: %s\n\n', model);

%% SECTION 2: UNIT CONVERSIONS AND CALCULATIONS
fprintf('SECTION 2: PARAMETER CONVERSIONS\n');
fprintf('─────────────────────────────────\n\n');

% Convert ground speed
GROUND_SPEED_FPS = GROUND_SPEED_KT * 1.68781;  % knots to ft/s
GROUND_SPEED_MS = GROUND_SPEED_FPS * 0.3048;   % ft/s to m/s
fprintf('Ground Speed:\n');
fprintf('  %.1f knots = %.2f ft/s = %.2f m/s\n\n', ...
        GROUND_SPEED_KT, GROUND_SPEED_FPS, GROUND_SPEED_MS);

% Convert altitude (NED frame: down is negative)
ALTITUDE_M = ALTITUDE_FT * 0.3048;
ALTITUDE_NED = -ALTITUDE_M;  % NED down is negative
fprintf('Altitude:\n');
fprintf('  %.0f ft = %.1f m\n', ALTITUDE_FT, ALTITUDE_M);
fprintf('  NED Down: %.1f m (negative in NED frame)\n\n', ALTITUDE_NED);

% Convert crosswind
CROSSWIND_FPS = CROSSWIND_KT * 1.68781;
CROSSWIND_MS = CROSSWIND_FPS * 0.3048;
fprintf('Crosswind:\n');
fprintf('  %.1f knots = %.2f ft/s = %.2f m/s\n\n', ...
        CROSSWIND_KT, CROSSWIND_FPS, CROSSWIND_MS);

% Calculate flight time
NOMINAL_TIME_S = SEGMENT_LENGTH_M / GROUND_SPEED_MS;
TOTAL_TIME_S = NOMINAL_TIME_S + TIME_MARGIN_S;
fprintf('Flight Time:\n');
fprintf('  Segment length: %.0f m\n', SEGMENT_LENGTH_M);
fprintf('  Ground speed: %.2f m/s\n', GROUND_SPEED_MS);
fprintf('  Nominal time: %.1f s\n', NOMINAL_TIME_S);
fprintf('  Total sim time: %.1f s (with %.0f s margin)\n\n', ...
        TOTAL_TIME_S, TIME_MARGIN_S);

%% SECTION 3: DEFINE REFERENCE TRAJECTORY
fprintf('SECTION 3: REFERENCE TRAJECTORY DEFINITION\n');
fprintf('───────────────────────────────────────────\n\n');

% Define trajectory waypoints in NED frame
% Track along North direction (heading = 0 deg)
fprintf('Trajectory Waypoints (NED frame):\n');

% Start point
N_start = 0;
E_start = 0;
D_start = ALTITUDE_NED;
fprintf('  Start: (N=%.1f, E=%.1f, D=%.1f) m\n', N_start, E_start, D_start);

% End point (1 km North)
N_end = SEGMENT_LENGTH_M;
E_end = 0;  % Straight track, no east deviation
D_end = ALTITUDE_NED;
fprintf('  End:   (N=%.1f, E=%.1f, D=%.1f) m\n\n', N_end, E_end, D_end);

% Create timeseries trajectory
% Use 3 waypoints: start, middle, end for smooth trajectory
% IMPORTANT: time must be a COLUMN vector for GUAM
time = [0; NOMINAL_TIME_S/2; NOMINAL_TIME_S];
N_time = length(time);

% Position waypoints (NED)
pos = zeros(N_time, 3);
pos(:,1) = [N_start; (N_start+N_end)/2; N_end];  % North
pos(:,2) = [E_start; (E_start+E_end)/2; E_end];  % East
pos(:,3) = [D_start; (D_start+D_end)/2; D_end];  % Down

% Velocity in inertial frame (constant along North)
vel_i = zeros(N_time, 3);
vel_i(:,1) = GROUND_SPEED_MS;  % North velocity
vel_i(:,2) = 0;                % East velocity
vel_i(:,3) = 0;                % Down velocity

fprintf('Velocity Profile:\n');
fprintf('  V_north: %.2f m/s\n', vel_i(1,1));
fprintf('  V_east:  %.2f m/s\n', vel_i(1,2));
fprintf('  V_down:  %.2f m/s\n\n', vel_i(1,3));

% Compute heading and heading rate
chi = atan2(vel_i(:,2), vel_i(:,1));  % Heading angle
chid = gradient(chi) ./ gradient(time); % Heading rate

fprintf('Heading:\n');
fprintf('  Chi: %.2f deg (North)\n', rad2deg(chi(1)));
fprintf('  Chi_dot: %.4f deg/s\n\n', rad2deg(chid(1)));

% Add STARS library for quaternion functions (required for QrotZ and Qtrans)
addpath(genpath('lib'));

% Transform velocity to heading frame
q = QrotZ(chi);
vel = Qtrans(q, vel_i);

% Create RefInput structure for GUAM
RefInput.Vel_bIc_des  = timeseries(vel, time);   % Heading frame velocity
RefInput.pos_des      = timeseries(pos, time);   % Inertial position (NED)
RefInput.chi_des      = timeseries(chi, time);   % Heading angle
RefInput.chi_dot_des  = timeseries(chid, time);  % Heading rate
RefInput.vel_des      = timeseries(vel_i, time); % Inertial velocity

fprintf('RefInput structure created for GUAM\n\n');

%% SECTION 4: CONFIGURE WIND ENVIRONMENT
fprintf('SECTION 4: WIND ENVIRONMENT CONFIGURATION\n');
fprintf('──────────────────────────────────────────\n\n');

% Calculate wind vector in NED frame
% Track is along North (0 deg), crosswind is perpendicular (East)
wind_angle_rad = deg2rad(TRACK_HEADING_DEG + CROSSWIND_DIR_DEG);
Wind_N = CROSSWIND_MS * cos(wind_angle_rad);
Wind_E = CROSSWIND_MS * sin(wind_angle_rad);
Wind_D = 0;

fprintf('Wind Vector (NED frame):\n');
fprintf('  Wind_North: %.2f m/s\n', Wind_N);
fprintf('  Wind_East:  %.2f m/s (crosswind)\n', Wind_E);
fprintf('  Wind_Down:  %.2f m/s\n\n', Wind_D);

% Store wind configuration
% Note: We'll modify setupWinds.m or inject wind directly
wind_config.Vel_wHh = [Wind_N; Wind_E; Wind_D];
wind_config.VelDtH_wHh = [0; 0; 0];  % No wind gradient
wind_config.Gust_wHh = [0; 0; 0];    % No gusts

%% SECTION 5: CONFIGURE GUAM SIMULATION
fprintf('SECTION 5: GUAM SIMULATION CONFIGURATION\n');
fprintf('─────────────────────────────────────────\n\n');

% Step 1: Configure variants BEFORE calling simSetup
% Use RefInputEnum.TIMESERIES (value = 3)
userStruct.variants.refInputType = 3;  % Timeseries input

% Use CtrlEnum.BASELINE (value = 2)
userStruct.variants.ctrlType = 2;      % Baseline LQRi controller

fprintf('Step 5.1: Simulation Variants Configured\n');
fprintf('  refInputType: %d (TIMESERIES)\n', userStruct.variants.refInputType);
fprintf('  ctrlType: %d (BASELINE)\n\n', userStruct.variants.ctrlType);

% Step 2: Assign reference trajectory to target BEFORE simSetup
target.RefInput = RefInput;
fprintf('Step 5.2: Reference trajectory assigned to target.RefInput\n\n');

% Step 3: Call simSetup to initialize simulation
fprintf('Step 5.3: Calling simSetup...\n');
simSetup;
fprintf('  ✓ simSetup complete\n\n');

% Step 4: Modify wind configuration AFTER simSetup
% SimInput is created by simSetup in base workspace
fprintf('Step 5.4: Configuring wind environment...\n');
try
    % Check if SimInput exists in base workspace
    evalin('base', 'SimInput;');
    
    % Inject wind vector
    evalin('base', sprintf('SimInput.Environment.Winds.Vel_wHh = [%.4f; %.4f; %.4f];', ...
           Wind_N, Wind_E, Wind_D));
    fprintf('  ✓ Wind vector injected: [%.2f, %.2f, %.2f] m/s\n\n', Wind_N, Wind_E, Wind_D);
catch ME
    fprintf('  ⚠ Warning: Could not set wind. Error: %s\n', ME.message);
    fprintf('  Continuing with zero wind...\n\n');
end

% Step 5: Set simulation stop time
fprintf('Step 5.5: Setting simulation parameters...\n');
set_param(model, 'StopTime', num2str(TOTAL_TIME_S));
fprintf('  ✓ Simulation stop time: %.1f s\n\n', TOTAL_TIME_S);

%% SECTION 6: RUN SIMULATION
fprintf('SECTION 6: RUNNING SIMULATION\n');
fprintf('──────────────────────────────\n\n');

fprintf('Starting GUAM simulation...\n');
fprintf('Please wait (this may take 1-2 minutes)...\n\n');

% Load model if not already loaded
if ~bdIsLoaded(model)
    fprintf('Loading model %s...\n', model);
    load_system(model);
end

tic;
sim(model);
sim_time = toc;

fprintf('✓ Simulation completed successfully\n');
fprintf('  Elapsed time: %.1f seconds\n\n', sim_time);

%% SECTION 7: EXTRACT SIMULATION DATA
fprintf('SECTION 7: DATA EXTRACTION\n');
fprintf('───────────────────────────\n\n');

% Extract logged data
logsout = evalin('base', 'logsout');
SimOut = logsout{1}.Values;

% Extract vehicle position (NED frame)
pos_data = squeeze(SimOut.Vehicle.EOM.InertialData.Pos_bii.Data);
time_sim = SimOut.Vehicle.EOM.InertialData.Pos_bii.Time;

% Extract individual position components
N_actual = pos_data(:,1);  % North position
E_actual = pos_data(:,2);  % East position
D_actual = pos_data(:,3);  % Down position

fprintf('Extracted Data:\n');
fprintf('  Time points: %d samples\n', length(time_sim));
fprintf('  Position range:\n');
fprintf('    North: %.1f to %.1f m\n', min(N_actual), max(N_actual));
fprintf('    East:  %.1f to %.1f m\n', min(E_actual), max(E_actual));
fprintf('    Down:  %.1f to %.1f m\n\n', min(D_actual), max(D_actual));

%% SECTION 8: COMPUTE REFERENCE TRAJECTORY AT SIMULATION TIME POINTS
fprintf('SECTION 8: REFERENCE TRAJECTORY INTERPOLATION\n');
fprintf('──────────────────────────────────────────────\n\n');

% Interpolate reference position to match simulation time points
N_ref = interp1(time, pos(:,1), time_sim, 'linear', 'extrap');
E_ref = interp1(time, pos(:,2), time_sim, 'linear', 'extrap');
D_ref = interp1(time, pos(:,3), time_sim, 'linear', 'extrap');

fprintf('Reference trajectory interpolated to %d simulation time points\n\n', ...
        length(time_sim));

%% SECTION 9: COMPUTE FLIGHT TECHNICAL ERROR (FTE)
fprintf('SECTION 9: FLIGHT TECHNICAL ERROR COMPUTATION\n');
fprintf('──────────────────────────────────────────────\n\n');

fprintf('FTE Calculation Method:\n');
fprintf('  Track heading: %.1f deg (North)\n', TRACK_HEADING_DEG);
fprintf('  For heading = 0 deg (North track):\n');
fprintf('    - Longitudinal error (along-track): e_parallel = N - N_ref\n');
fprintf('    - Lateral error (cross-track/FTE):  e_lateral  = E - E_ref\n\n');

% Position errors in NED frame
dN = N_actual - N_ref;  % North error
dE = E_actual - E_ref;  % East error
dD = D_actual - D_ref;  % Down error (altitude error)

% For North track (heading = 0), track-aligned coordinates are simple:
% Along-track (longitudinal) error
e_parallel = dN;

% Cross-track (lateral) error = FTE
e_lateral = dE;  % This is the Flight Technical Error

% Altitude error
e_altitude = -dD;  % Convert NED down to altitude (positive up)

fprintf('Error Statistics:\n\n');

% Lateral FTE statistics
max_lateral = max(abs(e_lateral));
rms_lateral = sqrt(mean(e_lateral.^2));
p95_lateral = prctile(abs(e_lateral), 95);

fprintf('Lateral FTE (Cross-track error):\n');
fprintf('  Maximum absolute error: %.2f m\n', max_lateral);
fprintf('  RMS error:              %.2f m\n', rms_lateral);
fprintf('  95th percentile:        %.2f m\n\n', p95_lateral);

% Along-track error statistics
max_parallel = max(abs(e_parallel));
rms_parallel = sqrt(mean(e_parallel.^2));

fprintf('Along-track error:\n');
fprintf('  Maximum absolute error: %.2f m\n', max_parallel);
fprintf('  RMS error:              %.2f m\n\n', rms_parallel);

% Altitude error statistics
max_altitude = max(abs(e_altitude));
rms_altitude = sqrt(mean(e_altitude.^2));

fprintf('Altitude error:\n');
fprintf('  Maximum absolute error: %.2f m\n', max_altitude);
fprintf('  RMS error:              %.2f m\n\n', rms_altitude);

%% SECTION 10: GENERATE PLOTS
fprintf('SECTION 10: GENERATING PLOTS\n');
fprintf('────────────────────────────\n\n');

% Create figure directory
fig_dir = 'Crosswind_FTE_Results';
if ~exist(fig_dir, 'dir')
    mkdir(fig_dir);
end

%% Plot 1: 2D Ground Track
figure('Position', [100, 100, 800, 600]);

plot(E_ref, N_ref, 'k--', 'LineWidth', 2, 'DisplayName', 'Desired Path');
hold on;
plot(E_actual, N_actual, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Actual Path');

% Mark start and end points
plot(E_ref(1), N_ref(1), 'go', 'MarkerSize', 10, 'MarkerFaceColor', 'g', ...
     'DisplayName', 'Start');
plot(E_ref(end), N_ref(end), 'rs', 'MarkerSize', 10, 'MarkerFaceColor', 'r', ...
     'DisplayName', 'End');

% Add wind arrow
wind_arrow_start = [0, 500];  % Middle of path
wind_arrow_scale = 50;  % Scale for visibility
quiver(wind_arrow_start(1), wind_arrow_start(2), ...
       Wind_E*wind_arrow_scale, Wind_N*wind_arrow_scale, ...
       0, 'Color', 'r', 'LineWidth', 2, 'MaxHeadSize', 2, ...
       'DisplayName', sprintf('Crosswind (%.0f kt)', CROSSWIND_KT));

grid on;
xlabel('East (m)', 'FontSize', 12);
ylabel('North (m)', 'FontSize', 12);
title(sprintf('Ground Track: 1 km Straight Segment with %.0f kt Crosswind', ...
      CROSSWIND_KT), 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
axis equal;

% Save figure
saveas(gcf, fullfile(fig_dir, 'Ground_Track.png'));
fprintf('✓ Saved: Ground_Track.png\n');

%% Plot 2: Lateral FTE vs Time
figure('Position', [150, 150, 1000, 600]);

subplot(2,1,1);
plot(time_sim, e_lateral, 'b-', 'LineWidth', 1.5);
hold on;
yline(0, 'k--', 'LineWidth', 1);
yline(max_lateral, 'r--', 'LineWidth', 1, ...
      'Label', sprintf('Max = %.2f m', max_lateral), 'LabelHorizontalAlignment', 'left');
yline(-max_lateral, 'r--', 'LineWidth', 1, ...
      'Label', sprintf('Min = %.2f m', -max_lateral), 'LabelHorizontalAlignment', 'left');
grid on;
xlabel('Time (s)', 'FontSize', 12);
ylabel('Lateral FTE (m)', 'FontSize', 12);
title(sprintf('Lateral Flight Technical Error (Crosswind: %.0f kt, Ground Speed: %.0f kt)', ...
      CROSSWIND_KT, GROUND_SPEED_KT), 'FontSize', 14, 'FontWeight', 'bold');
legend('Lateral FTE', 'Zero Error', 'Location', 'best');

subplot(2,1,2);
plot(time_sim, abs(e_lateral), 'b-', 'LineWidth', 1.5);
hold on;
yline(rms_lateral, 'g--', 'LineWidth', 2, ...
      'Label', sprintf('RMS = %.2f m', rms_lateral), 'LabelHorizontalAlignment', 'left');
yline(p95_lateral, 'm--', 'LineWidth', 2, ...
      'Label', sprintf('95%% = %.2f m', p95_lateral), 'LabelHorizontalAlignment', 'left');
grid on;
xlabel('Time (s)', 'FontSize', 12);
ylabel('|Lateral FTE| (m)', 'FontSize', 12);
title('Absolute Lateral FTE with Statistics', 'FontSize', 13, 'FontWeight', 'bold');
legend('|Lateral FTE|', 'Location', 'best');

% Save figure
saveas(gcf, fullfile(fig_dir, 'Lateral_FTE.png'));
fprintf('✓ Saved: Lateral_FTE.png\n');

%% Plot 3: All Error Components
figure('Position', [200, 200, 1000, 800]);

subplot(3,1,1);
plot(time_sim, e_lateral, 'b-', 'LineWidth', 1.5);
hold on;
yline(0, 'k--');
grid on;
ylabel('Lateral Error (m)', 'FontSize', 11);
title('Position Errors vs Time', 'FontSize', 14, 'FontWeight', 'bold');
legend('Cross-track (FTE)', 'Location', 'best');

subplot(3,1,2);
plot(time_sim, e_parallel, 'r-', 'LineWidth', 1.5);
hold on;
yline(0, 'k--');
grid on;
ylabel('Along-track Error (m)', 'FontSize', 11);
legend('Longitudinal', 'Location', 'best');

subplot(3,1,3);
plot(time_sim, e_altitude, 'g-', 'LineWidth', 1.5);
hold on;
yline(0, 'k--');
grid on;
xlabel('Time (s)', 'FontSize', 12);
ylabel('Altitude Error (m)', 'FontSize', 11);
legend('Vertical', 'Location', 'best');

% Save figure
saveas(gcf, fullfile(fig_dir, 'All_Errors.png'));
fprintf('✓ Saved: All_Errors.png\n\n');

%% SECTION 11: SAVE RESULTS
fprintf('SECTION 11: SAVING RESULTS\n');
fprintf('──────────────────────────\n\n');

% Create results structure
results = struct();
results.parameters = struct( ...
    'segment_length_m', SEGMENT_LENGTH_M, ...
    'ground_speed_kt', GROUND_SPEED_KT, ...
    'altitude_ft', ALTITUDE_FT, ...
    'crosswind_kt', CROSSWIND_KT, ...
    'track_heading_deg', TRACK_HEADING_DEG ...
);

results.time = time_sim;
results.position_actual = [N_actual, E_actual, D_actual];
results.position_ref = [N_ref, E_ref, D_ref];
results.errors = struct( ...
    'lateral', e_lateral, ...
    'longitudinal', e_parallel, ...
    'altitude', e_altitude ...
);

results.statistics = struct( ...
    'lateral_max_m', max_lateral, ...
    'lateral_rms_m', rms_lateral, ...
    'lateral_95p_m', p95_lateral, ...
    'longitudinal_max_m', max_parallel, ...
    'longitudinal_rms_m', rms_parallel, ...
    'altitude_max_m', max_altitude, ...
    'altitude_rms_m', rms_altitude ...
);

% Save to MAT file
save(fullfile(fig_dir, 'Crosswind_FTE_Results.mat'), 'results');
fprintf('✓ Saved: Crosswind_FTE_Results.mat\n');

% Export to Excel
results_table = table( ...
    time_sim, N_actual, E_actual, D_actual, ...
    N_ref, E_ref, D_ref, ...
    e_lateral, e_parallel, e_altitude, ...
    'VariableNames', {'Time_s', 'N_actual_m', 'E_actual_m', 'D_actual_m', ...
                      'N_ref_m', 'E_ref_m', 'D_ref_m', ...
                      'Lateral_FTE_m', 'Longitudinal_Error_m', 'Altitude_Error_m'} ...
);

writetable(results_table, fullfile(fig_dir, 'Crosswind_FTE_Data.xlsx'));
fprintf('✓ Saved: Crosswind_FTE_Data.xlsx\n\n');

%% SECTION 12: FINAL SUMMARY
fprintf('╔════════════════════════════════════════════════════════════════╗\n');
fprintf('║                      ANALYSIS COMPLETE                         ║\n');
fprintf('╚════════════════════════════════════════════════════════════════╝\n\n');

fprintf('SIMULATION SUMMARY\n');
fprintf('──────────────────\n');
fprintf('Flight Parameters:\n');
fprintf('  • Distance: %.0f m\n', SEGMENT_LENGTH_M);
fprintf('  • Ground Speed: %.0f kt (%.1f m/s)\n', GROUND_SPEED_KT, GROUND_SPEED_MS);
fprintf('  • Altitude: %.0f ft (%.1f m)\n', ALTITUDE_FT, ALTITUDE_M);
fprintf('  • Crosswind: %.0f kt (%.1f m/s)\n', CROSSWIND_KT, CROSSWIND_MS);
fprintf('  • Controller: GUAM Baseline (LQRi)\n\n');

fprintf('LATERAL FTE RESULTS (Key Metric)\n');
fprintf('─────────────────────────────────\n');
fprintf('  • Maximum: %.2f m\n', max_lateral);
fprintf('  • RMS:     %.2f m\n', rms_lateral);
fprintf('  • 95%%ile:  %.2f m\n\n', p95_lateral);

fprintf('OUTPUTS\n');
fprintf('───────\n');
fprintf('  Location: %s/\n', fig_dir);
fprintf('  • Ground_Track.png      - 2D flight path visualization\n');
fprintf('  • Lateral_FTE.png       - FTE time history with statistics\n');
fprintf('  • All_Errors.png        - Complete error analysis\n');
fprintf('  • Crosswind_FTE_Results.mat  - MATLAB workspace data\n');
fprintf('  • Crosswind_FTE_Data.xlsx    - Excel spreadsheet\n\n');

fprintf('To modify parameters, edit the USER CONFIGURABLE PARAMETERS section\n');
fprintf('at the top of this script.\n\n');

fprintf('Analysis completed: %s\n', datestr(now));
fprintf('════════════════════════════════════════════════════════════════\n\n');

%% HELPER FUNCTIONS
% (None required for this script - all functionality is inline)
