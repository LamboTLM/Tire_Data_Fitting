%% RP_TireAnalyzer v1.0 — FSAE TTC Tire Visualization Tool
% Dynamics Regensburg | RP25e
% ═══════════════════════════════════════════════════════════════════════════
%
% AUFBAU:
%   1. CONFIG   → Ordner, Plot-Gruppen, Binning-Parameter
%   2. LADEN    → Alle .mat-Dateien je Ordner automatisch einlesen
%   3. PLOTTEN  → Aktivierte Gruppen je Reifen + Overlay-Vergleich
%
% PLOTS:
%   A — Lateral Fy     (A1–A8)   nur Cornering-Daten
%   B — Längskraft Fx  (B1–B8)   nur Drive/Brake-Daten
%   C — Momente        (C1–C6)   nur Cornering-Daten
%   D — Reibungsellipse(D1–D4)   Lat + Long nötig
%   E — Sturz & Druck  (E1–E4)   Cornering mit IA-Sweep
%   F — Temperatur     (F1–F4)   TTC TSTC/TSTI/TSTO Kanäle
%   G — Geschwindigkeit(G1–G4)   TTC 15/25/45 mph Blöcke
%   H — Verschleiß     (H1–H3)   Neu vs. verschlissen, Transient
%   I — Qualität       (I1–I3)   Zeitkanäle, Status, Coverage
%   Overlay — I4/I5   alle Reifen überlagert
%
% ═══════════════════════════════════════════════════════════════════════════

clear; close all; clc;

%% ╔═══════════════════════════════════════════════════════════════════════╗
%% ║  1. KONFIGURATION — nur diesen Block anpassen                       ║
%% ╚═══════════════════════════════════════════════════════════════════════╝

% ── Reifen-Ordner ─────────────────────────────────────────────────────────
% Format: {'Pfad/zum/Ordner',  'Anzeigename im Plot'}
% Jeder Ordner enthält alle .mat-Dateien eines Reifens (Cornering + Drive/Brake).
CFG.tires = {'0_Tire_test_data\0_Reifen_43075', '0_Tire_test_data\0_Reifen_43100'};

% ── Plot-Gruppen aktivieren ────────────────────────────────────────────────
CFG.plots.A = true;    % Lateral Fy
CFG.plots.B = true;    % Längskraft Fx
CFG.plots.C = true;    % Momente Mz / Mx
CFG.plots.D = true;    % Reibungsellipse  (benötigt Lat + Long)
CFG.plots.E = true;    % Sturz & Druck
CFG.plots.F = true;    % Temperatur
CFG.plots.G = true;    % Geschwindigkeit
CFG.plots.H = true;    % Verschleiß & Transient
CFG.plots.I = true;    % Datenqualität

% ── Einheiten der .mat-Dateien ─────────────────────────────────────────────
% 'USCS' = lb / deg / mph / psi   (TTC Standard-Download)
% 'SI'   = N  / deg / kph / kPa
CFG.units = 'USCS';

% ── Savitzky-Golay Filter für Kennlinien ──────────────────────────────────
CFG.filter.order = 3;
CFG.filter.frame = 21;    % muss ungerade sein

% ── Klassifizierungsschwellen ─────────────────────────────────────────────
CFG.thresh.alpha_deg = 0.5;    % deg  — ab wann gilt α als "aktiv"
CFG.thresh.kappa     = 0.02;   % [–]  — ab wann gilt κ als "aktiv"

% ── Binning-Toleranzen (intern immer SI) ──────────────────────────────────
CFG.bin.fz_tol = 80;     % N
CFG.bin.ia_tol = 0.4;    % deg
CFG.bin.p_tol  = 3.5;    % kPa  (~0.5 psi)
CFG.bin.v_tol  = 2.0;    % m/s  (~7 km/h)

%% ╔═══════════════════════════════════════════════════════════════════════╗
%% ║  2. DATEN LADEN                                                      ║
%% ╚═══════════════════════════════════════════════════════════════════════╝

nT         = size(CFG.tires, 1);
CFG.clr    = lines(max(nT, 3));
tires      = cell(nT, 1);

fprintf('=== RP_TireAnalyzer v1.0 — Lade Reifendaten ===\n');
for t = 1:nT
    tires{t} = ttc_load(CFG.tires{t,1}, CFG.tires{t,2}, CFG);
    fprintf('  [%d] %-30s → %-14s | %d Punkte\n', t, ...
        tires{t}.name, tires{t}.testType, length(tires{t}.alpha));
end
fprintf('\n');

%% ╔═══════════════════════════════════════════════════════════════════════╗
%% ║  3. PLOTS ERZEUGEN                                                   ║
%% ╚═══════════════════════════════════════════════════════════════════════╝

for t = 1:nT
    tire = tires{t};
    hasL = ismember(tire.testType, {'Lateral','Both'});
    hasX = ismember(tire.testType, {'Longitudinal','Both'});
    hasT = ~all(isnan(tire.TSTC));

    fprintf('Plotte %s ...\n', tire.name);
    if CFG.plots.A && hasL,          pg_A(tire, CFG); end
    if CFG.plots.B && hasX,          pg_B(tire, CFG); end
    if CFG.plots.C && hasL,          pg_C(tire, CFG); end
    if CFG.plots.D && hasL && hasX,  pg_D(tire, CFG); end
    if CFG.plots.E && hasL,          pg_E(tire, CFG); end
    if CFG.plots.F && hasT,          pg_F(tire, CFG); end
    if CFG.plots.G,                  pg_G(tire, CFG); end
    if CFG.plots.H,                  pg_H(tire, CFG); end
    if CFG.plots.I,                  pg_I(tire, CFG); end
end

if CFG.plots.I && nT > 1
    pg_overlay(tires, CFG);
end

fprintf('=== Fertig. ===\n');


%% ═══════════════════════════════════════════════════════════════════════════
%                            HILFSFUNKTIONEN
%% ═══════════════════════════════════════════════════════════════════════════

% ─── DATEN LADEN ─────────────────────────────────────────────────────────
function tire = ttc_load(folder, name, CFG)
% Lädt alle .mat-Dateien in FOLDER, konvertiert Einheiten nach SI (intern),
% konkateniert alle Runs und klassifiziert den Testtyp automatisch.

    files = dir(fullfile(folder, '*.mat'));
    if isempty(files)
        error('RP_TireAnalyzer: Keine .mat-Dateien gefunden in:\n  %s', folder);
    end

    % Alle TTC-Kanäle (Calspan Ausgabe)
    ch = {'ET','FX','FY','FZ','MX','MZ','SA','IA','SL','P','V','N', ...
          'TSTC','TSTI','TSTO','RE','RL'};
    raw = struct();
    for f = ch; raw.(f{1}) = []; end
    raw.runID = [];

    for k = 1:numel(files)
        fpath  = fullfile(files(k).folder, files(k).name);
        d      = load(fpath);
        % Länge aus erstem vorhandenem Feld bestimmen
        fnames = fieldnames(d);
        nrows  = numel(d.(fnames{1})(:));
        for f = ch
            fn = f{1};
            if isfield(d, fn)
                raw.(fn) = [raw.(fn); double(d.(fn)(:))];
            else
                raw.(fn) = [raw.(fn); nan(nrows, 1)];
            end
        end
        raw.runID = [raw.runID; k * ones(nrows, 1)];
    end

    % ── Einheitenumrechnung → SI ──────────────────────────────────────
    if strcmpi(CFG.units, 'USCS')
        lb2N     = 4.44822;
        lbft2Nm  = 1.35582;
        mph2ms   = 0.44704;
        psi2kPa  = 6.89476;
        in2m     = 0.0254;
        raw.FX   = raw.FX  * lb2N;
        raw.FY   = raw.FY  * lb2N;
        raw.FZ   = raw.FZ  * lb2N;
        raw.MX   = raw.MX  * lbft2Nm;
        raw.MZ   = raw.MZ  * lbft2Nm;
        raw.V    = raw.V   * mph2ms;
        raw.P    = raw.P   * psi2kPa;
        raw.RE   = raw.RE  * in2m;
        raw.RL   = raw.RL  * in2m;
        % degF → degC
        for tf = {'TSTC','TSTI','TSTO'}
            raw.(tf{1}) = (raw.(tf{1}) - 32) * 5/9;
        end
    else
        % SI: V in kph → m/s
        raw.V = raw.V / 3.6;
    end

    % ── SAE → ISO Vorzeichenkonvention ──────────────────────────────────
    % SAE: FY negativ für positiven SA → ISO: FY positiv für positiven α
    raw.FY = -raw.FY;
    raw.MZ = -raw.MZ;
    raw.SA = -raw.SA;

    % ── Kinematik in SI ─────────────────────────────────────────────────
    alpha = raw.SA * (pi/180);
    gamma = raw.IA * (pi/180);
    kappa = raw.SL;

    % ── Testtyp-Erkennung ────────────────────────────────────────────────
    thr_a = CFG.thresh.alpha_deg * pi/180;
    thr_k = CFG.thresh.kappa;
    hasL  = any(abs(alpha) > thr_a);
    hasX  = any(abs(kappa) > thr_k);
    if hasL && hasX,      testType = 'Both';
    elseif hasL,          testType = 'Lateral';
    elseif hasX,          testType = 'Longitudinal';
    else,                 testType = 'Unknown';
    end

    % ── Tire-Struct befüllen ─────────────────────────────────────────────
    tire.name     = name;
    tire.folder   = folder;
    tire.testType = testType;
    tire.runID    = raw.runID;
    tire.ET       = raw.ET;

    tire.alpha = alpha;
    tire.gamma = gamma;
    tire.kappa = kappa;
    tire.V     = raw.V;
    tire.omega = raw.N * (2*pi/60);

    tire.Fy = raw.FY;
    tire.Fx = raw.FX;
    tire.Fz = abs(raw.FZ);
    tire.Mz = raw.MZ;
    tire.Mx = raw.MX;

    tire.muy  = tire.Fy ./ max(tire.Fz, 1);
    tire.mux  = tire.Fx ./ max(tire.Fz, 1);

    tire.P    = raw.P;
    tire.TSTC = raw.TSTC;
    tire.TSTI = raw.TSTI;
    tire.TSTO = raw.TSTO;
    tire.RE   = raw.RE;
    tire.RL   = raw.RL;

    % ── Nominale Stufen für Binning ──────────────────────────────────────
    tire.fzLevels = nomLevels(tire.Fz,            CFG.bin.fz_tol);
    tire.iaLevels = nomLevels(rad2deg(tire.gamma), CFG.bin.ia_tol);
    tire.pLevels  = nomLevels(tire.P,             CFG.bin.p_tol);
    tire.vLevels  = nomLevels(tire.V,             CFG.bin.v_tol);
