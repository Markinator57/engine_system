function [properties, key_values] = sub_PressureLoss_Pump_LCH4_to_Cooling(inputs, properties)

    D   = inputs.D_Pump_to_Cooling_Inlet;
    A   = (D/2)^2 * pi;
    L   = inputs.L_Pump_to_Cooling_Inlet;
    K   = 0.8;          % Combined minor-loss coefficient for fuel feedline bends, valves, and control-system losses only
    N   = 100;          % Number of segments
    dx  = L / N;        % Segment length [m]

    %% Minor/geometric loss — applied once at pipe entrance
    v_inlet      = inputs.m_dot_fuel / (properties.rho * A);
    q_inlet      = 0.5 * properties.rho * v_inlet^2;
    dP_geom      = K * q_inlet;
    properties.p = properties.p - dP_geom;

    %% Segmented Darcy-Weisbach integration
    dP_fric_total = 0;

    for i = 1:N
        rho_i = py.CoolProp.CoolProp.PropsSI('D', 'P', properties.p, 'T', properties.T, 'Methane');
        mu_i  = py.CoolProp.CoolProp.PropsSI('V', 'P', properties.p, 'T', properties.T, 'Methane');

        v_i  = inputs.m_dot_fuel / (rho_i * A);
        Re_i = (rho_i * v_i * D) / mu_i;
        q_i  = 0.5 * rho_i * v_i^2;

        f_i           = friction_factor(Re_i);
        dP_i          = f_i * (dx / D) * q_i;
        dP_fric_total = dP_fric_total + dP_i;
        properties.p  = properties.p - dP_i;
    end

    %% Final properties update
    properties.rho = py.CoolProp.CoolProp.PropsSI('D',      'P', properties.p, 'T', properties.T, 'Methane');
    properties.c_p = py.CoolProp.CoolProp.PropsSI('CPMASS', 'P', properties.p, 'T', properties.T, 'Methane');
    properties.v   = inputs.m_dot_fuel / (properties.rho * A);

    %% Dynamic pressure at outlet (for bookkeeping)
    dP_dyn = 0.5 * properties.rho * properties.v^2;

    %% Output
    key_values.Pressures.dP_fric         = dP_fric_total;
    key_values.Pressures.dP_geom         = dP_geom;
    key_values.Pressures.dP_irreversible = dP_fric_total + dP_geom;
    key_values.Pressures.dP_dyn          = dP_dyn;
    key_values.Re                        = (properties.rho * properties.v * D) / ...
                                            py.CoolProp.CoolProp.PropsSI('V', 'P', properties.p, 'T', properties.T, 'Methane');
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