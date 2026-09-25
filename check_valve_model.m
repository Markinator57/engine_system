function check_valve_model

p = parameters();

% each row: name, valve sequence, simulated time [s], initial state
cases = {
    'Start-up, 300 ms fuel lead'        , @(t) seq_start(t,p)              , 3.0 , 'cold'
    'Shutdown, MFV first (RL10 order)'  , @(t) seq_close(t,p,p.tc,'MFV')   , 0.5 , 'hot'
    'Shutdown, both together'           , @(t) seq_close(t,p,p.tc,'both')  , 0.5 , 'hot'
    'Shutdown, MOV first'               , @(t) seq_close(t,p,p.tc,'MOV')   , 0.5 , 'hot'
    'Emergency, both in 20 ms'          , @(t) seq_close(t,p,0.020,'both') , 0.4 , 'hot'
    'Chamber pushed to 90 bar, 10 ms'   , @(t) seq_spike(t,p,90e5)         , 0.2 , 'hot'
    'Chamber pushed to 95 bar, 10 ms'   , @(t) seq_spike(t,p,95e5)         , 0.2 , 'hot'
    'Chamber pushed to 100 bar, 10 ms'  , @(t) seq_spike(t,p,100e5)        , 0.2 , 'hot'
    };

fprintf('\n%-35s %8s %8s %8s %9s %9s\n', '', 'pc max', 'dp_ox', 'dp_f', 'rev LOx', 'rev gas');
fprintf('%-35s %8s %8s %8s %9s %9s\n', 'case', '[bar]', '[bar]', '[bar]', '[g]', '[g]');
for k = 1:size(cases,1)
    r = simulate(cases{k,2}, p, cases{k,3}, cases{k,4});
    fprintf('%-35s %8.1f %8.2f %8.2f %9.1f %9.2f\n', cases{k,1}, max(r.pc)/1e5, ...
            min(r.dp_ox)/1e5, min(r.dp_f)/1e5, r.rev_ox*1e3, r.rev_f*1e3);
end

% -------- figure 1: start-up ---------------------------------------------
r = simulate(@(t) seq_start(t,p), p, 3.0, 'cold');
plot_run(r, p, 1, 'Start-up: MFV opens at 0 s, MOV + ignition at 0.3 s, pumps bootstrap over 2 s')

% -------- figure 2: nominal shutdown -------------------------------------
r = simulate(@(t) seq_close(t,p,p.tc,'MFV'), p, 0.45, 'hot');
plot_run(r, p, 1e3, 'Shutdown: MFV closes first, MOV 100 ms later')

% -------- figure 3: how high must p_c go before backflow starts? ---------
target = (80:2:100)*1e5;
pcmax = zeros(size(target));  dpo = pcmax;  dpf = pcmax;
for k = 1:numel(target)
    r = simulate(@(t) seq_spike(t,p,target(k)), p, 0.18, 'hot');
    pcmax(k) = max(r.pc)/1e5;
    dpo(k)   = min(r.dp_ox)/1e5;
    dpf(k)   = min(r.dp_f)/1e5;
end
p0_ox = interp1(-dpo, pcmax, 0);                % where the LOx curve crosses zero
p0_f  = interp1(-dpf, pcmax, 0);                % where the CH4 curve crosses zero

figure('Color','w','Name','Backflow threshold'); hold on; grid on
plot(pcmax, dpo, '-o', 'Color', p.cOx, 'LineWidth', 2)
plot(pcmax, dpf, '-o', 'Color', p.cF,  'LineWidth', 2)
plot([80 100], [0 0], 'r--')
plot([p0_f p0_ox], [0 0], 'ko', 'MarkerFaceColor', 'k')
text(p0_ox + 0.5, 2, sprintf('LOx: %.0f bar', p0_ox))
text(p0_f - 4, -2, sprintf('CH_4: %.0f bar', p0_f))
xlim([80 100])
xlabel('Chamber pressure reached during a 10 ms excursion [bar]')
ylabel('worst \Deltap_{inj} [bar]')
legend('LOx side', 'CH_4 side', 'Location', 'northeast')
title('Backflow threshold')
end


