classdef DeprecatedGlobalFrameFieldsRejectedTest < matlab.unittest.TestCase
    %DEPRECATEDGLOBALFRAMEFIELDSREJECTEDTEST Old raw frame authorities fail fast.

    methods (Test)
        function oldGlobalFrameFieldsAreRejectedAtConfigBoundary(testCase)
            fields = {'FrameNumSamples', 'NumFramesPerScenario', ...
                'FrameLength', 'FrameDuration', 'ObservationDuration', ...
                'TimeResolution'};

            for idx = 1:numel(fields)
                cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
                if ~isfield(cfg.Factories.Scenario, 'Global')
                    cfg.Factories.Scenario.Global = struct();
                end
                cfg.Factories.Scenario.Global.(fields{idx}) = 1;
                testCase.verifyError(@() ...
                    csrd.pipeline.runtime.buildRuntimePlan(cfg), ...
                    'CSRD:RuntimePlan:DeprecatedRawField');
            end
        end
    end
end
