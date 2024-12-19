classdef FSK < blocks.physical.modulate.BaseModulator

    properties (Access = private)
        freq_sep
    end

    properties
        pureModulator

    end

    methods (Access = protected)

        function [y, bw] = baseModulator(obj, x)
            y = obj.pureModulator(x);

            if isprop(obj, 'freq_sep')
                bw = obj.freq_sep * obj.ModulatorOrder;
            else
                bw = obw(y, obj.SampleRate);
            end

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)

            obj.IsDigital = true;
            obj.NumTransmitAntennas = 1;
            max_freq_sep = obj.SampleRate / (obj.ModulatorOrder - 1);
            obj.freq_sep = round((rand(1) * 0.1 + 0.4) * max_freq_sep / 100) * 100;

            if ~isfield(obj.ModulatorConfig, 'SymbolOrder')
                obj.ModulatorConfig.SymbolOrder = randsample(["bin", "gray"], 1);
            end

            obj.pureModulator = @(x)fskmod(x, ...
                obj.ModulatorOrder, ...
                obj.freq_sep, ...
                obj.SamplePerSymbol, ...
                obj.SampleRate, ...
                'discont', ...
                obj.ModulatorConfig.SymbolOrder);
            modulatorHandle = @(x)obj.baseModulator(x);
        end

    end

end
