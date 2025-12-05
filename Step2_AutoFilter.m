%% STEP 2: Einzeldateien erzeugen & Testmethode bestimmen
%  Splittet die Daten, bestimmt den Typ (Lat/Long/Comb) und speichert
%  jede Messung als einzelne .mat Datei in den Inbox-Ordner.

clear; clc;

% --- Konfiguration ---
input_file = fullfile('1_All_Segments/', 'Step1_AllSegments.mat');

inbox_folder = fullfile('2_Segments_splitted');

% Daten laden
if ~isfile(input_file), error('Step 1 Datei fehlt!'); end
load(input_file); % Lädt 'all_segments'

fprintf('Verarbeite %d Segmente...\n', length(all_segments));

%% Hauptschleife
for i = 1:length(all_segments)
    td = all_segments(i);
    
    % 1. Filtern (Kurzer Check vor dem Speichern)
    % Wirf leere oder extrem kurze Schnipsel (< 0.5s) sofort weg
    if isempty(td.et) || (td.et(end) - td.et(1)) < 0.5
        continue; 
    end
    
    % 2. Test-Methode bestimmen (Deine Funktion)
    td = setTestingMethod_Smoothed(td, deg2rad(0.5), 0.02, 301);
    method_str = td.TestMethod; 
    
    % 3. Sprechenden Dateinamen generieren
    % Format: [Ursprungsdatei]_[SegmentNr]_[Methode].mat
    % Falls 'SourceFile' nicht im Objekt steht, nutzen wir einen Zähler
    if isprop(td, 'Comments') && ~isempty(td.Comments)
        [~, src_name, ~] = fileparts(td.Comments);
    else
        src_name = 'UnknownRun';
    end
    
    % Unerlaubte Zeichen aus Dateinamen entfernen
    src_name = regexprep(src_name, '[^a-zA-Z0-9]', '');
    
    filename = sprintf('%s_Seg%03d_%s.mat', src_name, i, method_str);
    full_path = fullfile(inbox_folder, filename);
    
    % 4. Speichern
    % Wir speichern das einzelne Objekt direkt in die Datei
    save(full_path, 'td');
    
    if mod(i, 50) == 0, fprintf('... %d verarbeitet\n', i); end
end

fprintf('Fertig! Alle Dateien liegen in "%s".\n', inbox_folder);