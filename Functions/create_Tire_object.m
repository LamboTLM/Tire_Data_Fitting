function [tdnew] = create_Tire_object
% Erstellt ein tireData Object im SAE Koordinaten system

tdnew = tireData();                         % Anlegen des Objects
tdnew = tdnew.coordinateTransform("SAE");   % Definition des Koordinaten systems, später überschrieben

end
