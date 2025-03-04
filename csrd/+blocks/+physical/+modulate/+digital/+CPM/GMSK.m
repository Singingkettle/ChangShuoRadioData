classdef GMSK < blocks.physical.modulate.digital.FSK.FSK

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % Initialize digital modulation
            obj.IsDigital = true;
            obj.NumTransmitAntennas = 1;

            % Set default modulator configuration if not provided
            if ~isfield(obj.ModulatorConfig, 'BandwidthTimeProduct')
                % BT typically ranges from 0.2 to 0.5
                % Lower BT means better spectral efficiency but more ISI
                obj.ModulatorConfig.BandwidthTimeProduct = rand(1) * 0.3 + 0.2;
                obj.ModulatorConfig.PulseLength = randi([4, 10], 1);
                obj.ModulatorConfig.SymbolPrehistory = randsample([-1, 1], 1);
                obj.ModulatorConfig.InitialPhaseOffset = rand(1) * 2 * pi;
            end

            % Create GMSK modulator
            obj.pureModulator = comm.GMSKModulator( ...
                BitInput = true, ...
                BandwidthTimeProduct = obj.ModulatorConfig.BandwidthTimeProduct, ...
                PulseLength = obj.ModulatorConfig.PulseLength, ...
                SymbolPrehistory = obj.ModulatorConfig.SymbolPrehistory, ...
                InitialPhaseOffset = obj.ModulatorConfig.InitialPhaseOffset, ...
                SamplesPerSymbol = obj.SamplePerSymbol);
            modulatorHandle = @(x)obj.baseModulator(x);
        end

    end

end
