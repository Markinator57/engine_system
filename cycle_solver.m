function [key_values, properties_flow] = cycle_solver ()

    % TODO: Add iterations for convergence, convergence criteria is p_fuel & p_oxi == 80 bar at injector outlet
    %       Add *more* visualization tools for the flow values all over the cycle

    [inputs, properties_fuel, properties_oxidizer] = engine_inputs();

    %% Tanks 🡇
    properties_flow.fuel.Tanks = properties_fuel;

    properties_flow.oxidizer.Tanks = properties_oxidizer;

    %% Pumps 🡇

    [properties_fuel, key_values.P_Pump_LCH4] = sub_Pump_LCH4(inputs, properties_fuel);
    properties_flow.fuel.Pump_LCH4 = properties_fuel;
    inputs.P_turbine_LCH4_needed = key_values.P_Pump_LCH4 / inputs.eta_turbine_LCH4;

    [properties_oxidizer, key_values.P_Pump_LOx] = sub_Pump_LOx(inputs, properties_oxidizer);
    properties_flow.oxidizer.Pump_LOx = properties_oxidizer;
    inputs.P_turbine_LOx_needed = key_values.P_Pump_LOx / inputs.eta_turbine_LOx;

    %% Cooling Channels 🡇 (only fuel)

    [properties_fuel, key_values.delta_T_Cooling_Channels] = sub_Cooling_channels(inputs, properties_fuel);
    properties_flow.fuel.Cooling_Channels = properties_fuel;

    %% Turbine LCH4 🡇 (only fuel)

    [properties_fuel, key_values.delta_p_Turbine_LCH4] = sub_Turbine_LCH4(inputs, properties_fuel);
    properties_flow.fuel.Turbine_LCH4 = properties_fuel;

    %% Turbine LOx 🡇 (only fuel)
    
    [properties_fuel, key_values.delta_p_Turbine_LOx] = sub_Turbine_LOx(inputs, properties_fuel);
    properties_flow.fuel.Turbine_LOx = properties_fuel;

    %% Injector 🡇

    [properties_fuel, key_values.TC_Ingoing_fuel] = sub_Injector_CH4(inputs, properties_fuel);
    properties_flow.fuel.Injector = properties_fuel;

    [properties_oxidizer, key_values.TC_Ingoing_oxidizer] = sub_Injector_LOx(inputs, properties_oxidizer);
    properties_flow.oxidizer.Injector = properties_oxidizer;

    %% Thrust Chamber 🡇
    [key_values.Thrust_Chamber] = sub_Thrust_Chamber(inputs, properties_oxidizer, properties_fuel);


    %% Visualization
    plot_cycle(key_values, properties_flow)
end