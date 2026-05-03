function profile = PortableMonitor_40MHz()
%PORTABLEMONITOR_40MHZ v0 receiver profile: handheld monitor up to 40 MHz Fs.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：提供 CSRD 生产链路中的 PortableMonitor_40MHz 实现。
%
% Source numbers: docs/audits/2026-04-...refactor.md §5.bis B (row 1).
% Schema:        docs/audits/phases/phase-2-blueprint.md §3.1.3.B.
%
% Hard constraint (§5.bis B): SampleRate == ObservableBandwidth (equivalent
% baseband contract). ObservableBandwidthHz is left empty here and bound
% at runtime by Validator/ScenarioFactory once SampleRate is sampled.

    profile = struct( ...
        'SampleRateChoicesHz',     {{10e6, 20e6, 40e6}}, ...
        'ObservableBandwidthHz',   [], ...
        'NumAntennasRange',        [1 2], ...
        'NoiseFigureRangeDb',      [8 12], ...
        'SensitivityDbm',          -90, ...
        'CarrierFrequencyRangeHz', [8e3 8e9]);
end
