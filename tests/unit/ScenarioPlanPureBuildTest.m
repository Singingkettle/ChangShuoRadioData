classdef ScenarioPlanPureBuildTest < matlab.unittest.TestCase
    %SCENARIOPLANPUREBUILDTEST ScenarioPlan is not built through frame execution.

    methods (Test)
        function planScenarioDoesNotCallFrameStep(testCase)
            code = fileread(localScenarioFactoryPath());
            codeOnly = localStripComments(code);

            testCase.verifyEmpty(regexp(codeOnly, ...
                'step\s*\(\s*obj\s*,\s*1\s*\)', 'once'));
        end

        function scenarioFactoryHasNoFrameOnePlanCache(testCase)
            code = fileread(localScenarioFactoryPath());
            codeOnly = localStripComments(code);

            testCase.verifyFalse(contains(codeOnly, 'plannedFrameOne'));
        end
    end
end

function filePath = localScenarioFactoryPath()
testDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(fileparts(testDir));
filePath = fullfile(projectRoot, '+csrd', '+factories', 'ScenarioFactory.m');
end

function codeOnly = localStripComments(code)
lines = regexp(code, '\r\n|\n|\r', 'split');
for idx = 1:numel(lines)
    commentStart = strfind(lines{idx}, '%');
    if ~isempty(commentStart)
        lines{idx} = extractBefore(lines{idx}, commentStart(1));
    end
end
codeOnly = strjoin(lines, newline);
end
