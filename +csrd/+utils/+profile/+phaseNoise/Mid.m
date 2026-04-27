function profile = Mid()
%MID v0 phase-noise level: commercial base station / mid-tier SDR (default).
%
% Source: docs/audits/2026-04-...refactor.md §16.8.3 (row 'Mid').
% Bound directly to comm.PhaseNoise (Level, FrequencyOffset).

    profile = struct( ...
        'LevelDbcPerHz',     [-80 -100 -120 -135], ...
        'FrequencyOffsetsHz', [1e3 1e4 1e5 1e6]);
end
