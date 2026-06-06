%% Pre Skirpt
clear;
close all;
clc

%% Load Tire data
addpath("0_Tire_test_data\")

tirepath = pwd;
tydexdir = dir(fullfile(tirepath,"0_Tire_test_data\0_Reifen_43075","*.mat"));
tydexstr = join([{tydexdir.folder}',{tydexdir.name}'],filesep);

for i = 1:1:numel(tydexstr)
    tire_data_raw(i) = load(string(tydexstr(i)));
end

clearvars -except tire_data_raw

%% tireData Object processing
% Create Tire object
[td_1] = create_Tire_object;

% Populate (Auskommentiert für Geschwindigkeit)
[td_1] = populate_tire_object(td_1, tire_data_raw(3),'TTC_Lateral');

%% Preprocess Tire Data
td_1 = split(td_1, "et");
td_1 = mean(td_1, "Fz");          % bleibt für Fz-Konditionierung
% td_1 = downsample(td_1, 2);

%% Filter-Vergleich: Auf einem repräsentativen Segment entscheiden
% Segment-Index nach Wahl — am besten eines mit sauberem Full-Sweep
SEG_IDX = 5;
compareFilters(td_1(SEG_IDX));    % öffnet Figure mit allen 5 Filteroptionen

%% Sobald du dich entschieden hast, hier deinen gewählten Filter einsetzen:
% Beispiel: Savitzky-Golay, Polygrad 3, Fenster 21
CHOSEN_FILTER = "sgolay";
SG_ORDER  = 3;
SG_FRAME  = 21;   % muss ungerade sein

for i = 1:numel(td_1)
    td_1(i).Fy = sgolayfilt(td_1(i).Fy, SG_ORDER, SG_FRAME);
    td_1(i).Fx = sgolayfilt(td_1(i).Fx, SG_ORDER, SG_FRAME);
    td_1(i).Mz = sgolayfilt(td_1(i).Mz, SG_ORDER, SG_FRAME);
end

%% Visualisierung nach Filter-Wahl
plotTireStatus(td_1(SEG_IDX), deg2rad(0.5), 0.02, 51);
plotTireCharacteristics(td_1);


%% Functions
function [tdnew] = create_Tire_object
tdnew = tireData();                         % Anlegen des Objects
tdnew = tdnew.coordinateTransform("SAE");   % Definition des Koordinaten systems, später überschrieben
end

function [tdnew] = populate_tire_object(tdnew, fsData,TestMethod)
%% Eingangsvariabeln
% TestMethod = Welche Testdaten werden angeschaut, "Lateral" für Drive
% Brake und Longitudinal für Cornering

%% Ausgangsvariabeln
% tdnew ist jetzt ein befülltes tiredata object

%% Function Code

% Preperation
[row, ~] = size(fsData.MX);

% --- Messdaten und Achsen (Umrechnung in SI-Einheiten) ---
tdnew.et                = fsData.ET;                        % Zeit [s]
tdnew.seget             = fsData.ET;                        % Segmentzeit [s]
tdnew.segment           = ones(row, 1);                     % Segment-ID (Platzhalter: 1)
tdnew.measnumb          = linspace(1, row, row);            % Messpunktnummer
tdnew.Fx                = fsData.FX;                        % Längskraft [N]
tdnew.Fy                = fsData.FY;                        % Seitenkraft [N]
tdnew.Fz                = fsData.FZ;                        % Normalkraft [N]
tdnew.Mx                = fsData.MX;                        % Überrollmoment (Mx) [Nm]
tdnew.My                = zeros(row, 1);                    % Kippmoment (My) [Nm] (Zero-Placeholder)
tdnew.Mz                = fsData.MZ;                        % Ausrichtendes Moment (Mz) [Nm]
tdnew.IP                = fsData.P * 1000;                  % Inflationsdruck [Pa] (von kPa)
tdnew.alpha             = (pi/180) * fsData.SA;             % Schräglaufwinkel [rad] (von deg)
tdnew.gamma             = (pi/180) * fsData.IA;             % Sturzwinkel [rad] (von deg)
tdnew.kappa             = fsData.SL;                        % Längsschlupf [-]
tdnew.phit              = zeros(row, 1);                    % Wegrollwinkel [rad] (Zero-Placeholder)
tdnew.V                 = (1000 / 3600) * (fsData.V);       % Geschwindigkeit [m/s] (von km/h)
tdnew.omega             = (1 / 60) * (fsData.N);            % Radwinkelgeschw. [U/s] (von U/min)

% --- Statische Metadaten (Reifendimensionen und Testbedingungen) ---
tdnew.TestMethod        = TestMethod;                       % Testtyp (Wichtig für Fx/Fy-Trennung)
tdnew.TireSize          = "152.4/67R10";                    % Reifengröße, (Technisch nicht relevant, platzhalter stehen gelassen)
tdnew.SectionWidth      = 152.4000;                         % Schnittbreite [mm]
tdnew.AspectRatio       = 67;                               % Querschnittsverhältnis [%]
tdnew.RimDiameter       = 10;                               % Felgendurchmesser [inch]
tdnew.OverallDiameter   = 0.472;                            % Gesamtdurchmesser [m]
tdnew.LoadIndex         = 90;                               % Lastindex
tdnew.SpeedSymbol       = "V";                              % Geschwindigkeitssymbol
tdnew.TestFacility      = "FS Tire Data";                   % Testeinrichtung (Metadaten)
tdnew.TestMachine       = "MTS Flat-Trac LTRe";             % Testmaschine (Metadaten)
tdnew.RimWidth          = 7;                                % Felgenbreite [inch]
tdnew.Surface           = "120 3Mite";                      % Oberflächentyp
tdnew.SurfaceCondition  = "Dry";                            % Oberflächenzustand
tdnew.TestDate          = "24-Apr-2020 14:55:29";           % Testdatum/Zeit
tdnew                   = tdnew.coordinateTransform("ISO"); % Konvertierung zu ISO-Standardachse

end

function plotTireStatusWithSplits(tireObj, threshold_SA, threshold_SL, filter_window, parentHandle)
% PLOTTIRESTATUSWITHSPLITS Plottet ein Array von Tire-Objekten hintereinander.
%
% EINGABE:
%   tireObj:       Array von Objekten (z.B. 62x1) oder Einzelobjekt
%   threshold_SA:  Grenzwert Alpha
%   threshold_SL:  Grenzwert Kappa
%   filter_window: Fenstergröße Glättung

%% 1. Standardwerte
if nargin < 5, parentHandle = []; end
if nargin < 4, filter_window = 51; end
if nargin < 3, threshold_SL = 0.005; end
if nargin < 2, threshold_SA = 0.2; end
if mod(filter_window, 2) == 0, filter_window = filter_window + 1; end

%% 2. DATEN SAMMELN (Concatenation Loop)
% Wir gehen durch alle Elemente im Array und sammeln die Daten in Cells

nFiles = numel(tireObj); % Anzahl der Objekte (z.B. 62)

% Cell-Arrays zum Zwischenspeichern
c_alpha = cell(nFiles, 1);
c_kappa = cell(nFiles, 1);
c_v     = cell(nFiles, 1);
c_et    = cell(nFiles, 1);

% --- Loop über alle 62 Dateien ---
for i = 1:nFiles
    currentObj = tireObj(i);

    % Daten holen (mit lokaler Hilfsfunktion s.u.)
    a = tryGetProp(currentObj, {'alpha', 'Alpha', 'SA', 'sa', 'ALPHAR'});
    k = tryGetProp(currentObj, {'kappa', 'Kappa', 'SR', 'sr', 'SL', 'sl'});
    v = tryGetProp(currentObj, {'V', 'v', 'Vx', 'vx', 'speed'});
    t = tryGetProp(currentObj, {'et', 'ET', 'time', 'Time', 't'});

    % Fallbacks für leere/fehlende Daten im aktuellen Objekt
    len = max([length(a), length(k)]);
    if isempty(a), a = zeros(len,1); end
    if isempty(k), k = zeros(len,1); end
    if isempty(v), v = zeros(len,1); end
    if isempty(t), t = (1:len)'; end % Dummy Zeit falls fehlt

    % Auf gleiche Länge bringen (min length)
    nMin = min([length(a), length(k), length(v), length(t)]);
    if nMin > 0
        c_alpha{i} = a(1:nMin);
        c_kappa{i} = k(1:nMin);
        c_v{i}     = v(1:nMin);
        c_et{i}    = t(1:nMin);
    end
end

% --- Alles zusammenfügen (Vertcat) ---
% Aus vielen kleinen Vektoren werden 4 riesige Vektoren
alpha   = vertcat(c_alpha{:});
kappa   = vertcat(c_kappa{:});
v_sig   = vertcat(c_v{:});
et_data = vertcat(c_et{:});

if isempty(alpha)
    error('Das Objekt-Array scheint keine validen Daten zu enthalten.');
end

total_n = length(alpha);
x_axis  = 1:total_n; % Globale Index-Achse

%% 3. Splits finden (Sägezahn + Objekt-Übergänge)
% Ein Split ist dort, wo ET resettet wird (diff < 0)
% Da wir die Objekte hintereinander gehängt haben, passiert das
% automatisch zwischen Objekt 1 und 2.

split_indices = find(diff(et_data) < -0.1) + 1;
test_boundaries = [1; split_indices; total_n];

%% 4. Status Berechnung (Global)
raw_status = zeros(total_n, 1);
TYPE_INAKTIV=0; TYPE_LATERAL=1; TYPE_LONGITUDINAL=2; TYPE_COMBINED=3;

% Vectorized calculation (schneller als For-Loop bei vielen Daten)
is_lat  = abs(alpha) > threshold_SA;
is_long = abs(kappa) > threshold_SL;

raw_status(is_lat)  = TYPE_LATERAL;
raw_status(is_long) = TYPE_LONGITUDINAL;
raw_status(is_lat & is_long) = TYPE_COMBINED;
% Rest bleibt 0 (Inaktiv)

smooth_status = medfilt1(raw_status, filter_window);

%% 5. Plotting
if isempty(parentHandle)
    f = figure('Name', ['Full Analysis (' num2str(nFiles) ' Files)'], 'NumberTitle', 'off');
    f.Position(3:4) = [1200 900];
    target = f;
else
    target = parentHandle;
end

t = tiledlayout(target, 5, 1, 'TileSpacing', 'compact');
ax_list = gobjects(5,1);

% Helper Macro für Plots
ax_list(1) = nexttile; plot(x_axis, alpha); ylabel('Alpha'); grid on; title('Slip Angle');
yline([threshold_SA, -threshold_SA], 'r--');

ax_list(2) = nexttile; plot(x_axis, kappa); ylabel('Kappa'); grid on; title('Slip Ratio');
yline([threshold_SL, -threshold_SL], 'm--');

ax_list(3) = nexttile; plot(x_axis, v_sig, 'Color', '#D95319'); ylabel('V'); grid on; title('Velocity');

ax_list(4) = nexttile; plot(x_axis, et_data, 'Color', '#77AC30'); ylabel('ET [s]'); grid on; title('Time Segments');

ax_list(5) = nexttile; hold on;
plot(x_axis, raw_status, '.', 'Color', [0.8 0.8 0.8]); % Punkt statt Kreis für Performance
plot(x_axis, smooth_status, 'k-', 'LineWidth', 1.5);
ylabel('Status'); xlabel(['Datenpunkte (Total: ' num2str(total_n) ')']);
yticks(0:3); yticklabels({'Inaktiv', 'Lat', 'Long', 'Comb'});
ylim([-0.5 3.5]); grid on;

linkaxes(ax_list, 'x');
xlim([1 total_n]);

%% 6. Visualisierung der Splits
if ~isempty(split_indices)
    % Linien zeichnen
    for ax = ax_list'
        xline(ax, split_indices, ':k', 'Alpha', 0.4); % Leichtere Linien für Performance
    end

    % Labels (Nur jedes 5. Label zeichnen, sonst wird es bei 62 Tests unleserlich)
    label_step = max(1, round(nFiles / 15)); % Automatische Dichte der Labels

    for k = 1:label_step:(length(test_boundaries)-1)
        idx_start = test_boundaries(k);
        idx_end   = test_boundaries(k+1);
        idx_mid   = (idx_start + idx_end) / 2;

        text(ax_list(1), idx_mid, double(max(alpha)), num2str(k), ...
            'HorizontalAlignment', 'center', ...
            'FontSize', 8, 'BackgroundColor', 'w', 'EdgeColor', 'none');
    end
end
end

function val = tryGetProp(obj, candidates)
val = [];
% Robust check for property or field
for k = 1:length(candidates)
    fn = candidates{k};
    if (isobject(obj) && isprop(obj, fn)) || (isstruct(obj) && isfield(obj, fn))
        val = obj.(fn);
        return;
    end
end
end

function plotTireStatus(tireObj, threshold_SA, threshold_SL, filter_window)
% PLOTTIRESTATUS  Vollständige Zeitkanal-Übersicht eines tireData-Segments.
%
% Zeigt: α, κ, γ, V, Fz, Fy, Fx, Mz, Mx sowie den abgeleiteten Test-Status.
% Alle Achsen sind verknüpft (linkaxes).
%
% EINGABE:
%   tireObj       – einzelnes tireData-Objekt
%   threshold_SA  – α-Schwellwert für Status-Klassifizierung [rad]
%   threshold_SL  – κ-Schwellwert [-]
%   filter_window – Medianfilterfenster für Status-Glättung (ungerade int)

%% Defaults
if nargin < 4, filter_window = 51; end
if nargin < 3, threshold_SL  = 0.02; end
if nargin < 2, threshold_SA  = deg2rad(0.5); end
if mod(filter_window, 2) == 0, filter_window = filter_window + 1; end

%% Daten entpacken & angleichen
fields = {'alpha','kappa','gamma','V','Fz','Fy','Fx','Mz','Mx','et'};
d = struct();
for k = 1:numel(fields)
    f = fields{k};
    if isprop(tireObj, f)
        d.(f) = tireObj.(f);
    else
        d.(f) = [];
    end
end

% Gemeinsame Länge
lens = structfun(@numel, d);
n    = min(lens(lens > 0));
for k = 1:numel(fields)
    f = fields{k};
    if numel(d.(f)) >= n
        d.(f) = d.(f)(1:n);
    else
        d.(f) = zeros(n, 1);   % Fallback: Nullvektor
    end
end
t_axis = d.et;

%% Status berechnen
raw_status = zeros(n,1);
is_lat  = abs(d.alpha) > threshold_SA;
is_long = abs(d.kappa) > threshold_SL;
raw_status(is_lat)            = 1;
raw_status(is_long)           = 2;
raw_status(is_lat & is_long)  = 3;
smooth_status = medfilt1(raw_status, filter_window);

%% ---- FIGURE: Zeitkanal-Übersicht ----
fig1 = figure('Name','Tire Status — Zeitkanäle','NumberTitle','off');
fig1.Position(3:4) = [1100 1000];

COL_KINEM = '#0072BD';   % Blau  → kinematische Eingangsgrößen
COL_FORCE = '#D95319';   % Orange→ Kräfte/Momente
COL_COND  = '#77AC30';   % Grün  → Testbedingungen

t = tiledlayout(fig1, 10, 1, 'TileSpacing','compact','Padding','compact');
ax = gobjects(10,1);

% 1 — Schräglaufwinkel
ax(1) = nexttile; hold on;
plot(t_axis, rad2deg(d.alpha), 'Color', COL_KINEM, 'LineWidth',1.2);
yline([ rad2deg(threshold_SA), -rad2deg(threshold_SA)], 'r--', 'Alpha',0.6);
ylabel('α [°]'); title('Schräglaufwinkel'); grid on;

% 2 — Längsschlupf
ax(2) = nexttile; hold on;
plot(t_axis, d.kappa, 'Color', COL_KINEM, 'LineWidth',1.2);
yline([ threshold_SL, -threshold_SL], 'm--', 'Alpha',0.6);
ylabel('κ [–]'); title('Längsschlupf'); grid on;

% 3 — Sturzwinkel
ax(3) = nexttile;
plot(t_axis, rad2deg(d.gamma), 'Color', COL_KINEM, 'LineWidth',1.2);
ylabel('γ [°]'); title('Sturzwinkel (Camber)'); grid on;

% 4 — Geschwindigkeit
ax(4) = nexttile;
plot(t_axis, d.V, 'Color', COL_COND, 'LineWidth',1.2);
ylabel('V [m/s]'); title('Geschwindigkeit'); grid on;

% 5 — Normalkraft
ax(5) = nexttile;
plot(t_axis, d.Fz, 'Color', COL_COND, 'LineWidth',1.2);
ylabel('Fz [N]'); title('Normalkraft'); grid on;

% 6 — Seitenkraft
ax(6) = nexttile;
plot(t_axis, d.Fy, 'Color', COL_FORCE, 'LineWidth',1.2);
ylabel('Fy [N]'); title('Seitenkraft'); grid on;

% 7 — Längskraft
ax(7) = nexttile;
plot(t_axis, d.Fx, 'Color', COL_FORCE, 'LineWidth',1.2);
ylabel('Fx [N]'); title('Längskraft'); grid on;

% 8 — Ausrichtendes Moment
ax(8) = nexttile;
plot(t_axis, d.Mz, 'Color', COL_FORCE, 'LineWidth',1.2);
ylabel('Mz [Nm]'); title('Ausrichtendes Moment'); grid on;

% 9 — Überrollmoment
ax(9) = nexttile;
plot(t_axis, d.Mx, 'Color', COL_FORCE, 'LineWidth',1.2);
ylabel('Mx [Nm]'); title('Überrollmoment'); grid on;

% 10 — Status
ax(10) = nexttile; hold on;
plot(t_axis, raw_status,    '.', 'Color',[0.75 0.75 0.75], 'MarkerSize',3);
plot(t_axis, smooth_status, 'k-','LineWidth',1.8);
yticks(0:3); yticklabels({'Inaktiv','Lateral','Longit.','Combined'});
ylim([-0.5 3.5]); ylabel('Status'); xlabel('Zeit [s]');
title(['Klassifizierung  (α-Thresh: ', num2str(rad2deg(threshold_SA),'%.2f'), ...
       '°  κ-Thresh: ', num2str(threshold_SL), ')']);
grid on;

linkaxes(ax,'x');
end

function plotTireCharacteristics(tireObjArr)
% PLOTTIRECHARCTERISTICS  Scatter-Plots aller Segmente für Reifenfitting.
%
% Zeigt:
%   (1) Fy vs α,  farbkodiert nach Fz
%   (2) μy = Fy/Fz vs α
%   (3) Mz vs α,  farbkodiert nach Fz
%   (4) Mx vs Fz  (Überrollmoment-Kennlinie)
%   (5) Fy vs α,  farbkodiert nach γ (Camber-Einfluss)
%   (6) Mz vs α,  farbkodiert nach γ
%
% Alle Arrays werden zuerst konkatenieret → ein großer Scatter.

%% Daten aller Segmente zusammenführen
alpha_all = [];  kappa_all = [];  Fy_all = [];  Fx_all = [];
Fz_all    = [];  Mz_all    = [];  Mx_all = [];  gamma_all = [];

for i = 1:numel(tireObjArr)
    obj = tireObjArr(i);
    n = min([numel(obj.alpha), numel(obj.Fy), numel(obj.Fz), ...
             numel(obj.Mz),   numel(obj.Mx),  numel(obj.gamma)]);
    if n < 2, continue; end

    alpha_all  = [alpha_all;  obj.alpha(1:n)];
    Fy_all     = [Fy_all;     obj.Fy(1:n)];
    Fx_all     = [Fx_all;     obj.Fx(1:n)];
    Fz_all     = [Fz_all;     obj.Fz(1:n)];
    Mz_all     = [Mz_all;     obj.Mz(1:n)];
    Mx_all     = [Mx_all;     obj.Mx(1:n)];
    gamma_all  = [gamma_all;  obj.gamma(1:n)];
end

alpha_deg = rad2deg(alpha_all);
gamma_deg = rad2deg(gamma_all);
muy       = Fy_all ./ max(abs(Fz_all), 10);   % verhindert /0

%% ---- FIGURE: Charakteristik-Übersicht ----
fig2 = figure('Name','Tire Characteristics','NumberTitle','off');
fig2.Position(3:4) = [1300 900];

tl = tiledlayout(fig2, 2, 3, 'TileSpacing','compact','Padding','compact');
title(tl, 'Reifenkennlinien — alle Segmente überlagert', 'FontSize',13);

MKSIZE = 2;   % kleiner Punkt für schnelles Rendering bei großen Datensätzen

% --- (1) Fy vs α  nach Fz ---
ax1 = nexttile;
sc1 = scatter(alpha_deg, Fy_all, MKSIZE, Fz_all, 'filled');
xlabel('α [°]'); ylabel('Fy [N]');
title('Seitenkraft  F_y vs α');
cb1 = colorbar; cb1.Label.String = 'Fz [N]';
colormap(ax1, turbo); grid on; axis tight;
xline(0,'k--','Alpha',0.4);

% --- (2) μy vs α ---
ax2 = nexttile;
sc2 = scatter(alpha_deg, muy, MKSIZE, Fz_all, 'filled');
xlabel('α [°]'); ylabel('μ_y = F_y / F_z  [–]');
title('Normierte Seitenkraft  μ_y vs α');
cb2 = colorbar; cb2.Label.String = 'Fz [N]';
colormap(ax2, turbo); grid on; axis tight;
yline([ 1, -1], 'r--', 'Alpha',0.5);   % μ = 1 Referenzlinie
xline(0,'k--','Alpha',0.4);

% --- (3) Mz vs α  nach Fz ---
ax3 = nexttile;
sc3 = scatter(alpha_deg, Mz_all, MKSIZE, Fz_all, 'filled');
xlabel('α [°]'); ylabel('Mz [Nm]');
title('Ausrichtendes Moment  M_z vs α');
cb3 = colorbar; cb3.Label.String = 'Fz [N]';
colormap(ax3, turbo); grid on; axis tight;
xline(0,'k--','Alpha',0.4);

% --- (4) Mx vs Fz ---
ax4 = nexttile;
scatter(Fz_all, Mx_all, MKSIZE, abs(alpha_deg), 'filled');
xlabel('Fz [N]'); ylabel('Mx [Nm]');
title('Überrollmoment  M_x vs F_z');
cb4 = colorbar; cb4.Label.String = '|α| [°]';
colormap(ax4, parula); grid on; axis tight;

% --- (5) Fy vs α  nach Camber γ ---
ax5 = nexttile;
scatter(alpha_deg, Fy_all, MKSIZE, gamma_deg, 'filled');
xlabel('α [°]'); ylabel('Fy [N]');
title('Seitenkraft  F_y vs α  (nach γ)');
cb5 = colorbar; cb5.Label.String = 'γ [°]';
colormap(ax5, cool); grid on; axis tight;
xline(0,'k--','Alpha',0.4);

% --- (6) Mz vs α  nach Camber γ ---
ax6 = nexttile;
scatter(alpha_deg, Mz_all, MKSIZE, gamma_deg, 'filled');
xlabel('α [°]'); ylabel('Mz [Nm]');
title('Ausrichtendes Moment  M_z vs α  (nach γ)');
cb6 = colorbar; cb6.Label.String = 'γ [°]';
colormap(ax6, cool); grid on; axis tight;
xline(0,'k--','Alpha',0.4);
end

function compareFilters(tireObj)
% COMPAREFILTERS  Vergleicht 5 Filterstrategien auf Fy (und Mz) eines Segments.
%
% Angezeigte Methoden:
%   1 — Moving Average      einfach, symmetrisch, verschmiert Peaks
%   2 — Savitzky-Golay      Polynomfit im Fenster; erhält Peak-Form am besten
%   3 — Median              robust gegen Spikes; nicht-linear
%   4 — Butterworth (IIR)   frequenzbasiert, Nullphasen-Anwendung via filtfilt
%   5 — LOWESS              lokale Regresssion; sehr flexibel, langsamer
%
% EMPFEHLUNG für TTC-Fitting: Savitzky-Golay (Methode 2)
% → erhält Kurvenform (entscheidend für Pacejka-Fit), filtert HF-Rauschen.

%% Rohdaten
Fy_raw = tireObj.Fy;
Mz_raw = tireObj.Mz;
n      = numel(Fy_raw);
t_ax   = (1:n)';

%% ---- Filterparameter (hier zentral anpassen) ----
MA_K         = 21;       % Moving Average Fensterbreite
SG_ORDER     = 3;        % Savitzky-Golay Polynomgrad
SG_FRAME     = 21;       % Savitzky-Golay Fensterlänge (ungerade)
MED_K        = 21;       % Median Fensterlänge (ungerade)
BUTTER_ORDER = 4;        % Butterworth Filterordnung
BUTTER_FC    = 0.04;     % Grenzfrequenz (normiert 0..1, 1 = Nyquist)
LOWESS_SPAN  = 0.03;     % LOWESS Glättungsspanne (Anteil der Datenpunkte)

%% ---- Filterberechnungen ----
% 1 — Moving Average
Fy_ma  = movmean(Fy_raw, MA_K);
Mz_ma  = movmean(Mz_raw, MA_K);

% 2 — Savitzky-Golay
Fy_sg  = sgolayfilt(Fy_raw, SG_ORDER, SG_FRAME);
Mz_sg  = sgolayfilt(Mz_raw, SG_ORDER, SG_FRAME);

% 3 — Median
Fy_med = medfilt1(Fy_raw, MED_K);
Mz_med = medfilt1(Mz_raw, MED_K);

% 4 — Butterworth (nullphasig via filtfilt)
[b, a] = butter(BUTTER_ORDER, BUTTER_FC, 'low');
Fy_bw  = filtfilt(b, a, Fy_raw);
Mz_bw  = filtfilt(b, a, Mz_raw);

% 5 — LOWESS (erfordert Curve Fitting Toolbox oder Statistics Toolbox)
try
    Fy_lw  = smooth(Fy_raw, LOWESS_SPAN, 'lowess');
    Mz_lw  = smooth(Mz_raw, LOWESS_SPAN, 'lowess');
catch
    warning('compareFilters: smooth() nicht verfügbar — LOWESS übersprungen.');
    Fy_lw  = NaN(size(Fy_raw));
    Mz_lw  = NaN(size(Mz_raw));
end

%% ---- Residuen berechnen (Roh minus Gefiltert → zeigt was entfernt wurde) ----
res = @(raw, filt) raw - filt;

%% ---- Plotting ----
methods   = {'Moving Avg (k='+string(MA_K)+')', ...
             'Savitzky-Golay (p='+string(SG_ORDER)+', k='+string(SG_FRAME)+')', ...
             'Median (k='+string(MED_K)+')', ...
             'Butterworth (n='+string(BUTTER_ORDER)+', fc='+string(BUTTER_FC)+')', ...
             'LOWESS (span='+string(LOWESS_SPAN)+')'};

Fy_filtered = {Fy_ma, Fy_sg, Fy_med, Fy_bw, Fy_lw};
Mz_filtered = {Mz_ma, Mz_sg, Mz_med, Mz_bw, Mz_lw};

NMET = numel(methods);
COL  = lines(NMET);   % je eine Farbe pro Methode

fig = figure('Name','Filter-Vergleich','NumberTitle','off');
fig.Position = [50 50 1600 950];

tl = tiledlayout(fig, 3, NMET, 'TileSpacing','compact','Padding','compact');
title(tl, 'Filter-Vergleich — Fy & Mz', 'FontSize',13);

for m = 1:NMET
    %% Zeile 1: Fy gefiltert (+ Rohdaten im Hintergrund)
    ax_top = nexttile(m);
    hold on;
    plot(t_ax, Fy_raw,          'Color',[0.8 0.8 0.8], 'LineWidth',0.8, ...
         'DisplayName','Roh');
    plot(t_ax, Fy_filtered{m},  'Color',COL(m,:), 'LineWidth',1.6, ...
         'DisplayName', methods{m});
    if m == 1, ylabel('F_y [N]'); end
    title(methods{m}, 'FontSize',9, 'Interpreter','none');
    legend('Location','northwest','FontSize',7);
    grid on; axis tight;

    %% Zeile 2: Residuum Fy (zeigt welches Rauschen entfernt wurde)
    ax_mid = nexttile(m + NMET);
    plot(t_ax, res(Fy_raw, Fy_filtered{m}), 'Color',COL(m,:), 'LineWidth',0.8);
    yline(0,'k--','Alpha',0.5);
    if m == 1, ylabel('Residuum F_y [N]'); end
    xlabel('Sample [–]');
    title('Residuum (Roh – Gefiltert)', 'FontSize',8);
    grid on; axis tight;

    %% Zeile 3: Mz gefiltert
    ax_bot = nexttile(m + 2*NMET);
    hold on;
    plot(t_ax, Mz_raw,         'Color',[0.8 0.8 0.8], 'LineWidth',0.8);
    plot(t_ax, Mz_filtered{m}, 'Color',COL(m,:), 'LineWidth',1.6);
    if m == 1, ylabel('M_z [Nm]'); end
    title('M_z gefiltert', 'FontSize',8);
    grid on; axis tight;
end

%% Gemeinsame Annotation
annotation(fig, 'textbox', [0.01 0.01 0.98 0.04], ...
    'String', ['Empfehlung für Pacejka-Fit: Savitzky-Golay — ' ...
               'erhält Peak-Form am besten, symmetrisch, ' ...
               'kein Phasenverzug (k=' num2str(SG_FRAME) ', p=' num2str(SG_ORDER) ')'], ...
    'FitBoxToText','on', 'EdgeColor','none', 'FontSize',9, ...
    'Color',[0 0.5 0], 'HorizontalAlignment','center');
end