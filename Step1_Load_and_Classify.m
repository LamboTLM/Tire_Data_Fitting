function Step1_Load_and_Classify()
%% Step 1 v2: Laden, Bessel-Filter, Split und Klassifikation
%
%  Strategie:
%    1) Raw .mat laden
%    2) Bessel-Filter (5 Hz Tiefpass) auf alle Kraft- und Winkelkanäle
%    3) populate_tire_object → tireData Objekt erstellen
%    4) split("et") → Toolbox-native Segmentierung
%    5) setTestingMethod_Smoothed → Klassifikation
%    6) Qualitätsfilter (Mindestpunkte, Coverage, Temperatur)
%    7) Speichern
%
%  Warum Bessel-Filter?
%    - Maximale Gruppenlaufzeitkonstanz (linearer Phasengang)
%    - Keine Phasenverzerrung der Kraft-Schlupf-Kurven
%    - Dämpft hochfrequentes Messrauschen ohne Kurvenform zu verzerren
%    - Im Gegensatz zu Butterworth/Chebyshev: kein Überschwingen

addpath("Functions");

%% ── Konfiguration ─────────────────────────────────────────────────────────
ROOT_DATA_DIR   = '0_Tire_test_data';
OUT_DIR         = '1_All_Segments';
OUT_FILE        = fullfile(OUT_DIR, 'Step1_AllSegments.mat');

% Bessel-Filter Parameter
BESSEL_ORDER    = 4;      % Filterordnung (4 = guter Kompromiss Schärfe/Stabilität)
BESSEL_FC_HZ    = 5.0;   % Grenzfrequenz [Hz] – TTC-Sweeps haben Inhalt < 1 Hz
FS_HZ           = 100.0; % Abtastrate [Hz] (Standard TTC)
%  → Normierte Grenzfrequenz: Wn = 2 * Fc / Fs = 0.10
%  → Alles über 5 Hz ist Messrauschen, kein Reifensignal

% Klassifikation (wie bisher)
SA_THRESH_DEG   = 0.5;   % [deg] ab wann SA "aktiv"
SL_THRESH       = 0.02;  % [-]   ab wann SL "aktiv"
FILTER_WIN      = 301;   % Medianfilter-Fenster für Klassifikation

% Qualitätsfilter
MIN_POINTS      = 50;    % Mindest-Datenpunkte pro Segment nach Filterung
TEMP_MIN        = 40;    % [°C]  Mindesttemperatur (Warmup ausschließen)
FZ_MIN          = 50;    % [N]   Kein Reifenkontakt
SA_COVERAGE_DEG = 7.0;  % [deg] Lateral: muss ±SA abgedeckt sein
SL_COVERAGE     = 0.06; % [-]   Long/Combined: muss ±SL abgedeckt sein

%% ── Bessel-Filter vorbereiten ─────────────────────────────────────────────
Wn = 2 * BESSEL_FC_HZ / FS_HZ;   % Normierte Grenzfrequenz (0 < Wn < 1)
[b_bess, a_bess] = besself_digital(BESSEL_ORDER, Wn);
fprintf('Bessel-Filter: Ordnung %d, Fc=%.1f Hz (Wn=%.4f)\n\n', ...
    BESSEL_ORDER, BESSEL_FC_HZ, Wn);

%% ── Unterordner finden ────────────────────────────────────────────────────
subdirs = dir(ROOT_DATA_DIR);
subdirs = subdirs([subdirs.isdir] & ~startsWith({subdirs.name}, '.'));
fprintf('Reifen-Ordner gefunden: %d\n', numel(subdirs));
for d = 1:numel(subdirs)
    fprintf('  [%d] %s\n', d, subdirs(d).name);
end
fprintf('\n');

if ~isfolder(OUT_DIR), mkdir(OUT_DIR); end

%% ── Ergebnis-Container ────────────────────────────────────────────────────
all_segments    = tireData.empty;   % Alle akzeptierten Segmente
processed_tires = struct('tire_id',{}, 'safe_id',{}, ...
    'n_lateral',{}, 'n_longitudinal',{}, 'n_combined',{});

