classdef FrequencyAllocationOverlapContractTest < matlab.unittest.TestCase
    %FREQUENCYALLOCATIONOVERLAPCONTRACTTEST Default generation cannot hide overlap.

    methods (Test)

        function defaultConfigurationDisablesOverlap(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);

            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            fa = cfg.Factories.Scenario.CommunicationBehavior.FrequencyAllocation;
            testCase.verifyFalse(fa.AllowOverlap);
        end

        function regulatoryPathPrecedesGenericOverlapWarning(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            pathText = fullfile(root, '+csrd', '+blocks', '+scenario', ...
                '@CommunicationBehaviorSimulator', 'private', ...
                'performScenarioFrequencyAllocation.m');
            text = fileread(pathText);
            regulatoryIdx = strfind(text, 'RegulatoryCatalog');
            warningIdx = strfind(text, 'Insufficient bandwidth, using overlapping allocation');
            testCase.assertNotEmpty(regulatoryIdx);
            testCase.assertNotEmpty(warningIdx);
            testCase.verifyLessThan(regulatoryIdx(1), warningIdx(1));
        end

        function overlapRequiresExplicitProvenance(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            pathText = fullfile(root, '+csrd', '+blocks', '+scenario', ...
                '@CommunicationBehaviorSimulator', 'private', ...
                'performScenarioFrequencyAllocation.m');
            text = fileread(pathText);
            testCase.verifyNotEmpty(strfind(text, ...
                'ExplicitFrequencyAllocationAllowOverlap'));
            testCase.verifyNotEmpty(strfind(text, ...
                'FrequencyAllocationInsufficientBandwidth'));
        end

    end
end
