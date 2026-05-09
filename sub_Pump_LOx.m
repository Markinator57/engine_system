function [properties, key_values] = sub_Pump_LOx(inputs, properties)

    % TODO: Research validity of Formulary equations in real life
    %       Polytropic exponent?
    %       Add 1-eta energy to temperature?
    %       Research more realistic equations/transformations
    
    p_intermediate = properties.p + inputs.delta_p_pump_LOx;
    properties.p = p_intermediate - inputs.delta_p_partial;
    
    P_pump = (inputs.m_dot_oxidizer * inputs.delta_p_pump_LOx) / (inputs.eta_pump_LOx * properties.rho);
    
    properties.T = properties.T + P_pump * (1 - inputs.eta_pump_LOx) / properties.c_p;
    
    properties.rho = py.CoolProp.CoolProp.PropsSI('D', 'P', properties.p, 'T', properties.T, 'Oxygen');
    properties.c_p = py.CoolProp.CoolProp.PropsSI('CPMASS', 'T', properties.T, 'P', properties.p, 'Oxygen');

    key_values = P_pump;
end