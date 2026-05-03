function profile = Mid()
%MID v0 phase-noise level: commercial base station / mid-tier SDR (default).
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：提供 CSRD 生产链路中的 Mid 实现。
%
% Source: docs/audits/2026-04-...refactor.md §16.8.3 (row 'Mid').
% Bound directly to comm.PhaseNoise (Level, FrequencyOffset).

    profile = struct( ...
        'LevelDbcPerHz',     [-80 -100 -120 -135], ...
        'FrequencyOffsetsHz', [1e3 1e4 1e5 1e6]);
end
