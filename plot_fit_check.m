%% plot_fit_check.m – Umfassende Reifenmodell Diagnose (Dark Mode)
%
%  Plots:
%   Fig 1:  Fy Pure – Modell vs. Messdaten
%   Fig 2:  Fx Pure – Modell vs. Messdaten
%   Fig 3:  Kurvensteifigkeit Cα vs. Fz + Normierte Fy-Kurven
%   Fig 4:  Schlupfsteifigkeit Cκ vs. Fz + Normierte Fx-Kurven
%   Fig 5:  Peak-Kräfte vs. Fz (Fy_peak, Fx_peak, mu_y, mu_x)
%   Fig 6:  G-Faktor Diagnostik (G_xa vs. kappa, G_yk vs. alpha)
%   Fig 7:  Combined Fy & Fx – Modell vs. Daten
%   Fig 8:  Reibungsellipse bei mehreren Fz-Levels
%   Fig 9:  Residuen-Analyse (Fy und Fx)
%   Fig 10: Sturz-Sensitivität (Camber Sweep)

close all;
clc;
addpath("Functions");

%% ── Laden ─────────────────────────────────────────────────────────────────
load('2_Fitted_Model/Step2_FittedModel.mat');  % tm, fit_meta, processed_tires
load('1_All_Segments/Step1_Overview.mat');      % processed_tires (konsistent)

fprintf('Modell: %s\n', tm.Name);
fprintf('Gefittet am: %s\n\n', fit_meta.FittedOn);

%% ── Segmente laden ────────────────────────────────────────────────────────
n_lat  = [processed_tires.n_lateral];
n_long = [processed_tires.n_longitudinal];
n_comb = [processed_tires.n_combined];
[~, idx_fy]   = max(n_lat);
[~, idx_fx]   = max(n_long);
[~, idx_comb] = max(n_comb);

td_lat  = load_segs(processed_tires(idx_fy).out_file,   'Lateral');
td_long = load_segs(processed_tires(idx_fx).out_file,   'Longitudinal');
td_comb = load_segs(processed_tires(idx_comb).out_file, 'Combined');

fprintf('Segmente: Lateral=%d  Long.=%d  Combined=%d\n\n', ...
        numel(td_lat), numel(td_long), numel(td_comb));

%% ── Parameter & Sweep-Vektoren ────────────────────────────────────────────
p         = get_params(tm);
alpha_vec = linspace(-0.25, 0.25, 200);     % [rad]
kappa_vec = linspace(-0.40, 0.40, 200);     % [-]
alpha_deg = rad2deg(alpha_vec);
kappa_pct = kappa_vec * 100;
fz_levels = [400, 650, 900, 1150];
gamma_ref = 0;
pi_ref    = tm.INFLPRES;
Fz0       = tm.FNOMIN;

% Fz Sweep für Steifigkeitskurven
fz_sweep  = linspace(100, 1400, 60);

% Farben: bright palette für Dark Mode
clr = [0.27 0.72 0.95;   % Blau
       0.95 0.60 0.10;   % Orange
       0.35 0.90 0.35;   % Grün
       0.95 0.35 0.35];  % Rot

%% ══════════════════════════════════════════════════════════════════════════
%% Fig 1: Fy Pure – Modell vs. Messdaten
%% ══════════════════════════════════════════════════════════════════════════
if numel(td_lat) > 0
    fig1 = new_fig('Fy Pure', [50 50 1000 600]);
    tiledlayout(2, 2, 'TileSpacing','compact','Padding','compact');

    for fi = 1:4
        ax = nexttile; dark_ax(ax);
        hold on; grid on;
        fz = fz_levels(fi);

        % Messdaten (grau)
        for i = 1:numel(td_lat)
            scatter(rad2deg(td_lat(i).alpha), td_lat(i).Fy, 2, ...
                    [0.45 0.45 0.45], 'HandleVisibility','off');
        end

        % Modell
        fy_m = sweep_fy(p, alpha_vec, fz, gamma_ref, pi_ref);
        plot(alpha_deg, fy_m, 'Color', clr(fi,:), 'LineWidth', 2.0, ...
             'DisplayName', sprintf('Fz=%dN', fz));

        % Steifigkeit annotieren (slope bei alpha=0)
        C_alpha = diff_at_zero(alpha_vec, fy_m);
        text(0.05, 0.12, sprintf('Cα = %.0f N/rad', C_alpha), ...
             'Units','normalized','Color',[0.85 0.85 0.85],'FontSize',8);

        xlabel('α [°]'); ylabel('Fy [N]');
        title(sprintf('Fz = %d N', fz), 'Color','w');
        legend('Location','best','TextColor','w','Color',[0.15 0.15 0.15]);
        xline(0,'Color',[0.5 0.5 0.5],'LineStyle','--','HandleVisibility','off');
        yline(0,'Color',[0.5 0.5 0.5],'LineStyle','--','HandleVisibility','off');
    end
    sgtitle(sprintf('Fy Pure | %s | RMSE=%.1fN', ...
            processed_tires(idx_fy).tire_id, fit_meta.Fy_Pure_rmse), ...
            'Color','w','FontSize',11,'Interpreter','none');
