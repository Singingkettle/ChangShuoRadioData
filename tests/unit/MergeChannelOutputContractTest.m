classdef MergeChannelOutputContractTest < matlab.unittest.TestCase
    % MergeChannelOutputContractTest
    %
    % Phase 1 / H14 contract for ChannelFactory.mergeChannelOutput
    % (whitelist-based merge):
    %
    %   * Upstream fields that are NOT in CHANNEL_OWNED_FIELDS must be
    %     preserved verbatim.
    %   * The channel block ONLY owns 'Signal' plus a documented list of
    %     channel-specific physics fields.
    %   * New fields produced by the channel block are added when not
    %     already defined upstream (forward compat).
    %   * A non-struct channelBlockOutput is treated as a raw Signal
    %     payload.
    %
    % Driver: instantiates a ChannelFactory and calls mergeChannelOutput
    % directly; no step() execution required.

    properties
        Factory
    end

    methods (TestMethodSetup)
        function createFactory(testCase)
            cfg.ChannelModels.AWGN = struct('handle', 'csrd.blocks.physical.channel.AWGN');
            testCase.Factory = csrd.factories.ChannelFactory('Config', cfg);
        end
    end

    methods (Test)

        function preservesUpstreamMetadataWhenChannelReturnsSignalStruct(testCase)
            upstream = struct( ...
                'ID', 1, 'TxId', 'Tx1', 'BurstId', 'Tx1.B3', ...
                'SegmentId', 'Tx1.B3.S0', 'SubBurstId', 'Tx1.B3.S0.SB0', ...
                'ModulatorConfig', struct('ModulationType', 'QPSK'), ...
                'Header', struct('Runtime', struct('Frame', 1)), ...
                'Planned', struct('Bandwidth', 1e6), ...
                'Signal', complex(ones(8,1), 0), ...
                'SampleRate', 20e6 ...
            );
            channelOut = struct( ...
                'Signal', complex(zeros(8,1), 1), ...
                'PathLoss', 42.5 ...
            );
            merged = testCase.Factory.mergeChannelOutput(upstream, channelOut);

            % Upstream-owned fields preserved.
            for f = {'ID', 'TxId', 'BurstId', 'SegmentId', 'SubBurstId', ...
                    'ModulatorConfig', 'Header', 'Planned', 'SampleRate'}
                fn = f{1};
                testCase.verifyTrue(isfield(merged, fn), ...
                    sprintf('Field %s must be preserved by the merge.', fn));
                testCase.verifyEqual(merged.(fn), upstream.(fn), ...
                    sprintf('Field %s must equal the upstream value.', fn));
            end
            % Channel-owned fields overwritten / added.
            testCase.verifyEqual(merged.Signal, channelOut.Signal, ...
                'Signal must be overwritten by the channel block output.');
            testCase.verifyEqual(merged.PathLoss, 42.5, ...
                'PathLoss must come from the channel block output.');
        end

        function injectsNewChannelMetadata(testCase)
            upstream = struct('ID', 9, 'TxId', 'Tx9', 'Signal', complex(ones(4,1), 0));
            channelOut = struct( ...
                'Signal', complex(zeros(4,1), 1), ...
                'ChannelInfo', struct('Type', 'Rayleigh'), ...
                'NumValidPaths', 3 ...
            );
            merged = testCase.Factory.mergeChannelOutput(upstream, channelOut);
            testCase.verifyEqual(merged.ID, 9, 'Upstream ID preserved.');
            testCase.verifyEqual(merged.ChannelInfo.Type, 'Rayleigh', ...
                'New channel metadata must be attached.');
            testCase.verifyEqual(merged.NumValidPaths, 3, ...
                'New channel metadata must be attached.');
        end

        function preservesUpstreamForUnknownNonChannelFields(testCase)
            % A field that is not in the whitelist and IS already present
            % upstream must keep the upstream value, even if the channel
            % block (incorrectly) tries to overwrite it. This is the
            % central data-loss defence vs the previous implementation.
            upstream = struct('ID', 11, 'TxId', 'Tx11', ...
                'ModulatorConfig', struct('ModulationType', 'QPSK'), ...
                'Signal', complex(ones(2,1), 0));
            channelOut = struct('Signal', complex(zeros(2,1), 1), ...
                'ModulatorConfig', struct('ModulationType', 'BPSK'));
            merged = testCase.Factory.mergeChannelOutput(upstream, channelOut);
            testCase.verifyEqual(merged.ModulatorConfig.ModulationType, 'QPSK', ...
                ['Upstream ModulatorConfig must NOT be overwritten by ' ...
                 'a channel block, since ModulatorConfig is not in the ' ...
                 'channel-owned whitelist.']);
        end

        function nonStructChannelOutputBecomesSignalPayload(testCase)
            upstream = struct('ID', 7, 'TxId', 'Tx7', 'Signal', []);
            payload = complex(ones(16, 1), 0);
            merged = testCase.Factory.mergeChannelOutput(upstream, payload);
            testCase.verifyEqual(merged.ID, 7, 'Upstream ID preserved.');
            testCase.verifyEqual(merged.TxId, 'Tx7', 'Upstream TxId preserved.');
            testCase.verifyEqual(merged.Signal, payload, ...
                'Non-struct payload must be attached as Signal.');
        end

        function whitelistOverwritesEvenWhenUpstreamHadValue(testCase)
            % Channel-owned fields must overwrite upstream if both define
            % them. The classic example is PathLoss: the upstream may
            % carry the analytical FSPL value while the channel block
            % returns a measured/simulated value.
            upstream = struct('ID', 1, 'PathLoss', 50, 'Signal', []);
            channelOut = struct('Signal', complex(ones(2,1)), 'PathLoss', 70);
            merged = testCase.Factory.mergeChannelOutput(upstream, channelOut);
            testCase.verifyEqual(merged.PathLoss, 70, ...
                'PathLoss is in the whitelist; channel value must win.');
        end

    end

end
