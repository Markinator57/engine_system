function plot_cycle(key_values, properties_flow)
% Visualizes the expander cycle fluid state cascade, top to bottom.
% White boxes; T values colored warm, p values colored cool; two colorbars.
% Key values from each subsystem are annotated beside their rectangle.
% Usage:  [kv, pf] = cycle_solver();   plot_cycle(kv, pf);

    %% --- Unpack states ---
    sf_tank = properties_flow.fuel.Tanks;
    sf_pump = properties_flow.fuel.Pump_LCH4;
    sf_cool = properties_flow.fuel.Cooling_Channels;
    sf_t1   = properties_flow.fuel.Turbine_LCH4;
    sf_t2   = properties_flow.fuel.Turbine_LOx;
    sf_inj  = properties_flow.fuel.Injector;
    so_tank = properties_flow.oxidizer.Tanks;
    so_pump = properties_flow.oxidizer.Pump_LOx;
    so_inj  = properties_flow.oxidizer.Injector;
    TC      = key_values.Thrust_Chamber;

    %% --- Ranges ---
    all_T = [sf_tank.T, sf_pump.T, sf_cool.T, sf_t1.T, sf_t2.T, sf_inj.T, ...
             so_tank.T, so_pump.T, so_inj.T, TC.T_CC];
    T_lo = min(all_T);   T_hi = TC.T_CC;

    all_p_bar = [sf_tank.p, sf_pump.p, sf_cool.p, sf_t1.p, sf_t2.p, sf_inj.p, ...
                 so_tank.p, so_pump.p, so_inj.p] / 1e5;
    p_lo = min(all_p_bar);   p_hi = max(all_p_bar);

    %% --- Colormaps (both readable on white) ---
    n = 256;
    % T: dark orange -> dark crimson  (warm scale)
    cmap_T = [linspace(0.0, 0.70, n)', linspace(0.7, 0.05, n)', linspace(0.9, 0.1, n)'];
    % p: cornflower blue -> dark navy (cool scale)
    cmap_p = [linspace(0.95, 0.1, n)', linspace(0.7, 0.00, n)', linspace(0.0, 0.70, n)'];

    t2c_T = @(T) cmap_T(max(1, min(n, round(1 + (n-1)*(T       - T_lo) / max(T_hi - T_lo, 1)))), :);
    t2c_p = @(p) cmap_p(max(1, min(n, round(1 + (n-1)*(p/1e5   - p_lo) / max(p_hi - p_lo, 1)))), :);

    %% --- Layout ---
    BW   = 3.0;    BH   = 0.88;   % stage box (BH tall enough for 3 text rows)
    TC_W = 4.8;    TC_H = 1.10;   % thrust chamber
    xF   = 2.0;    xO   = 8.0;    xTC = 5.0;
    RS   = 1.35;                   % row spacing (center to center)

    yR     = @(k) 10.0 - k * RS;
    y_tank = yR(1);
    y_pump = yR(2);
    y_cool = yR(3);
    y_t1   = yR(4);
    y_t2   = yR(5);
    y_inj  = yR(6);
    y_tc   = max(yR(7), TC_H/2 + 0.08);   % clamp so box never clips y=0

    BGC  = [0.09 0.09 0.11];       % dark figure background
    ANC  = [0.60 0.63 0.72];       % annotation text color

    %% --- Figure and axes ---
    figure('Name', 'Expander Cycle  —  Fluid State Cascade', ...
           'Color', BGC, 'Position', [50 20 1400 920]);
    ax = axes('Color', BGC, 'XColor', 'none', 'YColor', 'none', ...
              'Position', [0.02 0.03 0.82 0.93]);
    hold(ax, 'on');
    xlim(ax, [0 10]);
    ylim(ax, [0 10]);

    %% --- Column headers ---
    text(ax, xF, y_tank + BH/2 + 0.42, '— FUEL (LCH4) —', ...
         'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold', ...
         'Color', [0.35 0.65 1.0], 'FontName', 'Consolas');
    text(ax, xO, y_tank + BH/2 + 0.42, '— OXIDIZER (LOx) —', ...
         'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold', ...
         'Color', [0.35 1.0 0.55], 'FontName', 'Consolas');

    %% --- Fuel stage boxes ---
    draw_stage(ax, xF, y_tank, 'TANK   (LCH4)',      sf_tank, BW, BH, t2c_T, t2c_p);
    draw_stage(ax, xF, y_pump, 'PUMP   LCH4',        sf_pump, BW, BH, t2c_T, t2c_p);
    draw_stage(ax, xF, y_cool, 'COOLING CHANNELS',   sf_cool, BW, BH, t2c_T, t2c_p);
    draw_stage(ax, xF, y_t1,   'TURBINE  LCH4',      sf_t1,   BW, BH, t2c_T, t2c_p);
    draw_stage(ax, xF, y_t2,   'TURBINE  (LOx drv)', sf_t2,   BW, BH, t2c_T, t2c_p);
    draw_stage(ax, xF, y_inj,  'INJECTOR  (fuel)',   sf_inj,  BW, BH, t2c_T, t2c_p);

    %% --- Oxidizer stage boxes ---
    draw_stage(ax, xO, y_tank, 'TANK   (LOx)',       so_tank, BW, BH, t2c_T, t2c_p);
    draw_stage(ax, xO, y_pump, 'PUMP   LOx',         so_pump, BW, BH, t2c_T, t2c_p);
    draw_stage(ax, xO, y_inj,  'INJECTOR  (oxi)',    so_inj,  BW, BH, t2c_T, t2c_p);

    %% --- Thrust chamber (white box, gold border) ---
    fill(ax, [xTC-TC_W/2, xTC+TC_W/2, xTC+TC_W/2, xTC-TC_W/2], ...
             [y_tc-TC_H/2, y_tc-TC_H/2, y_tc+TC_H/2, y_tc+TC_H/2], ...
         [1 1 1], 'EdgeColor', [0.70 0.52 0.05], 'LineWidth', 2.8);
    text(ax, xTC, y_tc + TC_H*0.33, 'THRUST CHAMBER', ...
         'HorizontalAlignment', 'center', 'FontSize', 13, 'FontWeight', 'bold', ...
         'Color', [0.15 0.15 0.18], 'FontName', 'Consolas');
    text(ax, xTC, y_tc + TC_H*0.07, sprintf('T_{CC} = %.0f K', TC.T_CC), ...
         'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold', ...
         'Color', t2c_T(TC.T_CC), 'FontName', 'Consolas');
    text(ax, xTC, y_tc - TC_H*0.13, sprintf('v_e = %.0f m/s', TC.v_e), ...
         'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold', ...
         'Color', [0.20 0.20 0.24], 'FontName', 'Consolas');
    text(ax, xTC, y_tc - TC_H*0.34, sprintf('F = %.2f kN', TC.F_thrust / 1e3), ...
         'HorizontalAlignment', 'center', 'FontSize', 13, 'FontWeight', 'bold', ...
         'Color', [0.72 0.47 0.03], 'FontName', 'Consolas');

    %% --- Fuel path connectors ---
    arr(ax, xF, y_tank - BH/2,  xF,                  y_pump + BH/2);
    arr(ax, xF, y_pump - BH/2,  xF,                  y_cool + BH/2);
    arr(ax, xF, y_cool - BH/2,  xF,                  y_t1   + BH/2);
    arr(ax, xF, y_t1   - BH/2,  xF,                  y_t2   + BH/2);
    arr(ax, xF, y_t2   - BH/2,  xF,                  y_inj  + BH/2);
    arr(ax, xF, y_inj  - BH/2,  xTC - TC_W/2 + 0.35, y_tc   + TC_H/2);

    %% --- Oxidizer path connectors ---
    arr(ax, xO, y_tank - BH/2, xO, y_pump + BH/2);
    % Dashed holding line: LOx waits at pump pressure while fuel traverses turbines
    plot(ax, [xO xO], [y_pump - BH/2, y_inj + BH/2], '--', ...
         'Color', [0.40 0.44 0.50], 'LineWidth', 1.4);
    arr(ax, xO, y_inj  - BH/2, xTC + TC_W/2 - 0.35, y_tc + TC_H/2);

    %% --- Key value annotations ---
    xF_r = xF + BW/2;   % right edge of fuel boxes
    xO_l = xO - BW/2;   % left edge of oxidizer boxes

    % Pump LCH4: power consumed
    ann_r(ax, xF_r, y_pump, ...
          {sprintf('P = %.1f kW', key_values.P_Pump_LCH4 / 1e3)}, ANC);

    % Cooling channels: heat absorbed and temperature rise
    ann_r(ax, xF_r, y_cool, ...
          {sprintf('Q_{in} = %.0f kW', key_values.Q_dot_Cooling / 1e3), ...
           sprintf('\\Delta T = +%.1f K', key_values.delta_T_Cooling_Channels)}, ANC);

    % Turbine LCH4: temperature drop + pressure drop
    dT_t1 = sf_t1.T - sf_cool.T;   % negative (temperature drops)
    ann_r(ax, xF_r, y_t1, ...
          {sprintf('\\Delta T = %.1f K', dT_t1), ...
           sprintf('\\Delta p = %.1f bar', key_values.delta_p_Turbine_LCH4 / 1e5)}, ANC);

    % Turbine LOx driver: temperature drop + pressure drop
    dT_t2 = sf_t2.T - sf_t1.T;     % negative
    ann_r(ax, xF_r, y_t2, ...
          {sprintf('\\Delta T = %.1f K', dT_t2), ...
           sprintf('\\Delta p = %.1f bar', key_values.delta_p_Turbine_LOx / 1e5)}, ANC);

    % Pump LOx: power consumed
    ann_l(ax, xO_l, y_pump, ...
          {sprintf('P = %.1f kW', key_values.P_Pump_LOx / 1e3)}, ANC);

    %% --- Colorbar: Temperature (upper right) ---
    ax_cT = axes('Parent', gcf, 'Position', [0 0 0.001 0.001], 'Visible', 'off');
    colormap(ax_cT, cmap_T);
    caxis(ax_cT, [T_lo, T_hi]);
    cb_T                = colorbar(ax_cT);
    cb_T.Position       = [0.862 0.52 0.022 0.42];
    cb_T.Color          = [0.70 0.70 0.75];
    cb_T.FontName       = 'Consolas';
    cb_T.FontSize       = 9;
    cb_T.Label.String   = 'T  [K]';
    cb_T.Label.Color    = [0.70 0.70 0.75];
    cb_T.Label.FontSize = 10;

    %% --- Colorbar: Pressure (lower right) ---
    ax_cp = axes('Parent', gcf, 'Position', [0 0 0.001 0.001], 'Visible', 'off');
    colormap(ax_cp, cmap_p);
    caxis(ax_cp, [p_lo, p_hi]);
    cb_p                = colorbar(ax_cp);
    cb_p.Position       = [0.862 0.05 0.022 0.42];
    cb_p.Color          = [0.70 0.70 0.75];
    cb_p.FontName       = 'Consolas';
    cb_p.FontSize       = 9;
    cb_p.Label.String   = 'p  [bar]';
    cb_p.Label.Color    = [0.70 0.70 0.75];
    cb_p.Label.FontSize = 10;

    %% --- Title ---
    title(ax, 'Expander Cycle  —  Fluid State Cascade', ...
          'Color', [0.72 0.72 0.78], 'FontSize', 14, ...
          'FontWeight', 'bold', 'FontName', 'Consolas');
end


%% ---- Local sub-functions -------------------------------------------------

function draw_stage(ax, cx, cy, label, state, BW, BH, t2c_T, t2c_p)
    % White box, gray border
    fill(ax, [cx-BW/2, cx+BW/2, cx+BW/2, cx-BW/2], ...
             [cy-BH/2, cy-BH/2, cy+BH/2, cy+BH/2], ...
         [1 1 1], 'EdgeColor', [0.55 0.55 0.60], 'LineWidth', 1.8);
    % Component name — dark, not color-coded
    text(ax, cx, cy + BH*0.25, label, ...
         'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold', ...
         'Color', [0.15 0.15 0.18], 'FontName', 'Consolas');
    % Temperature — warm color, bold, big
    text(ax, cx, cy - BH*0.03, sprintf('T = %.0f K', state.T), ...
         'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold', ...
         'Color', t2c_T(state.T), 'FontName', 'Consolas');
    % Pressure — cool color, bold, big
    text(ax, cx, cy - BH*0.30, sprintf('p = %.1f bar', state.p / 1e5), ...
         'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold', ...
         'Color', t2c_p(state.p), 'FontName', 'Consolas');
end


function ann_r(ax, bx, cy, lines, col)
% Annotate to the RIGHT of a box. lines = cell array of strings (1 or 2).
    xt = bx + 0.22;
    plot(ax, [bx, xt - 0.04], [cy, cy], '-', 'Color', [0.40 0.43 0.52], 'LineWidth', 0.9);
    n   = numel(lines);
    sep = 0.22;                                   % vertical gap between lines
    for k = 1:n
        yk = cy + sep * ((n + 1) / 2 - k);        % evenly centered on cy
        text(ax, xt, yk, lines{k}, ...
             'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
             'FontSize', 9.5, 'FontWeight', 'bold', 'Color', col, ...
             'FontName', 'Consolas', 'Interpreter', 'tex');
    end
end


function ann_l(ax, bx, cy, lines, col)
% Annotate to the LEFT of a box. lines = cell array of strings (1 or 2).
    xt = bx - 0.22;
    plot(ax, [bx, xt + 0.04], [cy, cy], '-', 'Color', [0.40 0.43 0.52], 'LineWidth', 0.9);
    n   = numel(lines);
    sep = 0.22;
    for k = 1:n
        yk = cy + sep * ((n + 1) / 2 - k);
        text(ax, xt, yk, lines{k}, ...
             'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
             'FontSize', 9.5, 'FontWeight', 'bold', 'Color', col, ...
             'FontName', 'Consolas', 'Interpreter', 'tex');
    end
end


function arr(ax, x1, y1, x2, y2)
    col = [0.50 0.52 0.58];
    plot(ax, [x1 x2], [y1 y2], '-', 'Color', col, 'LineWidth', 1.8);
    dx = x2 - x1;  dy = y2 - y1;
    L  = hypot(dx, dy);
    if L < 1e-9; return; end
    ux = dx / L;  uy = dy / L;
    hw = 0.07;    hl = 0.14;
    % Perpendicular to (ux,uy) is (-uy, ux)
    fill(ax, [x2-hl*ux-hw*uy,  x2,  x2-hl*ux+hw*uy], ...
             [y2-hl*uy+hw*ux,  y2,  y2-hl*uy-hw*ux], col, 'EdgeColor', col);
end
