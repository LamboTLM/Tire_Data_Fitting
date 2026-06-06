%% TTC Reifen-Testdaten: Finaler Lightmode-Bericht
% Optimiert für den Ausdruck. Erstellt formatfüllende Seiten.

%% 1. Konfiguration
basePath = 'C:\Users\Danie\OneDrive\Desktop\Tire_Data_fitting_MF6.2\Visualisieren Rohdaten\0_Tire_test_data';
fileList = dir(fullfile(basePath, 'B2356run*.mat'));

% Globale Einstellungen für den Lightmode (Drucker-freundlich)
set(groot, 'defaultFigureColor', [1 1 1]);
set(groot, 'defaultAxesColor', [1 1 1]);
set(groot, 'defaultAxesXColor', [0 0 0]);
set(groot, 'defaultAxesYColor', [0 0 0]);
set(groot, 'defaultTextColor', [0 0 0]);
% Verhindert, dass MATLAB den schwarzen Screen-Hintergrund in den Export übernimmt
set(groot, 'defaultFigureInvertHardcopy', 'on'); 

%% 2. Verarbeitung
for i = 1:length(fileList)
    data = load(fullfile(fileList(i).folder, fileList(i).name));
    
    fprintf('\n\n---\n');
    fprintf('# Testlauf: %s\n', fileList(i).name);
    fprintf('**Reifen:** %s | **Typ:** %s\n', char(data.tireid), char(data.testid));

    %% A) Rohdaten-Übersicht (Ganze Seite)
    allFields = fieldnames(data);
    plotFields = allFields(structfun(@(x) isnumeric(x) && length(x) > 100, data));
    
    numPlots = length(plotFields);
    cols = 4; rows = ceil(numPlots/cols);
    
    % Fenster erstellen
    figRaw = figure('Units', 'normalized', 'Position', [0.05 0.05 0.9 0.8], 'Color', 'w');
    
    for j = 1:numPlots
        subplot(rows, cols, j);
        plot(data.(plotFields{j}), 'LineWidth', 1, 'Color', [0 0.3 0.7]); 
        
        title(plotFields{j}, 'Interpreter', 'none', 'FontSize', 8, 'Color', 'k');
        grid on;
        set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'FontSize', 7);
    end
    
    sgtitle(['Rohdaten Übersicht: ' fileList(i).name], 'Interpreter', 'none', 'Color', 'k');
    
    drawnow;
    snapnow; 
    close(figRaw);

    %% B) Analyse-Plot (Ganze Seite)
    figAna = figure('Units', 'normalized', 'Position', [0.05 0.05 0.9 0.8], 'Color', 'w');
    
    if isfield(data, 'SA') && isfield(data, 'FY')
        scatter(data.SA, data.FY, 15, data.FZ, 'filled');
        cb = colorbar; ylabel(cb, 'Radlast FZ [N]');
        xlabel('Schräglaufwinkel SA [deg]');
        ylabel('Seitenkraft FY [N]');
        title(['Analyse: Seitenkraft-Kennfeld - ' fileList(i).name], 'Interpreter', 'none');
    elseif isfield(data, 'SL') && isfield(data, 'FX')
        scatter(data.SL, data.FX, 15, data.FZ, 'filled');
        cb = colorbar; ylabel(cb, 'Radlast FZ [N]');
        xlabel('Schlupf SL [-]');
        ylabel('Längskraft FX [N]');
        title(['Analyse: Längskraft-Kennfeld - ' fileList(i).name], 'Interpreter', 'none');
    end
    
    set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
    grid on;
    drawnow;
    snapnow;
    close(figAna);
end

%% 3. Reset
set(groot, 'defaultFigureColor', 'remove');
set(groot, 'defaultAxesColor', 'remove');
set(groot, 'defaultFigureInvertHardcopy', 'remove');