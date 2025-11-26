% Check dataset structures
fprintf('Checking Data_Set_2.mat...\n');
if exist('Data_Set_2.mat', 'file')
    ds2 = load('Data_Set_2.mat');
    fprintf('Fields in Data_Set_2:\n');
    disp(fieldnames(ds2));
end

fprintf('\nChecking Data_Set_3.mat...\n');
if exist('Data_Set_3.mat', 'file')
    ds3 = load('Data_Set_3.mat');
    fprintf('Fields in Data_Set_3:\n');
    disp(fieldnames(ds3));
end

fprintf('\nChecking Data_Set_4.mat...\n');
if exist('Data_Set_4.mat', 'file')
    ds4 = load('Data_Set_4.mat');
    fprintf('Fields in Data_Set_4:\n');
    disp(fieldnames(ds4));
end