end

%% ══════════════════════════════════════════════════════════════════════════
%% Fig 2: Fx Pure – Modell vs. Messdaten
%% ══════════════════════════════════════════════════════════════════════════
if numel(td_long) > 0
    fig2 = new_fig('Fx Pure', [70 50 1000 600]);
    tiledlayout(2, 2, 'TileSpacing','compact','Padding','compact');

    for fi = 1:4
        ax = nexttile; dark_ax(ax);
        hold on; grid on;
        fz = fz_levels(fi);

        for i = 1:numel(td_long)
            scatter(td_long(i).kappa*100, td_long(i).Fx, 2, ...
                    [0.45 0.45 0.45],'HandleVisibility','off');
        end

        fx_m = sweep_fx(p, kappa_vec, fz, gamma_ref, pi_ref);
        plot(kappa_pct, fx_m, 'Color', clr(fi,:), 'LineWidth', 2.0, ...
             'DisplayName', sprintf('Fz=%dN', fz));

        C_kappa = diff_at_zero(kappa_vec, fx_m);
        text(0.05, 0.12, sprintf('Cκ = %.0f N', C_kappa), ...
             'Units','normalized','Color',[0.85 0.85 0.85],'FontSize',8);

        xlabel('κ [%]'); ylabel('Fx [N]');
        title(sprintf('Fz = %d N', fz), 'Color','w');
        legend('Location','best','TextColor','w','Color',[0.15 0.15 0.15]);
        xline(0,'Color',[0.5 0.5 0.5],'LineStyle','--','HandleVisibility','off');
        yline(0,'Color',[0.5 0.5 0.5],'LineStyle','--','HandleVisibility','off');
    end
    sgtitle(sprintf('Fx Pure | %s | RMSE=%.1fN', ...
            processed_tires(idx_fx).tire_id, fit_meta.Fx_Pure_rmse), ...
            'Color','w','FontSize',11,'Interpreter','none');
end

%% ══════════════════════════════════════════════════════════════════════════
%% Fig 3: Kurvensteifigkeit Cα vs. Fz + Normierte Fy-Kurven
%% ══════════════════════════════════════════════════════════════════════════
fig3 = new_fig('Cornering Stiffness', [90 50 1100 500]);
tiledlayout(1, 2, 'TileSpacing','compact','Padding','compact');

% 3a: Cα vs. Fz
ax3a = nexttile; dark_ax(ax3a); hold on; grid on;
C_alpha_arr = zeros(size(fz_sweep));
for fi = 1:numel(fz_sweep)
    fy_m = sweep_fy(p, alpha_vec, fz_sweep(fi), gamma_ref, pi_ref);
    C_alpha_arr(fi) = diff_at_zero(alpha_vec, fy_m);
end
plot(fz_sweep, C_alpha_arr, 'Color', clr(1,:), 'LineWidth', 2.5);
% Datenpunkte aus Messung
if numel(td_lat) > 0
    c_meas = []; fz_meas = [];
    for i = 1:numel(td_lat)
        al = td_lat(i).alpha; fy = td_lat(i).Fy; fz = td_lat(i).Fz;
        if numel(al) > 5
            [~,iz] = min(abs(al));
            if iz > 2 && iz < numel(al)-1
                dfy = (fy(iz+1)-fy(iz-1)) / (al(iz+1)-al(iz-1));
                c_meas(end+1) = dfy;  %#ok<AGROW>
                fz_meas(end+1) = mean(fz);  %#ok<AGROW>
            end
        end
    end
    if ~isempty(c_meas)
        scatter(fz_meas, c_meas, 40, [0.95 0.95 0.4], 'filled', 'DisplayName','Messung');
        legend('Modell','Messung','TextColor','w','Color',[0.15 0.15 0.15]);
    end
