function plot_pressure_loss_vs_ROF()
% Sweeps the O/F ratio (ROF) from 2.8 to 3.8 and plots the total
% irreversible line pressure loss (Darcy-Weisbach friction + inlet
% minor/geometric loss, as computed inside cycle_solver/run_cycle) for
% the fuel (LCH4) and oxidizer (LOx) feed lines.

    ROF_vec = linspace(2.8, 3.8, 11);
    dP_CH4  = nan(size(ROF_vec));
    dP_LOX  = nan(size(ROF_vec));

    for i = 1:numel(ROF_vec)
        fprintf('Running cycle_solver for ROF = %.3f ...\n', ROF_vec(i));
        try
            key_values = cycle_solver(ROF_vec(i), false);
            dP_CH4(i) = key_values.TotalDeltaP_irreversible_CH4 / 1e5;  % [bar]
            dP_LOX(i) = key_values.TotalDeltaP_irreversible_LOX / 1e5;  % [bar]
        catch ME
            warning('ROF = %.3f failed: %s', ROF_vec(i), ME.message);
        end
    end

    figure('Name', 'Line pressure loss vs O/F ratio', 'Color', 'w', ...
           'Position', [100 100 850 550]);
    ax = axes('Position', [0.11 0.13 0.85 0.78]);
    hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');

    plot(ax, ROF_vec, dP_CH4, '-o', 'Color', [0.20 0.55 1.00], ...
         'MarkerFaceColor', [0.20 0.55 1.00], 'LineWidth', 2.0, ...
         'MarkerSize', 7, 'DisplayName', 'LCH4 lines (fuel)');
    plot(ax, ROF_vec, dP_LOX, '-s', 'Color', [0.10 0.70 0.35], ...
         'MarkerFaceColor', [0.10 0.70 0.35], 'LineWidth', 2.0, ...
         'MarkerSize', 8, 'DisplayName', 'LOx lines (oxidizer)');

    xlabel(ax, 'O/F ratio (ROF)  [-]');
    ylabel(ax, 'Total irreversible line pressure loss  \DeltaP  [bar]');
    title(ax, 'Feed-line pressure loss vs mixture ratio');
    legend(ax, 'Location', 'best');
end
