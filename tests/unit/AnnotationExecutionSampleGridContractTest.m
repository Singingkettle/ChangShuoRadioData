classdef AnnotationExecutionSampleGridContractTest < matlab.unittest.TestCase
    % AnnotationExecutionSampleGridContractTest - Annotation uses inserted samples.

    methods (Test)
        function receiverProcessingContainsSampleGridValidator(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            code = fileread(fullfile(root, '+csrd', '+core', '@ChangShuo', ...
                'private', 'processReceiverProcessing.m'));

            testCase.verifyTrue(contains(code, 'validateExecutionSampleGrid'), ...
                'processReceiverProcessing must validate Truth.Execution sample grid.');
            testCase.verifyTrue(contains(code, 'frameStart / sampleRate'));
            testCase.verifyTrue(contains(code, 'frameEnd / sampleRate'));
            testCase.verifyTrue(contains(code, 'frameCount / sampleRate'));
        end
    end
end
