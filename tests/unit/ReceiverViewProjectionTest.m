classdef ReceiverViewProjectionTest < matlab.unittest.TestCase
    %RECEIVERVIEWPROJECTIONTEST Phase 3 unit tests for the ReceiverView
    %projection algorithm exposed as the Hidden static method
    %`csrd.blocks.scenario.CommunicationBehaviorSimulator.projectReceiverViews`.
    %
    %   Validates the canonical 5-field ReceiverView schema (audit
    %   §3.1.ter A / docs/audits/phases/phase-3-construction.md §3.1.A):
    %     ReceiverId / ProjectedCenterOffsetHz / ProjectedLowerEdgeHz /
    %     ProjectedUpperEdgeHz / IsVisible / VisibilityReason.
    %
    %   Maps to: phase-3-construction.md §6 S2.

    methods (Test)

        function singleReceiverPopulatesOneView(testCase)
            spectrum = makeSpectrum(10e6, 0);
            rxConfigs = {makeRxConfig('Rx1', [-25e6, 25e6])};
            rvs = csrd.blocks.scenario.CommunicationBehaviorSimulator ...
                .projectReceiverViews(spectrum, rxConfigs, [-25e6, 25e6]);
            testCase.verifyEqual(numel(rvs), 1);
            testCase.verifyEqual(rvs(1).ReceiverId, 'Rx1');
            verifyFiveFieldSchema(testCase, rvs(1));
        end

        function multipleReceiversPopulatesAllViews(testCase)
            spectrum = makeSpectrum(10e6, 0);
            rxConfigs = {makeRxConfig('Rx1', [-25e6, 25e6]), ...
                          makeRxConfig('Rx2', [-25e6, 25e6]), ...
                          makeRxConfig('Rx3', [-25e6, 25e6])};
            rvs = csrd.blocks.scenario.CommunicationBehaviorSimulator ...
                .projectReceiverViews(spectrum, rxConfigs, [-25e6, 25e6]);
            testCase.verifyEqual(numel(rvs), 3);
            testCase.verifyEqual({rvs.ReceiverId}, {'Rx1', 'Rx2', 'Rx3'});
            for k = 1:3
                verifyFiveFieldSchema(testCase, rvs(k));
            end
        end

        function projectionMatchesPlannedFreqOffsetUnifiedRx(testCase)
            % Phase 3 unified-receiver case: ProjectedCenterOffsetHz on
            % every ReceiverView equals txSpectrum.PlannedFreqOffset.
            spectrum = makeSpectrum(8e6, 7.5e6);
            rxConfigs = {makeRxConfig('Rx1', [-25e6, 25e6]), ...
                          makeRxConfig('Rx2', [-25e6, 25e6])};
            rvs = csrd.blocks.scenario.CommunicationBehaviorSimulator ...
                .projectReceiverViews(spectrum, rxConfigs, [-25e6, 25e6]);
            for k = 1:numel(rvs)
                testCase.verifyEqual(rvs(k).ProjectedCenterOffsetHz, 7.5e6);
                testCase.verifyEqual(rvs(k).ProjectedLowerEdgeHz, 7.5e6 - 4e6);
                testCase.verifyEqual(rvs(k).ProjectedUpperEdgeHz, 7.5e6 + 4e6);
            end
        end

        function inBandReceiverFlaggedVisible(testCase)
            spectrum = makeSpectrum(4e6, 0);
            rxConfigs = {makeRxConfig('Rx1', [-25e6, 25e6])};
            rvs = csrd.blocks.scenario.CommunicationBehaviorSimulator ...
                .projectReceiverViews(spectrum, rxConfigs, [-25e6, 25e6]);
            testCase.verifyTrue(rvs(1).IsVisible);
            testCase.verifyEqual(rvs(1).VisibilityReason, 'InBand');
        end

        function smallerReceiverWindowFlaggedOutOfBand(testCase)
            % Tx placed near the edge (offset = 20 MHz, half-bw = 4 MHz)
            % is fully out of a tight Rx window of [-1, +1] MHz.
            spectrum = makeSpectrum(8e6, 20e6);
            rxConfigs = {makeRxConfig('Rx1', [-1e6, 1e6])};
            rvs = csrd.blocks.scenario.CommunicationBehaviorSimulator ...
                .projectReceiverViews(spectrum, rxConfigs, [-25e6, 25e6]);
            testCase.verifyFalse(rvs(1).IsVisible);
            testCase.verifyEqual(rvs(1).VisibilityReason, 'OutOfBand');
        end

        function edgeClippedReceiverFlaggedNonVisible(testCase)
            % half-bw = 4 MHz, offset = +6 MHz, half-window = +8 MHz
            % => abs(offset) + halfBw = 10 MHz > 8 MHz (not InBand)
            % => abs(offset) - halfBw = 2 MHz < 8 MHz (still partially in)
            spectrum = makeSpectrum(8e6, 6e6);
            rxConfigs = {makeRxConfig('Rx1', [-8e6, 8e6])};
            rvs = csrd.blocks.scenario.CommunicationBehaviorSimulator ...
                .projectReceiverViews(spectrum, rxConfigs, [-25e6, 25e6]);
            testCase.verifyFalse(rvs(1).IsVisible);
            testCase.verifyEqual(rvs(1).VisibilityReason, 'EdgeClipped');
        end

        function structInputFormDoesNotBreakProjection(testCase)
            % Receivers may be passed as a struct array; the algorithm
            % must still produce equivalent output.
            spectrum = makeSpectrum(4e6, 0);
            rxStruct(1) = makeRxConfig('Rx1', [-25e6, 25e6]);
            rxStruct(2) = makeRxConfig('Rx2', [-25e6, 25e6]);
            rvs = csrd.blocks.scenario.CommunicationBehaviorSimulator ...
                .projectReceiverViews(spectrum, rxStruct, [-25e6, 25e6]);
            testCase.verifyEqual(numel(rvs), 2);
            testCase.verifyEqual({rvs.ReceiverId}, {'Rx1', 'Rx2'});
        end

        function missingObservableRangeFailsFast(testCase)
            % Receiver-view projection must use the receiver's own
            % Observation.ObservableRange; the unified fallback hid
            % configuration bugs.
            spectrum = makeSpectrum(8e6, 6e6);
            rxConfigs = {struct('EntityID', 'Rx1')};
            testCase.verifyError(@() csrd.blocks.scenario.CommunicationBehaviorSimulator ...
                .projectReceiverViews(spectrum, rxConfigs, [-8e6, 8e6]), ...
                'CSRD:Scenario:MissingReceiverObservableRange');
        end

        function missingSpectrumFieldsThrows(testCase)
            % Defensive: missing PlannedFreqOffset / PlannedBandwidth
            % must trigger a deterministic error.
            badSpectrum = struct('PlannedBandwidth', 4e6);
            rxConfigs = {makeRxConfig('Rx1', [-25e6, 25e6])};
            testCase.verifyError(@() csrd.blocks.scenario ...
                .CommunicationBehaviorSimulator.projectReceiverViews( ...
                badSpectrum, rxConfigs, [-25e6, 25e6]), ...
                'CSRD:Scenario:MissingSpectrum');
        end

    end
