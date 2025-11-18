% Quick check of what GUAM actually produces
simSetup;
model = 'GUAM';

% Simple cruise setup
userStruct.variants.refInputType = 3;
time = [0; 60]';
pos = [0, 0, -91.44; 1830, 0, -91.44];
vel_i = [30.5, 0, 0; 30.5, 0, 0];
chi = [0; 0];
chid = [0; 0];

addpath(genpath('lib'));
q = QrotZ(chi);
vel = Qtrans(q, vel_i);

RefInput.Vel_bIc_des = timeseries(vel, time);
RefInput.pos_des = timeseries(pos, time);
RefInput.chi_des = timeseries(chi, time);
RefInput.chi_dot_des = timeseries(chid, time);
RefInput.vel_des = timeseries(vel_i, time);
target.RefInput = RefInput;

SimIn.StopTime = 60;
sim(model);

% Extract and plot actual trajectory
logsout = evalin('base', 'logsout');
SimOut = logsout{1}.Values;
pos_actual = squeeze(SimOut.Vehicle.EOM.InertialData.Pos_bii.Data);
time_actual = SimOut.Time.Data;

figure;
subplot(2,2,1);
plot(time_actual, pos_actual(:,1), 'b-', 'LineWidth', 2);
xlabel('Time (s)'); ylabel('North (ft)');
title('North Position vs Time');
grid on;

subplot(2,2,2);
plot(time_actual, pos_actual(:,2), 'r-', 'LineWidth', 2);
xlabel('Time (s)'); ylabel('East (ft)');
title('East Position vs Time');
grid on;

subplot(2,2,3);
plot(time_actual, -pos_actual(:,3), 'g-', 'LineWidth', 2);
xlabel('Time (s)'); ylabel('Altitude (ft)');
title('Altitude vs Time');
grid on;

subplot(2,2,4);
plot(pos_actual(:,1), pos_actual(:,2), 'b-', 'LineWidth', 2);
xlabel('North (ft)'); ylabel('East (ft)');
title('Ground Track');
axis equal; grid on;

fprintf('Position range:\n');
fprintf('  North: %.1f to %.1f ft\n', min(pos_actual(:,1)), max(pos_actual(:,1)));
fprintf('  East: %.1f to %.1f ft\n', min(pos_actual(:,2)), max(pos_actual(:,2)));
fprintf('  Down: %.1f to %.1f ft\n', min(pos_actual(:,3)), max(pos_actual(:,3)));
