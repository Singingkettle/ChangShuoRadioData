function profile = High()
%HIGH v0 phase-noise level: low-end SDR / cheap transceiver.
%
% Source: docs/audits/2026-04-...refactor.md §16.8.3 (row 'High').
% Bound directly to comm.PhaseNoise (Level, FrequencyOffset).

    profile = struct( ...
        'LevelDbcPerHz',     [-60 -80 -100 -115], ...
        'FrequencyOffsetsHz', [1e3 1e4 1e5 1e6]);
end
