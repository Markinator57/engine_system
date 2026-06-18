function results = sweep_and_plot(varargin)
% sweep_and_plot  Sweep 1 or 2 tunable inputs and plot cycle responses
%
% Usage:
%   results = sweep_and_plot('varnames', {'delta_p_pump_LCH4'}, 'ranges', {[4e6,8e6]}, 'npoints', [41], 'plotvars', struct('P_Pump_LCH4',1,'W_Turbine_LCH4',1))
%   results = sweep_and_plot('varnames', {'delta_p_pump_LCH4','Q_dot'}, 'ranges', {[4e6,8e6],[1e6,1e7]}, 'npoints', [31,21])
%
% Options (name-value pairs):
%   'varnames' - cellstr of 1 or 2 field names in `inputs` to sweep
%   'ranges'   - cell array of 1x2 numeric vectors [min,max] for each var
%   'npoints'  - numeric vector of number of points for each var
%   'logscale' - logical vector indicating log spacing for each var (default false)
%   'plotvars' - struct with fields to visualize. Set field to 1 to enable.
%                Typical keys are fields from `key_values` produced by cycle_solver.
%   'probes'   - cell array of dot-paths into `properties_flow` or `key_values`
%                (e.g. {'fuel.Cooling_Channels.T', 'fuel.Pump_LCH4.T'}).
%   'verbose'  - logical (default true)
%
% Returns:
%   results - struct with fields: varnames, grid, key_values_grid (cell or struct),
%             numeric arrays of enabled plotvars, and raw solver outputs.

% Parse inputs
p = inputParser;
addParameter(p,'varnames',{},@(x) iscellstr(x) || isstring(x));
addParameter(p,'ranges',{},@iscell);
addParameter(p,'npoints',[],@isnumeric);
addParameter(p,'logscale',[],@isnumeric);
addParameter(p,'plotvars',struct(),@isstruct);
addParameter(p,'probes',{},@(x) iscell(x) || isstring(x) || ischar(x));
addParameter(p,'verbose',true,@islogical);
addParameter(p,'autoplot',true,@islogical);
parse(p,varargin{:});
opts = p.Results;

% Normalize probes option to cellstr
if ischar(opts.probes)
    opts.probes = {opts.probes};
elseif isstring(opts.probes)
    opts.probes = cellstr(opts.probes);
end
if isempty(opts.probes)
    opts.probes = {};
end

if isempty(opts.varnames)
    error('Specify at least one variable name to sweep via ''varnames''');
end

nvars = numel(opts.varnames);
if ~(nvars==1 || nvars==2)
    error('Only 1D or 2D sweeps supported (1 or 2 varnames).');
end