end


function verifyFiveFieldSchema(testCase, rv)
    testCase.verifyTrue(isfield(rv, 'ReceiverId'));
    testCase.verifyTrue(isfield(rv, 'ProjectedCenterOffsetHz'));
    testCase.verifyTrue(isfield(rv, 'ProjectedLowerEdgeHz'));
    testCase.verifyTrue(isfield(rv, 'ProjectedUpperEdgeHz'));
    testCase.verifyTrue(isfield(rv, 'IsVisible'));
    testCase.verifyTrue(isfield(rv, 'VisibilityReason'));
    testCase.verifyTrue(islogical(rv.IsVisible));
    testCase.verifyTrue(isnumeric(rv.ProjectedCenterOffsetHz));
    testCase.verifyTrue(isnumeric(rv.ProjectedLowerEdgeHz));
    testCase.verifyTrue(isnumeric(rv.ProjectedUpperEdgeHz));
    testCase.verifyTrue(ischar(rv.ReceiverId));
    testCase.verifyTrue(ischar(rv.VisibilityReason));
    testCase.verifyTrue(any(strcmp(rv.VisibilityReason, ...
        {'InBand', 'OutOfBand', 'EdgeClipped'})));
end

function spectrum = makeSpectrum(plannedBw, plannedFreqOffset)
    spectrum = struct( ...
        'PlannedBandwidth',  plannedBw, ...
        'PlannedFreqOffset', plannedFreqOffset, ...
        'LowerBound',        plannedFreqOffset - plannedBw / 2, ...
        'UpperBound',        plannedFreqOffset + plannedBw / 2);
end

function rxConfig = makeRxConfig(entityID, observableRange)
    rxConfig = struct();
    rxConfig.EntityID = entityID;
    rxConfig.Observation = struct( ...
        'SampleRate',           observableRange(2) - observableRange(1), ...
        'CenterFrequency',      0, ...
        'RealCarrierFrequency', 2.4e9, ...
        'ObservableRange',      observableRange);
end
