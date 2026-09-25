function plot_flow_analysis(key_values, properties_flow)
% Three plots along the flow direction (tank -> injector), CH4 and LOx:
%   1) Reynolds number in the pipelines only   (taken from key_values)
%   2) Mach number  Ma = v / sqrt(R*(cp/(cp-R))*T)   (from properties_flow)
%   3) Pressure cascade, annotated with the component causing each change
%
% Usage:  [kv, pf] = cycle_solver();   plot_flow_analysis(kv, pf);

    %% --- Specific gas constants ---
    R_univ = 8314.4;                 % [J/(kmol K)]
    R_CH4  = R_univ / 16.043;        % [J/(kg K)]
    R_O2   = R_univ / 31.999;        % [J/(kg K)]

    C_F = [0.20 0.55 1.00];          % fuel (LCH4) colour
    C_O = [0.10 0.70 0.35];          % oxidizer (LOx) colour

    %% ====================================================================
    %  1) REYNOLDS NUMBER - PIPELINES ONLY
    %% ====================================================================
    pipe_f_lbl = {'Tank\rightarrowPump', 'Pump\rightarrowCooling', ...
                  'Cooling\rightarrowTurb CH4', 'Turb CH4\rightarrowTurb LOx', ...
                  'Turb LOx\rightarrowInjector'};
    pipe_f_x = [1 2 3 4 5];
    Re_f = [ double(key_values.Re_Tank_to_Pump_LCH4), ...
             double(key_values.Re_Pump_LCH4_to_Cooling), ...
             double(key_values.Re_Cooling_to_Turbine_LCH4), ...
             double(key_values.Re_Turbine_LCH4_to_Turbine_LOX), ...
             double(key_values.Re_Turbine_LOX_to_Injector) ];

    % Oxidizer has only two pipe runs - placed at the matching positions
    pipe_o_x = [1 5];
    Re_o = [ double(key_values.Re_Tank_to_LOX_Pump), ...
             double(key_values.Re_LOX_Pump_to_Injector) ];

    figure('Name', 'Reynolds number along the flow path', 'Color', 'w', ...
           'Position', [60 80 900 520]);
    ax = axes('Position', [0.10 0.17 0.87 0.76]);
    hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');

    plot(ax, pipe_f_x, Re_f, '-o', 'Color', C_F, 'MarkerFaceColor', C_F, ...
         'LineWidth', 2.0, 'MarkerSize', 7, 'DisplayName', 'LCH4 (fuel)');
    plot(ax, pipe_o_x, Re_o, '-s', 'Color', C_O, 'MarkerFaceColor', C_O, ...
         'LineWidth', 2.0, 'MarkerSize', 8, 'DisplayName', 'LOx (oxidizer)');

    % Regime reference lines - drawn only if they fall near the data range,
    % so they never stretch the axis into a band of empty space.
    Re_all = [Re_f, Re_o];
    if min(Re_all) < 2e4
        yline(ax, 2000, ':',  'laminar limit (Re = 2000)', ...
              'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
        yline(ax, 4000, '--', 'turbulent onset (Re = 4000)', ...
              'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
    end

    for k = 1:numel(Re_f)
        text(ax, pipe_f_x(k), Re_f(k), sprintf('  %.2e', Re_f(k)), ...
             'Color', C_F*0.8, 'FontSize', 8.5, 'VerticalAlignment', 'bottom');
    end
    for k = 1:numel(Re_o)
        text(ax, pipe_o_x(k), Re_o(k), sprintf('  %.2e', Re_o(k)), ...
             'Color', C_O*0.8, 'FontSize', 8.5, 'VerticalAlignment', 'top');
    end

    set(ax, 'XTick', pipe_f_x, 'XTickLabel', pipe_f_lbl, ...
        'XTickLabelRotation', 20, 'YScale', 'log');
    xlim(ax, [0.75 5.45]);
    if min(Re_all) < 2e4
        ylim(ax, [1.5e3, max(Re_all) * 2.2]);
    else
        ylim(ax, [min(Re_all) / 1.5, max(Re_all) * 2.2]);
    end
    ylabel(ax, 'Reynolds number  Re  [-]');
    title(ax, 'Reynolds number in the pipelines');
    legend(ax, 'Location', 'best');

    %% ====================================================================
    %  2) MACH NUMBER
    %% ====================================================================
    % Only the pipe stations carry a velocity, so Ma is evaluated there.
    st_f = { properties_flow.fuel.Pipe_Tank_to_Pump_LCH4, ...
             properties_flow.fuel.Pump_LCH4_to_Cooling, ...
             properties_flow.fuel.Pipe_Cooling_to_Turbine_LCH4, ...
             properties_flow.fuel.Pipe_Turbine_LCH4_to_Turbine_LOX, ...
             properties_flow.fuel.Pipe_Turbine_LOX_to_Injector };
    st_o = { properties_flow.oxidizer.Pipe_PressureLoss_Tank_to_LOX_Pump, ...
             properties_flow.oxidizer.Pipe_PressureLoss_LOX_Pump_to_Injector };

    Ma_f = zeros(1, numel(st_f));   v_f = Ma_f;
    for k = 1:numel(st_f)
        [Ma_f(k), v_f(k)] = mach_of(st_f{k}, R_CH4);
    end
    Ma_o = zeros(1, numel(st_o));   v_o = Ma_o;
    for k = 1:numel(st_o)
        [Ma_o(k), v_o(k)] = mach_of(st_o{k}, R_O2);
    end

    figure('Name', 'Mach number along the flow path', 'Color', 'w', ...
           'Position', [90 60 900 520]);
    ax = axes('Position', [0.10 0.17 0.87 0.76]);
    hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');

    plot(ax, pipe_f_x, Ma_f, '-o', 'Color', C_F, 'MarkerFaceColor', C_F, ...
         'LineWidth', 2.0, 'MarkerSize', 7, 'DisplayName', 'LCH4 (fuel)');
    plot(ax, pipe_o_x, Ma_o, '-s', 'Color', C_O, 'MarkerFaceColor', C_O, ...
         'LineWidth', 2.0, 'MarkerSize', 8, 'DisplayName', 'LOx (oxidizer)');

    % Ma = 0.3 reference only when the data actually approaches it, otherwise
    % it would compress every point into the bottom of the axis.
    Ma_all = [Ma_f, Ma_o];
    if max(Ma_all) > 0.12
        yline(ax, 0.3, '--', 'incompressible limit (Ma = 0.3)', ...
              'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
    end

    for k = 1:numel(Ma_f)
        text(ax, pipe_f_x(k), Ma_f(k), sprintf('  %.3f  (v = %.1f m/s)', Ma_f(k), v_f(k)), ...
             'Color', C_F*0.8, 'FontSize', 8.5, 'VerticalAlignment', 'bottom');
    end
    for k = 1:numel(Ma_o)
        text(ax, pipe_o_x(k), Ma_o(k), sprintf('  %.3f  (v = %.1f m/s)', Ma_o(k), v_o(k)), ...
             'Color', C_O*0.8, 'FontSize', 8.5, 'VerticalAlignment', 'top');
    end

    set(ax, 'XTick', pipe_f_x, 'XTickLabel', pipe_f_lbl, 'XTickLabelRotation', 20);
    xlim(ax, [0.75 5.45]);
    Ma_top = max(Ma_all) * 1.25;
    if max(Ma_all) > 0.12; Ma_top = max(Ma_top, 0.34); end
    ylim(ax, [0, Ma_top]);
    ylabel(ax, 'Mach number  Ma  [-]');
    title(ax, 'Mach number in the pipelines');
    legend(ax, 'Location', 'best');

    %% ====================================================================
    %  3) PRESSURE CASCADE
    %% ====================================================================
    pf = properties_flow.fuel;
    p_f = [ pf.Tanks.p, ...
            pf.Pipe_Tank_to_Pump_LCH4.p, ...
            pf.Pump_LCH4.p, ...
            pf.Pump_LCH4_to_Cooling.p, ...
            pf.Cooling_Channels.p, ...
            pf.Pipe_Cooling_to_Turbine_LCH4.p, ...
            pf.Turbine_LCH4.p, ...
            pf.Pipe_Turbine_LCH4_to_Turbine_LOX.p, ...
            pf.Turbine_LOx.p, ...
            pf.Pipe_Turbine_LOX_to_Injector.p, ...
            pf.Injector.p ];
    p_f = double(p_f) / 1e5;
    x_f = 1:11;
    lbl_f = {'Tank', 'Feed line', 'Pump CH4', 'Line to cooling', ...
             'Cooling channels', 'Line to turbine', 'Turbine CH4', ...
             'Crossover duct', 'Turbine LOx', 'Line to injector', 'Injector'};
    % Component responsible for the change from the previous station
    cause_f = {'', 'pipes', 'PUMP CH4 (gain)', 'pipes', ...
               'COOLING CHAMBER', 'pipes', 'TURBINE CH4', ...
               'crossover duct', 'TURBINE LOx', 'pipe + trim to inj. inlet', ...
               'INJECTOR'};

    po = properties_flow.oxidizer;
    p_o = [ po.Tanks.p, ...
            po.Pipe_PressureLoss_Tank_to_LOX_Pump.p, ...
            po.Pump_LOx.p, ...
            po.Pipe_PressureLoss_LOX_Pump_to_Injector.p, ...
            po.Injector.p ];
    p_o = double(p_o) / 1e5;
    x_o = [1 2 3 10 11];
    cause_o = {'', 'pipes', 'PUMP LOx (gain)', ...
               'pipe + trim to inj. inlet', 'INJECTOR'};

    figure('Name', 'Pressure along the flow path', 'Color', 'w', ...
           'Position', [120 40 1150 620]);
    ax = axes('Position', [0.075 0.20 0.905 0.72]);
    hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');

    plot(ax, x_f, p_f, '-o', 'Color', C_F, 'MarkerFaceColor', C_F, ...
         'LineWidth', 2.0, 'MarkerSize', 7, 'DisplayName', 'LCH4 (fuel)');
    plot(ax, x_o, p_o, '-s', 'Color', C_O, 'MarkerFaceColor', C_O, ...
         'LineWidth', 2.0, 'MarkerSize', 8, 'DisplayName', 'LOx (oxidizer)');

    yline(ax, 80, '--', 'p_{CC} required = 80 bar', 'Color', [0.75 0.35 0.05], ...
          'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left', ...
          'HandleVisibility', 'off');

    p_max = max([p_f, p_o]);
    annotate_changes(ax, x_f, p_f, cause_f, C_F*0.8, +1, p_max);
    annotate_changes(ax, x_o, p_o, cause_o, C_O*0.7, -1, p_max);

    set(ax, 'XTick', x_f, 'XTickLabel', lbl_f, 'XTickLabelRotation', 25);
    xlim(ax, [0.7 11.4]);
    ylim(ax, [-0.06 * p_max, p_max * 1.10]);
    ylabel(ax, 'Static pressure  p  [bar]');
    title(ax, 'Pressure cascade');
    legend(ax, 'Location', 'northwest');
end

%% ---- local helpers ------------------------------------------------------

function [Ma, v] = mach_of(state, R_spec)
% Ma = v / sqrt(R * (cp/(cp-R)) * T)
    v     = double(state.v);
    c_p   = double(state.c_p);
    T     = double(state.T);
    kappa = c_p / (c_p - R_spec);
    Ma    = v / sqrt(R_spec * kappa * T);
end

function annotate_changes(ax, x, p, cause, col, side, p_max)
% Label every station with the component that produced the pressure change.
    for k = 2:numel(p)
        dp = p(k) - p(k-1);
        if abs(dp) < 1e-3; continue; end
        xm = (x(k) + x(k-1)) / 2;
        ym = (p(k) + p(k-1)) / 2;
        if side > 0
            va = 'bottom';   yo =  0.035 * p_max;
        else
            va = 'top';      yo = -0.035 * p_max;
        end
        text(ax, xm, ym + yo, sprintf('%s\n%+.1f bar', cause{k}, dp), ...
             'Color', col, 'FontSize', 8, 'FontWeight', 'bold', ...
             'HorizontalAlignment', 'center', 'VerticalAlignment', va, ...
             'Interpreter', 'none');
    end
end
