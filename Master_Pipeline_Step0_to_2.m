%% Master_Pipeline_Step0_to_2.m
%  TTC Round 9 - Reifenmodell-Pipeline (RP25e, Hoosier 43075)
%  Schritte 0-2: Run-Lookup, Laden/Filtern/Klassifizieren, Fit der Stuetzreifen
%
% Autor: Lambo || Datum: 22.06.26
%
%  Aufbau:
%    Abschnitt 1: KONFIGURATION  <- hier Pfade/Parameter anpassen
%    Abschnitt 2: AUSFUEHRUNG    <- ruft die drei Schritte nacheinander auf
%    %% Functions: lokale Funktionen (Step0/Step1/Step2 + Hilfsfunktionen)
%
%  Einfach mit F5 (Run) starten. Alle Zwischenergebnisse werden in den
%  unten konfigurierten Ordnern als .mat gespeichert.

clear; clc; close all;
addpath("Functions");

%% ════════════════════════════════════════════════════════════════════════
%% ABSCHNITT 1: KONFIGURATION
%% ════════════════════════════════════════════════════════════════════════

DATA_ROOT     = '0_Tire_test_data';      % Ordner mit B2356run<N>.mat Dateien
SEG_DIR       = '1_All_Segments';        % Output von Step1
FIT_DIR       = '2_Fitted_Models';       % Output von Step2
FILE_PATTERN  = 'B2356run%d.mat';        % Dateinamen-Schema, ggf. anpassen

RIM_WIDTH_IN  = 7;                       % RP25e faehrt 7" Felge

TARGET_TIRE_CODE  = '43075';                          % Zielreifen (kein Fx!)
SUPPORT_TIRE_CODES = {'43100','D0571','MRF_ZTD1'};    % Stuetzreifen (voll)
ALL_TIRE_CODES     = [{TARGET_TIRE_CODE}, SUPPORT_TIRE_CODES];

DOWNSAMPLE_FACTOR = 3;   % fuer Step2 Fit (Bessel hat bereits geglaettet)

%% ════════════════════════════════════════════════════════════════════════
%% ABSCHNITT 2: AUSFUEHRUNG
%% ════════════════════════════════════════════════════════════════════════

fprintf('╔══════════════════════════════════════════════════════════╗\n');
fprintf('║  STEP 0: Run-Lookup-Tabelle aufbauen                       ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n');
run_table = local_Step0_Build_Run_Lookup();

fprintf('\n╔══════════════════════════════════════════════════════════╗\n');
fprintf('║  STEP 1: Laden, Filtern, Klassifizieren                    ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n');
local_Step1_Load_and_Segment(run_table, DATA_ROOT, ...
    'TireCodes', ALL_TIRE_CODES, ...
    'RimWidthIn', RIM_WIDTH_IN, ...
    'OutDir', SEG_DIR, ...
    'FilePattern', FILE_PATTERN);

fprintf('\n╔══════════════════════════════════════════════════════════╗\n');
fprintf('║  STEP 2: Fit der Stuetzreifen (Fy/Fx Pure + Combined)       ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n');
support_models = local_Step2_Fit_Support_Tires(SEG_DIR, ...
    'TireCodes', SUPPORT_TIRE_CODES, ...
    'OutDir', FIT_DIR, ...
    'DownsampleFactor', DOWNSAMPLE_FACTOR); %#ok<NASGU>

fprintf('\nFERTIG. Naechster Schritt: Step3 (Fy-Pure-Fit fuer %s) und\n', TARGET_TIRE_CODE);
fprintf('Step4 (mu-Verhaeltnis-Schaetzung fuer Fx auf Basis der Stuetzreifen).\n');


%% Functions

