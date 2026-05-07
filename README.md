# engine_system
RP__II expander engine cycle development project.

## Architecture

The initial idea is that there be different individual functions for each of the subsystems, where we input the ingoing fluid's properties and get the outgoing properties according to the changes in the subsystem

After that, a function for the entire cycle, with different free-choice design parameters as inputs, would call on the individual functions one by one passing on the fluid's properties cascadingly.

```

[efficiencies, Power, delta_p_Pump_LOx, etc] = full_cycle (R_OF, T_c, etc)
    [properties1] = sub_Tanks(properties0)
    [properties2] = sub_Pump(properties1)
    [properties3] = sub_Cooling(properties2)
    [properties4] = sub_Turbine(properties3)
    [properties5] = sub_Turbine(properties4)
    [properties6] = sub_Injector(properties5)
    ...
[efficiencies, Power, delta_p_Pump_LOx, etc] = (properties_n)

```

Feel free to clone the repo and edit and commit whatever you guys want.
