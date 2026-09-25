function pipe_resize_for_velocity()
% Enforces v <= 10 m/s in every pipe by resizing D where needed
% (D_new = D_old * sqrt(v_old/10), since v ~ 1/D^2 at fixed mass flow).
% Prints old vs new diameter/velocity per line, and total irreversible
% line pressure loss (bar) before vs after resizing.

    V_MAX = 10; % [m/s]

    %% Baseline run
    [kv0, pf0] = cycle_solver([], false);

    stations = { ...
        'D_Tank_to_Pump_LCH4',    pf0.fuel.Pipe_Tank_to_Pump_LCH4.v; ...
        'D_Pump_to_Cooling_Inlet',pf0.fuel.Pump_LCH4_to_Cooling.v; ...
        'D_Cooling_Outlet_to_Turbine', pf0.fuel.Pipe_Cooling_to_Turbine_LCH4.v; ...
        'D_TurbineCH4_to_TurbineOx',   pf0.fuel.Pipe_Turbine_LCH4_to_Turbine_LOX.v; ...
        'D_TurbineOx_to_Injector',     pf0.fuel.Pipe_Turbine_LOX_to_Injector.v; ...
        'D_Tank_to_LOX_Pump',          pf0.oxidizer.Pipe_PressureLoss_Tank_to_LOX_Pump.v; ...
        'D_OxPump_to_Injector',        pf0.oxidizer.Pipe_PressureLoss_LOX_Pump_to_Injector.v };

    [inputs0, ~, ~] = engine_inputs();

    D_override = struct();
    fprintf('%-28s | %8s | %8s | %8s | %8s\n', 'Line', 'D_old[mm]', 'v_old[m/s]', 'D_new[mm]', 'v_new[m/s]');
    for i = 1:size(stations,1)
        name  = stations{i,1};
        v_old = double(stations{i,2});
        D_old = inputs0.(name);
        if v_old > V_MAX
            D_new = D_old * sqrt(v_old / V_MAX);
            v_new = V_MAX; % by construction
        else
            D_new = D_old;
            v_new = v_old;
        end
        D_override.(name) = D_new;
        fprintf('%-28s | %8.2f | %8.2f | %8.2f | %8.2f\n', name, D_old*1e3, v_old, D_new*1e3, v_new);
    end

    %% Resized run
    [kv1, pf1] = cycle_solver([], false, D_override);

    dP_old_bar = (kv0.TotalDeltaP_irreversible_CH4 + kv0.TotalDeltaP_irreversible_LOX) / 1e5;
    dP_new_bar = (kv1.TotalDeltaP_irreversible_CH4 + kv1.TotalDeltaP_irreversible_LOX) / 1e5;

    fprintf('\nTotal irreversible line pressure loss:\n');
    fprintf('  Before resizing: %.3f bar\n', dP_old_bar);
    fprintf('  After resizing:  %.3f bar\n', dP_new_bar);
    fprintf('  Change:          %+.3f bar (%+.1f%%)\n', dP_new_bar - dP_old_bar, 100*(dP_new_bar-dP_old_bar)/dP_old_bar);
end
