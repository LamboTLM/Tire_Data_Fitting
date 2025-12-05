function tireObj_out = setTestingMethod_Smoothed(tireObj_in, threshold_SA, threshold_SL, filter_window)
% SETTESTINGMETHOD_SMOOTHED Bestimmt die TestingMethod basierend auf dem dominierenden
%                            glatten Klassifizierungs-Ergebnis der Zeitreihe.
%
% EINGABE:
%   tireObj_in: Ein tireData-Objekt oder Array von Objekten.
%   threshold_SA: Schwellenwert für Schlupfwinkel (z.B. 0.5 deg).
%   threshold_SL: Schwellenwert für Längsschlupf (z.B. 0.02).
%   filter_window: Fenstergröße für den Medianfilter (Muss ungerade sein).

%% 1. Standard-Werte und Konstanten
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

%% 2. Hauptschleife über alle Objekte
for k = 1:length(tireObj_in)
    current_obj = tireObj_in(k);

    % --- Daten extrahieren: Korrektur auf 'alpha' und 'kappa' ---
    SA_data = current_obj.alpha;
    SL_data = current_obj.kappa;

    % Vektoren synchronisieren
    minLen = min(length(SA_data), length(SL_data));
    SA_data = SA_data(1:minLen);
    SL_data = SL_data(1:minLen);
    numPoints = minLen;

    classificationVector = zeros(numPoints, 1);

    % --- 3. Punktweise Klassifizierung ---
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

    % --- 4. Klassifizierung glätten (Medianfilter) ---
    smoothedClassification = medfilt1(classificationVector, filter_window);

    % --- 5. Dominante Phase bestimmen (KORRIGIERTE Logik) ---

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

        % --- 6. TestingMethod zuweisen ---
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