% Normalize options
if isempty(opts.ranges) || numel(opts.ranges)~=nvars
    error('''ranges'' must be a cell array with one [min,max] per var.');
end
if isempty(opts.npoints)
    opts.npoints = 41 * ones(1,nvars);
end
if numel(opts.npoints)==1
    opts.npoints = repmat(opts.npoints,1,nvars);
end
if isempty(opts.logscale)
    opts.logscale = false(1,nvars);
end
if numel(opts.logscale)==1
    opts.logscale = repmat(opts.logscale,1,nvars);
end

% Load default inputs to ensure all fields exist
[inputs0, pf0, po0] = engine_inputs();

% Build grids
grids = cell(1,nvars);
for i=1:nvars
    r = opts.ranges{i};
    if opts.logscale(i)
        grids{i} = logspace(log10(r(1)), log10(r(2)), opts.npoints(i));
    else
        grids{i} = linspace(r(1), r(2), opts.npoints(i));
    end
end

results.varnames = opts.varnames;
results.grid = grids;
results.plotvars = opts.plotvars;
results.autoplot = opts.autoplot;
results.probes_list = opts.probes;

% Prepare storage
if nvars==1
    nx = numel(grids{1});
    kvs = cell(nx,1);
    pf_grid = cell(nx,1);
else
    nx = numel(grids{1}); ny = numel(grids{2});
    kvs = cell(nx,ny);
    pf_grid = cell(nx,ny);
end

% Prepare probes storage
probe_list = opts.probes;
nprobes = numel(probe_list);
probe_fields = cell(1,nprobes);
probes_data = struct();
if nprobes > 0
    for pi = 1:nprobes
        orig = probe_list{pi};
        try
            fname = matlab.lang.makeValidName(regexprep(orig, '[^A-Za-z0-9]', '_'));
        catch
            fname = regexprep(orig, '[^A-Za-z0-9]', '_');
        end
        probe_fields{pi} = fname;
        if nvars==1
            probes_data.(fname) = nan(nx,1);
        else
            probes_data.(fname) = nan(nx,ny);
        end
    end
end

% Determine which plot variables requested and prepare numeric arrays
plotfields = fieldnames(opts.plotvars);
active_plotfields = plotfields(structfun(@(x) x==1, opts.plotvars));
num_active = numel(active_plotfields);

if nvars==1
    data = struct();
    for k=1:num_active
        data.(active_plotfields{k}) = nan(nx,1);
    end
else
    data = struct();
    for k=1:num_active
        data.(active_plotfields{k}) = nan(nx,ny);
    end
end

% Sweep loops
if opts.verbose
    fprintf('Starting %d-D sweep: %s\n', nvars, strjoin(opts.varnames, ', '));
end

if nvars==1
    for i=1:nx
        inputs = inputs0;
        inputs.(opts.varnames{1}) = grids{1}(i);
            % Sanity check: derived turbine exit pressure must be finite
            invalid_point = false;
            if isfield(inputs, 'p_CC_req') && isfield(inputs, 'delta_p_inj_percent')
                denom = 1 - inputs.delta_p_inj_percent;
                if ~isfinite(denom) || abs(denom) < eps
                    invalid_point = true;
                else
                    p_turbine_exit = inputs.p_CC_req / denom;
                    if ~isfinite(p_turbine_exit) || p_turbine_exit <= 0 || p_turbine_exit > 1e12
                        invalid_point = true;
                    end
                end
            end
            if invalid_point
                if opts.verbose
                    fprintf('Skipping invalid point i=%d: delta_p_inj_percent=%.6g\n', i, inputs.delta_p_inj_percent);
                end
                kvs{i} = [];
                pf_grid{i} = [];
                for k=1:num_active
                    data.(active_plotfields{k})(i) = NaN;
                end
                continue;
            end
            try
                [kv, pf_out] = cycle_solver_custom(inputs, pf0, po0, false);
                kvs{i} = kv;
                pf_grid{i} = pf_out;
                % Extract requested probes (try properties_flow first, then key_values)
                if nprobes > 0
                    for pi = 1:nprobes
                        tok = strsplit(probe_list{pi}, '.');
                        val_found = false;
                        % try properties_flow (pf_out)
                        if true
                            v = pf_out;
                            for tt = 1:numel(tok)
                                tk = tok{tt};
                                if isstruct(v) && isfield(v, tk)
                                    v = v.(tk);
                                else
                                    v = [];
                                    break;
                                end
                            end
                            if ~isempty(v) && isnumeric(v) && isscalar(v)
                                probes_data.(probe_fields{pi})(i) = v;
                                val_found = true;
                            end
                        end
                        if ~val_found
                            % try key_values (kv)
                            if true
                                v = kv;
                                for tt = 1:numel(tok)
                                    tk = tok{tt};
                                    if isstruct(v) && isfield(v, tk)
                                        v = v.(tk);
                                    else
                                        v = [];
                                        break;
                                    end
                                end
                                if ~isempty(v) && isnumeric(v) && isscalar(v)
                                    probes_data.(probe_fields{pi})(i) = v;
                                    val_found = true;
                                end
                            end
                        end
                    end
                end
            for k=1:num_active
                f = active_plotfields{k};
                if isfield(kv, f)
                    data.(f)(i) = kv.(f);
                else
                    % try nested in key_values.Thrust_Chamber or others
                    if isstruct(kv) && isfield(kv, 'Thrust_Chamber') && isfield(kv.Thrust_Chamber, f)
                        data.(f)(i) = kv.Thrust_Chamber.(f);
                    else
                        data.(f)(i) = NaN;
                    end
                end
            end
        catch ME
            warning('Iteration %d failed: %s', i, ME.message);
            for k=1:num_active
                data.(active_plotfields{k})(i) = NaN;
            end
        end
    end

    % Plot 2D graphs (optional)
    if opts.autoplot
        figure;
        for k=1:num_active
            subplot(num_active,1,k)
            plot(grids{1}, data.(active_plotfields{k}), '-o');
            xlabel(opts.varnames{1});
            ylabel(active_plotfields{k});
            grid on;
        end
    end
    % Plot 1D probes (optional)
    if opts.autoplot && nprobes>0
        figure;
        for pi=1:nprobes
            subplot(nprobes,1,pi)
            plot(grids{1}, probes_data.(probe_fields{pi}), '-o');
            xlabel(opts.varnames{1});
            ylabel(results.probes_list{pi});
            grid on;
        end
    end
else
    for i=1:nx
        for j=1:ny
            inputs = inputs0;
            inputs.(opts.varnames{1}) = grids{1}(i);
            inputs.(opts.varnames{2}) = grids{2}(j);
            % Sanity check: derived turbine exit pressure must be finite
            invalid_point = false;
            if isfield(inputs, 'p_CC_req') && isfield(inputs, 'delta_p_inj_percent')
                denom = 1 - inputs.delta_p_inj_percent;
                if ~isfinite(denom) || abs(denom) < eps
                    invalid_point = true;
                else
                    p_turbine_exit = inputs.p_CC_req / denom;
                    if ~isfinite(p_turbine_exit) || p_turbine_exit <= 0 || p_turbine_exit > 1e12
                        invalid_point = true;
                    end
                end
            end
            if invalid_point
                if opts.verbose
                    fprintf('Skipping invalid point i=%d j=%d: delta_p_inj_percent=%.6g\n', i, j, inputs.delta_p_inj_percent);
                end
                kvs{i,j} = [];
                pf_grid{i,j} = [];
                for k=1:num_active
                    data.(active_plotfields{k})(i,j) = NaN;
                end
                continue;
            end
            try
                [kv, pf_out] = cycle_solver_custom(inputs, pf0, po0, false);
                kvs{i,j} = kv;
                pf_grid{i,j} = pf_out;
                    % Extract requested probes (try properties_flow first, then key_values)
                    if nprobes > 0
                        for pi = 1:nprobes
                            tok = strsplit(probe_list{pi}, '.');
                            val_found = false;
                                % try properties_flow (pf_out)
                                    if true
                                v = pf_out;
                                for tt = 1:numel(tok)
                                    tk = tok{tt};
                                    if isstruct(v) && isfield(v, tk)
                                        v = v.(tk);
                                    else
                                        v = [];
                                        break;
                                    end
                                end
                                if ~isempty(v) && isnumeric(v) && isscalar(v)
                                    probes_data.(probe_fields{pi})(i,j) = v;
                                    val_found = true;
                                end
                            end
                            if ~val_found
                                % try key_values (kv)
                                if true
                                    v = kv;
                                    for tt = 1:numel(tok)
                                        tk = tok{tt};
                                        if isstruct(v) && isfield(v, tk)
                                            v = v.(tk);
                                        else
                                            v = [];
                                            break;
                                        end
                                    end
                                    if ~isempty(v) && isnumeric(v) && isscalar(v)
                                        probes_data.(probe_fields{pi})(i,j) = v;
                                        val_found = true;
                                    end
                                end
                            end
                        end
                    end
                for k=1:num_active
                    f = active_plotfields{k};
                    if isfield(kv, f)
                        data.(f)(i,j) = kv.(f);
                    else
                        if isstruct(kv) && isfield(kv, 'Thrust_Chamber') && isfield(kv.Thrust_Chamber, f)
                            data.(f)(i,j) = kv.Thrust_Chamber.(f);
                        else
                            data.(f)(i,j) = NaN;
                        end
                    end
                end
            catch ME
                warning('Iteration (%d,%d) failed: %s', i, j, ME.message);
                for k=1:num_active
                    data.(active_plotfields{k})(i,j) = NaN;
                end
            end
        end
    end

    % Plot 3D surfaces (optional)
    [X,Y] = meshgrid(grids{2}, grids{1}); % meshgrid cols=var2, rows=var1
    if opts.autoplot
        for k=1:num_active
            figure;
            Z = data.(active_plotfields{k});
            surf(X, Y, Z, 'EdgeColor','none');
            xlabel(opts.varnames{2});
            ylabel(opts.varnames{1});
            zlabel(active_plotfields{k});
            colorbar;
            view(3);
        end
    end
    % Plot 2D probes (optional)
    if opts.autoplot && nprobes>0
        for pi=1:nprobes
            figure;
            Z = probes_data.(probe_fields{pi});
            surf(X, Y, Z, 'EdgeColor','none');
            xlabel(opts.varnames{2});
            ylabel(opts.varnames{1});
            zlabel(results.probes_list{pi});
            colorbar; view(3);
        end
    end
end

% Pack results
results.kv_grid = kvs;
results.data = data;
results.pf_grid = pf_grid;
if exist('probes_data','var')
    results.probes = probes_data;
    results.probe_fields = probe_fields;
else
    results.probes = struct();
    results.probe_fields = {};
end

if opts.verbose
    fprintf('Sweep completed.');
end
end
