% Check what's in the datasets
fprintf('Checking Challenge Problems datasets...\n\n');

% Dataset 1: Trajectories
fprintf('=== Dataset 1: Own-Ship Trajectories ===\n');
load('Data_Set_1.mat');
whos
fprintf('\n');

% Dataset 2: Stationary Obstacles
fprintf('=== Dataset 2: Stationary Obstacles ===\n');
load('Data_Set_2.mat');
whos
fprintf('\n');

% Dataset 3: Moving Obstacles
fprintf('=== Dataset 3: Moving Obstacles ===\n');
load('Data_Set_3.mat');
whos
fprintf('\n');

% Dataset 4: Failures
fprintf('=== Dataset 4: Failure Scenarios ===\n');
load('Data_Set_4.mat');
whos
fprintf('\n');
