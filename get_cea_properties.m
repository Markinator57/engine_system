function [T_CC, M] = get_cea_properties(p_CC, R_OF)
    % Inputs:
    %   p_CC  - chamber pressure [bar]
    %   R_OF  - oxidizer to fuel mixture ratio [-]
    % Outputs:
    %   T_CC  - adiabatic flame temperature [K]
    %   M     - combustion product molar mass [kg/kmol]
    %   K     - ratio of specific heats [-]

    persistent cea
    if isempty(cea)
        rocketcea = py.importlib.import_module('rocketcea.cea_obj');
        cea = rocketcea.CEA_Obj(oxName='LOX', fuelName='CH4');
    end

    p_CC_psia = p_CC / 6894.76;  % CEA expects psia

    % T_CC: get_Tcomb returns a scalar directly
    T_CC = double(cea.get_Tcomb(Pc=p_CC_psia, MR=R_OF)) * 5/9; % Rankine to Kelvin

    % M and K: get_Chamber_MolWt_gamma returns a tuple
    MK      = cell(cea.get_Chamber_MolWt_gamma(Pc=p_CC_psia, MR=R_OF));
    M       = double(MK{1});   % [g/mol]
    % kappa   = double(MK{2});   % [-]
end