function result = run_single_MC_sim(run_id, MC_params, ref_traj, corridor_width, model_name)
%% RUN_SINGLE_MC_SIM
% Run a single Monte Carlo simulation (separate file version)
%
% This is a standalone function (not nested) to avoid workspace issues
%
% Inputs:
%   run_id         - Simulation run ID (1 to N)
%   MC_params      - Monte Carlo parameter structure
%   ref_traj       - Reference trajectory structure
%   corridor_width - Corridor half-width (m)
%   model_name     - GUAM model name ('GUAM')
%
% Outputs:
%   result - Structure with simulation results

    % Initialize result structure
    result = struct();
    result.success = false;
    result.max_lateral_FTE = NaN;
    result.rms_lateral_FTE = NaN;
    result.max_TSE = NaN;
    result.rms_TSE = NaN;
    result.min_distance_to_boundary = NaN;
    result.is_hit = false;
    result.trajectory = struct('N', [], 'E', [], 'D', [], 'time', []);
    
    % Validate run_id
    if ~isnumeric(run_id) || run_id < 1 || run_id > length(MC_params.wind_E_ms)
        warning('Invalid run_id: %s', mat2str(run_id));
        return;
    end
    
    try
        % Extract parameters for this run
        wind_E = MC_params.wind_E_ms(run_id);
        wind_N = MC_params.wind_N_ms(run_id);
        wind_D = MC_params.wind_D_ms(run_id);
        y0 = MC_params.y0_m(run_id);
        heading_err = MC_params.heading_err_deg(run_id);
        nse_sigma = MC_params.nse_sigma_m(run_id);
        
        % Configure for BASELINE controller and TIMESERIES reference
        evalin('base', 'userStruct.variants.refInputType = 3;');  % TIMESERIES
        evalin('base', 'userStruct.variants.ctrlType = 2;');      % BASELINE
        
        % Apply initial conditions
        ref_pos_modified = ref_traj.pos;
        ref_pos_modified(:, 2) = ref_pos_modified(:, 2) + y0;  % Lateral offset
        
        % Modify heading
        ref_chi_modified = ref_traj.chi + deg2rad(heading_err);
        
        % Create RefInput structure
        RefInput.Vel_bIc_des = ref_traj.Vel_bIc_des;
        RefInput.pos_des = timeseries(ref_pos_modified, ref_traj.time);
        RefInput.chi_des = timeseries(ref_chi_modified, ref_traj.time);
        RefInput.chi_dot_des = ref_traj.chi_dot_des;
        RefInput.vel_des = ref_traj.vel_des;
        
        assignin('base', 'RefInput', RefInput);
        evalin('base', 'target.RefInput = RefInput;');
        evalin('base', 'simSetup;');
        
        % Apply wind disturbance
        apply_wind_to_GUAM(wind_N, wind_E, wind_D);
        
        % Run simulation
        evalin('base', sprintf('SimIn.StopTime = %.6f;', ref_traj.time(end)));
        evalin('base', sprintf('sim(''%s'');', model_name));
        
        % Extract results
        logsout = evalin('base', 'logsout');
        SimOut = logsout{1}.Values;
        
        % Get actual trajectory
        time_sim = SimOut.Time.Data;
        pos_data = SimOut.Vehicle.Sensor.Pos_bIi.Data;
        N_actual = pos_data(:,1);  % North
        E_actual = pos_data(:,2);  % East
        D_actual = pos_data(:,3);  % Down
        
        % Compute lateral error (FTE)
        e_lateral = compute_lateral_error(N_actual, E_actual, ref_traj);
        
        % Add navigation sensor error (NSE)
        nse = nse_sigma * randn(size(e_lateral));
        
        % Compute TSE
        tse = compute_TSE(e_lateral, nse);
        
        % Compute distance to boundary
        d_min = compute_min_distance_to_boundary(E_actual, corridor_width);
        
        % Store results
        result.max_lateral_FTE = max(abs(e_lateral));
        result.rms_lateral_FTE = sqrt(mean(e_lateral.^2));
        result.max_TSE = max(abs(tse));
        result.rms_TSE = sqrt(mean(tse.^2));
        result.min_distance_to_boundary = d_min;
        result.is_hit = (d_min < 0);
        result.trajectory.N = N_actual;
        result.trajectory.E = E_actual;
        result.trajectory.D = D_actual;
        result.trajectory.time = time_sim;
        result.success = true;
        
    catch ME
        % Simulation failed
        warning('Run %d failed: %s', run_id, ME.message);
        result.success = false;
    end
end