end
xlabel('Fz [N]'); ylabel('Cα [N/rad]');
title('Kurvensteifigkeit vs. Radlast','Color','w');

% 3b: Normierte Fy/Fz vs. alpha (Self-similarity)
ax3b = nexttile; dark_ax(ax3b); hold on; grid on;
for fi = 1:numel(fz_levels)
    fz = fz_levels(fi);
    fy_m = sweep_fy(p, alpha_vec, fz, gamma_ref, pi_ref);
    plot(alpha_deg, fy_m/fz, 'Color', clr(fi,:), 'LineWidth', 1.8, ...
         'DisplayName', sprintf('Fz=%dN', fz));
end
% Messdaten normiert
if numel(td_lat) > 0
    for i = 1:numel(td_lat)
        fz_mean = mean(td_lat(i).Fz);
        scatter(rad2deg(td_lat(i).alpha), td_lat(i).Fy/fz_mean, 1, ...
                [0.40 0.40 0.40],'HandleVisibility','off');
    end
end
xlabel('α [°]'); ylabel('Fy/Fz = μy [-]');
title('Normierte Fy-Kurven (Self-similarity)','Color','w');
legend('Location','best','TextColor','w','Color',[0.15 0.15 0.15]);
xline(0,'Color',[0.5 0.5 0.5],'LineStyle','--','HandleVisibility','off');
yline(0,'Color',[0.5 0.5 0.5],'LineStyle','--','HandleVisibility','off');
sgtitle('Kurvensteifigkeit & Normierung','Color','w','FontSize',11);

%% ══════════════════════════════════════════════════════════════════════════
%% Fig 4: Schlupfsteifigkeit Cκ vs. Fz + Normierte Fx-Kurven
%% ══════════════════════════════════════════════════════════════════════════
fig4 = new_fig('Slip Stiffness', [110 50 1100 500]);
tiledlayout(1, 2, 'TileSpacing','compact','Padding','compact');

ax4a = nexttile; dark_ax(ax4a); hold on; grid on;
C_kappa_arr = zeros(size(fz_sweep));
for fi = 1:numel(fz_sweep)
    fx_m = sweep_fx(p, kappa_vec, fz_sweep(fi), gamma_ref, pi_ref);
    C_kappa_arr(fi) = diff_at_zero(kappa_vec, fx_m);
end
plot(fz_sweep, C_kappa_arr, 'Color', clr(2,:), 'LineWidth', 2.5);
xlabel('Fz [N]'); ylabel('Cκ [N]');
title('Schlupfsteifigkeit vs. Radlast','Color','w');

ax4b = nexttile; dark_ax(ax4b); hold on; grid on;
for fi = 1:numel(fz_levels)
    fz = fz_levels(fi);
    fx_m = sweep_fx(p, kappa_vec, fz, gamma_ref, pi_ref);
    plot(kappa_pct, fx_m/fz, 'Color', clr(fi,:), 'LineWidth', 1.8, ...
         'DisplayName', sprintf('Fz=%dN', fz));
end
if numel(td_long) > 0
    for i = 1:numel(td_long)
        fz_mean = mean(td_long(i).Fz);
        scatter(td_long(i).kappa*100, td_long(i).Fx/fz_mean, 1, ...
                [0.40 0.40 0.40],'HandleVisibility','off');
    end
end
xlabel('κ [%]'); ylabel('Fx/Fz = μx [-]');
title('Normierte Fx-Kurven','Color','w');
legend('Location','best','TextColor','w','Color',[0.15 0.15 0.15]);
xline(0,'Color',[0.5 0.5 0.5],'LineStyle','--','HandleVisibility','off');
yline(0,'Color',[0.5 0.5 0.5],'LineStyle','--','HandleVisibility','off');
sgtitle('Schlupfsteifigkeit & Normierung','Color','w','FontSize',11);

%% ══════════════════════════════════════════════════════════════════════════
%% Fig 5: Peak-Kräfte vs. Fz
%% ══════════════════════════════════════════════════════════════════════════
fig5 = new_fig('Peak Forces', [130 50 1100 500]);
tiledlayout(1, 2, 'TileSpacing','compact','Padding','compact');

fy_peak = zeros(size(fz_sweep));
fx_peak = zeros(size(fz_sweep));
for fi = 1:numel(fz_sweep)
    fy_peak(fi) = max(sweep_fy(p, alpha_vec, fz_sweep(fi), gamma_ref, pi_ref));
    fx_peak(fi) = max(sweep_fx(p, kappa_vec, fz_sweep(fi), gamma_ref, pi_ref));
