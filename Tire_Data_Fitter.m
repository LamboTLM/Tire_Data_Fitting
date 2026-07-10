%% Tire Data Fitter
% Skript zum Fitten von Vorgefilterten Reifendaten
% Autor: Lambo

%% Preskript
clc
clear

%% Config
Folder = 'C:\Users\Danie\OneDrive\Desktop\Tire_Data_fitting_MF6.2\02_Filtered_Tire_Data_Objects';
Fittypes = [0, 0, 0, 0]; % Fx_p, Fx_p,

%% Load Data into Workspace and Downsample
tdnew = load_all_files_from_folder(Folder);

% Further Preprocessing
tdnew = downsample(tdnew,2); % Decrease sample rate of tireData object 
tdnew = mean(tdnew, ["Fz","IP"]); % Assign mean value of tire data channel in tireData object to entire tire data channel array

% plot(tdnew([tdnew.TestMethod] == "Lateral"));
% plot(tdnew([tdnew.TestMethod] == "Longitudinal"));
% plot(tdnew([tdnew.TestMethod] == "Combined"));

%% Create Tire Modell
tm = tireModel.new("MF");
tm.Name = "Hossier_R20";

%% Set Nominal Conditions and model Limits
difftable = [];
[tm, ~] = fit(tm, tdnew, "Nominal");
% difftable
[tm, ~] = fit(tm, tdnew, "Dimensions");
% difftable
[tm, difftable] = fit(tm, tdnew, "Limits", "Parameters", ["FZMAX", "ALPMIN", "ALPMAX"]);
difftable

tm.INFLPRES = 54000; % ca. 0,8 Bar
tm.LONGVL  =  11.18;
% tm.FNOMIN = 685;
tm.TireSize = "152.4/67R10";

%% Start Tire modell Fitting
lateral_data = tdnew([tdnew.TestMethod] == "Lateral");
Longitudanal_data = tdnew([tdnew.TestMethod] == 'Longitudinal');
Combined_data = tdnew([tdnew.TestMethod] == "Combined");

% Fit Fy Pure
[tm, ~]  = fit(tm,lateral_data,"Fy Pure",PlotFit=true, FixedParameters="FZMIN");

% Fit Fx Pure
[tm, ~]  = fit(tm,Longitudanal_data,"Fx Pure",PlotFit=true);

% Fit Fy Combined
[tm, ~]  = fit(tm,Combined_data,"Fy Combined",PlotFit=true);

% Fit Fx Combined
[tm, ~]  = fit(tm,Combined_data,"Fx Combined",PlotFit=true);

plot([tm,tireModel.new("MF")],Data=tdnew);

%% Export der .tir datei:
Date = string(today("datetime"));
File_Name = append(tm.Name,'_' ,Date,'.tir');
export(tm,File_Name, overwrite=true);

function All_Files_combined = load_all_files_from_folder(folderPath)
% loadAllMatFiles Lädt alle .mat-Dateien aus einem Ordner in eine Struktur
%
% Eingabe:  folderPath - Pfad zum Zielordner (String oder char)
% Ausgabe:  data       - Struktur, die die Daten aller Dateien enthält

% Standardmäßig leere Struktur zurückgeben, falls nichts gefunden wird
All_Files_combined = [];

% Überprüfen, ob der Ordner überhaupt existiert
if ~isfolder(folderPath)
    warning('Der angegebene Ordner existiert nicht: %s', folderPath);
    return;
end

% Alle .mat-Dateien im Ordner auflisten
filePattern = fullfile(folderPath, '*.mat');
matFiles = dir(filePattern);

% Falls keine Dateien gefunden wurden
if isempty(matFiles)
    fprintf('Keine .mat-Dateien in "%s" gefunden.\n', folderPath);
    return;
end

% Schleife über alle gefundenen Dateien
for i = 1:length(matFiles)
    currentFile = fullfile(matFiles(i).folder, matFiles(i).name);

    % Datei laden und in die Struktur speichern
    currentfile_struc = load(currentFile);
    All_Files_combined = [All_Files_combined; currentfile_struc.tireData_export];

end

end