%% ===================== parameters ====
function p = parameters()
% --- chamber, from the CAD ---------------------------------------------
p.Vc    = 3.680e-3;                 % m^3   injector face -> throat
p.At    = pi/4*62.63e-3^2;          % m^2   throat, D = 62.63 mm
p.pc0   = 80e5;                     % Pa    nominal chamber pressure (E-R04)
p.pamb  = 1e5;                      % Pa    ambient
p.mdot  = 13.154;                   % kg/s  total (final converged point)
p.OF    = 3.09;
p.mox   = p.mdot*p.OF/(1+p.OF);     % kg/s  9.94
p.mf    = p.mdot/(1+p.OF);          % kg/s  3.22
p.cstar = p.pc0*p.At/p.mdot;        % m/s   1874, consistent with the geometry

gc      = 1.15;                     % combustion gas
Gam     = sqrt(gc)*(2/(gc+1))^((gc+1)/(2*(gc-1)));
p.gam_c = gc;
p.RTc   = (p.cstar*Gam)^2;          % J/kg  R*T of the hot combustion gas
p.Rc    = 8314/22;                  % J/kg K
p.Tc    = p.RTc/p.Rc;               % K     ~3600
p.RT_ox = 259.8*120;                % J/kg  unburnt oxygen, cold

% --- pressures (converged cycle, report Fig. 1 / Table VI) --------------
p.dp_inj_ox = 12e5;                 % Pa    LOx injector drop (Table VI)
p.dp_inj_f  = 8e5;                  % Pa    CH4 injector drop (Table VI)
p.p_man_ox  = p.pc0 + p.dp_inj_ox;  % Pa    LOx dome   = 92 bar
p.p_man_f   = p.pc0 + p.dp_inj_f;   % Pa    CH4 plenum = 88 bar
p.dp_valve  = 0.1e5;                % Pa    drop across each open main valve:
                                    %       ball valves, ~0.1 bar in the report's
                                    %       pressure cascade (Fig. 4)
p.p_sup_ox  = p.p_man_ox + p.dp_valve;   % Pa  upstream of the MOV = 92.1 bar
p.p_sup_f   = p.p_man_f  + p.dp_valve;   % Pa  upstream of the MFV = 88.1 bar
p.p_tank    = 2e5;                  % Pa    run tanks, E-R05 / E-R06

% --- LOx side -----------------------------------------------------------
p.rho   = 1141;                     % kg/m^3
p.Vdome = 0.835e-3;                 % m^3   from the CAD
p.beta  = 0.94e9;                   % Pa    bulk modulus, fluid + dome wall
p.A_inj_ox = p.mox/sqrt(2*p.rho*p.dp_inj_ox);  % effective CdA, sized for nominal
p.A_mov    = p.mox/sqrt(2*p.rho*p.dp_valve);   % MOV, dp_valve when fully open

% --- CH4 side (gas after the turbines) ----------------------------------
p.Rf    = 518.28;                   % J/kg K
p.gam_f = 1.22;
p.Tf    = 550;                      % K   isothermal plenum (LOx turbine exit)
p.Vplen = 0.667e-3;                 % m^3 from the CAD
r       = p.pc0/p.p_man_f;
psi     = sqrt(2*p.gam_f/((p.gam_f-1)*p.Rf*p.Tf) ...
               *(r^(2/p.gam_f) - r^((p.gam_f+1)/p.gam_f)));
p.A_inj_f = p.mf/(p.p_man_f*psi);            % sized for nominal
r2      = p.p_man_f/p.p_sup_f;               % MFV, same formula, sized for
psi2    = sqrt(2*p.gam_f/((p.gam_f-1)*p.Rf*p.Tf) ...
               *(r2^(2/p.gam_f) - r2^((p.gam_f+1)/p.gam_f)));
p.A_mfv = p.mf/(p.p_sup_f*psi2);             % dp_valve when fully open

% --- sequencing (RL10A-3-3A, NASA TM 107318) -----------------------------
p.t0     = 0.05;                    % s   event starts here
p.t_lead = 0.30;                    % s   fuel lead: ignition ~0.3 s after start
p.t_open = 0.20;                    % s   valve opening stroke   (assumption)
p.tc     = 0.150;                   % s   valve closing stroke   (assumption)
p.gap    = 0.100;                   % s   delay to the second valve at shutdown
p.t_boot = 2.0;                     % s   pumps reach full speed ~2 s after ignition

% --- colours ------------------------
p.cOx = [0      0.4470 0.7410];
p.cF  = [0.8500 0.3250 0.0980];
p.cPc = [0 0 0];
end


