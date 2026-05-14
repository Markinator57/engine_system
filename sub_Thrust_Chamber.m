function [key_values] = sub_Thrust_Chamber(inputs, properties_oxidizer, properties_fuel)

    % TODO: Setting p_out to 1 atm assumes ideally adapted nozzle, we want that yes,
    %           but that also depends on p_CC, so need to review way of formulating, so as to not hardcode it
    %       Add some Q_dot model here?
    %       p_CC inaccurate, also not reaaaally that important if both p_fuel and p_oxi converge, but nevertheless.
    %       Expand model to more accurate?
    %       Ask thrust chamber, they surely already researched something

    p_out = 101300;
    p_in = (properties_oxidizer.p + properties_fuel.p) / 2;

    [T_CC_ideal, Molar_mass, kappa] = get_cea_properties(p_in, inputs.ROF);

    % Apply combustion efficiency: incomplete combustion lowers effective flame temperature
    T_CC = T_CC_ideal * inputs.eta_combustion;

    v_e = sqrt(inputs.eta_nozzle * 2 * (kappa/(kappa-1)) * inputs.R_gas/Molar_mass * T_CC * (1 - (p_out/p_in)^((kappa-1)/kappa)));

    F_thrust = inputs.m_dot_tot * v_e;

    key_values.T_CC_ideal = T_CC_ideal;
    key_values.T_CC = T_CC;
    key_values.Molar_mass = Molar_mass;
    key_values.v_e = v_e;
    key_values.F_thrust = F_thrust;
end