classdef SCFDMA < OFDM
    % This class is based on https://www.mathworks.com/help/comm/ug/scfdma-vs-ofdm.html
    
    properties (Nontunable)
        SubcarrierMappingInterval (1, 1) {mustBeReal, mustBePositive} = 1
    end
    
    methods (Access = protected)
        
        function [y, bw] = baseModulation(obj, x)
            
            x = obj.firstStageModulation(x);
            x = obj.ostbc(x);
            obj.NumSymbols = fix(size(x, 1) / obj.NumDataSubcarriers);
            x = x(1:obj.NumSymbols * obj.NumDataSubcarriers, :);
            x = reshape(x, [obj.NumDataSubcarriers, obj.NumSymbols, obj.NumTransmitAntennnas]);
            x = fft(x, obj.NumDataSubcarriers);
            x_ = zeros(obj.UsedSubCarr, obj.NumSymbols, obj.NumTransmitAntennnas);
            x_ (1:obj.SubcarrierMappingInterval:obj.NumDataSubcarriers * obj.SubcarrierMappingInterval, :, :) = x;
            
            obj.secondStageModulation.NumSymbols = obj.NumSymbols;
            y = obj.secondStageModulation(x_);
            
            bw = obj.Subcarrierspacing * obj.UsedSubCarr;
            obj.TimeDuration = size(y, 1) / obj.SampleRate;
            
        end
        
        function secondStageModulation = genSecondStageModulation(obj)
            p = obj.ModulationConfig.scfdma;
            
            NoUsedCarriers = p.FFTLength - ((obj.NumDataSubcarriers -1)*obj.SubcarrierMappingInterval + 1);
            NumGuardBandCarriers = [floor(NoUsedCarriers/2); floor(NoUsedCarriers/2)];

            secondStageModulation = comm.OFDMModulation( ...
                FFTLength = p.FFTLength, ...
                NumGuardBandCarriers = NumGuardBandCarriers, ...
                CyclicPrefixLength = p.CyclicPrefixLength, ...
                OversamplingFactor = p.OversamplingFactor, ...
                NumTransmitAntennas = obj.NumTransmitAntennnas);
            
            % Without pilot, the UsedSubCarr is equal NumDataSubcarriers
            obj.UsedSubCarr = p.FFTLength - sum(secondStageModulation.NumGuardBandCarriers);
            obj.SampleRate = obj.Subcarrierspacing * p.FFTLength;
        end
        
    end
    
end
