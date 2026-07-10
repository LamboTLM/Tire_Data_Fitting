classdef Tire_Filter_App_mat < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                      matlab.ui.Figure
        AuswahlPanel                  matlab.ui.container.Panel
        LoadTireDataButton            matlab.ui.control.Button
        ExportButton                  matlab.ui.control.Button
        Test_file_directroy           matlab.ui.control.EditField
        OpenDirectoryButton           matlab.ui.control.Button
        Panel                         matlab.ui.container.Panel
        ReifentestViewerCarNo62Label  matlab.ui.control.Label
        DynamicseVLabel               matlab.ui.control.Label
        TabGroup2                     matlab.ui.container.TabGroup
        TestPreprocessingTab          matlab.ui.container.Tab
        CorneringTab_2                matlab.ui.container.Tab
        CorneringKennwerteTab_2       matlab.ui.container.Tab
        CamberSweepTab_2              matlab.ui.container.Tab
        DriveBrakeTab_2               matlab.ui.container.Tab
        UIAxes_DB_1                   matlab.ui.control.UIAxes
        UIAxes_DB_2                   matlab.ui.control.UIAxes
        UIAxes_DB_3                   matlab.ui.control.UIAxes
        CombinedSlipTab_2             matlab.ui.container.Tab
        UIAxes_CS_1                   matlab.ui.control.UIAxes
        UIAxes_CS_2                   matlab.ui.control.UIAxes
        ColdtohotVerschleissTab       matlab.ui.container.Tab
        TransientTab_2                matlab.ui.container.Tab
        UIAxes_TR_1                   matlab.ui.control.UIAxes
        UIAxes_TR_2                   matlab.ui.control.UIAxes
        SpeedVergleichTab_2           matlab.ui.container.Tab
        UIAxes_SV_1                   matlab.ui.control.UIAxes
        UIAxes_SV_2                   matlab.ui.control.UIAxes
        UIAxes_SV_3                   matlab.ui.control.UIAxes
        RohdatenExplorerTab_2         matlab.ui.container.Tab
        ManuelSelctionTab             matlab.ui.container.Tab
    end


    %% Property Definitionene

    % Propertys für Backend
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
        SmoothingRows = struct('Parameter', {}, 'RowLayout', {}, 'TypeDropDown', {}, 'EnabledCheckBox', {}, 'Param1Label', {}, 'Param1EditField', {}, 'Param2Label', {}, 'Param2EditField', {}, 'DeleteButton', {})

        % Nutzungs-Masken (je ein logical-Array, gleiche Groesse wie app.sweep)
        SweepIsUsed logical = []      % EFFEKTIVE Maske (Filter & ~Manuell) - wird von allen Plots konsultiert
        FilterIsUsed logical = []     % Ergebnis der reinen Bounds-Filterung (ohne manuellen Ausschluss)
        ManualExclude logical = []    % Manuell (per Klick im Sweep-Auswahl-Tab) ausgeschlossene Sweeps

        % Reifen daten nach denen gefiltert werden kann
        KNOWN_CHANNELS cell = {'alpha', 'kappa', 'Fx', 'Fy', 'Fz', 'Mx', 'Mz', 'IP', 'gamma', 'V', 'omega', 'TtreadI', 'TtreadC', 'TtreadO'} % Bekannte Messkanaele, unabhaengig vom Ladezustand

        % Smothings die gemacht werden koennen
        SMOOTHING_TYPES cell = {'Butterworth', 'Bessel', 'Savitzky-Golay', 'Moving Average', 'Median', 'Hampel'}

       NOMINAL_LEVELS struct = struct( ...
              'Fz',    [222.4 444.8 667.2 889.6 1112.1 1556.9], ...  % [N]   (50/100/150/200/250/350 lbf)
              'IP',    [55158 68948 82737 96527], ...                 % [Pa]  (8/10/12/14 psi)
              'gamma', [0 0.0349 0.0698], ...                         % [rad] (0/2/4 deg)
              'V',     [11.2 20.1])                                   % [m/s] (25/45 mph)

       ZeroOffset struct = struct('alpha0_deg', {}, 'mz0', {})
    
    end

    % Properties for Java Scripts
    properties (Access = public)
        StartupHTML                   matlab.ui.control.HTML
        LogoTopRight                  matlab.ui.control.Image

        UIFigure_html                 matlab.ui.Figure
        FilterSmoothingHTML           matlab.ui.control.HTML
        CorneringHTML                 matlab.ui.control.HTML
        Cornering_kennwerte_HTML      matlab.ui.control.HTML
        Manual_selection_html         matlab.ui.control.HTML
        test_preprocessing_HTML       matlab.ui.control.HTML
        cold_to_hot_HTML              matlab.ui.control.HTML
        camber_sweep_HTML             matlab.ui.control.HTML
        rohdaten_explorer_HTML        matlab.ui.control.HTML
    end

    % Alle Eigenen functions
    methods (Access = private)
        %% Reifenobjecte
        
        function load_Tire_Data(app)
            % LOAD_TIRE_DATA Laedt einen neuen Reifentest und ersetzt den
            % kompletten sweep-indizierten State der App.
            %
            % Autor: Lambo || Datum: 10.07.26
            % Changelog:
            %   10.07.26 - Expliziter Reset von SweepIsUsed/FilterIsUsed/
            %              ManualExclude/ZeroOffset VOR dem Laden. Ohne
            %              diesen Reset behalten die Masken ihre Groesse
            %              aus dem vorherigen Test: Stimmt die Sweep-Anzahl
            %              nicht mehr, crasht update_combined_mask bei der
            %              UND-Verknuepfung FilterIsUsed & ~ManualExclude
            %              (Dimensionskonflikt) - und weil der Crash VOR
            %              refresh_all_plots() liegt, bleiben alle Tabs auf
            %              dem Plot des alten Tests stehen. Stimmt die
            %              Anzahl zufaellig, wird stattdessen der manuelle
            %              Ausschluss des alten Tests auf den neuen
            %              uebertragen (falsche Sweeps ausgeblendet).

            app.sweep          = [];
            app.ZeroOffset     = struct('alpha0_deg', {}, 'mz0', {});
            app.SweepIsUsed    = [];
            app.FilterIsUsed   = [];
            app.ManualExclude  = [];

            % Laden des Dateipfads aus dem Textfeld
            tire_file_full = string(app.Test_file_directroy.Value);
            tire_file_full = strip(tire_file_full, 'both', "'");
            app.tire_file = tire_file_full; % fuer Default-Namen beim Export
            tire_data_raw = load(tire_file_full);

            % tireData-Objekt erstellen und befüllen
            td_raw = create_Tire_object(app);
            td_raw = populate_tire_object(app, td_raw, tire_data_raw);
            segs = split(td_raw, "et");
            segs = setTestingMethod_Smoothed(app, segs, deg2rad(app.SA_THRESH_DEG), app.SL_THRESH, app.FILTER_WIN);

            % Abfertigen der Sweeps
            app.sweep = segs;
            app.ZeroOffset = app.compute_zero_offsets(segs); % NEU: Punkt 3

        end

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

        %% Daten Verarbeitung

        function offsets = compute_zero_offsets(app, sweeps)
            % COMPUTE_ZERO_OFFSETS Berechnet fuer alle Lateral-Sweeps die
            % Konizitaets- (alpha0) und Plysteer-Offsets (mz0) und liefert ein
            % Parallel-Array zu 'sweeps' zurueck (gleiche Indizierung wie
            % app.sweep / app.SweepIsUsed). Fuer Longitudinal/Combined/Undefined
            % Sweeps bleiben die Werte 0.
            %
            % Autor: Lambo || Datum: 09.07.26

            n = numel(sweeps);
            offsets = struct('alpha0_deg', num2cell(zeros(1, n)), 'mz0', num2cell(zeros(1, n)));

            for k = 1:n
                if sweeps(k).TestMethod == "Lateral"
                    [a0, m0] = app.compute_single_zero_offset(sweeps(k));
                    offsets(k).alpha0_deg = a0;
                    offsets(k).mz0 = m0;
                end
            end
        end

        function [alpha0_deg, mz0] = compute_single_zero_offset(app, s)
            % COMPUTE_SINGLE_ZERO_OFFSET Bestimmt fuer einen einzelnen
            % Lateral-Sweep die SA-Nullstelle von Fy (Konizitaet) und den
            % zugehoerigen Mz-Offset (Plysteer).
            %
            % VORGEHEN (Standard-TTC-Workflow):
            %   1. Auf- und Absweep anhand des Vorzeichens von d(alpha)/dt trennen
            %   2. Beide Aeste auf ein gemeinsames SA-Gitter interpolieren und
            %      mitteln -> eliminiert hysteresebedingte Verschiebung
            %   3. Nullstelle alpha0 von Fy_avg(alpha) im Fitband per linearer
            %      Regression bestimmen
            %   4. Mz_avg an der Stelle alpha0 auswerten = Plysteer-Offset mz0
            %
            % ANWENDUNG (in den Plot-Functions):
            %   alpha_corrected = alpha - alpha0_deg   % SA-Achse verschoben
            %   mz_corrected    = mz - mz0             % Mz um Offset bereinigt
            %   Fy selbst wird NICHT verschoben - durch die SA-Verschiebung geht
            %   die Kurve automatisch durch den Ursprung.
            %
            % Autor: Lambo || Datum: 09.07.26

            ZERO_BAND_DEG = 3.0; % [deg] Fitband um die Fy-Nullstelle
            SMOOTH_WIN = 31;     % [Samples] feste Glaettung NUR fuer die Nullstellensuche
            % (unabhaengig von den user-waehlbaren Smoothing-Settings,
            % damit die Offset-Berechnung beim Laden deterministisch ist)

            alpha_deg = rad2deg(s.alpha(:));
            fy = movmean(s.Fy(:), SMOOTH_WIN);
            mz = movmean(s.Mz(:), SMOOTH_WIN);

            % 1. Auf-/Absweep trennen
            d_alpha = [diff(alpha_deg); 0];
            up_idx = d_alpha >= 0;
            down_idx = ~up_idx;

            if nnz(up_idx) < 5 || nnz(down_idx) < 5
                alpha_grid = alpha_deg;
                fy_avg = fy;
                mz_avg = mz;
            else
                [alpha_up_s, ord_u] = sort(alpha_deg(up_idx));
                fy_tmp = fy(up_idx);   fy_up_s = fy_tmp(ord_u);
                mz_tmp = mz(up_idx);   mz_up_s = mz_tmp(ord_u);

                [alpha_down_s, ord_d] = sort(alpha_deg(down_idx));
                fy_tmp = fy(down_idx); fy_down_s = fy_tmp(ord_d);
                mz_tmp = mz(down_idx); mz_down_s = mz_tmp(ord_d);

                % Doppelte SA-Stuetzstellen entfernen (Mittelwert der
                % zugehoerigen y-Werte) - interp1 verlangt eindeutige
                % Stuetzstellen, sonst "Sample points must be unique"
                [alpha_up_s, fy_up_s, mz_up_s] = app.dedupe_xy(alpha_up_s, fy_up_s, mz_up_s);
                [alpha_down_s, fy_down_s, mz_down_s] = app.dedupe_xy(alpha_down_s, fy_down_s, mz_down_s);

                lo = max(min(alpha_up_s), min(alpha_down_s));
                hi = min(max(alpha_up_s), max(alpha_down_s));

                if hi <= lo
                    alpha_grid = alpha_deg; fy_avg = fy; mz_avg = mz;
                else
                    alpha_grid = linspace(lo, hi, 200)';
                    fy_up_i   = interp1(alpha_up_s,   fy_up_s,   alpha_grid, 'linear');
                    fy_down_i = interp1(alpha_down_s, fy_down_s, alpha_grid, 'linear');
                    mz_up_i   = interp1(alpha_up_s,   mz_up_s,   alpha_grid, 'linear');
                    mz_down_i = interp1(alpha_down_s, mz_down_s, alpha_grid, 'linear');
                    fy_avg = mean([fy_up_i, fy_down_i], 2);
                    mz_avg = mean([mz_up_i, mz_down_i], 2);
                end
            end

            % 2. Nullstelle von Fy_avg(alpha) per linearer Regression im Fitband
            idx_band = abs(alpha_grid) <= ZERO_BAND_DEG;
            if nnz(idx_band) < 3
                alpha0_deg = 0; mz0 = 0; % Fallback: zu wenig Punkte -> keine Korrektur
                return
            end

            p_fy = polyfit(alpha_grid(idx_band), fy_avg(idx_band), 1);
            if abs(p_fy(1)) < eps
                alpha0_deg = 0;
            else
                alpha0_deg = -p_fy(2) / p_fy(1); % [deg] Konizitaets-Offset (Nullstelle)
            end

            % 3. Mz-Offset (Plysteer) = Wert der gemittelten Mz-Kurve an alpha0
            p_mz = polyfit(alpha_grid(idx_band), mz_avg(idx_band), 1);
            mz0 = polyval(p_mz, alpha0_deg); % [Nm]
        end

        function [x_u, varargout] = dedupe_xy(~, x, varargin)
            % DEDUPE_XY Entfernt doppelte Stuetzstellen in x, indem alle
            % zugehoerigen y-Werte (varargin) pro eindeutigem x-Wert
            % gemittelt werden. interp1 verlangt eindeutige Stuetzstellen -
            % ohne diese Bereinigung wirft interp1 bei Sweeps mit
            % wiederholten SA-Samples (z.B. Haltephasen) den Fehler
            % "Sample points must be unique".
            %
            % EINGABE:
            %   x:        Stuetzstellen-Vektor (z.B. sortierte SA-Werte)
            %   varargin: Beliebig viele y-Vektoren gleicher Laenge wie x
            % AUSGABE:
            %   x_u:      Eindeutige, aufsteigend sortierte Stuetzstellen
            %   varargout: Gemittelte y-Vektoren (gleiche Reihenfolge wie varargin)
            %
            % Autor: Lambo || Datum: 10.07.26

            [x_u, ~, ic] = unique(x(:));
            varargout = cell(1, numel(varargin));
            for k = 1:numel(varargin)
                varargout{k} = accumarray(ic, varargin{k}(:), [], @mean);
            end
        end

        %%  Plotten
        
        function refresh_all_plots(app)
            % REFRESH_ALL_PLOTS Zeichnet ALLE Plots der App neu. Zentrale
            % Stelle, die von Filter-, Smoothing- und manuellen
            % Auswahl-Aenderungen aufgerufen wird.
            %
            % Autor: Lambo || Datum: 08.07.26
            % Changelog:
            %   08.07.26 - Explizites cla('reset') statt cla() um Ghost-Plots
            %              zu vermeiden. Hold-State wird vor cla zurückgesetzt.

            if isempty(app.sweep)
                return
            end

            plot_cornering_html(app)
            plot_cornering_kennwerte_html(app)
            plot_manual_selection_html(app)
            plot_test_preprocessing_html(app)
            plot_camber_sweep_html(app)
            % app.plot_drive_brake();
            % app.plot_combined_slip();
            plot_cold_to_hot_html(app)
            % app.plot_transient();
            % app.plot_speed_vergleich();
            plot_rohdaten_explorer_html(app)
        end

        function plot_cornering_html(app)
            % PLOT_CORNERING_HTML Baut den Datenvertrag fuer das ECharts-
            % Cornering-Widget (CorneringHTML) aus den TestMethod=='Lateral'
            % Sweeps und schreibt ihn nach app.CorneringHTML.Data. Ersetzt
            % die reine MATLAB-Plot-Funktion plot_cornering() fuer die
            % Darstellung -- Filter-/Smoothing-Backend bleibt unveraendert.
            %
            % Autor: Lambo || Datum: 08.07.26

            if isempty(app.sweep)
                return
            end
            if isempty(app.CorneringHTML) || ~isvalid(app.CorneringHTML)
                return
            end

            methods_ = [app.sweep.TestMethod];
            is_lateral = (methods_ == "Lateral");
            lateral_idx = find(is_lateral);
            lateral_sweeps = app.sweep(lateral_idx);
            if isempty(lateral_sweeps)
                return
            end
            if isempty(app.SweepIsUsed)
                app.SweepIsUsed = true(size(app.sweep));
            end

            sweeps_payload = cell(1, numel(lateral_sweeps));
            for k = 1:numel(lateral_sweeps)
                orig_idx = lateral_idx(k);
                s = lateral_sweeps(k);

                sa_deg    = rad2deg(s.alpha) - app.ZeroOffset(orig_idx).alpha0_deg;
                fy_smooth = app.smooth_channel(s, 'Fy', s.Fy);
                mz_smooth = app.smooth_channel(s, 'Mz', s.Mz) - app.ZeroOffset(orig_idx).mz0;
                mx_smooth = app.smooth_channel(s, 'Mx', s.Mx);

                sweeps_payload{k} = struct( ...
                    'id',        k - 1, ...                    % 0-basiert fuer JS
                    'origIndex', orig_idx, ...                  % 1-basiert, Rueckweg nach MATLAB
                    'fz',        median(s.Fz, 'omitnan'), ...
                    'used',      logical(app.SweepIsUsed(orig_idx)), ...
                    'r2',        app.r2_quality(s.Fy, fy_smooth), ...
                    'sa',        sa_deg(:)', ...
                    'raw',       struct('Fy', s.Fy(:)', 'Mz', s.Mz(:)', 'Mx', s.Mx(:)'), ...
                    'smooth',    struct('Fy', fy_smooth(:)', 'Mz', mz_smooth(:)', 'Mx', mx_smooth(:)') ...
                    );
            end

            payload = struct( ...
                'xLabel',   'Schraeglaufwinkel alpha [deg]', ...
                'channels', {{ ...
                struct('key', 'Fy', 'label', 'Fy [N]'), ...
                struct('key', 'Mz', 'label', 'Mz [Nm]'), ...
                struct('key', 'Mx', 'label', 'Mx [Nm]') ...
                }}, ...
                'sweeps',   {sweeps_payload} ...
                );

            app.CorneringHTML.Data = payload;
        end

        function plot_cornering_kennwerte_html(app)
            % PLOT_CORNERING_KENNWERTE_HTML Baut den Datenvertrag fuer das ECharts-
            % Kennwerte-Widget (KennwerteHTML) aus den TestMethod=='Lateral' Sweeps
            % und schreibt ihn nach app.KennwerteHTML.Data. Ersetzt die reine
            % MATLAB-Plot-Funktion plot_cornering_kennwerte() (UIAxes_CK_1/2/3) fuer
            % die Darstellung -- Kennwert-Berechnung (FYmax, mu_max, C_Fy,alpha)
            % bleibt unveraendert. Hide-Unused-Logik wandert vom MATLAB-seitigen
            % HideUnusedCheckBox in den client-seitigen Toggle des HTML-Widgets;
            % es werden daher immer ALLE Lateral-Sweeps berechnet und uebergeben.
            %
            % Zweck: Kennwerte-Payload fuer uihtml-Kennwerte-Viewer
            % Abhaengigkeiten: app.sweep, app.SweepIsUsed, app.smooth_channel(), app.KennwerteHTML
            % Autor: Lambo || Datum: 08.07.26
            %
            % Changelog:
            %   08.07.26 - Lambo - Initiale Version (ersetzt plot_cornering_kennwerte)

            % Konfiguration
            ZERO_BAND_DEG = 1.5; % [deg] Band um SA = 0 fuer Steigungsfit (C_Fy,alpha)

            if isempty(app.sweep)
                return
            end
            if isempty(app.Cornering_kennwerte_HTML) || ~isvalid(app.Cornering_kennwerte_HTML)
                return
            end

            % Vorberechnungen
            methods_ = [app.sweep.TestMethod];
            is_lateral = (methods_ == "Lateral");
            lateral_idx = find(is_lateral);
            lateral_sweeps = app.sweep(lateral_idx);

            if isempty(lateral_sweeps)
                return
            end
            if isempty(app.SweepIsUsed)
                app.SweepIsUsed = true(size(app.sweep));
            end

            n = numel(lateral_sweeps); % [-] Anzahl Lateral-Sweeps

            % Berechnung
            sweeps_payload = cell(1, n);
            for k = 1:n
                orig_idx = lateral_idx(k);
                s = lateral_sweeps(k);

                sa_deg = rad2deg(s.alpha) - app.ZeroOffset(orig_idx).alpha0_deg;
                fy_plot = app.smooth_channel(s, 'Fy', s.Fy);
                fz_plot = app.smooth_channel(s, 'Fz', s.Fz);

                [fy_max_val, idx_fy_max] = max(abs(fy_plot));
                fy_max = fy_max_val * sign(fy_plot(idx_fy_max)); % [N] vorzeichenbehaftet
                mu_max = app.calc_mu_max_robust(fy_plot, fz_plot); % [-]

                idx_zero = abs(sa_deg) <= ZERO_BAND_DEG;
                if sum(idx_zero) >= 3
                    p = polyfit(sa_deg(idx_zero), fy_plot(idx_zero), 1);
                    c_fy_alpha = p(1); % [N/deg]
                else
                    c_fy_alpha = NaN;
                end

                sweeps_payload{k} = struct( ...
                    'id',        k - 1, ...                    % 0-basiert fuer JS
                    'origIndex', orig_idx, ...                  % 1-basiert, Rueckweg nach MATLAB
                    'fz',        median(s.Fz, 'omitnan'), ...
                    'used',      logical(app.SweepIsUsed(orig_idx)), ...
                    'fyMax',     fy_max, ...
                    'muMax',     mu_max, ...
                    'cFyAlpha',  c_fy_alpha ...
                    );
            end

            %% Ausgabe
            payload = struct('sweeps', {sweeps_payload});
            app.Cornering_kennwerte_HTML.Data = payload;
        end

        function plot_manual_selection_html(app)
            % PLOT_MANUAL_SELECTION_HTML Baut den Datenvertrag fuer das ECharts-
            % Manual-Selection-Widget (ManualSelectionHTML) aus ALLEN Sweeps und
            % schreibt ihn nach app.ManualSelectionHTML.Data. Ersetzt die reine
            % MATLAB-Plot-Funktion plot_manual_selection() (UIAxes_MS_1/2/3) fuer
            % die Darstellung. Kanaele werden bereits hier vollstaendig geglaettet
            % uebergeben (app.smooth_channel) -- das HTML-Widget macht kein
            % Smoothing selbst. Toggle des manuellen Ausschlusses und der
            % Gelb-Markierung laufen ueber Events aus JS zurueck nach MATLAB
            % (siehe HTMLEventReceivedFcn-Kommentar im HTML-Header).
            %
            % Zweck: Manual-Selection-Payload fuer uihtml-Sweep-Viewer
            % Abhaengigkeiten: app.sweep, app.FilterIsUsed, app.ManualExclude,
            %                  app.ShowFilteredYellowCheckBox, app.smooth_channel(),
            %                  app.ManualSelectionHTML
            % Autor: Lambo || Datum: 08.07.26
            %
            % Changelog:
            %   08.07.26 - Lambo - Initiale Version (ersetzt plot_manual_selection)

            % Konfiguration
            channel_groups_def = { ...
                struct('title', 'Kraefte',       'ylabel', 'Kraft [N]',        'channels', {{'Fx', 'Fy', 'Fz'}}), ...
                struct('title', 'Momente',       'ylabel', 'Moment [Nm]',      'channels', {{'Mx', 'My', 'Mz'}}), ...
                struct('title', 'Temperaturen',  'ylabel', 'Temperatur [°C]',  'channels', {{'TtreadI', 'TtreadC', 'TtreadO'}}) ...
                };
            all_channels = [channel_groups_def{1}.channels, channel_groups_def{2}.channels, channel_groups_def{3}.channels];

            if isempty(app.sweep)
                return
            end
            if isempty(app.Manual_selection_html) || ~isvalid(app.Manual_selection_html)
                return
            end
            if isempty(app.FilterIsUsed)
                app.FilterIsUsed = true(size(app.sweep));
            end
            if isempty(app.ManualExclude)
                app.ManualExclude = false(size(app.sweep));
            end

            % Vorberechnungen
            n = numel(app.sweep); % [-] Anzahl aller Sweeps (kein TestMethod-Filter)

            % Berechnung
            sweeps_payload = cell(1, n);
            for k = 1:n
                s = app.sweep(k);

                chans_struct = struct();
                for c = 1:numel(all_channels)
                    ch_name = all_channels{c};
                    y_raw = s.(ch_name);
                    y_smooth = app.smooth_channel(s, ch_name, y_raw);
                    chans_struct.(ch_name) = y_smooth(:)';
                end

                sweeps_payload{k} = struct( ...
                    'id',            k - 1, ...                          % 0-basiert fuer JS
                    'origIndex',     k, ...                               % 1-basiert, Rueckweg nach MATLAB
                    'filterUsed',    logical(app.FilterIsUsed(k)), ...
                    'manualExclude', logical(app.ManualExclude(k)), ...
                    'et',            s.et(:)', ...
                    'channels',      chans_struct ...
                    );
            end

            % % Ausgabe
            % payload = struct( ...
            %     'showFilteredYellow', logical(app.ShowFilteredYellowCheckBox.Value), ...
            %     'channelGroups',      {channel_groups_def}, ...
            %     'sweeps',             {sweeps_payload} );

            % Ausgabe
            payload = struct( ...
                'channelGroups',      {channel_groups_def}, ...
                'sweeps',             {sweeps_payload} );
            
            app.Manual_selection_html.Data = payload;
        end

        function plot_test_preprocessing_html(app)
            % PLOT_TEST_PREPROCESSING_HTML Baut den Datenvertrag fuer das ECharts-
            % Test-Preprocessing-Widget (PreprocessingHTML) aus ALLEN Sweeps und
            % schreibt ihn nach app.PreprocessingHTML.Data. Ersetzt die reine
            % MATLAB-Plot-Funktion plot_test_preprocessing() (UIAxes_Sweep/
            % UIAxes_Mu/UIAxes_Pneu) fuer die Darstellung. mu_y und Pneumatic
            % Trail werden NICHT mehr hier berechnet, sondern client-seitig aus
            % fy/fz/mz/alphaDeg (reine Division) -- exakt wie im MATLAB-Code,
            % aber ohne doppelte Berechnung. hide_unused-Filterung entfaellt
            % hier (wandert in den Client-Toggle); alle Sweeps werden mit 'used'
            % markiert uebergeben.
            %
            % Zweck: Test-Preprocessing-Payload fuer uihtml-Sweep-Viewer
            % Abhaengigkeiten: app.sweep, app.SweepIsUsed, app.smooth_channel(),
            %                  app.PreprocessingHTML
            % Autor: Lambo || Datum: 09.07.26
            %
            % Changelog:
            %   09.07.26 - Lambo - Initiale Version (ersetzt plot_test_preprocessing)

            % Konfiguration
            FY_THRESHOLD = 50; % [N] Mindest-FY fuer Pneumatic-Trail-Berechnung (Startwert)
            method_colors = struct( ...
                'Lateral',      '#C72129', ...
                'Longitudinal', '#3399E6', ...
                'Combined',     '#E6B31A', ...
                'Undefined',    '#808080');

            if isempty(app.sweep)
                return
            end
            if isempty(app.test_preprocessing_HTML) || ~isvalid(app.test_preprocessing_HTML)
                return
            end
            if isempty(app.SweepIsUsed)
                app.SweepIsUsed = true(size(app.sweep));
            end

            % Vorberechnungen
            n = numel(app.sweep); % [-] Anzahl aller Sweeps (kein TestMethod-Filter)

            % Berechnung
            sweeps_payload = cell(1, n);
            for k = 1:n
                s = app.sweep(k);
                method_str = char(s.TestMethod);
                is_lateral = strcmp(method_str, 'Lateral');

                fy_smooth = app.smooth_channel(s, 'Fy', s.Fy);

                sweep_struct = struct( ...
                    'id',         k - 1, ...                    % 0-basiert fuer JS
                    'origIndex',  k, ...                          % 1-basiert, Rueckweg nach MATLAB
                    'testMethod', method_str, ...
                    'used',       logical(app.SweepIsUsed(k)), ...
                    'et',         s.et(:)', ...
                    'fy',         fy_smooth(:)' ...
                    );

                if is_lateral
                    fz_smooth = app.smooth_channel(s, 'Fz', s.Fz);
                    mz_smooth = app.smooth_channel(s, 'Mz', s.Mz);
                    sweep_struct.fzMedian = median(s.Fz, 'omitnan');
                    sweep_struct.alphaDeg = rad2deg(s.alpha(:)');
                    sweep_struct.fz = fz_smooth(:)';
                    sweep_struct.mz = mz_smooth(:)';
                end

                sweeps_payload{k} = sweep_struct;
            end

            % Ausgabe
            payload = struct( ...
                'fyThreshold',  FY_THRESHOLD, ...
                'methodColors', method_colors, ...
                'sweeps',       {sweeps_payload} ...
                );

            app.test_preprocessing_HTML.Data = payload;
        end
        
        function plot_cold_to_hot_html(app)
            % PLOT_COLD_TO_HOT_HTML Baut den Datenvertrag fuer das ECharts-
            % Cold-to-Hot-Widget (ColdHotHTML) aus den TestMethod=='Lateral'
            % Sweeps und schreibt ihn nach app.ColdHotHTML.Data. Ersetzt die
            % reine MATLAB-Plot-Funktion plot_cold_to_hot() (UIAxes_CH_1/2) fuer
            % die Darstellung -- Kennwert-Berechnung (mu_max, C_Fy,alpha) bleibt
            % unveraendert. Hide-Unused-Filterung entfaellt hier (wandert in den
            % Client-Toggle); alle Lateral-Sweeps werden mit 'used' markiert
            % uebergeben.
            %
            % Zweck: Cold-to-Hot-Payload fuer uihtml-Kennwerte-Viewer
            % Abhaengigkeiten: app.sweep, app.SweepIsUsed, app.smooth_channel(),
            %                  app.ColdHotHTML
            % Autor: Lambo || Datum: 09.07.26
            %
            % Changelog:
            %   09.07.26 - Lambo - Initiale Version (ersetzt plot_cold_to_hot)

            % Konfiguration
            ZERO_BAND_DEG = 1.5; % [deg] Band um SA = 0 fuer Steigungsfit (C_Fy,alpha)

            if isempty(app.sweep)
                return
            end
            if isempty(app.cold_to_hot_HTML) || ~isvalid(app.cold_to_hot_HTML)
                return
            end

            methods_ = [app.sweep.TestMethod];
            is_lateral = (methods_ == "Lateral");
            lateral_idx = find(is_lateral);
            lateral_sweeps = app.sweep(lateral_idx);

            if isempty(lateral_sweeps)
                return
            end
            if isempty(app.SweepIsUsed)
                app.SweepIsUsed = true(size(app.sweep));
            end

            % Vorberechnungen
            n = numel(lateral_sweeps); % [-] Anzahl Lateral-Sweeps

            % Berechnung
            sweeps_payload = cell(1, n);
            for k = 1:n
                orig_idx = lateral_idx(k);
                s = lateral_sweeps(k);

                temp_c = median(s.TtreadC, 'omitnan');
                fy_smooth = app.smooth_channel(s, 'Fy', s.Fy);
                fz_smooth = app.smooth_channel(s, 'Fz', s.Fz);
                mu_max = app.calc_mu_max_robust(fy_smooth, fz_smooth); % [-]

                sa_deg = rad2deg(s.alpha) - app.ZeroOffset(orig_idx).alpha0_deg;
                idx_zero = abs(sa_deg) <= ZERO_BAND_DEG;
                if sum(idx_zero) >= 3
                    p = polyfit(sa_deg(idx_zero), fy_smooth(idx_zero), 1);
                    c_fy_alpha = p(1); % [N/deg]
                else
                    c_fy_alpha = NaN;
                end

                sweeps_payload{k} = struct( ...
                    'id',        sprintf('s%d', orig_idx), ...
                    'origIndex', orig_idx, ...
                    'used',      logical(app.SweepIsUsed(orig_idx)), ...
                    'tempC',     temp_c, ...
                    'muMax',     mu_max, ...
                    'cFyAlpha',  c_fy_alpha ...
                    );
            end

            % Ausgabe
            payload = struct('sweeps', {sweeps_payload});
            app.cold_to_hot_HTML.Data = payload;
        end
        
        function plot_camber_sweep_html(app)
            % PLOT_CAMBER_SWEEP_HTML Baut den Datenvertrag fuer das ECharts-
            % Camber-Sweep-Widget (CamberHTML) aus den TestMethod=='Lateral'
            % Sweeps und schreibt ihn nach app.CamberHTML.Data. Ersetzt die
            % reine MATLAB-Plot-Funktion plot_camber_sweep() (UIAxes_Cam_1/2/3)
            % fuer die Darstellung -- Farbcodierung nach Sturzwinkel (Turbo)
            % passiert jetzt client-seitig in JS. Hide-Unused-Filterung
            % entfaellt hier (wandert in den Client-Toggle); alle Lateral-
            % Sweeps werden mit 'used' markiert uebergeben.
            %
            % Zweck: Camber-Sweep-Payload fuer uihtml-Sweep-Viewer
            % Abhaengigkeiten: app.sweep, app.SweepIsUsed, app.smooth_channel(),
            %                  app.CamberHTML
            % Autor: Lambo || Datum: 09.07.26
            %
            % Changelog:
            %   09.07.26 - Lambo - Initiale Version (ersetzt plot_camber_sweep)

            % Konfiguration
            if isempty(app.sweep)
                return
            end
            if isempty(app.camber_sweep_HTML) || ~isvalid(app.camber_sweep_HTML)
                return
            end

            methods_ = [app.sweep.TestMethod];
            is_lateral = (methods_ == "Lateral");
            lateral_idx = find(is_lateral);
            lateral_sweeps = app.sweep(lateral_idx);

            if isempty(lateral_sweeps)
                return
            end
            if isempty(app.SweepIsUsed)
                app.SweepIsUsed = true(size(app.sweep));
            end

            % Vorberechnungen
            n = numel(lateral_sweeps); % [-] Anzahl Lateral-Sweeps

            % Berechnung
            sweeps_payload = cell(1, n);
            for k = 1:n
                orig_idx = lateral_idx(k);
                s = lateral_sweeps(k);

                fy_smooth = app.smooth_channel(s, 'Fy', s.Fy);
                mz_smooth = app.smooth_channel(s, 'Mz', s.Mz);
                mx_smooth = app.smooth_channel(s, 'Mx', s.Mx);

                sweeps_payload{k} = struct( ...
                    'id',          sprintf('s%d', orig_idx), ...
                    'origIndex',   orig_idx, ...
                    'used',        logical(app.SweepIsUsed(orig_idx)), ...
                    'alphaDeg',     rad2deg(s.alpha(:)') - app.ZeroOffset(orig_idx).alpha0_deg, ...
                    'fy',          fy_smooth(:)', ...
                    'mz',           mz_smooth(:)' - app.ZeroOffset(orig_idx).mz0, ...
                    'mx',          mx_smooth(:)', ...
                    'gammaMedian', rad2deg(median(s.gamma, 'omitnan')), ...
                    'fzMedian',    median(s.Fz, 'omitnan') ...
                    );
            end

            % Ausgabe
            payload = struct('sweeps', {sweeps_payload});
            app.camber_sweep_HTML.Data = payload;
        end
        
        function plot_rohdaten_explorer_html(app)
            % PLOT_ROHDATEN_EXPLORER_HTML Baut den Datenvertrag fuer das ECharts-
            % Rohdaten-Explorer-Widget (RohdatenHTML) aus ALLEN Sweeps und
            % schreibt ihn nach app.RohdatenHTML.Data. Ersetzt die reine MATLAB-
            % Plot-Funktion plot_rohdaten_explorer() (UIAxes_RE_1/UIAxes_RE_2)
            % fuer die Darstellung. WICHTIG: fz und alphaDeg werden bewusst ROH
            % uebergeben (kein app.smooth_channel) -- der Rohdaten-Explorer soll
            % die ungefilterten Messwerte zeigen. Hide-Unused-Filterung entfaellt
            % hier (wandert in den Client-Toggle); alle Sweeps werden mit 'used'
            % markiert uebergeben.
            %
            % Zweck: Rohdaten-Explorer-Payload fuer uihtml-Sweep-Viewer
            % Abhaengigkeiten: app.sweep, app.SweepIsUsed, app.RohdatenHTML
            % Autor: Lambo || Datum: 09.07.26
            %
            % Changelog:
            %   09.07.26 - Lambo - Initiale Version (ersetzt plot_rohdaten_explorer)

            % Konfiguration
            method_colors = struct( ...
                'Lateral',      '#C72229', ...
                'Longitudinal', '#33A3E6', ...
                'Combined',     '#E6B21A', ...
                'Undefined',    '#808080');

            if isempty(app.sweep)
                return
            end
            if isempty(app.rohdaten_explorer_HTML) || ~isvalid(app.rohdaten_explorer_HTML)
                return
            end
            if isempty(app.SweepIsUsed)
                app.SweepIsUsed = true(size(app.sweep));
            end

            % Vorberechnungen
            n = numel(app.sweep); % [-] Anzahl aller Sweeps (kein TestMethod-Filter)

            % Berechnung
            sweeps_payload = cell(1, n);
            for k = 1:n
                s = app.sweep(k);

                sweeps_payload{k} = struct( ...
                    'id',         sprintf('s%d', k), ...
                    'origIndex',  k, ...                          % 1-basiert, Rueckweg nach MATLAB
                    'testMethod', char(s.TestMethod), ...
                    'used',       logical(app.SweepIsUsed(k)), ...
                    'et',         s.et(:)', ...                    % [s] roh
                    'fz',         s.Fz(:)', ...                    % [N] roh, kein smooth_channel
                    'alphaDeg',   rad2deg(s.alpha(:)') ...          % [deg] roh
                    );
            end

            % Ausgabe
            payload = struct( ...
                'methodColors', method_colors, ...
                'sweeps',       {sweeps_payload} ...
                );
            app.rohdaten_explorer_HTML.Data = payload;
        end

        % Plot Helper
        function r2 = r2_quality(~, y_raw, y_smooth)
            % R2_QUALITY Einfaches Guetemass (Bestimmtheitsmass) zwischen
            % Roh- und geglaetteter Kurve, fuer die Anzeige im
            % Cornering-Widget (Sidebar-Tabelle).
            %
            % Autor: Lambo || Datum: 08.07.26

            y_raw = y_raw(:);
            y_smooth = y_smooth(:);
            valid = ~isnan(y_raw) & ~isnan(y_smooth);
            if nnz(valid) < 2
                r2 = NaN;
                return
            end
            ss_res = sum((y_raw(valid) - y_smooth(valid)).^2);
            ss_tot = sum((y_raw(valid) - mean(y_raw(valid))).^2);
            if ss_tot < eps
                r2 = 1;
            else
                r2 = 1 - ss_res / ss_tot;
            end
        end
        
        function mu_max = calc_mu_max_robust(~, fy_smooth, fz_smooth, fz_min_fraction)
            % CALC_MU_MAX_ROBUST Berechnet mu_max nur an Punkten mit ausreichend
            % Vertikallast (Fz > fz_min_fraction * Fz_nominal), damit einzelne
            % Fz-Einbrueche (z.B. Flat-Trac-Bandschwingungen) nicht als
            % Reibwert-Spitzen fehlinterpretiert werden.
            %
            % EINGABE:
            %   fy_smooth, fz_smooth: geglaettete Kanaele (gleiche Laenge)
            %   fz_min_fraction: [-] Mindestanteil des Fz-Sollwerts, Default 0.8
            %
            % Autor: Lambo || Datum: 09.07.26

            if nargin < 4
                fz_min_fraction = 0.8; % [-] 80% des Fz-Sollwerts als Mindestschwelle
            end

            fz_nominal = median(fz_smooth, 'omitnan'); % [N]
            valid = abs(fz_smooth) >= fz_min_fraction * abs(fz_nominal);

            if nnz(valid) < 3
                valid = true(size(fz_smooth)); % Fallback, falls Schwelle zu streng greift
            end

            mu_max = max(abs(fy_smooth(valid) ./ fz_smooth(valid)), [], 'omitnan');
        end

        %% Filter functions

        function apply_filters(app)
            % APPLY_FILTERS Wertet alle aktiven Filterzeilen aus dem
            % JavaScript-Frontend aus und schreibt das Ergebnis nach
            % app.FilterIsUsed. Neue Bedingungen: 'Ungleich (!=)',
            % 'Band um Nominal [±%]', 'Band um Peak [±%]', 'Band um Wert [±%]'.
            %
            % Semantik der val1/val2-Felder (siehe Data Contract im HTML-Header):
            %   Band um Nominal: val1 = Toleranz [%] um den naechsten Rasterwert
            %                    aus app.NOMINAL_LEVELS (Snap-to-Nominal)
            %   Band um Peak:    val1 = Toleranz [%] unterhalb des Kanal-Peaks
            %                    ueber ALLE Sweeps (Warmup-/Temperaturfenster-Filter)
            %   Band um Wert:    val1 = Referenzwert, val2 = Toleranz [%]
            %
            % Autor: Lambo || Datum: 09.07.26
            % Changelog:
            %   09.07.26 - Band-Bedingungen ergaenzt, Peak-Level-Cache pro
            %              Filterlauf (statt pro Sweep) fuer Performance

            if isempty(app.sweep)
                return
            end

            n = numel(app.sweep);
            used = true(n, 1);

            % Vorberechnungen: Peak-Level pro Kanal EINMAL cachen (nicht in der
            % Sweep-Schleife neu berechnen -> O(n) statt O(n^2))
            peak_cache = struct();

            for k = 1:n
                s = app.sweep(k);
                for f = 1:numel(app.FilterRows)

                    % Unterscheidung, falls MATLAB das JS-Array als Cell-Array interpretiert
                    if iscell(app.FilterRows)
                        row = app.FilterRows{f};
                    else
                        row = app.FilterRows(f);
                    end

                    level = app.get_sweep_level(s, row.parameter);
                    v1 = row.val1;
                    v2 = row.val2;

                    switch row.condition
                        case 'Lowerbound (>=)'
                            ok = level >= v1;

                        case 'Upperbound (<=)'
                            ok = level <= v1;

                        case 'Bereich [min,max]'
                            ok = level >= v1 && level <= v2;

                        case 'Gleich (==)'
                            ok = level == v1;

                        case 'Ungleich (!=)'
                            ok = level ~= v1;

                        case 'Band um Nominal [±%]'
                            % Snap auf naechsten Rasterwert, dann relative Toleranz.
                            % v1 = Toleranz [%]
                            [nominal, tol_abs] = app.get_nominal_level(row.parameter, level, v1);
                            if isnan(nominal)
                                ok = true; % Kein Raster definiert -> Filter neutral
                            else
                                ok = abs(abs(level) - nominal) <= tol_abs;
                            end

                        case 'Band um Peak [±%]'
                            % v1 = Toleranz [%]. Behalte Sweeps, deren Level
                            % innerhalb v1 % unterhalb des Peaks aller Sweeps liegt.
                            % Typischer Einsatz: TtreadC -> Warmup-Sweeps ausschliessen.
                            if ~isfield(peak_cache, row.parameter)
                                peak_cache.(row.parameter) = app.get_channel_peak_level(row.parameter);
                            end
                            peak = peak_cache.(row.parameter);
                            ok = abs(level) >= peak * (1 - v1 / 100);

                        case 'Band um Wert [±%]'
                            % v1 = Referenzwert, v2 = Toleranz [%]
                            ok = abs(level - v1) <= abs(v1) * (v2 / 100);

                        otherwise
                            ok = true;
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
            % SweepIsUsed, die von ALLEN Plot-Funktionen konsultiert wird.
            %
            % Autor: Lambo || Datum: 08.07.26

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

        function [nominal, tol_abs] = get_nominal_level(app, parameter, level, tol_pct)
            % GET_NOMINAL_LEVEL Snap-to-Nominal: Findet den naechstgelegenen
            % Sollwert aus app.NOMINAL_LEVELS fuer den gegebenen Sweep-Level und
            % berechnet die zugehoerige absolute Toleranz.
            %
            % Sonderfall nominal == 0 (z. B. gamma = 0 deg): Eine relative Toleranz
            % um 0 waere degeneriert -> Toleranz wird auf tol_pct % des kleinsten
            % Rasterabstands bezogen.
            %
            % EINGABE:
            %   parameter: Kanalname (Feldname in app.NOMINAL_LEVELS)
            %   level:     Sweep-Level (median des Kanals) [Kanaleinheit]
            %   tol_pct:   Toleranz [%]
            % AUSGABE:
            %   nominal:   Naechster Rasterwert [Kanaleinheit], NaN wenn kein Raster
            %   tol_abs:   Absolute Toleranz [Kanaleinheit]
            %
            % Autor: Lambo || Datum: 09.07.26

            if ~isfield(app.NOMINAL_LEVELS, parameter)
                nominal = NaN;
                tol_abs = NaN;
                return
            end

            grid_vals = app.NOMINAL_LEVELS.(parameter);
            [~, idx] = min(abs(abs(level) - grid_vals));
            nominal = grid_vals(idx);

            if nominal == 0
                if numel(grid_vals) > 1
                    ref = min(diff(sort(grid_vals))); % kleinster Rasterabstand
                else
                    ref = 1; % Fallback bei Ein-Punkt-Raster
                end
                tol_abs = ref * (tol_pct / 100);
            else
                tol_abs = nominal * (tol_pct / 100);
            end
        end

        function peak = get_channel_peak_level(app, parameter)
            % GET_CHANNEL_PEAK_LEVEL Maximaler |Sweep-Level| eines Kanals ueber
            % alle geladenen Sweeps. Referenz fuer 'Band um Peak [±%]'.
            %
            % Autor: Lambo || Datum: 09.07.26

            n = numel(app.sweep);
            levels = nan(n, 1);
            for k = 1:n
                levels(k) = app.get_sweep_level(app.sweep(k), parameter);
            end
            peak = max(abs(levels), [], 'omitnan');
        end

        %% Smoothing functions

        function x_smooth = apply_smoothing(~, x, filter_type, param1, param2, fs)
            % APPLY_SMOOTHING Wendet den gewaehlten Glaettungsfilter auf einen
            % Kanal an. Alle IIR-Filter laufen durch filtfilt -> Nullphase,
            % keine kuenstliche Hysterese in Fy-vs-SA-Kennfeldern.
            %
            % Typen und Parameter (muss mit filter_smoothing.html uebereinstimmen):
            %   Butterworth    : param1 = Ordnung N,  param2 = fc [Hz]  (EMPFOHLEN)
            %   Bessel         : param1 = Ordnung N,  param2 = fc [Hz]
            %   Savitzky-Golay : param1 = Ordnung,    param2 = Fenster
            %   Moving Average : param1 = Fenster
            %   Median         : param1 = Fenster
            %   Hampel         : param1 = Fenster,    param2 = n-Sigma
            %
            % Autor: Lambo || Datum: 09.07.26
            % Changelog:
            %   09.07.26 - Butterworth (digital, exaktes fc) als neuer Standard.
            %              Bessel: bilinear jetzt MIT Prewarping bei fc, sonst
            %              stimmt die eingestellte Grenzfrequenz nicht (Frequency
            %              Warping der Bilineartransformation). Hampel ergaenzt
            %              (reine Spike-Entfernung, Signal bleibt sonst roh).

            x = x(:);
            n = numel(x);

            switch filter_type
                case 'Butterworth'
                    N = round(param1);      % [-] Filterordnung
                    fc = param2;            % [Hz] Grenzfrequenz
                    pad_len = 3 * (N + 1);  % [-] Mindestlaenge fuer filtfilt-Randbehandlung
                    if fc <= 0 || fc >= fs/2 || n <= pad_len
                        x_smooth = x;
                        return
                    end
                    [b, a] = butter(N, fc / (fs/2)); % Direkt digital -> fc exakt
                    x_smooth = filtfilt(b, a, x);

                case 'Bessel'
                    N = round(param1);      % [-] Filterordnung
                    fc = param2;            % [Hz] Grenzfrequenz
                    if fc <= 0 || fc >= fs/2 || n < 3*N
                        x_smooth = x;
                        return
                    end
                    Wn = 2*pi*fc;           % [rad/s] analoge Grenzfrequenz
                    [num, den] = besself(N, Wn);
                    % Prewarping bei fc: sorgt dafuer, dass die digitale
                    % Grenzfrequenz exakt bei fc liegt (4. Argument = Match-Frequenz)
                    [numd, dend] = bilinear(num, den, fs, fc);
                    x_smooth = filtfilt(numd, dend, x);

                case 'Savitzky-Golay'
                    order = round(param1);  % [-] Polynomordnung
                    win = round(param2);    % [-] Fensterbreite (ungerade)
                    if mod(win, 2) == 0
                        win = win + 1;
                    end
                    win = max(win, order + 1 + mod(order + 1, 2));
                    if n <= win
                        x_smooth = x;
                        return
                    end
                    x_smooth = sgolayfilt(x, order, win);

                case 'Moving Average'
                    win = max(1, round(param1)); % [-] Fensterbreite
                    x_smooth = movmean(x, win);

                case 'Median'
                    win = round(param1);    % [-] Fensterbreite (ungerade)
                    if mod(win, 2) == 0
                        win = win + 1;
                    end
                    x_smooth = medfilt1(x, win);

                case 'Hampel'
                    % Ausreisser-Filter: ersetzt NUR Spikes (> n-Sigma vom lokalen
                    % Median), laesst das Signal sonst unveraendert. Ideal fuer
                    % V/omega -- kein Tiefpass-Effekt, kein Peak-Verlust.
                    win = max(1, round(param1)); % [-] Halbfenster
                    nsig = param2;               % [-] Sigma-Schwelle
                    if nsig <= 0
                        nsig = 3; % Standardwert nach Hampel-Konvention
                    end
                    x_smooth = hampel(x, win, nsig);

                otherwise
                    x_smooth = x;
            end
        end
        
        function row = get_smoothing_row_for_parameter(app, parameter)
            row = [];
            for k = 1:numel(app.SmoothingRows)

                if iscell(app.SmoothingRows)
                    currentRow = app.SmoothingRows{k};
                else
                    currentRow = app.SmoothingRows(k);
                end

                % Zieht 'parameter' und 'active' aus dem JS-Struct
                if strcmp(currentRow.parameter, parameter) && currentRow.active
                    row = currentRow;
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

            % Liest 'type', 'param1' und 'param2' aus dem JS-Struct
            y_out = app.apply_smoothing(y_raw, row.type, row.param1, row.param2, fs);
        end

        %% Export

        function export_Tire_Data(app)
            % EXPORT_TIRE_DATA Exportiert den aktuell geladenen Reifentest
            % als bereinigtes tireData-Objekt in eine .mat-Datei:
            %   - Sweeps, die durch Filter oder manuellen Ausschluss NICHT
            %     genutzt werden (~app.SweepIsUsed), werden komplett entfernt
            %   - Alle Kanaele werden mit der aktuell aktiven Glaettung
            %     (app.SmoothingRows) ueberschrieben
            %   - Nullpunkt-Korrektur (alpha0/mz0 aus app.ZeroOffset) wird
            %     fest in alpha/Mz eingerechnet, nicht nur fuers Plotten
            % Dialogfenster (uiputfile) erlaubt Speicherort UND Dateinamen
            % frei zu waehlen, vorbelegt mit "<Testname>_export_<Datum>".
            %
            % Autor: Lambo || Datum: 10.07.26

            if isempty(app.sweep)
                uialert(app.UIFigure, 'Kein Reifentest geladen - nichts zu exportieren.', 'Export nicht moeglich');
                return
            end

            if isempty(app.SweepIsUsed)
                mask = true(size(app.sweep)); % noch nicht gefiltert -> alles nutzen
            else
                mask = app.SweepIsUsed;
            end

            if ~any(mask)
                uialert(app.UIFigure, 'Alle Sweeps sind durch Filter/manuellen Ausschluss deaktiviert - nichts zu exportieren.', 'Export nicht moeglich');
                return
            end

            % 1. Ausgeschlossene Sweeps entfernen (Filter + Manuell)
            export_sweeps = app.sweep(mask);
            export_offsets = app.ZeroOffset(mask);

            % 2. Glaettung + Nullpunkt-Korrektur fest in die Kanaele einrechnen
            for k = 1:numel(export_sweeps)
                s = export_sweeps(k);

                % Glaettung je Kanal (no-op, falls keine aktive Smoothing-Row
                % fuer den jeweiligen Kanal existiert)
                for c = 1:numel(app.KNOWN_CHANNELS)
                    ch = app.KNOWN_CHANNELS{c};
                    try
                        s.(ch) = app.smooth_channel(s, ch, s.(ch));
                    catch
                        continue % Kanal in diesem tireData-Objekt nicht vorhanden
                    end
                end

                % Nullpunkt-Korrektur (Longitudinal/Combined/Undefined haben
                % laut compute_zero_offsets ohnehin alpha0_deg = mz0 = 0)
                s.alpha = s.alpha - deg2rad(export_offsets(k).alpha0_deg);
                s.Mz    = s.Mz - export_offsets(k).mz0;

                export_sweeps(k) = s;
            end

            % 3. Default-Dateinamen aus Testname + Exportdatum bauen
            if isempty(app.tire_file)
                base_name = "Tire";
            else
                [~, base_name, ~] = fileparts(app.tire_file);
                base_name = string(base_name);
            end
            date_str = string(datetime('now', 'Format', 'yyyyMMdd_HHmm'));
            default_name = base_name + "_export_" + date_str + ".mat";

            % 4. Speicherort + Dateiname per Dialog abfragen (frei editierbar)
            [file, location] = uiputfile('*.mat', 'Bereinigten Reifentest exportieren', default_name);
            if isequal(file, 0)
                return % Abgebrochen
            end

            tireData_export = export_sweeps; %#ok<NASGU> Name der gespeicherten Variable
            save(fullfile(location, file), 'tireData_export');

            uialert(app.UIFigure, ...
                sprintf('Export erfolgreich: %s (%d von %d Sweeps)', ...
                fullfile(location, file), numel(export_sweeps), numel(app.sweep)), ...
                'Export abgeschlossen', 'Icon', 'success');
        end

        %% Eigene Callbacks

        function StartupHTMLDataChanged(app, event)
            if isequal(event.Data, "start")
                delete(app.StartupHTML);   % Startup-Screen entfernen
                % app.MainPanel.Visible = 'on';   % Hauptansicht einblenden – Namen ggf. anpassen
            end
        end

        function FilterSmoothingHTMLDataChanged(app, event)

            % Holt das übergebene Daten-Struct aus der HTML-Komponente
            receivedData = app.FilterSmoothingHTML.Data;

            % 2. Filter-Daten konvertieren und in app.FilterRows einspeisen
            % (Hier adaptierst du die Struktur auf deine bestehende Backend-Logik)
            app.FilterRows = receivedData.filters;

            % 3. Smoothing-Daten konvertieren und in app.SmoothingRows einspeisen
            app.SmoothingRows = receivedData.smoothings;

            % 4. Zentraler Berechnungs- und Plot-Aufruf (kein Auto-Update mehr!)
            apply_filters(app);
        end

        function CorneringHTMLEventReceived(app, event)
            % CORNERINGHTMLEVENTRECEIVED Reagiert auf Events aus dem
            % Cornering-ECharts-Widget. Aktuell relevant fuer's Backend:
            % 'sweepUsedToggled' (aendert SweepIsUsed und damit auch
            % andere Plots/Tabs). 'modeChanged' und 'hideUnusedChanged'
            % sind rein visuelle Zustaende, die das Widget selbst haelt
            % -- hier ist nichts zu tun.
            %
            % Autor: Lambo || Datum: 08.07.26

            name = event.HTMLEventName;
            data = event.HTMLEventData;

            switch name
                case 'sweepUsedToggled'
                    if isempty(app.SweepIsUsed)
                        app.SweepIsUsed = true(size(app.sweep));
                    end
                    app.SweepIsUsed(data.origIndex) = logical(data.used);

                    app.plot_cornering_html();
                    % Falls andere Tabs SweepIsUsed ebenfalls
                    % beruecksichtigen sollen, hier zusaetzlich
                    % app.refresh_all_plots() aufrufen, sobald diese
                    % Funktion wieder aktiv ist.

                otherwise
                    % modeChanged, hideUnusedChanged: kein Backend-Bezug
            end
        end

    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)

            % Startup der App
            clc
            % addpath('html') % hier werden die HMTL functions später liegen

            % Erstellen der Javaskript Startmaske (Einblenden wenn alles
            % andere Fertig ist)
            app.StartupHTML = uihtml(app.UIFigure);
            app.StartupHTML.Position = [1 1 app.UIFigure.Position(3) app.UIFigure.Position(4)];
            app.StartupHTML.HTMLSource = fullfile(pwd, 'startup_screen.html');
            app.StartupHTML.DataChangedFcn = createCallbackFcn(app, @StartupHTMLDataChanged, true);
            drawnow

            % Erstellen der Javaskript Elemente für Filter und Smoothing
            app.FilterSmoothingHTML = uihtml(app.UIFigure);
            app.FilterSmoothingHTML.Position = [1 1 129 430];
            app.FilterSmoothingHTML.HTMLSource = fullfile(pwd, 'filter_smoothing.html');
            app.FilterSmoothingHTML.DataChangedFcn = createCallbackFcn(app, @FilterSmoothingHTMLDataChanged, true);

            % Erstellen der Javaskript Elemente für den Cornering Tab
            app.CorneringHTML = uihtml(app.CorneringTab_2);
            app.CorneringHTML.Position = [0 0 640 430];
            app.CorneringHTML.HTMLSource = fullfile(pwd, 'cornering_plot.html');
            app.CorneringHTML.HTMLEventReceivedFcn = createCallbackFcn(app, @CorneringHTMLEventReceived, true);

            % Erstellen der Javaskript Elemente für den Cornering Kennwerte
            app.Cornering_kennwerte_HTML = uihtml(app.CorneringKennwerteTab_2);
            app.Cornering_kennwerte_HTML.Position = [0 0 640 430];
            app.Cornering_kennwerte_HTML.HTMLSource = fullfile(pwd, 'cornering_kennwerte.html');

            % Erstellen der Javaskript Elemente für den Manuel Selector
            app.Manual_selection_html = uihtml(app.ManuelSelctionTab);
            app.Manual_selection_html.Position = [0 0 640 430];
            app.Manual_selection_html.HTMLSource = fullfile(pwd, 'manual_selection.html');

            % Erstellen der Javaskript Elemente für den test_prepocessing
            app.test_preprocessing_HTML = uihtml(app.TestPreprocessingTab);
            app.test_preprocessing_HTML.Position = [0 0 640 430];
            app.test_preprocessing_HTML.HTMLSource = fullfile(pwd, 'test_preprocessing.html');

            % Erstellen der Javaskript Elemente für den cold_to_hot
            app.cold_to_hot_HTML = uihtml(app.ColdtohotVerschleissTab);
            app.cold_to_hot_HTML.Position = [0 0 640 430];
            app.cold_to_hot_HTML.HTMLSource = fullfile(pwd, 'cold_to_hot.html');

            % Erstellen der Javaskript Elemente für den Manuel Selector
            app.camber_sweep_HTML = uihtml(app.CamberSweepTab_2);
            app.camber_sweep_HTML.Position = [0 0 640 430];
            app.camber_sweep_HTML.HTMLSource = fullfile(pwd, 'camber_sweep.html');

            % Erstellen der Javaskript Elemente für den rohdaten_explorer
            app.rohdaten_explorer_HTML = uihtml(app.RohdatenExplorerTab_2);
            app.rohdaten_explorer_HTML.Position = [0 0 640 430];
            app.rohdaten_explorer_HTML.HTMLSource = fullfile(pwd, 'rohdaten_explorer.html');

            % Startmaske explizit ganz nach vorne stacken
            uistack(app.StartupHTML, 'top')
            drawnow

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

            load_Tire_Data(app);
            apply_filters(app);
            % app.refresh_all_plots();

        end

        % Button pushed function: OpenDirectoryButton
        function OpenDirectoryButtonPushed(app, event)

            [file,location] = uigetfile;
            tire_file_from_button = fullfile(location, file);
            app.Test_file_directroy.Value = tire_file_from_button;
       
        end

        % Button pushed function: ExportButton
        function ExportButtonPushed(app, event)
            export_Tire_Data(app);
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

            % Create CorneringTab_2
            app.CorneringTab_2 = uitab(app.TabGroup2);
            app.CorneringTab_2.Title = 'Cornering';

            % Create CorneringKennwerteTab_2
            app.CorneringKennwerteTab_2 = uitab(app.TabGroup2);
            app.CorneringKennwerteTab_2.Title = 'Cornering Kennwerte';

            % Create CamberSweepTab_2
            app.CamberSweepTab_2 = uitab(app.TabGroup2);
            app.CamberSweepTab_2.Title = 'Camber Sweep';

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

            % Create ManuelSelctionTab
            app.ManuelSelctionTab = uitab(app.TabGroup2);
            app.ManuelSelctionTab.Title = 'Manuel Selction';

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
            app.Test_file_directroy.Position = [113 12 430 22];
            app.Test_file_directroy.Value = '''C:\Users\Danie\OneDrive\Desktop\Tire_Data_fitting_MF6.2\0_Tire_test_data\0_Reifen_43075\B2356run6.mat''';

            % Create LoadTireDataButton
            app.LoadTireDataButton = uibutton(app.AuswahlPanel, 'push');
            app.LoadTireDataButton.ButtonPushedFcn = createCallbackFcn(app, @LoadTireDataButtonPushed, true);
            app.LoadTireDataButton.Position = [550 11 89 23];
            app.LoadTireDataButton.Text = 'Load Tire Data';

            % Create ExportButton
            app.ExportButton = uibutton(app.AuswahlPanel, 'push');
            app.ExportButton.ButtonPushedFcn = createCallbackFcn(app, @ExportButtonPushed, true);
            app.ExportButton.Position = [646 11 115 23];
            app.ExportButton.Text = 'Export Tire Data';

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