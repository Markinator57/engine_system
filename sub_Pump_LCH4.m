function [properties, key_values] = sub_Pump_LCH4(inputs, properties)
    p_intermediate = properties.p + inputs.delta_p_pump_LCH4;
    properties.p = p_intermediate - inputs.delta_p_partial;
    
    P_pump = (inputs.m_dot_fuel * inputs.delta_p_pump_LCH4) / (inputs.eta_pump_LCH4 * properties.rho);
    
    properties.T = properties.T + P_pump * (1 - inputs.eta_pump_LCH4) / properties.c_p;
    
    properties.rho = py.CoolProp.CoolProp.PropsSI('D', 'P', properties.p, 'T', properties.T, 'Methane');
    properties.c_p = py.CoolProp.CoolProp.PropsSI('CPMASS', 'T', properties.T, 'P', properties.p, 'Methane');

    key_values = P_pump;
end