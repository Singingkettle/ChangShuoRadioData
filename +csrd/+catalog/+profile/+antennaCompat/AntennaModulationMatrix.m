function profile = AntennaModulationMatrix()
%ANTENNAMODULATIONMATRIX v0 antenna-vs-modulation 3-state compatibility matrix.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：提供 CSRD 生产链路中的 AntennaModulationMatrix 实现。
%
% Source: docs/audits/2026-04-...refactor.md §16.8.4 (3-state table).
% Phase 2 §3.1.3.D wires the table here.
%
% Each modulation family maps to a 1x5 cell aligned with AntennaBins =
% [1 2 4 8 16] transmit antennas:
%   'Forbidden'   - Validator rejects this combination
%   'Conditional' - allowed only if the matching entry in Conditions is
%                   satisfied; missing condition -> reject
%   'Allowed'     - no extra constraint

    m = containers.Map('KeyType', 'char', 'ValueType', 'any');

    m('FM')      = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};
    m('PM')      = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};
    m('DSBAM')   = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};
    m('SSBAM')   = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};
    m('DSBSCAM') = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};
    m('VSBAM')   = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};

    m('FSK')     = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};
    m('MSK')     = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};
    m('CPFSK')   = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};
    m('GFSK')    = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};
    m('GMSK')    = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};

    m('PSK')     = {'Allowed','Allowed','Allowed','Conditional','Forbidden'};
    m('QAM')     = {'Allowed','Allowed','Allowed','Conditional','Forbidden'};
    m('PAM')     = {'Allowed','Allowed','Allowed','Conditional','Forbidden'};
    m('APSK')    = {'Allowed','Allowed','Allowed','Conditional','Forbidden'};
    m('OOK')     = {'Allowed','Allowed','Allowed','Conditional','Forbidden'};
    m('ASK')     = {'Allowed','Allowed','Allowed','Conditional','Forbidden'};

    m('OFDM')    = {'Allowed','Allowed','Allowed','Allowed','Conditional'};
    m('SC-FDMA') = {'Allowed','Allowed','Allowed','Forbidden','Forbidden'};
    m('OTFS')    = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};

    profile = struct( ...
        'Matrix',      m, ...
        'AntennaBins', [1 2 4 8 16], ...
        'Conditions',  struct( ...
            'PSK_QAM_x8', 'SymbolRate >= 1e6', ...
            'OFDM_x16',   'NumSubcarriers >= 512'));
end