end

% ─── NOMINALE STUFEN ERMITTELN ────────────────────────────────────────────
function levels = nomLevels(data, tol)
% Findet diskrete Nennwerte durch iteratives Clustering.
    data = data(isfinite(data));
    if isempty(data), levels = []; return; end
    sorted = sort(unique(round(data / tol) * tol));
    merged = sorted(1);
    for k = 2:numel(sorted)
        if sorted(k) - merged(end) > 2*tol
            merged(end+1) = sorted(k); %#ok<AGROW>
        end
    end
    levels = zeros(1, numel(merged));
    for k = 1:numel(merged)
        levels(k) = median(data(abs(data - merged(k)) <= tol));
    end
    levels = sort(levels);
end

% ─── BINNING-MASKE ───────────────────────────────────────────────────────
function mask = binMask(data, nom, tol)
    mask = abs(data - nom) <= tol;
end

% ─── REGION-MASKEN ───────────────────────────────────────────────────────
function mask = latMask(tire, CFG)
    mask = abs(tire.alpha) > CFG.thresh.alpha_deg*pi/180 & ...
           abs(tire.kappa) <= CFG.thresh.kappa;
end

function mask = longMask(tire, CFG)
    mask = abs(tire.alpha) <= CFG.thresh.alpha_deg*pi/180 & ...
           abs(tire.kappa)  > CFG.thresh.kappa;
end

% ─── FIGURE ERSTELLEN ────────────────────────────────────────────────────
function fig = mkfig(tire, id, subtitle_str)
    fig = figure('Name', sprintf('[%s] %s — %s', tire.name, id, subtitle_str), ...
                 'NumberTitle', 'off');
    fig.Position(3:4) = [900 620];
end

% ─── SG-FILTER WRAPPER ───────────────────────────────────────────────────
function y = sgSmooth(x, CFG)
    if numel(x) > CFG.filter.frame
        y = sgolayfilt(x(:), CFG.filter.order, CFG.filter.frame);
    else
        y = x(:);
    end
end

% ─── SCATTER + COLORBAR ──────────────────────────────────────────────────
function scatter_colored(ax, x, y, c, clab, cmap)
    if nargin < 6, cmap = 'turbo'; end
    scatter(ax, x, y, 3, c, 'filled');
    cb = colorbar(ax); cb.Label.String = clab;
    colormap(ax, cmap);
    grid(ax, 'on'); axis(ax, 'tight');
end

% ─── CORNERING STIFFNESS ─────────────────────────────────────────────────
function Cs = corneringStiffness(alpha, Fy, thr_rad)
    if nargin < 3, thr_rad = 3*pi/180; end
    mask = abs(alpha) < thr_rad & isfinite(Fy) & isfinite(alpha);
    if sum(mask) < 3, Cs = NaN; return; end
    p  = polyfit(alpha(mask), Fy(mask), 1);
    Cs = p(1);
end


%% ═══════════════════════════════════════════════════════════════════════════
%%                        GRUPPE A — LATERAL Fy
%% ═══════════════════════════════════════════════════════════════════════════
function pg_A(tire, CFG)

mL      = latMask(tire, CFG);
adeg    = rad2deg(tire.alpha);
fzLvl   = tire.fzLevels;
col_fz  = parula(max(numel(fzLvl), 2));
iaLvl   = tire.iaLevels;
col_ia  = cool(max(numel(iaLvl),  2));
pLvl    = tire.pLevels;
col_p   = summer(max(numel(pLvl), 2));

%% A1 — Fy vs α, coloriert nach Fz
f = mkfig(tire, 'A1', 'Fy vs α — coloriert nach Fz');
ax = axes(f);
scatter_colored(ax, adeg(mL), tire.Fy(mL), tire.Fz(mL), 'Fz [N]');
xlabel(ax,'α [°]'); ylabel(ax,'Fy [N]');
title(ax, [tire.name ' — Seitenkraft Fy vs Schräglaufwinkel α']);
xline(ax, 0, 'k--', 'Alpha', 0.4);

%% A2 — μy vs α, coloriert nach Fz
f = mkfig(tire, 'A2', 'μy = Fy/Fz vs α');
ax = axes(f);
scatter_colored(ax, adeg(mL), tire.muy(mL), tire.Fz(mL), 'Fz [N]');
xlabel(ax,'α [°]'); ylabel(ax,'μy = Fy/Fz [–]');
title(ax, [tire.name ' — Normierte Seitenkraft μy']);
yline(ax, [1 -1], 'r--', 'Alpha', 0.5);
xline(ax, 0, 'k--', 'Alpha', 0.4);

%% A3 — Fy vs α — iso-Fz Kurven
f = mkfig(tire, 'A3', 'Fy vs α — iso-Fz Kurven');
ax = axes(f); hold(ax,'on');
lgd = strings(1, numel(fzLvl));
for k = 1:numel(fzLvl)
    mF = mL & binMask(tire.Fz, fzLvl(k), CFG.bin.fz_tol);
    if sum(mF) < 10, continue; end
    [as, si] = sort(tire.alpha(mF));
    Fys = sgSmooth(tire.Fy(mF), CFG); Fys = Fys(si);
    plot(ax, rad2deg(as), Fys, '-', 'Color', col_fz(k,:), 'LineWidth', 1.5);
    lgd(k) = sprintf('Fz ≈ %.0f N', fzLvl(k));
end
legend(ax, lgd(lgd ~= ""), 'Location','southeast');
xlabel(ax,'α [°]'); ylabel(ax,'Fy [N]');
title(ax, [tire.name ' — Fy vs α — diskrete Laststufen']);
xline(ax,0,'k--','Alpha',0.4); grid(ax,'on');

%% A4 — Fy vs α — iso-IA Kurven
f = mkfig(tire, 'A4', 'Fy vs α — iso-IA Kurven');
ax = axes(f); hold(ax,'on');
lgd = strings(1, numel(iaLvl));
for k = 1:numel(iaLvl)
    mI = mL & binMask(rad2deg(tire.gamma), iaLvl(k), CFG.bin.ia_tol);
    if sum(mI) < 10, continue; end
    [as, si] = sort(tire.alpha(mI));
    Fys = sgSmooth(tire.Fy(mI), CFG); Fys = Fys(si);
    plot(ax, rad2deg(as), Fys, '-', 'Color', col_ia(k,:), 'LineWidth', 1.5);
    lgd(k) = sprintf('IA ≈ %.1f°', iaLvl(k));