%% ================== integration ===
function r = simulate(seq, p, tmax, initial)
if strcmp(initial, 'cold')          % everything at ambient, valves shut
    y0 = [p.pamb; p.pamb; p.pamb*p.Vplen/(p.Rf*p.Tf)];
else                                % nominal steady state
    y0 = [p.pc0; p.p_man_ox; p.p_man_f*p.Vplen/(p.Rf*p.Tf)];
end
opt = odeset('RelTol',1e-7, 'AbsTol',[1e2 1e2 1e-9], 'MaxStep',2e-4);
sol = ode15s(@(t,y) rhs(t,y,seq,p), [0 tmax], y0, opt);

r.t   = linspace(0, tmax, 4000);
Y     = deval(sol, r.t);
r.pc  = Y(1,:);  r.p_ox = Y(2,:);
r.p_f = Y(3,:)*p.Rf*p.Tf/p.Vplen;
r.dp_ox = r.p_ox - r.pc;
r.dp_f  = r.p_f  - r.pc;

% recompute the flows along the solution: injector flows and supply
n = numel(r.t);
r.q_ox = zeros(1,n);  r.q_f = r.q_ox;  r.sup_ox = r.q_ox;  r.sup_f = r.q_ox;
for k = 1:n
    f = flows(Y(:,k), seq(r.t(k)), p);
    r.q_ox(k) = f.inj_ox;   r.q_f(k)   = f.inj_f;
    r.sup_ox(k) = f.sup_ox; r.sup_f(k) = f.sup_f;
end
r.rev_ox = -trapz(r.t, min(r.q_ox, 0));      % reverse mass through the injector
r.rev_f  = -trapz(r.t, min(r.q_f,  0));
end


function dy = rhs(t, y, seq, p)
v  = seq(t);
f  = flows(y, v, p);
pc = y(1);

% chamber: what enters minus what leaves through the throat
RT    = chamber_RT(f.inj_ox, f.inj_f, p);
cstar = p.cstar*sqrt(RT/p.RTc);                 % c* of what is burning now
q_out = p.At*pc/cstar ...                       % choked throat, switched off
        * sqrt(max(1 - (p.pamb/max(pc,p.pamb))^2, 0));   % smoothly at ambient
dpc   = RT/p.Vc*(max(f.inj_ox,0) + max(f.inj_f,0) - q_out);
if ~isnan(v.pc)
    dpc = (v.pc - pc)/1e-4;                     % p_c imposed during a spike
end

% LOx dome: liquid compliance, dp/dm = beta/(rho*V)
dp_ox = p.beta/(p.Vdome*p.rho)*(f.mov - f.inj_ox);

% CH4 plenum: mass balance (isothermal gas)
dm_f  = f.mfv - f.inj_f;

dy = [dpc; dp_ox; dm_f];
end


%% ======================== flow models ===
function f = flows(y, v, p)
pc = y(1);  p_ox = y(2);  p_f = y(3)*p.Rf*p.Tf/p.Vplen;

% pressure upstream of the main valves: tank pressure until the pumps spin
% up (v.boot = 0), nominal pump discharge at full speed (v.boot = 1)
f.sup_ox = p.p_tank + v.boot*(p.p_sup_ox - p.p_tank);
f.sup_f  = p.p_tank + v.boot*(p.p_sup_f  - p.p_tank);

f.mov    = qliq(f.sup_ox - p_ox, p.A_mov*v.mov, p.rho);
f.inj_ox = qliq(p_ox - pc,       p.A_inj_ox,    p.rho);

f.mfv = qgas(f.sup_f, p_f, p.Tf, p.A_mfv*v.mfv, p.Rf, p.gam_f);
if p_f >= pc
    f.inj_f =  qgas(p_f, pc, p.Tf, p.A_inj_f, p.Rf, p.gam_f);
else
    % reverse: hot combustion gas pushed into the methane plenum
    f.inj_f = -qgas(pc, p_f, p.Tc, p.A_inj_f, p.Rc, p.gam_c);
end
end


function RT = chamber_RT(q_ox, q_f, p)
% R*T of the gas entering the chamber. Only the flow that finds its partner
% at the nominal O/F burns (R*Tc); any excess enters cold. Needed during the
% fuel lead (methane only, nothing burns) and at shutdown once one valve is
% shut. The residence time in the chamber is ~0.65 ms, so the chamber gas
% follows the incoming mixture almost instantly.
q_ox = max(q_ox,0);  q_f = max(q_f,0);
if q_ox + q_f < 1e-6
    RT = p.RTc;  return
