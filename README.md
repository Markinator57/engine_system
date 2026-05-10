# Expander Cycle Engine Simulation — Codebase Documentation

## Project Overview

This MATLAB codebase simulates a **liquid rocket engine expander cycle** for TUM M.Sc. Aerospace coursework (RP II). The engine burns Liquid Methane (LCH4) and Liquid Oxygen (LOx) targeting 40 kN thrust at 80 bar chamber pressure with a specific impulse of ~340 s.

The architecture is a **cascading subsystem model**: each engine component is its own function that receives a fluid property struct, computes thermodynamic changes, and passes updated properties downstream. Fluid properties are queried from CoolProp (Python) and combustion properties from NASA CEA.

---

## File Structure

```
engine_system/
├── engine_inputs.m          # Central parameter definition
├── cycle_solver.m           # Main orchestrator / cascade driver
├── get_cea_properties.m     # NASA CEA interface (chemistry)
├── plot_cycle.m             # Thermodynamic state visualization
├── sub_Pump_LCH4.m          # Fuel pump model
├── sub_Pump_LOx.m           # Oxidizer pump model
├── sub_Cooling_channels.m   # Regenerative cooling jacket
├── sub_Turbine_LCH4.m       # Turbine driving fuel pump
├── sub_Turbine_LOx.m        # Turbine driving oxidizer pump
├── sub_Injector_CH4.m       # Fuel injector pressure drop
├── sub_Injector_LOx.m       # Oxidizer injector pressure drop
├── sub_Thrust_Chamber.m     # Combustion chamber + nozzle
├── README.md                # Architecture philosophy overview
└── CODEBASE.md              # This file
```

---

## Architecture & Data Flow

The simulation runs as a linear cascade (no convergence loop yet):

```
engine_inputs()
    └── Initializes: inputs struct, properties_fuel (CH4 @ 110 K), properties_oxidizer (LOx @ 90 K)

cycle_solver.m  [main script]
    ├── [1] Tanks          → properties_flow.tank_fuel / tank_oxi
    ├── [2] sub_Pump_LCH4  → properties_flow.pump_fuel   + key_values.P_pump_fuel
    ├── [3] sub_Pump_LOx   → properties_flow.pump_oxi    + key_values.P_pump_oxi
    ├── [4] sub_Cooling_channels → properties_flow.cooling + key_values.delta_T_cooling
    ├── [5] sub_Turbine_LCH4    → properties_flow.turbine_fuel + key_values.delta_p_turb_fuel
    ├── [6] sub_Turbine_LOx     → properties_flow.turbine_oxi  + key_values.delta_p_turb_oxi
    ├── [7] sub_Injector_CH4    → properties_flow.inj_fuel     + key_values.p_inj_fuel
    ├── [8] sub_Injector_LOx    → properties_flow.inj_oxi      + key_values.p_inj_oxi
    └── [9] sub_Thrust_Chamber  → key_values.T_CC, v_e, F_thrust

plot_cycle(key_values, properties_flow, inputs)
    └── Renders annotated T-p cascade diagram for both propellant lines
```

The `properties_*` structs carry `{T, p, rho, c_p}` at each stage. CoolProp is called after each component to update these values at the new thermodynamic state.

---

## File-by-File Reference

### [engine_inputs.m](engine_inputs.m)

**Signature**: `[inputs, properties_fuel, properties_oxidizer] = engine_inputs()`

Defines all fixed design parameters and computes derived quantities. This is the single source of truth for engine requirements and component efficiencies.

| Variable | Value | Description |
|---|---|---|
| `F_thrust_req` | 40 000 N | Required thrust |
| `p_CC_req` | 80 × 10⁵ Pa | Target chamber pressure |
| `Isp` | 340 s | Specific impulse |
| `eta_pump` | 0.93 | Pump isentropic efficiency |
| `eta_turbine` | 0.90 | Turbine isentropic efficiency |
| `eta_combustion` | 0.97 | Combustion efficiency |
| `eta_nozzle` | 0.96 | Nozzle efficiency |
| `ROF` | 3.4 | Oxidizer-to-fuel mass ratio |
| `Q_dot` | 5 × 10⁶ W | Cooling heat load |
| `delta_p_pump_fuel/oxi` | (Pa) | Pump pressure rise |
| `m_dot_total` | (kg/s) | Total mass flow from F/v_e |
| `m_dot_fuel/oxi` | (kg/s) | Split from ROF |

Initial propellant states are set here:
- **Fuel**: CH4 at 110 K, 2 × 10⁵ Pa
- **Oxidizer**: O2 at 90 K, 2 × 10⁵ Pa

Calls `get_cea_properties(p_CC_req, ROF)` to get combustion temperature, molar mass, and gamma before computing the ideal exhaust velocity and mass flows.

---

### [cycle_solver.m](cycle_solver.m)

**Type**: Script (not a function)

Drives the cascade by calling each subsystem in series. Collects results into two output structs:

