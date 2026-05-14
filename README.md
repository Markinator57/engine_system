# Expander Cycle Engine Simulation — Codebase Documentation

## Project Overview

This MATLAB codebase simulates a **liquid rocket engine expander cycle** for TUM M.Sc. Aerospace coursework (RP II). The engine burns Liquid Methane (LCH4) and Liquid Oxygen (LOx) targeting 40 kN thrust at a configurable chamber pressure, with a specific impulse of ~340 s.

The architecture is a **cascading subsystem model**: each engine component is its own function that receives a fluid property struct, computes thermodynamic changes, and passes updated properties downstream. Fluid properties are queried from CoolProp (Python) and combustion properties from NASA CEA.

---

## File Structure

```
engine_system/
├── engine_inputs.m          # Central parameter definition
├── cycle_solver.m           # Main orchestrator + Newton-Raphson closure
├── get_cea_properties.m     # NASA CEA interface (combustion chemistry)
├── plot_cycle.m             # Thermodynamic state cascade visualization
├── sub_Pump_LCH4.m          # Fuel pump model
├── sub_Pump_LOx.m           # Oxidizer pump model
├── sub_Cooling_channels.m   # Regenerative cooling jacket
├── sub_Turbine_LCH4.m       # Turbine driving fuel pump (forward isentropic)
├── sub_Turbine_LOx.m        # Turbine driving oxidizer pump (forward isentropic)
├── sub_Injector_CH4.m       # Fuel injector pressure drop
├── sub_Injector_LOx.m       # Oxidizer injector pressure drop
└── sub_Thrust_Chamber.m     # Combustion chamber + nozzle
```

---

## Architecture & Data Flow

```
engine_inputs()
    └── Initializes: inputs struct, properties_fuel (CH4 @ 110 K), properties_oxidizer (LOx @ 90 K)

cycle_solver()  [Newton-Raphson closure on Δp_pump_LCH4 and p_mid]
    ├── [1] Tanks               → initial fluid states
    ├── [2] sub_Pump_LCH4       → key_values.P_Pump_LCH4
    ├── [3] sub_Pump_LOx        → key_values.P_Pump_LOx
    ├── [4] sub_Cooling_channels→ key_values.delta_T_Cooling_Channels
    ├── [5] sub_Turbine_LCH4    → key_values.W_Turbine_LCH4, delta_p_Turbine_LCH4
    ├── [6] sub_Turbine_LOx     → key_values.W_Turbine_LOx,  delta_p_Turbine_LOx
    ├── [7] sub_Injector_CH4    → key_values.TC_Ingoing_fuel
    ├── [8] sub_Injector_LOx    → key_values.TC_Ingoing_oxidizer
    └── [9] sub_Thrust_Chamber  → key_values.Thrust_Chamber {T_CC, v_e, F_thrust}

plot_cycle(key_values, properties_flow)
    └── Renders annotated T–p cascade diagram for both propellant lines
```

The `properties_*` structs carry `{T, p, rho, c_p}` at each stage. CoolProp is called after each component to update these at the new thermodynamic state.

---


## File-by-File Reference

### [engine_inputs.m](engine_inputs.m)

**Signature**: `[inputs, properties_fuel, properties_oxidizer] = engine_inputs()`

Single source of truth for all design parameters. `delta_p_pump_LOx` is **derived** from `p_CC_req` so changing the chamber pressure target automatically updates the LOx pump sizing:

```matlab
inputs.p_turbine_exit  = inputs.p_CC_req / (1 - inputs.delta_p_inj_percent);
inputs.delta_p_pump_LOx = inputs.p_turbine_exit - p_tank_LOx + inputs.delta_p_partial;
```