end
legend(ax, lgd(lgd ~= ""), 'Location','southeast');
xlabel(ax,'α [°]'); ylabel(ax,'Fy [N]');
title(ax, [tire.name ' — Fy vs α — diskrete Sturzwinkel']);
xline(ax,0,'k--','Alpha',0.4); grid(ax,'on');

%% A5 — Cornering Stiffness vs Fz
f = mkfig(tire, 'A5', 'Cornering Stiffness vs Fz');
ax = axes(f); hold(ax,'on');
Cs = nan(1, numel(fzLvl));
for k = 1:numel(fzLvl)
    mF = mL & binMask(tire.Fz, fzLvl(k), CFG.bin.fz_tol);
    Cs(k) = corneringStiffness(tire.alpha(mF), tire.Fy(mF));
end
plot(ax, fzLvl, Cs/1000, 'o-', 'LineWidth',1.5, 'Color',[0 0.45 0.74], ...
     'MarkerFaceColor','w', 'MarkerSize',8);
xlabel(ax,'Fz [N]'); ylabel(ax,'CS [kN/rad]');
title(ax, [tire.name ' — Cornering Stiffness vs Normalkraft']);
grid(ax,'on');

%% A6 — Peak Fy & Peak μy vs Fz
f = mkfig(tire, 'A6', 'Peak Fy & Peak μy vs Fz');
tl = tiledlayout(f,1,2,'TileSpacing','compact');
ax1 = nexttile; ax2 = nexttile;
hold(ax1,'on'); hold(ax2,'on');
for k = 1:numel(fzLvl)
    mF = mL & binMask(tire.Fz, fzLvl(k), CFG.bin.fz_tol);
    if sum(mF) < 5, continue; end
    plot(ax1, fzLvl(k), max(tire.Fy(mF)), 'o', 'MarkerSize',9, ...
         'MarkerFaceColor',[0.20 0.60 0.90], 'MarkerEdgeColor','k');
    plot(ax2, fzLvl(k), max(tire.muy(mF)),'o', 'MarkerSize',9, ...
         'MarkerFaceColor',[0.85 0.33 0.10], 'MarkerEdgeColor','k');
end
xlabel(ax1,'Fz [N]'); ylabel(ax1,'Peak Fy [N]');
title(ax1,'Peak Fy vs Fz'); grid(ax1,'on');
xlabel(ax2,'Fz [N]'); ylabel(ax2,'Peak μy [–]');
title(ax2,'Peak μy vs Fz (Lastsensitivität)'); grid(ax2,'on');
title(tl, [tire.name ' — Lastsensitivität']);

%% A7 — Fy vs α — iso-P Kurven
f = mkfig(tire, 'A7', 'Fy vs α — iso-Druck');
ax = axes(f); hold(ax,'on');
lgd = strings(1, numel(pLvl));
for k = 1:numel(pLvl)
    mP = mL & binMask(tire.P, pLvl(k), CFG.bin.p_tol);
    if sum(mP) < 10, continue; end
    [as, si] = sort(tire.alpha(mP));
    Fys = sgSmooth(tire.Fy(mP), CFG); Fys = Fys(si);
    plot(ax, rad2deg(as), Fys, '-', 'Color', col_p(k,:), 'LineWidth', 1.5);
    lgd(k) = sprintf('P ≈ %.0f kPa', pLvl(k));
end
legend(ax, lgd(lgd ~= ""), 'Location','southeast');
xlabel(ax,'α [°]'); ylabel(ax,'Fy [N]');
title(ax, [tire.name ' — Druckeinfluss auf Seitenkraft']);
xline(ax,0,'k--','Alpha',0.4); grid(ax,'on');

%% A8 — 3D-Fläche Fy(α, Fz)
f = mkfig(tire, 'A8', 'Fy(α, Fz) — 3D-Fläche');
ax = axes(f);
mG0 = mL & abs(rad2deg(tire.gamma)) < 0.5;
if sum(mG0) > 50
    xi = linspace(min(adeg(mG0)), max(adeg(mG0)), 60);
    yi = linspace(min(tire.Fz(mG0)), max(tire.Fz(mG0)), 40);
    [XI, YI] = meshgrid(xi, yi);
    ZI = griddata(adeg(mG0), tire.Fz(mG0), tire.Fy(mG0), XI, YI, 'linear');
    surf(ax, XI, YI, ZI, 'EdgeColor','none', 'FaceAlpha',0.85);
    colormap(ax, turbo); colorbar(ax);
    xlabel(ax,'α [°]'); ylabel(ax,'Fz [N]'); zlabel(ax,'Fy [N]');
    title(ax, [tire.name ' — Fy(α, Fz) bei γ ≈ 0°']);
    view(ax,-35,30); grid(ax,'on');
end

end % pg_A


%% ═══════════════════════════════════════════════════════════════════════════
%%                        GRUPPE B — LÄNGSKRAFT Fx
%% ═══════════════════════════════════════════════════════════════════════════
function pg_B(tire, CFG)

mX     = longMask(tire, CFG);
fzLvl  = tire.fzLevels;
col_fz = parula(max(numel(fzLvl),2));
iaLvl  = tire.iaLevels;
col_ia = cool(max(numel(iaLvl),2));

%% B1 — Fx vs κ, coloriert nach Fz
f = mkfig(tire,'B1','Fx vs κ — coloriert nach Fz');
ax = axes(f);
scatter_colored(ax, tire.kappa(mX), tire.Fx(mX), tire.Fz(mX), 'Fz [N]');
xlabel(ax,'κ [–]'); ylabel(ax,'Fx [N]');
title(ax, [tire.name ' — Längskraft Fx vs Schlupf κ']);
xline(ax,0,'k--','Alpha',0.4);

%% B2 — μx vs κ
f = mkfig(tire,'B2','μx = Fx/Fz vs κ');
ax = axes(f);
scatter_colored(ax, tire.kappa(mX), tire.mux(mX), tire.Fz(mX), 'Fz [N]');
xlabel(ax,'κ [–]'); ylabel(ax,'μx = Fx/Fz [–]');
title(ax, [tire.name ' — Normierter Längsgrip μx']);
yline(ax,[1 -1],'r--','Alpha',0.5);
xline(ax,0,'k--','Alpha',0.4);

%% B3 — Fx vs κ — iso-Fz
f = mkfig(tire,'B3','Fx vs κ — iso-Fz');
ax = axes(f); hold(ax,'on');
lgd = strings(1,numel(fzLvl));
for k = 1:numel(fzLvl)
    mF = mX & binMask(tire.Fz, fzLvl(k), CFG.bin.fz_tol);
    if sum(mF) < 10, continue; end
    [ks, si] = sort(tire.kappa(mF));
    Fxs = sgSmooth(tire.Fx(mF), CFG); Fxs = Fxs(si);
    plot(ax, ks, Fxs, '-', 'Color', col_fz(k,:), 'LineWidth', 1.5);
    lgd(k) = sprintf('Fz ≈ %.0f N', fzLvl(k));
end
legend(ax, lgd(lgd ~= ""), 'Location','southeast');
xlabel(ax,'κ [–]'); ylabel(ax,'Fx [N]');
title(ax, [tire.name ' — Fx vs κ — diskrete Laststufen']);
xline(ax,0,'k--','Alpha',0.4); grid(ax,'on');

%% B4 — Fx vs κ — iso-IA
f = mkfig(tire,'B4','Fx vs κ — iso-IA');
ax = axes(f); hold(ax,'on');
lgd = strings(1,numel(iaLvl));
for k = 1:numel(iaLvl)
    mI = mX & binMask(rad2deg(tire.gamma), iaLvl(k), CFG.bin.ia_tol);
    if sum(mI) < 10, continue; end
    [ks, si] = sort(tire.kappa(mI));
    Fxs = sgSmooth(tire.Fx(mI), CFG); Fxs = Fxs(si);
    plot(ax, ks, Fxs, '-', 'Color', col_ia(k,:), 'LineWidth', 1.5);
    lgd(k) = sprintf('IA ≈ %.1f°', iaLvl(k));
end
legend(ax, lgd(lgd ~= ""), 'Location','southeast');
xlabel(ax,'κ [–]'); ylabel(ax,'Fx [N]');
title(ax, [tire.name ' — Fx vs κ — diskrete Sturzwinkel']);
xline(ax,0,'k--','Alpha',0.4); grid(ax,'on');

