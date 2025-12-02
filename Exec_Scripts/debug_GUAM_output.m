%% Debug GUAM Output Structure
% Check what logsout contains

clear all; close all; clc;

fprintf('Debugging GUAM output structure...\n\n');

% Navigate to GUAM root
script_dir = fileparts(mfilename('fullpath'));
guam_root = fileparts(script_dir);
cd(guam_root);

% Add paths
addpath(genpath('lib'));
addpath(genpath('Exec_Scripts'));
addpath(genpath('Utilities'));
addpath(genpath('Bez_Functions'));

model = 'GUAM';

%% Setup a simple test flight
global SimIn userStruct target

% Simple straight trajectory
R = 1500;  % 1500m radius
flight_time_s = 30;  % 30 seconds
h_min = 300;
h_max = 600;

% Start and end positions (NED frame)
start_pos_NED = [R, 0, -h_max];  % North boundary, at high altitude
end_pos_NED = [0, 0, -h_min];     % Vertiport center, at low altitude

% Create Bezier waypoints
waypoints_pos = {[start_pos_NED; start_pos_NED], ...
                 [start_pos_NED; end_pos_NED], ...
                 [end_pos_NED; end_pos_NED]};
waypoints_time = [0, flight_time_s];

% Setup userStruct
userStruct = struct();
userStruct.variants = struct();
userStruct.variants.EnvironmentModel = 'IsaAtmosphere';
userStruct.variants.TurbulenceModel = 'None';  % No turbulence for debug
userStruct.variants.WindModel = 'NoWind';      % No wind for debug
userStruct.outputFname = '';
userStruct.trajFile = '';

% Setup target
target = struct();
target.RefInput = struct();
target.RefInput.Bezier = struct();
target.RefInput.Bezier.waypoints = waypoints_pos;
target.RefInput.Bezier.time_wpts = waypoints_time;

% Initial conditions
[pos_i, vel_i, ~, chi, chid] = evalSegments(waypoints_pos{1}, waypoints_pos{2}, waypoints_pos{3}, ...
    waypoints_time(1), waypoints_time(2), waypoints_time(3), 0);

Q_i2c = [cos(chi/2), 0*sin(chi/2), 0*sin(chi/2), sin(chi/2)]';
target.RefInput.Vel_bIc_des = Qtrans(Q_i2c, vel_i);
target.RefInput.pos_des = pos_i;
target.RefInput.chi_des = chi;
target.RefInput.chi_dot_des = chid;
target.RefInput.trajectory.refTime = [0, flight_time_s];

fprintf('Running simSetup...\n');
simSetup;

fprintf('SimIn structure created\n\n');

% Set stop time
total_sim_time_s = flight_time_s + 10;
SimIn.stopTime = total_sim_time_s;

fprintf('Running GUAM simulation...\n');
fprintf('Stop time: %.1f s\n\n', total_sim_time_s);

try
    simOut = sim(model, 'ReturnWorkspaceOutputs', 'on', 'StopTime', num2str(total_sim_time_s));
    fprintf('✓ Simulation completed successfully!\n\n');
    
    % Examine logsout
    fprintf('═══════════════════════════════════════════════════════\n');
    fprintf('LOGSOUT STRUCTURE\n');
    fprintf('═══════════════════════════════════════════════════════\n\n');
    
    logsout = simOut.logsout;
    
    fprintf('logsout class: %s\n', class(logsout));
    fprintf('Number of elements: %d\n\n', logsout.numElements);
    
    fprintf('Available signals:\n');
    fprintf('%-30s %-20s %-15s\n', 'Name', 'Class', 'Size');
    fprintf('%-30s %-20s %-15s\n', repmat('-', 1, 30), repmat('-', 1, 20), repmat('-', 1, 15));
    
    for i = 1:logsout.numElements
        elem = logsout{i};
        elem_name = elem.Name;
        elem_class = class(elem.Values);
        
        if isa(elem.Values, 'timeseries')
            elem_size = size(elem.Values.Data);
            elem_size_str = sprintf('[%s]', num2str(elem_size));
        else
            elem_size_str = 'N/A';
        end
        
        fprintf('%-30s %-20s %-15s\n', elem_name, elem_class, elem_size_str);
    end
    
    fprintf('\n');
    fprintf('═══════════════════════════════════════════════════════\n');
    fprintf('TRYING TO EXTRACT POSITION DATA\n');
    fprintf('═══════════════════════════════════════════════════════\n\n');
    
    % Try different possible names for position
    possible_pos_names = {'Pos_bIi', 'Position', 'pos', 'Pos', 'pos_NED', 'Pos_NED'};
    
    pos_found = false;
    for i = 1:length(possible_pos_names)
        try
            fprintf('Trying: %s ... ', possible_pos_names{i});
            pos_data = logsout.getElement(possible_pos_names{i});
            
            if ~isempty(pos_data)
                fprintf('✓ FOUND!\n');
                fprintf('  Class: %s\n', class(pos_data.Values));
                fprintf('  Data size: %s\n', mat2str(size(pos_data.Values.Data)));
                fprintf('  Time length: %d\n', length(pos_data.Values.Time));
                fprintf('  First few positions:\n');
                disp(pos_data.Values.Data(1:min(5, end), :));
                pos_found = true;
                break;
            else
                fprintf('✗ Not found\n');
            end
        catch ME
            fprintf('✗ Error: %s\n', ME.message);
        end
    end
    
    if ~pos_found
        fprintf('\n⚠ WARNING: Could not find position data with standard names!\n');
        fprintf('Please check the logsout element names above.\n');
    end
    
catch ME
    fprintf('✗ Simulation FAILED!\n');
    fprintf('Error: %s\n', ME.message);
    fprintf('Stack:\n');
    for i = 1:length(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
end

fprintf('\n═══════════════════════════════════════════════════════\n');
fprintf('Debug complete!\n');
fprintf('═══════════════════════════════════════════════════════\n');
