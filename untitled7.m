%% TTC Data Report Generator (DIN A4 Word Export)
% Erstellt von: Gemini
% Zweck: Automatischer Plot und Metadaten-Export für TTC Reifen-Testdaten

%% 1. Konfiguration
% Dein spezifischer Pfad
basePath = 'C:\Users\Danie\OneDrive\Desktop\Tire_Data_fitting_MF6.2\0_Tire_test_data';
reportName = fullfile(basePath, 'TTC_Reifen_Testbericht.docx');

% Plot-Design (Darkmode-Präferenz)
plotBgColor = [0.15, 0.15, 0.15]; 
textColor = [1, 1, 1];

%% 2. Initialisierung
if ~exist(basePath, 'dir')
    error('Der angegebene Ordner wurde nicht gefunden: %s', basePath);
end

% Dateiliste abrufen
fileList = dir(fullfile(basePath));
if isempty(fileList)
    error('Keine passenden .mat Dateien im Ordner gefunden.');
end

% Report Generator Bibliotheken laden
import mlreportgen.dom.*;

% Dokument erstellen
doc = Document(reportName, 'docx');

% Seitenlayout auf DIN-A4 einstellen
section = doc.CurrentPageLayout;
section.PageSize.Height = '297mm';
section.PageSize.Width = '210mm';
section.PageMargins.Top = '15mm';
section.PageMargins.Bottom = '15mm';

fprintf('Starte Berichtserstellung für %d Dateien...\n', length(fileList));

%% 3. Verarbeitung der Dateien
for i = 1:length(fileList)
    currentFile = fullfile(fileList(i).folder, fileList(i).name);
    fprintf('Verarbeite: %s\n', fileList(i).name);
    
    % Daten laden
    data = load(currentFile);
    
    % --- Überschrift ---
    h = Heading(1, ['Testbericht: ' fileList(i).name]);
    h.Style = {Color('DarkBlue'), FontFamily('Arial')};
    append(doc, h);
    
    % --- Metadaten Tabelle ---
    % Wir extrahieren tireid, testid und source aus den geladenen Daten
    metaTable = Table({ ...
        'Parameter', 'Information'; ...
        'Datei', fileList(i).name; ...
        'Reifen ID', char(data.tireid); ...
        'Test Typ', char(data.testid); ...
        'Datenquelle', char(data.source) ...
    });
    metaTable.Style = {Border('solid'), Width('100%'), FontFamily('Arial'), FontSize('10pt')};
    metaTable.Attributes = {Attribute('align', 'center')};
    append(doc, metaTable);
    append(doc, Paragraph(' ')); % Abstand

    % --- Plot Erstellung ---
    % Figure im Hintergrund erstellen (Visible off)
    fig = figure('Visible', 'off', 'Color', plotBgColor, 'Units', 'pixels', 'Position', [100 100 800 500]);
    hold on;
    
    % Logik zur Auswahl der Daten (Cornering vs Drive/Brake)
    if isfield(data, 'SA') && isfield(data, 'FY') && contains(lower(char(data.testid)), 'cornering')
        % Seitenkraft-Plot
        plot(data.SA, data.FY, '.', 'Color', [0 0.7 1], 'MarkerSize', 4);
        xlabel('Schräglaufwinkel SA [deg]', 'Color', textColor);
        ylabel('Seitenkraft FY [N]', 'Color', textColor);
    elseif isfield(data, 'SL') && isfield(data, 'FX')
        % Längskraft-Plot
        plot(data.SL, data.FX, '.', 'Color', [1 0.5 0], 'MarkerSize', 4);
        xlabel('Schlupf SL [-]', 'Color', textColor);
        ylabel('Längskraft FX [N]', 'Color', textColor);
    end
    
    title(['Rohdaten-Visualisierung: ' fileList(i).name], 'Color', textColor);
    grid on;
    ax = gca;
    ax.Color = plotBgColor;
    ax.XColor = textColor;
    ax.YColor = textColor;
    ax.GridColor = [0.4 0.4 0.4];
    
    % Bild temporär speichern
    tempImg = fullfile(basePath, ['temp_plot_' num2str(i) '.png']);
    saveas(fig, tempImg);
    
    % In Word einfügen
    imgObj = Image(tempImg);
    imgObj.Width = '165mm';
    imgObj.Height = '100mm';
    append(doc, Paragraph(imgObj));
    
    % Seitenumbruch für die nächste Datei
    if i < length(fileList)
        append(doc, PageBreak());
    end
    
    % Aufräumen für diesen Durchgang
    close(fig);
    if exist(tempImg, 'file'), delete(tempImg); end
end

%% 4. Abschluss
close(doc);
fprintf('Fertig! Bericht wurde gespeichert unter:\n%s\n', reportName);

% Sicherheits-Pause für OneDrive-Sync
pause(1.5);

% Datei öffnen
if ispc && exist(reportName, 'file')
    winopen(reportName);
else
    fprintf('Hinweis: Datei konnte nicht automatisch geöffnet werden. Bitte manuell öffnen unter: %s\n', reportName);
end