| Variable | Value | Description |
|---|---|---|
| `F_thrust_req` | 40 000 N | Required thrust |
| `p_CC_req` | (Pa) | Target chamber pressure — primary design knob |
| `ROF` | 3.4 | Oxidizer-to-fuel mass ratio |
| `Q_dot` | (W) | Cooling heat load — controls turbine feasibility |
| `eta_pump_{LCH4,LOx}` | 0.93 | Pump isentropic efficiencies |
| `eta_turbine_{LCH4,LOx}` | 0.90 | Turbine isentropic efficiencies |
| `eta_combustion` | 0.97 | Combustion efficiency |
| `eta_nozzle` | 0.96 | Nozzle efficiency |
| `delta_p_inj_percent` | 0.20 | Injector fractional pressure drop |
| `delta_p_cooling_channels` | 1 × 10⁶ Pa | Pressure loss across cooling jacket |
| `delta_p_pump_LCH4` | (Pa) | Solver initial guess (overwritten at convergence) |
| `delta_p_pump_LOx` | (Pa) | Auto-derived from `p_turbine_exit` |

---

### [cycle_solver.m](cycle_solver.m)

**Signature**: `[key_values, properties_flow] = cycle_solver()`

Drives the cascade and closes the cycle via Newton-Raphson. Contains three local functions:

| Local function | Role |
|---|---|
| `newton2d(F, x0, lb, ftol, xtol, max_iter)` | Newton-Raphson with backtracking line search |
| `system_residual(x, inputs, pf0, po0)` | Evaluates $\mathbf{F}(\mathbf{x})$ by calling `run_cycle` |
| `run_cycle(inputs, pf0, po0)` | Executes the full thermodynamic cascade, returns W and P values |

After solver exit, a feasibility check is applied: $\|\mathbf{F}\| > 1\ \text{kW}$ raises an error with a diagnostic message.

---

### [sub_Pump_LCH4.m](sub_Pump_LCH4.m) & [sub_Pump_LOx.m](sub_Pump_LOx.m)

**Signature**: `[properties, P_pump] = sub_Pump_LCH4(inputs, properties)`

$$p_{out} = p_{in} + \Delta p_{pump} - \Delta p_{partial}$$

$$\dot{W}_{pump} = \frac{\dot{m}\,\Delta p_{pump}}{\eta_{pump}\,\rho_{in}}$$

$$T_{out} = T_{in} + \frac{\dot{W}_{pump}\,(1 - \eta_{pump})}{\dot{m}\,c_p}$$

**TODO**: Polytropic model; density variation during compression.

---

### [sub_Cooling_channels.m](sub_Cooling_channels.m)

**Signature**: `[properties, delta_T] = sub_Cooling_channels(inputs, properties)`

The cooling jacket heats the fuel at fixed mass flow (isobaric enthalpy addition):

$$h_{out} = h_{in} + \frac{\dot{Q}}{\dot{m}_{fuel}}, \qquad T_{out} = T\!\left(p_{in},\,h_{out}\right)_{\!CoolProp}$$

$$p_{out} = p_{in} - \Delta p_{cooling} - \Delta p_{partial}$$

This step determines $T_{in}$ for the turbines and is therefore the **primary driver of turbine feasibility**. More $\dot{Q}$ → higher $T_{in}$ → larger isentropic enthalpy drop → more shaft work available.

**TODO**: $\dot{Q}$ should be coupled to a thrust chamber heat flux model.

---

### [sub_Turbine_LCH4.m](sub_Turbine_LCH4.m) & [sub_Turbine_LOx.m](sub_Turbine_LOx.m)

**Signature**: `[properties, key_values] = sub_Turbine_LCH4(inputs, properties)`

Implements the **forward isentropic enthalpy method** described above. Both turbines process **methane** (the fuel stream drives both shafts in this topology):

$$h_{in} = h(T_{in},\,p_{in}), \quad s_{in} = s(T_{in},\,p_{in})$$

$$h_{out,s} = h(p_{out},\,s_{in}), \quad h_{out} = h_{in} - \eta_t\,(h_{in} - h_{out,s})$$

$$\dot{W}_{available} = \dot{m}_{fuel}\,(h_{in} - h_{out})$$

Exit state is recovered: $T_{out} = T(p_{out},\,h_{out})$, then CoolProp updates $\rho$ and $c_p$.

A diagnostic warning fires at each call:
- If $\dot{W}_{available} < \dot{W}_{pump,needed}/\eta_t$: shaft deficit — cycle cannot close
- If $\dot{W}_{available} \geq \dot{W}_{pump,needed}/\eta_t$: surplus energy logged