end
burn_f  = min(q_f, q_ox/p.OF);                  % fuel that finds oxygen
cold_f  = q_f  - burn_f;                        % excess methane
cold_ox = q_ox - burn_f*p.OF;                   % excess oxygen
RT = (burn_f*(1+p.OF)*p.RTc + cold_f*p.Rf*p.Tf + cold_ox*p.RT_ox)/(q_ox + q_f);
end


function q = qliq(dp, CdA, rho)
% Incompressible orifice, signed. The +dpmin keeps the slope finite at
% dp = 0 so the solver does not stall; away from zero it is the usual
% q = CdA*sqrt(2*rho*dp).
dpmin = 1e3;                                    % Pa
q = CdA*sqrt(2*rho)*dp/sqrt(abs(dp) + dpmin);
end


function q = qgas(pu, pd, T, CdA, R, gam)
% Compressible orifice, forward direction only, choked and subsonic.
if pu <= pd || CdA <= 0
    q = 0; return
end
r     = pd/pu;
rcrit = (2/(gam+1))^(gam/(gam-1));
if r <= rcrit                                   % choked
    G = sqrt(gam)*(2/(gam+1))^((gam+1)/(2*(gam-1)));
    q = CdA*pu*G/sqrt(R*T);
else                                            % subsonic
    q = CdA*pu*sqrt(2*gam/((gam-1)*R*T)*(r^(2/gam) - r^((gam+1)/gam)));
end
end


%% ===================== sequences ====

function v = seq_start(t, p)
t_ign  = p.t0 + p.t_lead;
v.mfv  = stroke(t, p.t0,  p.t_open, 'open');
v.mov  = stroke(t, t_ign, p.t_open, 'open');
v.boot = stroke(t, t_ign, p.t_boot, 'open');
v.pc   = NaN;
end

function v = seq_close(t, p, tclose, first)
t_mfv = p.t0;  t_mov = p.t0;
if strcmp(first, 'MFV'), t_mov = p.t0 + p.gap; end
if strcmp(first, 'MOV'), t_mfv = p.t0 + p.gap; end
v.mov  = stroke(t, t_mov, tclose, 'close');
v.mfv  = stroke(t, t_mfv, tclose, 'close');
v.boot = 1;
v.pc   = NaN;
end

function v = seq_spike(t, p, pc_target)
v.mov = 1;  v.mfv = 1;  v.boot = 1;
if t >= p.t0 && t <= p.t0 + 0.010
    v.pc = pc_target;
else
    v.pc = NaN;
end
end

function u = stroke(t, t0, dur, direction)
x = min(max((t - t0)/dur, 0), 1);
u = 0.5*(1 - cos(pi*x));
if strcmp(direction, 'close'), u = 1 - u; end
end


%% ============================ plots ====
function plot_run(r, p, scale, ttl)
t = (r.t - p.t0)*scale;
if scale == 1, tl = 'Time [s]'; else, tl = 'Time [ms]'; end
figure('Color','w','Name',ttl);

subplot(2,1,1); hold on; grid on
plot(t, r.pc/1e5,     'Color', p.cPc, 'LineWidth', 2)
plot(t, r.p_ox/1e5,   'Color', p.cOx, 'LineWidth', 2)
plot(t, r.p_f/1e5,    'Color', p.cF,  'LineWidth', 2)
plot(t, r.sup_ox/1e5, '--', 'Color', p.cOx, 'LineWidth', 1)
plot(t, r.sup_f/1e5,  '--', 'Color', p.cF,  'LineWidth', 1)
xlim([0 max(t)]); ylabel('Pressure [bar]'); title(ttl)
legend('chamber p_c','LOx dome','CH_4 plenum', ...
       'LOx pump discharge','CH_4 supply','Location','best')

subplot(2,1,2); hold on; grid on
plot(t, r.dp_ox/1e5, 'Color', p.cOx, 'LineWidth', 2)
plot(t, r.dp_f/1e5,  'Color', p.cF,  'LineWidth', 2)
plot([0 max(t)], [0 0], 'r--')
xlim([0 max(t)]); xlabel(tl); ylabel('\Deltap_{inj} [bar]')
legend('LOx side','CH_4 side','Location','best')
end
