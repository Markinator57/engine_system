function [properties, key_values] = sub_Turbine_LOx(inputs, properties)

    % Forward isentropic expansion model.
    % Exit pressure is a system constraint (injector + chamber), not derived from required power.
    % Feasibility: available shaft power must exceed pump demand.
    % Working fluid is methane (fuel stream drives both turbines).

    p_in  = properties.p;
    p_out = inputs.p_turbine_LOx_out;

    h_in    = py.CoolProp.CoolProp.PropsSI('H', 'T', properties.T, 'P', p_in, 'Methane');
    s_in    = py.CoolProp.CoolProp.PropsSI('S', 'T', properties.T, 'P', p_in, 'Methane');
    h_out_s = py.CoolProp.CoolProp.PropsSI('H', 'P', p_out, 'S', s_in, 'Methane');

    h_out       = h_in - inputs.eta_turbine_LOx * (h_in - h_out_s);
    W_available = inputs.m_dot_fuel * (h_in - h_out);

    if W_available < inputs.P_turbine_LOx_needed
        warning('LOx turbine: available %.1f W < needed %.1f W — pump pressure too low to close cycle', ...
                W_available, inputs.P_turbine_LOx_needed);
    else
        warning('LOx turbine: surplus: available %.1f W > needed %.1f W (excess %.1f W)', ...
                W_available, inputs.P_turbine_LOx_needed, W_available - inputs.P_turbine_LOx_needed);
    end

    properties.T   = py.CoolProp.CoolProp.PropsSI('T', 'P', p_out, 'H', h_out, 'Methane');
    properties.p   = p_out;
    properties.rho = py.CoolProp.CoolProp.PropsSI('D', 'P', p_out, 'T', properties.T, 'Methane');
    properties.c_p = py.CoolProp.CoolProp.PropsSI('CPMASS', 'T', properties.T, 'P', p_out, 'Methane');

    key_values.delta_p     = p_in - p_out;
    key_values.W_available = W_available;
end