%% B5 — Peak Fx & μx vs Fz
f = mkfig(tire,'B5','Peak Fx & μx vs Fz');
tl = tiledlayout(f,1,2,'TileSpacing','compact');
ax1 = nexttile; ax2 = nexttile;
hold(ax1,'on'); hold(ax2,'on');
for k = 1:numel(fzLvl)
    mF = mX & binMask(tire.Fz, fzLvl(k), CFG.bin.fz_tol);
    if sum(mF) < 5, continue; end
    plot(ax1, fzLvl(k), max(abs(tire.Fx(mF))), 'o', 'MarkerSize',9, ...
         'MarkerFaceColor',[0.85 0.33 0.10], 'MarkerEdgeColor','k');
    plot(ax2, fzLvl(k), max(abs(tire.mux(mF))),'o', 'MarkerSize',9, ...
         'MarkerFaceColor',[0.47 0.67 0.19], 'MarkerEdgeColor','k');
end
xlabel(ax1,'Fz [N]'); ylabel(ax1,'Peak |Fx| [N]');
title(ax1,'Peak Fx vs Fz'); grid(ax1,'on');
xlabel(ax2,'Fz [N]'); ylabel(ax2,'Peak |μx| [–]');
title(ax2,'Peak μx vs Fz'); grid(ax2,'on');
title(tl, [tire.name ' — Längsgrip Lastsensitivität']);

%% B6 — Slip Stiffness vs Fz
f = mkfig(tire,'B6','Slip Stiffness vs Fz');
ax = axes(f); hold(ax,'on');
Ks = nan(1,numel(fzLvl));
for k = 1:numel(fzLvl)
    mF = mX & binMask(tire.Fz, fzLvl(k), CFG.bin.fz_tol);
    mk = mF & abs(tire.kappa) < 0.05;
    if sum(mk) < 3, continue; end
    p    = polyfit(tire.kappa(mk), tire.Fx(mk), 1);
    Ks(k) = p(1);
end
plot(ax, fzLvl, Ks/1000, 'o-', 'LineWidth',1.5, 'Color',[0.85 0.33 0.10], ...
     'MarkerFaceColor','w', 'MarkerSize',8);
xlabel(ax,'Fz [N]'); ylabel(ax,'Slip Stiffness [kN/–]');
title(ax, [tire.name ' — Slip Stiffness vs Normalkraft']);
grid(ax,'on');

%% B7 — Fx vs κ bei iso-α (kombinierter Schlupf, TTC α=0°/2°/4°)
alp_targets = [0, 2, 4];
col_ab = lines(numel(alp_targets));
f = mkfig(tire,'B7','Fx vs κ — iso-α (kombiniert)');
ax = axes(f); hold(ax,'on');
lgd = strings(1,numel(alp_targets));
for k = 1:numel(alp_targets)
    mA = abs(rad2deg(tire.alpha) - alp_targets(k)) < 1.0 & ...
         abs(tire.kappa) > 0.005;
    if sum(mA) < 10, continue; end
    [ks, si] = sort(tire.kappa(mA));
    Fxs = sgSmooth(tire.Fx(mA), CFG); Fxs = Fxs(si);
    plot(ax, ks, Fxs, '-', 'Color', col_ab(k,:), 'LineWidth', 1.5);
    lgd(k) = sprintf('α ≈ %.0f°', alp_targets(k));
end
legend(ax, lgd(lgd ~= ""), 'Location','southeast');
xlabel(ax,'κ [–]'); ylabel(ax,'Fx [N]');
title(ax, [tire.name ' — Kombinierter Schlupf: Fx bei iso-α']);
xline(ax,0,'k--','Alpha',0.4); grid(ax,'on');

%% B8 — 3D-Fläche Fx(κ, Fz)
f = mkfig(tire,'B8','Fx(κ, Fz) — 3D-Fläche');
ax = axes(f);
mG0 = mX & abs(rad2deg(tire.gamma)) < 0.5;
if sum(mG0) > 50
    xi = linspace(min(tire.kappa(mG0)), max(tire.kappa(mG0)), 60);
    yi = linspace(min(tire.Fz(mG0)),    max(tire.Fz(mG0)),    40);
    [XI, YI] = meshgrid(xi, yi);
    ZI = griddata(tire.kappa(mG0), tire.Fz(mG0), tire.Fx(mG0), XI, YI, 'linear');
    surf(ax, XI, YI, ZI, 'EdgeColor','none', 'FaceAlpha',0.85);
    colormap(ax, turbo); colorbar(ax);
    xlabel(ax,'κ [–]'); ylabel(ax,'Fz [N]'); zlabel(ax,'Fx [N]');
    title(ax, [tire.name ' — Fx(κ, Fz) bei γ ≈ 0°']);
    view(ax,-35,30); grid(ax,'on');
end

end % pg_B


%% ═══════════════════════════════════════════════════════════════════════════
%%                        GRUPPE C — MOMENTE (Mz, Mx)
%% ═══════════════════════════════════════════════════════════════════════════
function pg_C(tire, CFG)

mL    = latMask(tire, CFG);
adeg  = rad2deg(tire.alpha);
fzLvl = tire.fzLevels;
iaLvl = tire.iaLevels;
col_ia = cool(max(numel(iaLvl),2));

%% C1 — Mz vs α, coloriert nach Fz
f = mkfig(tire,'C1','Mz vs α — coloriert nach Fz');
ax = axes(f);
scatter_colored(ax, adeg(mL), tire.Mz(mL), tire.Fz(mL), 'Fz [N]');
xlabel(ax,'α [°]'); ylabel(ax,'Mz [Nm]');
title(ax, [tire.name ' — Ausrichtendes Moment Mz vs α']);
xline(ax,0,'k--','Alpha',0.4);

%% C2 — Mz vs α — iso-IA
f = mkfig(tire,'C2','Mz vs α — iso-IA');
ax = axes(f); hold(ax,'on');
lgd = strings(1,numel(iaLvl));
for k = 1:numel(iaLvl)
    mI = mL & binMask(rad2deg(tire.gamma), iaLvl(k), CFG.bin.ia_tol);
    if sum(mI) < 10, continue; end
    [as, si] = sort(tire.alpha(mI));
    Mzs = sgSmooth(tire.Mz(mI), CFG); Mzs = Mzs(si);
    plot(ax, rad2deg(as), Mzs, '-', 'Color', col_ia(k,:), 'LineWidth',1.5);
    lgd(k) = sprintf('IA ≈ %.1f°', iaLvl(k));
end
legend(ax, lgd(lgd ~= ""), 'Location','northeast');
xlabel(ax,'α [°]'); ylabel(ax,'Mz [Nm]');
title(ax, [tire.name ' — Mz vs α — diskrete Sturzwinkel']);
xline(ax,0,'k--','Alpha',0.4); grid(ax,'on');

%% C3 — Pneumatischer Nachlauf tp = -Mz/Fy
f = mkfig(tire,'C3','Pneumatischer Nachlauf tp = -Mz/Fy');
ax = axes(f);
mV = mL & abs(tire.Fy) > 50;
tp = -tire.Mz(mV) ./ tire.Fy(mV);
scatter_colored(ax, adeg(mV), tp*1000, tire.Fz(mV), 'Fz [N]');
xlabel(ax,'α [°]'); ylabel(ax,'t_p [mm]');
title(ax, [tire.name ' — Pneumatischer Nachlauf (Pneumatic Trail)']);
xline(ax,0,'k--','Alpha',0.4); ylim(ax,[-60 60]);

%% C4 — Mx vs Fz
f = mkfig(tire,'C4','Mx vs Fz — Überrollmoment');
ax = axes(f);
scatter(ax, tire.Fz(mL), tire.Mx(mL), 3, abs(adeg(mL)), 'filled');
cb = colorbar(ax); cb.Label.String = '|α| [°]';
colormap(ax, parula);
xlabel(ax,'Fz [N]'); ylabel(ax,'Mx [Nm]');
title(ax, [tire.name ' — Überrollmoment Mx vs Normalkraft']);
grid(ax,'on'); axis(ax,'tight');

%% C5 — Mx vs α, coloriert nach Fz
f = mkfig(tire,'C5','Mx vs α — coloriert nach Fz');
ax = axes(f);
scatter_colored(ax, adeg(mL), tire.Mx(mL), tire.Fz(mL), 'Fz [N]');
xlabel(ax,'α [°]'); ylabel(ax,'Mx [Nm]');
title(ax, [tire.name ' — Mx vs α']);
xline(ax,0,'k--','Alpha',0.4);

