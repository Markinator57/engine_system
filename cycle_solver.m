function [key_values, properties_flow] = cycle_solver(varargin)
% Backwards-compatible wrapper for the cycle solver.
% Usage:
%   [kv, pf] = cycle_solver()                    % default inputs + plotting
%   [kv, pf] = cycle_solver(inputs, pf0, po0)    % programmatic inputs
%   [kv, pf] = cycle_solver(inputs, pf0, po0, do_plot)

if nargin == 0
    [inputs, pf0, po0] = engine_inputs();
    [key_values, properties_flow] = cycle_solver_custom(inputs, pf0, po0, true);
else
    % Pass through to the custom solver which accepts inputs and flags
    [key_values, properties_flow] = cycle_solver_custom(varargin{:});
end
end