% ═══════════════════════════════════════════════════════════════════════
% STEP 0: Run-Lookup-Tabelle
% ═══════════════════════════════════════════════════════════════════════
function run_table = local_Step0_Build_Run_Lookup()
% Erstellt die Run-Nummer -> Testbedingung Lookup-Tabelle
% fuer FSAE TTC Round 9, Projekt 2356.
%
% Quelle der Zuordnung:
%   - RunGuide_Round9.pdf (Tire/Rim -> Run-Bereich)
%   - 2356_Summary_Tables.xlsx, Sheet "Test Schedule" (Calspan Run-Log,
%     verifiziert Run-fuer-Run gegen "Command File Name" und "Run Comments")
%   - 2356_Summary_Tables.xlsx, Sheet "Tire ID Schedule" (TIRF Tire# -> Code/Compound)
%
% WICHTIG: Diese Tabelle ist HART KODIERT fuer Round 9 / Projekt 2356.
%          Bei anderen Runden muss sie neu aus dem jeweiligen RunGuide
%          und den Summary Tables aufgebaut werden (Struktur bleibt gleich).

C = {};
% --- 43075 16x7.5-10 R20, Rim 6" (tire4) ---
C(end+1,:) = {1,  '43075', '16x7.5-10_R20', 6, 'Transient',         'P1', true,  'Init spring + step steer'};
C(end+1,:) = {2,  '43075', '16x7.5-10_R20', 6, 'ColdToHot_Spring',  'P1', true,  'Repeat of Run1 (C1: load control problem in Run1)'};
C(end+1,:) = {3,  '43075', '16x7.5-10_R20', 6, 'MainSweep',         'P1', false, 'Aborted: pressure line broke (C2)'};
C(end+1,:) = {4,  '43075', '16x7.5-10_R20', 6, 'MainSweep',         'P1', false, 'Restart of Run3, also incomplete (C3)'};
C(end+1,:) = {5,  '43075', '16x7.5-10_R20', 6, 'MainSweep',         'P1', true,  'Restart, valid main sweep (10/14psi)'};
C(end+1,:) = {6,  '43075', '16x7.5-10_R20', 6, 'FinalSpeed',        'P2', true,  '8psi block + final 12psi + speed sweeps'};

% --- 43075 16x7.5-10 R20, Rim 7" (tire5) ---
C(end+1,:) = {7,  '43075', '16x7.5-10_R20', 7, 'Transient',         'P1', true,  ''};
C(end+1,:) = {8,  '43075', '16x7.5-10_R20', 7, 'MainSweep',         'P1', true,  '10/14/8psi main sweep'};
C(end+1,:) = {9,  '43075', '16x7.5-10_R20', 7, 'FinalSpeed',        'P2', true,  'Final 12psi + speed sweeps'};

% --- 43070 16x6.0-10 R20, Rim 6" (tire1) ---
C(end+1,:) = {10, '43070', '16x6.0-10_R20', 6, 'Transient',         'P1', true,  ''};
C(end+1,:) = {11, '43070', '16x6.0-10_R20', 6, 'MainSweep',         'P1', true,  ''};
C(end+1,:) = {12, '43070', '16x6.0-10_R20', 6, 'FinalSpeed',        'P2', true,  ''};

% --- 43070 16x6.0-10 R20, Rim 7" (tire2) ---
C(end+1,:) = {13, '43070', '16x6.0-10_R20', 7, 'Transient',         'P1', true,  ''};
C(end+1,:) = {14, '43070', '16x6.0-10_R20', 7, 'MainSweep',         'P1', true,  ''};
C(end+1,:) = {15, '43070', '16x6.0-10_R20', 7, 'FinalSpeed',        'P2', true,  ''};

% --- 43100 18.0x6.0-10 R20, Rim 6" (tire7) ---
C(end+1,:) = {27, '43100', '18x6.0-10_R20', 6, 'ColdToHot_Spring',  'P1', true,  ''};
C(end+1,:) = {28, '43100', '18x6.0-10_R20', 6, 'MainSweep',         'P1', true,  'C6: mech. limit reached on some conditions'};
C(end+1,:) = {29, '43100', '18x6.0-10_R20', 6, 'FinalSpeed',        'P2', true,  ''};

% --- 43100 18.0x6.0-10 R20, Rim 7" (tire8) ---
C(end+1,:) = {30, '43100', '18x6.0-10_R20', 7, 'ColdToHot_Spring',  'P1', true,  ''};
C(end+1,:) = {31, '43100', '18x6.0-10_R20', 7, 'MainSweep',         'P1', true,  'C6: mech. limit reached on some conditions'};
C(end+1,:) = {32, '43100', '18x6.0-10_R20', 7, 'FinalSpeed',        'P2', true,  ''};

% --- Goodyear D0571 18.0x6.5-10, Rim 6" (tire22) ---
C(end+1,:) = {33, 'D0571', '18x6.5-10',     6, 'ColdToHot_Spring',  'P1', true,  ''};
C(end+1,:) = {34, 'D0571', '18x6.5-10',     6, 'MainSweep',         'P1', true,  'C6: mech. limit reached on some conditions'};
C(end+1,:) = {35, 'D0571', '18x6.5-10',     6, 'FinalSpeed',        'P2', true,  ''};

% --- Goodyear D0571 18.0x6.5-10, Rim 7" (tire23) ---
C(end+1,:) = {36, 'D0571', '18x6.5-10',     7, 'ColdToHot_Spring',  'P1', true,  ''};
C(end+1,:) = {37, 'D0571', '18x6.5-10',     7, 'MainSweep',         'P1', true,  'C6: mech. limit reached on some conditions'};
C(end+1,:) = {38, 'D0571', '18x6.5-10',     7, 'FinalSpeed',        'P2', true,  ''};

% --- MRF 18x6.0-10 ZTD1, Rim 6" (tire17) ---
C(end+1,:) = {39, 'MRF_ZTD1', '18x6.0-10',  6, 'ColdToHot_Spring',  'P1', true,  ''};
C(end+1,:) = {40, 'MRF_ZTD1', '18x6.0-10',  6, 'MainSweep',         'P1', true,  'C6: mech. limit reached on some conditions'};
C(end+1,:) = {41, 'MRF_ZTD1', '18x6.0-10',  6, 'FinalSpeed',        'P2', true,  ''};

% --- MRF 18x6.0-10 ZTD1, Rim 7" (tire18) ---
C(end+1,:) = {42, 'MRF_ZTD1', '18x6.0-10',  7, 'ColdToHot_Spring',  'P1', true,  ''};
C(end+1,:) = {43, 'MRF_ZTD1', '18x6.0-10',  7, 'MainSweep',         'P1', true,  'C6: mech. limit reached on some conditions'};
C(end+1,:) = {44, 'MRF_ZTD1', '18x6.0-10',  7, 'FinalSpeed',        'P2', true,  ''};

% --- MRF 18x6.0-10 ZTD1, Rim 6" (tire19, Drive/Brake) ---
C(end+1,:) = {62, 'MRF_ZTD1', '18x6.0-10',  6, 'Warmup',    'P1', true, ''};
C(end+1,:) = {63, 'MRF_ZTD1', '18x6.0-10',  6, 'MainSweep', 'P1', true, '10/14/8psi Slip-Ratio-Sweeps'};
C(end+1,:) = {64, 'MRF_ZTD1', '18x6.0-10',  6, 'MainSweep', 'P2', true, 'Final 12psi + speed sweeps'};

% --- MRF 18x6.0-10 ZTD1, Rim 7" (tire20, Drive/Brake) ---
C(end+1,:) = {65, 'MRF_ZTD1', '18x6.0-10',  7, 'Warmup',    'P1', true, ''};
C(end+1,:) = {66, 'MRF_ZTD1', '18x6.0-10',  7, 'MainSweep', 'P1', true, ''};
C(end+1,:) = {67, 'MRF_ZTD1', '18x6.0-10',  7, 'MainSweep', 'P2', true, ''};

% --- 43100 18.0x6.0-10 R20, Rim 6" (tire9, Drive/Brake) ---
C(end+1,:) = {68, '43100', '18x6.0-10_R20', 6, 'Warmup',    'P1', true, ''};
C(end+1,:) = {69, '43100', '18x6.0-10_R20', 6, 'MainSweep', 'P1', true, 'C8: tire slipped on wheel'};
C(end+1,:) = {70, '43100', '18x6.0-10_R20', 6, 'MainSweep', 'P2', true, 'C8: tire slipped on wheel'};

% --- 43100 18.0x6.0-10 R20, Rim 7" (tire10, Drive/Brake) ---
C(end+1,:) = {71, '43100', '18x6.0-10_R20', 7, 'Warmup',    'P1', true, ''};
C(end+1,:) = {72, '43100', '18x6.0-10_R20', 7, 'MainSweep', 'P1', true, ''};
C(end+1,:) = {73, '43100', '18x6.0-10_R20', 7, 'MainSweep', 'P2', true, ''};

% --- Goodyear D0571 18.0x6.5-10, Rim 6" (tire24, Drive/Brake) ---
C(end+1,:) = {74, 'D0571', '18x6.5-10', 6, 'Warmup',    'P1', true, ''};
C(end+1,:) = {75, 'D0571', '18x6.5-10', 6, 'MainSweep', 'P1', true, ''};
C(end+1,:) = {76, 'D0571', '18x6.5-10', 6, 'MainSweep', 'P2', true, ''};

% --- Goodyear D0571 18.0x6.5-10, Rim 7" (tire25, Drive/Brake) ---
C(end+1,:) = {77, 'D0571', '18x6.5-10', 7, 'Warmup',    'P1', true, ''};
C(end+1,:) = {78, 'D0571', '18x6.5-10', 7, 'MainSweep', 'P1', true, 'C8: tire slipped on wheel'};
C(end+1,:) = {79, 'D0571', '18x6.5-10', 7, 'MainSweep', 'P2', true, ''};

run_table = cell2table(C, 'VariableNames', ...
    {'run_id','tire_code','construction','rim_width_in', ...
     'test_type','pressure_block','is_valid','comment'});

run_table.test_category = repmat({'Cornering'}, height(run_table), 1);
run_table.test_category(run_table.run_id >= 60) = {'DriveBrake'};

fprintf('Run-Lookup-Tabelle erstellt: %d Runs, %d Reifenkonstruktionen\n', ...
    height(run_table), numel(unique(run_table.tire_code)));
fprintf('  Cornering-Runs:   %d\n', sum(strcmp(run_table.test_category,'Cornering')));
fprintf('  Drive/Brake-Runs: %d\n', sum(strcmp(run_table.test_category,'DriveBrake')));
fprintf('  Als ungueltig markiert: %d (siehe comment-Spalte)\n', sum(~run_table.is_valid));
end


% ═══════════════════════════════════════════════════════════════════════
% STEP 1: Laden, Filtern, Klassifizieren
% ═══════════════════════════════════════════════════════════════════════
function local_Step1_Load_and_Segment(run_table, data_root, varargin)
% Laedt TTC Round-9 Rohdaten gezielt ueber die Run-Lookup-Tabelle,
% filtert und klassifiziert.
%
% Strategie (im Unterschied zum Altsystem):
%   1) Run-Lookup bestimmt VORAB welche Runs ueberhaupt fuer den Fit
%      relevant sind (Transient/ColdToHot werden kategorisch ausgeschlossen)
%   2) Nur relevante Runs werden geladen -> kein blindes Einlesen ganzer Ordner
%   3) Bessel/Butterworth-Filter wie bisher (Gruppenlaufzeit-Konstanz)
%   4) split("et") trennt Sweeps INNERHALB eines Runs
%   5) SA/SL-Punktklassifikation (Lateral/Longitudinal/Combined) NUR
%      innerhalb der bereits als relevant markierten Runs
%   6) Qualitaetsfilter (Temperatur, Fz-Kontakt, Coverage) wie bisher

