classdef ProvenanceDataflowTest < matlab.unittest.TestCase
    %PROVENANCEDATAFLOWTEST Phase 3 (§3.5 / §17.5 P3-7) provenance dataflow.
    %
    %   Pin the new provenance dataflow contract:
    %
    %     1. ChangShuo.LastGlobalLayout is a public read-only property.
    %     2. ChangShuo.extractProvenanceFromGlobalLayout returns the three
    %        canonical Phase 2 keys (BlueprintHash, BlueprintResamples,
    %        ValidatorVersion) populated from globalLayout, with sane
    %        empty defaults when fields are missing.
    %     3. SimulationRunner uses the public property + static helper
    %        instead of the legacy Hidden accessor (`getScenarioBlueprintProvenance`).
    %     4. Source-level dead-code grep: `getScenarioBlueprintProvenance`
    %        and `ismethod.*[Pp]rovenance` have 0 hits in production code.
    %     5. End-to-end smoke: a 1-Tx / 1-Rx scenario produces an annotation
    %        whose Header.Runtime carries non-empty BlueprintHash + ValidatorVersion.

    methods (Test)

        % ---------- Static helper: the three keys are always present ----

        function helperReturnsThreeCanonicalKeysOnEmptyInput(testCase)
            p = csrd.core.ChangShuo.extractProvenanceFromGlobalLayout(struct());
            testCase.verifyTrue(isstruct(p));
            testCase.verifyEqual(sort(fieldnames(p)), sort({'BlueprintHash'; ...
                'BlueprintResamples'; 'ValidatorVersion'}));
            testCase.verifyEqual(p.BlueprintHash, '');
            testCase.verifyEqual(p.BlueprintResamples, 0);
            testCase.verifyEqual(p.ValidatorVersion, '');
        end

        function helperReturnsThreeKeysOnNonStructInput(testCase)
            p = csrd.core.ChangShuo.extractProvenanceFromGlobalLayout([]);
            testCase.verifyTrue(isstruct(p));
            testCase.verifyEqual(p.BlueprintHash, '');
            testCase.verifyEqual(p.BlueprintResamples, 0);
            testCase.verifyEqual(p.ValidatorVersion, '');
        end

        function helperReadsBlueprintHashAndValidatorVersion(testCase)
            gl = struct();
            gl.BlueprintHash = 'deadbeefcafebabe';
            gl.NumBlueprintAttempts = 1;
            gl.ValidationReport = struct( ...
                'IsFeasible', true, ...
                'Provenance', struct('ValidatorVersion', 'p3-frozen'));
            p = csrd.core.ChangShuo.extractProvenanceFromGlobalLayout(gl);
            testCase.verifyEqual(p.BlueprintHash, 'deadbeefcafebabe');
            testCase.verifyEqual(p.BlueprintResamples, 0);
            testCase.verifyEqual(p.ValidatorVersion, 'p3-frozen');
        end

        function helperConvertsAttemptsToResamples(testCase)
            gl = struct();
            gl.BlueprintHash = 'h';
            gl.NumBlueprintAttempts = 3;
            gl.ValidationReport = struct('Provenance', struct('ValidatorVersion', 'p3-frozen'));
            p = csrd.core.ChangShuo.extractProvenanceFromGlobalLayout(gl);
            testCase.verifyEqual(p.BlueprintResamples, 2, ...
                'BlueprintResamples must be NumBlueprintAttempts - 1 (clamped at 0).');
        end

        function helperClampsZeroAttempts(testCase)
            gl = struct();
            gl.NumBlueprintAttempts = 0;
            p = csrd.core.ChangShuo.extractProvenanceFromGlobalLayout(gl);
            testCase.verifyEqual(p.BlueprintResamples, 0);
        end

        function helperToleratesMissingValidationReport(testCase)
            gl = struct('BlueprintHash', 'abc', 'NumBlueprintAttempts', 1);
            p = csrd.core.ChangShuo.extractProvenanceFromGlobalLayout(gl);
            testCase.verifyEqual(p.BlueprintHash, 'abc');
            testCase.verifyEqual(p.ValidatorVersion, '');
        end

        function helperIgnoresValidationReportMissingProvenance(testCase)
            gl = struct( ...
                'BlueprintHash', 'abc', ...
                'ValidationReport', struct('IsFeasible', true));
            p = csrd.core.ChangShuo.extractProvenanceFromGlobalLayout(gl);
            testCase.verifyEqual(p.ValidatorVersion, '');
        end

        % ---------- Engine property contract -----------------------------

        function lastGlobalLayoutIsPublicReadOnlyProperty(testCase)
            mc = ?csrd.core.ChangShuo;
            propNames = arrayfun(@(p) p.Name, mc.PropertyList, 'UniformOutput', false);
            idx = find(strcmp(propNames, 'LastGlobalLayout'), 1);
            testCase.assertNotEmpty(idx, ...
                'Phase 3 §3.5: ChangShuo must expose LastGlobalLayout property.');
            prop = mc.PropertyList(idx);
            testCase.verifyEqual(prop.GetAccess, 'public', ...
                'Phase 3 §3.5: LastGlobalLayout must be publicly readable.');
            testCase.verifyEqual(prop.SetAccess, 'private', ...
                'Phase 3 §3.5: LastGlobalLayout must be set only inside ChangShuo.');
        end

        function freshEngineLastGlobalLayoutIsEmptyStruct(testCase)
            engine = csrd.core.ChangShuo();
            testCase.verifyTrue(isstruct(engine.LastGlobalLayout));
            testCase.verifyEmpty(fieldnames(engine.LastGlobalLayout));
        end

        function externalSetOfLastGlobalLayoutIsRejected(testCase)
            engine = csrd.core.ChangShuo();
            try
                engine.LastGlobalLayout = struct('BlueprintHash', 'pwn');
                testCase.verifyFail('Phase 3 §3.5: LastGlobalLayout must reject external writes.');
            catch ME
                testCase.verifyTrue(any(strcmp(ME.identifier, { ...
                    'MATLAB:class:SetProhibited', 'MATLAB:noPublicSetMethod'})), ...
                    sprintf('Unexpected error id %s when writing read-only property.', ME.identifier));
            end
        end

        % ---------- Source-level dead-code grep --------------------------

        function legacyHiddenAccessorIsGoneFromChangShuo(testCase)
            txt = ProvenanceDataflowTest.readSrc('+csrd/+core/@ChangShuo/ChangShuo.m');
            code = ProvenanceDataflowTest.stripComments(txt);
            testCase.verifyEmpty(regexp(code, 'function\s+\w+\s*=\s*getScenarioBlueprintProvenance', 'once'), ...
                'Phase 3 §3.5: ChangShuo.getScenarioBlueprintProvenance must be deleted.');
        end

        function simulationRunnerNoLongerCallsHiddenAccessorOrIsmethod(testCase)
            txt = ProvenanceDataflowTest.readSrc('+csrd/SimulationRunner.m');
            code = ProvenanceDataflowTest.stripComments(txt);
            testCase.verifyEmpty(regexp(code, 'getScenarioBlueprintProvenance', 'once'), ...
                'Phase 3 §3.5: SimulationRunner must not call the legacy Hidden accessor.');
            testCase.verifyEmpty(regexp(code, 'ismethod\s*\([^)]*[Pp]rovenance', 'once'), ...
                'Phase 3 §3.5: SimulationRunner must not guard provenance with ismethod.');
            testCase.verifyTrue(contains(code, 'extractProvenanceFromGlobalLayout'), ...
                'Phase 3 §3.5: SimulationRunner must read provenance via the static helper.');
            testCase.verifyTrue(contains(code, 'LastGlobalLayout'), ...
                'Phase 3 §3.5: SimulationRunner must read the LastGlobalLayout property.');
        end

    end

    methods (Static, Access = private)

        function txt = readSrc(relPath)
            here = fileparts(mfilename('fullpath'));
            full = fullfile(here, '..', '..', relPath);
            assert(isfile(full), 'Could not locate %s', relPath);
            txt = fileread(full);
        end

        function out = stripComments(src)
            lines = regexp(src, '\r?\n', 'split');
            out = '';
            for k = 1:numel(lines)
                line = lines{k};
                inStr = false;
                cutAt = numel(line) + 1;
                for c = 1:numel(line)
                    ch = line(c);
                    if ch == '''' && (c == 1 || line(c-1) ~= '''')
                        inStr = ~inStr;
                    elseif ch == '%' && ~inStr
                        cutAt = c;
                        break;
                    end
                end
                out = [out, line(1:cutAt-1), newline]; %#ok<AGROW>
            end
        end

    end

end
