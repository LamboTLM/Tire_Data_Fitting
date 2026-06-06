%% Step 3: Reifen-Skalierung (Ansatz 2) und Export
%
%  Berechnet den Skalierungsfaktor k_Fy aus den Rohdaten beider Reifen
%  und wendet ihn auf die Amplitude-Parameter des gefitteten Modells an.
%
%  Logik:
%    Basis-Fit (z.B. 43075, hat Fy-Pure-Daten)
%    + Fx-Fit   (z.B. 43100, hat Fx/Combined-Daten)
%    + k_Fy skaliert die Fy-Amplitude des Basis-Fits auf den Ziel-Reifen
%    + k_Fx wird gleich k_Fy angenommen (gleiche Mischung R20, geometrisch)
%
%  Output: Eine einzelne .tir-Datei fuer den Ziel-Reifen

clear; clc; close all;
addpath("Functions");

%% ── Konfiguration ────────────────────────────────────────────────────────
BASE_MODEL_FILE  = '2_Fitted_Model/Step2_FittedModel.mat';
FX_DATA_DIR = '0_Reifen_43100';
EXPORT_DIR       = '4_Tire_model_export';
EXPORT_FILE      = 'Hoosier_10inch_R20_scaled.tir';

% Skalierungsparameter (koennen manuell ueberschrieben werden)
% Wenn COMPUTE_K = true: k wird aus Rohdaten berechnet
% Wenn COMPUTE_K = false: K_FY_MANUAL wird verwendet
COMPUTE_K    = true;
K_FY_MANUAL  = 0.8618;   % Fallback wenn COMPUTE_K = false

% Filter fuer k-Berechnung
FZ_MIN_K  = 900;   % [N]  Nur Punkte in diesem Fz-Fenster
FZ_MAX_K  = 1300;
SA_MIN_K  = 7;     % [deg] Nur Peak-Bereich (wo MF sensitiv ist)
IA_MAX_K  = 0.3;   % [deg] Nur IA~0

%% ── Basis-Modell laden ───────────────────────────────────────────────────
if ~isfile(BASE_MODEL_FILE)
    error('Basis-Modell fehlt: %s\nErst Step 2 ausfuehren.', BASE_MODEL_FILE);
end
load(BASE_MODEL_FILE);  % -> tm, fit_meta, tire_id_safe

base_tire_id = tire_id_safe;
fprintf('Basis-Modell: %s\n', base_tire_id);
fprintf('Gefittet am:  %s\n\n', fit_meta.FittedOn);

%% ── Skalierungsfaktor berechnen ──────────────────────────────────────────
if COMPUTE_K
    fprintf('Berechne k_Fy aus Rohdaten...\n');
    [k_fy, k_info] = compute_k_fy(DATA_DIR_BASE, DATA_DIR_FX, ...
                                   FZ_MIN_K, FZ_MAX_K, SA_MIN_K, IA_MAX_K);
    fprintf('  k_Fy = %.4f  (N_base=%d, N_fx=%d)\n', ...
            k_fy, k_info.N_base, k_info.N_fx);
    fprintf('  Basis-mu = %.4f ± %.4f\n', k_info.mu_base, k_info.std_base);
    fprintf('  Fx-mu    = %.4f ± %.4f\n', k_info.mu_fx,   k_info.std_fx);

    % Warnung wenn Streuung gross
    if k_info.std_fx / k_info.mu_fx > 0.15
        warning(['Grosse Streuung im Fx-Reifen-Datensatz (CV=%.1f%%).\n' ...
                 'k_Fy koennte unzuverlaessig sein. Manuellen Wert pruefen.'], ...
                 k_info.std_fx / k_info.mu_fx * 100);
    end
else
    k_fy = K_FY_MANUAL;
    fprintf('Manueller k_Fy = %.4f\n', k_fy);
end

% k_Fx = k_Fy (gleiche Mischung R20, nur Breite unterschiedlich)
k_fx = k_fy;
fprintf('  k_Fx = %.4f (= k_Fy, gleiche Mischung)\n\n', k_fx);

