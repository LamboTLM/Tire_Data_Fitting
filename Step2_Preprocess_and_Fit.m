function Step2_Preprocess_and_Fit()
%% Step 2 v2: Fit MF6.2 mit stabiler Parameter-Strategie
%
%  Wichtigste Änderungen gegenüber v1:
%
%  1) Eingang ist jetzt all_segments aus Step1_v2 (tireData-Array)
%     → kein separates Preprocessing mehr nötig (Bessel bereits angewendet)
%
%  2) Fit-Sequenz mit expliziter Parameter-Strategie:
%     a) Fy Pure  → nur P-Parameter, PKY1 Vorzeichen-Check
%     b) Fx Pure  → nur P-Parameter
%     c) Combined → R-Parameter mit eingefrorenen Shape/Offset-Parametern
%        RCX1=1, RCY1=1, RHX1=0, RHY1=0 (physikalisch MÜSSEN diese Werte sein)
%        REX1=0, REY1=0 (Overfitting-Schutz)
%        Nur RBX1, RBX2, RBY1, RBY2 werden gefittet
%
%  3) Solver-Optionen: MaxFuncEvals erhöht (9k → 30k)
%
%  4) Nach jedem Fit: Plausibilitätsprüfung mit Warnung + Auto-Korrektur

close all;
addpath("Functions");

%% ── Konfiguration ─────────────────────────────────────────────────────────
IN_FILE  = '1_All_Segments/Step1_AllSegments.mat';
OUT_DIR  = '2_Fitted_Model';
OUT_FILE = fullfile(OUT_DIR, 'Step2_FittedModel.mat');

INFLPRES = 69000;   % [Pa]  ~10 psi
NOMPRES  = 69000;
FNOMIN   = 700;     % [N]   Nennlast

% Downsampling: nur noch leichtes DS (Bessel hat bereits geglättet)
DOWNSAMPLE_FACTOR = 3;   % 100 Hz → ~33 Hz (war 5 in v1)

%% ── Daten laden ──────────────────────────────────────────────────────────
if ~isfile(IN_FILE)
    error('"%s" fehlt. Erst Step1_v2 ausführen.', IN_FILE);
end
load(IN_FILE);  % → all_segments, processed_tires

fprintf('Geladen: %d Segmente total\n\n', numel(all_segments));

%% ── Segmente nach Testmethode und Reifen aufteilen ─────────────────────
%
%  Fit-Zuweisung:
%    Fy Pure  ← Reifen mit den meisten Lateral-Segmenten
%    Fx Pure  ← Reifen mit den meisten Longitudinal-Segmenten
%    Combined ← Reifen mit den meisten Combined-Segmenten
%
n_lat  = [processed_tires.n_lateral];
n_long = [processed_tires.n_longitudinal];
n_comb = [processed_tires.n_combined];

[~, idx_fy]   = max(n_lat);
[~, idx_fx]   = max(n_long);
[~, idx_comb] = max(n_comb);

tire_id_fy   = processed_tires(idx_fy).tire_id;
tire_id_fx   = processed_tires(idx_fx).tire_id;
tire_id_comb = processed_tires(idx_comb).tire_id;

fprintf('Fit-Zuweisung:\n');
fprintf('  Fy Pure  ← "%s"  (%d Seg.)\n', tire_id_fy,   n_lat(idx_fy));
fprintf('  Fx Pure  ← "%s"  (%d Seg.)\n', tire_id_fx,   n_long(idx_fx));
fprintf('  Combined ← "%s"  (%d Seg.)\n', tire_id_comb, n_comb(idx_comb));
fprintf('\n');

% Segmente filtern
td_lat  = filter_by_tire_and_method(all_segments, tire_id_fy,   'Lateral');
td_long = filter_by_tire_and_method(all_segments, tire_id_fx,   'Longitudinal');
td_comb = filter_by_tire_and_method(all_segments, tire_id_comb, 'Combined');

fprintf('Gefunden: Lateral=%d  Long.=%d  Combined=%d\n\n', ...
        numel(td_lat), numel(td_long), numel(td_comb));

if numel(td_lat) == 0
    error('Keine Lateral-Segmente – Fy-Fit nicht möglich.');
end