p = inputParser;
addParameter(p, 'TireCodes', unique(run_table.tire_code), @iscell);
addParameter(p, 'RimWidthIn', 7, @isnumeric);
addParameter(p, 'OutDir', '1_All_Segments', @ischar);
addParameter(p, 'FilePattern', 'B2356run%d.mat', @ischar);
parse(p, varargin{:});
tire_codes   = p.Results.TireCodes;
RIM_WIDTH_IN = p.Results.RimWidthIn;
OUT_DIR      = p.Results.OutDir;
FILE_PATTERN = p.Results.FilePattern;

fprintf('Felgenbreite (Filter): %d"  (RP25e-Konfiguration)\n', RIM_WIDTH_IN);

BESSEL_ORDER    = 4;
BESSEL_FC_HZ    = 5.0;
FS_HZ           = 100.0;

SA_THRESH_DEG   = 0.5;
SL_THRESH       = 0.02;
FILTER_WIN      = 301;

MIN_POINTS      = 50;
TEMP_MIN        = 40;
FZ_MIN          = 50;
SA_COVERAGE_DEG = 7.0;
SL_COVERAGE     = 0.06;

EXCLUDED_TYPES = {'Transient', 'ColdToHot_Spring'};

if ~isfolder(OUT_DIR), mkdir(OUT_DIR); end