%% ── Skalierung anwenden ──────────────────────────────────────────────────
% Nur Amplitude-Parameter skalieren (D-Koeffizienten)
% NICHT skalieren: Form (B,C,E), Schlupfsteifigkeit (K), Combined (R)
tm_scaled = tm;

% Fy Amplitude
tm_scaled.PDY1 = tm.PDY1 * k_fy;
tm_scaled.PDY2 = tm.PDY2 * k_fy;
% PDY3 (Camber-Einfluss auf mu_y) bleibt - ist relativ, nicht absolut

% Fx Amplitude
tm_scaled.PDX1 = tm.PDX1 * k_fx;
tm_scaled.PDX2 = tm.PDX2 * k_fx;

fprintf('Skalierte Parameter:\n');
fprintf('  PDY1: %.4f -> %.4f\n', tm.PDY1, tm_scaled.PDY1);
fprintf('  PDY2: %.4f -> %.4f\n', tm.PDY2, tm_scaled.PDY2);
fprintf('  PDX1: %.4f -> %.4f\n', tm.PDX1, tm_scaled.PDX1);
fprintf('  PDX2: %.4f -> %.4f\n', tm.PDX2, tm_scaled.PDX2);
fprintf('\n');

%% ── Fit Fx auf dem Fx-Reifen (optional, wenn Daten vorhanden) ───────────
% Wenn der Fx-Reifen eigene Longitudinal/Combined-Daten hat,
% den Fx-Fit direkt auf diesen Daten machen (KEINE Skalierung noetig)
if isfolder(FX_DATA_DIR)
    fprintf('Fx-Reifen-Daten gefunden. Lade fuer direkten Fx-Fit...\n');
    % Lade die vorklassifizierten Fx-Segmente falls vorhanden
    fx_seg_file = '1_All_Segments/Step1_Classified_FxReifen.mat';
    if isfile(fx_seg_file)
        fx_data = load(fx_seg_file);
        td_long_fx = tireData.empty;
        td_comb_fx = tireData.empty;
        for i = 1:numel(fx_data.segments)
            td_tmp = build_tireData_simple(fx_data.segments(i));
            switch fx_data.segments(i).meta.TestMethod
                case 'Longitudinal', td_long_fx(end+1) = td_tmp;
                case 'Combined',     td_comb_fx(end+1) = td_tmp;
            end
        end

        if numel(td_long_fx) > 0
            fprintf('Fitte Fx Pure direkt auf Fx-Reifen-Daten...\n');
            [tm_scaled, res] = fit(tm_scaled, td_long_fx, "Fx Pure", PlotFit=true);
            fprintf('  RMSE = %.2f N\n', res.RMSE);
            % Nach direktem Fx-Fit: PDX1/PDX2 wieder zuruecksetzen
            % (wurden jetzt aus echten Daten gefittet, Skalierung nicht mehr noetig)
        end

        if numel(td_comb_fx) > 0
            fprintf('Fitte Combined direkt auf Fx-Reifen-Daten...\n');
            [tm_scaled, res] = fit(tm_scaled, td_comb_fx, "Fx Combined", PlotFit=true);
            fprintf('  RMSE = %.2f N\n', res.RMSE);
            [tm_scaled, res] = fit(tm_scaled, td_comb_fx, "Fy Combined", PlotFit=true);
            fprintf('  RMSE = %.2f N\n', res.RMSE);
        end
    end
end

%% ── Unsicherheits-Report ─────────────────────────────────────────────────
fprintf('\n── Unsicherheitsbericht ───────────────────────────────────────\n');
fprintf('  Basis-Fy-Fit RMSE:     %.1f N\n', fit_meta.Fy_Pure_rmse);
if isfield(fit_meta, 'Fx_Pure_rmse') && ~isnan(fit_meta.Fx_Pure_rmse)
    fprintf('  Basis-Fx-Fit RMSE:     %.1f N\n', fit_meta.Fx_Pure_rmse);
