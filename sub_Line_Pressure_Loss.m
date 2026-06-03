function [properties, key_values] = sub_Line_Pressure_Loss(inputs, properties)



    properties.p = properties.p - inputs.delta_p; % Pressure after pump, after partial losses, which is the turbine inlet pressure.
    
    P_pump = (inputs.m_dot_fuel * inputs.delta_p_pump_LCH4) / (inputs.eta_pump_LCH4 * properties.rho);
    
    properties.T = properties.T + P_pump * (1 - inputs.eta_pump_LCH4) / (inputs.m_dot_fuel * properties.c_p);  % Temperatre after pump, adding 1-eta energy to temperature

    properties.rho = py.CoolProp.CoolProp.PropsSI('D', 'P', properties.p, 'T', properties.T, 'Methane');
    properties.c_p = py.CoolProp.CoolProp.PropsSI('CPMASS', 'T', properties.T, 'P', properties.p, 'Methane');

    key_values = P_pump;
end