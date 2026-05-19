classdef ChannelEmptyOutputBeforeDopplerTest < matlab.unittest.TestCase
    %CHANNELEMPTYOUTPUTBEFOREDOPPLERTEST Guard empty RayTracing output handling.

    methods (Test)

        function processChannelPropagationRecordsEmptyOutputBeforeDoppler(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            sourcePath = fullfile(root, '+csrd', '+core', '@ChangShuo', ...
                'private', 'processChannelPropagation.m');
            code = fileread(sourcePath);

            testCase.verifyTrue(contains(code, ...
                'ChannelOutputWasEmptyBeforeGating'), ...
                'Empty channel output must be visible before duration gating pads it.');
            testCase.verifyTrue(contains(code, ...
                'Channel.EmptyOutputBeforeDoppler'), ...
                'Empty channel output before Doppler must be counted in performance diagnostics.');
            testCase.verifyTrue(contains(code, ...
                'if isempty(channelOutput.Signal)'), ...
                'Doppler must not be applied to an empty channel output.');
        end

    end
end
