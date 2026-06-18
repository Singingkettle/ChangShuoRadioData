classdef MessageSourceModulationBindingTest < matlab.unittest.TestCase
    %MESSAGESOURCEMODULATIONBINDINGTEST Message source must follow modulation.
    %
    % Analog modulation (FM/PM/AM variants) must be driven by the Audio
    % source; digital modulation (PSK/QAM/FSK/...) by RandomBit. Feeding a
    % bit stream to an analog modulator produces a physically meaningless
    % waveform, so the binding is a hard contract across the helper,
    % construction, and audio-selection layers.

    methods (Test)

        function helperClassifiesAnalogAndDigital(testCase)
            isAnalog = @(f) csrd.support.modulation.isAnalogModulationFamily(f);
            testCase.verifyTrue(isAnalog('FM'));
            testCase.verifyTrue(isAnalog('dsbam'));   % case-insensitive
            testCase.verifyTrue(isAnalog('VSBAM'));
            testCase.verifyFalse(isAnalog('PSK'));
            testCase.verifyFalse(isAnalog('QAM'));
            testCase.verifyFalse(isAnalog('OFDM'));
        end

        function helperMapsSourceFromFamily(testCase)
            src = @(f) csrd.support.modulation.messageSourceForModulation(f);
            testCase.verifyEqual(src('FM'), 'Audio');
            testCase.verifyEqual(src('SSBAM'), 'Audio');
            testCase.verifyEqual(src('PSK'), 'RandomBit');
            testCase.verifyEqual(src('QAM'), 'RandomBit');
        end

        function constructionAcceptsDigitalWithRandomBit(testCase)
            tx = localBaseTxScenario('PSK', 'RandomBit');
            seg = csrd.core.ChangShuo.buildSegmentConfigFromTxScenario(tx, 1);
            testCase.verifyEqual(char(string(seg.Message.TypeID)), 'RandomBit');
            testCase.verifyEqual(char(string(seg.Modulation.TypeID)), 'PSK');
        end

        function constructionAcceptsAnalogWithAudio(testCase)
            tx = localBaseTxScenario('FM', 'Audio');
            seg = csrd.core.ChangShuo.buildSegmentConfigFromTxScenario(tx, 1);
            testCase.verifyEqual(char(string(seg.Message.TypeID)), 'Audio');
            testCase.verifyEqual(char(string(seg.Modulation.TypeID)), 'FM');
        end

        function constructionRejectsAnalogWithRandomBit(testCase)
            tx = localBaseTxScenario('FM', 'RandomBit');
            testCase.verifyError( ...
                @() csrd.core.ChangShuo.buildSegmentConfigFromTxScenario(tx, 1), ...
                'CSRD:Construction:MessageSourceModulationMismatch');
        end

        function constructionRejectsDigitalWithAudio(testCase)
            tx = localBaseTxScenario('QAM', 'Audio');
            testCase.verifyError( ...
                @() csrd.core.ChangShuo.buildSegmentConfigFromTxScenario(tx, 1), ...
                'CSRD:Construction:MessageSourceModulationMismatch');
        end

        function audioSelectionIsDeterministicBySeed(testCase)
            a = csrd.blocks.physical.message.Audio('Seed', 123);
            o1 = a.step(1500, 44100);
            b = csrd.blocks.physical.message.Audio('Seed', 123);
            o2 = b.step(1500, 44100);
            testCase.verifyEqual(o1.data, o2.data, ...
                'Same seed must select the same clip and samples.');
            testCase.verifyEqual(o1.AudioFile, o2.AudioFile);
        end

        function audioOutputIsContinuousNotBinary(testCase)
            a = csrd.blocks.physical.message.Audio('Seed', 5);
            o = a.step(2000, 44100);
            distinct = numel(unique(round(o.data, 4)));
            testCase.verifyGreaterThan(distinct, 2, ...
                'Audio baseband must be continuous, not a 0/1 bit stream.');
        end

    end
end


function tx = localBaseTxScenario(modulationFamily, messageSource)
% localBaseTxScenario - Minimal txScenario for the segment builder contract.
tx = struct();
tx.Temporal.Intervals = [0, 1e-3];
tx.TransmissionState.FrameWindow = [0, 1e-3];
tx.Message.Type = messageSource;
tx.Message.Length = 1024;
tx.Modulation.Type = modulationFamily;
tx.Modulation.SymbolRate = 1e5;
tx.Modulation.BitsPerSymbol = 1;
tx.Hardware.NumAntennas = 1;
tx.ReceiverViews(1).ProjectedCenterOffsetHz = 0;
tx.Spectrum.PlannedBandwidth = 1e5;
tx.Spectrum.ReceiverSampleRate = 1e6;
end
