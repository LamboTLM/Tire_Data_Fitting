classdef TTC_Reifentest_Viewer < matlab.apps.AppBase
    % TTC_REIFENTEST_VIEWER Dashboard-App zur Visualisierung der FSAE TTC
    % Round 9 Reifentestdaten (Cornering, Drive/Brake, Transient).
    % Corporate Design: Dynamics e.V. -- OTH Regensburg Formula Student Team, Car No. 62
    % Autor: Lambo || Datum: 06.07.2026
    %
    % Erweiterung ggue. Vorversion: Split- und Filter-Layer fuer TTC-Rohdaten.
    % Ablauf: Reifen waehlen -> .mat-Dateien laden -> Kanaele parsen ->
    % in Sweep-Segmente splitten (FZ/IA/P-Stufen) -> Kraft-/Momentkanaele
    % per Butterworth-Tiefpass filtern -> Ergebnis in FZ-/IA-Listboxen
    % waehlbar machen und plotten. Das Fitten (Magic Formula) folgt in
    % einem spaeteren Schritt und ist hier bewusst noch nicht enthalten.
    %
    % Hinweis: Code-View App (classdef < matlab.apps.AppBase). Direkt lauffaehig
    % per "TTC_Reifentest_Viewer" im Command Window. Fuer die grafische
    % App-Designer-Design-View siehe Erklaerung im Chat (kein .mlapp-Paket).

    %% Properties -- UI-Komponenten
    properties (Access = public)
        UIFigure            matlab.ui.Figure
        MainGridLayout      matlab.ui.container.GridLayout

        HeaderPanel         matlab.ui.container.Panel
        HeaderGridLayout    matlab.ui.container.GridLayout
        TitleLabel          matlab.ui.control.Label
        SubtitleLabel       matlab.ui.control.Label

        ControlPanel        matlab.ui.container.Panel
        ControlGridLayout   matlab.ui.container.GridLayout
        TireDropDownLabel   matlab.ui.control.Label
        TireDropDown        matlab.ui.control.DropDown
        InfoLabel           matlab.ui.control.Label

        TabGroup                matlab.ui.container.TabGroup
        CorneringTab             matlab.ui.container.Tab
        CorneringKennwerteTab    matlab.ui.container.Tab
        CamberSweepTab           matlab.ui.container.Tab
        DriveBrakeTab            matlab.ui.container.Tab
        CombinedSlipTab          matlab.ui.container.Tab
        ColdToHotTab             matlab.ui.container.Tab
        TransientTab             matlab.ui.container.Tab
        SpeedVergleichTab        matlab.ui.container.Tab
        RohdatenExplorerTab      matlab.ui.container.Tab
    end

    %% Properties -- interne Daten (kein UI)
    properties (Access = private)
        Theme struct = struct()           % Dynamics e.V. Corporate-Design-Konstanten
        TabComponents struct = struct()   % Achsen/Filter-Handles je Tab
        TireList cell                     % Reifen/Rim-Kombinationen aus RunGuide Round 9

        RunGuideMap containers.Map        % Reifenname -> Struct mit .mat-Dateipfaden
        FilterCfg struct = struct()       % Butterworth-Filter- und Split-Konfiguration
        PlotChannelMap containers.Map     % TabKey -> {xChannel, yChannel} je Achse
        TestTypeForTab containers.Map     % TabKey -> zugehoerige Testart

        TireDataStore struct = struct()   % geladene+gesplittete+gefilterte Daten (aktueller Reifen)
        ActiveTireName char = ''
    end

    %% Methods -- Aufbau
    methods (Access = private)

        function init_theme(app)
            % Dynamics e.V. Corporate Design
            app.Theme.BgDark      = [27  27  27]  / 255;  % Eerie Black
            app.Theme.AccentRed   = [199 34  41]  / 255;  % Fire Engine Red
            app.Theme.BgPanel     = [42  42  42]  / 255;  % Jet
            app.Theme.TextWhite   = [1 1 1];
            app.Theme.RawGray     = [0.6 0.6 0.6];        % Farbe fuer Rohdaten-Overlay
            app.Theme.GridColor   = [0.55 0.55 0.55];
            app.Theme.FontHeading = 'Rift Bold Italic';   % Fallback: Systemfont falls nicht installiert
            app.Theme.FontSub     = 'Rift Light';
            app.Theme.FontBody    = 'Segoe UI';
        end

        function init_tire_list(app)
            % Physische Reifen/Rim-Kombinationen laut RunGuide_Round9 (14 Stueck)
            app.TireList = { ...
                'Hoosier 43075 16.0x7.5-10 R20 - Rim 6"'; ...
                'Hoosier 43075 16.0x7.5-10 R20 - Rim 7"'; ...
                'Hoosier 43070 16.0x6.0-10 R20 - Rim 6"'; ...
                'Hoosier 43070 16.0x6.0-10 R20 - Rim 7"'; ...
                'Hoosier 43100 18.0x6.0-10 R20 - Rim 6"'; ...
                'Hoosier 43100 18.0x6.0-10 R20 - Rim 7"'; ...
                'Goodyear D0571 18.0x6.5-10 - Rim 6"'; ...
                'Goodyear D0571 18.0x6.5-10 - Rim 7"'; ...
                'MRF 18x6.0-10 ZTD1 - Rim 6"'; ...
                'MRF 18x6.0-10 ZTD1 - Rim 7"'; ...
                'Hoosier 43164 20.5x7.0-13 R20 - Rim 7"'; ...
                'Hoosier 43164 20.5x7.0-13 R20 - Rim 8"'; ...
                'Goodyear D2704 20.0x7.0-13 - Rim 7"'; ...
                'Goodyear D2704 20.0x7.0-13 - Rim 8"'};
        end

        function init_run_guide_map(app)
            % TODO Lambo: Pfade an die tatsaechliche Round-9-Ordnerstruktur
            % anpassen (z.B. 'data/Round9/Run123.mat'). Solange ein Pfad leer
            % oder nicht auffindbar ist, zeigt die App fuer diese Testart
            % einfach "keine Daten" an, statt abzustuerzen.
            app.RunGuideMap = containers.Map();
            for k = 1:numel(app.TireList)
                tire_name = app.TireList{k};
                app.RunGuideMap(tire_name) = struct( ...
                    'Cornering',  '', ...
                    'DriveBrake', '', ...
                    'Transient',  '');
            end
        end

        function init_filter_config(app)
            % Konfiguration fuer Sweep-Splitting und Tiefpassfilterung.
            % Alles an einer Stelle -- passt zu deinem Konfigurationsblock-Stil.
            app.FilterCfg.SampleRate_Hz          = 50;   % TTC Round 9 Standard-Abtastrate
            app.FilterCfg.CutoffFreq_Hz           = 3;    % Grenzfrequenz Butterworth-Tiefpass
            app.FilterCfg.FilterOrder             = 2;    % Butterworth-Ordnung
            app.FilterCfg.ChannelsToFilter         = {'FX', 'FY', 'FZ', 'MZ', 'MX'};
            app.FilterCfg.SweepEdgeThreshold_FZ    = 50;   % [N]   Schwelle Stufenerkennung
            app.FilterCfg.SweepEdgeThreshold_IA    = 0.3;  % [deg] Schwelle Stufenerkennung
            app.FilterCfg.SweepEdgeThreshold_P     = 0.5;  % [psi] Schwelle Stufenerkennung
            app.FilterCfg.MinSweepSamples          = 25;   % Mindestlaenge eines Segments
        end

        function init_plot_channel_map(app)
            % Legt je Tab fest, welche Kanaele auf welcher Achse geplottet
            % werden (x-Kanal, y-Kanal als gefilterter Kanalname).
            app.PlotChannelMap = containers.Map();
            app.PlotChannelMap('Cornering')  = {{'SA', 'FY_gefiltert'}, ...
                                                 {'SA', 'MZ_gefiltert'}, ...
                                                 {'SA', 'MX_gefiltert'}};
            app.PlotChannelMap('DriveBrake') = {{'SL', 'FX_gefiltert'}};
            app.PlotChannelMap('Transient')  = {{'ET', 'FY_gefiltert'}, ...
                                                 {'ET', 'SA'}, ...
                                                 {'ET', 'V'}};
            % CorneringKennwerte, CamberSweep, CombinedSlip, ColdToHot,
            % SpeedVergleich, RohdatenExplorer: folgen in einem naechsten
            % Schritt (Kennwert-Berechnung bzw. Mehrkanal-/Dropdown-Logik).
            % Ohne Eintrag hier bleiben die zugehoerigen Achsen leer.
        end

        function init_test_type_map(app)
            % Ordnet jedem Tab die TTC-Testart zu, aus der er seine Daten bezieht
            app.TestTypeForTab = containers.Map( ...
                {'Cornering', 'CorneringKennwerte', 'CamberSweep', 'DriveBrake', ...
                 'CombinedSlip', 'ColdToHot', 'Transient', 'SpeedVergleich', 'RohdatenExplorer'}, ...
                {'Cornering', 'Cornering', 'Cornering', 'DriveBrake', ...
                 'DriveBrake', 'Cornering', 'Transient', 'DriveBrake', 'Cornering'});
        end

        function style_axes(app, ax, plot_spec)
            % Einheitliches Dynamics e.V. Dark-Theme fuer eine uiaxes-Instanz
            ax.Color     = app.Theme.BgPanel;
            ax.XColor    = app.Theme.TextWhite;
            ax.YColor    = app.Theme.TextWhite;
            ax.GridColor = app.Theme.GridColor;
            ax.Box       = 'on';
            grid(ax, 'on');

            ax.FontName = app.Theme.FontBody;

            title(ax, plot_spec.Title,  'Color', app.Theme.TextWhite, ...
                'FontName', app.Theme.FontSub, 'FontWeight', 'bold');
            xlabel(ax, plot_spec.XLabel, 'Color', app.Theme.TextWhite);
            ylabel(ax, plot_spec.YLabel, 'Color', app.Theme.TextWhite);
        end

        function tab_data = build_plot_tab(app, parent_tab, plot_specs, tab_key)
            % Einheitliches Layout fuer einen Analyse-Tab:
            % links Filter-Panel (FZ/IA-Auswahl + Rohdaten-Overlay), rechts Achsen-Stapel
            parent_tab.BackgroundColor = app.Theme.BgDark;

            tab_grid = uigridlayout(parent_tab, [1, 2]);
            tab_grid.ColumnWidth = {180, '1x'};
            tab_grid.BackgroundColor = app.Theme.BgDark;

            filter_panel = uipanel(tab_grid, 'Title', 'Filter');
            filter_panel.Layout.Row = 1;
            filter_panel.Layout.Column = 1;
            filter_panel.BackgroundColor = app.Theme.BgPanel;
            filter_panel.ForegroundColor = app.Theme.AccentRed;
            filter_panel.FontName = app.Theme.FontSub;
            filter_panel.FontWeight = 'bold';

            filter_grid = uigridlayout(filter_panel, [5, 1]);
            filter_grid.RowHeight = {20, '1x', 20, '1x', 24};
            filter_grid.BackgroundColor = app.Theme.BgPanel;

            lbl_fz = uilabel(filter_grid, 'Text', 'FZ [N]:');
            lbl_fz.FontColor = app.Theme.TextWhite;
            fz_listbox = uilistbox(filter_grid, 'Items', {}, 'Multiselect', 'on');
            fz_listbox.BackgroundColor = app.Theme.BgDark;
            fz_listbox.FontColor = app.Theme.TextWhite;
            fz_listbox.UserData = tab_key;
            fz_listbox.ValueChangedFcn = createCallbackFcn(app, @on_filter_selection_changed, true);

            lbl_ia = uilabel(filter_grid, 'Text', 'IA [deg]:');
            lbl_ia.FontColor = app.Theme.TextWhite;
            ia_listbox = uilistbox(filter_grid, 'Items', {}, 'Multiselect', 'on');
            ia_listbox.BackgroundColor = app.Theme.BgDark;
            ia_listbox.FontColor = app.Theme.TextWhite;
            ia_listbox.UserData = tab_key;
            ia_listbox.ValueChangedFcn = createCallbackFcn(app, @on_filter_selection_changed, true);

            raw_checkbox = uicheckbox(filter_grid, 'Text', 'Rohdaten ueberlagern', 'Value', false);
            raw_checkbox.FontColor = app.Theme.TextWhite;
            raw_checkbox.UserData = tab_key;
            raw_checkbox.ValueChangedFcn = createCallbackFcn(app, @on_filter_selection_changed, true);

            num_axes = numel(plot_specs);
            axes_grid = uigridlayout(tab_grid, [num_axes, 1]);
            axes_grid.Layout.Row = 1;
            axes_grid.Layout.Column = 2;
            axes_grid.BackgroundColor = app.Theme.BgDark;

            ax = gobjects(num_axes, 1);
            for k = 1:num_axes
                ax(k) = uiaxes(axes_grid);
                ax(k).Layout.Row = k;
                app.style_axes(ax(k), plot_specs(k));
            end

            tab_data.FilterPanel     = filter_panel;
            tab_data.FZListBox       = fz_listbox;
            tab_data.IAListBox       = ia_listbox;
            tab_data.ShowRawCheckBox = raw_checkbox;
            tab_data.Axes            = ax;
        end

        function createComponents(app)
            % Hauptfenster
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1300 800];
            app.UIFigure.Name = 'TTC Reifentest Viewer - Round 9';
            app.UIFigure.Color = app.Theme.BgDark;

            app.MainGridLayout = uigridlayout(app.UIFigure, [3, 1]);
            app.MainGridLayout.RowHeight = {60, 60, '1x'};
            app.MainGridLayout.RowSpacing = 4;
            app.MainGridLayout.BackgroundColor = app.Theme.BgDark;

            % -- Header-Bar: Dynamics e.V. Branding --
            app.HeaderPanel = uipanel(app.MainGridLayout);
            app.HeaderPanel.Layout.Row = 1;
            app.HeaderPanel.BackgroundColor = app.Theme.AccentRed;
            app.HeaderPanel.BorderType = 'none';

            app.HeaderGridLayout = uigridlayout(app.HeaderPanel, [1, 2]);
            app.HeaderGridLayout.ColumnWidth = {'1x', '2x'};
            app.HeaderGridLayout.BackgroundColor = app.Theme.AccentRed;

            app.TitleLabel = uilabel(app.HeaderGridLayout, 'Text', 'DYNAMICS e.V.');
            app.TitleLabel.FontName = app.Theme.FontHeading;
            app.TitleLabel.FontSize = 22;
            app.TitleLabel.FontWeight = 'bold';
            app.TitleLabel.FontColor = app.Theme.TextWhite;

            app.SubtitleLabel = uilabel(app.HeaderGridLayout, ...
                'Text', 'Reifentest Viewer -- FSAE TTC Round 9  |  Car No. 62');
            app.SubtitleLabel.FontName = app.Theme.FontSub;
            app.SubtitleLabel.FontSize = 13;
            app.SubtitleLabel.FontColor = app.Theme.TextWhite;
            app.SubtitleLabel.HorizontalAlignment = 'right';

            % -- Kontrollzeile: globale Reifen-Auswahl --
            app.ControlPanel = uipanel(app.MainGridLayout, 'Title', 'Auswahl');
            app.ControlPanel.Layout.Row = 2;
            app.ControlPanel.BackgroundColor = app.Theme.BgPanel;
            app.ControlPanel.ForegroundColor = app.Theme.AccentRed;
            app.ControlPanel.FontName = app.Theme.FontSub;
            app.ControlPanel.FontWeight = 'bold';

            app.ControlGridLayout = uigridlayout(app.ControlPanel, [1, 3]);
            app.ControlGridLayout.ColumnWidth = {60, 340, '1x'};
            app.ControlGridLayout.BackgroundColor = app.Theme.BgPanel;

            app.TireDropDownLabel = uilabel(app.ControlGridLayout, 'Text', 'Reifen:');
            app.TireDropDownLabel.FontColor = app.Theme.TextWhite;
            app.TireDropDown = uidropdown(app.ControlGridLayout);
            app.TireDropDown.Items = app.TireList;
            app.TireDropDown.BackgroundColor = app.Theme.BgDark;
            app.TireDropDown.FontColor = app.Theme.TextWhite;
            app.TireDropDown.ValueChangedFcn = createCallbackFcn(app, @on_tire_changed, true);

            app.InfoLabel = uilabel(app.ControlGridLayout, 'Text', '');
            app.InfoLabel.HorizontalAlignment = 'right';
            app.InfoLabel.FontColor = app.Theme.TextWhite;

            % -- Tab-Gruppe --
            app.TabGroup = uitabgroup(app.MainGridLayout);
            app.TabGroup.Layout.Row = 3;

            app.CorneringTab          = uitab(app.TabGroup, 'Title', 'Cornering');
            app.CorneringKennwerteTab = uitab(app.TabGroup, 'Title', 'Cornering-Kennwerte');
            app.CamberSweepTab        = uitab(app.TabGroup, 'Title', 'Camber-Sweep');
            app.DriveBrakeTab         = uitab(app.TabGroup, 'Title', 'Drive/Brake');
            app.CombinedSlipTab       = uitab(app.TabGroup, 'Title', 'Combined Slip');
            app.ColdToHotTab          = uitab(app.TabGroup, 'Title', 'Cold-to-Hot / Verschleiss');
            app.TransientTab          = uitab(app.TabGroup, 'Title', 'Transient');
            app.SpeedVergleichTab     = uitab(app.TabGroup, 'Title', 'Speed-Vergleich');
            app.RohdatenExplorerTab   = uitab(app.TabGroup, 'Title', 'Rohdaten-Explorer');

            % Tags = TabKeys, damit Callbacks (z.B. Tab-Wechsel) den
            % passenden Eintrag in TabComponents/PlotChannelMap finden
            app.CorneringTab.Tag          = 'Cornering';
            app.CorneringKennwerteTab.Tag = 'CorneringKennwerte';
            app.CamberSweepTab.Tag        = 'CamberSweep';
            app.DriveBrakeTab.Tag         = 'DriveBrake';
            app.CombinedSlipTab.Tag       = 'CombinedSlip';
            app.ColdToHotTab.Tag          = 'ColdToHot';
            app.TransientTab.Tag          = 'Transient';
            app.SpeedVergleichTab.Tag     = 'SpeedVergleich';
            app.RohdatenExplorerTab.Tag   = 'RohdatenExplorer';

            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @on_tab_changed, true);

            % -- Tab-Inhalte inkl. korrekter Achsbeschriftung --
            app.TabComponents.Cornering = app.build_plot_tab(app.CorneringTab, [ ...
                struct('Title', 'Seitenkraft vs. Schraeglaufwinkel', ...
                       'XLabel', 'Schraeglaufwinkel SA [deg]', 'YLabel', 'Seitenkraft FY [N]'); ...
                struct('Title', 'Rueckstellmoment vs. Schraeglaufwinkel', ...
                       'XLabel', 'Schraeglaufwinkel SA [deg]', 'YLabel', 'Rueckstellmoment MZ [Nm]'); ...
                struct('Title', 'Sturzmoment vs. Schraeglaufwinkel', ...
                       'XLabel', 'Schraeglaufwinkel SA [deg]', 'YLabel', 'Sturzmoment MX [Nm]')], 'Cornering');

            app.TabComponents.CorneringKennwerte = app.build_plot_tab(app.CorneringKennwerteTab, [ ...
                struct('Title', 'Schraeglaufsteifigkeit vs. Radlast', ...
                       'XLabel', 'Radlast FZ [N]', 'YLabel', 'Schraeglaufsteifigkeit C_\alpha [N/deg]'); ...
                struct('Title', 'Reibwert-Peak vs. Radlast', ...
                       'XLabel', 'Radlast FZ [N]', 'YLabel', '\mu_{y,peak} [-]')], 'CorneringKennwerte');

            app.TabComponents.CamberSweep = app.build_plot_tab(app.CamberSweepTab, ...
                struct('Title', 'Seitenkraft vs. Sturzwinkel (SA = 0 deg)', ...
                       'XLabel', 'Sturzwinkel IA [deg]', 'YLabel', 'Seitenkraft FY [N]'), 'CamberSweep');

            app.TabComponents.DriveBrake = app.build_plot_tab(app.DriveBrakeTab, ...
                struct('Title', 'Laengskraft vs. Schlupf', ...
                       'XLabel', 'Schlupf SL [-]', 'YLabel', 'Laengskraft FX [N]'), 'DriveBrake');

            app.TabComponents.CombinedSlip = app.build_plot_tab(app.CombinedSlipTab, ...
                struct('Title', 'Kraftschluss-Diagramm (Friction Circle)', ...
                       'XLabel', 'Laengskraft FX [N]', 'YLabel', 'Seitenkraft FY [N]'), 'CombinedSlip');

            app.TabComponents.ColdToHot = app.build_plot_tab(app.ColdToHotTab, [ ...
                struct('Title', 'Cold-to-Hot Verlauf', ...
                       'XLabel', 'Schraeglaufwinkel SA [deg]', 'YLabel', 'Seitenkraft FY [N]'); ...
                struct('Title', '12 psi Vergleich: Neu vs. Gebraucht', ...
                       'XLabel', 'Schraeglaufwinkel SA [deg]', 'YLabel', 'Seitenkraft FY [N]')], 'ColdToHot');

            app.TabComponents.Transient = app.build_plot_tab(app.TransientTab, [ ...
                struct('Title', 'Seitenkraft-Transiente nach Step-Steer', ...
                       'XLabel', 'Zeit ET [s]', 'YLabel', 'Seitenkraft FY [N]'); ...
                struct('Title', 'Schraeglaufwinkel-Verlauf', ...
                       'XLabel', 'Zeit ET [s]', 'YLabel', 'Schraeglaufwinkel SA [deg]'); ...
                struct('Title', 'Geschwindigkeitsverlauf', ...
                       'XLabel', 'Zeit ET [s]', 'YLabel', 'Geschwindigkeit V [mph]')], 'Transient');

            app.TabComponents.SpeedVergleich = app.build_plot_tab(app.SpeedVergleichTab, [ ...
                struct('Title', 'Seitenkraft vs. Schraeglaufwinkel bei versch. Geschwindigkeiten', ...
                       'XLabel', 'Schraeglaufwinkel SA [deg]', 'YLabel', 'Seitenkraft FY [N]'); ...
                struct('Title', 'Laengskraft vs. Schlupf bei versch. Geschwindigkeiten', ...
                       'XLabel', 'Schlupf SL [-]', 'YLabel', 'Laengskraft FX [N]')], 'SpeedVergleich');

            app.TabComponents.RohdatenExplorer = app.build_plot_tab(app.RohdatenExplorerTab, ...
                struct('Title', 'Rohdaten-Kanalverlauf', ...
                       'XLabel', 'Zeit ET [s]', 'YLabel', 'Kanalwert (Auswahl folgt)'), 'RohdatenExplorer');

            app.UIFigure.Visible = 'on';
        end

    end

    %% Methods -- Datenverarbeitung (Laden, Splitten, Filtern)
    methods (Access = private)

        function tire_data = load_and_process_tire(app, tire_name)
            % Laedt, splittet und filtert alle verfuegbaren Testarten fuer einen Reifen
            file_paths = app.RunGuideMap(tire_name);
            test_types = {'Cornering', 'DriveBrake', 'Transient'};
            tire_data = struct();

            for k = 1:numel(test_types)
                test_type = test_types{k};
                file_path = file_paths.(test_type);

                if isempty(file_path) || ~isfile(file_path)
                    tire_data.(test_type) = struct('Sweeps', [], 'Verfuegbar', false);
                    continue
                end

                raw    = app.load_ttc_matfile(file_path);
                parsed = app.parse_raw_struct(raw);
                sweeps = app.split_into_sweeps(parsed, test_type);
                sweeps = app.filter_sweeps(sweeps);

                tire_data.(test_type) = struct('Sweeps', sweeps, 'Verfuegbar', true);
            end
        end

        function raw = load_ttc_matfile(~, file_path)
            % Generischer TTC-Loader: liest .mat und gibt Struct aller enthaltenen
            % Variablen zurueck (Round 9 legt Kanaele meist als Top-Level-Variablen ab).
            raw = load(file_path);
        end

        function parsed = parse_raw_struct(~, raw)
            % Ordnet die Rohvariablen den Standard-TTC-Kanalnamen zu und
            % erzwingt Spaltenvektoren. TODO Lambo: Aliase ergaenzen, falls
            % deine Round-9-Dateien andere Variablennamen verwenden.
            channel_map = { ...
                'ET',   {'ET', 'time', 'Time'}; ...
                'V',    {'V', 'speed'}; ...
                'SA',   {'SA', 'slipangle'}; ...
                'IA',   {'IA', 'camber'}; ...
                'SL',   {'SL', 'SR', 'slipratio'}; ...
                'FZ',   {'FZ'}; ...
                'FX',   {'FX'}; ...
                'FY',   {'FY'}; ...
                'MZ',   {'MZ'}; ...
                'MX',   {'MX'}; ...
                'RL',   {'RL'}; ...
                'RE',   {'RE'}; ...
                'N',    {'N'}; ...
                'P',    {'P', 'pressure'}; ...
                'TSTC', {'TSTC'}; ...
                'TSTI', {'TSTI'}; ...
                'TSTO', {'TSTO'}};

            parsed = struct();
            raw_fields = fieldnames(raw);

            for k = 1:size(channel_map, 1)
                target_name = channel_map{k, 1};
                aliases = channel_map{k, 2};
                match_idx = find(ismember(lower(raw_fields), lower(aliases)), 1);

                if ~isempty(match_idx)
                    parsed.(target_name) = raw.(raw_fields{match_idx})(:);
                end
            end

            if ~isfield(parsed, 'ET')
                error('parse_raw_struct:MissingChannel', ...
                    'Zeitkanal ET konnte nicht gefunden werden - Rohdatenstruktur pruefen.');
            end
        end

        function sweeps = split_into_sweeps(app, parsed, test_type)
            % Segmentiert den Run anhand von Stufenaenderungen in FZ/IA/P in
            % einzelne Sweep-Abschnitte (ein Segment = eine Testkombination).
            n_samples = numel(parsed.ET);
            is_edge = false(n_samples, 1);

            if isfield(parsed, 'FZ')
                is_edge = is_edge | [false; abs(diff(parsed.FZ)) > app.FilterCfg.SweepEdgeThreshold_FZ];
            end
            if isfield(parsed, 'IA')
                is_edge = is_edge | [false; abs(diff(parsed.IA)) > app.FilterCfg.SweepEdgeThreshold_IA];
            end
            if isfield(parsed, 'P')
                is_edge = is_edge | [false; abs(diff(parsed.P)) > app.FilterCfg.SweepEdgeThreshold_P];
            end

            edge_idx = [1; find(is_edge); n_samples + 1];
            sweeps = struct('Data', {}, 'TestType', {}, 'FZ_Level', {}, 'IA_Level', {}, 'P_Level', {});

            for k = 1:numel(edge_idx) - 1
                idx_start = edge_idx(k);
                idx_end   = edge_idx(k + 1) - 1;

                if (idx_end - idx_start + 1) < app.FilterCfg.MinSweepSamples
                    continue
                end

                segment = app.slice_struct(parsed, idx_start:idx_end);

                sweeps(end + 1) = struct( ...
                    'Data', segment, ...
                    'TestType', test_type, ...
                    'FZ_Level', app.robust_level(segment, 'FZ'), ...
                    'IA_Level', app.robust_level(segment, 'IA'), ...
                    'P_Level', app.robust_level(segment, 'P')); %#ok<AGROW>
            end
        end

        function sweeps = filter_sweeps(app, sweeps)
            % Wendet einen phasenneutralen Butterworth-Tiefpass auf die
            % Kraft-/Momentkanaele jedes Sweep-Segments an (filtfilt = keine
            % Phasenverschiebung, wichtig fuer spaeteres Fitting).
            if isempty(sweeps)
                return
            end

            [filt_b, filt_a] = butter(app.FilterCfg.FilterOrder, ...
                app.FilterCfg.CutoffFreq_Hz / (app.FilterCfg.SampleRate_Hz / 2), 'low');

            for k = 1:numel(sweeps)
                for ch = app.FilterCfg.ChannelsToFilter
                    channel_name = ch{1};
                    min_len = 3 * app.FilterCfg.FilterOrder;

                    if isfield(sweeps(k).Data, channel_name) && numel(sweeps(k).Data.(channel_name)) > min_len
                        raw_signal = sweeps(k).Data.(channel_name);
                        sweeps(k).Data.([channel_name '_gefiltert']) = filtfilt(filt_b, filt_a, raw_signal);
                    end
                end
            end
        end

        function level = robust_level(~, segment, channel_name)
            % Robuster Kennwert (Median) eines Segments fuer die Stufenerkennung
            if isfield(segment, channel_name)
                level = median(segment.(channel_name), 'omitnan');
            else
                level = NaN;
            end
        end

        function segment = slice_struct(~, parsed, idx_range)
            % Schneidet alle Kanaele eines geparsten Structs auf denselben Indexbereich
            field_names = fieldnames(parsed);
            segment = struct();
            for k = 1:numel(field_names)
                segment.(field_names{k}) = parsed.(field_names{k})(idx_range);
            end
        end

        function populate_filter_listboxes(app)
            % Fuellt FZ-/IA-Listboxen jedes Tabs mit den in den Daten
            % tatsaechlich vorkommenden Stufen (gerundet, eindeutig, sortiert)
            tab_keys = fieldnames(app.TabComponents);

            for k = 1:numel(tab_keys)
                tab_key = tab_keys{k};
                if ~isKey(app.TestTypeForTab, tab_key)
                    continue
                end

                test_type = app.TestTypeForTab(tab_key);
                tab_data = app.TabComponents.(tab_key);

                if ~isfield(app.TireDataStore, test_type) || ~app.TireDataStore.(test_type).Verfuegbar
                    tab_data.FZListBox.Items = {};
                    tab_data.IAListBox.Items = {};
                    continue
                end

                sweeps = app.TireDataStore.(test_type).Sweeps;
                if isempty(sweeps)
                    tab_data.FZListBox.Items = {};
                    tab_data.IAListBox.Items = {};
                    continue
                end

                fz_levels = unique(round([sweeps.FZ_Level]));
                ia_levels = unique(round([sweeps.IA_Level], 1));

                tab_data.FZListBox.Items = cellstr(num2str(fz_levels(:)));
                tab_data.IAListBox.Items = cellstr(num2str(ia_levels(:)));
                tab_data.FZListBox.Value = tab_data.FZListBox.Items;
                tab_data.IAListBox.Value = tab_data.IAListBox.Items;
            end
        end

        function refresh_all_plots(app)
            tab_keys = fieldnames(app.TabComponents);
            for k = 1:numel(tab_keys)
                app.refresh_tab_plot(tab_keys{k});
            end
        end

        function refresh_tab_plot(app, tab_key)
            % Zeichnet die gefilterten (und optional rohen) Kurven fuer die
            % aktuell in FZ-/IA-Listbox gewaehlten Stufen. Tabs ohne Eintrag
            % in PlotChannelMap werden uebersprungen (folgen spaeter).
            if ~isfield(app.TabComponents, tab_key) ...
                    || ~isKey(app.TestTypeForTab, tab_key) ...
                    || ~isKey(app.PlotChannelMap, tab_key)
                return
            end

            test_type = app.TestTypeForTab(tab_key);
            if ~isfield(app.TireDataStore, test_type) || ~app.TireDataStore.(test_type).Verfuegbar
                return
            end

            sweeps = app.TireDataStore.(test_type).Sweeps;
            tab_data = app.TabComponents.(tab_key);
            channel_pairs = app.PlotChannelMap(tab_key);

            selected_fz = str2double(tab_data.FZListBox.Value);
            selected_ia = str2double(tab_data.IAListBox.Value);
            show_raw = tab_data.ShowRawCheckBox.Value;

            for ax_idx = 1:numel(channel_pairs)
                x_channel = channel_pairs{ax_idx}{1};
                y_channel = channel_pairs{ax_idx}{2};
                y_channel_raw = erase(y_channel, '_gefiltert');
                ax = tab_data.Axes(ax_idx);

                cla(ax);
                hold(ax, 'on');

                for k = 1:numel(sweeps)
                    fz_ok = isempty(selected_fz) || any(abs(round(sweeps(k).FZ_Level) - selected_fz) < 1);
                    ia_ok = isempty(selected_ia) || any(abs(round(sweeps(k).IA_Level, 1) - selected_ia) < 0.05);

                    if ~(fz_ok && ia_ok)
                        continue
                    end

                    if show_raw && isfield(sweeps(k).Data, y_channel_raw) && isfield(sweeps(k).Data, x_channel)
                        plot(ax, sweeps(k).Data.(x_channel), sweeps(k).Data.(y_channel_raw), ...
                            'Color', app.Theme.RawGray, 'LineWidth', 0.6);
                    end

                    if isfield(sweeps(k).Data, x_channel) && isfield(sweeps(k).Data, y_channel)
                        plot(ax, sweeps(k).Data.(x_channel), sweeps(k).Data.(y_channel), ...
                            'Color', app.Theme.AccentRed, 'LineWidth', 1.2);
                    end
                end

                hold(ax, 'off');
            end
        end

    end

    %% Methods -- Callbacks
    methods (Access = private)

        function on_tire_changed(app, ~)
            % Laedt fuer den neu gewaehlten Reifen alle Testarten, splittet
            % und filtert sie und aktualisiert danach UI und Plots.
            tire_name = app.TireDropDown.Value;
            app.InfoLabel.Text = sprintf('Lade Daten: %s ...', tire_name);
            drawnow;

            try
                app.TireDataStore = app.load_and_process_tire(tire_name);
                app.ActiveTireName = tire_name;
                app.populate_filter_listboxes();
                app.refresh_all_plots();
                app.InfoLabel.Text = sprintf('Ausgewaehlt: %s', tire_name);
            catch ME
                app.InfoLabel.Text = sprintf('Fehler beim Laden: %s', ME.message);
            end
        end

        function on_filter_selection_changed(app, event)
            % Wird von FZ-/IA-Listbox und "Rohdaten ueberlagern"-Checkbox ausgeloest
            tab_key = event.Source.UserData;
            app.refresh_tab_plot(tab_key);
        end

        function on_tab_changed(app, event)
            % Stellt sicher, dass ein frisch geoeffneter Tab aktuell ist,
            % auch wenn die Daten seit dem letzten Besuch neu geladen wurden
            tab_key = event.NewValue.Tag;
            app.refresh_tab_plot(tab_key);
        end

    end

    %% Methods -- App-Erstellung/-Zerstoerung
    methods (Access = public)

        function app = TTC_Reifentest_Viewer
            app.init_theme();
            app.init_tire_list();
            app.init_run_guide_map();
            app.init_filter_config();
            app.init_plot_channel_map();
            app.init_test_type_map();
            app.createComponents();

            if ~isempty(app.TireList)
                app.TireDropDown.Value = app.TireList{1};
                app.on_tire_changed([]);
            end

            registerApp(app, app.UIFigure);
        end

        function delete(app)
            delete(app.UIFigure);
        end

    end
end