%% STEP 3: Live Review mit File-Moving & Auto-Filter (Undefined & Cold)
%  1. Verschiebt automatisch "Undefined" Dateien.
%  2. Verschiebt automatisch zu kalte Reifen (Warmup).
%  3. Startet das interaktive Review für den Rest.

clear; clc;

% --- EINSTELLUNGEN ---
TEMP_MIN_THRESHOLD = 40; % [°C] Alles unter diesem Durchschnittswert gilt als Warmup

% --- 1. Pfad-Konfiguration ---
dir_inbox     = fullfile('2_Segments_splitted');
dir_accept    = fullfile('3_1_Segments_for_use');
dir_reject    = fullfile('3_2_Segments_discarded');
dir_warmup    = fullfile('3_2_Segments_discarded', 'Warmup');
dir_undefined = fullfile('3_2_Segments_discarded', 'Undefined');

% Check: Inbox da?
if ~exist(dir_inbox, 'dir')
    error('Eingangsordner "%s" nicht gefunden. Bitte erst Step 2 ausführen.', dir_inbox);
end

% Check: Zielordner erstellen
target_folders = {dir_accept, dir_reject, dir_warmup, dir_undefined};
for i = 1:length(target_folders)
    if ~exist(target_folders{i}, 'dir')
        mkdir(target_folders{i});
    end
end

%% --- 2. AUTO-MOVE: Undefined & Kalte Reifen aussortieren ---
fprintf('Starte Auto-Filter...\n');
files_all = dir(fullfile(dir_inbox, '*.mat'));

count_undef = 0;
count_cold  = 0;

% Ladebalken für User-Feedback, da das Laden dauern kann
hWait = waitbar(0, 'Prüfe Dateien auf Typ und Temperatur...');

for k = 1:length(files_all)
    fname = files_all(k).name;
    full_p = fullfile(dir_inbox, fname);
    
    waitbar(k/length(files_all), hWait, sprintf('Checke File %d/%d', k, length(files_all)));
    
    % A) Filter 1: Undefined (Check via Dateiname -> Schnell)
    if contains(fname, 'Undefined', 'IgnoreCase', true)
        movefile(full_p, dir_undefined);
        count_undef = count_undef + 1;
        continue; % Datei ist weg, weiter zur nächsten
    end
    
    % B) Filter 2: Temperatur (Muss geladen werden -> Langsamer)
    try
        tmp_check = load(full_p);
        if isfield(tmp_check, 'td')
            td_chk = tmp_check.td;
            
            % Temperatur prüfen (Variable TtreadI nutzen)
            if isprop(td_chk, 'TtreadI') && ~isempty(td_chk.TtreadI)
                mean_temp = mean(td_chk.TtreadI);
                
                if mean_temp < TEMP_MIN_THRESHOLD
                    movefile(full_p, dir_warmup);
                    count_cold = count_cold + 1;
                    continue; % Datei weg, weiter
                end
            end
        end
    catch
        % Falls Datei defekt, ignorieren wir sie hier erstmal
    end
end
close(hWait);

% Report
if (count_undef + count_cold) > 0
    fprintf('AUTO-FILTER BERICHT:\n');
    fprintf(' -> %d "Undefined" verschoben nach: %s\n', count_undef, dir_undefined);
    fprintf(' -> %d "Zu Kalt (<%.1f°C)" verschoben nach: %s\n', count_cold, TEMP_MIN_THRESHOLD, dir_warmup);
else
    fprintf(' -> Keine Dateien automatisch ausgefiltert.\n');
end


%% --- 3. GUI Setup ---
hFig = figure('Name', 'Tire Data Inspector', 'Units', 'normalized', ...
    'OuterPosition', [0 0 1 1], 'NumberTitle', 'off');

%% --- 4. Main Review Loop ---
while true
    % Inbox neu scannen (nachdem Filter durchgelaufen ist)
    files = dir(fullfile(dir_inbox, '*.mat'));
    
    if isempty(files)
        close(hFig);
        msgbox(sprintf('Inbox ist leer!\nAuto-Filter hat %d Dateien entfernt.', count_undef + count_cold), 'Fertig');
        break;
    end
    
    % Erste Datei nehmen
    current_file = files(1).name;
    full_path = fullfile(dir_inbox, current_file);
    
    % Laden
    try
        tmp = load(full_path);
        td = tmp.td;
    catch ME
        warning('Fehler beim Laden von %s: %s. Datei wird übersprungen/verschoben nach Rejected.', current_file, ME.message);
        movefile(full_path, dir_reject);
        continue;
    end
    
    % Visualisieren
    plot_detailed_view(td, current_file, length(files), hFig);
    
    % Entscheidung abwarten
    choice = 0;
    target = '';
    
    while choice == 0
        try
            waitforbuttonpress;
            if ~isvalid(hFig), return; end % Falls Fenster geschlossen wurde
            
            key = get(hFig, 'CurrentCharacter');
            switch lower(key)
                case 'y' % Yes -> Accept
                    choice = 1; target = dir_accept;
                    fprintf('[%s] -> Accepted\n', current_file);
                case 'n' % No -> Reject
                    choice = 2; target = dir_reject;
                    fprintf('[%s] -> Rejected\n', current_file);
                case 'w' % Warmup
                    choice = 3; target = dir_warmup;
                    fprintf('[%s] -> Warmup\n', current_file);
                case 'q' % Quit
                    close(hFig);
                    fprintf('Benutzerabbruch. Tschüss!\n');
                    return;
            end
        catch
            return;
        end
    end
    
    % Verschieben
    movefile(full_path, target);