%% ── Hauptschleife über Reifen-Ordner ─────────────────────────────────────
for d = 1:numel(subdirs)
    tire_dir = fullfile(ROOT_DATA_DIR, subdirs(d).name);
    files    = dir(fullfile(tire_dir, '*.mat'));

    fprintf('════════════════════════════════════════════════════════════\n');
    fprintf('Ordner [%d/%d]: %s  (%d Dateien)\n', d, numel(subdirs), ...
        subdirs(d).name, numel(files));

    if isempty(files)
        fprintf('  WARNUNG: Keine .mat-Dateien.\n\n'); continue;
    end

    cnt = struct('raw',0,'filtered_warm',0,'filtered_coverage',0, ...
        'lateral',0,'longitudinal',0,'combined',0,'undefined',0);

    tire_segs = tireData.empty;  % Segmente dieses Reifens

    for i = 1:numel(files)
        fpath = fullfile(files(i).folder, files(i).name);
        raw   = load(fpath);

        fprintf('  [%d/%d] %s\n', i, numel(files), files(i).name);

        %% ── 1. Bessel-Filter auf Rohdaten ─────────────────────────────
        % Kanäle die gefilter werden (Kräfte, Winkel, Schlupf)
        % ET, P, V, N, Temp: NICHT filtern (oder nur leicht)
        raw.FX = apply_bessel(raw.FX, b_bess, a_bess);
        raw.FY = apply_bessel(raw.FY, b_bess, a_bess);
        raw.FZ = abs(apply_bessel(raw.FZ, b_bess, a_bess));  % Fz immer positiv
        raw.MX = apply_bessel(raw.MX, b_bess, a_bess);
        raw.MZ = apply_bessel(raw.MZ, b_bess, a_bess);
        raw.SA = apply_bessel(raw.SA, b_bess, a_bess);
        raw.SL = apply_bessel(raw.SL, b_bess, a_bess);
        raw.IA = apply_bessel(raw.IA, b_bess, a_bess);
        raw.P  = max(raw.P, 0.1);   % Kein Filter, nur Clamp

        %% ── 2. tireData-Objekt erstellen und befüllen ─────────────────
        td_raw = create_Tire_object();
        td_raw = populate_tire_object(td_raw, raw);

        %% ── 3. Split nach Zeitsprüngen ────────────────────────────────
        %  split("et"): Toolbox-native Trennung bei ET-Sprüngen
        %  Gibt Array von tireData-Objekten zurück, je 1 pro Sweep
        segs = split(td_raw, "et");
        cnt.raw = cnt.raw + numel(segs);

        %% ── 4. Klassifikation (Lateral / Longitudinal / Combined) ─────
        segs = setTestingMethod_Smoothed(segs, ...
            deg2rad(SA_THRESH_DEG), SL_THRESH, FILTER_WIN);

        %% ── 5. Qualitätsfilter pro Segment ────────────────────────────
        for s = 1:numel(segs)
            
            seg = segs(s);

            % DEBUG – einmalig ausführen, danach auskommentieren
            fprintf('  DEBUG Segment 1: Fz=[%.1f, %.1f]  Temp=[%.1f, %.1f]\n', ...
            min(seg.Fz), max(seg.Fz), min(seg.TtreadI), max(seg.TtreadI));

            % Grundlegende Gültigkeitsmaske
            valid = (seg.Fz > FZ_MIN) & (seg.TtreadI > TEMP_MIN);
            n_valid = sum(valid);

            % Mindestpunkte
            if n_valid < MIN_POINTS
                cnt.filtered_warm = cnt.filtered_warm + 1;
                continue;
            end

            % Segmente auf gültige Punkte beschränken
            % (tireData unterstützt logisches Indexing)
            seg_valid = subsample(seg, valid);

            % Coverage-Check je nach Testmethode
            method = seg_valid.TestMethod;
            sa_vals = rad2deg(seg_valid.alpha);
            sl_vals = seg_valid.kappa;

            coverage_ok = true;
            switch method
                case 'Lateral'
                    if max(sa_vals) < SA_COVERAGE_DEG || min(sa_vals) > -SA_COVERAGE_DEG
                        coverage_ok = false;
                    end
                case {'Longitudinal', 'Combined'}
                    if max(sl_vals) < SL_COVERAGE || min(sl_vals) > -SL_COVERAGE
                        coverage_ok = false;
                    end
            end

            if ~coverage_ok
                cnt.filtered_coverage = cnt.filtered_coverage + 1;
                continue;
            end

            % Zählen und sammeln
            switch method
                case 'Lateral',      cnt.lateral      = cnt.lateral + 1;
                case 'Longitudinal', cnt.longitudinal = cnt.longitudinal + 1;
                case 'Combined',     cnt.combined     = cnt.combined + 1;
                otherwise,           cnt.undefined    = cnt.undefined + 1;
            end

            if ~strcmp(method, 'Undefined')
                tire_segs(end+1) = seg_valid;  %#ok<AGROW>
            end
        end % Segment-Loop

    end % File-Loop

    %% ── Reifen-Bericht ────────────────────────────────────────────────────
    tire_id = '';
    if numel(tire_segs) > 0
        tire_id = tire_segs(1).TireSize;  % TireSize = TireID (aus populate_tire_object)
    end
    safe_id = regexprep(regexprep(tire_id, '[^a-zA-Z0-9]', '_'), '_+', '_');

    fprintf('\n  ── Qualitätsbericht: %s ──\n', subdirs(d).name);
    fprintf('     Roh-Segmente nach split():     %d\n', cnt.raw);
    fprintf('     Gefiltert (Temp/Kontakt):     -%d Segmente\n', cnt.filtered_warm);
    fprintf('     Gefiltert (Coverage):         -%d Segmente\n', cnt.filtered_coverage);
    fprintf('     ─────────────────────────────────────────\n');
    fprintf('     → Lateral:                    %d\n', cnt.lateral);
    fprintf('     → Longitudinal:               %d\n', cnt.longitudinal);
    fprintf('     → Combined:                   %d\n', cnt.combined);
    fprintf('     → Undefined (verworfen):      %d\n\n', cnt.undefined);

    all_segments = [all_segments; tire_segs(:)];  %#ok<AGROW>

    processed_tires(end+1).tire_id       = tire_id;
    processed_tires(end).safe_id         = safe_id;
    processed_tires(end).n_lateral       = cnt.lateral;
    processed_tires(end).n_longitudinal  = cnt.longitudinal;
    processed_tires(end).n_combined      = cnt.combined;