end

ax5a = nexttile; dark_ax(ax5a); hold on; grid on;
plot(fz_sweep, fy_peak,           'Color',clr(1,:),'LineWidth',2.0,'DisplayName','Fy_{peak}');
plot(fz_sweep, fy_peak./fz_sweep, 'Color',clr(2,:),'LineWidth',1.5,'LineStyle','--','DisplayName','μy');
ylabel('Fy_{peak} [N]  /  μy [-]'); xlabel('Fz [N]');
title('Lateraler Grip vs. Radlast','Color','w');
legend('TextColor','w','Color',[0.15 0.15 0.15],'Location','northwest');

ax5b = nexttile; dark_ax(ax5b); hold on; grid on;
plot(fz_sweep, fx_peak,           'Color',clr(3,:),'LineWidth',2.0,'DisplayName','Fx_{peak}');
plot(fz_sweep, fx_peak./fz_sweep, 'Color',clr(4,:),'LineWidth',1.5,'LineStyle','--','DisplayName','μx');
ylabel('Fx_{peak} [N]  /  μx [-]'); xlabel('Fz [N]');
title('Longitudinaler Grip vs. Radlast','Color','w');
legend('TextColor','w','Color',[0.15 0.15 0.15],'Location','northwest');
sgtitle('Peak-Kräfte & Reibwerte vs. Fz','Color','w','FontSize',11);

%% ══════════════════════════════════════════════════════════════════════════
%% Fig 6: G-Faktor Diagnostik (Combined Weighting)
%% ══════════════════════════════════════════════════════════════════════════
fig6 = new_fig('G-Factor Diagnostics', [150 50 1100 500]);
tiledlayout(1, 2, 'TileSpacing','compact','Padding','compact');

dfz_ref = 0; fz_ref = Fz0;

% G_xa vs. kappa bei verschiedenen SA
ax6a = nexttile; dark_ax(ax6a); hold on; grid on;
sa_fixed_ga = deg2rad([0, 3, 6, 9, 12]);
lbl = {'SA=0°','SA=3°','SA=6°','SA=9°','SA=12°'};
for si = 1:numel(sa_fixed_ga)
    gxa = zeros(1, numel(kappa_vec));
    for ki = 1:numel(kappa_vec)
        gxa(ki) = calc_Gxa(p, kappa_vec(ki), sa_fixed_ga(si), dfz_ref);
    end
    plot(kappa_pct, gxa, 'Color', clr(mod(si-1,4)+1,:), 'LineWidth', 1.8, ...
         'DisplayName', lbl{si});
end
yline(1.0, 'Color',[0.7 0.7 0.7],'LineStyle','--','LineWidth',1,'HandleVisibility','off');
xlabel('κ [%]'); ylabel('G_{xa} [-]');
title('G_{xa}: Fx-Reduktion durch SA','Color','w');
legend('TextColor','w','Color',[0.15 0.15 0.15],'Location','best');
ylim([0, 1.1]);

% G_yk vs. SA bei verschiedenen kappa
ax6b = nexttile; dark_ax(ax6b); hold on; grid on;
kappa_fixed_gyk = [0, 0.05, 0.10, 0.20, 0.30];
lbl2 = {'κ=0%','κ=5%','κ=10%','κ=20%','κ=30%'};
for ki = 1:numel(kappa_fixed_gyk)
    gyk = zeros(1, numel(alpha_vec));
    for ai = 1:numel(alpha_vec)
        gyk(ai) = calc_Gyk(p, kappa_fixed_gyk(ki), alpha_vec(ai), dfz_ref);
    end
    plot(alpha_deg, gyk, 'Color', clr(mod(ki-1,4)+1,:), 'LineWidth', 1.8, ...
         'DisplayName', lbl2{ki});
end
yline(1.0, 'Color',[0.7 0.7 0.7],'LineStyle','--','LineWidth',1,'HandleVisibility','off');
xlabel('α [°]'); ylabel('G_{yk} [-]');
title('G_{yk}: Fy-Reduktion durch κ','Color','w');
legend('TextColor','w','Color',[0.15 0.15 0.15],'Location','best');
ylim([0, 1.1]);
sgtitle('Combined G-Faktoren (sollten monoton fallen, G(0)=1)','Color','w','FontSize',11);

