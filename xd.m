% %% Solve for p_e after fuel turbine from power balance P_T = P_P
% % -------------------------------------------------------
% 
% %% --- Inputs ---
% 
% % Pump parameters
% m_dot_P = 3.0;      % [kg/s]   mass flow rate
% rho     = 450;      % [kg/m3]  LCH4 density
% delta_p = 118e5;    % [Pa]     pump pressure rise
% eta_P   = 0.70;     % [-]      pump efficiency
% 
% % Turbine parameters
% m_dot_T = 3.0;      % [kg/s]   turbine mass flow rate
% c_p     = 2300;     % [J/kg/K] specific heat of gaseous CH4
% T_in    = 284;      % [K]      turbine inlet temperature
% p_in    = 112e5;    % [Pa]     turbine inlet pressure
% kappa   = 1.31;     % [-]      ratio of specific heats
% eta_T   = 0.75;     % [-]      turbine efficiency
% 
% %% --- Step 1: Required pump power ---
% P_P = (m_dot_P / rho) / eta_P * delta_p;
% fprintf('Required pump power P_P = %.2f kW\n', P_P/1e3);
% 
% %% --- Step 2: Solve for p_e from P_T = P_P ---
% % P_T = eta_T * m_dot_T * c_p * T_in * (1 - (p_e/p_in)^((kappa-1)/kappa))
% % Rearranging:
% % (p_e/p_in)^((kappa-1)/kappa) = 1 - P_P / (eta_T * m_dot_T * c_p * T_in)
% 
% rhs = 1 - P_P / (eta_T * m_dot_T * c_p * T_in);
% 
% if rhs <= 0
%     error('Turbine cannot supply enough power — increase T_in or reduce delta_p.');
% end
% 
% exponent    = (kappa - 1) / kappa;          % (kappa-1)/kappa
% p_ratio     = rhs^(1 / exponent);           % (p_e/p_in)
% p_e_solved  = p_ratio * p_in;               % [Pa]
% 
% %% --- Results ---
% fprintf('Pressure ratio p_e/p_in = %.4f\n', p_ratio);
% fprintf('p_in  = %.2f bar\n', p_in/1e5);
% fprintf('p_e   = %.2f bar  <-- exit pressure after fuel turbine\n', p_e_solved/1e5);
% fprintf('Delta p across turbine = %.2f bar\n', (p_in - p_e_solved)/1e5);
% 
% % Verify: recompute turbine power at solved p_e
% P_T_check = eta_T * m_dot_T * c_p * T_in * (1 - (p_e_solved/p_in)^exponent);
% fprintf('\nVerification:\n');
% fprintf('  P_P       = %.2f kW\n', P_P/1e3);
% fprintf('  P_T check = %.2f kW\n', P_T_check/1e3);