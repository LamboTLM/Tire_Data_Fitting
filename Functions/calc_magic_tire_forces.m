function [Fx, Fy] = calc_magic_tire_forces(tire_data, tire_state)
% calc_magic_tire_forces  Berechnet kombinierte Reifenkräfte Fx und Fy nach Pacejka MF 6.1.
%
% Inputs:
%   tire_data  : Struct mit Pacejka-Parametern und Skalierungsfaktoren
%                Pflichtfelder: FNOMIN, NOMPRES, alle P*/R*/L*-Parameter
%   tire_state : Struct mit aktuellem Reifenzustand
%                .k   Längsschlupf [-]
%                .af  Schräglaufwinkel [rad]
%                .Fz  Radlast [N]
%                .y   Sturzwinkel [rad]  (gamma)
%                .Pi  Reifeninnendruck [bar]
%
% Outputs:
%   Fx  Längskraft [N]  (kombiniert, inkl. Schräglauf-Einfluss G_xa)
%   Fy  Seitenkraft [N] (kombiniert, inkl. Längsschlupf-Einfluss G_yk)
%
% Hinweis: Bei Fz = 0 oder degenerierten Parametern (C_x/D_x/K_ya = 0)
%          werden Fx = 0 und Fy = 0 zurückgegeben (Schutz vor Division/0).

%% Dimensionslose Inkremente
Fz0 = tire_data.FNOMIN;
dfz = (tire_state.Fz - Fz0) ./ Fz0;
dpi = (tire_state.Pi - tire_data.NOMPRES) ./ tire_data.NOMPRES;

%% --- Fx (kombiniert) ---------------------------------------------------

% Horizontaler Versatz und Vertikalkraft-Offset (Längsrichtung)
S_hx = (tire_data.PHX1 + tire_data.PHX2 .* dfz) .* tire_data.LHX;
S_vx = (tire_data.PVX1 + tire_data.PVX2 .* dfz) .* tire_state.Fz .* tire_data.LVX .* tire_data.LMX;
S_hxa = tire_data.RHX1;  % Horizontalversatz des kombinierten Winkels

% Verschobene Eingangsgrößen
k_x = tire_state.k + S_hx;
a_s = tire_state.af + S_hxa;

% Längssteifigkeit (BUGFIX: PKX2 statt PEX2 in K_xk-Zeile)
K_xk = (tire_data.PKX1 + tire_data.PKX2 .* dfz) .* exp(tire_data.PKX3 .* dfz) ...
       .* (1 + tire_data.PPX1 .* dpi + tire_data.PPX2 .* dpi.^2) ...
       .* tire_state.Fz .* tire_data.LKX;

% Reibwert und Pacejka-Koeffizienten Fx
m_ux = (tire_data.PDX1 + tire_data.PDX2 .* dfz) ...
       .* (1 - tire_data.PDX3 .* tire_state.y.^2) ...
       .* (1 + tire_data.PPX3 .* dpi + tire_data.PPX4 .* dpi.^2) ...
       .* tire_data.LMUX;

C_x = tire_data.PCX1 .* tire_data.LCX;
D_x = m_ux .* tire_state.Fz;

% BUGFIX: E_x verwendet PEX1, PEX2, PEX4 (nicht PDX2 an zweiter Stelle)
E_x = (tire_data.PEX1 + tire_data.PEX2 .* dfz + tire_data.PEX3 .* dfz.^2) ...
      .* (1 - tire_data.PEX4 .* sign(k_x)) .* tire_data.LEX;

% Schutz vor Division durch 0 (C_x * D_x = 0 bei Fz=0 oder PCX1=0)
denom_Bx = C_x .* D_x;
if abs(denom_Bx) < eps
    Fx = 0;
    Fy = 0;
    return
end
B_x = K_xk ./ denom_Bx;

% Kombinationsfaktor G_xa (Schräglaufeinfluss auf Fx)
B_xa = (tire_data.RBX1 + tire_data.RBX3 .* tire_state.y.^2) ...
       .* cos(atan(tire_data.RBX2 .* tire_state.k)) .* tire_data.LXAL;
C_xa = tire_data.RCX1;
E_xa = tire_data.REX1 + tire_data.REX2 .* dfz;

Gxa_u = cos(C_xa .* atan(B_xa .* a_s  - E_xa .* (B_xa .* a_s  - atan(B_xa .* a_s))));
Gxa_l = cos(C_xa .* atan(B_xa .* S_hxa - E_xa .* (B_xa .* S_hxa - atan(B_xa .* S_hxa))));

% Schutz vor Division durch 0 im Weighting-Faktor
if abs(Gxa_l) < eps
    G_xa = 1;
else
    G_xa = Gxa_u ./ Gxa_l;
end

% Pacejka MF Fx (Grundkurve + Vertikalversatz, gewichtet mit G_xa)
Fx_pure = D_x .* sin(C_x .* atan(B_x .* k_x - E_x .* (B_x .* k_x - atan(B_x .* k_x)))) + S_vx;
Fx = Fx_pure .* G_xa;