Wn = 2 * BESSEL_FC_HZ / FS_HZ;
[b_bess, a_bess] = local_besself_digital(BESSEL_ORDER, Wn);
fprintf('Bessel-Filter: Ordnung %d, Fc=%.1f Hz (Wn=%.4f)\n\n', ...
    BESSEL_ORDER, BESSEL_FC_HZ, Wn);

for c = 1:numel(tire_codes)
    code = tire_codes{c};

    mask_relevant = strcmp(run_table.tire_code, code) & ...
                    run_table.rim_width_in == RIM_WIDTH_IN & ...
                    ~ismember(run_table.test_type, EXCLUDED_TYPES) & ...
                    run_table.is_valid;
    rows = run_table(mask_relevant, :);

    fprintf('════════════════════════════════════════════════════════════\n');
    fprintf('Reifen-Code: %s, Felge %d"  (%d relevante Runs von %d gesamt)\n', ...
        code, RIM_WIDTH_IN, height(rows), sum(strcmp(run_table.tire_code, code)));

    if isempty(rows)
        fprintf('  WARNUNG: Keine relevanten Runs nach Lookup-Filter.\n\n');
        continue;
    end

    cnt = struct('raw',0,'filtered_warm',0,'filtered_coverage',0, ...
        'lateral',0,'longitudinal',0,'combined',0,'undefined',0);
    tire_segs = tireData.empty;

    for r = 1:height(rows)
        run_id   = rows.run_id(r);
        rim_w    = rows.rim_width_in(r);
        ttype    = rows.test_type{r};
        fname    = sprintf(FILE_PATTERN, run_id);
        fpath    = fullfile(data_root, fname);

        if ~isfile(fpath)
            fprintf('  [Run %3d] FEHLT: %s\n', run_id, fname);
            continue;
        end

        fprintf('  [Run %3d] %s  (Rim %d", %s)\n', run_id, fname, rim_w, ttype);
        raw = load(fpath);

        raw.FX = local_apply_bessel(raw.FX, b_bess, a_bess);
        raw.FY = local_apply_bessel(raw.FY, b_bess, a_bess);
        raw.FZ = abs(local_apply_bessel(raw.FZ, b_bess, a_bess));
        raw.MX = local_apply_bessel(raw.MX, b_bess, a_bess);
        raw.MZ = local_apply_bessel(raw.MZ, b_bess, a_bess);
        raw.SA = local_apply_bessel(raw.SA, b_bess, a_bess);
        raw.SL = local_apply_bessel(raw.SL, b_bess, a_bess);
        raw.IA = local_apply_bessel(raw.IA, b_bess, a_bess);
        raw.P  = max(raw.P, 0.1);

        if ~isfield(raw, 'tireid'), raw.tireid = code; end
        if ~isfield(raw, 'testid'), raw.testid = ttype; end

        td_raw = create_Tire_object();
        td_raw = populate_tire_object(td_raw, raw);

        segs = split(td_raw, "et");
        cnt.raw = cnt.raw + numel(segs);

        segs = setTestingMethod_Smoothed(segs, ...
            deg2rad(SA_THRESH_DEG), SL_THRESH, FILTER_WIN);

        for s = 1:numel(segs)
            seg = segs(s);
            valid = (seg.Fz > FZ_MIN) & (seg.TtreadI > TEMP_MIN);
            n_valid = sum(valid);

            if n_valid < MIN_POINTS
                cnt.filtered_warm = cnt.filtered_warm + 1;
                continue;
            end

            seg_valid = local_subsample(seg, valid);
            method  = seg_valid.TestMethod;
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

            switch method
                case 'Lateral',      cnt.lateral      = cnt.lateral + 1;
                case 'Longitudinal', cnt.longitudinal = cnt.longitudinal + 1;
                case 'Combined',     cnt.combined     = cnt.combined + 1;
                otherwise,           cnt.undefined    = cnt.undefined + 1;
            end

            if ~strcmp(method, 'Undefined')
                seg_valid.Comments = sprintf('%s_run%d_rim%din', code, run_id, rim_w);
                tire_segs(end+1) = seg_valid;  %#ok<AGROW>
            end
        end
    end % Run-Loop

    fprintf('\n  ── Qualitaetsbericht: %s ──\n', code);
    fprintf('     Roh-Segmente nach split():   %d\n', cnt.raw);
    fprintf('     Gefiltert (Temp/Kontakt):   -%d\n', cnt.filtered_warm);
    fprintf('     Gefiltert (Coverage):       -%d\n', cnt.filtered_coverage);
    fprintf('     -> Lateral:                  %d\n', cnt.lateral);
    fprintf('     -> Longitudinal:             %d\n', cnt.longitudinal);
    fprintf('     -> Combined:                 %d\n', cnt.combined);
    fprintf('     -> Undefined (verworfen):    %d\n\n', cnt.undefined);

    out_file = fullfile(OUT_DIR, sprintf('Step1_Segments_%s.mat', code));
    save(out_file, 'tire_segs', 'code', 'cnt');
    fprintf('  Gespeichert: %s\n\n', out_file);