%% ══════════════════════════════════════════════════════════════════════════
%% Fig 7: Combined Fy & Fx vs. Daten
%% ══════════════════════════════════════════════════════════════════════════
if numel(td_comb) > 0
    fig7 = new_fig('Combined Forces', [170 50 1200 550]);
    tiledlayout(1, 2, 'TileSpacing','compact','Padding','compact');
    sgtitle(sprintf('Combined | %s', processed_tires(idx_comb).tire_id), ...
            'Color','w','FontSize',11,'Interpreter','none');

    fz_mid = 900;
    sa_fixed_c = deg2rad([0, -3, -6, -9]);
    clr_c = {[0.9 0.2 0.2],[0.2 0.9 0.2],[0.2 0.5 0.9],[0.9 0.8 0.2]};

    ax7a = nexttile; dark_ax(ax7a); hold on; grid on;
    for i = 1:numel(td_comb)
        scatter(td_comb(i).kappa*100, td_comb(i).Fy, 2, ...
                [0.40 0.40 0.40],'HandleVisibility','off');
    end
    for si = 1:numel(sa_fixed_c)
        fy_c = zeros(1, numel(kappa_vec));
        for ki = 1:numel(kappa_vec)
            s.af=sa_fixed_c(si); s.k=kappa_vec(ki); s.Fz=fz_mid; s.y=gamma_ref; s.Pi=pi_ref;
            [~, fy_c(ki)] = calc_magic_tire_forces(p, s);
        end
        plot(kappa_pct, fy_c, 'Color', clr_c{si}, 'LineWidth', 2, ...
             'DisplayName', sprintf('SA=%.0f°', rad2deg(sa_fixed_c(si))));
    end
    xlabel('κ [%]'); ylabel('Fy [N]');
    title(sprintf('Fy Combined | Fz=%dN', fz_mid),'Color','w');
    legend('TextColor','w','Color',[0.15 0.15 0.15]);
    xline(0,'Color',[0.5 0.5 0.5],'LineStyle','--','HandleVisibility','off');
    yline(0,'Color',[0.5 0.5 0.5],'LineStyle','--','HandleVisibility','off');

    ax7b = nexttile; dark_ax(ax7b); hold on; grid on;
    for i = 1:numel(td_comb)
        scatter(td_comb(i).kappa*100, td_comb(i).Fx, 2, ...
                [0.40 0.40 0.40],'HandleVisibility','off');
    end
    for si = 1:numel(sa_fixed_c)
        fx_c = zeros(1, numel(kappa_vec));
        for ki = 1:numel(kappa_vec)
            s.af=sa_fixed_c(si); s.k=kappa_vec(ki); s.Fz=fz_mid; s.y=gamma_ref; s.Pi=pi_ref;
            [fx_c(ki), ~] = calc_magic_tire_forces(p, s);
        end
        plot(kappa_pct, fx_c, 'Color', clr_c{si}, 'LineWidth', 2, ...
             'DisplayName', sprintf('SA=%.0f°', rad2deg(sa_fixed_c(si))));
    end
    xlabel('κ [%]'); ylabel('Fx [N]');
    title(sprintf('Fx Combined | Fz=%dN', fz_mid),'Color','w');
    legend('TextColor','w','Color',[0.15 0.15 0.15]);
    xline(0,'Color',[0.5 0.5 0.5],'LineStyle','--','HandleVisibility','off');
    yline(0,'Color',[0.5 0.5 0.5],'LineStyle','--','HandleVisibility','off');
end

%% ══════════════════════════════════════════════════════════════════════════
%% Fig 8: Reibungsellipse
%% ══════════════════════════════════════════════════════════════════════════
fig8 = new_fig('Friction Ellipse', [190 50 800 700]);
ax8 = axes('Color',[0.13 0.13 0.13],'XColor','w','YColor','w');
dark_ax(ax8); hold on; grid on;

phi_vec = linspace(0, 2*pi, 200);
for fi = 1:numel(fz_levels)
    fz = fz_levels(fi);
    fx_e = zeros(1, numel(phi_vec));
    fy_e = zeros(1, numel(phi_vec));
    for phi_i = 1:numel(phi_vec)
        s.af = deg2rad(10) * cos(phi_vec(phi_i));
        s.k  = 0.30        * sin(phi_vec(phi_i));
        s.Fz = fz; s.y = gamma_ref; s.Pi = pi_ref;
        [fx_e(phi_i), fy_e(phi_i)] = calc_magic_tire_forces(p, s);
    end
    plot(fy_e, fx_e, 'Color', clr(fi,:), 'LineWidth', 2.0, ...
         'DisplayName', sprintf('Fz=%dN', fz));