**Note on `sub_Turbine_LOx`**: the name refers to which pump this turbine drives, not the working fluid. The fluid is still methane.

---

### [sub_Injector_CH4.m](sub_Injector_CH4.m) & [sub_Injector_LOx.m](sub_Injector_LOx.m)

**Signature**: `[properties, key_values] = sub_Injector_CH4(inputs, properties)`

$$p_{out} = p_{in}\,(1 - \delta_{inj}), \qquad T_{out} = T_{in}\ \text{(isothermal)}$$

Both streams must enter the injector at $p_{turbine,exit} = p_{CC}/(1-\delta_{inj})$, so after the drop they both land at exactly $p_{CC}$.

**TODO**: Pressure drop fraction of 0.20 unvalidated; porous injector effects not modeled.

---

### [sub_Thrust_Chamber.m](sub_Thrust_Chamber.m)

**Signature**: `[key_values] = sub_Thrust_Chamber(inputs, properties_oxidizer, properties_fuel)`

$$p_{CC} = \frac{p_{fuel,in} + p_{oxi,in}}{2}, \qquad [T_{CC},\,M,\,k] = \text{CEA}(p_{CC},\,\text{ROF})$$

$$v_e = \sqrt{\eta_{nozzle} \cdot \frac{2k}{k-1} \cdot \frac{R}{M} \cdot T_{CC} \cdot \left[1 - \left(\frac{p_{atm}}{p_{CC}}\right)^{\!\frac{k-1}{k}}\right]}$$

$$F = \dot{m}_{tot}\,v_e$$

Exit pressure fixed at $p_{atm} = 101\,325\ \text{Pa}$ (perfectly expanded nozzle at sea level).

---

### [get_cea_properties.m](get_cea_properties.m)

**Signature**: `[T_CC, M, k] = get_cea_properties(p_CC, ROF)`

CoolProp is called via `py.CoolProp.CoolProp.PropsSI(...)`. The CEA object is `persistent` — initialized once and reused across calls to avoid repeated Python object construction overhead.

---

## Dependencies

| Dependency | Purpose | Interface |
|---|---|---|
| **CoolProp** (Python) | Real-gas properties for CH4 and O2 | `py.CoolProp.CoolProp.PropsSI(...)` |
| **RocketCEA** (Python) | Chemical equilibrium combustion | `py.rocketcea.cea_obj.CEA_Obj(...)` |
| **MATLAB** | Simulation host | — |

Both Python packages must be installed in the Python interpreter MATLAB is configured to use (`pyenv`).

---

## Running the Simulation

1. Ensure MATLAB is configured with a Python environment containing `CoolProp` and `rocketcea`.
2. Call `cycle_solver()` from the MATLAB command window or a script. It calls `engine_inputs()` automatically.
3. Results are returned as `key_values` (scalar metrics) and `properties_flow` (fluid state history per component).
4. `plot_cycle` is called automatically at the end.

**Primary design knobs** (in `engine_inputs.m`):

| Knob | Effect |
|---|---|
| `p_CC_req` | Scales all pump pressure requirements; primary sizing lever |
| `Q_dot` | Controls turbine inlet temperature; governs feasibility |
| `delta_p_inj_percent` | Changes turbine exit pressure; trades atomization quality for expansion range |
| `ROF` | Shifts mass flow split between fuel and oxidizer |

---

## Thermodynamic Model: Pump & Turbine Power

### Pump Power — Linear in $\Delta p$

A liquid pump moves an incompressible fluid against a pressure difference. Because liquid density $\rho$ is nearly constant across the pressure rise, the shaft power scales **linearly** with the imposed pressure differential:

$$\boxed{\dot{W}_{pump} = \frac{\dot{m} \cdot \Delta p_{pump}}{\eta_{pump} \cdot \rho}}$$

- $\dot{m}$ — propellant mass flow rate [kg/s]  
- $\Delta p_{pump}$ — pressure rise across the pump [Pa]  
- $\eta_{pump}$ — isentropic (hydraulic) efficiency [-]  
- $\rho$ — inlet density [kg/m³]

**Why linear?** Unlike a gas compressor, the liquid does negligible $p\,\mathrm{d}V$ work during compression. The specific work is simply $\Delta p / \rho$ (Bernoulli, incompressible limit), scaled by the efficiency. Doubling $\Delta p$ exactly doubles the required shaft power for fixed flow conditions.