end

fprintf('════════════════════════════════════════════════════════════\n');
fprintf('STEP 1 FERTIG.\n');
end


function [b, a] = local_besself_digital(order, Wn)
    [b, a] = butter(order, Wn, 'low');
end

function y = local_apply_bessel(x, b, a)
    if numel(x) < 3 * max(numel(a), numel(b))
        y = x; return;
    end
    y = filtfilt(b, a, double(x(:)));
    y = reshape(y, size(x));
    if any(isnan(y)) || any(isinf(y)) || max(abs(y)) > 1e6 * max(abs(x(:)))
        warning('apply_bessel: Filter instabil - ungefilterte Daten verwendet.');
        y = x;
    end
end

function seg_out = local_subsample(td, mask)
n = sum(mask);
seg_out = tireData();

seg_out.et      = td.et(mask);
seg_out.seget   = td.seget(mask);
seg_out.segment = ones(n, 1);
seg_out.measnumb = (1:n)';

seg_out.Fx = td.Fx(mask);
seg_out.Fy = td.Fy(mask);
seg_out.Fz = td.Fz(mask);
seg_out.Mx = td.Mx(mask);
seg_out.My = td.My(mask);
seg_out.Mz = td.Mz(mask);

seg_out.IP    = td.IP(mask);
seg_out.alpha = td.alpha(mask);
seg_out.gamma = td.gamma(mask);
seg_out.kappa = td.kappa(mask);
seg_out.phit  = td.phit(mask);
seg_out.V     = td.V(mask);
seg_out.omega = td.omega(mask);

seg_out.TtreadI = td.TtreadI(mask);
seg_out.TtreadC = td.TtreadC(mask);
seg_out.TtreadO = td.TtreadO(mask);

seg_out.TestMethod = td.TestMethod;
seg_out.TireSize   = td.TireSize;
seg_out.Comments   = td.Comments;
end


% ═══════════════════════════════════════════════════════════════════════
% STEP 2: Fit der Stuetzreifen (Fy/Fx Pure + Combined)
% ═══════════════════════════════════════════════════════════════════════
function support_models = local_Step2_Fit_Support_Tires(seg_dir, varargin)
% Fittet das MF6.x Reifenmodell fuer alle Stuetzreifen mit
% VOLLSTAENDIGEN Daten (Fy Pure + Fx Pure + Combined).
%
% Fit-Strategie 1:1 aus dem bewaehrten Einzelreifen-Workflow uebernommen:
%   a) Fy Pure  -> Vorzeichen-Check PKY1, Degressivitaets-Check PDY2
%   b) Fx Pure
%   c) Combined -> Shape/Offset-Parameter eingefroren
%      (RCX1=1, RCY1=1, RHX1=0, RHY1=0, REX1=REX2=REY1=REY2=0),
%      nur RBX1/RBX2/RBY1/RBY2 etc. werden frei gefittet
%   ...jetzt als Schleife ueber mehrere Reifen-Codes statt Einzelreifen.

p = inputParser;
addParameter(p, 'TireCodes', {'43100','D0571','MRF_ZTD1'}, @iscell);
addParameter(p, 'OutDir', '2_Fitted_Models', @ischar);
addParameter(p, 'Geometry', local_default_geometry(), @(x) isa(x,'containers.Map'));
addParameter(p, 'DownsampleFactor', 3, @isnumeric);
parse(p, varargin{:});
tire_codes = p.Results.TireCodes;
OUT_DIR    = p.Results.OutDir;
geometry   = p.Results.Geometry;
DS_FACTOR  = p.Results.DownsampleFactor;

