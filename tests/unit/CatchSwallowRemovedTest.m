classdef CatchSwallowRemovedTest < matlab.unittest.TestCase
    %CATCHSWALLOWREMOVEDTEST Phase 3 (§3.4) catch-swallow removal contract.
    %
    %   Pin the Phase 3 contract that the four legacy catch-swallow sites
    %   either rethrow now or have been deleted entirely:
    %
    %     1. processTransmitters.m              - removed the
    %        Status='Error_TransmitterProcessing' fallback.
    %     2. processTransmitterSegments.m       - removed the
    %        signalSegmentsPerTx{k} = [] silent-skip fallback.
    %     3. processTransmitImpairments.m       - removed the
    %        TransmitError = true magic flag (S4 deletion).
    %     4. ReceiveFactory.m (step path)       - removed the
    %        Error = 'ReceiverBlockStepFailed' silent annotation.
    %
    %   Plus the companion contract on
    %   csrd.pipeline.scenario.isScenarioSkipException :
    %     - any CSRD:Construction:* identifier is considered a
    %       scenario-skip token (Q3 = A: throw + scenario skip).
    %     - the historical tokens (SkipScenario / NoBuildingData /
    %       NoValidPaths / EmptyEntities / EntityDriftDetected) are still
    %       on the whitelist.

    methods (Test)

        % ---------- Source-level dead-code grep ------------------------

        function processTransmittersHasNoErrorTransmitterProcessingFallback(testCase)
            txt = CatchSwallowRemovedTest.readSrc('+csrd/+core/@ChangShuo/private/processTransmitters.m');
            code = CatchSwallowRemovedTest.stripComments(txt);
            testCase.verifyEmpty(regexp(code, 'Status''\s*,\s*''Error_TransmitterProcessing''', 'once'), ...
                'Phase 3 §3.4: legacy Error_TransmitterProcessing fallback must be removed.');
            testCase.verifyEmpty(regexp(code, 'txsSignalSegments\s*\{\s*txIdx\s*\}\s*=\s*\{\s*\}\s*;', 'once'), ...
                'Phase 3 §3.4: catch must not zero out txsSignalSegments{txIdx}.');
            testCase.verifyTrue(contains(code, 'rethrow(ME_tx)'), ...
                'Phase 3 §3.4: processTransmitters must rethrow per-Tx exceptions.');
        end

        function processTransmitterSegmentsHasNoEmptySegmentFallback(testCase)
            txt = CatchSwallowRemovedTest.readSrc('+csrd/+core/@ChangShuo/private/processTransmitterSegments.m');
            code = CatchSwallowRemovedTest.stripComments(txt);
            testCase.verifyEmpty(regexp(code, 'signalSegmentsPerTx\s*\{\s*k\s*\}\s*=\s*\[\s*\]\s*;', 'once'), ...
                'Phase 3 §3.4: catch must not silently zero out signalSegmentsPerTx{k}.');
            testCase.verifyTrue(contains(code, 'rethrow(ME_seg)'), ...
                'Phase 3 §3.4: processTransmitterSegments must rethrow per-segment exceptions.');
        end

        function processTransmitImpairmentsHasNoTransmitErrorFlag(testCase)
            txt = CatchSwallowRemovedTest.readSrc('+csrd/+core/@ChangShuo/private/processTransmitImpairments.m');
            code = CatchSwallowRemovedTest.stripComments(txt);
            testCase.verifyEmpty(regexp(code, 'TransmitError\s*=\s*true', 'once'), ...
                'Phase 3 §3.4 (and §3.2.B): TransmitError flag must be removed.');
            testCase.verifyEmpty(regexp(code, 'localResolvePlannedBandwidth', 'once'), ...
                'Phase 3 §3.2.B: localResolvePlannedBandwidth helper must be deleted.');
        end

        function receiveFactoryHasNoReceiverBlockStepFailedFallback(testCase)
            txt = CatchSwallowRemovedTest.readSrc('+csrd/+factories/ReceiveFactory.m');
            code = CatchSwallowRemovedTest.stripComments(txt);
            testCase.verifyEmpty(regexp(code, 'Error''\s*,\s*''ReceiverBlockStepFailed''', 'once'), ...
                'Phase 3 §3.4: ReceiverBlockStepFailed silent fallback must be removed.');
            testCase.verifyEmpty(regexp(code, '\.Error\s*=\s*''ReceiverBlockStepFailed''', 'once'), ...
                'Phase 3 §3.4: ReceiverBlockStepFailed silent stamp must be removed.');
            testCase.verifyTrue(contains(code, 'rethrow(ME_step)'), ...
                'Phase 3 §3.4: ReceiveFactory step catch must rethrow.');
        end

        function transmitFactoryHasNoBlockStepFailedFallback(testCase)
            txt = CatchSwallowRemovedTest.readSrc('+csrd/+factories/TransmitFactory.m');
            code = CatchSwallowRemovedTest.stripComments(txt);
            testCase.verifyEmpty(regexp(code, 'Error''\s*,\s*''TransmitterBlockStepFailed''', 'once'), ...
                'Phase 8: TransmitFactory must not stamp TransmitterBlockStepFailed sentinel outputs.');
            testCase.verifyEmpty(regexp(code, '\.Error\s*=\s*''TransmitterBlockStepFailed''', 'once'), ...
                'Phase 8: TransmitFactory must not return failed RF front-end signals as valid outputs.');
            testCase.verifyTrue(contains(code, 'rethrow(ME_step)'), ...
                'Phase 8: TransmitFactory step catch must rethrow RF front-end failures.');
        end

        function channelFactoryHasNoChannelBlockStepFailedFallback(testCase)
            txt = CatchSwallowRemovedTest.readSrc('+csrd/+factories/ChannelFactory.m');
            code = CatchSwallowRemovedTest.stripComments(txt);
            testCase.verifyEmpty(regexp(code, 'ChannelBlockStepFailed', 'once'), ...
                'Phase 5: ChannelFactory must not stamp ChannelBlockStepFailed sentinel outputs.');
            testCase.verifyTrue(contains(code, 'rethrow(ME_step)'), ...
                'Phase 5: ChannelFactory step catch must rethrow generic channel failures.');
        end

        function processChannelPropagationRethrowsGenericChannelErrors(testCase)
            txt = CatchSwallowRemovedTest.readSrc('+csrd/+core/@ChangShuo/private/processChannelPropagation.m');
            code = CatchSwallowRemovedTest.stripComments(txt);
            testCase.verifyTrue(contains(code, 'rethrow(ME_channel)'), ...
                'Phase 5: processChannelPropagation must rethrow channel exceptions.');
        end

        function generateSingleFrameHasNoFrameGenerationFailedFallback(testCase)
            txt = CatchSwallowRemovedTest.readSrc('+csrd/+core/@ChangShuo/private/generateSingleFrame.m');
            code = CatchSwallowRemovedTest.stripComments(txt);
            testCase.verifyEmpty(regexp(code, 'FrameGenerationFailed', 'once'), ...
                'Phase 5: generateSingleFrame must not write FrameGenerationFailed annotations.');
            testCase.verifyTrue(contains(code, 'rethrow(ME)'), ...
                'Phase 5: generateSingleFrame catch must rethrow non-skip errors.');
        end

        function processSingleTransmitterHasNoMissingTxSentinel(testCase)
            txt = CatchSwallowRemovedTest.readSrc('+csrd/+core/@ChangShuo/private/processSingleTransmitter.m');
            code = CatchSwallowRemovedTest.stripComments(txt);
            testCase.verifyEmpty(regexp(code, 'Error_MissingTxScenarioID', 'once'), ...
                'Phase 5: missing transmitter scenario ID must fail fast, not return an Error_* TxInfo.');
        end

        function legacyCocoConverterDoesNotParseV1Annotation(testCase)
            txt = CatchSwallowRemovedTest.readSrc('tools/convert_csrd_to_coco.m');
            code = CatchSwallowRemovedTest.stripComments(txt);
            testCase.verifyEmpty(regexp(code, 'meta\.annotation\.(rx|tx)', 'once'), ...
                'Phase 5: COCO converter must not parse legacy annotation.rx/tx paths.');
            testCase.verifyEmpty(regexp(code, 'annotation\.(rx|tx)', 'once'), ...
                'Phase 6: COCO converter must not read legacy annotation.rx/tx paths.');
            testCase.verifyTrue(contains(code, 'readAnnotationV2'), ...
                'Phase 6: COCO converter must validate annotation v2 before export.');
        end

        % ---------- isScenarioSkipException contract -------------------

        function constructionMissingIdentifiersAreHardFailures(testCase)
            ids = { ...
                'CSRD:Construction:MissingMessageConfig', ...
                'CSRD:Construction:MissingModulationConfig', ...
                'CSRD:Construction:MissingReceiverViews', ...
                'CSRD:Construction:MissingSampleRate', ...
                'CSRD:Construction:MissingFrequencyOffset', ...
                'CSRD:Construction:MissingSegmentPlannedTruth', ...
                'CSRD:Construction:MissingMobilityModel', ...
                'CSRD:Construction:MissingMapBoundaries', ...
                'CSRD:Construction:RxMissingObservation', ...
                'CSRD:Construction:RxMissingHardware', ...
                'CSRD:Construction:RxMissingPhysical', ...
                'CSRD:Construction:RxScenarioOutOfRange', ...
                'CSRD:Construction:RxMissingIdentifier', ...
                'CSRD:Construction:RxInvalidStatus', ...
                'CSRD:Construction:TxScenarioOutOfRange', ...
                'CSRD:Construction:TxMissingEntityID', ...
                'CSRD:Construction:MissingActiveSegmentIndices', ...
                'CSRD:Construction:MissingActiveIntervalIndices', ...
                'CSRD:Construction:ActiveButNoIntervals', ...
                'CSRD:Construction:ChannelMissingSampleRate', ...
                'CSRD:Construction:UnknownEntityType' ...
            };
            for k = 1:numel(ids)
                me = MException(ids{k}, 'phase3 contract probe');
                tf = csrd.pipeline.scenario.isScenarioSkipException(me);
                testCase.verifyFalse(tf, sprintf( ...
                    'Phase 20: %s must be counted as failure, not scenario skip.', ids{k}));
            end
        end

        function legacySkipTokensStillRecognised(testCase)
            ids = { ...
                'ScenarioFactory:SkipScenario', ...
                'CSRD:Map:NoBuildingData', ...
                'CSRD:RayTracing:NoValidPaths', ...
                'CSRD:Scenario:EmptyEntities', ...
                'CSRD:Scenario:EntityDriftDetected' ...
            };
            for k = 1:numel(ids)
                me = MException(ids{k}, 'phase3 backwards-compat probe');
                tf = csrd.pipeline.scenario.isScenarioSkipException(me);
                testCase.verifyTrue(tf, sprintf( ...
                    'Phase 3: legacy skip token %s must still match.', ids{k}));
            end
        end

        function arbitraryNonSkipIdentifierStillReturnsFalse(testCase)
            me = MException('CSRD:Foo:Bar', 'definitely not a scenario skip');
            testCase.verifyFalse(csrd.pipeline.scenario.isScenarioSkipException(me));
        end

        function emptyIdentifierIsNotScenarioSkip(testCase)
            me = MException('', 'no id');
            testCase.verifyFalse(csrd.pipeline.scenario.isScenarioSkipException(me));
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
            % Strip MATLAB single-line comments (% to EOL) so dead-code
            % grep regexes can be applied to executable code only.
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
