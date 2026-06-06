%% Step 4: Validierung und Visualisierung des skalierten Modells
%
%  Vergleicht:
%    1) Basis-Fit (ungSkaliert) vs. Messdaten Basis-Reifen
%    2) Skaliertes Modell      vs. Messdaten Fx-Reifen
%    3) Grip-Envelope fuer verschiedene Setups

clear; clc; close all;
addpath("Functions");

%% ── Laden ────────────────────────────────────────────────────────────────
load('4_Tire_model_export/ScaledModel.mat');   % tm_scaled, k_fy, k_fx
load('2_Fitted_Model/Step2_FittedModel.mat');   % tm (unSkaliert), fit_meta

fprintf('Modell: %s\n', base_tire_id);
fprintf('k_Fy = %.4f,  k_Fx = %.4f\n\n', k_fy, k_fx);

%% ── 1. Fy Pure Kurven: Modell vs. Rohdaten ───────────────────────────────
fz_levels  = [400, 700, 1000, 1200];       % [N] Fz-Level zum Plotten
alpha_vec  = linspace(-14, 14, 200);       % [deg]
gamma_ref  = 0;                            % [deg] Sturz
pi_ref     = tm_scaled.INFLPRES;          % [Pa]

fig1 = figure('Name', 'Fy Pure Validation', 'Position', [50 50 1200 700]);
t = tiledlayout(2, 2, 'TileSpacing', 'compact');
title(t, sprintf('Fy Pure — Modell vs. Daten | k_{Fy} = %.4f', k_fy));

% Rohdaten laden fuer Vergleich
raw_lat = load_raw_data({'B2356run4.mat','B2356run6.mat'}, '0_Tire_test_data.mat');

for fi = 1:numel(fz_levels)
    ax = nexttile;
    hold on; grid on;
    fz_t = fz_levels(fi);

    % Rohdaten
    mask = abs(raw_lat.FZ + fz_t) < 80 & abs(raw_lat.SL) < 0.01 & ...
           raw_lat.TSTI > 40 & abs(raw_lat.IA) < 0.5;
    scatter(raw_lat.SA(mask), raw_lat.FY(mask), 4, [0.75 0.75 0.75], ...
            'DisplayName', 'Messdaten');

    % Modell (unSkaliert)
    fy_unscaled = eval_fy_pure(tm, alpha_vec, fz_t, gamma_ref, pi_ref);
    plot(alpha_vec, fy_unscaled, 'b--', 'LineWidth', 1.5, ...
         'DisplayName', sprintf('Basis-Fit (43075)'));

    % Modell (Skaliert)
    fy_scaled = eval_fy_pure(tm_scaled, alpha_vec, fz_t, gamma_ref, pi_ref);
    plot(alpha_vec, fy_scaled, 'r-', 'LineWidth', 2, ...
         'DisplayName', sprintf('Skaliert (k=%.3f)', k_fy));

    xlabel('Schraeglauffwinkel [deg]');
    ylabel('Fy [N]');
    title(sprintf('Fz = %d N', fz_t));
    legend('Location', 'northwest', 'FontSize', 8);
    ylim([-3000 3000]);
end

%% ── 2. Grip-Envelope 3D ──────────────────────────────────────────────────
fig2 = figure('Name', 'Grip Envelope', 'Position', [100 100 900 700]);
set(fig2, 'Color', [0.12 0.12 0.12]);
ax3d = axes('Color', [0.18 0.18 0.18], 'XColor','w','YColor','w','ZColor','w');
hold on; grid on;

fz_vec  = linspace(300, 1400, 12);
phi_vec = linspace(0, 2*pi, 72);
[Phi, Fz_mesh] = meshgrid(phi_vec, fz_vec);

setups = {
    deg2rad(0),  pi_ref,        '0° Sturz',  [0.2, 0.6, 1.0];
    deg2rad(-2), pi_ref,        '-2° Sturz', [1.0, 0.35, 0.2];
    deg2rad(0),  pi_ref*1.15,   '+15% Druck',[0.2, 0.9, 0.3];
};

handles = gobjects(size(setups,1),1);
for s = 1:size(setups,1)
    gamma_s = setups{s,1};
    press_s = setups{s,2};
    color_s = setups{s,4};

    FX_env = zeros(size(Phi));
    FY_env = zeros(size(Phi));

    state.y  = gamma_s;
    state.Pi = press_s;

    for ii = 1:size(Fz_mesh,1)
        for jj = 1:size(Fz_mesh,2)
            state.af = deg2rad(12) * cos(Phi(ii,jj));
            state.k  = 0.20        * sin(Phi(ii,jj));
            state.Fz = Fz_mesh(ii,jj);
            [fx, fy] = calc_magic_tire_forces(extract_params(tm_scaled), state);
            FX_env(ii,jj) = fx;
            FY_env(ii,jj) = fy;
        end
    end

    handles(s) = surf(FX_env, FY_env, Fz_mesh, ...
        'FaceColor', color_s, 'EdgeColor', color_s*0.7, ...
        'FaceAlpha', 0.25, 'DisplayName', setups{s,3});