%% ── Downsampling (leicht, da Bessel bereits geglättet hat) ───────────────
td_lat  = downsample(td_lat,  DOWNSAMPLE_FACTOR);
td_long = downsample(td_long, DOWNSAMPLE_FACTOR);
td_comb = downsample(td_comb, DOWNSAMPLE_FACTOR);

fprintf('Nach DS (Faktor %d):\n', DOWNSAMPLE_FACTOR);
fprintf('  Lateral:    %d Punkte\n', count_pts(td_lat));
fprintf('  Long.:      %d Punkte\n', count_pts(td_long));
fprintf('  Combined:   %d Punkte\n\n', count_pts(td_comb));

%% ── Modell erstellen mit validen Startparametern ─────────────────────────
tm = tireModel.new("MF");
tm.Name     = 'MF_Hoosier_10inch_R20';
tm.INFLPRES = INFLPRES;
tm.NOMPRES  = NOMPRES;
tm.FNOMIN   = FNOMIN;

% Geometrie (Hoosier 43075: 16x7.5-10)
tm.UNLOADED_RADIUS = 0.2032;
tm.WIDTH           = 0.1905;
tm.ASPECT_RATIO    = 0.40;
tm.RIM_RADIUS      = 0.1270;
tm.RIM_WIDTH       = 0.1905;

% Limits aus Daten
td_all = [td_lat, td_long, td_comb];
[tm, ~] = fit(tm, td_all, "Limits", "Parameters", ["FZMAX","ALPMIN","ALPMAX"]);
tm.FZMIN = 0;

%% ── Startparameter: physikalisch begründet ──────────────────────────────
%
%  Fy Pure:
%    mu_y(700N) ≈ 2.0-2.5 für R20 Hoosier → PDY1 = 2.2
%    Degressivität: mu fällt ~10% pro Nennlast → PDY2 = -0.1
%    Peak bei α ≈ 8-10° → PKY1 ≈ 35 (POSITIV!)
%    Fz-Normierung: PKY2 ≈ 2.0

tm.PCY1 =  1.30;   % Formfaktor (fix halten wenn Fit divergiert)
tm.PDY1 =  2.20;   tm.PDY2 = -0.10;
tm.PEY1 = -0.30;   tm.PEY2 = -0.20;
tm.PKY1 = 35.00;   % POSITIV – Cornering Stiffness Amplitude
tm.PKY2 =  2.00;   tm.PKY3 =  0.00;
tm.PKY4 =  2.00;   % Formparameter (meist 2.0)
tm.PHY1 =  0.00;   tm.PHY2 =  0.00;
tm.PVY1 =  0.00;   tm.PVY2 =  0.00;
tm.PDY3 =  0.00;   % Camber-Einfluss auf mu_y (erst später aktivieren)

%  Fx Pure:
%    mu_x ähnlich mu_y → PDX1 = 2.2
%    Peak bei κ ≈ 15% → PKX1 ≈ 45

tm.PCX1 =  1.60;
tm.PDX1 =  2.20;   tm.PDX2 = -0.10;
tm.PEX1 = -0.50;   tm.PEX2 = -0.20;
tm.PKX1 = 45.00;   tm.PKX2 = -0.50;  tm.PKX3 =  0.00;
tm.PHX1 =  0.00;   tm.PHX2 =  0.00;
tm.PVX1 =  0.00;   tm.PVX2 =  0.00;

%  Combined – KRITISCH: Shape- und Offset-Parameter EINFRIEREN
%  RCX1 = 1.0: Kosinusfunktion bleibt im linearen Bereich
%  RHX1 = 0.0: kein künstlicher SA-Offset in G_xa
%  REX1 = 0.0: kein Overfitting durch Krümmungsparameter
%  Nur RBX1 und RBX2 werden gefittet (Steilheit und κ-Einfluss)

tm.RBX1 =  8.0;    tm.RBX2 =  6.0;   tm.RBX3 =  0.0;
tm.RCX1 =  1.0;    % ← EINGEFROREN (Shape muss ~1 sein)
tm.REX1 =  0.0;    % ← EINGEFROREN (Overfitting-Schutz)
tm.REX2 =  0.0;    % ← EINGEFROREN
tm.RHX1 =  0.0;    % ← EINGEFROREN (Offset muss ~0 sein)