end
if numel(td_comb) > 0
    for i = 1:numel(td_comb)
        scatter(td_comb(i).Fy, td_comb(i).Fx, 1, [0.40 0.40 0.40],'HandleVisibility','off');
    end
end
xlabel('Fy [N]'); ylabel('Fx [N]');
title('Reibungsellipse (α_{max}=10°, κ_{max}=30%)','Color','w');
legend('TextColor','w','Color',[0.15 0.15 0.15],'Location','best');
xline(0,'Color',[0.5 0.5 0.5],'LineStyle','--','HandleVisibility','off');
yline(0,'Color',[0.5 0.5 0.5],'LineStyle','--','HandleVisibility','off');
axis equal;

%% ══════════════════════════════════════════════════════════════════════════
%% Fig 9: Residuen-Analyse
%% ══════════════════════════════════════════════════════════════════════════
fig9 = new_fig('Residuals', [210 50 1100 500]);
tiledlayout(1, 2, 'TileSpacing','compact','Padding','compact');

% Fy Residuen
ax9a = nexttile; dark_ax(ax9a); hold on; grid on;
res_fy_all = []; alpha_all = [];
for i = 1:numel(td_lat)
    for k = 1:numel(td_lat(i).alpha)
        s.af=td_lat(i).alpha(k); s.k=0; s.Fz=td_lat(i).Fz(k); ...
        s.y=0; s.Pi=pi_ref;
        [~, fy_mod] = calc_magic_tire_forces(p, s);
        res_fy_all(end+1) = td_lat(i).Fy(k) - fy_mod;  %#ok<AGROW>
        alpha_all(end+1)  = rad2deg(td_lat(i).alpha(k));  %#ok<AGROW>
    end
end
if ~isempty(res_fy_all)
    scatter(alpha_all, res_fy_all, 2, [0.27 0.72 0.95], 'filled','HandleVisibility','off');
    rmse_fy = sqrt(mean(res_fy_all.^2));
    yline( rmse_fy,'Color',[0.95 0.4 0.4],'LineStyle','--','LineWidth',1.5, ...
           'DisplayName', sprintf('+RMSE=%.1fN', rmse_fy));
    yline(-rmse_fy,'Color',[0.95 0.4 0.4],'LineStyle','--','LineWidth',1.5, ...
           'HandleVisibility','off');
    yline(0,'Color',[0.7 0.7 0.7],'LineStyle',':','HandleVisibility','off');
    legend('TextColor','w','Color',[0.15 0.15 0.15]);
    text(0.02, 0.95, sprintf('RMSE = %.1f N', rmse_fy), 'Units','normalized', ...
         'Color',[0.9 0.9 0.9],'FontSize',9);
end
xlabel('α [°]'); ylabel('Fy_{mess} - Fy_{mod} [N]');
title('Fy Residuen vs. Schräglaufwinkel','Color','w');

% Fx Residuen
ax9b = nexttile; dark_ax(ax9b); hold on; grid on;
res_fx_all = []; kappa_all = [];
for i = 1:numel(td_long)
    for k = 1:numel(td_long(i).kappa)
        s.af=0; s.k=td_long(i).kappa(k); s.Fz=td_long(i).Fz(k); ...
        s.y=0; s.Pi=pi_ref;
        [fx_mod, ~] = calc_magic_tire_forces(p, s);
        res_fx_all(end+1) = td_long(i).Fx(k) - fx_mod;  %#ok<AGROW>
        kappa_all(end+1)  = td_long(i).kappa(k)*100;  %#ok<AGROW>
    end
end
if ~isempty(res_fx_all)
    scatter(kappa_all, res_fx_all, 2, [0.35 0.90 0.35], 'filled','HandleVisibility','off');
    rmse_fx = sqrt(mean(res_fx_all.^2));
    yline( rmse_fx,'Color',[0.95 0.4 0.4],'LineStyle','--','LineWidth',1.5,...
           'DisplayName', sprintf('+RMSE=%.1fN', rmse_fx));
    yline(-rmse_fx,'Color',[0.95 0.4 0.4],'LineStyle','--','LineWidth',1.5,...
           'HandleVisibility','off');
    yline(0,'Color',[0.7 0.7 0.7],'LineStyle',':','HandleVisibility','off');
    legend('TextColor','w','Color',[0.15 0.15 0.15]);
    text(0.02, 0.95, sprintf('RMSE = %.1f N', rmse_fx), 'Units','normalized', ...
         'Color',[0.9 0.9 0.9],'FontSize',9);
