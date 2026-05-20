classdef DerivedFieldsRejectedInRawConfigTest < matlab.unittest.TestCase
    % DerivedFieldsRejectedInRawConfigTest - Raw config rejects old authorities.

    methods (Test)
        function frameDerivedFieldsAreRejected(testCase)
            fields = {'FrameDuration', 'ObservationDuration', 'TimeResolution'};
            for idx = 1:numel(fields)
                cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
                cfg.Factories.Scenario.Global.(fields{idx}) = 1;
                testCase.verifyError(@() ...
                    csrd.pipeline.runtime.buildRuntimePlan(cfg), ...
                    ['CSRD:Frame:DeprecatedDerived' localSuffix(fields{idx})]);
            end
        end

        function legacyAuthorityFieldsAreRejected(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            cfg.Runner.FixedFrameLength = 1024;
            testCase.verifyError(@() csrd.pipeline.runtime.buildRuntimePlan(cfg), ...
                'CSRD:RuntimePlan:DeprecatedRawField');

            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            cfg.Factories.Channel.LinkBudget.CarrierFrequency = 2.4e9;
            testCase.verifyError(@() csrd.pipeline.runtime.buildRuntimePlan(cfg), ...
                'CSRD:RuntimeTruth:DeprecatedCarrierFrequencyAuthority');

            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            cfg.Factories.Scenario.PhysicalEnvironment.Map.OSM.MaxFileSizeMB = 32;
            testCase.verifyError(@() csrd.pipeline.runtime.buildRuntimePlan(cfg), ...
                'CSRD:RuntimePlan:DeprecatedRawField');

            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            cfg.Factories.Scenario.TestSegment.SeedValue = 7;
            testCase.verifyError(@() csrd.pipeline.runtime.buildRuntimePlan(cfg), ...
                'CSRD:RuntimePlan:DeprecatedRawField');

            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            cfg.Factories.Scenario.TestSegment.SegmentID = 'legacy';
            testCase.verifyError(@() csrd.pipeline.runtime.buildRuntimePlan(cfg), ...
                'CSRD:RuntimePlan:DeprecatedRawField');
        end
    end
end

function suffix = localSuffix(fieldName)
switch fieldName
    case 'FrameDuration'
        suffix = 'FrameDuration';
    case 'ObservationDuration'
        suffix = 'ObservationDuration';
    case 'TimeResolution'
        suffix = 'TimeResolution';
    otherwise
        suffix = '';
end
end
