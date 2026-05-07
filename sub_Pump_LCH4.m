function [T_out, p_out, rho_out, P_pump] = sub_Pump_LCH4(T_in, p_in, rho_in, eta, delta_p_Pump, delta_p_lines_partial, c_p, m_dot)
    p_intermediate = p_in + delta_p_Pump;
    p_out = p_intermediate - delta_p_lines_partial;
    
    P_pump = (m_dot * delta_p_Pump) / (eta * rho_in);
    
    T_out = T_in + P_pump * (1 - eta) / c_p;
end