end
xlabel('κ [%]'); ylabel('Fx_{mess} - Fx_{mod} [N]');
title('Fx Residuen vs. Längsschlupf','Color','w');
sgtitle('Residuen-Analyse','Color','w','FontSize',11);

%% ══════════════════════════════════════════════════════════════════════════
%% Fig 10: Sturz-Sensitivität (Camber)
%% ══════════════════════════════════════════════════════════════════════════
fig10 = new_fig('Camber Sensitivity', [230 50 1000 500]);
tiledlayout(1, 2, 'TileSpacing','compact','Padding','compact');

gamma_levels = deg2rad([-4, -2, 0, 2, 4]);
fz_camb      = 700;
clr_gamma    = [0.95 0.35 0.35;
                0.95 0.70 0.20;
                0.90 0.90 0.90;
                0.20 0.80 0.80;
                0.20 0.50 0.95];

ax10a = nexttile; dark_ax(ax10a); hold on; grid on;
for gi = 1:numel(gamma_levels)
    fy_m = sweep_fy(p, alpha_vec, fz_camb, gamma_levels(gi), pi_ref);
    plot(alpha_deg, fy_m, 'Color', clr_gamma(gi,:), 'LineWidth', 1.8, ...
         'DisplayName', sprintf('γ=%.0f°', rad2deg(gamma_levels(gi))));
end
xlabel('α [°]'); ylabel('Fy [N]');
title(sprintf('Fy vs. Sturz | Fz=%dN', fz_camb),'Color','w');
legend('TextColor','w','Color',[0.15 0.15 0.15],'Location','best');
xline(0,'Color',[0.5 0.5 0.5],'LineStyle','--','HandleVisibility','off');
yline(0,'Color',[0.5 0.5 0.5],'LineStyle','--','HandleVisibility','off');

% Camber Thrust: Fy bei alpha=0 als Funktion von Sturz
ax10b = nexttile; dark_ax(ax10b); hold on; grid on;
gamma_sweep = deg2rad(linspace(-6, 6, 80));
ct_arr = zeros(size(gamma_sweep));
for gi = 1:numel(gamma_sweep)
    s.af=0; s.k=0; s.Fz=fz_camb; s.y=gamma_sweep(gi); s.Pi=pi_ref;
    [~, fy_ct] = calc_magic_tire_forces(p, s);
    ct_arr(gi) = fy_ct;
end
plot(rad2deg(gamma_sweep), ct_arr, 'Color', clr(1,:), 'LineWidth', 2.5);
xlabel('Sturzwinkel γ [°]'); ylabel('Camber Thrust Fy [N]  (bei α=0)');
title(sprintf('Camber Thrust vs. Sturz | Fz=%dN', fz_camb),'Color','w');
xline(0,'Color',[0.5 0.5 0.5],'LineStyle','--','HandleVisibility','off');
yline(0,'Color',[0.5 0.5 0.5],'LineStyle','--','HandleVisibility','off');
sgtitle('Sturz-Sensitivität','Color','w','FontSize',11);

%% ── Figuren speichern ─────────────────────────────────────────────────────
plot_dir = '2_Fitted_Model/Fit_Plots';
if ~isfolder(plot_dir), mkdir(plot_dir); end
figs = findall(0,'Type','figure');
fprintf('Speichere %d Figures...\n', numel(figs));
for f = 1:numel(figs)
    fname = fullfile(plot_dir, sprintf('Check_%s.png', ...
            regexprep(figs(f).Name,'[^a-zA-Z0-9_]','_')));
    exportgraphics(figs(f), fname, 'Resolution', 150, 'BackgroundColor', [0.08 0.08 0.08]);
end
fprintf('Gespeichert in: %s\n', plot_dir);

%% ══════════════════════════════════════════════════════════════════════════
%% Hilfsfunktionen
%% ══════════════════════════════════════════════════════════════════════════

function fig = new_fig(name, pos)
    fig = figure('Name', name, 'Position', pos, 'Color', [0.08 0.08 0.08]);
end

function dark_ax(ax)
    ax.Color          = [0.13 0.13 0.13];
    ax.XColor         = [0.88 0.88 0.88];
    ax.YColor         = [0.88 0.88 0.88];
    ax.GridColor      = [0.42 0.42 0.42];
    ax.GridAlpha      = 0.45;
    ax.MinorGridColor = [0.30 0.30 0.30];
    ax.Title.Color    = [0.95 0.95 0.95];
    ax.XLabel.Color   = [0.82 0.82 0.82];
    ax.YLabel.Color   = [0.82 0.82 0.82];
    % ax.Parent.Color   = [0.08 0.08 0.08];