%% C6 — 3D-Fläche Mz(α, Fz)
f = mkfig(tire,'C6','Mz(α, Fz) — 3D-Fläche');
ax = axes(f);
mG0 = mL & abs(rad2deg(tire.gamma)) < 0.5;
if sum(mG0) > 50
    xi = linspace(min(adeg(mG0)), max(adeg(mG0)), 60);
    yi = linspace(min(tire.Fz(mG0)), max(tire.Fz(mG0)), 40);
    [XI,YI] = meshgrid(xi,yi);
    ZI = griddata(adeg(mG0), tire.Fz(mG0), tire.Mz(mG0), XI, YI, 'linear');
    surf(ax, XI, YI, ZI, 'EdgeColor','none', 'FaceAlpha',0.85);
    colormap(ax, turbo); colorbar(ax);
    xlabel(ax,'α [°]'); ylabel(ax,'Fz [N]'); zlabel(ax,'Mz [Nm]');
    title(ax, [tire.name ' — Mz(α, Fz) bei γ ≈ 0°']);
    view(ax,-35,30); grid(ax,'on');
end

end % pg_C


%% ═══════════════════════════════════════════════════════════════════════════
%%                        GRUPPE D — REIBUNGSELLIPSE
%% ═══════════════════════════════════════════════════════════════════════════
function pg_D(tire, CFG)

%% D1 — Reibungsellipse Fy vs Fx
f = mkfig(tire,'D1','Reibungsellipse Fy vs Fx');
ax = axes(f);
scatter_colored(ax, tire.Fx, tire.Fy, tire.Fz, 'Fz [N]');
xlabel(ax,'Fx [N]'); ylabel(ax,'Fy [N]');
title(ax, [tire.name ' — Reibungsellipse']);
xline(ax,0,'k--','Alpha',0.4); yline(ax,0,'k--','Alpha',0.4);
axis(ax,'equal');

%% D2 — Normierte Reibungsellipse μy vs μx
f = mkfig(tire,'D2','μy vs μx — normierte Reibungsellipse');
ax = axes(f);
scatter_colored(ax, tire.mux, tire.muy, tire.Fz, 'Fz [N]');
hold(ax,'on');
th = linspace(0, 2*pi, 200);
plot(ax, cos(th), sin(th), 'k--', 'LineWidth',0.8, 'Alpha',0.5);
xlabel(ax,'μx [–]'); ylabel(ax,'μy [–]');
title(ax, [tire.name ' — Normierte Reibungsellipse']);
axis(ax,'equal');
xline(ax,0,'k:'); yline(ax,0,'k:');

%% D3 — Fy vs α bei iso-κ (Lateral-Abfall durch kombinierten Schlupf)
kap_targets = [0, 0.05, 0.10, 0.15];
col_d = lines(numel(kap_targets));
f = mkfig(tire,'D3','Fy vs α — iso-κ (kombiniert)');
ax = axes(f); hold(ax,'on');
lgd = strings(1, numel(kap_targets));
for k = 1:numel(kap_targets)
    mK = abs(tire.kappa - kap_targets(k)) < 0.025 & ...
         abs(tire.alpha) > CFG.thresh.alpha_deg*pi/180;
    if sum(mK) < 10, continue; end
    [as, si] = sort(tire.alpha(mK));
    Fys = sgSmooth(tire.Fy(mK), CFG); Fys = Fys(si);
    plot(ax, rad2deg(as), Fys, '-', 'Color',col_d(k,:), 'LineWidth',1.5);
    lgd(k) = sprintf('κ ≈ %.2f', kap_targets(k));
end
legend(ax, lgd(lgd ~= ""), 'Location','southeast');
xlabel(ax,'α [°]'); ylabel(ax,'Fy [N]');
title(ax, [tire.name ' — Lateralkraft-Abfall durch kombinierten Schlupf']);
xline(ax,0,'k--','Alpha',0.4); grid(ax,'on');

%% D4 — Vektorieller Gesamtgrip √(μx²+μy²)
f = mkfig(tire,'D4','Vektorieller Gesamtgrip √(μx²+μy²)');
ax = axes(f);
mu_vec = sqrt(tire.mux.^2 + tire.muy.^2);
scatter_colored(ax, tire.Fx, tire.Fy, mu_vec, '|μ| [–]');
xlabel(ax,'Fx [N]'); ylabel(ax,'Fy [N]');
title(ax, [tire.name ' — Vektorieller Gesamtgrip']);
axis(ax,'equal');

end % pg_D


%% ═══════════════════════════════════════════════════════════════════════════
%%                        GRUPPE E — STURZ & DRUCK
%% ═══════════════════════════════════════════════════════════════════════════
function pg_E(tire, CFG)

% Camber-Sweep-Bereich: α≈0, κ≈0, IA variiert
mCS = abs(tire.alpha) < 2*pi/180 & abs(tire.kappa) < CFG.thresh.kappa;
mL  = latMask(tire, CFG);
fzLvl = tire.fzLevels;
pLvl  = tire.pLevels;
col_fz = parula(max(numel(fzLvl),2));

%% E1 — Fy vs IA (Camber Thrust Sweep)
f = mkfig(tire,'E1','Fy vs IA — Camber Thrust');
ax = axes(f); hold(ax,'on');
lgd = strings(1,numel(fzLvl));
for k = 1:numel(fzLvl)
    mF = mCS & binMask(tire.Fz, fzLvl(k), CFG.bin.fz_tol);
    if sum(mF) < 5, continue; end
    [ias, si] = sort(rad2deg(tire.gamma(mF)));
    Fys = sgSmooth(tire.Fy(mF), CFG); Fys = Fys(si);
    plot(ax, ias, Fys, '-', 'Color',col_fz(k,:), 'LineWidth',1.5);
    lgd(k) = sprintf('Fz ≈ %.0f N', fzLvl(k));
end
legend(ax, lgd(lgd ~= ""), 'Location','northwest');
xlabel(ax,'IA [°]'); ylabel(ax,'Fy [N]');
title(ax, [tire.name ' — Camber Thrust: Fy vs Sturzwinkel (α=0°, κ=0)']);
xline(ax,0,'k--','Alpha',0.4); grid(ax,'on');

%% E2 — Camber Stiffness vs Fz
f = mkfig(tire,'E2','Camber Stiffness vs Fz');
ax = axes(f); hold(ax,'on');
Cg = nan(1,numel(fzLvl));
for k = 1:numel(fzLvl)
    mF = mCS & binMask(tire.Fz, fzLvl(k), CFG.bin.fz_tol);
    mN = mF & abs(tire.gamma) < 1.5*pi/180;
    if sum(mN) < 3, continue; end
    p    = polyfit(rad2deg(tire.gamma(mN)), tire.Fy(mN), 1);
    Cg(k) = p(1);
end
plot(ax, fzLvl, Cg, 'o-', 'LineWidth',1.5, 'Color',[0.47 0.67 0.19], ...
     'MarkerFaceColor','w', 'MarkerSize',8);
xlabel(ax,'Fz [N]'); ylabel(ax,'Camber Stiffness [N/°]');
title(ax, [tire.name ' — Camber Stiffness vs Normalkraft']);
grid(ax,'on');

%% E3 — Cornering Stiffness vs Druck
f = mkfig(tire,'E3','Cornering Stiffness vs Druck');
ax = axes(f); hold(ax,'on');
Cs_p = nan(1,numel(pLvl));
for k = 1:numel(pLvl)
    mP = mL & binMask(tire.P, pLvl(k), CFG.bin.p_tol);
    Cs_p(k) = corneringStiffness(tire.alpha(mP), tire.Fy(mP));
end
plot(ax, pLvl, Cs_p/1000, 's-', 'LineWidth',1.5, 'Color',[0.49 0.18 0.56], ...
     'MarkerFaceColor','w', 'MarkerSize',8);
xlabel(ax,'Druck [kPa]'); ylabel(ax,'CS [kN/rad]');
title(ax, [tire.name ' — Druckempfindlichkeit der Cornering Stiffness']);
grid(ax,'on');

%% E4 — Peak Fy vs Druck
f = mkfig(tire,'E4','Peak Fy vs Druck — optimaler Betriebsdruck');
ax = axes(f); hold(ax,'on');
peakFy = nan(1,numel(pLvl));
for k = 1:numel(pLvl)
    mP = mL & binMask(tire.P, pLvl(k), CFG.bin.p_tol);
    if sum(mP) < 5, continue; end
    peakFy(k) = max(tire.Fy(mP));
end
plot(ax, pLvl, peakFy, 'd-', 'LineWidth',1.5, 'Color',[0 0.45 0.74], ...
     'MarkerFaceColor','w', 'MarkerSize',8);
xlabel(ax,'Druck [kPa]'); ylabel(ax,'Peak Fy [N]');
title(ax, [tire.name ' — Peak Fy vs Druck (optimaler Betriebsdruck)']);
grid(ax,'on');