INFLPRES = 82740;   % [Pa] 12 psi - Haupt-Testdruck laut RunGuide (P1-Block)
NOMPRES  = 82740;
FNOMIN   = 700;     % [N]  Nennlast

if ~isfolder(OUT_DIR), mkdir(OUT_DIR); end

support_models = struct('tire_code', {}, 'tm', {}, 'fit_meta', {});

for c = 1:numel(tire_codes)
    code = tire_codes{c};
    fprintf('════════════════════════════════════════════════════════════\n');
    fprintf('Fitte Stuetzreifen: %s\n', code);

    seg_file = fullfile(seg_dir, sprintf('Step1_Segments_%s.mat', code));
    if ~isfile(seg_file)
        warning('Step2: Segmentdatei fehlt fuer %s (%s) - uebersprungen.', code, seg_file);
        continue;
    end
    S = load(seg_file);
    segs = S.tire_segs;

    if isempty(segs)
        warning('Step2: Keine Segmente fuer %s - uebersprungen.', code);
        continue;
    end

    methods_all = arrayfun(@(s) string(s.TestMethod), segs);
    td_lat  = segs(methods_all == "Lateral");
    td_long = segs(methods_all == "Longitudinal");
    td_comb = segs(methods_all == "Combined");

    fprintf('  Segmente (vor DS): Lateral=%d, Longitudinal=%d, Combined=%d\n', ...
        numel(td_lat), numel(td_long), numel(td_comb));

    if isempty(td_lat)
        warning('Step2: Keine Lateral-Segmente fuer %s - Fy-Pure-Fit nicht moeglich.', code);
        continue;
    end

    td_lat  = local_downsample_segs(td_lat,  DS_FACTOR);
    td_long = local_downsample_segs(td_long, DS_FACTOR);
    td_comb = local_downsample_segs(td_comb, DS_FACTOR);
    fprintf('  Punkte nach DS (Faktor %d): Lateral=%d, Long.=%d, Combined=%d\n', ...
        DS_FACTOR, local_count_pts(td_lat), local_count_pts(td_long), local_count_pts(td_comb));

    tm = tireModel.new("MF");
    tm.Name     = sprintf('MF_%s', code);
    tm.INFLPRES = INFLPRES;
    tm.NOMPRES  = NOMPRES;
    tm.FNOMIN   = FNOMIN;

    if isKey(geometry, code)
        g = geometry(code);
        tm.UNLOADED_RADIUS = g.UNLOADED_RADIUS;
        tm.WIDTH           = g.WIDTH;
        tm.ASPECT_RATIO    = g.ASPECT_RATIO;
        tm.RIM_RADIUS      = g.RIM_RADIUS;
        tm.RIM_WIDTH       = g.RIM_WIDTH;
    else
        warning('Step2: Keine Geometrie fuer %s hinterlegt - Toolbox-Defaults bleiben aktiv.', code);
    end

    td_all = [td_lat, td_long, td_comb];
    [tm, ~] = fit(tm, td_all, "Limits", "Parameters", ["FZMAX","ALPMIN","ALPMAX"]);
    tm.FZMIN = 0;

    tm.PCY1 =  1.30;
    tm.PDY1 =  2.20;   tm.PDY2 = -0.10;
    tm.PEY1 = -0.30;   tm.PEY2 = -0.20;
    tm.PKY1 = 35.00;   tm.PKY2 =  2.00;  tm.PKY3 = 0.00;
    tm.PKY4 =  2.00;
    tm.PHY1 =  0.00;   tm.PHY2 =  0.00;
    tm.PVY1 =  0.00;   tm.PVY2 =  0.00;
    tm.PDY3 =  0.00;

    tm.PCX1 =  1.60;
    tm.PDX1 =  2.20;   tm.PDX2 = -0.10;
    tm.PEX1 = -0.50;   tm.PEX2 = -0.20;
    tm.PKX1 = 45.00;   tm.PKX2 = -0.50;  tm.PKX3 = 0.00;
    tm.PHX1 =  0.00;   tm.PHX2 =  0.00;
    tm.PVX1 =  0.00;   tm.PVX2 =  0.00;

    tm.RBX1 =  8.0;    tm.RBX2 =  6.0;   tm.RBX3 = 0.0;
    tm.RCX1 =  1.0;    tm.REX1 =  0.0;   tm.REX2 = 0.0;   tm.RHX1 = 0.0;

    tm.RBY1 = 12.0;    tm.RBY2 =  6.0;   tm.RBY3 = 0.0;   tm.RBY4 = 0.0;
    tm.RCY1 =  1.0;    tm.REY1 =  0.0;   tm.REY2 = 0.0;
    tm.RHY1 =  0.0;    tm.RHY2 =  0.0;

    fit_meta = struct('FittedOn', datestr(now), 'INFLPRES', INFLPRES, ...
        'FNOMIN', FNOMIN, 'Fy_Pure_rmse', NaN, 'Fx_Pure_rmse', NaN, ...
        'Fy_Comb_rmse', NaN, 'Fx_Comb_rmse', NaN, ...
        'n_lateral', numel(td_lat), 'n_longitudinal', numel(td_long), ...
        'n_combined', numel(td_comb));

    fprintf('  ── Fit 1: Fy Pure ──\n');
    [tm, res] = fit(tm, td_lat, "Fy Pure", PlotFit=false);
    fit_meta.Fy_Pure_rmse = local_extract_rmse(res);
    fprintf('    RMSE = %.1f N\n', fit_meta.Fy_Pure_rmse);

    if tm.PKY1 < 0
        fprintf('    *** PKY1=%.4f negativ - Vorzeichen korrigiert, Refit...\n', tm.PKY1);
        tm.PKY1 = abs(tm.PKY1);
        [tm, res] = fit(tm, td_lat, "Fy Pure", PlotFit=false);
        fit_meta.Fy_Pure_rmse = local_extract_rmse(res);
        fprintf('    Refit RMSE = %.1f N\n', fit_meta.Fy_Pure_rmse);
    end
    if tm.PDY2 > 0
        warning('Step2 [%s]: PDY2=%.4f positiv (keine Degressivitaet erkennbar).', code, tm.PDY2);
    end

    if ~isempty(td_long)
        fprintf('  ── Fit 2: Fx Pure ──\n');
        [tm, res] = fit(tm, td_long, "Fx Pure", PlotFit=false);
        fit_meta.Fx_Pure_rmse = local_extract_rmse(res);
        fprintf('    RMSE = %.1f N\n', fit_meta.Fx_Pure_rmse);
    else
        fprintf('  Keine Longitudinal-Daten - Fx Pure uebersprungen.\n');
    end

    if ~isempty(td_comb)
        tm.RCX1 = 1.0; tm.RHX1 = 0.0; tm.REX1 = 0.0; tm.REX2 = 0.0;
        tm.RCY1 = 1.0; tm.RHY1 = 0.0; tm.REY1 = 0.0; tm.REY2 = 0.0;

        fprintf('  ── Fit 3: Fy Combined (RCX1/RHX1/REX1-2 eingefroren) ──\n');
        [tm, res] = fit(tm, td_comb, "Fy Combined", PlotFit=false);
        fit_meta.Fy_Comb_rmse = local_extract_rmse(res);
        fprintf('    RMSE = %.1f N\n', fit_meta.Fy_Comb_rmse);

        tm.RCX1 = 1.0; tm.RHX1 = 0.0; tm.REX1 = 0.0; tm.REX2 = 0.0;
        tm.RCY1 = 1.0; tm.RHY1 = 0.0; tm.REY1 = 0.0; tm.REY2 = 0.0;

        fprintf('  ── Fit 4: Fx Combined ──\n');
        [tm, res] = fit(tm, td_comb, "Fx Combined", PlotFit=false);
        fit_meta.Fx_Comb_rmse = local_extract_rmse(res);
        fprintf('    RMSE = %.1f N\n', fit_meta.Fx_Comb_rmse);

        tm.RCX1 = 1.0; tm.RHX1 = 0.0; tm.REX1 = 0.0; tm.REX2 = 0.0;
        tm.RCY1 = 1.0; tm.RHY1 = 0.0; tm.REY1 = 0.0; tm.REY2 = 0.0;
    else
        fprintf('  Keine Combined-Daten - Combined-Fit uebersprungen.\n');
    end

    fprintf('  Plausibilitaetscheck:\n');
    local_verify_g_factors(tm);

    idx = numel(support_models) + 1;
    support_models(idx).tire_code = code;
    support_models(idx).tm        = tm;
    support_models(idx).fit_meta  = fit_meta;

    out_file = fullfile(OUT_DIR, sprintf('Step2_FittedModel_%s.mat', code));
    save(out_file, 'tm', 'fit_meta', 'code');
    fprintf('  Gespeichert: %s\n\n', out_file);