- `key_values` — scalar performance metrics (powers, pressures, temperatures, thrust)
- `properties_flow` — fluid state history; each field is a properties struct at that component's outlet

After the cascade, calls `plot_cycle(key_values, properties_flow, inputs)`.

**Known limitation**: No convergence loop. The solver currently runs open-loop; a future iteration should loop until the injector face pressures (fuel and oxidizer) both converge to 80 bar.

---

### [get_cea_properties.m](get_cea_properties.m)

**Signature**: `[T_CC, M, k] = get_cea_properties(p_CC, R_OF)`

Interfaces with the NASA CEA library via MATLAB's Python bridge (`py.*`).

| Output | Unit | Description |
|---|---|---|
| `T_CC` | K | Adiabatic flame temperature |
| `M` | kg/mol | Combustion product molar mass |
| `k` | — | Specific heat ratio (gamma) |

Internally converts Pa → psia for CEA, Rankine → Kelvin for temperature. The CEA object is stored as a `persistent` variable so it is only initialized once across repeated calls.

**Dependencies**: Python environment with `RocketCEA` installed and accessible to MATLAB.

---

### [plot_cycle.m](plot_cycle.m)

**Signature**: `plot_cycle(key_values, properties_flow, inputs)`

Generates a 1400 × 920 dark-background figure showing both propellant lines side by side:

- **Left column**: Fuel (LCH4) — blue accent
- **Right column**: Oxidizer (LOx) — green accent

Each stage is drawn as a white box. Temperature values use a warm color scale (orange → crimson); pressure values use a cool scale (cornflower blue → navy). Colorbars are added for both.

Annotated values beside each box:
- Pumps: shaft power (kW)
- Cooling channels: heat input (MW) and temperature rise (K)
- Turbines: temperature drop (K) and pressure drop (bar)

The thrust chamber appears at the bottom center with a gold border showing T_CC, exhaust velocity, and thrust.

**Internal helpers** (defined at end of file):
| Helper | Description |
|---|---|
| `draw_stage(ax, x, y, label, T, p, t_color, p_color)` | Draws component box with T/p annotation |
| `ann_r(ax, x, y, str)` | Right-side annotation with connector line |
| `ann_l(ax, x, y, str)` | Left-side annotation with connector line |
| `arr(ax, x1, y1, x2, y2)` | Flow arrow with arrowhead |

---

### [sub_Pump_LCH4.m](sub_Pump_LCH4.m) & [sub_Pump_LOx.m](sub_Pump_LOx.m)

**Signature**: `[properties_out, P_pump] = sub_Pump_LCH4(properties_in, inputs)`  
**Signature**: `[properties_out, P_pump] = sub_Pump_LOx(properties_in, inputs)`

Models isentropic compression with efficiency loss.

**Physics**:

$$p_{out} = p_{in} + \Delta p_{pump} - \Delta p_{L\&V_{partial}}$$

$$\dot{W}_{pump} = \frac{\dot{m} \cdot \Delta p}{\eta_{pump} \cdot \rho_{in}}$$

$$\Delta T = \frac{\dot{W}_{pump} \cdot (1 - \eta_{pump})}{\dot{m} \cdot c_p}$$

$$T_{out} = T_{in} + \Delta T$$

After computing new T and p, CoolProp is queried for updated `{rho, c_p}`.

**TODO**: Polytropic exponent validation; more realistic pump map model.

---

### [sub_Cooling_channels.m](sub_Cooling_channels.m)

**Signature**: `[properties_out, delta_T] = sub_Cooling_channels(properties_in, inputs)`

Models the regenerative cooling jacket where methane absorbs waste heat from the thrust chamber wall before entering the turbine(s).

**Physics** (isobaric heating):

$$h_{out} = h_{in} + \frac{\dot{Q}}{\dot{m}_{fuel}}$$

$$T_{out} = \text{CoolProp}(p_{in},\, h_{out},\, \text{CH}_4)$$

$$p_{out} = p_{in} - \Delta p_{cooling} - \Delta p_{L\&V_{partial}}$$

**TODO**: Q_dot is a hardcoded 5 MW constant; should be coupled to the thrust chamber heat flux model. Supercritical methane behavior at high pressures needs validation.

---

### [sub_Turbine_LCH4.m](sub_Turbine_LCH4.m) & [sub_Turbine_LOx.m](sub_Turbine_LOx.m)

**Signature**: `[properties_out, delta_p] = sub_Turbine_LCH4(properties_in, P_pump_needed, inputs)`  
**Signature**: `[properties_out, delta_p] = sub_Turbine_LOx(properties_in, P_pump_needed, inputs)`

Models isentropic expansion with efficiency to extract shaft power.

**Physics**:

$$\dot{W}_{turbine} = \frac{\dot{W}_{pump}}{\eta_{turbine}}$$

$$\Delta T = -\frac{\dot{W}_{turbine}}{\eta_{turbine} \cdot \dot{m} \cdot c_p}$$

$$T_{out} = T_{in} + \Delta T$$