tm.RBY1 = 12.0;    tm.RBY2 =  6.0;   tm.RBY3 =  0.0;  tm.RBY4 =  0.0;
tm.RCY1 =  1.0;    % ← EINGEFROREN
tm.REY1 =  0.0;    % ← EINGEFROREN
tm.REY2 =  0.0;    % ← EINGEFROREN
tm.RHY1 =  0.0;    % ← EINGEFROREN
tm.RHY2 =  0.0;    % ← EINGEFROREN

%% ── Fit-Sequenz ───────────────────────────────────────────────────────────
fit_meta          = struct();
fit_meta.FittedOn = datestr(now);
fit_meta.INFLPRES = INFLPRES;
fit_meta.FNOMIN   = FNOMIN;

%% 1. Fy Pure ───────────────────────────────────────────────────────────────
fprintf('━━━ Fit 1/4: Fy Pure [%s] ━━━\n', tire_id_fy);
tic;
[tm, res] = fit(tm, td_lat, "Fy Pure", PlotFit=true);
fit_meta.Fy_Pure_rmse   = extract_rmse(res);
fit_meta.Fy_Pure_time_s = toc;
fprintf('  RMSE = %.1f N  |  t = %.1f s\n', ...
        fit_meta.Fy_Pure_rmse, fit_meta.Fy_Pure_time_s);

% ── Plausibilitätsprüfung nach Fy Pure ──────────────────────────────────
fprintf('  Fy Pure Check:\n');
if tm.PKY1 < 0
    fprintf('  *** PKY1=%.4f NEGATIV – Vorzeichen korrigiert, Refit...\n', tm.PKY1);
    tm.PKY1 = abs(tm.PKY1);
    [tm, res] = fit(tm, td_lat, "Fy Pure", PlotFit=false);
    fit_meta.Fy_Pure_rmse = extract_rmse(res);
    fprintf('       PKY1 korrigiert → Refit RMSE = %.1f N\n', fit_meta.Fy_Pure_rmse);
end
if tm.PDY2 > 0
    warning('PDY2=%.4f positiv (keine Degressivität). Startparameter prüfen.', tm.PDY2);
end
fprintf('  PDY1=%.3f  PDY2=%.3f  PCY1=%.3f  PKY1=%.3f\n\n', ...
        tm.PDY1, tm.PDY2, tm.PCY1, tm.PKY1);

%% 2. Fx Pure ───────────────────────────────────────────────────────────────
if numel(td_long) > 0
    fprintf('━━━ Fit 2/4: Fx Pure [%s] ━━━\n', tire_id_fx);
    tic;
    [tm, res] = fit(tm, td_long, "Fx Pure", PlotFit=true);
    fit_meta.Fx_Pure_rmse   = extract_rmse(res);
    fit_meta.Fx_Pure_time_s = toc;
    fprintf('  RMSE = %.1f N  |  t = %.1f s\n\n', ...
            fit_meta.Fx_Pure_rmse, fit_meta.Fx_Pure_time_s);
else
    fit_meta.Fx_Pure_rmse = NaN;
    fprintf('  Kein Fx-Fit – keine Long.-Segmente.\n\n');
end

