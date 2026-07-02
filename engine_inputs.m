function [inputs, properties_fuel, properties_oxidizer] = engine_inputs()
    %% Pipes and Valves. Geometries
    % --- CH4 (Fuel) Line ---
    inputs.L_Tank_to_Pump              = 1.50;   % [m] Tank outlet to CH4 pump inlet
    inputs.L_Pump_to_Cooling_Inlet     = 0.80;   % [m] CH4 pump outlet to regen cooling jacket inlet
    inputs.L_Cooling_Outlet_to_Turbine = 0.60;   % [m] Cooling jacket outlet to turbine inlet
    
    % --- Turbine-to-Turbine crossover (if dual-turbine / separate shafts) ---
    inputs.L_TurbineCH4_to_TurbineOx  = 0.40;   % [m] CH4 turbine outlet to LOX turbine inlet (gas path)
    
    % --- LOX Lines ---
    inputs.L_TurbineOx_to_Injector    = 0.50;   % [m] LOX turbine exit to injector
    inputs.L_OxPump_to_Injector       = 1.20;   % [m] LOX pump outlet to injector (bypass / direct line)
    
    % --- Pipe Inner Diameters ---
    inputs.D_Tank_to_Pump             = 0.063;  % [m] ~63 mm | CH4 tank outlet (low-pressure, low velocity)
    inputs.D_Pump_to_Cooling_Inlet    = 0.040;  % [m] ~40 mm | High-pressure CH4 after pump
    inputs.D_Cooling_Outlet_to_Turbine= 0.040;  % [m] ~40 mm | Supercritical CH4, high pressure
    inputs.D_TurbineCH4_to_TurbineOx  = 0.050;  % [m] ~50 mm | Hot gas crossover duct
    inputs.D_TurbineOx_to_Injector    = 0.050;  % [m] ~50 mm | LOX turbopump exit to injector
    inputs.D_OxPump_to_Injector       = 0.080;  % [m] ~80 mm | LOX main feed line (high flow rate)

    %% Physical constants
    inputs.g0 = 9.8067;                     % [m/s^2]
    inputs.R_gas = 8314.4;                  % [J/(kmol·K)]

    %% Engine requirements
    inputs.F_thrust_req = 40e3;             % [N]
    inputs.p_CC_req = 80e5;                 % [Pa]

    %% Efficiencies
    inputs.eta_pump_LOx = 0.7;             % (Ask teams and revise)
    inputs.eta_pump_LCH4 = 0.68;            % (Ask teams and revise)
    inputs.eta_turbine_LOx = 0.75;          % (Ask teams and revise)
    inputs.eta_turbine_LCH4 = 0.75;         % (Ask teams and revise)
    inputs.eta_combustion = 0.98;           % (Ask teams and revise)
    inputs.eta_nozzle = 0.96;               % (Ask teams and revise)

    %% Propellant properties
    inputs.ROF = 3.09;                       % (Research and ask Thrust chamber)  stoch
    [T_CC, M, k] = get_cea_properties(inputs.p_CC_req, inputs.ROF);
    inputs.T_CC_ideal = T_CC;
    inputs.Molar_mass_CC_ideal = M;
    inputs.kappa_CC_ideal = k;
    inputs.v_e_ideal = sqrt(inputs.eta_nozzle * 2 * (inputs.kappa_CC_ideal/(inputs.kappa_CC_ideal-1)) * (inputs.R_gas/inputs.Molar_mass_CC_ideal) * inputs.T_CC_ideal * (1 - (101300/inputs.p_CC_req)^((inputs.kappa_CC_ideal-1)/inputs.kappa_CC_ideal)));

    %% Get necessary massflow (at given ROF):
    inputs.m_dot_tot = inputs.F_thrust_req / inputs.v_e_ideal;    % add pressure terms later, when nozzle defined
    inputs.m_dot_fuel = inputs.m_dot_tot / (inputs.ROF + 1);
    inputs.m_dot_oxidizer = inputs.m_dot_tot - inputs.m_dot_fuel;

    %% Pressures
    inputs.delta_p_inj_fuel = 8e5;            % [Pa] fuel injector pressure drop
    inputs.delta_p_inj_oxidizer = 12e5;      % [Pa] oxidizer injector pressure drop
    inputs.delta_p_cooling_channels = 24.2184e5; % [Pa]      % (Research and ask Thrust Chamber)
    inputs.delta_p_pump_LCH4 = 6e6;         % [Pa]      % initial guess for solver — tuned to p_CC_req

    % Injector inlet pressures required to land at chamber pressure after each injector drop.
    inputs.p_fuel_injector_inlet = inputs.p_CC_req + inputs.delta_p_inj_fuel;
    inputs.p_oxidizer_injector_inlet = inputs.p_CC_req + inputs.delta_p_inj_oxidizer;

    % The methane turbine train must deliver fuel to the injector at the fuel-side target pressure.
    % The LOx pump chain is independent and uses the oxidizer-side target pressure.
    inputs.p_turbine_exit = inputs.p_fuel_injector_inlet;

    % LOx pump rise derived from oxidizer injector requirement so the chain always closes:
    % p_exit_LOx = p_tank + delta_p_pump_LOx - delta_p_partial = p_oxidizer_injector_inlet
    p_tank_LOx = 2e5;                       % [Pa]  oxidizer tank pressure
    inputs.delta_p_pump_LOx = inputs.p_oxidizer_injector_inlet - p_tank_LOx;

    %% Cooling assumptions
    inputs.Heating_radiation_factor = 1.03;  
    inputs.Q_dot = 4.985657e6 * inputs.Heating_radiation_factor;                     % [J/s]     % (Ask Thrust Chamber)

    %% Fuel properties (input here initial properties) 
    properties_fuel.T = 110;                % [K]       % (Design choice, fairly easy, just a quick research)
    properties_fuel.p = 2e5;                % [Pa]
    properties_fuel.rho = py.CoolProp.CoolProp.PropsSI('D', 'P', properties_fuel.p, 'T', properties_fuel.T, 'Methane');
    properties_fuel.c_p = py.CoolProp.CoolProp.PropsSI('CPMASS', 'T', properties_fuel.T, 'P', properties_fuel.p, 'Methane');

    %% Oxidizer properties (input here initial properties)
    properties_oxidizer.T = 90;             % [K]
    properties_oxidizer.p = 2e5;            % [Pa]
    properties_oxidizer.rho = py.CoolProp.CoolProp.PropsSI('D', 'P', properties_oxidizer.p, 'T', properties_oxidizer.T, 'Oxygen');
    properties_oxidizer.c_p = py.CoolProp.CoolProp.PropsSI('CPMASS', 'T', properties_oxidizer.T, 'P', properties_oxidizer.p, 'Oxygen');
    
    %% Turbine geometry inputs
    inputs.D_mean_LCH4    = 0.05;    % [m]   Initial estimate — update from impeller sizing
    inputs.nu_target_LCH4 = 0.45;    % [-]   Blade speed ratio target (impulse: 0.35–0.50)
    inputs.D_mean_LOx     = 0.06;    % [m]   Initial estimate
    inputs.nu_target_LOx  = 0.45;    % [-]   Blade speed ratio target
end