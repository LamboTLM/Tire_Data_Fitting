function [tdnew] = populate_tire_object(tdnew, fsData)
%% Eingangsvariabeln
% tdnew ist ein leeres tireData Object
% fsData ist ein befülltest testdaten struc

%% Ausgangsvariabeln
% tdnew ist ein befülltes tiredata object

%% Function Code
% Preperation
[row, ~] = size(fsData.MX);

% --- Messdaten und Achsen (Umrechnung in SI-Einheiten) ---
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

% --- Statische Metadaten (Reifendimensionen und Testbedingungen) ---
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