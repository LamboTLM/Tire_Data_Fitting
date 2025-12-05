%% Step 1: Load and Convert TTC Testdata to tireData Class
clear; clc;

% TTC Data must be in the 0_Tire_test_data.mat folder as .mat data
% this skript loads the Data and combines it into one

addpath("0_Tire_test_data.mat");
addpath("Functions");
files = dir(fullfile(pwd, "0_Tire_test_data.mat/", "*.mat"));
file_paths = fullfile({files.folder}, {files.name});
all_segments = create_Tire_object;

for i = 1:numel(file_paths)
    tmp = load(file_paths{i});
    TireObject_tmp = create_Tire_object;
    TireObject_tmp = populate_tire_object(TireObject_tmp, tmp);
    TireObject_tmp = split(TireObject_tmp,"et");
    all_segments = [all_segments; TireObject_tmp];
end

% Speichern
save('1_All_Segments\Step1_AllSegments.mat', 'all_segments');