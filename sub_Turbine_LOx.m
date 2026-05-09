function [properties, key_values] = sub_Turbine_LOx(inputs, properties)
    T_in = properties.T;
    properties.T = - inputs.P_turbine_LOx_needed / (inputs.eta_turbine_LOx * inputs.m_dot_fuel * properties.c_p) + properties.T;
    
    kappa = py.CoolProp.CoolProp.PropsSI('isentropic_expansion_coefficient', 'P', properties.p, 'T', T_in, 'Methane');
    p_in = properties.p;
    properties.p = properties.p * (properties.T / T_in)^(kappa / (kappa -1)) - inputs.delta_p_partial;
    delta_p = properties.p - p_in;

    properties.rho = py.CoolProp.CoolProp.PropsSI('D', 'P', properties.p, 'T', properties.T, 'Methane');
    properties.c_p = py.CoolProp.CoolProp.PropsSI('CPMASS', 'T', properties.T, 'P', properties.p, 'Methane');

    key_values = delta_p;
end