$$p_{out} = p_{in} \left(\frac{T_{out}}{T_{in}}\right)^{\kappa / (\kappa - 1)} - \Delta p_{L\&V_{partial}}$$

$$\Delta p = p_{in} - p_{out}$$

in `sub_Turbine_LOx`: the fluid is still methane (fuel passes through both turbines in this expander cycle topology). The CoolProp queries correctly use `"CH4"` internally.

**TODO**: Isentropic assumption validation; polytropic turbine model.

---

### [sub_Injector_CH4.m](sub_Injector_CH4.m) & [sub_Injector_LOx.m](sub_Injector_LOx.m)

**Signature**: `[T_inj, p_inj, properties_out] = sub_Injector_CH4(properties_in, inputs)`  
**Signature**: `[T_inj, p_inj, properties_out] = sub_Injector_LOx(properties_in, inputs)`

Models the pressure drop across the injector head (20% of inlet pressure, defined at engine_inputs) with no heat transfer.

**Physics**:

$$p_{out} = p_{in} \cdot (1 - 0.20)$$

$$T_{out} = T_{in} \quad \text{(isothermal)}$$

**TODO**: 20% pressure drop is a design rule of thumb; needs validation against injector team sizing. Porous injector pressure recovery not modeled.

---

### [sub_Thrust_Chamber.m](sub_Thrust_Chamber.m)

**Signature**: `[T_CC, M_CC, v_e, F_thrust] = sub_Thrust_Chamber(properties_fuel_in, properties_oxi_in, inputs)`

Models combustion and isentropic nozzle expansion.

**Physics**:

$$p_{CC} = \frac{p_{fuel,in} + p_{oxi,in}}{2}$$

$$[T_{CC},\, M,\, k] = \text{CEA}(p_{CC},\, \text{ROF})$$

$$v_e = \sqrt{\eta_{nozzle} \cdot \frac{2k}{k-1} \cdot \frac{R}{M} \cdot T_{CC} \cdot \left[1 - \left(\frac{p_{exit}}{p_{CC}}\right)^{(k-1)/k}\right]}$$

$$F = (\dot{m}_{fuel} + \dot{m}_{oxi}) \cdot v_e$$

Exit pressure is hardcoded to 101 325 Pa (sea level), assuming a perfectly expanded nozzle.

**TODO**:
- Exit pressure should be a function of chamber pressure and area ratio.
- Q_dot heat model not yet coupled to cooling channels.

---

## Dependencies

| Dependency | Purpose | Interface |
|---|---|---|
| **CoolProp** (Python) | Real-gas fluid properties for CH4 and O2 | `py.CoolProp.CoolProp.PropsSI(...)` |
| **RocketCEA** (Python) | Chemical equilibrium combustion properties | `py.rocketcea.cea_obj.CEA_Obj(...)` |
| **MATLAB** | Simulation host environment | — |

Both Python packages must be installed in the Python interpreter that MATLAB is configured to use (`pyenv`).

---

## Key Design Parameters

| Parameter | Value | Unit |
|---|---|---|
| Required Thrust | 40 000 | N |
| Chamber Pressure | 80 | bar |
| Specific Impulse | 340 | s |
| O/F Ratio | 3.4 | — |
| Pump Efficiency | 0.93 | — |
| Turbine Efficiency | 0.90 | — |
| Combustion Efficiency | 0.97 | — |
| Nozzle Efficiency | 0.96 | — |
| Cooling Heat Load | 5 | MW |
| LCH4 Tank Temperature | 110 | K |
| LOx Tank Temperature | 90 | K |
| Tank Pressure | 2 | bar |

---

## Known Issues & Open TODOs

| # | Location | Issue |
|---|---|---|
| 1 | `cycle_solver.m` | No convergence loop — injector face pressures are not iterated to 80 bar |
| 2 | `sub_Turbine_LOx.m` | Naming implies oxidizer flow but fuel (CH4) passes through both turbines |
| 3 | `sub_Pump_*.m` | Simplified pump model; polytropic exponent not validated |
| 4 | `sub_Cooling_channels.m` | Q_dot hardcoded; should couple to thrust chamber heat flux |
| 5 | `sub_Injector_*.m` | 20% pressure drop unvalidated; porous injector behavior not modeled |
| 6 | `sub_Thrust_Chamber.m` | Exit pressure hardcoded to 1 atm; nozzle area ratio not modeled |
| 7 | `sub_Thrust_Chamber.m` | Q_dot feedback to cooling channels not implemented |

---

## Running the Simulation

1. Ensure MATLAB is configured with a Python environment containing `CoolProp` and `rocketcea`.
2. Run `cycle_solver.m` as the entry point — it calls `engine_inputs()` automatically.
3. Results are printed to the workspace as `key_values` and `properties_flow`.
4. `plot_cycle` is called automatically at the end to render the cascade diagram.

To inspect an intermediate state, access e.g. `properties_flow.pump_fuel` after running the solver.