%% 3. Combined – Fy ─────────────────────────────────────────────────────────
if numel(td_comb) > 0
    %% ── KRITISCH: Eingefrorene Parameter VOR Combined-Fit setzen ──────────
    %  Auch wenn der Fit sie verändert hat (durch implizite Bounds der Toolbox):
    %  hier explizit zurücksetzen
    tm.RCX1 =  1.0;    % Shape: MUSS 1.0 sein damit G_xa(alpha=0)=1
    tm.RCY1 =  1.0;    % Shape: MUSS 1.0 sein damit G_yk(kappa=0)=1
    tm.RHX1 =  0.0;    % Offset: MUSS 0.0 sein
    tm.RHY1 =  0.0;    % Offset: MUSS 0.0 sein
    tm.RHY2 =  0.0;
    tm.REX1 =  0.0;    % Krümmung: auf 0 eingefroren
    tm.REX2 =  0.0;
    tm.REY1 =  0.0;
    tm.REY2 =  0.0;

    fprintf('━━━ Fit 3/4: Fy Combined [%s] ━━━\n', tire_id_comb);
    fprintf('  (RCX1, RHX1, REX1/2 eingefroren – nur RBX1, RBX2 frei)\n');
    tic;
    [tm, res] = fit(tm, td_comb, "Fy Combined", PlotFit=true);
    fit_meta.Fy_Comb_rmse   = extract_rmse(res);
    fit_meta.Fy_Comb_time_s = toc;
    fprintf('  RMSE = %.1f N  |  t = %.1f s\n\n', ...
            fit_meta.Fy_Comb_rmse, fit_meta.Fy_Comb_time_s);

    % Nach Fy Combined: R-Shape nochmal einfrieren (Toolbox könnte es geändert haben)
    tm.RCX1 = 1.0; tm.RHX1 = 0.0; tm.REX1 = 0.0; tm.REX2 = 0.0;
    tm.RCY1 = 1.0; tm.RHY1 = 0.0; tm.REY1 = 0.0; tm.REY2 = 0.0;

    %% 4. Combined – Fx ─────────────────────────────────────────────────────
    fprintf('━━━ Fit 4/4: Fx Combined [%s] ━━━\n', tire_id_comb);
    tic;
    [tm, res] = fit(tm, td_comb, "Fx Combined", PlotFit=true);
    fit_meta.Fx_Comb_rmse   = extract_rmse(res);
    fit_meta.Fx_Comb_time_s = toc;
    fprintf('  RMSE = %.1f N  |  t = %.1f s\n\n', ...
            fit_meta.Fx_Comb_rmse, fit_meta.Fx_Comb_time_s);

    % Letzte Einfrierung nach allen Combined-Fits
    tm.RCX1 = 1.0; tm.RHX1 = 0.0; tm.REX1 = 0.0; tm.REX2 = 0.0;
    tm.RCY1 = 1.0; tm.RHY1 = 0.0; tm.REY1 = 0.0; tm.REY2 = 0.0;

else
    fit_meta.Fy_Comb_rmse = NaN;
    fit_meta.Fx_Comb_rmse = NaN;
    fprintf('  Kein Combined-Fit – keine Combined-Segmente.\n\n');
end

%% ── Finaler Parameter-Check ──────────────────────────────────────────────
fprintf('\n━━━ Finaler G-Faktor Check ━━━\n');
verify_g_factors(tm);

%% ── Fit-Bericht ──────────────────────────────────────────────────────────
fprintf('\n══ Fit-Bericht ═════════════════════════════════════════════\n');
fprintf('  %-14s  %-44s  %s\n', 'Fit', 'Reifen', 'RMSE [N]');
fprintf('  %s\n', repmat('-',1,70));
fprintf('  %-14s  %-44s  %.1f\n', 'Fy Pure', tire_id_fy, fit_meta.Fy_Pure_rmse);
if ~isnan(fit_meta.Fx_Pure_rmse)
    fprintf('  %-14s  %-44s  %.1f\n', 'Fx Pure', tire_id_fx, fit_meta.Fx_Pure_rmse);
end
if isfield(fit_meta,'Fy_Comb_rmse') && ~isnan(fit_meta.Fy_Comb_rmse)
    fprintf('  %-14s  %-44s  %.1f\n', 'Fy Combined', tire_id_comb, fit_meta.Fy_Comb_rmse);
    fprintf('  %-14s  %-44s  %.1f\n', 'Fx Combined', tire_id_comb, fit_meta.Fx_Comb_rmse);
end
fprintf('═══════════════════════════════════════════════════════════\n\n');

%% ── Speichern ────────────────────────────────────────────────────────────
if ~isfolder(OUT_DIR), mkdir(OUT_DIR); end

% tire_id_safe für Step3 Kompatibilität
tire_id_safe = processed_tires(idx_fy).safe_id;

save(OUT_FILE, 'tm', 'fit_meta', 'processed_tires', 'tire_id_safe');
fprintf('Modell gespeichert: %s\n', OUT_FILE);
fprintf('Nächster Schritt: plot_fit_check() oder Step3_Scale_and_Export()\n');

end % main


%% ══════════════════════════════════════════════════════════════════════════
%% Hilfsfunktionen
%% ══════════════════════════════════════════════════════════════════════════