end % pg_E


%% ═══════════════════════════════════════════════════════════════════════════
%%                        GRUPPE F — TEMPERATUR
%% ═══════════════════════════════════════════════════════════════════════════
function pg_F(tire, CFG)

mL   = latMask(tire, CFG);
adeg = rad2deg(tire.alpha);
et   = tire.ET;
cols_s = {'#0072BD','#D95319','#77AC30'};
sens   = {'TSTC','TSTI','TSTO'};
snames = {'Center','Inboard','Outboard'};

%% F1 — Fy vs α, coloriert nach Oberflächentemperatur (TSTC)
f = mkfig(tire,'F1','Fy vs α — coloriert nach Oberflächentemp.');
ax = axes(f);
mT = mL & ~isnan(tire.TSTC);
scatter_colored(ax, adeg(mT), tire.Fy(mT), tire.TSTC(mT), 'T_{surf} [°C]', 'hot');
xlabel(ax,'α [°]'); ylabel(ax,'Fy [N]');
title(ax, [tire.name ' — Temperatureinfluss auf Seitenkraft']);
xline(ax,0,'k--','Alpha',0.4);

%% F2 — Peak μy vs Oberflächentemperatur (alle 3 Sensoren)
f = mkfig(tire,'F2','Peak μy vs Oberflächentemperatur');
ax = axes(f); hold(ax,'on');
bins_t = 20:5:120;
for s = 1:3
    tdata  = tire.(sens{s})(mL);
    mudata = tire.muy(mL);
    muy_bin = nan(1,numel(bins_t)-1);
    t_bin   = nan(1,numel(bins_t)-1);
    for b = 1:numel(bins_t)-1
        mb = tdata >= bins_t(b) & tdata < bins_t(b+1);
        if sum(mb) < 5, continue; end
        muy_bin(b) = max(mudata(mb));
        t_bin(b)   = mean(tdata(mb));
    end
    plot(ax, t_bin, muy_bin, 'o-', 'LineWidth',1.2, 'Color',cols_s{s}, ...
         'MarkerFaceColor',cols_s{s}, 'MarkerSize',5, 'DisplayName',snames{s});
end
legend(ax,'Location','best'); grid(ax,'on');
xlabel(ax,'Oberflächentemperatur [°C]'); ylabel(ax,'Peak μy [–]');
title(ax, [tire.name ' — Temperaturabhängigkeit des Grips (Peak μy)']);

%% F3 — Temperaturprofil TSTI / TSTC / TSTO vs Zeit
f = mkfig(tire,'F3','Temperaturprofil über Reifenbreite vs Zeit');
ax = axes(f); hold(ax,'on');
plot(ax, et, tire.TSTI, 'Color',cols_s{2}, 'LineWidth',0.8, 'DisplayName','Inboard');
plot(ax, et, tire.TSTC, 'Color',cols_s{1}, 'LineWidth',1.2, 'DisplayName','Center');
plot(ax, et, tire.TSTO, 'Color',cols_s{3}, 'LineWidth',0.8, 'DisplayName','Outboard');
legend(ax,'Location','best'); grid(ax,'on');
xlabel(ax,'ET [s]'); ylabel(ax,'T [°C]');
title(ax, [tire.name ' — Oberflächentemperaturprofil (Breite) über Testzeit']);

%% F4 — Cold-to-hot Sweeps: erste 12 Sweeps überlagert
f = mkfig(tire,'F4','Cold-to-hot Sweeps — Fy(α) Sweep 1–12');
ax = axes(f); hold(ax,'on');
mL_idx = find(mL);
if numel(mL_idx) > 20
    dalpha     = diff(tire.alpha(mL_idx));
    sw_bounds  = [1; find(dalpha(1:end-1).*dalpha(2:end) < 0)+1; numel(mL_idx)];
    n_sweeps   = min(12, floor(numel(sw_bounds)/2));
    col_cth    = cool(max(n_sweeps,2));
    for sw = 1:n_sweeps
        i1   = mL_idx(sw_bounds(2*sw-1));
        i2   = mL_idx(min(sw_bounds(2*sw), numel(mL_idx)));
        idxs = i1:i2;
        if numel(idxs) < 5, continue; end
        [as, si] = sort(tire.alpha(idxs));
        Fys = tire.Fy(idxs); Fys = Fys(si);
        plot(ax, rad2deg(as), Fys, '-', 'Color',col_cth(sw,:), 'LineWidth',1.0, ...
             'DisplayName', sprintf('Sweep %d', sw));
    end
    legend(ax,'Location','southeast','FontSize',7,'NumColumns',3);
end
xlabel(ax,'α [°]'); ylabel(ax,'Fy [N]');
title(ax, [tire.name ' — Cold-to-hot: Einarbeiten & Aufheizen']);
xline(ax,0,'k--','Alpha',0.4); grid(ax,'on');

end % pg_F


%% ═══════════════════════════════════════════════════════════════════════════
%%                        GRUPPE G — GESCHWINDIGKEIT
%% ═══════════════════════════════════════════════════════════════════════════
function pg_G(tire, CFG)

mL    = latMask(tire, CFG);
mX    = longMask(tire, CFG);
vLvl  = tire.vLevels;
col_v = lines(max(numel(vLvl),2));

%% G1 — Fy vs α bei verschiedenen Geschwindigkeiten
if any(mL) && numel(vLvl) >= 1
    f = mkfig(tire,'G1','Fy vs α — Geschwindigkeitsvergleich');
    ax = axes(f); hold(ax,'on');
    lgd = strings(1,numel(vLvl));
    for k = 1:numel(vLvl)
        mV = mL & binMask(tire.V, vLvl(k), CFG.bin.v_tol);
        if sum(mV) < 10, continue; end
        [as, si] = sort(tire.alpha(mV));
        Fys = sgSmooth(tire.Fy(mV), CFG); Fys = Fys(si);
        plot(ax, rad2deg(as), Fys, '-', 'Color',col_v(k,:), 'LineWidth',1.5);
        lgd(k) = sprintf('V ≈ %.0f km/h', vLvl(k)*3.6);
    end
    legend(ax, lgd(lgd ~= ""), 'Location','southeast');
    xlabel(ax,'α [°]'); ylabel(ax,'Fy [N]');
    title(ax, [tire.name ' — Geschwindigkeitseinfluss auf Lateral (TTC 15/25/45 mph)']);
    xline(ax,0,'k--','Alpha',0.4); grid(ax,'on');
end

%% G2 — Fx vs κ bei verschiedenen Geschwindigkeiten
if any(mX) && numel(vLvl) >= 1
    f = mkfig(tire,'G2','Fx vs κ — Geschwindigkeitsvergleich');
    ax = axes(f); hold(ax,'on');
    lgd = strings(1,numel(vLvl));
    for k = 1:numel(vLvl)
        mV = mX & binMask(tire.V, vLvl(k), CFG.bin.v_tol);
        if sum(mV) < 10, continue; end
        [ks, si] = sort(tire.kappa(mV));
        Fxs = sgSmooth(tire.Fx(mV), CFG); Fxs = Fxs(si);
        plot(ax, ks, Fxs, '-', 'Color',col_v(k,:), 'LineWidth',1.5);
        lgd(k) = sprintf('V ≈ %.0f km/h', vLvl(k)*3.6);
    end
    legend(ax, lgd(lgd ~= ""), 'Location','southeast');
    xlabel(ax,'κ [–]'); ylabel(ax,'Fx [N]');
    title(ax, [tire.name ' — Geschwindigkeitseinfluss auf Longitudinal']);
    xline(ax,0,'k--','Alpha',0.4); grid(ax,'on');
end

%% G3 — Cornering Stiffness vs Geschwindigkeit
if any(mL) && numel(vLvl) > 1
    f = mkfig(tire,'G3','Cornering Stiffness vs Geschwindigkeit');
    ax = axes(f); hold(ax,'on');
    Cs_v = nan(1,numel(vLvl));
    for k = 1:numel(vLvl)
        mV    = mL & binMask(tire.V, vLvl(k), CFG.bin.v_tol);
        Cs_v(k) = corneringStiffness(tire.alpha(mV), tire.Fy(mV));
    end
    plot(ax, vLvl*3.6, Cs_v/1000, 'o-', 'LineWidth',1.5, ...
         'Color',[0.30 0.75 0.93], 'MarkerFaceColor','w', 'MarkerSize',8);
    xlabel(ax,'V [km/h]'); ylabel(ax,'CS [kN/rad]');
    title(ax, [tire.name ' — Cornering Stiffness vs Geschwindigkeit']);
    grid(ax,'on');
