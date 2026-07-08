classdef Tire_Filter_App_mat < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                      matlab.ui.Figure
        SmoothingPanel                matlab.ui.container.Panel
        SmoothingRowsGrid             matlab.ui.container.GridLayout
        SmoothingAddDropDown          matlab.ui.control.DropDown
        FilterPanel                   matlab.ui.container.Panel
        FilterRowsGrid                matlab.ui.container.GridLayout
        HideUnusedCheckBox            matlab.ui.control.CheckBox
        FilterAddDropDown             matlab.ui.control.DropDown
        AuswahlPanel                  matlab.ui.container.Panel
        LoadTireDataButton            matlab.ui.control.Button
        Test_file_directroy           matlab.ui.control.EditField
        OpenDirectoryButton           matlab.ui.control.Button
        Panel                         matlab.ui.container.Panel
        ReifentestViewerCarNo62Label  matlab.ui.control.Label
        DynamicseVLabel               matlab.ui.control.Label
        TabGroup2                     matlab.ui.container.TabGroup
        TestPreprocessingTab          matlab.ui.container.Tab
        UIAxes_Sweep                  matlab.ui.control.UIAxes
        UIAxes_Mu                     matlab.ui.control.UIAxes
        UIAxes_Pneu                   matlab.ui.control.UIAxes
        CorneringTab_2                matlab.ui.container.Tab
        UIAxes                        matlab.ui.control.UIAxes
        UIAxes_2                      matlab.ui.control.UIAxes
        UIAxes_3                      matlab.ui.control.UIAxes
        CorneringKennwerteTab_2       matlab.ui.container.Tab
        UIAxes_CK_1                   matlab.ui.control.UIAxes
        UIAxes_CK_2                   matlab.ui.control.UIAxes
        UIAxes_CK_3                   matlab.ui.control.UIAxes
        CamberSweepTab_2              matlab.ui.container.Tab
        UIAxes_Cam_1                  matlab.ui.control.UIAxes
        UIAxes_Cam_2                  matlab.ui.control.UIAxes
        UIAxes_Cam_3                  matlab.ui.control.UIAxes
        DriveBrakeTab_2                matlab.ui.container.Tab
        UIAxes_DB_1                   matlab.ui.control.UIAxes
        UIAxes_DB_2                   matlab.ui.control.UIAxes
        UIAxes_DB_3                   matlab.ui.control.UIAxes
        CombinedSlipTab_2              matlab.ui.container.Tab
        UIAxes_CS_1                   matlab.ui.control.UIAxes
        UIAxes_CS_2                   matlab.ui.control.UIAxes
        ColdtohotVerschleissTab       matlab.ui.container.Tab
        UIAxes_CH_1                   matlab.ui.control.UIAxes
        UIAxes_CH_2                   matlab.ui.control.UIAxes
        TransientTab_2                matlab.ui.container.Tab
        UIAxes_TR_1                   matlab.ui.control.UIAxes
        UIAxes_TR_2                   matlab.ui.control.UIAxes
        SpeedVergleichTab_2           matlab.ui.container.Tab
        UIAxes_SV_1                   matlab.ui.control.UIAxes
        UIAxes_SV_2                   matlab.ui.control.UIAxes
        UIAxes_SV_3                   matlab.ui.control.UIAxes
        RohdatenExplorerTab_2         matlab.ui.container.Tab
        UIAxes_RE_1                   matlab.ui.control.UIAxes
        UIAxes_RE_2                   matlab.ui.control.UIAxes
        ManuelSelctionTab             matlab.ui.container.Tab
        ShowFilteredYellowCheckBox    matlab.ui.control.CheckBox
        UIAxes_MS_1                   matlab.ui.control.UIAxes
        UIAxes_MS_2                   matlab.ui.control.UIAxes
        UIAxes_MS_3                   matlab.ui.control.UIAxes
        FrequenzanalyseTab            matlab.ui.container.Tab
        UIAxes_FA_Time                matlab.ui.control.UIAxes
        UIAxes_FA_Spec                matlab.ui.control.UIAxes
        FA_SweepDropDown              matlab.ui.control.DropDown
        FA_ChannelDropDown            matlab.ui.control.DropDown
        FA_AnalyzeButton              matlab.ui.control.Button
        FA_ApplyCutoffButton          matlab.ui.control.Button
        FA_ResultLabel                matlab.ui.control.Label
    end


    %% Definieren der Filter Config
    properties (Access = private)
        % Klassifikation
        SA_THRESH_DEG (1,1) double = 0.5    % [deg] ab wann SA "aktiv"
        SL_THRESH (1,1) double = 0.02       % [-] ab wann SL "aktiv"
        FILTER_WIN (1,1) double = 301       % Medianfilter-Fenster fuer Klassifikation

        % Qualitaetsfilter
        MIN_POINTS (1,1) double = 50        % Mindest-Datenpunkte pro Segment
        TEMP_MIN (1,1) double = 40          % [°C] Mindesttemperatur
        FZ_MIN (1,1) double = 50            % [N] Kein Reifenkontakt
        SA_COVERAGE_DEG (1,1) double = 7.0  % [deg] Lateral-Coverage
        SL_COVERAGE (1,1) double = 0.06     % [-] Long/Combined-Coverage

        % Daten
        sweep
        tire_file
        FilterRows = struct('Parameter', {}, 'ParameterLabel', {}, 'RowLayout', {}, 'ConditionDropDown', {}, 'Value1EditField', {}, 'Value2EditField', {}, 'DeleteButton', {})
        SmoothingRows = struct('Parameter', {}, 'RowLayout', {}, 'TypeDropDown', {}, 'EnabledCheckBox', {}, 'Param1Label', {}, 'Param1EditField', {}, 'Param2Label', {}, 'Param2EditField', {}, 'R2Label', {}, 'DeleteButton', {})

        % Nutzungs-Masken (je ein logical-Array, gleiche Groesse wie app.sweep)
        SweepIsUsed logical = []      % EFFEKTIVE Maske (Filter & ~Manuell) - wird von allen Plots konsultiert
        FilterIsUsed logical = []     % Ergebnis der reinen Bounds-Filterung (ohne manuellen Ausschluss)
        ManualExclude logical = []    % Manuell (per Klick im Sweep-Auswahl-Tab) ausgeschlossene Sweeps

        % Reifen daten nach denen gefiltert werden kann
        KNOWN_CHANNELS cell = {'alpha', 'kappa', 'Fx', 'Fy', 'Fz', 'Mx', 'Mz', 'IP', 'gamma', 'V', 'omega', 'TtreadI', 'TtreadC', 'TtreadO'} % Bekannte Messkanaele, unabhaengig vom Ladezustand

        % Smothings die gemacht werden koennen
        SMOOTHING_TYPES cell = {'Butterworth', 'Bessel', 'Moving Average', 'Savitzky-Golay', 'Median', 'Hampel (Despike)'}

        % Frequenzanalyse-Tab: letzter Analyse-Zustand (fuer "Cutoff uebernehmen")
        FA_LastCutoffSuggestion double = NaN
        FA_LastChannel char = ''
    end

    methods (Access = private)
        %% Reifenobjecte
        
        % Main function
        function load_Tire_Data(app)

            % Laden des Dateipfads aus dem Textfeld
            tire_file_full = string(app.Test_file_directroy.Value);
            tire_file_full = strip(tire_file_full, 'both', "'");
            tire_data_raw = load(tire_file_full);

            % tireData-Objekt erstellen und befüllen
            td_raw = create_Tire_object(app);
            td_raw = populate_tire_object(app, td_raw, tire_data_raw);
            segs = split(td_raw, "et");
            segs = setTestingMethod_Smoothed(app, segs, deg2rad(app.SA_THRESH_DEG), app.SL_THRESH, app.FILTER_WIN);

            % Abfertigen der Sweeps
            app.sweep = segs;

            % Frequenzanalyse-Tab: Sweep-Auswahl neu befuellen
            app.populate_fa_sweep_dropdown();
        end

        % Helper Functions
        function [tdnew] = create_Tire_object(app)
            % Erstellt ein tireData Object im SAE Koordinaten system

            tdnew = tireData();                         % Anlegen des Objects
            tdnew = tdnew.coordinateTransform("SAE");   % Definition des Koordinaten systems, später überschrieben

        end

        function [tdnew] = populate_tire_object(app, tdnew, fsData)
            %% Eingangsvariabeln
            % tdnew ist ein leeres tireData Object
            % fsData ist ein befülltest testdaten struc

            %% Ausgangsvariabeln
            % tdnew ist ein befülltes tiredata object

            %% Function Code
            % Preperation
            [row, ~] = size(fsData.MX);

            % Messdaten und Achsen (Umrechnung in SI-Einheiten) ---
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
            tdnew.TtreadI           = fsData.TSTI;                      % Reifen Temperatur Inner in °C
            tdnew.TtreadC           = fsData.TSTC;                      % Reifen Temperatur Center in °C
            tdnew.TtreadO           = fsData.TSTO;                      % Reifen Temperatur Outer in °C

            % Statische Metadaten (Reifendimensionen und Testbedingungen) ---
            tdnew.Comments          = fsData.tireid;                      % Name des Reifens zur dateibenneung
            tdnew.TestMethod        = fsData.testid;                    % Testtyp (Wichtig für Fx/Fy-Trennung)
            tdnew.TireSize          = "152.4/67R10";                    % Reifengröße, (Technisch nicht relevant, platzhalter stehen gelassen)
            tdnew.SectionWidth      = 152.4000;                         % Schnittbreite [mm]
            tdnew.AspectRatio       = 67;                               % Querschnittsverhältnis [%]
            tdnew.RimDiameter       = 10;                               % Felgendurchmesser [inch]
            tdnew.OverallDiameter   = 0.472;                            % Gesamtdurchmesser [m]
            tdnew.LoadIndex         = 90;                               % Lastindex
            tdnew.SpeedSymbol       = "V";                              % Geschwindigkeitssymbol
            tdnew.TestFacility      = "Dynamics e.V.";                  % Testeinrichtung (Metadaten)
            tdnew.TestMachine       = "MTS Flat-Trac LTRe";             % Testmaschine (Metadaten)
            tdnew.RimWidth          = 7;                                % Felgenbreite [inch]
            tdnew.Surface           = "120 3Mite";                      % Oberflächentyp
            tdnew.SurfaceCondition  = "Dry";                            % Oberflächenzustand
            tdnew.TestDate          = "24-Apr-2020 14:55:29";           % Testdatum/Zeit
            tdnew                   = tdnew.coordinateTransform("ISO"); % Konvertierung zu ISO-Standardachse
        end

        function tireObj_out = setTestingMethod_Smoothed(app, tireObj_in, threshold_SA, threshold_SL, filter_window)
            % SETTESTINGMETHOD_SMOOTHED Bestimmt die TestingMethod basierend auf dem dominierenden
            %                            glatten Klassifizierungs-Ergebnis der Zeitreihe.
            %
            % Autor: Lambo || Datum: 17.04.26
            %
            % EINGABE:
            %   tireObj_in: Ein tireData-Objekt oder Array von Objekten.
            %   threshold_SA: Schwellenwert für Schlupfwinkel (z.B. 0.5 deg).
            %   threshold_SL: Schwellenwert für Längsschlupf (z.B. 0.02).
            %   filter_window: Fenstergröße für den Medianfilter (Muss ungerade sein).

            % 1. Standard-Werte und Konstanten
            if nargin < 4
                filter_window = 301;
            end
            if nargin < 3
                threshold_SL = 0.02;
            end
            if nargin < 2
                threshold_SA = 0.5;
            end

            % Stelle sicher, dass das Filterfenster ungerade ist
            if mod(filter_window, 2) == 0
                filter_window = filter_window + 1;
            end

            % Definitionen (müssen mit dem Visualisierungs-Skript übereinstimmen)
            TYPE_INAKTIV = 0;
            TYPE_LATERAL = 1;
            TYPE_LONGITUDINAL = 2;
            TYPE_COMBINED = 3;

            tireObj_out = tireObj_in; % Kopie des Eingabeobjekts erstellen

            % 2. Hauptschleife über alle Objekte
            for k = 1:length(tireObj_in)
                current_obj = tireObj_in(k);

                % Daten extrahieren: Korrektur auf 'alpha' und 'kappa' ---
                SA_data = current_obj.alpha;
                SL_data = current_obj.kappa;

                % Vektoren synchronisieren
                minLen = min(length(SA_data), length(SL_data));
                SA_data = SA_data(1:minLen);
                SL_data = SL_data(1:minLen);
                numPoints = minLen;

                classificationVector = zeros(numPoints, 1);

                % 3. Punktweise Klassifizierung ---
                for p = 1:numPoints
                    sa_active = abs(SA_data(p)) > threshold_SA;
                    sl_active = abs(SL_data(p)) > threshold_SL;

                    if sa_active && ~sl_active
                        classificationVector(p) = TYPE_LATERAL;
                    elseif ~sa_active && sl_active
                        classificationVector(p) = TYPE_LONGITUDINAL;
                    elseif sa_active && sl_active
                        classificationVector(p) = TYPE_COMBINED;
                    else
                        classificationVector(p) = TYPE_INAKTIV;
                    end
                end

                % 4. Klassifizierung glätten (Medianfilter) ---
                smoothedClassification = medfilt1(classificationVector, filter_window);

                % 5. Dominante Phase bestimmen (KORRIGIERTE Logik) ---

                % 1. Aktive Phasen aus dem geglätteten Vektor isolieren (Ignoriere TYPE_INAKTIV = 0)
                activeClassification = smoothedClassification(smoothedClassification > TYPE_INAKTIV);

                dominant_phase_percentage = 0; % Initialisierung
                max_count = 0;

                if isempty(activeClassification)
                    % Wenn nach der Glättung nur noch INAKTIV übrig ist
                    method = 'Undefined';
                else
                    % 2. Zähle die Häufigkeiten der aktiven Phasen (1, 2, 3)
                    count_Lateral = sum(activeClassification == TYPE_LATERAL);
                    count_Longitudinal = sum(activeClassification == TYPE_LONGITUDINAL);
                    count_Combined = sum(activeClassification == TYPE_COMBINED);

                    phase_counts = [count_Lateral, count_Longitudinal, count_Combined];

                    % Finde die dominanteste aktive Phase
                    [max_count, dominant_index] = max(phase_counts);

                    % Konvertiere Index (1, 2, 3) zurück zum Phasen-Typ (1=Lat, 2=Long, 3=Comb)
                    dominant_type = dominant_index;

                    % 6. TestingMethod zuweisen ---
                    if dominant_type == TYPE_LATERAL
                        method = 'Lateral';
                    elseif dominant_type == TYPE_LONGITUDINAL
                        method = 'Longitudinal';
                    elseif dominant_type == TYPE_COMBINED
                        method = 'Combined';
                    else
                        method = 'Error: Unknown Type'; % Sollte nicht erreicht werden
                    end

                    % Prozentsatz für die Ausgabe
                    total_active_points = length(activeClassification);
                    dominant_phase_percentage = (max_count / total_active_points) * 100;
                end

                % Zuweisung des Ergebnisses
                % HINWEIS: Wir verwenden 'TestMethod' basierend auf Ihrer letzten Eingabe
                current_obj.TestMethod = method;

                % Geändertes Objekt zurückschreiben
                tireObj_out(k) = current_obj;

                % fprintf('   Datei %d/%d: TestingMethod auf "%s" gesetzt (Dominante Phase: %.1f%%)\n', ...
                %         k, length(tireObj_in), method, dominant_phase_percentage);
            end
        end

        %%  Plotten

        function plot_cornering(app)
            % PLOT_CORNERING Cornering-Plots: FY, MZ, MX ueber Schraeglaufwinkel SA,
            % farbcodiert nach FZ-Niveau. Nur reine SA-Sweeps (TestMethod = 'Lateral').
            % Beruecksichtigt die effektive Nutzungsmaske (SweepIsUsed = Filter & ~Manuell)
            % und aktive Smoothing-Profile.
            %
            % Autor: Lambo || Datum: 07.07.26
            % Changelog:
            %   07.07.26 - Smoothing-Integration ueber smooth_channel() ergaenzt

            methods = [app.sweep.TestMethod];
            is_lateral = (methods == "Lateral");
            lateral_idx = find(is_lateral);
            lateral_sweeps = app.sweep(lateral_idx);

            if isempty(lateral_sweeps)
                return
            end

            if isempty(app.SweepIsUsed)
                app.SweepIsUsed = true(size(app.sweep));
            end

            fz_levels = arrayfun(@(s) median(s.Fz, 'omitnan'), lateral_sweeps);
            cmap = turbo(numel(lateral_sweeps));
            hide_unused = app.HideUnusedCheckBox.Value;

            app.clear_axes(app.UIAxes); hold(app.UIAxes, 'on');
            app.clear_axes(app.UIAxes_2); hold(app.UIAxes_2, 'on');
            app.clear_axes(app.UIAxes_3); hold(app.UIAxes_3, 'on');

            for k = 1:numel(lateral_sweeps)
                orig_idx = lateral_idx(k);
                is_used = app.SweepIsUsed(orig_idx);
                if ~is_used && hide_unused
                    continue
                end

                s = lateral_sweeps(k);
                sa_deg = rad2deg(s.alpha);

                fy_plot = app.smooth_channel(s, 'Fy', s.Fy);
                mz_plot = app.smooth_channel(s, 'Mz', s.Mz);
                mx_plot = app.smooth_channel(s, 'Mx', s.Mx);

                if is_used
                    col = cmap(k, :);
                    lw = 1.0;
                    dname = sprintf('FZ \\approx %.0f N', fz_levels(k));
                else
                    col = [0.5 0.5 0.5];
                    lw = 0.5;
                    dname = sprintf('FZ \\approx %.0f N (gefiltert)', fz_levels(k));
                end

                plot(app.UIAxes, sa_deg, fy_plot, 'Color', col, 'LineWidth', lw, 'DisplayName', dname);
                plot(app.UIAxes_2, sa_deg, mz_plot, 'Color', col, 'LineWidth', lw, 'HandleVisibility', 'off');
                plot(app.UIAxes_3, sa_deg, mx_plot, 'Color', col, 'LineWidth', lw, 'HandleVisibility', 'off');
            end

            hold(app.UIAxes, 'off'); hold(app.UIAxes_2, 'off'); hold(app.UIAxes_3, 'off');
            legend(app.UIAxes, 'show', 'Location', 'best', 'Interpreter', 'tex');
        end

        function plot_test_preprocessing(app)
            % PLOT_TEST_PREPROCESSING Test-Preprocessing-Plots: Rohdatenverlauf mit
            % Sweep-Grenzen (ET, alle TestMethods), normierte Reibwertkurve
            % (mu_y = FY/|FZ|) und Pneumatic Trail (t_p = -MZ/FY). Reibwertkurve/
            % Pneumatic Trail nur fuer Lateral-Sweeps. Beruecksichtigt die
            % effektive Nutzungsmaske (SweepIsUsed) und Smoothing-Profile.
            %
            % Autor: Lambo || Datum: 07.07.26

            FY_THRESHOLD = 50; % [N] Mindest-FY fuer Pneumatic-Trail-Berechnung

            if isempty(app.SweepIsUsed)
                app.SweepIsUsed = true(size(app.sweep));
            end

            hide_unused = app.HideUnusedCheckBox.Value;

            ax_sweep = app.UIAxes_Sweep;
            app.clear_axes(ax_sweep); hold(ax_sweep, 'on');

            method_colors = containers.Map( ...
                {'Lateral', 'Longitudinal', 'Combined', 'Undefined'}, ...
                {[0.78 0.13 0.16], [0.20 0.60 0.90], [0.90 0.70 0.10], [0.50 0.50 0.50]});

            for k = 1:numel(app.sweep)
                is_used = app.SweepIsUsed(k);
                if ~is_used && hide_unused
                    continue
                end

                s = app.sweep(k);
                fy_plot = app.smooth_channel(s, 'Fy', s.Fy);
                method_str = char(s.TestMethod);

                if isKey(method_colors, method_str)
                    col = method_colors(method_str);
                else
                    col = [0.5 0.5 0.5];
                end
                if ~is_used
                    col = [0.4 0.4 0.4];
                end

                lw = 1.0 * is_used + 0.5 * ~is_used;
                plot(ax_sweep, s.et, fy_plot, 'Color', col, 'LineWidth', lw, 'HandleVisibility', 'off');

                if k > 1
                    xline(ax_sweep, s.et(1), '--', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off');
                end
            end

            method_names = keys(method_colors);
            for m = 1:numel(method_names)
                plot(ax_sweep, NaN, NaN, 'Color', method_colors(method_names{m}), 'DisplayName', method_names{m});
            end

            hold(ax_sweep, 'off');
            legend(ax_sweep, 'show', 'Location', 'best');

            methods = [app.sweep.TestMethod];
            is_lateral = (methods == "Lateral");
            lateral_idx = find(is_lateral);
            lateral_sweeps = app.sweep(lateral_idx);

            if isempty(lateral_sweeps)
                return
            end

            fz_levels = arrayfun(@(s) median(s.Fz, 'omitnan'), lateral_sweeps);
            cmap = turbo(numel(lateral_sweeps));

            app.clear_axes(app.UIAxes_Mu); hold(app.UIAxes_Mu, 'on');
            app.clear_axes(app.UIAxes_Pneu); hold(app.UIAxes_Pneu, 'on');

            for k = 1:numel(lateral_sweeps)
                orig_idx = lateral_idx(k);
                is_used = app.SweepIsUsed(orig_idx);
                if ~is_used && hide_unused
                    continue
                end

                s = lateral_sweeps(k);
                sa_deg = rad2deg(s.alpha);

                fy_plot = app.smooth_channel(s, 'Fy', s.Fy);
                fz_plot = app.smooth_channel(s, 'Fz', s.Fz);
                mz_plot = app.smooth_channel(s, 'Mz', s.Mz);

                if is_used
                    col = cmap(k, :);
                    lw = 1.0;
                    dname = sprintf('FZ \\approx %.0f N', fz_levels(k));
                else
                    col = [0.5 0.5 0.5];
                    lw = 0.5;
                    dname = sprintf('FZ \\approx %.0f N (gefiltert)', fz_levels(k));
                end

                mu_y = fy_plot ./ abs(fz_plot);
                plot(app.UIAxes_Mu, sa_deg, mu_y, 'Color', col, 'LineWidth', lw, 'DisplayName', dname);

                valid = abs(fy_plot) > FY_THRESHOLD;
                t_p = -mz_plot(valid) ./ fy_plot(valid);
                plot(app.UIAxes_Pneu, sa_deg(valid), t_p, 'Color', col, 'LineWidth', lw, 'HandleVisibility', 'off');
            end

            hold(app.UIAxes_Mu, 'off'); hold(app.UIAxes_Pneu, 'off');
            legend(app.UIAxes_Mu, 'show', 'Location', 'best', 'Interpreter', 'tex');
        end

        function plot_cornering_kennwerte(app)
            % PLOT_CORNERING_KENNWERTE Extrahiert charakteristische Kennwerte
            % der Lateral-Sweeps und stellt sie ueber der Normalkraft FZ dar.
            %
            % Autor: Lambo || Datum: 07.07.26

            ZERO_BAND_DEG = 1.5; % [deg] Band um SA = 0 fuer Steigungsfit

            methods = [app.sweep.TestMethod];
            is_lateral = (methods == "Lateral");
            lateral_idx = find(is_lateral);
            lateral_sweeps = app.sweep(lateral_idx);

            if isempty(lateral_sweeps)
                return
            end

            if isempty(app.SweepIsUsed)
                app.SweepIsUsed = true(size(app.sweep));
            end

            hide_unused = app.HideUnusedCheckBox.Value;

            n = numel(lateral_sweeps);
            fz_vec = zeros(n, 1);
            fy_max_vec = zeros(n, 1);
            mu_max_vec = zeros(n, 1);
            sa_fy_max_vec = zeros(n, 1);
            c_fy_alpha_vec = zeros(n, 1);
            mz_max_vec = zeros(n, 1);

            for k = 1:n
                orig_idx = lateral_idx(k);
                s = lateral_sweeps(k);
                fz_vec(k) = median(s.Fz, 'omitnan');

                if ~app.SweepIsUsed(orig_idx) && hide_unused
                    continue
                end

                sa_deg = rad2deg(s.alpha);
                fy_plot = app.smooth_channel(s, 'Fy', s.Fy);
                fz_plot = app.smooth_channel(s, 'Fz', s.Fz);
                mz_plot = app.smooth_channel(s, 'Mz', s.Mz);

                [fy_max_val, idx_fy_max] = max(abs(fy_plot));
                fy_max_vec(k) = fy_max_val * sign(fy_plot(idx_fy_max));
                sa_fy_max_vec(k) = sa_deg(idx_fy_max);
                mu_max_vec(k) = max(abs(fy_plot ./ abs(fz_plot)), [], 'omitnan');
                mz_max_vec(k) = max(abs(mz_plot), [], 'omitnan');

                idx_zero = abs(sa_deg) <= ZERO_BAND_DEG;
                if sum(idx_zero) >= 3
                    p = polyfit(sa_deg(idx_zero), fy_plot(idx_zero), 1);
                    c_fy_alpha_vec(k) = p(1);
                else
                    c_fy_alpha_vec(k) = NaN;
                end
            end

            app.clear_axes(app.UIAxes_CK_1); hold(app.UIAxes_CK_1, 'on');
            app.clear_axes(app.UIAxes_CK_2); hold(app.UIAxes_CK_2, 'on');
            app.clear_axes(app.UIAxes_CK_3); hold(app.UIAxes_CK_3, 'on');

            for k = 1:n
                orig_idx = lateral_idx(k);
                is_used = app.SweepIsUsed(orig_idx);
                if ~is_used && hide_unused
                    continue
                end

                if is_used
                    col = [0.78 0.13 0.16];
                    ms = 6;
                else
                    col = [0.5 0.5 0.5];
                    ms = 4;
                end

                plot(app.UIAxes_CK_1, fz_vec(k), fy_max_vec(k), 'o', 'Color', col, 'MarkerFaceColor', col, 'MarkerSize', ms);
                plot(app.UIAxes_CK_2, fz_vec(k), mu_max_vec(k), 'o', 'Color', col, 'MarkerFaceColor', col, 'MarkerSize', ms);
                plot(app.UIAxes_CK_3, fz_vec(k), c_fy_alpha_vec(k), 'o', 'Color', col, 'MarkerFaceColor', col, 'MarkerSize', ms);
            end

            title(app.UIAxes_CK_1, 'Max. Seitenkraft');
            xlabel(app.UIAxes_CK_1, 'FZ [N]'); ylabel(app.UIAxes_CK_1, 'FY_{max} [N]');
            title(app.UIAxes_CK_2, 'Max. Reibwert');
            xlabel(app.UIAxes_CK_2, 'FZ [N]'); ylabel(app.UIAxes_CK_2, '\mu_{y,max} [-]', 'Interpreter', 'tex');
            title(app.UIAxes_CK_3, 'Cornering-Stiffness');
            xlabel(app.UIAxes_CK_3, 'FZ [N]'); ylabel(app.UIAxes_CK_3, 'C_{Fy,\alpha} [N/deg]', 'Interpreter', 'tex');

            hold(app.UIAxes_CK_1, 'off'); hold(app.UIAxes_CK_2, 'off'); hold(app.UIAxes_CK_3, 'off');
        end

        function plot_camber_sweep(app)
            % PLOT_CAMBER_SWEEP Visualisiert den Einfluss des Sturzwinkels gamma
            % auf die Lateral-Kennlinien. Farbcodierung nach gamma.
            %
            % Autor: Lambo || Datum: 07.07.26

            methods = [app.sweep.TestMethod];
            is_lateral = (methods == "Lateral");
            lateral_idx = find(is_lateral);
            lateral_sweeps = app.sweep(lateral_idx);

            if isempty(lateral_sweeps)
                return
            end

            if isempty(app.SweepIsUsed)
                app.SweepIsUsed = true(size(app.sweep));
            end

            hide_unused = app.HideUnusedCheckBox.Value;

            gamma_levels = arrayfun(@(s) median(s.gamma, 'omitnan'), lateral_sweeps);
            fz_levels = arrayfun(@(s) median(s.Fz, 'omitnan'), lateral_sweeps);
            cmap = turbo(numel(lateral_sweeps));

            app.clear_axes(app.UIAxes_Cam_1); hold(app.UIAxes_Cam_1, 'on');
            app.clear_axes(app.UIAxes_Cam_2); hold(app.UIAxes_Cam_2, 'on');
            app.clear_axes(app.UIAxes_Cam_3); hold(app.UIAxes_Cam_3, 'on');

            for k = 1:numel(lateral_sweeps)
                orig_idx = lateral_idx(k);
                is_used = app.SweepIsUsed(orig_idx);
                if ~is_used && hide_unused
                    continue
                end

                s = lateral_sweeps(k);
                sa_deg = rad2deg(s.alpha);
                gamma_deg = rad2deg(gamma_levels(k));

                fy_plot = app.smooth_channel(s, 'Fy', s.Fy);
                mz_plot = app.smooth_channel(s, 'Mz', s.Mz);
                mx_plot = app.smooth_channel(s, 'Mx', s.Mx);

                if is_used
                    col = cmap(k, :);
                    lw = 1.0;
                    dname = sprintf('\\gamma \\approx %.1f^\\circ, FZ \\approx %.0f N', gamma_deg, fz_levels(k));
                else
                    col = [0.5 0.5 0.5];
                    lw = 0.5;
                    dname = sprintf('\\gamma \\approx %.1f^\\circ (gefiltert)', gamma_deg);
                end

                plot(app.UIAxes_Cam_1, sa_deg, fy_plot, 'Color', col, 'LineWidth', lw, 'DisplayName', dname);
                plot(app.UIAxes_Cam_2, sa_deg, mz_plot, 'Color', col, 'LineWidth', lw, 'HandleVisibility', 'off');
                plot(app.UIAxes_Cam_3, sa_deg, mx_plot, 'Color', col, 'LineWidth', lw, 'HandleVisibility', 'off');
            end

            title(app.UIAxes_Cam_1, 'Seitenkraft / Schraeglaufwinkel');
            xlabel(app.UIAxes_Cam_1, 'SA [deg]'); ylabel(app.UIAxes_Cam_1, 'FY [N]');
            title(app.UIAxes_Cam_2, 'Rueckstellmoment / Schraeglaufwinkel');
            xlabel(app.UIAxes_Cam_2, 'SA [deg]'); ylabel(app.UIAxes_Cam_2, 'MZ [Nm]');
            title(app.UIAxes_Cam_3, 'Sturzmoment / Schraeglaufwinkel');
            xlabel(app.UIAxes_Cam_3, 'SA [deg]'); ylabel(app.UIAxes_Cam_3, 'MX [Nm]');

            hold(app.UIAxes_Cam_1, 'off'); hold(app.UIAxes_Cam_2, 'off'); hold(app.UIAxes_Cam_3, 'off');
            legend(app.UIAxes_Cam_1, 'show', 'Location', 'best', 'Interpreter', 'tex');
        end

        function plot_drive_brake(app)
            % PLOT_DRIVE_BRAKE Longitudinal-Kennlinien: FX, MZ, FY ueber
            % Laengsschlupf kappa. Nur Longitudinal-Sweeps.
            %
            % Autor: Lambo || Datum: 07.07.26

            methods = [app.sweep.TestMethod];
            is_long = (methods == "Longitudinal");
            long_idx = find(is_long);
            long_sweeps = app.sweep(long_idx);

            if isempty(long_sweeps)
                return
            end

            if isempty(app.SweepIsUsed)
                app.SweepIsUsed = true(size(app.sweep));
            end

            hide_unused = app.HideUnusedCheckBox.Value;

            fz_levels = arrayfun(@(s) median(s.Fz, 'omitnan'), long_sweeps);
            cmap = turbo(numel(long_sweeps));

            app.clear_axes(app.UIAxes_DB_1); hold(app.UIAxes_DB_1, 'on');
            app.clear_axes(app.UIAxes_DB_2); hold(app.UIAxes_DB_2, 'on');
            app.clear_axes(app.UIAxes_DB_3); hold(app.UIAxes_DB_3, 'on');

            for k = 1:numel(long_sweeps)
                orig_idx = long_idx(k);
                is_used = app.SweepIsUsed(orig_idx);
                if ~is_used && hide_unused
                    continue
                end

                s = long_sweeps(k);
                kappa_plot = s.kappa;

                fx_plot = app.smooth_channel(s, 'Fx', s.Fx);
                mz_plot = app.smooth_channel(s, 'Mz', s.Mz);
                fy_plot = app.smooth_channel(s, 'Fy', s.Fy);

                if is_used
                    col = cmap(k, :);
                    lw = 1.0;
                    dname = sprintf('FZ \\approx %.0f N', fz_levels(k));
                else
                    col = [0.5 0.5 0.5];
                    lw = 0.5;
                    dname = sprintf('FZ \\approx %.0f N (gefiltert)', fz_levels(k));
                end

                plot(app.UIAxes_DB_1, kappa_plot, fx_plot, 'Color', col, 'LineWidth', lw, 'DisplayName', dname);
                plot(app.UIAxes_DB_2, kappa_plot, mz_plot, 'Color', col, 'LineWidth', lw, 'HandleVisibility', 'off');
                plot(app.UIAxes_DB_3, kappa_plot, fy_plot, 'Color', col, 'LineWidth', lw, 'HandleVisibility', 'off');
            end

            title(app.UIAxes_DB_1, 'Laengskraft / Laengsschlupf');
            xlabel(app.UIAxes_DB_1, '\kappa [-]'); ylabel(app.UIAxes_DB_1, 'FX [N]');
            title(app.UIAxes_DB_2, 'Rueckstellmoment / Laengsschlupf');
            xlabel(app.UIAxes_DB_2, '\kappa [-]'); ylabel(app.UIAxes_DB_2, 'MZ [Nm]');
            title(app.UIAxes_DB_3, 'Seitenkraft / Laengsschlupf');
            xlabel(app.UIAxes_DB_3, '\kappa [-]'); ylabel(app.UIAxes_DB_3, 'FY [N]');

            hold(app.UIAxes_DB_1, 'off'); hold(app.UIAxes_DB_2, 'off'); hold(app.UIAxes_DB_3, 'off');
            legend(app.UIAxes_DB_1, 'show', 'Location', 'best', 'Interpreter', 'tex');
        end

        function plot_combined_slip(app)
            % PLOT_COMBINED_SLIP Visualisiert Combined-Slip-Sweeps: FX ueber
            % kappa und FY ueber SA.
            %
            % Autor: Lambo || Datum: 07.07.26

            methods = [app.sweep.TestMethod];
            is_comb = (methods == "Combined");
            comb_idx = find(is_comb);
            comb_sweeps = app.sweep(comb_idx);

            if isempty(comb_sweeps)
                return
            end

            if isempty(app.SweepIsUsed)
                app.SweepIsUsed = true(size(app.sweep));
            end

            hide_unused = app.HideUnusedCheckBox.Value;

            fz_levels = arrayfun(@(s) median(s.Fz, 'omitnan'), comb_sweeps);
            cmap = turbo(numel(comb_sweeps));

            app.clear_axes(app.UIAxes_CS_1); hold(app.UIAxes_CS_1, 'on');
            app.clear_axes(app.UIAxes_CS_2); hold(app.UIAxes_CS_2, 'on');

            for k = 1:numel(comb_sweeps)
                orig_idx = comb_idx(k);
                is_used = app.SweepIsUsed(orig_idx);
                if ~is_used && hide_unused
                    continue
                end

                s = comb_sweeps(k);
                sa_deg = rad2deg(s.alpha);
                kappa_plot = s.kappa;

                fx_plot = app.smooth_channel(s, 'Fx', s.Fx);
                fy_plot = app.smooth_channel(s, 'Fy', s.Fy);

                if is_used
                    col = cmap(k, :);
                    lw = 1.0;
                    dname = sprintf('FZ \\approx %.0f N', fz_levels(k));
                else
                    col = [0.5 0.5 0.5];
                    lw = 0.5;
                    dname = sprintf('FZ \\approx %.0f N (gefiltert)', fz_levels(k));
                end

                plot(app.UIAxes_CS_1, kappa_plot, fx_plot, 'Color', col, 'LineWidth', lw, 'DisplayName', dname);
                plot(app.UIAxes_CS_2, sa_deg, fy_plot, 'Color', col, 'LineWidth', lw, 'HandleVisibility', 'off');
            end

            title(app.UIAxes_CS_1, 'Laengskraft / Laengsschlupf (Combined)');
            xlabel(app.UIAxes_CS_1, '\kappa [-]'); ylabel(app.UIAxes_CS_1, 'FX [N]');
            title(app.UIAxes_CS_2, 'Seitenkraft / Schraeglaufwinkel (Combined)');
            xlabel(app.UIAxes_CS_2, 'SA [deg]'); ylabel(app.UIAxes_CS_2, 'FY [N]');

            hold(app.UIAxes_CS_1, 'off'); hold(app.UIAxes_CS_2, 'off');
            legend(app.UIAxes_CS_1, 'show', 'Location', 'best', 'Interpreter', 'tex');
        end

        function plot_cold_to_hot(app)
            % PLOT_COLD_TO_HOT Visualisiert Temperaturabhaengigkeit der
            % Lateral-Kennwerte ueber der mittleren Reifentemperatur TtreadC.
            %
            % Autor: Lambo || Datum: 07.07.26

            ZERO_BAND_DEG = 1.5; % [deg]

            methods = [app.sweep.TestMethod];
            is_lateral = (methods == "Lateral");
            lateral_idx = find(is_lateral);
            lateral_sweeps = app.sweep(lateral_idx);

            if isempty(lateral_sweeps)
                return
            end

            if isempty(app.SweepIsUsed)
                app.SweepIsUsed = true(size(app.sweep));
            end

            hide_unused = app.HideUnusedCheckBox.Value;

            n = numel(lateral_sweeps);
            temp_vec = zeros(n, 1);
            mu_max_vec = zeros(n, 1);
            c_fy_alpha_vec = zeros(n, 1);

            for k = 1:n
                orig_idx = lateral_idx(k);
                s = lateral_sweeps(k);
                temp_vec(k) = median(s.TtreadC, 'omitnan');

                if ~app.SweepIsUsed(orig_idx) && hide_unused
                    continue
                end

                sa_deg = rad2deg(s.alpha);
                fy_plot = app.smooth_channel(s, 'Fy', s.Fy);
                fz_plot = app.smooth_channel(s, 'Fz', s.Fz);

                mu_max_vec(k) = max(abs(fy_plot ./ abs(fz_plot)), [], 'omitnan');

                idx_zero = abs(sa_deg) <= ZERO_BAND_DEG;
                if sum(idx_zero) >= 3
                    p = polyfit(sa_deg(idx_zero), fy_plot(idx_zero), 1);
                    c_fy_alpha_vec(k) = p(1);
                else
                    c_fy_alpha_vec(k) = NaN;
                end
            end

            app.clear_axes(app.UIAxes_CH_1); hold(app.UIAxes_CH_1, 'on');
            app.clear_axes(app.UIAxes_CH_2); hold(app.UIAxes_CH_2, 'on');

            for k = 1:n
                orig_idx = lateral_idx(k);
                is_used = app.SweepIsUsed(orig_idx);
                if ~is_used && hide_unused
                    continue
                end

                if is_used
                    col = [0.78 0.13 0.16];
                    ms = 6;
                else
                    col = [0.5 0.5 0.5];
                    ms = 4;
                end

                plot(app.UIAxes_CH_1, temp_vec(k), mu_max_vec(k), 'o', 'Color', col, 'MarkerFaceColor', col, 'MarkerSize', ms);
                plot(app.UIAxes_CH_2, temp_vec(k), c_fy_alpha_vec(k), 'o', 'Color', col, 'MarkerFaceColor', col, 'MarkerSize', ms);
            end

            title(app.UIAxes_CH_1, 'Max. Reibwert ueber Temperatur');
            xlabel(app.UIAxes_CH_1, 'T_{tread,C} [°C]'); ylabel(app.UIAxes_CH_1, '\mu_{y,max} [-]', 'Interpreter', 'tex');
            title(app.UIAxes_CH_2, 'Cornering-Stiffness ueber Temperatur');
            xlabel(app.UIAxes_CH_2, 'T_{tread,C} [°C]'); ylabel(app.UIAxes_CH_2, 'C_{Fy,\alpha} [N/deg]', 'Interpreter', 'tex');

            hold(app.UIAxes_CH_1, 'off'); hold(app.UIAxes_CH_2, 'off');
        end

        function plot_transient(app)
            % PLOT_TRANSIENT Zeigt Zeitverlaeufe von Schraeglaufwinkel und
            % Seitenkraft fuer alle Sweeps. Farbcodierung nach TestMethod.
            %
            % Autor: Lambo || Datum: 07.07.26

            if isempty(app.sweep)
                return
            end

            if isempty(app.SweepIsUsed)
                app.SweepIsUsed = true(size(app.sweep));
            end

            hide_unused = app.HideUnusedCheckBox.Value;

            method_colors = containers.Map( ...
                {'Lateral', 'Longitudinal', 'Combined', 'Undefined'}, ...
                {[0.78 0.13 0.16], [0.20 0.60 0.90], [0.90 0.70 0.10], [0.50 0.50 0.50]});

            app.clear_axes(app.UIAxes_TR_1); hold(app.UIAxes_TR_1, 'on');
            app.clear_axes(app.UIAxes_TR_2); hold(app.UIAxes_TR_2, 'on');

            for k = 1:numel(app.sweep)
                is_used = app.SweepIsUsed(k);
                if ~is_used && hide_unused
                    continue
                end

                s = app.sweep(k);
                sa_deg = rad2deg(s.alpha);
                fy_plot = app.smooth_channel(s, 'Fy', s.Fy);
                method_str = char(s.TestMethod);

                if isKey(method_colors, method_str)
                    col = method_colors(method_str);
                else
                    col = [0.5 0.5 0.5];
                end
                if ~is_used
                    col = [0.4 0.4 0.4];
                end

                lw = 1.0 * is_used + 0.5 * ~is_used;
                plot(app.UIAxes_TR_1, s.et, sa_deg, 'Color', col, 'LineWidth', lw, 'HandleVisibility', 'off');
                plot(app.UIAxes_TR_2, s.et, fy_plot, 'Color', col, 'LineWidth', lw, 'HandleVisibility', 'off');

                if k > 1
                    xline(app.UIAxes_TR_1, s.et(1), '--', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off');
                    xline(app.UIAxes_TR_2, s.et(1), '--', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off');
                end
            end

            method_names = keys(method_colors);
            for m = 1:numel(method_names)
                plot(app.UIAxes_TR_1, NaN, NaN, 'Color', method_colors(method_names{m}), 'DisplayName', method_names{m});
            end

            title(app.UIAxes_TR_1, 'Schraeglaufwinkel-Zeitverlauf');
            xlabel(app.UIAxes_TR_1, 'ET [s]'); ylabel(app.UIAxes_TR_1, 'SA [deg]');
            title(app.UIAxes_TR_2, 'Seitenkraft-Zeitverlauf');
            xlabel(app.UIAxes_TR_2, 'ET [s]'); ylabel(app.UIAxes_TR_2, 'FY [N]');

            hold(app.UIAxes_TR_1, 'off'); hold(app.UIAxes_TR_2, 'off');
            legend(app.UIAxes_TR_1, 'show', 'Location', 'best');
        end

        function plot_speed_vergleich(app)
            % PLOT_SPEED_VERGLEICH Vergleicht charakteristische Kennwerte
            % ueber der Fahrgeschwindigkeit V. Nur Lateral-Sweeps.
            %
            % Autor: Lambo || Datum: 07.07.26

            ZERO_BAND_DEG = 1.5; % [deg]

            methods = [app.sweep.TestMethod];
            is_lateral = (methods == "Lateral");
            lateral_idx = find(is_lateral);
            lateral_sweeps = app.sweep(lateral_idx);

            if isempty(lateral_sweeps)
                return
            end

            if isempty(app.SweepIsUsed)
                app.SweepIsUsed = true(size(app.sweep));
            end

            hide_unused = app.HideUnusedCheckBox.Value;

            n = numel(lateral_sweeps);
            v_vec = zeros(n, 1);
            fy_max_vec = zeros(n, 1);
            mu_max_vec = zeros(n, 1);
            c_fy_alpha_vec = zeros(n, 1);

            for k = 1:n
                orig_idx = lateral_idx(k);
                s = lateral_sweeps(k);
                v_vec(k) = median(s.V, 'omitnan');

                if ~app.SweepIsUsed(orig_idx) && hide_unused
                    continue
                end

                sa_deg = rad2deg(s.alpha);
                fy_plot = app.smooth_channel(s, 'Fy', s.Fy);
                fz_plot = app.smooth_channel(s, 'Fz', s.Fz);

                mu_max_vec(k) = max(abs(fy_plot ./ abs(fz_plot)), [], 'omitnan');
                fy_max_vec(k) = max(abs(fy_plot), [], 'omitnan');

                idx_zero = abs(sa_deg) <= ZERO_BAND_DEG;
                if sum(idx_zero) >= 3
                    p = polyfit(sa_deg(idx_zero), fy_plot(idx_zero), 1);
                    c_fy_alpha_vec(k) = p(1);
                else
                    c_fy_alpha_vec(k) = NaN;
                end
            end

            app.clear_axes(app.UIAxes_SV_1); hold(app.UIAxes_SV_1, 'on');
            app.clear_axes(app.UIAxes_SV_2); hold(app.UIAxes_SV_2, 'on');
            app.clear_axes(app.UIAxes_SV_3); hold(app.UIAxes_SV_3, 'on');

            for k = 1:n
                orig_idx = lateral_idx(k);
                is_used = app.SweepIsUsed(orig_idx);
                if ~is_used && hide_unused
                    continue
                end

                if is_used
                    col = [0.78 0.13 0.16];
                    ms = 6;
                else
                    col = [0.5 0.5 0.5];
                    ms = 4;
                end

                plot(app.UIAxes_SV_1, v_vec(k), fy_max_vec(k), 'o', 'Color', col, 'MarkerFaceColor', col, 'MarkerSize', ms);
                plot(app.UIAxes_SV_2, v_vec(k), mu_max_vec(k), 'o', 'Color', col, 'MarkerFaceColor', col, 'MarkerSize', ms);
                plot(app.UIAxes_SV_3, v_vec(k), c_fy_alpha_vec(k), 'o', 'Color', col, 'MarkerFaceColor', col, 'MarkerSize', ms);
            end

            title(app.UIAxes_SV_1, 'Max. Seitenkraft ueber V');
            xlabel(app.UIAxes_SV_1, 'V [m/s]'); ylabel(app.UIAxes_SV_1, 'FY_{max} [N]');
            title(app.UIAxes_SV_2, 'Max. Reibwert ueber V');
            xlabel(app.UIAxes_SV_2, 'V [m/s]'); ylabel(app.UIAxes_SV_2, '\mu_{y,max} [-]', 'Interpreter', 'tex');
            title(app.UIAxes_SV_3, 'Cornering-Stiffness ueber V');
            xlabel(app.UIAxes_SV_3, 'V [m/s]'); ylabel(app.UIAxes_SV_3, 'C_{Fy,\alpha} [N/deg]', 'Interpreter', 'tex');

            hold(app.UIAxes_SV_1, 'off'); hold(app.UIAxes_SV_2, 'off'); hold(app.UIAxes_SV_3, 'off');
        end

        function plot_rohdaten_explorer(app)
            % PLOT_ROHDATEN_EXPLORER Zeigt Rohdaten-Zeitverlaeufe aller Sweeps
            % fuer FZ und SA. Farbcodierung nach TestMethod.
            %
            % Autor: Lambo || Datum: 07.07.26

            if isempty(app.sweep)
                return
            end

            if isempty(app.SweepIsUsed)
                app.SweepIsUsed = true(size(app.sweep));
            end

            hide_unused = app.HideUnusedCheckBox.Value;

            method_colors = containers.Map( ...
                {'Lateral', 'Longitudinal', 'Combined', 'Undefined'}, ...
                {[0.78 0.13 0.16], [0.20 0.60 0.90], [0.90 0.70 0.10], [0.50 0.50 0.50]});

            app.clear_axes(app.UIAxes_RE_1); hold(app.UIAxes_RE_1, 'on');
            app.clear_axes(app.UIAxes_RE_2); hold(app.UIAxes_RE_2, 'on');

            for k = 1:numel(app.sweep)
                is_used = app.SweepIsUsed(k);
                if ~is_used && hide_unused
                    continue
                end

                s = app.sweep(k);
                sa_deg = rad2deg(s.alpha);
                fz_plot = s.Fz;
                method_str = char(s.TestMethod);

                if isKey(method_colors, method_str)
                    col = method_colors(method_str);
                else
                    col = [0.5 0.5 0.5];
                end
                if ~is_used
                    col = [0.4 0.4 0.4];
                end

                lw = 1.0 * is_used + 0.5 * ~is_used;
                plot(app.UIAxes_RE_1, s.et, fz_plot, 'Color', col, 'LineWidth', lw, 'HandleVisibility', 'off');
                plot(app.UIAxes_RE_2, s.et, sa_deg, 'Color', col, 'LineWidth', lw, 'HandleVisibility', 'off');

                if k > 1
                    xline(app.UIAxes_RE_1, s.et(1), '--', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off');
                    xline(app.UIAxes_RE_2, s.et(1), '--', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off');
                end
            end

            method_names = keys(method_colors);
            for m = 1:numel(method_names)
                plot(app.UIAxes_RE_1, NaN, NaN, 'Color', method_colors(method_names{m}), 'DisplayName', method_names{m});
            end

            title(app.UIAxes_RE_1, 'Normalkraft-Zeitverlauf');
            xlabel(app.UIAxes_RE_1, 'ET [s]'); ylabel(app.UIAxes_RE_1, 'FZ [N]');
            title(app.UIAxes_RE_2, 'Schraeglaufwinkel-Zeitverlauf');
            xlabel(app.UIAxes_RE_2, 'ET [s]'); ylabel(app.UIAxes_RE_2, 'SA [deg]');

            hold(app.UIAxes_RE_1, 'off'); hold(app.UIAxes_RE_2, 'off');
            legend(app.UIAxes_RE_1, 'show', 'Location', 'best');
        end

        function plot_manual_selection(app)
            % PLOT_MANUAL_SELECTION Zeigt alle Sweeps ueber der Zeit in drei
            % Kanal-Gruppen (Kraefte / Momente / Temperaturen). Ein Klick in
            % einen der drei Plots schaltet den manuellen Ausschluss
            % (app.ManualExclude) des betroffenen Sweeps um. Ueber den Filter
            % ausgeschlossene Sweeps (~app.FilterIsUsed) und manuell
            % ausgeschlossene Sweeps werden als rot-transparenter Hintergrund
            % markiert. Ueber die Checkbox ShowFilteredYellowCheckBox lassen
            % sich reine Filter-Ausschluesse zusaetzlich gelb hervorheben, um
            % sie von manuellen Ausschluessen zu unterscheiden.
            %
            % Autor: Lambo || Datum: 07.07.26

            if isempty(app.sweep)
                return
            end
            if isempty(app.FilterIsUsed)
                app.FilterIsUsed = true(size(app.sweep));
            end
            if isempty(app.ManualExclude)
                app.ManualExclude = false(size(app.sweep));
            end

            show_filtered_yellow = app.ShowFilteredYellowCheckBox.Value;

            axs = [app.UIAxes_MS_1, app.UIAxes_MS_2, app.UIAxes_MS_3];
            channel_groups = {{'Fx', 'Fy', 'Fz'}, {'Mx', 'My', 'Mz'}, {'TtreadI', 'TtreadC', 'TtreadO'}};
            line_colors = [0.85 0.20 0.20; 0.20 0.55 0.90; 0.20 0.75 0.35];
            titles_ms = {'Kraefte', 'Momente', 'Temperaturen'};
            ylabels_ms = {'Kraft [N]', 'Moment [Nm]', 'Temperatur [°C]'};

            for a = axs
                app.clear_axes(a); hold(a, 'on');
            end

            % Linienplots + Trennlinien je Kanal-Gruppe
            for g = 1:3
                a = axs(g);
                chans = channel_groups{g};

                for c = 1:numel(chans)
                    for k = 1:numel(app.sweep)
                        s = app.sweep(k);
                        y_raw = s.(chans{c});
                        y_plot = app.smooth_channel(s, chans{c}, y_raw);
                        plot(a, s.et, y_plot, 'Color', line_colors(c, :), 'LineWidth', 0.9, 'HitTest', 'off', 'HandleVisibility', 'off');
                    end
                    % Legendeneintrag (einmalig, ausserhalb der Sweep-Schleife)
                    plot(a, NaN, NaN, 'Color', line_colors(c, :), 'DisplayName', chans{c}, 'HitTest', 'off');
                end

                for k = 2:numel(app.sweep)
                    xline(a, app.sweep(k).et(1), '--', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off');
                end

                title(a, titles_ms{g});
                xlabel(a, 'ET [s]'); ylabel(a, ylabels_ms{g});
                legend(a, 'show', 'Location', 'best');

                % Klick auf die Achse aktiviert die Sweep-Auswahl
                a.ButtonDownFcn = createCallbackFcn(app, @ManualSelectAxesClicked, true);
            end

            % Ausschluss-Hintergrund je Sweep (hinter die Linien gelegt)
            for g = 1:3
                a = axs(g);
                yl = ylim(a);

                for k = 1:numel(app.sweep)
                    is_manual = app.ManualExclude(k);
                    is_filter_excluded = ~app.FilterIsUsed(k);

                    if is_manual
                        face_col = [0.85 0.10 0.10];
                    elseif is_filter_excluded
                        if show_filtered_yellow
                            face_col = [0.95 0.85 0.15];
                        else
                            face_col = [0.85 0.10 0.10];
                        end
                    else
                        continue
                    end

                    s = app.sweep(k);
                    t0 = s.et(1); t1 = s.et(end);

                    p = patch(a, [t0 t1 t1 t0], [yl(1) yl(1) yl(2) yl(2)], face_col, ...
                        'FaceAlpha', 0.28, 'EdgeColor', 'none', ...
                        'HitTest', 'off', 'PickableParts', 'none', 'HandleVisibility', 'off');
                    uistack(p, 'bottom');
                end
            end

            for a = axs
                hold(a, 'off');
            end

            % X-Achsen aller drei UIAxes synchronisieren (Zoom & Pan)
            axs = [app.UIAxes_MS_1, app.UIAxes_MS_2, app.UIAxes_MS_3];
            linkaxes(axs, 'x');

        end

        function updateDynamicYLimits(~, targetAxes)
            xLim = targetAxes.XLim;
            lines = findobj(targetAxes, 'Type', 'line'); % Sucht nur echte Datenlinien (ignoriert Patches)

            yMin = Inf;
            yMax = -Inf;

            for j = 1:length(lines)
                xData = lines(j).XData;
                yData = lines(j).YData;

                % Nur Datenpunkte innerhalb des aktuellen X-Sichtfelds
                inView = (xData >= xLim(1)) & (xData <= xLim(2));
                if any(inView)
                    yMin = min(yMin, min(yData(inView)));
                    yMax = max(yMax, max(yData(inView)));
                end
            end

            % Wenn gueltige Liniendaten im Sichtfeld sind, Achse neu skalieren (+20% Range)
            if isfinite(yMin) && isfinite(yMax)
                yRange = yMax - yMin;
                if yRange == 0, yRange = 1; end
                puffer = 0.10 * yRange; % 10% Puffer oben und unten

                targetAxes.YLim = [yMin - puffer, yMax + puffer];
            end
        end

        %% Achsen-Hilfsfunktion (Bugfix: alte Linie blieb nach Filtern sichtbar)

        function clear_axes(~, ax)
            % CLEAR_AXES Entfernt zuverlaessig ALLE Grafikobjekte (Linien,
            % Patches, Text-Annotationen) aus einer Achse - unabhaengig von
            % deren HandleVisibility-Eigenschaft.
            %
            % HINTERGRUND / BUGFIX:
            % cla(ax) loescht laut MATLAB-Dokumentation nur Objekte mit
            % HandleVisibility = 'on'. In dieser App werden praktisch alle
            % plot()/patch()-Aufrufe bewusst mit 'HandleVisibility','off'
            % erstellt (damit sie nicht einzeln in der Legende auftauchen).
            % Genau diese Objekte wurden von cla() daher NICHT entfernt -
            % nach dem Anwenden eines Filters/Smoothings blieb die alte,
            % ungefilterte Linie unsichtbar fuer die Legende, aber weiterhin
            % sichtbar im Plot, und die neue Linie wurde einfach darueber
            % gezeichnet. findall() (im Gegensatz zu findobj()) ignoriert
            % HandleVisibility und findet wirklich alle Kind-Objekte, die
            % dann explizit geloescht werden.
            %
            % Autor: Lambo || Datum: 08.07.26

            delete(findall(ax, 'Type', 'line'));
            delete(findall(ax, 'Type', 'patch'));
            delete(findall(ax, 'Type', 'text'));
            delete(findall(ax, 'Type', 'constantline')); % xline/yline
        end

        %% Filter Panel

        function param_list = get_filterable_parameters(app)
            % GET_FILTERABLE_PARAMETERS Liefert die Liste der fuer Bounds-Filter
            % verfuegbaren Messkanaele.
            %
            % Autor: Lambo || Datum: 07.07.26
            param_list = app.KNOWN_CHANNELS;
        end

        function build_filter_panel(app)
            % FilterPanel-Aufbau
            outerGrid = uigridlayout(app.FilterPanel, [3, 1]);
            outerGrid.RowHeight = {22, '1x', 22};

            app.FilterAddDropDown = uidropdown(outerGrid, ...
                'Items', [{'+ Parameter hinzufuegen'}, app.get_filterable_parameters()], ...
                'Value', '+ Parameter hinzufuegen');
            app.FilterAddDropDown.ValueChangedFcn = createCallbackFcn(app, @FilterAddDropDownValueChanged, true);

            app.FilterPanel = uipanel(outerGrid, 'Scrollable', 'on', 'BorderType', 'none');
            app.FilterRowsGrid = uigridlayout(app.FilterPanel, [1, 1]);
            app.FilterRowsGrid.RowHeight = {'fit'};
            app.FilterRowsGrid.RowSpacing = 4;

            app.HideUnusedCheckBox = uicheckbox(outerGrid, ...
                'Text', 'Ungenutzte Runs ausblenden', 'Value', true);
            app.HideUnusedCheckBox.ValueChangedFcn = createCallbackFcn(app, @HideUnusedCheckBoxValueChanged, true);
        end

        function FilterAddDropDownValueChanged(app, event)
            parameter = app.FilterAddDropDown.Value;
            if strcmp(parameter, '+ Parameter hinzufuegen')
                return
            end
            app.add_filter_row(parameter);
            app.FilterAddDropDown.Value = '+ Parameter hinzufuegen';
        end

        function add_filter_row(app, parameter)
            row_number = numel(app.FilterRows) + 1;
            app.FilterRowsGrid.RowHeight = repmat({'fit'}, 1, row_number);

            rowGrid = uigridlayout(app.FilterRowsGrid, [2, 4]);
            rowGrid.Layout.Row = row_number;
            rowGrid.RowHeight = {16, 22};
            rowGrid.ColumnWidth = {'1x', 55, 55, 22};
            rowGrid.Padding = [0 4 0 4];
            rowGrid.ColumnSpacing = 3;
            rowGrid.RowSpacing = 2;

            paramLabel = uilabel(rowGrid, 'Text', parameter, 'FontWeight', 'bold', 'FontSize', 9);
            paramLabel.Layout.Row = 1; paramLabel.Layout.Column = [1 3];
            delBtn = uibutton(rowGrid, 'push', 'Text', 'x');
            delBtn.Layout.Row = 1; delBtn.Layout.Column = 4;

            condDD = uidropdown(rowGrid, 'Items', ...
                {'Lowerbound (>=)', 'Upperbound (<=)', 'Bereich [min,max]', 'Gleich (==)', 'Ungleich (!=)'});
            condDD.Layout.Row = 2; condDD.Layout.Column = 1;

            val1 = uieditfield(rowGrid, 'numeric', 'Value', 0, 'Tooltip', 'Wert');
            val1.Layout.Row = 2; val1.Layout.Column = 2;

            val2 = uieditfield(rowGrid, 'numeric', 'Value', 0, 'Tooltip', 'bis', 'Visible', 'off');
            val2.Layout.Row = 2; val2.Layout.Column = 3;

            for ctrl = [condDD, val1, val2, delBtn]
                ctrl.UserData = row_number;
            end

            condDD.ValueChangedFcn = createCallbackFcn(app, @FilterRowChanged, true);
            val1.ValueChangedFcn = createCallbackFcn(app, @FilterRowChanged, true);
            val2.ValueChangedFcn = createCallbackFcn(app, @FilterRowChanged, true);
            delBtn.ButtonPushedFcn = createCallbackFcn(app, @FilterRowDeletePushed, true);

            new_row.Parameter = parameter;
            new_row.ParameterLabel = paramLabel;
            new_row.RowLayout = rowGrid;
            new_row.ConditionDropDown = condDD;
            new_row.Value1EditField = val1;
            new_row.Value2EditField = val2;
            new_row.DeleteButton = delBtn;

            app.FilterRows(row_number) = new_row;
            app.apply_filters();
        end

        function FilterRowChanged(app, event)
            row_idx = event.Source.UserData;
            row = app.FilterRows(row_idx);
            is_range = strcmp(row.ConditionDropDown.Value, 'Bereich [min,max]');
            row.Value2EditField.Visible = is_range;
            app.apply_filters();
        end

        function FilterRowDeletePushed(app, event)
            row_idx = event.Source.UserData;
            delete(app.FilterRows(row_idx).RowLayout);
            app.FilterRows(row_idx) = [];
            app.rebuild_filter_row_layout();
            app.apply_filters();
        end

        function rebuild_filter_row_layout(app)
            app.FilterRowsGrid.RowHeight = repmat({'fit'}, 1, numel(app.FilterRows));
            for k = 1:numel(app.FilterRows)
                row = app.FilterRows(k);
                row.RowLayout.Layout.Row = k;
                for ctrl = [row.ConditionDropDown, row.Value1EditField, row.Value2EditField, row.DeleteButton]
                    ctrl.UserData = k;
                end
            end
        end

        function apply_filters(app)
            % APPLY_FILTERS Wertet alle aktiven Filterzeilen (UND-Verknuepfung)
            % je Sweep aus und aktualisiert app.FilterIsUsed. Der manuelle
            % Ausschluss (app.ManualExclude) bleibt davon unberuehrt - beide
            % werden in update_combined_mask() zur effektiven Maske
            % app.SweepIsUsed zusammengefuehrt.
            %
            % Autor: Lambo || Datum: 07.07.26
            % Changelog:
            %   07.07.26 - Schreibt nun in FilterIsUsed statt SweepIsUsed und
            %              delegiert Refresh an update_combined_mask()

            if isempty(app.sweep)
                return
            end

            n = numel(app.sweep);
            used = true(n, 1);

            for k = 1:n
                s = app.sweep(k);
                for f = 1:numel(app.FilterRows)
                    row = app.FilterRows(f);
                    level = app.get_sweep_level(s, row.Parameter);
                    v1 = row.Value1EditField.Value;
                    v2 = row.Value2EditField.Value;

                    switch row.ConditionDropDown.Value
                        case 'Lowerbound (>=)', ok = level >= v1;
                        case 'Upperbound (<=)', ok = level <= v1;
                        case 'Bereich [min,max]', ok = level >= v1 && level <= v2;
                        case 'Gleich (==)', ok = level == v1;
                        case 'Ungleich (!=)', ok = level ~= v1;
                        otherwise, ok = true;
                    end

                    if ~ok
                        used(k) = false;
                        break
                    end
                end
            end

            app.FilterIsUsed = used;
            app.update_combined_mask();
        end

        function level = get_sweep_level(~, sweep, parameter)
            level = median(sweep.(parameter), 'omitnan');
        end

        function update_combined_mask(app)
            % UPDATE_COMBINED_MASK Kombiniert Filter-Ergebnis (FilterIsUsed) und
            % manuellen Ausschluss (ManualExclude) zur effektiven Nutzungsmaske
            % SweepIsUsed, die von ALLEN Plot-Funktionen der App konsultiert
            % wird. Ein manuell ausgeschlossener Sweep gilt damit fuer die
            % gesamte App als aussortiert. Triggert danach ein Neu-Zeichnen
            % aller Plots (Fix fuer den Refresh-Bug beim Smoothing/Filtern).
            %
            % Autor: Lambo || Datum: 07.07.26

            if isempty(app.sweep)
                return
            end
            if isempty(app.FilterIsUsed)
                app.FilterIsUsed = true(size(app.sweep));
            end
            if isempty(app.ManualExclude)
                app.ManualExclude = false(size(app.sweep));
            end

            app.SweepIsUsed = app.FilterIsUsed & ~app.ManualExclude;
            app.refresh_all_plots();
        end

        function refresh_all_plots(app)
            % REFRESH_ALL_PLOTS Zeichnet ALLE Plots der App neu. Zentrale
            % Stelle, die von Filter-, Smoothing- und manuellen
            % Auswahl-Aenderungen aufgerufen wird, damit keine Tabs mehr
            % veraltete Daten zeigen.
            %
            % Autor: Lambo || Datum: 07.07.26

            if isempty(app.sweep)
                return
            end

            % Neu Plotten
            app.plot_test_preprocessing();
            app.plot_cornering();
            app.plot_cornering_kennwerte();
            app.plot_camber_sweep();
            app.plot_drive_brake();
            app.plot_combined_slip();
            app.plot_cold_to_hot();
            app.plot_transient();
            app.plot_speed_vergleich();
            app.plot_rohdaten_explorer();
            app.plot_manual_selection();

            % Smoothing-Guetekriterium (R^2) neu berechnen
            app.update_smoothing_r2();
        end

        function idx = find_sweep_at_time(app, t)
            % FIND_SWEEP_AT_TIME Ermittelt den Index des Sweeps, dessen
            % ET-Bereich den Zeitpunkt t enthaelt. Fallback: naechstliegender
            % Sweep-Mittelpunkt, falls t exakt auf einer Luecke liegt.
            %
            % Autor: Lambo || Datum: 07.07.26

            idx = [];
            if isempty(app.sweep)
                return
            end

            for k = 1:numel(app.sweep)
                s = app.sweep(k);
                if t >= s.et(1) && t <= s.et(end)
                    idx = k;
                    return
                end
            end

            mids = arrayfun(@(s) (s.et(1) + s.et(end)) / 2, app.sweep);
            [~, idx] = min(abs(mids - t));
        end

        function ManualSelectAxesClicked(app, event)
            % MANUALSELECTAXESCLICKED Klick in einen der drei
            % Sweep-Auswahl-Plots: ermittelt den betroffenen Sweep ueber die
            % Klick-Zeit (ET) und schaltet dessen manuellen Ausschluss
            % (app.ManualExclude) um. Aktualisiert danach die
            % Sweep-Auswahl-Plots UND alle anderen Plots der App.
            %
            % Autor: Lambo || Datum: 07.07.26

            if isempty(app.sweep)
                return
            end

            t_click = event.IntersectionPoint(1);
            idx = app.find_sweep_at_time(t_click);
            if isempty(idx)
                return
            end

            if isempty(app.ManualExclude)
                app.ManualExclude = false(size(app.sweep));
            end

            app.ManualExclude(idx) = ~app.ManualExclude(idx);
            app.update_combined_mask();
        end

        function ShowFilteredYellowCheckBoxValueChanged(app, event)
            % SHOWFILTEREDYELLOWCHECKBOXVALUECHANGED Schaltet die gelbe
            % Sondermarkierung fuer rein filter-ausgeschlossene Sweeps im
            % Sweep-Auswahl-Tab um. Betrifft nur die Darstellung dieses
            % Tabs, nicht die effektive Nutzungsmaske.
            %
            % Autor: Lambo || Datum: 07.07.26
            if ~isempty(app.sweep)
                app.plot_manual_selection();
            end
        end

        %% Smooth Panel

        function build_smoothing_panel(app)
            outerGrid = uigridlayout(app.SmoothingPanel, [2, 1]);
            outerGrid.RowHeight = {22, '1x'};

            app.SmoothingAddDropDown = uidropdown(outerGrid, ...
                'Items', [{'+ Parameter hinzufuegen'}, app.get_filterable_parameters()], ...
                'Value', '+ Parameter hinzufuegen');
            app.SmoothingAddDropDown.ValueChangedFcn = createCallbackFcn(app, @SmoothingAddDropDownValueChanged, true);

            app.SmoothingPanel = uipanel(outerGrid, 'Scrollable', 'on', 'BorderType', 'none');
            app.SmoothingRowsGrid = uigridlayout(app.SmoothingPanel, [1, 1]);
            app.SmoothingRowsGrid.RowHeight = {'fit'};
            app.SmoothingRowsGrid.RowSpacing = 4;
        end

        function SmoothingAddDropDownValueChanged(app, event)
            parameter = app.SmoothingAddDropDown.Value;
            if strcmp(parameter, '+ Parameter hinzufuegen')
                return
            end
            app.add_smoothing_row(parameter);
            app.SmoothingAddDropDown.Value = '+ Parameter hinzufuegen';
        end

        function add_smoothing_row(app, parameter)
            row_number = numel(app.SmoothingRows) + 1;
            app.SmoothingRowsGrid.RowHeight = repmat({'fit'}, 1, row_number);

            rowGrid = uigridlayout(app.SmoothingRowsGrid, [5, 3]);
            rowGrid.Layout.Row = row_number;
            rowGrid.RowHeight = {16, 22, 22, 22, 16};
            rowGrid.ColumnWidth = {40, '1x', 22};
            rowGrid.Padding = [0 4 0 4];
            rowGrid.ColumnSpacing = 3;
            rowGrid.RowSpacing = 2;

            paramLabel = uilabel(rowGrid, 'Text', parameter, 'FontWeight', 'bold', 'FontSize', 9);
            paramLabel.Layout.Row = 1; paramLabel.Layout.Column = [1 2];
            delBtn = uibutton(rowGrid, 'push', 'Text', 'x');
            delBtn.Layout.Row = 1; delBtn.Layout.Column = 3;

            enabledBox = uicheckbox(rowGrid, 'Text', 'aktiv', 'Value', true);
            enabledBox.Layout.Row = 2; enabledBox.Layout.Column = 1;
            typeDD = uidropdown(rowGrid, 'Items', app.SMOOTHING_TYPES, 'Value', app.SMOOTHING_TYPES{1});
            typeDD.Layout.Row = 2; typeDD.Layout.Column = [2 3];

            param1Label = uilabel(rowGrid, 'Text', 'N', 'HorizontalAlignment', 'right', 'FontSize', 9);
            param1Label.Layout.Row = 3; param1Label.Layout.Column = 1;
            param1Edit = uieditfield(rowGrid, 'numeric', 'Value', 4);
            param1Edit.Layout.Row = 3; param1Edit.Layout.Column = [2 3];

            param2Label = uilabel(rowGrid, 'Text', 'fc [Hz]', 'HorizontalAlignment', 'right', 'FontSize', 9);
            param2Label.Layout.Row = 4; param2Label.Layout.Column = 1;
            param2Edit = uieditfield(rowGrid, 'numeric', 'Value', 5);
            param2Edit.Layout.Row = 4; param2Edit.Layout.Column = [2 3];

            r2Label = uilabel(rowGrid, 'Text', 'R^2: -', 'FontSize', 9, 'FontColor', [0.6 0.6 0.6], ...
                'HorizontalAlignment', 'right', 'Tooltip', ...
                'Guete/Aggressivitaet des Filters: R^2 zwischen Roh- und gefiltertem Signal (1 = keine Veraenderung, 0 = starke Glaettung)');
            r2Label.Layout.Row = 5; r2Label.Layout.Column = [1 3];

            for ctrl = [typeDD, enabledBox, param1Edit, param2Edit, delBtn]
                ctrl.UserData = row_number;
            end

            typeDD.ValueChangedFcn = createCallbackFcn(app, @SmoothingTypeChanged, true);
            enabledBox.ValueChangedFcn = createCallbackFcn(app, @SmoothingRowChanged, true);
            param1Edit.ValueChangedFcn = createCallbackFcn(app, @SmoothingRowChanged, true);
            param2Edit.ValueChangedFcn = createCallbackFcn(app, @SmoothingRowChanged, true);
            delBtn.ButtonPushedFcn = createCallbackFcn(app, @SmoothingRowDeletePushed, true);

            new_row.Parameter = parameter;
            new_row.RowLayout = rowGrid;
            new_row.TypeDropDown = typeDD;
            new_row.EnabledCheckBox = enabledBox;
            new_row.Param1Label = param1Label;
            new_row.Param1EditField = param1Edit;
            new_row.Param2Label = param2Label;
            new_row.Param2EditField = param2Edit;
            new_row.R2Label = r2Label;
            new_row.DeleteButton = delBtn;

            app.SmoothingRows(row_number) = new_row;
            app.update_smoothing_row_labels(new_row);
            app.refresh_plots_if_loaded();
        end

        function update_smoothing_row_labels(~, row)
            switch row.TypeDropDown.Value
                case 'Butterworth'
                    row.Param1Label.Text = 'Ordnung N';
                    row.Param2Label.Text = 'fc [Hz]';
                    row.Param2Label.Visible = 'on';
                    row.Param2EditField.Visible = 'on';
                case 'Bessel'
                    row.Param1Label.Text = 'Ordnung N';
                    row.Param2Label.Text = 'fc [Hz]';
                    row.Param2Label.Visible = 'on';
                    row.Param2EditField.Visible = 'on';
                case 'Savitzky-Golay'
                    row.Param1Label.Text = 'Ordnung';
                    row.Param2Label.Text = 'Fenster [Samples]';
                    row.Param2Label.Visible = 'on';
                    row.Param2EditField.Visible = 'on';
                case 'Moving Average'
                    row.Param1Label.Text = 'Fenster [Samples]';
                    row.Param2Label.Visible = 'off';
                    row.Param2EditField.Visible = 'off';
                case 'Median'
                    row.Param1Label.Text = 'Fenster [Samples]';
                    row.Param2Label.Visible = 'off';
                    row.Param2EditField.Visible = 'off';
                case 'Hampel (Despike)'
                    row.Param1Label.Text = 'Fenster K';
                    row.Param2Label.Text = 'n-Sigma';
                    row.Param2Label.Visible = 'on';
                    row.Param2EditField.Visible = 'on';
            end
        end

        function SmoothingTypeChanged(app, event)
            row_idx = event.Source.UserData;
            app.update_smoothing_row_labels(app.SmoothingRows(row_idx));
            app.refresh_plots_if_loaded();
        end

        function SmoothingRowChanged(app, event)
            app.refresh_plots_if_loaded();
        end

        function SmoothingRowDeletePushed(app, event)
            row_idx = event.Source.UserData;
            delete(app.SmoothingRows(row_idx).RowLayout);
            app.SmoothingRows(row_idx) = [];
            app.rebuild_smoothing_row_layout();
            app.refresh_plots_if_loaded();
        end

        function rebuild_smoothing_row_layout(app)
            app.SmoothingRowsGrid.RowHeight = repmat({'fit'}, 1, numel(app.SmoothingRowsGrid));
            for k = 1:numel(app.SmoothingRows)
                row = app.SmoothingRows(k);
                row.RowLayout.Layout.Row = k;
                for ctrl = [row.TypeDropDown, row.EnabledCheckBox, row.Param1EditField, row.Param2EditField, row.DeleteButton]
                    ctrl.UserData = k;
                end
            end
        end

        function refresh_plots_if_loaded(app)
            % REFRESH_PLOTS_IF_LOADED Triggert einen VOLLSTAENDIGEN Neu-Plot
            % aller Tabs, wenn bereits Daten geladen sind (z.B. nach Aenderung
            % einer Smoothing-Zeile).
            %
            % Autor: Lambo || Datum: 07.07.26
            % Changelog:
            %   07.07.26 - Ruft nun refresh_all_plots() statt nur 2 Plot-
            %              Funktionen auf (Fix: viele Tabs aktualisierten
            %              sich nach dem Smoothen nicht)

            if ~isempty(app.sweep)
                app.refresh_all_plots();
            end
        end

        % Eigentliches Smoothing
        function x_smooth = apply_smoothing(~, x, filter_type, param1, param2, fs)
            % APPLY_SMOOTHING Wendet den gewaehlten Filtertyp auf einen
            % Kanal-Vektor an.
            %
            % Autor: Lambo || Datum: 07.07.26
            % Changelog:
            %   08.07.26 - 'Butterworth' (echter zero-phase Tiefpass ueber
            %              butter()+filtfilt()) und 'Hampel (Despike)'
            %              (Ausreisser-/Spike-Entfernung ueber hampel())
            %              ergaenzt.

            x = x(:);
            n = numel(x);

            switch filter_type
                case 'Butterworth'
                    N = round(param1);
                    fc = param2;
                    if fc <= 0 || fc >= fs/2 || n < 3*(N+1)
                        x_smooth = x;
                        return
                    end
                    Wn = fc / (fs/2); % normierte Grenzfrequenz (0..1)
                    [b, a] = butter(N, Wn, 'low');
                    x_smooth = filtfilt(b, a, x);

                case 'Bessel'
                    N = round(param1);
                    fc = param2;
                    if fc <= 0 || fc >= fs/2 || n < 3*N
                        x_smooth = x;
                        return
                    end
                    Wn = 2*pi*fc;
                    [num, den] = besself(N, Wn);
                    [numd, dend] = bilinear(num, den, fs);
                    x_smooth = filtfilt(numd, dend, x);

                case 'Moving Average'
                    win = max(1, round(param1));
                    x_smooth = movmean(x, win);

                case 'Savitzky-Golay'
                    order = round(param1);
                    win = round(param2);
                    if mod(win, 2) == 0
                        win = win + 1;
                    end
                    win = max(win, order + 1 + mod(order + 1, 2));
                    if n <= win
                        x_smooth = x;
                        return
                    end
                    x_smooth = sgolayfilt(x, order, win);

                case 'Median'
                    win = round(param1);
                    if mod(win, 2) == 0
                        win = win + 1;
                    end
                    x_smooth = medfilt1(x, win);

                case 'Hampel (Despike)'
                    % Reine Ausreisser-/Spike-Entfernung (z.B. fuer MZ-Glitches),
                    % KEIN generelles Glaetten. Ersetzt nur Punkte, die mehr als
                    % n-Sigma vom lokalen Median abweichen, durch den lokalen
                    % Median. Empfohlen als erste Stufe VOR einem Butterworth-
                    % Tiefpass (separate Smoothing-Zeile), damit Spikes nicht
                    % in die Nachbarschaft verschmiert werden.
                    win = max(1, round(param1));
                    nsigma = param2;
                    if nsigma <= 0
                        nsigma = 3;
                    end
                    if n <= 2*win
                        x_smooth = x;
                        return
                    end
                    x_smooth = hampel(x, win, nsigma);

                otherwise
                    x_smooth = x;
            end
        end

        function row = get_smoothing_row_for_parameter(app, parameter)
            row = [];
            for k = 1:numel(app.SmoothingRows)
                if strcmp(app.SmoothingRows(k).Parameter, parameter) && ...
                        app.SmoothingRows(k).EnabledCheckBox.Value
                    row = app.SmoothingRows(k);
                    return
                end
            end
        end

        function y_out = smooth_channel(app, s, parameter, y_raw)
            row = app.get_smoothing_row_for_parameter(parameter);
            if isempty(row)
                y_out = y_raw;
                return
            end
            fs = 1 / median(diff(s.et), 'omitnan');
            y_out = app.apply_smoothing(y_raw, row.TypeDropDown.Value, ...
                row.Param1EditField.Value, row.Param2EditField.Value, fs);
        end

        function update_smoothing_r2(app)
            % UPDATE_SMOOTHING_R2 Berechnet fuer jede aktive Smoothing-Zeile
            % ein R^2-Guetemass zwischen Roh- und gefiltertem Signal (ueber
            % alle aktuell genutzten Sweeps hinweg gepoolt) und schreibt es
            % in das zugehoerige R2Label. Dient als Kennzahl dafuer, wie
            % "aggressiv" ein Filter/Smoothing eingreift:
            %   R^2 nahe 1  -> Filter veraendert das Signal kaum
            %   R^2 nahe 0  -> Filter veraendert das Signal stark
            % Formel: R^2 = 1 - SS_res / SS_tot, mit
            %   SS_res = sum((roh - gefiltert)^2)
            %   SS_tot = sum((roh - mean(roh))^2)
            %
            % Autor: Lambo || Datum: 08.07.26

            if isempty(app.sweep) || isempty(app.SmoothingRows)
                return
            end

            for r = 1:numel(app.SmoothingRows)
                row = app.SmoothingRows(r);
                param = row.Parameter;

                if ~row.EnabledCheckBox.Value
                    row.R2Label.Text = 'R^2: -';
                    row.R2Label.FontColor = [0.6 0.6 0.6];
                    continue
                end

                y_raw_all = [];
                y_smooth_all = [];

                for k = 1:numel(app.sweep)
                    s = app.sweep(k);
                    y_raw = s.(param);
                    fs = 1 / median(diff(s.et), 'omitnan');
                    y_smooth = app.apply_smoothing(y_raw, row.TypeDropDown.Value, ...
                        row.Param1EditField.Value, row.Param2EditField.Value, fs);

                    y_raw_all = [y_raw_all; y_raw(:)]; %#ok<AGROW>
                    y_smooth_all = [y_smooth_all; y_smooth(:)]; %#ok<AGROW>
                end

                valid = ~isnan(y_raw_all) & ~isnan(y_smooth_all);
                if nnz(valid) < 2
                    row.R2Label.Text = 'R^2: -';
                    row.R2Label.FontColor = [0.6 0.6 0.6];
                    continue
                end

                y_raw_v = y_raw_all(valid);
                y_smooth_v = y_smooth_all(valid);

                ss_res = sum((y_raw_v - y_smooth_v).^2);
                ss_tot = sum((y_raw_v - mean(y_raw_v)).^2);

                if ss_tot <= eps
                    r2 = 1;
                else
                    r2 = 1 - ss_res / ss_tot;
                end
                r2 = max(min(r2, 1), 0); % numerisch auf [0,1] clampen

                if r2 >= 0.95
                    col = [0.35 0.75 0.35]; % gruen: kaum Eingriff
                elseif r2 >= 0.8
                    col = [0.90 0.70 0.10]; % gelb: moderat
                else
                    col = [0.85 0.20 0.20]; % rot: aggressiv
                end

                row.R2Label.Text = sprintf('R^2: %.3f', r2);
                row.R2Label.FontColor = col;
            end
        end

        %% Frequenzanalyse-Tab

        function populate_fa_sweep_dropdown(app)
            % POPULATE_FA_SWEEP_DROPDOWN Befuellt die Sweep-Auswahl im
            % Frequenzanalyse-Tab nach dem Laden neuer Reifendaten.
            %
            % Autor: Lambo || Datum: 08.07.26

            if isempty(app.sweep)
                app.FA_SweepDropDown.Items = {};
                return
            end

            items = strings(1, numel(app.sweep));
            for k = 1:numel(app.sweep)
                s = app.sweep(k);
                fz = median(s.Fz, 'omitnan');
                items(k) = sprintf('%d: %s (FZ~%.0fN, %.1fs)', k, char(s.TestMethod), fz, s.et(end)-s.et(1));
            end
            app.FA_SweepDropDown.Items = cellstr(items);
            app.FA_SweepDropDown.ItemsData = 1:numel(app.sweep);
            app.FA_SweepDropDown.Value = 1;
        end

        function FA_AnalyzeButtonPushed(app, event)
            % FA_ANALYZEBUTTONPUSHED Fuehrt fuer den gewaehlten Sweep/Kanal
            % eine FFT-Analyse durch: identifiziert die Sweep-Grundfrequenz
            % (aus SA), die Radrotationsfrequenz (aus omega) und die
            % dominante Ripple-Frequenz oberhalb der Grundfrequenz im
            % gewaehlten Kraft-/Momentkanal. Daraus wird ein Cutoff-Vorschlag
            % fuer einen Butterworth-Tiefpass abgeleitet und als Vorschau
            % (roh vs. Vorschlag) geplottet.
            %
            % Autor: Lambo || Datum: 08.07.26

            if isempty(app.sweep)
                uialert(app.UIFigure, 'Bitte zuerst Reifendaten laden.', 'Keine Daten');
                return
            end

            idx = app.FA_SweepDropDown.Value;
            chan = app.FA_ChannelDropDown.Value;

            s = app.sweep(idx);
            t = s.et(:);
            y = s.(chan);
            y = y(:);

            fs = 1 / median(diff(t), 'omitnan');
            n = numel(y);
            if n < 16
                uialert(app.UIFigure, 'Sweep zu kurz fuer eine sinnvolle FFT-Analyse.', 'Zu wenig Daten');
                return
            end

            % --- FFT des gewaehlten Kanals ---
            y_dc = y - mean(y, 'omitnan');
            Y = fft(y_dc);
            halfN = floor(n/2);
            f = (0:halfN-1) * (fs/n);
            amp = abs(Y(1:halfN)) / n * 2;

            % --- Sweep-Grundfrequenz ueber SA-Spektrum ---
            sa = s.alpha(:) - mean(s.alpha, 'omitnan');
            if numel(sa) ~= n
                m = min(numel(sa), n);
                sa = sa(1:m);
            end
            Ysa = fft(sa, n);
            amp_sa = abs(Ysa(1:halfN));
            if numel(amp_sa) > 2
                [~, idx_fund] = max(amp_sa(2:end));
                f_fund = f(idx_fund + 1);
            else
                f_fund = f(1);
            end
            if f_fund <= 0
                f_fund = fs / n; % Fallback: kleinste aufloesbare Frequenz
            end

            % --- Radrotationsfrequenz (omega ist bereits in U/s = Hz) ---
            f_rot = mean(s.omega, 'omitnan');

            % --- Ripple-Peak oberhalb der 3-fachen Grundfrequenz suchen ---
            mask_search = f > 3 * f_fund;
            f_search = f(mask_search);
            amp_search = amp(mask_search);
            f_ripple = NaN;
            if numel(amp_search) > 3
                [~, loc] = findpeaks(amp_search, 'SortStr', 'descend', 'NPeaks', 1);
                if ~isempty(loc)
                    f_ripple = f_search(loc(1));
                end
            end

            % --- Cutoff-Vorschlag ableiten ---
            if ~isnan(f_ripple) && f_ripple > f_fund
                f_cut_suggest = sqrt(max(f_fund * 5, fs/n) * (f_ripple * 0.5));
                f_cut_suggest = min(f_cut_suggest, f_ripple * 0.8);
                f_cut_suggest = max(f_cut_suggest, f_fund * 3);
            else
                f_cut_suggest = min(f_fund * 8, fs/2 * 0.9); % Fallback ohne klaren Ripple-Peak
            end

            app.FA_LastCutoffSuggestion = f_cut_suggest;
            app.FA_LastChannel = chan;

            % --- Zeitsignal-Plot: Roh vs. Cutoff-Vorschlag (Butterworth N=4) ---
            app.clear_axes(app.UIAxes_FA_Time); hold(app.UIAxes_FA_Time, 'on');
            y_test = app.apply_smoothing(y, 'Butterworth', 4, f_cut_suggest, fs);
            plot(app.UIAxes_FA_Time, t, y, 'Color', [0.55 0.55 0.55], 'LineWidth', 0.8, 'DisplayName', 'Roh');
            plot(app.UIAxes_FA_Time, t, y_test, 'Color', [0.78 0.13 0.16], 'LineWidth', 1.4, ...
                'DisplayName', sprintf('Vorschlag fc = %.2f Hz', f_cut_suggest));
            hold(app.UIAxes_FA_Time, 'off');
            legend(app.UIAxes_FA_Time, 'show', 'Location', 'best');
            title(app.UIAxes_FA_Time, sprintf('Zeitsignal - Sweep #%d, %s', idx, chan));
            xlabel(app.UIAxes_FA_Time, 'ET [s]'); ylabel(app.UIAxes_FA_Time, chan);

            % --- Spektrum-Plot mit markierten Frequenzen ---
            app.clear_axes(app.UIAxes_FA_Spec); hold(app.UIAxes_FA_Spec, 'on');
            plot(app.UIAxes_FA_Spec, f, amp, 'Color', [0.20 0.55 0.90], 'DisplayName', 'Spektrum');
            xline(app.UIAxes_FA_Spec, f_fund, '--', 'Color', [0.20 0.75 0.35], 'LineWidth', 1.2, ...
                'Label', 'Sweep-Grundfrequenz', 'LabelOrientation', 'horizontal');
            if f_rot > 0 && f_rot < fs/2
                xline(app.UIAxes_FA_Spec, f_rot, '--', 'Color', [0.90 0.70 0.10], 'LineWidth', 1.2, ...
                    'Label', 'Radrotation', 'LabelOrientation', 'horizontal');
            end
            if ~isnan(f_ripple)
                xline(app.UIAxes_FA_Spec, f_ripple, '--', 'Color', [0.78 0.13 0.16], 'LineWidth', 1.2, ...
                    'Label', 'Ripple', 'LabelOrientation', 'horizontal');
            end
            xline(app.UIAxes_FA_Spec, f_cut_suggest, '-', 'Color', [1 1 1], 'LineWidth', 1.6, ...
                'Label', 'Cutoff-Vorschlag', 'LabelOrientation', 'horizontal');
            hold(app.UIAxes_FA_Spec, 'off');
            title(app.UIAxes_FA_Spec, 'Amplitudenspektrum');
            xlabel(app.UIAxes_FA_Spec, 'Frequenz [Hz]'); ylabel(app.UIAxes_FA_Spec, 'Amplitude');

            if ~isnan(f_ripple)
                xlim_max = min(fs/2, f_ripple * 3);
            else
                xlim_max = min(fs/2, f_fund * 30);
            end
            if xlim_max > 0
                xlim(app.UIAxes_FA_Spec, [0, xlim_max]);
            end

            % --- Ergebnis-Text ---
            rot_str = sprintf('%.3f Hz', f_rot);
            if isnan(f_ripple)
                ripple_str = 'kein klarer Peak gefunden';
            else
                ripple_str = sprintf('%.3f Hz', f_ripple);
            end

            app.FA_ResultLabel.Text = sprintf([ ...
                'Sweep-Grundfrequenz:   %.3f Hz\n' ...
                'Radrotationsfrequenz:  %s\n' ...
                'Ripple-Frequenz:       %s\n' ...
                'Cutoff-Vorschlag:      %.2f Hz'], ...
                f_fund, rot_str, ripple_str, f_cut_suggest);
        end

        function FA_ApplyCutoffButtonPushed(app, event)
            % FA_APPLYCUTOFFBUTTONPUSHED Uebernimmt den zuletzt ermittelten
            % Cutoff-Vorschlag als Butterworth-Tiefpass (Ordnung 4) in eine
            % Smoothing-Zeile fuer den analysierten Kanal - legt die Zeile
            % an, falls noch keine existiert, sonst wird die bestehende
            % aktualisiert.
            %
            % Autor: Lambo || Datum: 08.07.26

            if isnan(app.FA_LastCutoffSuggestion) || isempty(app.FA_LastChannel)
                uialert(app.UIFigure, 'Bitte zuerst eine Analyse durchfuehren.', 'Kein Vorschlag');
                return
            end

            row = [];
            for k = 1:numel(app.SmoothingRows)
                if strcmp(app.SmoothingRows(k).Parameter, app.FA_LastChannel)
                    row = app.SmoothingRows(k);
                    break
                end
            end

            if isempty(row)
                app.add_smoothing_row(app.FA_LastChannel);
                row = app.SmoothingRows(end);
            end

            row.TypeDropDown.Value = 'Butterworth';
            row.EnabledCheckBox.Value = true;
            row.Param1EditField.Value = 4;
            row.Param2EditField.Value = round(app.FA_LastCutoffSuggestion, 2);
            app.update_smoothing_row_labels(row);

            app.refresh_plots_if_loaded();
        end

    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)

            clc
            build_filter_panel(app)
            build_smoothing_panel(app)

        end

        % Button pushed function: LoadTireDataButton
        function LoadTireDataButtonPushed(app, event)

            % LOADTIREDATABUTTONPUSHED Laedt die Reifentestdaten und zeichnet
            % danach ALLE Plots ueber den zentralen refresh_all_plots()-Pfad
            % neu.
            %
            % Autor: Lambo || Datum: 07.07.26
            % Changelog:
            %   07.07.26 - Einzelne Plot-Aufrufe durch refresh_all_plots()
            %              ersetzt (inkl. neuem Sweep-Auswahl-Tab)

            load_Tire_Data(app)
            app.refresh_all_plots();

        end

        % Button pushed function: OpenDirectoryButton
        function OpenDirectoryButtonPushed(app, event)

            [file,location] = uigetfile;
            tire_file_from_button = fullfile(location, file);
            app.Test_file_directroy.Value = tire_file_from_button;
       
        end

        % Value changed function: HideUnusedCheckBox
        function HideUnusedCheckBoxValueChanged(app, event)
            % HIDEUNUSEDCHECKBOXVALUECHANGED Schaltet um zwischen "gefilterte/
            % ausgeschlossene Sweeps ausgrauen" und "komplett ausblenden".
            % Triggert einen vollstaendigen Neu-Plot aller Tabs.
            %
            % Autor: Lambo || Datum: 07.07.26
            % Changelog:
            %   07.07.26 - Ruft refresh_all_plots() statt nur 2 Plot-
            %              Funktionen auf

            if ~isempty(app.sweep)
                app.refresh_all_plots();
            end

        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [0 100 768 556];
            app.UIFigure.Name = 'MATLAB App';

            % Create TabGroup2
            app.TabGroup2 = uitabgroup(app.UIFigure);
            app.TabGroup2.Position = [129 1 640 430];

            % Create TestPreprocessingTab
            app.TestPreprocessingTab = uitab(app.TabGroup2);
            app.TestPreprocessingTab.Title = 'Test-Preprocessing';

            % Create UIAxes_Pneu
            app.UIAxes_Pneu = uiaxes(app.TestPreprocessingTab);
            title(app.UIAxes_Pneu, 'Pneumatic Trail')
            xlabel(app.UIAxes_Pneu, 'Schräglaufwinkel SA [deg]')
            ylabel(app.UIAxes_Pneu, 't_p = -MZ / FY [m]')
            zlabel(app.UIAxes_Pneu, 'Z')
            app.UIAxes_Pneu.Position = [2 3 639 133];

            % Create UIAxes_Mu
            app.UIAxes_Mu = uiaxes(app.TestPreprocessingTab);
            title(app.UIAxes_Mu, 'Normierte Reibwertkurve')
            xlabel(app.UIAxes_Mu, 'Schräglaufwinkel SA [deg]')
            ylabel(app.UIAxes_Mu, '\mu_y = FY / |FZ| [-]')
            zlabel(app.UIAxes_Mu, 'Z')
            app.UIAxes_Mu.Position = [0 139 639 133];

            % Create UIAxes_Sweep
            app.UIAxes_Sweep = uiaxes(app.TestPreprocessingTab);
            title(app.UIAxes_Sweep, 'Rohdatenverlauf mit Sweep-Grenzen')
            xlabel(app.UIAxes_Sweep, 'Zeit ET [s]')
            ylabel(app.UIAxes_Sweep, 'Seitenkraft FY [N]')
            zlabel(app.UIAxes_Sweep, 'Z')
            app.UIAxes_Sweep.Position = [1 275 639 133];

            % Create CorneringTab_2
            app.CorneringTab_2 = uitab(app.TabGroup2);
            app.CorneringTab_2.Title = 'Cornering';

            % Create UIAxes_3
            app.UIAxes_3 = uiaxes(app.CorneringTab_2);
            title(app.UIAxes_3, 'Sturtzmoment / Schräglaufwinkel')
            xlabel(app.UIAxes_3, 'Schräglaufwinkel')
            ylabel(app.UIAxes_3, 'Sturtzmoment Mx [Nm]')
            zlabel(app.UIAxes_3, 'Z')
            app.UIAxes_3.Position = [2 3 639 133];

            % Create UIAxes_2
            app.UIAxes_2 = uiaxes(app.CorneringTab_2);
            title(app.UIAxes_2, 'Title')
            xlabel(app.UIAxes_2, 'Rückstellmoment MZ [Nm]')
            ylabel(app.UIAxes_2, 'Schräglaufwinkel SA [deg]')
            zlabel(app.UIAxes_2, 'Z')
            app.UIAxes_2.Position = [0 139 639 133];

            % Create UIAxes
            app.UIAxes = uiaxes(app.CorneringTab_2);
            title(app.UIAxes, 'Seitenkraft / Schräglaufwinkel')
            xlabel(app.UIAxes, 'Schraglaufwinkel SA [deg]')
            ylabel(app.UIAxes, 'Seitenkraft FY [N]')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.Position = [1 275 639 133];

            % Create CorneringKennwerteTab_2
            app.CorneringKennwerteTab_2 = uitab(app.TabGroup2);
            app.CorneringKennwerteTab_2.Title = 'Cornering Kennwerte';

            % Create UIAxes_CK_3
            app.UIAxes_CK_3 = uiaxes(app.CorneringKennwerteTab_2);
            title(app.UIAxes_CK_3, 'Cornering-Stiffness')
            xlabel(app.UIAxes_CK_3, 'FZ [N]')
            ylabel(app.UIAxes_CK_3, 'C_{Fy,\alpha} [N/deg]')
            zlabel(app.UIAxes_CK_3, 'Z')
            app.UIAxes_CK_3.Position = [2 3 639 133];

            % Create UIAxes_CK_2
            app.UIAxes_CK_2 = uiaxes(app.CorneringKennwerteTab_2);
            title(app.UIAxes_CK_2, 'Max. Reibwert')
            xlabel(app.UIAxes_CK_2, 'FZ [N]')
            ylabel(app.UIAxes_CK_2, '\mu_{y,max}')
            zlabel(app.UIAxes_CK_2, 'Z')
            app.UIAxes_CK_2.Position = [0 139 639 133];

            % Create UIAxes_CK_1
            app.UIAxes_CK_1 = uiaxes(app.CorneringKennwerteTab_2);
            title(app.UIAxes_CK_1, 'Max. Seitenkraft')
            xlabel(app.UIAxes_CK_1, 'FZ [N]')
            ylabel(app.UIAxes_CK_1, 'FY_{max} [N]')
            zlabel(app.UIAxes_CK_1, 'Z')
            app.UIAxes_CK_1.Position = [1 275 639 133];

            % Create CamberSweepTab_2
            app.CamberSweepTab_2 = uitab(app.TabGroup2);
            app.CamberSweepTab_2.Title = 'Camber Sweep';

            % Create UIAxes_Cam_3
            app.UIAxes_Cam_3 = uiaxes(app.CamberSweepTab_2);
            title(app.UIAxes_Cam_3, 'Sturzmoment / Schräglaufwinkel')
            xlabel(app.UIAxes_Cam_3, 'SA [deg]')
            ylabel(app.UIAxes_Cam_3, 'MX [Nm]')
            zlabel(app.UIAxes_Cam_3, 'Z')
            app.UIAxes_Cam_3.Position = [2 3 639 133];

            % Create UIAxes_Cam_2
            app.UIAxes_Cam_2 = uiaxes(app.CamberSweepTab_2);
            title(app.UIAxes_Cam_2, 'Rückstellmoment / Schräglaufwinkel')
            xlabel(app.UIAxes_Cam_2, 'SA [deg]')
            ylabel(app.UIAxes_Cam_2, 'MZ [Nm]')
            zlabel(app.UIAxes_Cam_2, 'Z')
            app.UIAxes_Cam_2.Position = [0 139 639 133];

            % Create UIAxes_Cam_1
            app.UIAxes_Cam_1 = uiaxes(app.CamberSweepTab_2);
            title(app.UIAxes_Cam_1, 'Seitenkraft / Schräglaufwinkel')
            xlabel(app.UIAxes_Cam_1, 'SA [deg]')
            ylabel(app.UIAxes_Cam_1, 'FY [N]')
            zlabel(app.UIAxes_Cam_1, 'Z')
            app.UIAxes_Cam_1.Position = [1 275 639 133];

            % Create DriveBrakeTab_2
            app.DriveBrakeTab_2 = uitab(app.TabGroup2);
            app.DriveBrakeTab_2.Title = 'Drive/Brake';

            % Create UIAxes_DB_3
            app.UIAxes_DB_3 = uiaxes(app.DriveBrakeTab_2);
            title(app.UIAxes_DB_3, 'Seitenkraft / Längsschlupf')
            xlabel(app.UIAxes_DB_3, '\kappa [-]')
            ylabel(app.UIAxes_DB_3, 'FY [N]')
            zlabel(app.UIAxes_DB_3, 'Z')
            app.UIAxes_DB_3.Position = [2 3 639 133];

            % Create UIAxes_DB_2
            app.UIAxes_DB_2 = uiaxes(app.DriveBrakeTab_2);
            title(app.UIAxes_DB_2, 'Rückstellmoment / Längsschlupf')
            xlabel(app.UIAxes_DB_2, '\kappa [-]')
            ylabel(app.UIAxes_DB_2, 'MZ [Nm]')
            zlabel(app.UIAxes_DB_2, 'Z')
            app.UIAxes_DB_2.Position = [0 139 639 133];

            % Create UIAxes_DB_1
            app.UIAxes_DB_1 = uiaxes(app.DriveBrakeTab_2);
            title(app.UIAxes_DB_1, 'Längskraft / Längsschlupf')
            xlabel(app.UIAxes_DB_1, '\kappa [-]')
            ylabel(app.UIAxes_DB_1, 'FX [N]')
            zlabel(app.UIAxes_DB_1, 'Z')
            app.UIAxes_DB_1.Position = [1 275 639 133];

            % Create CombinedSlipTab_2
            app.CombinedSlipTab_2 = uitab(app.TabGroup2);
            app.CombinedSlipTab_2.Title = 'Combined Slip';

            % Create UIAxes_CS_2
            app.UIAxes_CS_2 = uiaxes(app.CombinedSlipTab_2);
            title(app.UIAxes_CS_2, 'Seitenkraft / Schräglaufwinkel (Combined)')
            xlabel(app.UIAxes_CS_2, 'SA [deg]')
            ylabel(app.UIAxes_CS_2, 'FY [N]')
            zlabel(app.UIAxes_CS_2, 'Z')
            app.UIAxes_CS_2.Position = [0 139 639 133];

            % Create UIAxes_CS_1
            app.UIAxes_CS_1 = uiaxes(app.CombinedSlipTab_2);
            title(app.UIAxes_CS_1, 'Längskraft / Längsschlupf (Combined)')
            xlabel(app.UIAxes_CS_1, '\kappa [-]')
            ylabel(app.UIAxes_CS_1, 'FX [N]')
            zlabel(app.UIAxes_CS_1, 'Z')
            app.UIAxes_CS_1.Position = [1 275 639 133];

            % Create ColdtohotVerschleissTab
            app.ColdtohotVerschleissTab = uitab(app.TabGroup2);
            app.ColdtohotVerschleissTab.Title = 'Cold-to-hot / Verschleiss';

            % Create UIAxes_CH_2
            app.UIAxes_CH_2 = uiaxes(app.ColdtohotVerschleissTab);
            title(app.UIAxes_CH_2, 'Cornering-Stiffness über Temperatur')
            xlabel(app.UIAxes_CH_2, 'T_{tread,C} [°C]')
            ylabel(app.UIAxes_CH_2, 'C_{Fy,\alpha} [N/deg]')
            zlabel(app.UIAxes_CH_2, 'Z')
            app.UIAxes_CH_2.Position = [0 139 639 133];

            % Create UIAxes_CH_1
            app.UIAxes_CH_1 = uiaxes(app.ColdtohotVerschleissTab);
            title(app.UIAxes_CH_1, '''Max. Reibwert über Temperatur''')
            xlabel(app.UIAxes_CH_1, 'T_{tread,C} [°C]')
            ylabel(app.UIAxes_CH_1, '\mu_{y,max} [-]')
            zlabel(app.UIAxes_CH_1, 'Z')
            app.UIAxes_CH_1.Position = [1 275 639 133];

            % Create TransientTab_2
            app.TransientTab_2 = uitab(app.TabGroup2);
            app.TransientTab_2.Title = 'Transient';

            % Create UIAxes_TR_2
            app.UIAxes_TR_2 = uiaxes(app.TransientTab_2);
            title(app.UIAxes_TR_2, 'Seitenkraft-Zeitverlauf')
            xlabel(app.UIAxes_TR_2, 'ET [s]')
            ylabel(app.UIAxes_TR_2, 'FY [N]')
            zlabel(app.UIAxes_TR_2, 'Z')
            app.UIAxes_TR_2.Position = [0 139 639 133];

            % Create UIAxes_TR_1
            app.UIAxes_TR_1 = uiaxes(app.TransientTab_2);
            title(app.UIAxes_TR_1, 'Schräglaufwinkel-Zeitverlauf')
            xlabel(app.UIAxes_TR_1, 'ET [s]')
            ylabel(app.UIAxes_TR_1, 'SA [deg]')
            zlabel(app.UIAxes_TR_1, 'Z')
            app.UIAxes_TR_1.Position = [1 275 639 133];

            % Create SpeedVergleichTab_2
            app.SpeedVergleichTab_2 = uitab(app.TabGroup2);
            app.SpeedVergleichTab_2.Title = 'Speed-Vergleich';

            % Create UIAxes_SV_3
            app.UIAxes_SV_3 = uiaxes(app.SpeedVergleichTab_2);
            title(app.UIAxes_SV_3, 'Cornering-Stiffness über V')
            xlabel(app.UIAxes_SV_3, 'V [m/s]')
            ylabel(app.UIAxes_SV_3, 'C_{Fy,\alpha} [N/deg]')
            zlabel(app.UIAxes_SV_3, 'Z')
            app.UIAxes_SV_3.Position = [2 3 639 133];

            % Create UIAxes_SV_2
            app.UIAxes_SV_2 = uiaxes(app.SpeedVergleichTab_2);
            title(app.UIAxes_SV_2, 'Max. Reibwert über V')
            xlabel(app.UIAxes_SV_2, 'V [m/s]')
            ylabel(app.UIAxes_SV_2, '\mu_{y,max} [-]')
            zlabel(app.UIAxes_SV_2, 'Z')
            app.UIAxes_SV_2.Position = [0 139 639 133];

            % Create UIAxes_SV_1
            app.UIAxes_SV_1 = uiaxes(app.SpeedVergleichTab_2);
            title(app.UIAxes_SV_1, 'Max. Seitenkraft über V')
            xlabel(app.UIAxes_SV_1, 'V [m/s]')
            ylabel(app.UIAxes_SV_1, 'FY_{max} [N]')
            zlabel(app.UIAxes_SV_1, 'Z')
            app.UIAxes_SV_1.Position = [1 275 639 133];

            % Create RohdatenExplorerTab_2
            app.RohdatenExplorerTab_2 = uitab(app.TabGroup2);
            app.RohdatenExplorerTab_2.Title = 'Rohdaten Explorer';

            % Create UIAxes_RE_2
            app.UIAxes_RE_2 = uiaxes(app.RohdatenExplorerTab_2);
            title(app.UIAxes_RE_2, 'Schräglaufwinkel-Zeitverlauf')
            xlabel(app.UIAxes_RE_2, 'ET [s]')
            ylabel(app.UIAxes_RE_2, 'SA [deg]')
            zlabel(app.UIAxes_RE_2, 'Z')
            app.UIAxes_RE_2.Position = [0 139 639 133];

            % Create UIAxes_RE_1
            app.UIAxes_RE_1 = uiaxes(app.RohdatenExplorerTab_2);
            title(app.UIAxes_RE_1, 'Normalkraft-Zeitverlauf')
            xlabel(app.UIAxes_RE_1, 'ET [s]')
            ylabel(app.UIAxes_RE_1, 'FZ [N]')
            zlabel(app.UIAxes_RE_1, 'Z')
            app.UIAxes_RE_1.Position = [1 275 639 133];

            % Create ManuelSelctionTab
            app.ManuelSelctionTab = uitab(app.TabGroup2);
            app.ManuelSelctionTab.Title = 'Manuel Selction';

            % Create UIAxes_MS_3
            app.UIAxes_MS_3 = uiaxes(app.ManuelSelctionTab);
            title(app.UIAxes_MS_3, 'Seitenkraft / Längsschlupf')
            xlabel(app.UIAxes_MS_3, '\kappa [-]')
            ylabel(app.UIAxes_MS_3, 'FY [N]')
            zlabel(app.UIAxes_MS_3, 'Z')
            app.UIAxes_MS_3.Position = [2 3 639 133];

            % Create UIAxes_MS_2
            app.UIAxes_MS_2 = uiaxes(app.ManuelSelctionTab);
            title(app.UIAxes_MS_2, 'Rückstellmoment / Längsschlupf')
            xlabel(app.UIAxes_MS_2, '\kappa [-]')
            ylabel(app.UIAxes_MS_2, 'MZ [Nm]')
            zlabel(app.UIAxes_MS_2, 'Z')
            app.UIAxes_MS_2.Position = [0 139 639 133];

            % Create UIAxes_MS_1
            app.UIAxes_MS_1 = uiaxes(app.ManuelSelctionTab);
            title(app.UIAxes_MS_1, 'Längskraft / Längsschlupf')
            xlabel(app.UIAxes_MS_1, '\kappa [-]')
            ylabel(app.UIAxes_MS_1, 'FX [N]')
            zlabel(app.UIAxes_MS_1, 'Z')
            app.UIAxes_MS_1.Position = [1 275 639 133];

            % Create ShowFilteredYellowCheckBox
            app.ShowFilteredYellowCheckBox = uicheckbox(app.ManuelSelctionTab);
            app.ShowFilteredYellowCheckBox.Text = 'ShowFilteredYellowCheckBox';
            app.ShowFilteredYellowCheckBox.Position = [51 127 181 22];

            % Create FrequenzanalyseTab
            app.FrequenzanalyseTab = uitab(app.TabGroup2);
            app.FrequenzanalyseTab.Title = 'Frequenzanalyse';

            % Create UIAxes_FA_Time
            app.UIAxes_FA_Time = uiaxes(app.FrequenzanalyseTab);
            title(app.UIAxes_FA_Time, 'Zeitsignal (Roh vs. Cutoff-Vorschlag)')
            xlabel(app.UIAxes_FA_Time, 'ET [s]')
            ylabel(app.UIAxes_FA_Time, 'Kanal')
            zlabel(app.UIAxes_FA_Time, 'Z')
            app.UIAxes_FA_Time.Position = [1 240 639 130];

            % Create UIAxes_FA_Spec
            app.UIAxes_FA_Spec = uiaxes(app.FrequenzanalyseTab);
            title(app.UIAxes_FA_Spec, 'Amplitudenspektrum')
            xlabel(app.UIAxes_FA_Spec, 'Frequenz [Hz]')
            ylabel(app.UIAxes_FA_Spec, 'Amplitude')
            zlabel(app.UIAxes_FA_Spec, 'Z')
            app.UIAxes_FA_Spec.Position = [1 96 639 134];

            % Create FA_SweepDropDown
            app.FA_SweepDropDown = uidropdown(app.FrequenzanalyseTab);
            app.FA_SweepDropDown.Items = {'Bitte Daten laden'};
            app.FA_SweepDropDown.FontSize = 10;
            app.FA_SweepDropDown.Position = [8 6 260 22];

            % Create FA_ChannelDropDown
            app.FA_ChannelDropDown = uidropdown(app.FrequenzanalyseTab);
            app.FA_ChannelDropDown.Items = {'Fx', 'Fy', 'Fz', 'Mx', 'My', 'Mz'};
            app.FA_ChannelDropDown.Value = 'Fz';
            app.FA_ChannelDropDown.FontSize = 10;
            app.FA_ChannelDropDown.Position = [272 6 80 22];

            % Create FA_AnalyzeButton
            app.FA_AnalyzeButton = uibutton(app.FrequenzanalyseTab, 'push');
            app.FA_AnalyzeButton.ButtonPushedFcn = createCallbackFcn(app, @FA_AnalyzeButtonPushed, true);
            app.FA_AnalyzeButton.Position = [358 6 90 22];
            app.FA_AnalyzeButton.Text = 'Analysieren';

            % Create FA_ApplyCutoffButton
            app.FA_ApplyCutoffButton = uibutton(app.FrequenzanalyseTab, 'push');
            app.FA_ApplyCutoffButton.ButtonPushedFcn = createCallbackFcn(app, @FA_ApplyCutoffButtonPushed, true);
            app.FA_ApplyCutoffButton.Position = [454 6 150 22];
            app.FA_ApplyCutoffButton.Text = 'Cutoff uebernehmen';

            % Create FA_ResultLabel
            app.FA_ResultLabel = uilabel(app.FrequenzanalyseTab);
            app.FA_ResultLabel.Position = [8 32 620 60];
            app.FA_ResultLabel.Text = 'Sweep auswaehlen, Kanal waehlen und "Analysieren" klicken.';

            % Create Panel
            app.Panel = uipanel(app.UIFigure);
            app.Panel.ForegroundColor = [0.1059 0.1059 0.1059];
            app.Panel.BackgroundColor = [0.7804 0.1333 0.1608];
            app.Panel.Position = [3 495 767 62];

            % Create DynamicseVLabel
            app.DynamicseVLabel = uilabel(app.Panel);
            app.DynamicseVLabel.FontName = 'Rift';
            app.DynamicseVLabel.FontSize = 36;
            app.DynamicseVLabel.Position = [9 7 169 48];
            app.DynamicseVLabel.Text = 'Dynamics e.V.';

            % Create ReifentestViewerCarNo62Label
            app.ReifentestViewerCarNo62Label = uilabel(app.Panel);
            app.ReifentestViewerCarNo62Label.HorizontalAlignment = 'right';
            app.ReifentestViewerCarNo62Label.FontName = 'Rift';
            app.ReifentestViewerCarNo62Label.FontSize = 18;
            app.ReifentestViewerCarNo62Label.Position = [557 18 208 25];
            app.ReifentestViewerCarNo62Label.Text = 'Reifentest Viewer | Car No. 62     ';

            % Create AuswahlPanel
            app.AuswahlPanel = uipanel(app.UIFigure);
            app.AuswahlPanel.ForegroundColor = [0.7804 0.1333 0.1608];
            app.AuswahlPanel.Title = 'Auswahl';
            app.AuswahlPanel.FontName = 'Rift';
            app.AuswahlPanel.Position = [2 430 767 66];

            % Create OpenDirectoryButton
            app.OpenDirectoryButton = uibutton(app.AuswahlPanel, 'push');
            app.OpenDirectoryButton.ButtonPushedFcn = createCallbackFcn(app, @OpenDirectoryButtonPushed, true);
            app.OpenDirectoryButton.Position = [6 11 100 23];
            app.OpenDirectoryButton.Text = 'Open Directory';

            % Create Test_file_directroy
            app.Test_file_directroy = uieditfield(app.AuswahlPanel, 'text');
            app.Test_file_directroy.FontSize = 10;
            app.Test_file_directroy.Position = [113 12 544 22];
            app.Test_file_directroy.Value = '''C:\Users\Danie\OneDrive\Desktop\Tire_Data_fitting_MF6.2\0_Tire_test_data\0_Reifen_43075\B2356run6.mat''';

            % Create LoadTireDataButton
            app.LoadTireDataButton = uibutton(app.AuswahlPanel, 'push');
            app.LoadTireDataButton.ButtonPushedFcn = createCallbackFcn(app, @LoadTireDataButtonPushed, true);
            app.LoadTireDataButton.Position = [667 11 89 23];
            app.LoadTireDataButton.Text = 'Load Tire Data';

            % Create FilterPanel
            app.FilterPanel = uipanel(app.UIFigure);
            app.FilterPanel.ForegroundColor = [0.7804 0.1333 0.1608];
            app.FilterPanel.Title = 'Filter';
            app.FilterPanel.Position = [3 216 127 214];

            % Create FilterRowsGrid
            app.FilterRowsGrid = uigridlayout(app.FilterPanel);
            app.FilterRowsGrid.ColumnWidth = {'1x'};
            app.FilterRowsGrid.RowHeight = {22, '1x', 22};
            app.FilterRowsGrid.Padding = [3.92000579833984 10 3.92000579833984 10];

            % Create FilterAddDropDown
            app.FilterAddDropDown = uidropdown(app.FilterRowsGrid);
            app.FilterAddDropDown.Items = {'+ Add Parameter'};
            app.FilterAddDropDown.FontSize = 10;
            app.FilterAddDropDown.Layout.Row = 1;
            app.FilterAddDropDown.Layout.Column = 1;
            app.FilterAddDropDown.Value = '+ Add Parameter';

            % Create HideUnusedCheckBox
            app.HideUnusedCheckBox = uicheckbox(app.FilterRowsGrid);
            app.HideUnusedCheckBox.ValueChangedFcn = createCallbackFcn(app, @HideUnusedCheckBoxValueChanged, true);
            app.HideUnusedCheckBox.Text = 'Hide Unused Data';
            app.HideUnusedCheckBox.Layout.Row = 3;
            app.HideUnusedCheckBox.Layout.Column = 1;

            % Create SmoothingPanel
            app.SmoothingPanel = uipanel(app.UIFigure);
            app.SmoothingPanel.ForegroundColor = [0.7804 0.1333 0.1608];
            app.SmoothingPanel.Title = 'Smoothing';
            app.SmoothingPanel.Position = [1 1 127 214];

            % Create SmoothingRowsGrid
            app.SmoothingRowsGrid = uigridlayout(app.SmoothingPanel);
            app.SmoothingRowsGrid.ColumnWidth = {'1x'};
            app.SmoothingRowsGrid.RowHeight = {22, '1x'};
            app.SmoothingRowsGrid.Padding = [3.92000579833984 10 3.92000579833984 10];

            % Create SmoothingAddDropDown
            app.SmoothingAddDropDown = uidropdown(app.SmoothingRowsGrid);
            app.SmoothingAddDropDown.Items = {'+ Add Parameter'};
            app.SmoothingAddDropDown.FontSize = 10;
            app.SmoothingAddDropDown.Layout.Row = 1;
            app.SmoothingAddDropDown.Layout.Column = 1;
            app.SmoothingAddDropDown.Value = '+ Add Parameter';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = Tire_Filter_App

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end