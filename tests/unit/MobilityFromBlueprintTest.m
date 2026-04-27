classdef MobilityFromBlueprintTest < matlab.unittest.TestCase
    %MOBILITYFROMBLUEPRINTTEST Phase 3 (§3.3.C) mobility-from-blueprint contract.
    %
    %   Pin the contract that PhysicalEnvironmentSimulator.assignMobilityModel
    %   reads the per-entity mobility model from the supplied configuration
    %   slice and never falls back to a random pick. The legacy line
    %       models = {'RandomWalk', 'Waypoint', 'Stationary'};
    %       mobilityModel = models{randi(length(models))};
    %   has been removed; an entity that reaches the simulator without an
    %   explicit Mobility.Model raises CSRD:Construction:MissingMobilityModel.
    %
    %   The helper is exposed as a Static, Hidden method on
    %   csrd.blocks.scenario.PhysicalEnvironmentSimulator so it can be
    %   exercised here without instantiating the full simulator.

    methods (Test)

        % ---------- Happy path: canonical Mobility.Model layout --------

        function txWithMobilityModelReturnsConfiguredValue(testCase)
            cfg = MobilityFromBlueprintTest.makeEntityConfig('Vehicular');
            actual = csrd.blocks.scenario.PhysicalEnvironmentSimulator ...
                .assignMobilityModel('Transmitter', cfg);
            testCase.verifyEqual(actual, 'Vehicular');
        end

        function rxWithStationaryModelReturnsStationary(testCase)
            cfg = MobilityFromBlueprintTest.makeEntityConfig('Stationary');
            actual = csrd.blocks.scenario.PhysicalEnvironmentSimulator ...
                .assignMobilityModel('Receiver', cfg);
            testCase.verifyEqual(actual, 'Stationary');
        end

        % ---------- Happy path: alternate flat MobilityModel field -----

        function flatMobilityModelFieldIsAccepted(testCase)
            cfg = struct('MobilityModel', 'Waypoint');
            actual = csrd.blocks.scenario.PhysicalEnvironmentSimulator ...
                .assignMobilityModel('Transmitter', cfg);
            testCase.verifyEqual(actual, 'Waypoint');
        end

        function stringMobilityModelIsCoercedToChar(testCase)
            cfg = struct('Mobility', struct('Model', "RandomWalk"));
            actual = csrd.blocks.scenario.PhysicalEnvironmentSimulator ...
                .assignMobilityModel('Transmitter', cfg);
            testCase.verifyClass(actual, 'char');
            testCase.verifyEqual(actual, 'RandomWalk');
        end

        % ---------- Determinism: no random fallback path ---------------

        function repeatedCallsReturnIdenticalValue(testCase)
            % Phase 3 contract: regardless of how many times we call the
            % resolver with the same blueprint slice, we get back the same
            % mobility model. The legacy randi-based selection violated
            % this and is gone.
            cfg = MobilityFromBlueprintTest.makeEntityConfig('RandomWalk');
            n = 8;
            seen = strings(1, n);
            for k = 1:n
                seen(k) = csrd.blocks.scenario.PhysicalEnvironmentSimulator ...
                    .assignMobilityModel('Transmitter', cfg);
            end
            testCase.verifyEqual(numel(unique(seen)), 1);
            testCase.verifyEqual(char(seen(1)), 'RandomWalk');
        end

        % ---------- Sad path: missing config / fields ------------------

        function missingEntityConfigRaisesMissingMobilityModel(testCase)
            f = @() csrd.blocks.scenario.PhysicalEnvironmentSimulator ...
                .assignMobilityModel('Transmitter');
            testCase.verifyError(f, 'CSRD:Construction:MissingMobilityModel');
        end

        function missingMobilityModelFieldRaisesMissingMobilityModel(testCase)
            cfg = struct('Count', struct('Min', 1, 'Max', 4));
            f = @() csrd.blocks.scenario.PhysicalEnvironmentSimulator ...
                .assignMobilityModel('Transmitter', cfg);
            testCase.verifyError(f, 'CSRD:Construction:MissingMobilityModel');
        end

        function emptyMobilityModelRaisesMissingMobilityModel(testCase)
            cfg = struct('Mobility', struct('Model', ''));
            f = @() csrd.blocks.scenario.PhysicalEnvironmentSimulator ...
                .assignMobilityModel('Receiver', cfg);
            testCase.verifyError(f, 'CSRD:Construction:MissingMobilityModel');
        end

        function nonStringMobilityModelRaisesMissingMobilityModel(testCase)
            cfg = struct('Mobility', struct('Model', 42));
            f = @() csrd.blocks.scenario.PhysicalEnvironmentSimulator ...
                .assignMobilityModel('Transmitter', cfg);
            testCase.verifyError(f, 'CSRD:Construction:MissingMobilityModel');
        end

        % ---------- Dead-code grep: no randi fallback in source --------

        function deadCodeRandiFallbackIsRemoved(testCase)
            here = fileparts(mfilename('fullpath'));
            classFile = fullfile(here, '..', '..', '+csrd', '+blocks', ...
                '+scenario', '@PhysicalEnvironmentSimulator', ...
                'PhysicalEnvironmentSimulator.m');
            testCase.assertTrue(isfile(classFile), ...
                sprintf('Expected to find PhysicalEnvironmentSimulator.m at %s', classFile));
            txt = fileread(classFile);
            codeOnly = MobilityFromBlueprintTest.stripComments(txt);
            testCase.verifyEmpty(regexp(codeOnly, 'models\s*\{\s*randi\s*\(\s*length\s*\(\s*models\s*\)\s*\)\s*\}', 'once'), ...
                'Phase 3 §3.3.C: legacy random mobility selection must not be present.');
            testCase.verifyEmpty(regexp(codeOnly, '\{\s*''RandomWalk''\s*,\s*''Waypoint''\s*,\s*''Stationary''\s*\}', 'once'), ...
                'Phase 3 §3.3.C: legacy candidate-mobility cell array must not be present.');

            privateDir = fullfile(here, '..', '..', '+csrd', '+blocks', ...
                '+scenario', '@PhysicalEnvironmentSimulator', 'private');
            legacyHelper = fullfile(privateDir, 'assignMobilityModel.m');
            testCase.verifyFalse(isfile(legacyHelper), ...
                ['Phase 3 §3.3.C: the legacy private/assignMobilityModel.m ', ...
                 'helper must be deleted; the resolver lives as a Static, ', ...
                 'Hidden method on PhysicalEnvironmentSimulator now.']);
        end

    end

    methods (Static, Access = private)

        function cfg = makeEntityConfig(modelName)
            cfg = struct();
            cfg.Count = struct('Min', 1, 'Max', 1);
            cfg.Mobility = struct('Model', modelName);
        end

        function out = stripComments(src)
            % Strip MATLAB single-line comments (% to EOL) so dead-code
            % grep regexes can be applied to executable code only. We
            % deliberately keep the line breaks so line-anchored patterns
            % still behave sensibly.
            lines = regexp(src, '\r?\n', 'split');
            out = '';
            for k = 1:numel(lines)
                line = lines{k};
                % Find first '%' that is not inside a single-quoted
                % string. The simulator source does not use char-literal
                % '%' patterns in mobility code, so a conservative parse
                % is sufficient here.
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