end

%% G4 — Effektiver & belasteter Radius vs Fz
if ~all(isnan(tire.RE)) && ~all(isnan(tire.RL))
    f = mkfig(tire,'G4','Reifenradien RE & RL vs Fz');
    tl = tiledlayout(f,1,2,'TileSpacing','compact');
    ax1 = nexttile; ax2 = nexttile;
    scatter_colored(ax1, tire.Fz, tire.RE*100, tire.V*3.6, 'V [km/h]');
    xlabel(ax1,'Fz [N]'); ylabel(ax1,'RE [cm]');
    title(ax1,'Effektiver Radius RE vs Fz');
    scatter_colored(ax2, tire.Fz, tire.RL*100, tire.V*3.6, 'V [km/h]');
    xlabel(ax2,'Fz [N]'); ylabel(ax2,'RL [cm]');
    title(ax2,'Belasteter Radius RL vs Fz');
    title(tl, [tire.name ' — Reifenradien']);
end

end % pg_G


%% ═══════════════════════════════════════════════════════════════════════════
%%                        GRUPPE H — VERSCHLEISS & TRANSIENT
%% ═══════════════════════════════════════════════════════════════════════════
function pg_H(tire, CFG)

mL   = latMask(tire, CFG);
adeg = rad2deg(tire.alpha);

%% H1 — Neu vs. Verschlissen (erster vs. letzter 12-psi-Block)
if ~isempty(tire.pLevels)
    p_nom  = tire.pLevels(end);
    mP     = mL & binMask(tire.P, p_nom, CFG.bin.p_tol);
    runs_p = unique(tire.runID(mP));

    if numel(runs_p) >= 2
        r_first  = runs_p(1);
        r_last   = runs_p(end);
        m_first  = mP & tire.runID == r_first;
        m_last   = mP & tire.runID == r_last;

        f = mkfig(tire,'H1','Neu vs. Verschlissen (12-psi-Block Fy)');
        ax = axes(f); hold(ax,'on');
        if sum(m_first) > 10
            [as,si] = sort(tire.alpha(m_first));
            Fys = sgSmooth(tire.Fy(m_first), CFG); Fys = Fys(si);
            plot(ax, rad2deg(as), Fys, 'b-', 'LineWidth',1.8, ...
                 'DisplayName', sprintf('Erster Block (Run %d)', r_first));
        end
        if sum(m_last) > 10
            [as,si] = sort(tire.alpha(m_last));
            Fys = sgSmooth(tire.Fy(m_last), CFG); Fys = Fys(si);
            plot(ax, rad2deg(as), Fys, 'r--', 'LineWidth',1.8, ...
                 'DisplayName', sprintf('Letzter Block (Run %d)', r_last));
        end
        legend(ax,'Location','southeast'); grid(ax,'on');
        xlabel(ax,'α [°]'); ylabel(ax,'Fy [N]');
        title(ax, sprintf('%s — Fy(α): Neu vs. Verschlissen @ P ≈ %.0f kPa', ...
              tire.name, p_nom));
        xline(ax,0,'k--','Alpha',0.4);
    end
end

%% H2 — Relaxationslänge (Transienter Bereich)
mTrans = abs(tire.V) > 0.05 & abs(tire.V) < 2.5;
if sum(mTrans) > 50
    f = mkfig(tire,'H2','Relaxationsverhalten — Fy nach Step-Steer');
    f.Position(3:4) = [900 800];
    tl = tiledlayout(f, 3, 1, 'TileSpacing','compact','Padding','compact');
    idx_t = find(mTrans);
    ax1 = nexttile;
    plot(ax1, tire.ET(idx_t), tire.Fy(idx_t), 'b-', 'LineWidth',1.0);
    ylabel(ax1,'Fy [N]'); title(ax1,'Seitenkraft (Fy)'); grid(ax1,'on');
    ax2 = nexttile;
    plot(ax2, tire.ET(idx_t), adeg(idx_t), 'r-', 'LineWidth',1.0);
    ylabel(ax2,'α [°]'); title(ax2,'Schräglaufwinkel (α)'); grid(ax2,'on');
    ax3 = nexttile;
    plot(ax3, tire.ET(idx_t), tire.V(idx_t)*3.6, 'Color',[0.47 0.67 0.19], 'LineWidth',1.0);
    ylabel(ax3,'V [km/h]'); xlabel(ax3,'ET [s]');
    title(ax3,'Geschwindigkeit (V)'); grid(ax3,'on');
    linkaxes([ax1,ax2,ax3],'x');
    title(tl, [tire.name ' — Transienter Bereich: Relaxationsverhalten']);
end

%% H3 — Reifenfederkennlinie (Spring Rate): Fz vs RL
mSR = abs(tire.alpha) < 1*pi/180 & abs(tire.kappa) < 0.01 & ...
      ~isnan(tire.RL) & isfinite(tire.RL) & tire.RL > 0;

if sum(mSR) > 50
    f = mkfig(tire,'H3','Reifenfederkennlinie (Spring Rate)');
    ax = axes(f); hold(ax,'on');
    pLvl  = tire.pLevels;
    col_p = summer(max(numel(pLvl),2));
    lgd   = strings(1,numel(pLvl));
    for k = 1:numel(pLvl)
        mP = mSR & binMask(tire.P, pLvl(k), CFG.bin.p_tol);
        if sum(mP) < 5, continue; end
        [rls,si] = sort(tire.RL(mP));
        Fzs = tire.Fz(mP); Fzs = Fzs(si);
        plot(ax, rls*100, Fzs, '.', 'Color',col_p(k,:), 'MarkerSize',4);
        lgd(k) = sprintf('P ≈ %.0f kPa', pLvl(k));
    end
    legend(ax, lgd(lgd ~= ""), 'Location','northwest');
    xlabel(ax,'RL [cm]'); ylabel(ax,'Fz [N]');
    title(ax, [tire.name ' — Federkennlinie: Fz vs belasteter Radius RL']);
    grid(ax,'on'); axis(ax,'tight');
end

end % pg_H


%% ═══════════════════════════════════════════════════════════════════════════
%%                        GRUPPE I — DATENQUALITÄT
%% ═══════════════════════════════════════════════════════════════════════════
function pg_I(tire, CFG)

et   = tire.ET;
adeg = rad2deg(tire.alpha);

%% I1 — Alle Kanäle vs Zeit (Zeitkanal-Übersicht)
f = mkfig(tire,'I1','Alle Kanäle vs Zeit');
f.Position(3:4) = [1000 1100];
tl = tiledlayout(f, 11, 1, 'TileSpacing','compact', 'Padding','compact');
chans = {
    adeg,                    'α [°]',    'Schräglaufwinkel';
    tire.kappa,              'κ [–]',    'Längsschlupf';
    rad2deg(tire.gamma),     'IA [°]',   'Sturzwinkel';
    tire.V*3.6,              'V [km/h]', 'Geschwindigkeit';
    tire.P,                  'P [kPa]',  'Reifendruck';
    tire.Fz,                 'Fz [N]',   'Normalkraft';
    tire.Fy,                 'Fy [N]',   'Seitenkraft';
    tire.Fx,                 'Fx [N]',   'Längskraft';
    tire.Mz,                 'Mz [Nm]',  'Ausrichtendes Moment';
    tire.Mx,                 'Mx [Nm]',  'Überrollmoment';
    tire.TSTC,               'T [°C]',   'Oberflächentemp. (Center)'
};
for k = 1:size(chans,1)
    axk = nexttile;
    plot(axk, et, chans{k,1}, 'LineWidth', 0.7);
    ylabel(axk, chans{k,2}, 'FontSize',8);
    title(axk, chans{k,3}, 'FontSize',8);
    grid(axk,'on'); set(axk,'XTickLabel',[]);
end
xlabel(tl, 'ET [s]');
title(tl, [tire.name ' — Zeitkanal-Übersicht (alle Kanäle)'], 'FontSize',11);

%% I2 — Test-Status Klassifizierung
f = mkfig(tire,'I2','Test-Status Klassifizierung');
f.Position(3:4) = [1000 800];
tl = tiledlayout(f, 5, 1, 'TileSpacing','compact', 'Padding','compact');
thr_a = CFG.thresh.alpha_deg * pi/180;
thr_k = CFG.thresh.kappa;
raw_status = zeros(numel(tire.alpha),1);
raw_status(abs(tire.alpha) >  thr_a)                              = 1;
raw_status(abs(tire.kappa) >  thr_k)                              = 2;
raw_status(abs(tire.alpha) >  thr_a & abs(tire.kappa) > thr_k)   = 3;
smooth_status = medfilt1(raw_status, 51);