The irreversibility heats the fluid slightly:

$$T_{out} = T_{in} + \frac{\dot{W}_{pump}\,(1 - \eta_{pump})}{\dot{m}\,c_p}$$

---

### Turbine Power — Non-linear in $T_{in}$ and $p_{in}$

A turbine expands a high-pressure fluid to a lower exit pressure, converting enthalpy into shaft work. Unlike the pump, this process is **strongly non-linear** in both inlet temperature and pressure, especially for methane near its critical point ($T_c = 190.6\ \text{K}$, $p_c = 46.1\ \text{bar}$).

#### Forward Isentropic Enthalpy Method

The implemented model works entirely in enthalpy-entropy space via CoolProp — **no ideal-gas assumptions**:

**Step 1 — Inlet state:**

$$h_{in} = h(T_{in},\, p_{in}), \qquad s_{in} = s(T_{in},\, p_{in})$$

**Step 2 — Isentropic exit enthalpy** (constant-entropy expansion to $p_{out}$):

$$h_{out,s} = h(p_{out},\, s_{in})$$

This is the enthalpy the fluid would reach after a perfectly reversible (isentropic) expansion. It encodes the full real-gas thermodynamics through the equation of state.

**Step 3 — Actual exit enthalpy** (accounting for irreversibilities via $\eta_{turbine}$):

$$h_{out} = h_{in} - \eta_{turbine}\,(h_{in} - h_{out,s})$$

The term $(h_{in} - h_{out,s})$ is the **isentropic enthalpy drop** — the maximum work extractable per unit mass for this pressure ratio. The efficiency $\eta_{turbine}$ captures all irreversibilities (friction, tip clearance, heat loss).

**Step 4 — Available shaft power:**

$$\boxed{\dot{W}_{turbine} = \dot{m}_{fuel}\,(h_{in} - h_{out})}$$

#### Why Non-linear?

For an ideal gas, the isentropic enthalpy drop reduces to:

$$h_{in} - h_{out,s} = c_p\,T_{in}\left[1 - \left(\frac{p_{out}}{p_{in}}\right)^{\!\frac{\gamma-1}{\gamma}}\right]$$

which is already non-linear in both $T_{in}$ (linear factor) and the pressure ratio (power-law). For **real supercritical methane**, the real-gas equation of state makes this relationship even more complex — $c_p$ itself varies strongly with $T$ and $p$ (diverges near the pseudocritical line), and the isentropic exponent is not constant.

As a result, **doubling the inlet temperature does not double the turbine output**, and small changes in inlet conditions near the critical point can produce disproportionately large changes in available work. This is the physical reason why a reduction in $\dot{Q}$ (cooling heat load) causes the turbines to become unable to power the pumps — not a coding artefact.

---

## Cycle Closure: Two-Shaft Power Balance

### Topology

Both turbines expand the **same working fluid** (methane from the fuel line) in series:

```
Fuel Tank → Pump (LCH4) → Cooling Channels → Turbine 1 (LCH4 shaft)
                                                    ↓ p_mid
                                              Turbine 2 (LOx shaft)
                                                    ↓ p_turbine_exit
                                              Injector → Chamber

Oxidizer Tank → Pump (LOx) → ─────────────────────────→ Injector → Chamber
```

Turbine 1 drives the **fuel pump** (LCH4 shaft).  
Turbine 2 drives the **oxidizer pump** (LOx shaft).

### Shaft Balance Equations

Each shaft must independently satisfy its own power balance:

$$\dot{W}_{turbine,LCH4}(\Delta p_{pump,LCH4},\; p_{mid}) = \frac{\dot{W}_{pump,LCH4}(\Delta p_{pump,LCH4})}{\eta_{turbine}}$$

$$\dot{W}_{turbine,LOx}(\Delta p_{pump,LCH4},\; p_{mid}) = \frac{\dot{W}_{pump,LOx}}{\eta_{turbine}}$$

This is a **2 × 2 nonlinear system** in the two free parameters:

