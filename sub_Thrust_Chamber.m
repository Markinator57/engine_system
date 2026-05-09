function [key_values] = sub_Thrust_Chamber(inputs, properties_oxidizer, properties_fuel)
    % Assumes ideally adapted nozzle --> review
    p_out = 101300;
    p_in = (properties_oxidizer.p + properties_fuel.p) / 2;
    T_in = (properties_oxidizer.T + properties_fuel.T) / 2;
    kappa = py.CoolProp.CoolProp.PropsSI('isentropic_expansion_coefficient', 'P', p_in, 'T', T_in, 'Methane');

    % Dependency on CoolProp library!!
    [T_CC, Molar_mass] = get_cea_properties(p_in, inputs.ROF);

    v_e = sqrt(inputs.eta_nozzle * 2 * (kappa/(kappa-1)) * inputs.R_gas/Molar_mass * T_CC * (1 - (p_out/p_in)^((kappa-1)/kappa)));

    F_thrust = inputs.m_dot_tot * v_e;

    key_values.T_CC = T_CC;
    key_values.Molar_mass = Molar_mass;
    key_values.v_e = v_e;
    key_values.F_thrust = F_thrust;
end