end

fprintf('════════════════════════════════════════════════════════════\n');
fprintf('STEP 2 FERTIG - %d von %d Stuetzreifen erfolgreich gefittet.\n\n', ...
    numel(support_models), numel(tire_codes));
fprintf('%-12s  %10s  %10s  %12s  %12s\n', 'Reifen', 'Fy_Pure', 'Fx_Pure', 'Fy_Comb', 'Fx_Comb');
for i = 1:numel(support_models)
    fm = support_models(i).fit_meta;
    fprintf('%-12s  %10.1f  %10.1f  %12.1f  %12.1f\n', ...
        support_models(i).tire_code, fm.Fy_Pure_rmse, fm.Fx_Pure_rmse, ...
        fm.Fy_Comb_rmse, fm.Fx_Comb_rmse);
end

save(fullfile(OUT_DIR, 'Step2_AllSupportModels.mat'), 'support_models');
end


function geo = local_default_geometry()
% PLATZHALTER-Geometrie aus Nominal-Reifenbezeichnung abgeleitet.
% BITTE mit '2356 Summary Tables.xlsx' (Tire Weights o.ae.) verifizieren!
% Werte in Metern.
geo = containers.Map();

% 43100: 18.0x6.0-10 R20 - Hoosier-Katalog bestaetigt 18.1" OD, 8.1" Sektion
geo('43100') = struct('UNLOADED_RADIUS', 0.2300, 'WIDTH', 0.2057, ...
    'ASPECT_RATIO', 0.45, 'RIM_RADIUS', 0.1270, 'RIM_WIDTH', 0.1778);