| Free variable | Physical meaning |
|---|---|
| $x_1 = \Delta p_{pump,LCH4}$ | Fuel pump pressure rise — sets pump power demand AND turbine inlet pressure |
| $x_2 = p_{mid}$ | Inter-turbine pressure — splits available expansion between the two shafts |

The LOx pump pressure rise $\Delta p_{pump,LOx}$ is **not** a free variable; it is derived from the chamber pressure requirement:

$$p_{turbine,exit} = \frac{p_{CC}}{1 - \delta_{inj}}, \qquad \Delta p_{pump,LOx} = p_{turbine,exit} - p_{tank} + \Delta p_{partial}$$

where $\delta_{inj}$ is the injector fractional pressure drop. This ensures the oxidizer always arrives at the injector face at exactly $p_{turbine,exit}$, so after the injector drop it lands at $p_{CC}$.

### Residual Vector

Define the residual:

$$\mathbf{F}(\mathbf{x}) = \begin{pmatrix} \dot{W}_{T,LCH4}(x_1,\,x_2) - \dot{W}_{P,LCH4}(x_1)/\eta_t \\ \dot{W}_{T,LOx}(x_1,\,x_2) - \dot{W}_{P,LOx}/\eta_t \end{pmatrix}$$

The cycle is closed when $\mathbf{F}(\mathbf{x}) = \mathbf{0}$.

### Newton-Raphson Solver

`cycle_solver.m` finds the root using Newton-Raphson with a finite-difference Jacobian and backtracking line search (no Optimization Toolbox required):

$$\mathbf{x}^{(k+1)} = \mathbf{x}^{(k)} - \alpha\,\mathbf{J}^{-1}\mathbf{F}(\mathbf{x}^{(k)})$$

where $\alpha \in (0,1]$ is the line-search step length chosen to ensure $\|\mathbf{F}(\mathbf{x}^{(k+1)})\| < \|\mathbf{F}(\mathbf{x}^{(k)})\|$, and the Jacobian is approximated column-by-column:

$$J_{ij} \approx \frac{F_i(\mathbf{x} + h\,\mathbf{e}_j) - F_i(\mathbf{x})}{h}, \qquad h = \max(10^{-4}\,|x_j|,\;10^4\ \text{Pa})$$

Convergence criterion: $\|\mathbf{F}\| < 1\ \text{W}$. If the solver exits with $\|\mathbf{F}\| > 1\ \text{kW}$, the cycle is declared **infeasible** — the turbines cannot produce enough shaft work to close both shaft balances at the given operating point.

### Feasibility Boundary

The cycle becomes infeasible when the total heat load $\dot{Q}$ is too low relative to $p_{CC}$. This is because:

1. Less $\dot{Q}$ → lower $T_{in}$ at turbine inlet → smaller isentropic enthalpy drop $(h_{in} - h_{out,s})$
2. Less available turbine work → can't sustain the pump power demands
3. Higher $p_{CC}$ → higher $\Delta p_{pump,LOx}$ → more LOx pump power needed

The pump power scales as $\dot{W}_{pump} \propto \dot{m}\,\Delta p \propto \dot{m}\,p_{CC}$, while turbine output scales with inlet enthalpy — a function of $\dot{Q}$. These two must remain balanced for a feasible cycle.

---

## Known Issues & Open TODOs

| # | Location | Issue |
|---|---|---|
| 1 | `sub_Pump_*.m` | Simplified incompressible model; polytropic exponent not validated |
| 2 | `sub_Cooling_channels.m` | $\dot{Q}$ is a fixed input; should couple to thrust chamber heat flux |
| 3 | `sub_Injector_*.m` | 20 % pressure drop is a rule of thumb; porous injector physics not modeled |
| 4 | `sub_Thrust_Chamber.m` | Exit pressure hardcoded to 1 atm; nozzle area ratio not modeled |
| 5 | `sub_Thrust_Chamber.m` | $\dot{Q}$ feedback to cooling channels not implemented |
| 6 | `engine_inputs.m` | $\Delta p_{pump,LCH4}$ initial guess may need tuning when $p_{CC}$ is changed significantly |
| 7 | `cycle_solver.m` | Newton-Raphson may converge slowly if initial guess is far from solution |