%% --- Fy (kombiniert) ---------------------------------------------------

% Sturzsteifigkeit und Schräglaufsteifigkeit
K_yy = (tire_data.PKY6 + tire_data.PKY7 .* dfz) ...
       .* (1 + tire_data.PPY5 .* dpi) .* tire_state.Fz .* tire_data.LKY;

K_ya = tire_data.PKY1 .* Fz0 ...
       .* (1 + tire_data.PPY1 .* dpi) ...
       .* sin(tire_data.PKY4 .* atan(tire_state.Fz ...
            ./ ((tire_data.PKY2 + tire_data.PKY5 .* tire_state.y.^2) ...
                .* (1 + tire_data.PPY2 .* dpi) .* Fz0))) ...
       .* (1 - tire_data.PKY3 .* abs(tire_state.y)) .* tire_data.LKY;

% Schutz vor Division durch 0 (K_ya = 0 bei PKY1=0 oder Fz=0)
if abs(K_ya) < eps
    Fx = 0;
    Fy = 0;
    return
end

% Versatzterme (Sturz- und Grundversatz)
S_Vyg = tire_state.Fz .* (tire_data.PVY3 + tire_data.PVY4 .* dfz) ...
        .* tire_state.y .* tire_data.LKY .* tire_data.LMUY;
S_Hyy = (K_yy .* tire_state.y - S_Vyg) ./ K_ya;
S_Hy0 = (tire_data.PHY1 + tire_data.PHY2 .* dfz) .* tire_data.LHY;
S_Hy  = S_Hy0 + S_Hyy;

S_Vy0 = tire_state.Fz .* (tire_data.PVY1 + tire_data.PVY2 .* dfz) .* tire_data.LVY .* tire_data.LMUY;
S_Hk  = tire_data.RHY1 + tire_data.RHY2 .* dfz;
S_Vy  = S_Vy0 + S_Vyg;

% Verschobene Eingangsgrößen
a_y = tire_state.af + S_Hy;
k_s = tire_state.k  + S_Hk;

% Reibwert und Pacejka-Koeffizienten Fy
C_y  = tire_data.PCY1 .* tire_data.LCY;
mu_y = (tire_data.PDY1 + tire_data.PDY2 .* dfz) ...
       .* (1 - tire_data.PDY3 .* tire_state.y.^2) ...
       .* (1 + tire_data.PPY3 .* dpi + tire_data.PPY4 .* dpi.^2) ...
       .* tire_data.LMUY;
D_y  = mu_y .* tire_state.Fz;

E_y = (tire_data.PEY1 + tire_data.PEY2 .* dfz) ...
      .* (1 + tire_data.PEY5 .* tire_state.y.^2 ...
          - (tire_data.PEY3 + tire_data.PEY4 .* tire_state.y) .* sign(a_y)) ...
      .* tire_data.LEY;

% Schutz vor Division durch 0
denom_By = C_y .* D_y;
if abs(denom_By) < eps
    Fy = 0;
else
    B_y = K_ya ./ denom_By;

    % Kombinationsfaktor G_yk (Längsschlupfeinfluss auf Fy)
    B_yk = (tire_data.RBY1 + tire_data.RBY4 .* tire_state.y.^2) ...
           .* cos(atan(tire_data.RBY2 .* (tire_state.af - tire_data.RBY3))) .* tire_data.LYKA;
    C_yk = tire_data.RCY1;
    E_yk = tire_data.REY1 + tire_data.REY2 .* dfz;

    G_yk_num = cos(C_yk .* atan(B_yk .* k_s - E_yk .* (B_yk .* k_s - atan(B_yk .* k_s))));
    G_yk_den = cos(C_yk .* atan(B_yk .* S_Hk - E_yk .* (B_yk .* S_Hk - atan(B_yk .* S_Hk))));

    if abs(G_yk_den) < eps
        G_yk = 1;
    else
        G_yk = G_yk_num ./ G_yk_den;
    end

    % Spin-Versatzterm (Reifensturz-Kopplung)
    D_Vyk = mu_y .* tire_state.Fz ...
            .* (tire_data.RVY1 + tire_data.RVY2 .* dfz + tire_data.RVY3 .* tire_state.y) ...
            .* cos(atan(tire_data.RVY4 .* tire_state.af));
    S_Vyk = D_Vyk .* sin(tire_data.RVY5 .* atan(tire_data.RVY6 .* tire_state.k)) .* tire_data.LYKA;

    % Pacejka MF Fy (Grundkurve + Versätze, gewichtet mit G_yk)
    F_yp = D_y .* sin(C_y .* atan(B_y .* a_y - E_y .* (B_y .* a_y - atan(B_y .* a_y)))) + S_Vy;
    Fy   = G_yk .* F_yp + S_Vyk;
end

end