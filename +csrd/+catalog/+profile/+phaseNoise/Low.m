function profile = Low()
%LOW v0 phase-noise level: high-end lab source / SDR with TCXO.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：提供 CSRD 生产链路中的 Low 实现。
%
% Source: docs/audits/2026-04-...refactor.md §16.8.3 (row 'Low').
% Bound directly to comm.PhaseNoise (Level, FrequencyOffset).

    profile = struct( ...
        'LevelDbcPerHz',     [-100 -120 -140 -150], ...
        'FrequencyOffsetsHz', [1e3 1e4 1e5 1e6]);
end