end


%% --- 5. VISUALISIERUNGS-FUNKTION (7 Subplots) ---
function plot_detailed_view(td, filename, remaining, hFig)
    % Fokus auf Figur setzen
    set(0, 'CurrentFigure', hFig);
    t = tiledlayout(hFig, 7, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    
    % Titelzeile
    title(t, sprintf('File: %s | Remaining in Inbox: %d', filename, remaining), ...
        'Interpreter', 'none', 'FontSize', 14, 'FontWeight', 'bold');
    
    x = td.et;
    
    % --- 1. Slip Angle (Alpha) ---
    ax1 = nexttile;
    plot(x, rad2deg(td.alpha), 'b', 'LineWidth', 1.2);
    ylabel('Alpha [deg]'); grid on;
    if isprop(td, 'TestMethod'), mStr = td.TestMethod; else, mStr = 'Unknown'; end
    title(['Method: ' mStr], 'Color', 'k', 'FontWeight', 'bold');
    
    % --- 2. Slip Ratio (Kappa) ---
    ax2 = nexttile;
    plot(x, td.kappa, 'm', 'LineWidth', 1.2);
    ylabel('Kappa [-]'); grid on;
    
    % --- 3. Lateral Force (Fy) ---
    ax3 = nexttile;
    plot(x, td.Fy, 'Color', '#0072BD');
    ylabel('Fy [N]'); grid on;
    
    % --- 4. Longitudinal Force (Fx) ---
    ax4 = nexttile;
    plot(x, td.Fx, 'Color', '#D95319');
    ylabel('Fx [N]'); grid on;
    
    % --- 5. Vertical Load (Fz) ---
    ax5 = nexttile;
    plot(x, td.Fz, 'k');
    ylabel('Fz [N]'); grid on;
    meanFz = mean(td.Fz);
    yline(meanFz, 'r--', sprintf('Mean: %.0f N', meanFz), 'LabelVerticalAlignment', 'bottom');
    ylim([0, max(td.Fz)*1.2]);
    
    % --- 6. Speed & Temp ---
    ax6 = nexttile;
    yyaxis left;
    plot(x, td.V * 3.6, 'b-');
    ylabel('V [km/h]');
    set(gca, 'YColor', 'b');
    
    yyaxis right;
    temp = td.TtreadI; % Variable TtreadI wie gewünscht
    plot(x, temp, 'r-', 'LineWidth', 1);
    ylabel('Temp [°C]');
    set(gca, 'YColor', 'r');
    grid on; title('Conditions');
    
    % --- 7. Classification Flow (Visueller Check) ---
    ax7 = nexttile;
    SA = td.alpha; SL = td.kappa;
    n = min(length(SA), length(SL));
    cls = zeros(n,1);
    threshold_SA = deg2rad(0.5);
    threshold_SL = 0.02;
    for p=1:n
        isA = abs(SA(p)) > threshold_SA;
        isK = abs(SL(p)) > threshold_SL;
        if isA && isK, cls(p)=3;
        elseif isA, cls(p)=1;
        elseif isK, cls(p)=2;
        end
    end
    cls_smooth = medfilt1(cls, 51);
    
    hold on;
    plot(x(1:n), cls, '.', 'Color', [0.85 0.85 0.85], 'MarkerSize', 4);
    plot(x(1:n), cls_smooth, 'k-', 'LineWidth', 1.5);
    yticks([0 1 2 3]);
    yticklabels({'Inaktiv', 'Lat', 'Long', 'Comb'});
    ylabel('Algo-Class');
    grid on;
    ylim([-0.5 3.5]);
    title('Testing Method Algorithm Check');
    
    linkaxes([ax1 ax2 ax3 ax4 ax5 ax6 ax7], 'x');
    xlim([x(1) x(end)]);
end