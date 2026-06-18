# Sweep_and_Plot — Quick Tutorial

Short reference for `sweep_and_plot` usage, arguments and examples. Keep this open while preparing sweeps.

## Overview

`sweep_and_plot` performs 1D or 2D parameter sweeps of one or two tunable inputs, runs the cycle solver for every grid point, collects requested output variables and user probes, and (optionally) auto-plots the results.

Use it to see how `key_values` and `fluid_properties` produced by the solver change as you vary 1–2 inputs.

## Quick examples

1D sweep (single variable):

```matlab
results = sweep_and_plot( ...
  'varnames', {'ROF'}, ...                     % one variable name
  'ranges', {[3.09,3.23]}, ...                 % [min,max]
  'npoints', [10], ...                         % number of grid points
  'plotvars', struct('P_Pump_LCH4',1), ...     % which solver outputs to plot
  'probes', {'fuel.Cooling_Channels.T'}, ...   % dot-path(s) to nested values
  'autoplot', true, 'verbose', true);
```

2D sweep (two variables):

```matlab
results = sweep_and_plot( ...
  'varnames', {'ROF','delta_p_inj_percent'}, ...
  'ranges', {[3.0,3.3],[0.08,0.12]}, ...
  'npoints', [6,10], ...
  'plotvars', struct('P_Pump_LCH4',1,'W_Turbine_LCH4',1), ...
  'probes', {'fuel.Cooling_Channels.T','oxidizer.Pump_LOx.T'}, ...
  'autoplot', true, 'verbose', true);
```

## Arguments (name-value pairs)

- `varnames` (required): cell array of 1 or 2 strings. Each string must be a top-level field name that the solver accepts in the `inputs` struct (for example, `ROF`, `delta_p_inj_percent`, `Q_dot`, `delta_p_pump_LCH4`). The code sets `inputs.(varname)=value` for each grid point, so the name must exist or be meaningful when assigned.

- `ranges` (required): cell array where each entry is a numeric 1x2 vector `[min,max]` for the corresponding `varnames` entry. Order matches `varnames`.

- `npoints` (optional): vector `[n1]` or `[n1,n2]` giving the number of points per variable. Default is `41` points per variable when omitted.

- `plotvars` (optional): struct whose field names are the output quantities you want to visualize and whose values are `1` to enable. Example: `struct('P_Pump_LCH4',1,'W_Turbine_LCH4',1)`. The code extracts these names from the solver's `key_values` (`kv`) return; if a field is nested under `kv.Thrust_Chamber` it will also be found automatically. If a requested name is not present for a point, the entry is set to `NaN`.

- `probes` (optional): cell array of dot-separated paths (strings) used to extract nested scalar values from either the solver's `properties_flow` output (`pf_out`) or from `key_values` (`kv`). Examples:
  - `fuel.Cooling_Channels.T` — the temperature value stored at `properties_flow.fuel.Cooling_Channels.T` (if returned by the solver),
  - `oxidizer.Pump_LOx.T` — a nested scalar under `properties_flow` or `key_values`.

  The driver tries `pf_out` first, then `kv`. Only numeric scalar probe values are recorded. Probe names are sanitized into valid MATLAB field names (dots and special chars replaced with `_`) and stored in `results.probe_fields`.

- `autoplot` (optional): logical (default `true`). When `true` the function will automatically create simple plots for requested `plotvars` and `probes` (line plots for 1D, surface plots for 2D).

- `verbose` (optional): logical (default `true`). Prints progress messages and reports skipped/invalid grid points.

## Output structure

The function plots the entered variables by itself, but still, it has the following outputs in for debugging.

- `results.varnames` — the `varnames` cell array you passed in.
- `results.grid` — cell array of grid vectors (one per variable).
- `results.kv_grid` — cell(s) containing the full `key_values` (`kv`) struct returned for each valid grid point. Invalid/skipped points are `[]`.
- `results.pf_grid` — cell(s) containing `properties_flow` (`pf_out`) for each run.
- `results.data` — struct with numeric arrays for each enabled `plotvars` (shapes described above).
- `results.probes` — struct with numeric arrays for each sanitized probe field (NaN where probe was missing or invalid).
- `results.probe_fields` — cell array of the sanitized probe field names.

## Notes & tips

- Invalid points: the driver performs quick sanity checks (for example it checks that `1 - delta_p_inj_percent` is finite and not near zero). If a requested input combination makes the solver invalid the cell entry is left empty and numeric outputs are `NaN`.
- Start with small `npoints` (e.g. 11) when exploring a new region — large grids produce many solver runs and take time.
- If a `plotvars` field is missing, inspect `results.kv_grid` for one successful run to find the correct key name.
- To discover probeable fields, run a single `cycle_solver` (or `cycle_solver_custom`) call and inspect the returned `properties_flow` and `key_values` structs.