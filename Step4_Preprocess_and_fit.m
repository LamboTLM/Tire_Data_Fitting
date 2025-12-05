%% Pre Skirpt
clear;
close all;
clc
addpath("Functions\")

%% Load Testdata
tirepath = pwd;
tydexdir = dir(fullfile(tirepath,"3_1_Segments_for_use","*.mat"));
tydexstr = join([{tydexdir.folder}',{tydexdir.name}'],filesep);

td_temp = [];

for i = 1:1:numel(tydexstr)
    load(string(tydexstr(i)));
    td_temp = [td_temp, td];
end

td = td_temp;

%% Preprocess Tire Data
% Downsample data for quicker Fits but less Quality for high Downsampling
td = downsample(td, 2);

% Filter Data Fx
filter_window = 5;
td = filter(td, channels="Fx", k=filter_window);

% Filter Data Fy
filter_window = 5;
td = filter(td, channels="Fy", k=filter_window);

% "Filter" Data Fz by assigning the mean of Fz to the whole of Fz
td = mean(td, "Fz");

% Filter Data Mx
filter_window = 5;
td = filter(td, channels="Mx", k=filter_window);

% Filter Data Mz
filter_window = 5;
td = filter(td, channels="Mz", k=filter_window);

% Filter Data Fz
filter_window = 5;
td = filter(td, channels="Fz", k=filter_window);

% Pick out Data
Lateral_Data        = td([td.TestMethod] == "Lateral");
Longitudinal_Data   = td([td.TestMethod] == "Longitudinal");
Combined_Data       = td([td.TestMethod] == "Combined");

% Create Tire modell
[tm] = create_tire_modell;

% Set Conditions
[tm] = set_conditions(tm);

% Set Modell limits
[tm] = set_modell_limits (tm , td);

%% Modell fitting
% Pure Fitting

fprintf('Fitte Fy Pure...\n');
[tm, ~]  = fit(tm, Lateral_Data, "Fy Pure", PlotFit=true);

fprintf('Fitte Fx Pure...\n');
[tm, ~]  = fit(tm, Longitudinal_Data, "Fx Pure", PlotFit=true);

fprintf('Fitte Fy Combined...\n');
[tm, ~] = fit(tm, Combined_Data, "Fy Combined", PlotFit=true);

fprintf('Fitte Fx Combined...\n');
[tm, ~] = fit(tm, Combined_Data, "Fx Combined", PlotFit=true);

% Roll werte, hier passen die Testdaten noch nicht
% fprintf('Fitte My Pure (Rollwiderstand)...\n');
% [tm, ~] = fit(tm, Longitudinal_Data, "My", PlotFit=true);
% 
% fprintf('Fitte Mz Pure (Rückstellmoment)...\n');
% [tm, ~]  = fit(tm, Lateral_Data, "Mz Pure", PlotFit=true);
% 
% fprintf('Fitte Mx Pure (Kippmoment)...\n');
% [tm, ~]  = fit(tm, Lateral_Data, "Mx Pure", PlotFit=true);
% 
% fprintf('Fitte Mz Combined...\n');
% [tm, ~] = fit(tm, Combined_Data, "Mz Combined", PlotFit=true);

fprintf('%s - Zeit: %.3f s\n', 'Modell fitting abgeschlossen', toc);

%% Export
exportPath = "4_Tire_model_export";
exportFile = "Testtire_Hossier.tir";
export(tm, fullfile(exportPath, exportFile), overwrite=true);

%% Functions

function [tm] = create_tire_modell
% tic
tm = tireModel.new("MF");
tm.Name = "New Fitted Model";
% fprintf('%s - Zeit: %.3f s\n', 'Create Tire modell', toc);
end

function [tm] = set_conditions(tm)
% tic
tm.INFLPRES = 54000;              % Initialer Fülldruck [Pa] (Für ungeladenen Reifen)
tm.NOMPRES = 54000;               % Nenn-Bezugsdruck [Pa] (MF-Parameter werden relativ dazu gefittet)
tm.FNOMIN = 685;                  % Nenn-Bezugslast [N] (Die vertikale Last, für die die Koeffizienten gelten)
tm.TireSize = "152.4/67R10";      % Reifengröße (Metadaten)
% fprintf('%s - Zeit: %.3f s\n', 'Set Conditions', toc);
end

function [tm] = set_modell_limits (tm , tdnew)
% tic
[tm, ~] = fit(tm, tdnew, "Dimensions");
[tm, ~] = fit(tm, tdnew, "Limits", "Parameters", ["FZMAX", "ALPMIN", "ALPMAX"]);
% fprintf('%s - Zeit: %.3f s\n', 'Set Modell limits', toc);
end

function plotTireStatus(tireObj, threshold_SA, threshold_SL, filter_window)
% PLOTTIRESTATUS Visualisiert Alpha, Kappa, V, ET und den Status.
%
% EINGABE:
%   tireObj:       Ein einzelnes tireData-Objekt (z.B. td(1))
%   threshold_SA:  Grenzwert Alpha [deg] (Standard: 0.2)
%   threshold_SL:  Grenzwert Kappa [-]   (Standard: 0.005)
%   filter_window: Fenstergröße Glättung (Standard: 51)

%% Unpack Data
alpha = tireObj.alpha;
kappa = tireObj.kappa;
v_sig = tireObj.V;

% Zeitachse und ET-Daten
et_data = tireObj.et;
t_axis = et_data;
x_label_str = 'Zeit [s]';
Fz_data = tireObj.Fz;

%% Calculation
% Längen anpassen (Sicherstellen, dass alle Vektoren gleich lang sind)
n = min([length(alpha), length(kappa), length(t_axis), length(v_sig), length(et_data)]);

alpha   = alpha(1:n);
kappa   = kappa(1:n);
v_sig   = v_sig(1:n);
et_data = et_data(1:n);
t_axis  = t_axis(1:n);

%% 3. Status berechnen
raw_status = zeros(n, 1);

TYPE_INAKTIV = 0;
TYPE_LATERAL = 1;
TYPE_LONGITUDINAL = 2;
TYPE_COMBINED = 3;

for i = 1:n
    is_lat = abs(alpha(i)) > threshold_SA;
    is_long = abs(kappa(i)) > threshold_SL;
    if is_lat && is_long
        raw_status(i) = TYPE_COMBINED;
    elseif is_lat
        raw_status(i) = TYPE_LATERAL;
    elseif is_long
        raw_status(i) = TYPE_LONGITUDINAL;
    else
        raw_status(i) = TYPE_INAKTIV;
    end
end

% Glättung
smooth_status = medfilt1(raw_status, filter_window);

%% 4. Plotten
f = figure('Name', 'Tire Status Analysis', 'NumberTitle', 'off');
% Fenster etwas höher machen, da wir jetzt 5 Plots haben
% f.Position(4) = f.Position(4) * 1.2;

tiledlayout(6,1, 'TileSpacing', 'compact');

% --- Subplot 1: Slip Angle (Alpha) ---
ax1 = nexttile;
plot(t_axis, alpha, 'LineWidth', 1.5); hold on;
yline(threshold_SA, 'r--', 'Limit', 'LabelHorizontalAlignment', 'left');
yline(-threshold_SA, 'r--', 'Limit', 'LabelHorizontalAlignment', 'left');
ylabel('Alpha [deg]');
title(['Slip Angle (Threshold: ' num2str(threshold_SA) ' deg)']);
grid on;

% --- Subplot 2: Slip Ratio (Kappa) ---
ax2 = nexttile;
plot(t_axis, kappa, 'LineWidth', 1.5); hold on;
yline(threshold_SL, 'm--', 'Limit', 'LabelHorizontalAlignment', 'left');
yline(-threshold_SL, 'm--', 'Limit', 'LabelHorizontalAlignment', 'left');
ylabel('Kappa [-]');
title(['Slip Ratio (Threshold: ' num2str(threshold_SL) ')']);
grid on;

% --- Subplot 3: Velocity (V) ---
ax3 = nexttile;
plot(t_axis, v_sig, 'LineWidth', 1.5, 'Color', '#D95319'); % Matlab Orange
ylabel('V [m/s]'); % Einheit anpassen falls km/h
title('Velocity');
grid on;

% --- Subplot 4: Elapsed Time (ET) ---
ax4 = nexttile;
plot(t_axis, et_data, 'LineWidth', 1.5, 'Color', '#77AC30'); % Matlab Grün
ylabel('ET [s]');
title('Elapsed Time Check');
grid on;

% --- Subplot 5: Status ---
ax5 = nexttile;
hold on;

% Rohdaten (graue Punkte)
h_raw = plot(t_axis, raw_status, 'o','Color', [0.5 0.5 0.5],'MarkerSize', 3,'DisplayName', 'Roh');

% Geglättete Daten
h_smooth = plot(t_axis, smooth_status, '-','LineWidth', 2.5,'DisplayName', ['Filter: ' num2str(filter_window)]);

legend([h_smooth, h_raw], 'Location', 'northwest', 'Orientation', 'horizontal');
yticks([0 1 2 3]);
yticklabels({'Inaktiv', 'Lateral', 'Longit.', 'Combined'});
ylabel('Status');
xlabel(x_label_str);
title('Klassifizierung');
grid on;
ylim([-0.5 3.5]);

% --- Subplot 6: Vertical Force (Fz) ---
ax6 = nexttile;
plot(t_axis,Fz_data, 'LineWidth', 1.5, 'Color', '#D95319'); % Matlab Orange
ylabel('Fz [N]'); % Einheit anpassen falls km/h
title('Vertical Force');
grid on;

% Achsen verknüpfen (Zoom auf einem Plot zoomt alle)
linkaxes([ax1, ax2, ax3, ax4, ax5, ax6], 'x');
end