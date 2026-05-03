classdef AnnotationExecutionSampleGridContractTest < matlab.unittest.TestCase
    % AnnotationExecutionSampleGridContractTest - Annotation uses inserted samples.
    % 中文说明：Truth.Execution 时间必须来自接收端实际插入样点。

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