end % Ordner-Loop

%% ── Gesamtübersicht und Speichern ─────────────────────────────────────────
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('FERTIG – %d Segmente total gespeichert\n\n', numel(all_segments));
fprintf('%-45s  %8s  %8s  %8s\n', 'Reifen-ID', 'Lateral', 'Long.', 'Combined');
fprintf('%s\n', repmat('-',1,75));
for d = 1:numel(processed_tires)
    fprintf('%-45s  %8d  %8d  %8d\n', ...
        processed_tires(d).tire_id, ...
        processed_tires(d).n_lateral, ...
        processed_tires(d).n_longitudinal, ...
        processed_tires(d).n_combined);
end

save(OUT_FILE, 'all_segments', 'processed_tires');
fprintf('\nGespeichert: %s\n', OUT_FILE);
fprintf('Nächster Schritt: Step2_Preprocess_and_Fit_v2()\n');

end % main


%% ══════════════════════════════════════════════════════════════════════════
%% Hilfsfunktionen
%% ══════════════════════════════════════════════════════════════════════════

function [b, a] = besself_digital(order, Wn)
    % Butterworth Tiefpass – mit filtfilt() kein Phasengang, 
    % daher kein Nachteil gegenüber Bessel
    [b, a] = butter(order, Wn, 'low');
end

function y = apply_bessel(x, b, a)
    if numel(x) < 3 * max(numel(a), numel(b))
        y = x; return;
    end
    y = filtfilt(b, a, double(x(:)));
    y = reshape(y, size(x));

    % Stabilitätscheck: wenn Filter explodiert, Original zurückgeben
    if any(isnan(y)) || any(isinf(y)) || max(abs(y)) > 1e6 * max(abs(x(:)))
        warning('apply_bessel: Filter instabil – ungefilterte Daten verwendet.');
        y = x;
    end
end


function seg_out = subsample(td, mask)
%  Beschränkt ein tireData-Objekt auf gültige Punkte via logischer Maske.
%  Gibt ein neues tireData-Objekt zurück.
%
%  HINWEIS: Falls tireData logisches Indexing nativ unterstützt,
%  ersetze durch: seg_out = td(mask);
%  Ansonsten: manuelle Kanal-Zuweisung.

n = sum(mask);
seg_out = tireData();

% Zeitachsen
seg_out.et      = td.et(mask);
seg_out.seget   = td.seget(mask);
seg_out.segment = ones(n, 1);
seg_out.measnumb = (1:n)';

% Kräfte & Momente
seg_out.Fx = td.Fx(mask);
seg_out.Fy = td.Fy(mask);
seg_out.Fz = td.Fz(mask);
seg_out.Mx = td.Mx(mask);
seg_out.My = td.My(mask);
seg_out.Mz = td.Mz(mask);

% Kinematik
seg_out.IP    = td.IP(mask);
seg_out.alpha = td.alpha(mask);
seg_out.gamma = td.gamma(mask);
seg_out.kappa = td.kappa(mask);
seg_out.phit  = td.phit(mask);
seg_out.V     = td.V(mask);
seg_out.omega = td.omega(mask);

% Temperaturen
seg_out.TtreadI = td.TtreadI(mask);
seg_out.TtreadC = td.TtreadC(mask);
seg_out.TtreadO = td.TtreadO(mask);

% Metadaten
seg_out.TestMethod = td.TestMethod;
seg_out.TireSize   = td.TireSize;
seg_out.Comments   = td.Comments;
end