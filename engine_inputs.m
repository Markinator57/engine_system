function [inputs, properties_fuel, properties_oxidizer] = engine_inputs()

%% Physical constants
inputs.g0 = 9.8067;
inputs.R_gas = 8314;

%% Engine requirements
inputs.F_thrust_req = 40e3;             % N
inputs.p_CC_req = 80e5;                 % Pa
inputs.Isp = 340;                       % s (TBD)

%% Efficiencies
inputs.eta_pump_LOx = 0.93;             % (TBD)
inputs.eta_pump_LCH4 = 0.93;            % (TBD)
inputs.eta_turbine_LOx = 0.90;          % (TBD)
inputs.eta_turbine_LCH4 = 0.90;         % (TBD)
inputs.eta_combustion = 0.97;           % (TBD)
inputs.eta_nozzle = 0.96;               % (TBD)

%% Propellant properties
inputs.ROF = 3.4;                % (TBD)
[T_CC, M] = get_cea_properties(inputs.p_CC_req, inputs.ROF);
inputs.T_CC_ideal = T_CC;
inputs.Molar_mass_CC_ideal = M;
inputs.kappa_CC_ideal = py.CoolProp.CoolProp.PropsSI('isentropic_expansion_coefficient', 'P', inputs.p_CC_req, 'T', inputs.T_CC_ideal, 'Methane');
inputs.v_e_ideal = sqrt(inputs.eta_nozzle * 2 * (inputs.kappa_CC_ideal/(inputs.kappa_CC_ideal-1)) * (inputs.R_gas/inputs.Molar_mass_CC_ideal) * inputs.T_CC_ideal * (1 - (101300/inputs.p_CC_req)^((inputs.kappa_CC_ideal-1)/inputs.kappa_CC_ideal)));

%% Get necessary massflow:
inputs.m_dot_tot = inputs.F_thrust_req / inputs.v_e_ideal;
inputs.m_dot_fuel = inputs.m_dot_tot / (inputs.ROF + 1);
inputs.m_dot_oxidizer = inputs.m_dot_tot - inputs.m_dot_fuel;

%% Pressures
inputs.delta_p_inj_percent = 0.20; % (TBD)
inputs.delta_p_cooling_channels = 5e5;    % Pa % (TBD)
inputs.delta_p_feed = 2e5;       % Pa
inputs.delta_p_partial = inputs.delta_p_feed / 5;

inputs.delta_p_pump_LCH4 = 15e6;
inputs.delta_p_pump_LOx = 10e6;

%% Cooling assumptions
inputs.Q_dot = 1e6; %(TBD)

%% Fuel properties (input here initial properties
properties_fuel.T = 110;
properties_fuel.p = 2e5;
properties_fuel.rho = py.CoolProp.CoolProp.PropsSI('D', 'P', properties_fuel.p, 'T', properties_fuel.T, 'Methane');
properties_fuel.c_p = py.CoolProp.CoolProp.PropsSI('CPMASS', 'T', properties_fuel.T, 'P', properties_fuel.p, 'Methane');

%% Fuel properties (input here initial properties);
properties_oxidizer.T = 90;
properties_oxidizer.p = 2e5;
properties_oxidizer.rho = py.CoolProp.CoolProp.PropsSI('D', 'P', properties_oxidizer.p, 'T', properties_oxidizer.T, 'Oxygen');
properties_oxidizer.c_p = py.CoolProp.CoolProp.PropsSI('CPMASS', 'T', properties_oxidizer.T, 'P', properties_oxidizer.p, 'Oxygen');

end