ax1 = nexttile; plot(ax1,et,adeg);            ylabel(ax1,'α [°]');
yline(ax1, [CFG.thresh.alpha_deg, -CFG.thresh.alpha_deg],'r--','Alpha',0.5);
grid(ax1,'on');
ax2 = nexttile; plot(ax2,et,tire.kappa);      ylabel(ax2,'κ [–]');
yline(ax2,[thr_k,-thr_k],'m--','Alpha',0.5); grid(ax2,'on');
ax3 = nexttile; plot(ax3,et,tire.V*3.6,'Color','#D95319'); ylabel(ax3,'V [km/h]'); grid(ax3,'on');
ax4 = nexttile; plot(ax4,et,tire.P,'Color','#77AC30');     ylabel(ax4,'P [kPa]');  grid(ax4,'on');
ax5 = nexttile; hold(ax5,'on');
plot(ax5,et,raw_status,'.','Color',[0.8 0.8 0.8],'MarkerSize',2);
plot(ax5,et,smooth_status,'k-','LineWidth',1.5);
yticks(ax5,0:3); yticklabels(ax5,{'Inaktiv','Lateral','Longit.','Combined'});
ylim(ax5,[-0.5 3.5]); xlabel(ax5,'ET [s]'); grid(ax5,'on');
linkaxes([ax1,ax2,ax3,ax4,ax5],'x');
title(tl, [tire.name ' — Test-Status Klassifizierung'], 'FontSize',11);

%% I3 — α/κ Coverage Map (2D-Histogramm)
f = mkfig(tire,'I3','Coverage Map — α/κ Datendichte');
ax = axes(f);
histogram2(ax, adeg, tire.kappa, 40, 40, ...
           'DisplayStyle','tile', 'ShowEmptyBins','off');
colorbar(ax); colormap(ax, turbo);
xlabel(ax,'α [°]'); ylabel(ax,'κ [–]');
title(ax, [tire.name ' — Datendichte-Map α/κ']);
xline(ax, [CFG.thresh.alpha_deg, -CFG.thresh.alpha_deg], 'w--', 'Alpha',0.6);
yline(ax, [thr_k, -thr_k], 'w--', 'Alpha',0.6);
grid(ax,'on');

end % pg_I


%% ═══════════════════════════════════════════════════════════════════════════
%%                        OVERLAY — REIFEN VERGLEICH
%% ═══════════════════════════════════════════════════════════════════════════
function pg_overlay(tires, CFG)

nT = numel(tires);

%% Fy vs α — Overlay
f = figure('Name','[Overlay] I4a — Fy vs α Reifen-Vergleich', ...
           'NumberTitle','off');
f.Position(3:4) = [900 620];
ax = axes(f); hold(ax,'on');
for t = 1:nT
    tire = tires{t};
    if ~ismember(tire.testType,{'Lateral','Both'}), continue; end
    mL = latMask(tire, CFG);
    [as,si] = sort(tire.alpha(mL));
    Fys = sgSmooth(tire.Fy(mL), CFG); Fys = Fys(si);
    plot(ax, rad2deg(as), Fys, '-', 'Color',CFG.clr(t,:), 'LineWidth',2, ...
         'DisplayName', tire.name);
end
legend(ax,'Location','southeast'); grid(ax,'on');
xlabel(ax,'α [°]'); ylabel(ax,'Fy [N]');
title(ax,'Reifen-Vergleich — Fy vs α (alle Laststufen überlagert)');
xline(ax,0,'k--','Alpha',0.4);

%% μy vs α — Overlay (normiert)
f = figure('Name','[Overlay] I4b — μy vs α Reifen-Vergleich', ...
           'NumberTitle','off');
f.Position(3:4) = [900 620];
ax = axes(f); hold(ax,'on');
for t = 1:nT
    tire = tires{t};
    if ~ismember(tire.testType,{'Lateral','Both'}), continue; end
    mL = latMask(tire, CFG);
    [as,si] = sort(tire.alpha(mL));
    mys = sgSmooth(tire.muy(mL), CFG); mys = mys(si);
    plot(ax, rad2deg(as), mys, '-', 'Color',CFG.clr(t,:), 'LineWidth',2, ...
         'DisplayName', tire.name);
end
legend(ax,'Location','southeast'); grid(ax,'on');
xlabel(ax,'α [°]'); ylabel(ax,'μy [–]');
title(ax,'Reifen-Vergleich — μy vs α (normiert, alle Lasten)');
xline(ax,0,'k--','Alpha',0.4);
yline(ax,[-1 1],'k:','Alpha',0.5);

%% Cornering Stiffness vs Fz — Overlay
f = figure('Name','[Overlay] I5a — Cornering Stiffness Vergleich', ...
           'NumberTitle','off');
f.Position(3:4) = [900 620];
ax = axes(f); hold(ax,'on');
for t = 1:nT
    tire = tires{t};
    if ~ismember(tire.testType,{'Lateral','Both'}), continue; end
    mL    = latMask(tire, CFG);
    fzLvl = tire.fzLevels;
    Cs_v  = nan(1,numel(fzLvl));
    for k = 1:numel(fzLvl)
        mF    = mL & binMask(tire.Fz, fzLvl(k), CFG.bin.fz_tol);
        Cs_v(k) = corneringStiffness(tire.alpha(mF), tire.Fy(mF));
    end
    plot(ax, fzLvl, Cs_v/1000, 'o-', 'Color',CFG.clr(t,:), 'LineWidth',1.8, ...
         'MarkerFaceColor',CFG.clr(t,:), 'MarkerSize',7, 'DisplayName',tire.name);
end
legend(ax,'Location','northwest'); grid(ax,'on');
xlabel(ax,'Fz [N]'); ylabel(ax,'CS [kN/rad]');
title(ax,'Reifen-Vergleich — Cornering Stiffness vs Fz');

%% Peak μy vs Fz — Overlay (Lastsensitivität)
f = figure('Name','[Overlay] I5b — Peak μy vs Fz Vergleich', ...
           'NumberTitle','off');
f.Position(3:4) = [900 620];
ax = axes(f); hold(ax,'on');
for t = 1:nT
    tire  = tires{t};
    if ~ismember(tire.testType,{'Lateral','Both'}), continue; end
    mL    = latMask(tire, CFG);
    fzLvl = tire.fzLevels;
    pk    = nan(1,numel(fzLvl));
    for k = 1:numel(fzLvl)
        mF = mL & binMask(tire.Fz, fzLvl(k), CFG.bin.fz_tol);
        if sum(mF) < 5, continue; end
        pk(k) = max(tire.muy(mF));
    end
    plot(ax, fzLvl, pk, 'd-', 'Color',CFG.clr(t,:), 'LineWidth',1.8, ...
         'MarkerFaceColor',CFG.clr(t,:), 'MarkerSize',7, 'DisplayName',tire.name);
end
legend(ax,'Location','best'); grid(ax,'on');
xlabel(ax,'Fz [N]'); ylabel(ax,'Peak μy [–]');
title(ax,'Reifen-Vergleich — Lastsensitivität (Peak μy vs Fz)');

%% Reibungsellipse — Overlay (Both-Reifen)
any_both = any(cellfun(@(r) strcmp(r.testType,'Both'), tires));
if any_both
    f = figure('Name','[Overlay] I4c — Reibungsellipse Vergleich', ...
               'NumberTitle','off');
    f.Position(3:4) = [800 800];
    ax = axes(f); hold(ax,'on');
    for t = 1:nT
        tire = tires{t};
        if ~strcmp(tire.testType,'Both'), continue; end
        scatter(ax, tire.mux, tire.muy, 3, CFG.clr(t,:), 'filled', ...
                'MarkerFaceAlpha',0.25);
        plot(ax, NaN, NaN, 'o', 'Color',CFG.clr(t,:), ...
             'MarkerFaceColor',CFG.clr(t,:), 'MarkerSize',7, 'DisplayName',tire.name);
    end
    th = linspace(0,2*pi,200);
    plot(ax, cos(th), sin(th), 'k--', 'LineWidth',0.8, 'DisplayName','Einheitskreis');
    legend(ax,'Location','best'); grid(ax,'on'); axis(ax,'equal');
    xlabel(ax,'μx [–]'); ylabel(ax,'μy [–]');
    title(ax,'Reifen-Vergleich — Normierte Reibungsellipse');
    xline(ax,0,'k:'); yline(ax,0,'k:');
end

end % pg_overlay