end

function fy = sweep_fy(p, alpha_vec, fz, gamma, pi_pa)
    fy = zeros(1, numel(alpha_vec));
    for i = 1:numel(alpha_vec)
        s.af=alpha_vec(i); s.k=0; s.Fz=fz; s.y=gamma; s.Pi=pi_pa;
        [~, fy(i)] = calc_magic_tire_forces(p, s);
    end
end

function fx = sweep_fx(p, kappa_vec, fz, gamma, pi_pa)
    fx = zeros(1, numel(kappa_vec));
    for i = 1:numel(kappa_vec)
        s.af=0; s.k=kappa_vec(i); s.Fz=fz; s.y=gamma; s.Pi=pi_pa;
        [fx(i), ~] = calc_magic_tire_forces(p, s);
    end
end

function C = diff_at_zero(x_vec, y_vec)
% Numerische Steigung bei x=0 (zentrale Differenz)
    [~, i0] = min(abs(x_vec));
    i0 = max(2, min(i0, numel(x_vec)-1));
    C  = (y_vec(i0+1) - y_vec(i0-1)) / (x_vec(i0+1) - x_vec(i0-1));
end

function G = calc_Gxa(p, kappa, alpha_s, dfz)
    S_hxa = p.RHX1;
    a_s   = alpha_s + S_hxa;
    B_xa  = (p.RBX1 + p.RBX3 * 0) * cos(atan(p.RBX2 * kappa)) * p.LXAL;
    C_xa  = p.RCX1;
    E_xa  = min(p.REX1 + p.REX2 * dfz, 1.0);
    num   = cos(C_xa*atan(B_xa*a_s   - E_xa*(B_xa*a_s   - atan(B_xa*a_s))));
    den   = cos(C_xa*atan(B_xa*S_hxa - E_xa*(B_xa*S_hxa - atan(B_xa*S_hxa))));
    G     = max(num / max(abs(den), 1e-9), 0);
end

function G = calc_Gyk(p, kappa, alpha, dfz)
    S_Hk = p.RHY1 + p.RHY2 * dfz;
    k_s  = kappa + S_Hk;
    B_yk = (p.RBY1 + p.RBY4 * 0) * cos(atan(p.RBY2 * (alpha - p.RBY3))) * p.LYKA;
    C_yk = p.RCY1;
    E_yk = min(p.REY1 + p.REY2 * dfz, 1.0);
    num  = cos(C_yk*atan(B_yk*k_s  - E_yk*(B_yk*k_s  - atan(B_yk*k_s))));
    den  = cos(C_yk*atan(B_yk*S_Hk - E_yk*(B_yk*S_Hk - atan(B_yk*S_Hk))));
    G    = max(num / max(abs(den), 1e-9), 0);
end

function p = get_params(tm)
    names = {'FNOMIN','NOMPRES', ...
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
    for i = 1:numel(names)
        try, p.(names{i}) = tm.(names{i});
        catch, p.(names{i}) = 1.0; end
    end
end

function td_arr = load_segs(mat_file, method)
    td_arr = tireData.empty;
    if ~isfile(mat_file), warning('Nicht gefunden: %s', mat_file); return; end
    s = load(mat_file);
    for i = 1:numel(s.segments)
        if strcmp(s.segments(i).meta.TestMethod, method)
            td_arr(end+1) = build_td_plot(s.segments(i));  %#ok<AGROW>
        end
    end
end

function td = build_td_plot(seg)
    d = seg.data; m = seg.meta; n = numel(d.et);
    td = tireData();
    td.et=d.et; td.seget=d.et; td.segment=ones(n,1); td.measnumb=(1:n)';
    td.Fx= d.FX; td.Fy=-d.FY; td.Fz=d.FZ;
    td.Mx=d.MX; td.My=zeros(n,1); td.Mz=d.MZ; td.IP=d.P;
    td.alpha=deg2rad(d.SA); td.gamma=deg2rad(d.IA);
    td.kappa=d.SL; td.phit=zeros(n,1); td.V=d.V; td.omega=zeros(n,1);
    td.TtreadI=d.TSTI; td.TtreadC=d.TSTC; td.TtreadO=d.TSTO;
    td.Comments=m.SourceFile; td.TestMethod=m.TestMethod; td.TireSize=m.TireID;
end