function td_out = filter_by_tire_and_method(all_segs, tire_id, method)
%  Gibt alle Segmente zurück die zu einem bestimmten Reifen UND einer
%  bestimmten Testmethode gehören
    td_out = tireData.empty;
    for i = 1:numel(all_segs)
        seg = all_segs(i);
        % TireSize enthält die tire_id (gesetzt in populate_tire_object via Comments)
        if strcmp(seg.TestMethod, method) && ...
           (strcmp(seg.TireSize, tire_id) || contains(seg.Comments, tire_id) || ...
            strcmp(seg.Comments, tire_id))
            td_out(end+1) = seg;  %#ok<AGROW>
        end
    end
end


function n = count_pts(td)
    n = 0;
    for i = 1:numel(td)
        n = n + numel(td(i).Fz);
    end
end


function verify_g_factors(tm)
%  Schneller Plausibilitätscheck: G_xa(alpha=0, kappa=0) und G_yk(kappa=0, alpha=0)
%  müssen exakt 1.0 sein – das ist eine mathematische Identität die das Modell
%  garantieren muss, unabhängig von den Fit-Daten.

    try, LXAL = tm.LXAL; catch, LXAL = 1.0; end
    try, LYKA = tm.LYKA; catch, LYKA = 1.0; end

    % G_xa bei alpha=0, kappa=0
    S_hxa = tm.RHX1;
    B_xa  = tm.RBX1 * cos(atan(tm.RBX2 * 0)) * LXAL;
    a_s   = 0 + S_hxa;
    E_xa  = min(tm.REX1, 1.0);
    num   = cos(tm.RCX1*atan(B_xa*a_s   - E_xa*(B_xa*a_s   - atan(B_xa*a_s))));
    den   = cos(tm.RCX1*atan(B_xa*S_hxa - E_xa*(B_xa*S_hxa - atan(B_xa*S_hxa))));
    Gxa_0 = num / max(abs(den), 1e-12);

    % G_yk bei kappa=0, alpha=0
    S_Hk = tm.RHY1;
    k_s  = 0 + S_Hk;
    B_yk = tm.RBY1 * cos(atan(tm.RBY2 * (0 - tm.RBY3))) * LYKA;
    E_yk = min(tm.REY1, 1.0);
    num2 = cos(tm.RCY1*atan(B_yk*k_s  - E_yk*(B_yk*k_s  - atan(B_yk*k_s))));
    den2 = cos(tm.RCY1*atan(B_yk*S_Hk - E_yk*(B_yk*S_Hk - atan(B_yk*S_Hk))));
    Gyk_0 = num2 / max(abs(den2), 1e-12);

    % Output
    fprintf('  RCX1=%.4f  RHX1=%.6f  RBX1=%.4f  RBX2=%.4f\n', ...
            tm.RCX1, tm.RHX1, tm.RBX1, tm.RBX2);
    fprintf('  G_xa(alpha=0, k=0) = %.6f', Gxa_0);
    if abs(Gxa_0 - 1.0) < 0.001
        fprintf('  ✓ OK\n');
    else
        fprintf('  *** FEHLER – Modell ist inkonsistent!\n');
        fprintf('      Ursache: RCX1≠1 oder RHX1≠0. Aktuell: RCX1=%.4f, RHX1=%.4f\n', ...
                tm.RCX1, tm.RHX1);
    end

    fprintf('  RCY1=%.4f  RHY1=%.6f  RBY1=%.4f  RBY2=%.4f\n', ...
            tm.RCY1, tm.RHY1, tm.RBY1, tm.RBY2);
    fprintf('  G_yk(kappa=0, a=0) = %.6f', Gyk_0);
    if abs(Gyk_0 - 1.0) < 0.001
        fprintf('  ✓ OK\n');
    else
        fprintf('  *** FEHLER – Modell ist inkonsistent!\n');
    end
    fprintf('\n');
end


function rmse = extract_rmse(res)
    if isempty(res), rmse = NaN; return; end
    candidates = {'RMSE','RMS','NRMSE','rmse','rms'};
    for k = 1:numel(candidates)
        if ismember(candidates{k}, res.Properties.VariableNames)
            vals = res.(candidates{k});
            rmse = mean(vals(~isnan(vals)));
            return;
        end
    end
    for k = 1:width(res)
        vals = res{:,k};
        if isnumeric(vals)
            rmse = mean(vals(~isnan(vals)));
            return;
        end
    end
    rmse = NaN;
end