function [T_out, p_out, rho_out] = sub_Cooling_channels(T_in, p_in, rho_in, eta, Q_dot, delta_p_lines_partial, c_p, m_dot)
    % m_dot * h_in + Q_dot = m_dot * h_out
    h_in = c_p * T_in;
    h_out = h_in + Q_dot / m_dot;
    
    % T_out --> lookup table / find equation

    p_out = p_in - delta_p_lines_partial;
end