end

xlabel('Fx [N]'); ylabel('Fy [N]'); zlabel('Fz [N]');
title('Grip-Envelope: Skaliertes Modell', 'Color','w');
view(45, 30);
legend(handles, 'TextColor','w', 'Color',[0.2 0.2 0.2], 'Location','northeastoutside');
line([0 0],[0 0],[min(fz_vec) max(fz_vec)], 'Color','w','LineStyle','--');

%% ── 3. Textueller Report ─────────────────────────────────────────────────
fprintf('\n══ Modell-Report ══════════════════════════════════════════════\n');
fprintf('  Basis-Fit Fy RMSE:   %.1f N\n', fit_meta.Fy_Pure_rmse);
if isfield(fit_meta,'Fx_Pure_rmse') && ~isnan(fit_meta.Fx_Pure_rmse)
    fprintf('  Basis-Fit Fx RMSE:   %.1f N\n', fit_meta.Fx_Pure_rmse);
end
fprintf('  k_Fy angewendet:     %.4f (-> %.1f%% Amplitude-Offset)\n', ...
        k_fy, abs(1-k_fy)*100);
fprintf('\n  Skalierte Parameter:\n');
fprintf('    PDY1: %.4f  PDY2: %.4f\n', tm_scaled.PDY1, tm_scaled.PDY2);
fprintf('    PDX1: %.4f  PDX2: %.4f\n', tm_scaled.PDX1, tm_scaled.PDX2);
fprintf('\n  Unangefasste Parameter (Form):\n');
fprintf('    PCY1: %.4f  PEY1: %.4f  PKY1: %.4f\n', ...
        tm_scaled.PCY1, tm_scaled.PEY1, tm_scaled.PKY1);
fprintf('═══════════════════════════════════════════════════════════════\n');

%% ══════════════════════════════════════════════════════════════════════════
%% Hilfsfunktionen
%% ══════════════════════════════════════════════════════════════════════════

function raw = load_raw_data(filenames, data_dir)
    raw.SA=[]; raw.FY=[]; raw.FZ=[]; raw.SL=[]; raw.IA=[]; raw.TSTI=[];
    for i = 1:numel(filenames)
        d = load(fullfile(data_dir, filenames{i}));
        raw.SA    = [raw.SA;    d.SA];
        raw.FY    = [raw.FY;    d.FY];
        raw.FZ    = [raw.FZ;    abs(d.FZ)];  % Betrag
        raw.SL    = [raw.SL;    d.SL];
        raw.IA    = [raw.IA;    d.IA];
        raw.TSTI  = [raw.TSTI;  d.TSTI];
    end
end


function fy = eval_fy_pure(tire_model, alpha_deg, fz, gamma_deg, pi_pa)
% Wertet Fy Pure aus dem MF-Modell aus (vereinfacht ueber tireModel.eval falls verfuegbar)
    fy = zeros(size(alpha_deg));
    p  = extract_params(tire_model);
    for i = 1:numel(alpha_deg)
        state.af = deg2rad(alpha_deg(i));
        state.k  = 0;
        state.Fz = fz;
        state.y  = deg2rad(gamma_deg);
        state.Pi = pi_pa;
        [~, fy(i)] = calc_magic_tire_forces(p, state);
    end
end


function p = extract_params(tm)
% Extrahiert alle benoetigten Parameter als Struct fuer calc_magic_tire_forces
    param_names = {'FNOMIN','NOMPRES', ...
        'PCX1','PDX1','PDX2','PDX3','PEX1','PEX2','PEX3','PEX4', ...
        'PKX1','PKX2','PKX3','PHX1','PHX2','PVX1','PVX2', ...
        'PPX1','PPX2','PPX3','PPX4', ...
        'PCY1','PDY1','PDY2','PDY3','PEY1','PEY2','PEY3','PEY4','PEY5', ...
        'PKY1','PKY2','PKY3','PKY4','PKY5','PKY6','PKY7', ...
        'PHY1','PHY2','PVY1','PVY2','PVY3','PVY4', ...
        'PPY1','PPY2','PPY3','PPY4','PPY5', ...
        'RBX1','RBX2','RBX3','RCX1','REX1','REX2','RHX1', ...
        'RBY1','RBY2','RBY3','RBY4','RCY1','REY1','REY2','RHY1','RHY2', ...
        'RVY1','RVY2','RVY3','RVY4','RVY5','RVY6', ...
        'LCX','LCY','LEX','LEY','LHX','LHY','LKX','LKY', ...
        'LMX','LMUX','LMUY','LVX','LVY','LYKA','LXAL'};
    for i = 1:numel(param_names)
        pn = param_names{i};
        if isprop(tm, pn) || isfield(tm, pn)
            p.(pn) = tm.(pn);
        else
            p.(pn) = 1.0;   % Default (Scaling-Faktor = 1 wenn nicht gesetzt)
        end
    end
end
