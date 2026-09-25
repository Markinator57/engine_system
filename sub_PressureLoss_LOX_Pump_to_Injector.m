function [properties, key_values] = sub_PressureLoss_LOX_Pump_to_Injector(inputs, properties)

    D   = inputs.D_OxPump_to_Injector;
    A   = (D/2)^2 * pi;
    L   = inputs.L_OxPump_to_Injector;
    K   = 0.8;          % Combined minor-loss coefficient for a LOX feedline with bends, valves, and other control-system losses only
    N   = 100;          % Number of segments
    dx  = L / N;        % Segment length [m]

    %% Minor/geometric loss — applied once at pipe entrance
    v_inlet      = inputs.m_dot_oxidizer / (properties.rho * A);
    q_inlet      = 0.5 * properties.rho * v_inlet^2;
    dP_geom      = K * q_inlet;
    properties.p = properties.p - dP_geom;

    %% Main Oxidizer Valve (ball valve) — located at line midpoint
    % K = 3*f_T, Crane clean-commercial-steel f_T at D = 80 mm -> f_T = 0.018
    K_valve = 0.054;
    N_half  = N / 2;

    %% Check Valve (swing check, downstream of Main Oxidizer Valve, before injector)
    % K = 100*f_T, Crane clean-commercial-steel f_T at D = 80 mm -> f_T = 0.018
    K_check = 1.80;
    N_check = round(N * 0.75);

    %% Segmented Darcy-Weisbach integration
    dP_fric_total = 0;

    for i = 1:N
        rho_i = py.CoolProp.CoolProp.PropsSI('D', 'P', properties.p, 'T', properties.T, 'Oxygen');
        mu_i  = py.CoolProp.CoolProp.PropsSI('V', 'P', properties.p, 'T', properties.T, 'Oxygen');

        v_i  = inputs.m_dot_oxidizer / (rho_i * A);
        Re_i = (rho_i * v_i * D) / mu_i;
        q_i  = 0.5 * rho_i * v_i^2;

        f_i           = friction_factor(Re_i);
        dP_i          = f_i * (dx / D) * q_i;
        dP_fric_total = dP_fric_total + dP_i;
        properties.p  = properties.p - dP_i;

        % Main Oxidizer Valve, applied once at the line midpoint
        if i == N_half
            rho_v        = py.CoolProp.CoolProp.PropsSI('D', 'P', properties.p, 'T', properties.T, 'Oxygen');
            v_v          = inputs.m_dot_oxidizer / (rho_v * A);
            q_v          = 0.5 * rho_v * v_v^2;
            dP_valve     = K_valve * q_v;
            properties.p = properties.p - dP_valve;
        end

        % Check Valve, applied downstream of the Main Oxidizer Valve
        if i == N_check
            rho_c        = py.CoolProp.CoolProp.PropsSI('D', 'P', properties.p, 'T', properties.T, 'Oxygen');
            v_c          = inputs.m_dot_oxidizer / (rho_c * A);
            q_c          = 0.5 * rho_c * v_c^2;
            dP_check     = K_check * q_c;
            properties.p = properties.p - dP_check;
        end
    end

    %% Final properties update
    properties.rho = py.CoolProp.CoolProp.PropsSI('D',      'P', properties.p, 'T', properties.T, 'Oxygen');
    properties.c_p = py.CoolProp.CoolProp.PropsSI('CPMASS', 'P', properties.p, 'T', properties.T, 'Oxygen');
    properties.v   = inputs.m_dot_oxidizer / (properties.rho * A);

    %% Dynamic pressure at outlet (for bookkeeping)
    dP_dyn = 0.5 * properties.rho * properties.v^2;

    %% Output
    key_values.Pressures.dP_fric         = dP_fric_total;
    key_values.Pressures.dP_geom         = dP_geom;
    key_values.Pressures.dP_valve        = dP_valve;
    key_values.Pressures.K_valve         = K_valve;
    key_values.Pressures.dP_check        = dP_check;
    key_values.Pressures.K_check         = K_check;
    key_values.Pressures.dP_irreversible = dP_fric_total + dP_geom + dP_valve + dP_check;
    key_values.Pressures.dP_dyn          = dP_dyn;
    key_values.Re                        = (properties.rho * properties.v * D) / ...
                                            py.CoolProp.CoolProp.PropsSI('V', 'P', properties.p, 'T', properties.T, 'Oxygen');
    key_values.deltaP                    = dP_fric_total + dP_geom;
end

% -----------------------------------------------------------------------
function f_d = friction_factor(Re)
    if Re < 2000
        f_d = 64 / Re;
    elseif Re > 4000
        arg = 0.629 * Re;
        W   = lambertw(0, arg);
        f_d = 1 / (0.838 * W)^2;
    else
        f_lam  = 64 / 2000;
        arg_t  = 0.629 * 4000;
        W_t    = lambertw(0, arg_t);
        f_turb = 1 / (0.838 * W_t)^2;
        alpha  = (Re - 2000) / (4000 - 2000);
        f_d    = (1 - alpha) * f_lam + alpha * f_turb;
    end
end