end
fprintf('  Skalierungsfaktor k:   %.4f\n', k_fy);
fprintf('  Amplitude-Fehler:      ~%.1f%%\n', abs(1-k_fy)*100);
fprintf('  Empfehlung:  Dieses Modell ist fuer Fahrdynamikrechnung\n');
fprintf('               geeignet. Nicht fuer Reifenentwicklung verwenden.\n');
fprintf('───────────────────────────────────────────────────────────────\n\n');

%% ── Export ───────────────────────────────────────────────────────────────
if ~isfolder(EXPORT_DIR), mkdir(EXPORT_DIR); end
export_path = fullfile(EXPORT_DIR, EXPORT_FILE);
export(tm_scaled, export_path, overwrite=true);
fprintf('Exportiert: %s\n', export_path);

% Auch skaliertes Modell als .mat speichern
save(fullfile(EXPORT_DIR, 'ScaledModel.mat'), 'tm_scaled', 'k_fy', 'k_fx', ...
     'base_tire_id', 'fit_meta');

%% ══════════════════════════════════════════════════════════════════════════
%% Hilfsfunktionen
%% ══════════════════════════════════════════════════════════════════════════

function [k, info] = compute_k_fy(dir_base, dir_fx, fz_min, fz_max, sa_min, ia_max)
% Berechnet k_Fy = mu_fx / mu_base aus rohen .mat-Dateien
    mu_base = compute_mu_from_dir(dir_base, fz_min, fz_max, sa_min, ia_max);
    mu_fx   = compute_mu_from_dir(dir_fx,   fz_min, fz_max, sa_min, ia_max);

    if isempty(mu_base) || isempty(mu_fx)
        error('Nicht genug Daten fuer k-Berechnung. FZ-Fenster oder SA-Bereich pruefen.');
    end

    k           = mean(mu_fx) / mean(mu_base);
    info.mu_base = mean(mu_base);
    info.std_base= std(mu_base);
    info.mu_fx   = mean(mu_fx);
    info.std_fx  = std(mu_fx);
    info.N_base  = numel(mu_base);
    info.N_fx    = numel(mu_fx);
end


function mu_vals = compute_mu_from_dir(data_dir, fz_min, fz_max, sa_min, ia_max)
% Laedt alle .mat-Dateien in einem Ordner und gibt Fy/Fz-Werte zurueck
    files = dir(fullfile(data_dir, '*.mat'));
    mu_vals = [];
    for i = 1:numel(files)
        d = load(fullfile(files(i).folder, files(i).name));
        if ~all(isfield(d, {'FY','FZ','SA','SL','IA','TSTI'})), continue; end

        sa   = abs(d.SA);
        fy   = abs(d.FY);
        fz   = abs(d.FZ);
        sl   = abs(d.SL);
        ia   = abs(d.IA);
        temp = d.TSTI;

        mask = (temp > 40) & (sl < 0.01) & ...
               (fz > fz_min) & (fz < fz_max) & ...
               (sa > sa_min) & (ia < ia_max);

        if sum(mask) > 10
            mu_vals = [mu_vals; (fy(mask) ./ fz(mask))];  %#ok<AGROW>
        end
    end
end


function td = build_tireData_simple(seg_struct)
% Minimale tireData-Erstellung aus Segment-Struct
    s = seg_struct.data;
    m = seg_struct.meta;
    n = numel(s.et);

    td = tireData();
    td = td.coordinateTransform("SAE");
    td.et = s.et; td.seget = s.et;
    td.segment = ones(n,1); td.measnumb = (1:n)';
    td.Fx = s.FX; td.Fy = s.FY; td.Fz = s.FZ;
    td.Mx = s.MX; td.My = zeros(n,1); td.Mz = s.MZ;
    td.IP = s.P; td.alpha = deg2rad(s.SA); td.gamma = deg2rad(s.IA);
    td.kappa = s.SL; td.phit = zeros(n,1); td.V = s.V;
    td.omega = zeros(n,1);
    td.TtreadI = s.TSTI; td.TtreadC = s.TSTC; td.TtreadO = s.TSTO;
    td.Comments = m.SourceFile; td.TestMethod = m.TestMethod;
    td = td.coordinateTransform("ISO");
end