% D0571: 18.0x6.5-10 - PLATZHALTER aus Nominalbezeichnung
geo('D0571') = struct('UNLOADED_RADIUS', 0.2280, 'WIDTH', 0.1651, ...
    'ASPECT_RATIO', 0.45, 'RIM_RADIUS', 0.1270, 'RIM_WIDTH', 0.1778);

% MRF_ZTD1: 18.0x6.0-10 - PLATZHALTER aus Nominalbezeichnung
geo('MRF_ZTD1') = struct('UNLOADED_RADIUS', 0.2280, 'WIDTH', 0.1524, ...
    'ASPECT_RATIO', 0.45, 'RIM_RADIUS', 0.1270, 'RIM_WIDTH', 0.1778);
end


function local_verify_g_factors(tm)
    try, LXAL = tm.LXAL; catch, LXAL = 1.0; end
    try, LYKA = tm.LYKA; catch, LYKA = 1.0; end

    S_hxa = tm.RHX1;
    B_xa  = tm.RBX1 * cos(atan(tm.RBX2 * 0)) * LXAL;
    a_s   = 0 + S_hxa;
    E_xa  = min(tm.REX1, 1.0);
    num   = cos(tm.RCX1*atan(B_xa*a_s   - E_xa*(B_xa*a_s   - atan(B_xa*a_s))));
    den   = cos(tm.RCX1*atan(B_xa*S_hxa - E_xa*(B_xa*S_hxa - atan(B_xa*S_hxa))));
    Gxa_0 = num / max(abs(den), 1e-12);

    S_Hk = tm.RHY1;
    k_s  = 0 + S_Hk;
    B_yk = tm.RBY1 * cos(atan(tm.RBY2 * (0 - tm.RBY3))) * LYKA;
    E_yk = min(tm.REY1, 1.0);
    num2 = cos(tm.RCY1*atan(B_yk*k_s  - E_yk*(B_yk*k_s  - atan(B_yk*k_s))));
    den2 = cos(tm.RCY1*atan(B_yk*S_Hk - E_yk*(B_yk*S_Hk - atan(B_yk*S_Hk))));
    Gyk_0 = num2 / max(abs(den2), 1e-12);

    if abs(Gxa_0 - 1.0) < 0.001
        fprintf('    G_xa(0,0) = %.6f  OK\n', Gxa_0);
    else
        fprintf('    G_xa(0,0) = %.6f  *** INKONSISTENT (RCX1=%.4f, RHX1=%.6f)\n', ...
            Gxa_0, tm.RCX1, tm.RHX1);
    end
    if abs(Gyk_0 - 1.0) < 0.001
        fprintf('    G_yk(0,0) = %.6f  OK\n', Gyk_0);
    else
        fprintf('    G_yk(0,0) = %.6f  *** INKONSISTENT (RCY1=%.4f, RHY1=%.6f)\n', ...
            Gyk_0, tm.RCY1, tm.RHY1);
    end
end


function rmse = local_extract_rmse(res)
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


function n = local_count_pts(td)
    n = 0;
    for i = 1:numel(td)
        n = n + numel(td(i).Fz);
    end
end


function td_ds = local_downsample_segs(td_array, factor)
    if factor <= 1
        td_ds = td_array;
        return;
    end
    td_ds = tireData.empty;
    for i = 1:numel(td_array)
        td = td_array(i);
        n  = numel(td.Fz);
        idx = 1:factor:n;
        if numel(idx) < 20, continue; end

        seg = tireData();
        seg.et      = td.et(idx);
        seg.seget   = td.seget(idx);
        seg.segment = ones(numel(idx),1);
        seg.measnumb= (1:numel(idx))';
        seg.Fx = td.Fx(idx); seg.Fy = td.Fy(idx); seg.Fz = td.Fz(idx);
        seg.Mx = td.Mx(idx); seg.My = td.My(idx); seg.Mz = td.Mz(idx);
        seg.IP = td.IP(idx); seg.alpha = td.alpha(idx); seg.gamma = td.gamma(idx);
        seg.kappa = td.kappa(idx); seg.phit = td.phit(idx); seg.V = td.V(idx);
        seg.omega = td.omega(idx);
        seg.TtreadI = td.TtreadI(idx); seg.TtreadC = td.TtreadC(idx); seg.TtreadO = td.TtreadO(idx);
        seg.TestMethod = td.TestMethod; seg.TireSize = td.TireSize; seg.Comments = td.Comments;

        td_ds(end+1) = seg;  %#ok<AGROW>
    end
end