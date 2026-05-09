function [properties, key_values] = sub_Cooling_channels(inputs, properties)

    % TODO: Research/ask for a more accurate esstimate of Q_dot
    %       Have Q_dot dependent on other quantities? percentage of energy in thrust chamber? Research
    %       Check correct use of CoolProp over state transition into supercritical
    %       Research validity of isobaric assumption

    % m_dot * h_in + Q_dot = m_dot * h_out
    h_in = py.CoolProp.CoolProp.PropsSI('H', 'P', properties.p, 'T', properties.T, 'Methane');
    h_out = h_in + inputs.Q_dot / inputs.m_dot_fuel;
    
    properties.p
    T_in = properties.T;
    properties.T = py.CoolProp.CoolProp.PropsSI('T', 'P', properties.p, 'H', h_out, 'Methane');
    delta_T = properties.T - T_in;

    properties.p = properties.p - inputs.delta_p_partial;

    properties.rho = py.CoolProp.CoolProp.PropsSI('D', 'P', properties.p, 'T', properties.T, 'Methane');
    properties.c_p = py.CoolProp.CoolProp.PropsSI('CPMASS', 'T', properties.T, 'P', properties.p, 'Methane');

    key_values = delta_T;
end

