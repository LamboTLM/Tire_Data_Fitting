function [Fx_max, Fy_max] = calc_magic_tire_forces(tire_data, Tire_state)
% Unpack Struc for easier Handling (Not Performance)
% calc_magic_tire_forces Berechnet die Kräftlimits Fx_max und Fy_max nach Pacejka.
%
% Inputs:
%   tire_data: Struct mit allen p- und r-Parametern (z.B. tire_data.p_Dy1)
%   tire_state: Struct mit allen Reifen zustandsWerten darunter:
%   kappa:     Längsschlupf [-]
%   alpha_F:   Schräglaufwinkel [rad]
%   Fz:        Radlast [N]
%   gamma:     Sturzwinkel [rad]
%   Pi:        Reifendruck

% Dimensionslose incerments
Fz0 = tire_data.FNOMIN;
dfz = (Tire_state.Fz - Fz0) ./ Fz0;
dpi = (Tire_state.Pi - tire_data.NOMPRES) ./ tire_data.NOMPRES;

%% Fx_max Combined
S_hx = (tire_data.PHX1 + tire_data.PHX2 .* dfz) .* tire_data.LHX;
S_vx = (tire_data.PVX1 + tire_data.PVX2 .* dfz) .* Tire_state.Fz .* tire_data.LVX .* tire_data.LMX;
S_hxa = tire_data.RHX1;

k_x = Tire_state.k + S_hx;
K_xk = (tire_data.PKX1 + tire_data.PKX2 .* dfz) .* exp(tire_data.PKX3 .* dfz) .* (1 + tire_data.PPX1 .* dpi + tire_data.PPX2 .* dpi.^2) .* Tire_state.Fz .* tire_data.LKX;
a_s = Tire_state.af + S_hxa;
m_ux = (tire_data.PDX1 + tire_data.PDX2 .* dfz) .* (1 - tire_data.PDX3 .* Tire_state.y.^2) .* (1 + tire_data.PPX3 .* dpi + tire_data.PPX4 .* dpi.^2) .* tire_data.LMUX;

C_x = tire_data.PCX1 .* tire_data.LCX;
D_x = m_ux .* Tire_state.Fz;
E_x = (tire_data.PEX1 + tire_data.PEX2 .* dfz + tire_data.PEX3 .* dfz.^2) .* (1 - tire_data.PEX4 .* sign(k_x)) .* tire_data.LEX;
B_x = K_xk ./ (C_x .* D_x);

B_xa = (tire_data.RBX1 + tire_data.RBX3 .* Tire_state.y.^2) .* cos(atan(tire_data.RBX2 .* Tire_state.k)) .* tire_data.LXAL;
C_xa = tire_data.RCX1;
E_xa = tire_data.REX1 + tire_data.REX2 .* dfz;

Gxa_u = cos( C_xa .* atan(B_xa .* a_s - E_xa .* (B_xa .* a_s - atan(B_xa .* a_s))));
Gxa_l = cos( C_xa .* atan (B_xa .* S_hxa - E_xa .* (B_xa .* S_hxa - atan(B_xa .* S_hxa))));

G_xa = Gxa_u ./ Gxa_l;

Fx_max = (D_x .* sin(C_x .* atan(B_x .* k_x - E_x .*(B_x .*k_x - atan(B_x .* k_x))))+S_vx) .* G_xa;

%% Fy max Combined

K_yy  = (tire_data.PKY6 + tire_data.PKY7 .* dfz) .* (1 + tire_data.PPY5 .* dpi) .* Tire_state.Fz .* tire_data.LKY;
K_ya = tire_data.PKY1 .* Fz0 .* (1 + tire_data.PPY1 .* dpi) .* sin(tire_data.PKY4 .* atan(Tire_state.Fz ./ ((tire_data.PKY2 + tire_data.PKY5 .* Tire_state.y.^2) .* (1 + tire_data.PPY2 .* dpi) .* Fz0))) .* (1 - tire_data.PKY3 .* abs(Tire_state.y)) .* tire_data.LKY;

S_Vyg = Tire_state.Fz .* (tire_data.PVY3 + tire_data.PVY4 .* dfz) .* Tire_state.y .* tire_data.LKY .* tire_data.LMUY;
S_Hyy = (K_yy .* Tire_state.y - S_Vyg) ./ K_ya ;
S_Hy0 = (tire_data.PHY1 + tire_data.PHY2 .* dfz) .* tire_data.LHY;
S_Hy  = S_Hy0 + S_Hyy;

S_Vy0 = Tire_state.Fz .* (tire_data.PVY1 + tire_data.PVY2 .* dfz) .* tire_data.LVY .* tire_data.LMUY;
S_Hk = tire_data.RHY1 + tire_data.RHY2 .* dfz;
S_Vy  = S_Vy0 + S_Vyg;

a_y = Tire_state.af + S_Hy;
k_s = Tire_state.k + S_Hk;

C_y = tire_data.PCY1 .* tire_data.LCY;
mu_y = (tire_data.PDY1 + tire_data.PDY2 .* dfz) .* (1 - tire_data.PDY3 .* Tire_state.y.^2) .* (1 + tire_data.PPY3 .* dpi + tire_data.PPY4 .* dpi.^2) .* tire_data.LMUY;
D_y = mu_y .* Tire_state.Fz;
E_y = (tire_data.PEY1 + tire_data.PEY2 .* dfz) .* (1 + tire_data.PEY5 .* Tire_state.y.^2 - (tire_data.PEY3 + tire_data.PEY4 .* Tire_state.y) .* sign(a_y)) .* tire_data.LEY;
B_y = K_ya ./ (C_y .* D_y);

B_yk = (tire_data.RBY1 + tire_data.RBY4 .* Tire_state.y.^2) .* cos(atan(tire_data.RBY2 .* (Tire_state.af - tire_data.RBY3))) .* tire_data.LYKA;
C_yk = tire_data.RCY1;
E_yk = tire_data.REY1 + tire_data.REY2 .* dfz;

G_yk_num = cos(C_yk .* atan(B_yk .* k_s - E_yk .* (B_yk .* k_s - atan(B_yk .* k_s))));
G_yk_den = cos(C_yk .* atan(B_yk .* S_Hk - E_yk .* (B_yk .* S_Hk - atan(B_yk .* S_Hk))));
G_yk = G_yk_num ./ G_yk_den;

D_Vyk = mu_y .* Tire_state.Fz .* (tire_data.RVY1 + tire_data.RVY2 .* dfz + tire_data.RVY3 .* Tire_state.y) .* cos(atan(tire_data.RVY4 .* Tire_state.af));
S_Vyk = D_Vyk .* sin(tire_data.RVY5 .* atan(tire_data.RVY6 .* Tire_state.k)) .* tire_data.LYKA;

F_yp = D_y .* sin(C_y .* atan(B_y .* a_y - E_y .* (B_y .* a_y - atan(B_y .* a_y)))) + S_Vy;
Fy_max = G_yk .* F_yp + S_Vyk;


end