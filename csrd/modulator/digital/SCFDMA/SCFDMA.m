classdef SCFDMA < BaseModulator
    % This class is based on https://www.mathworks.com/help/comm/ug/scfdma-vs-ofdm.html
    
    properties (Nontunable)
        Subcarrierspacing (1, 1) {mustBeReal, mustBePositive} = 30e3
        % Transmit parameters
        NumTransmitAntennnas (1, 1) {mustBePositive, mustBeInteger, mustBeMember(NumTransmitAntennnas, [1, 2, 3, 4])} = 1
        SubcarrierMappingInterval (1, 1) {mustBeReal, mustBePositive} = 1
    end
    
    properties
        
        firstStageModulator
        ostbc
        secondStageModulator
        NumDataSubcarriers
        NumSymbols
        UsedSubCarr
    end
    
    methods (Access = protected)
        
        function [y, bw] = baseModulator(obj, x)
            
            x = obj.firstStageModulator(x);
            x = obj.ostbc(x);
            obj.NumSymbols = fix(size(x, 1) / obj.NumDataSubcarriers);
            x = x(1:obj.NumSymbols * obj.NumDataSubcarriers, :);
            x = reshape(x, [obj.NumDataSubcarriers, obj.NumSymbols, obj.NumTransmitAntennnas]);
            x = cat(1, x, ...
                zeros(obj.ModulatorConfig.ofdm.FFTLength - ...
                obj.NumDataSubcarriers, obj.NumSymbols, ...
                obj.NumTransmitAntennnas));
            x = fft(x(1:obj.NumDataSubcarriers, :), obj.NumDataSubcarriers);
            x_ = zeros(obj.ModulatorConfig.ofdm.FFTLength, obj.NumSymbols);
            x_ (1:obj.SubcarrierMappingInterval:obj.NumDataSubcarriers * obj.SubcarrierMappingInterval, :) = x;
            
            x = obj.secondStageModulator(x_);
            y = obj.sampler(x);
            
            obj.UsedSubCarr = obj.NumDataSubcarriers;
            bw = obj.Subcarrierspacing * obj.UsedSubCarr;
            obj.TimeDuration = size(y, 1) / obj.SampleRate;
            
        end
        
        function ostbc = genOSTBC(obj)
            
            if obj.NumTransmitAntennnas > 1
                
                if obj.NumTransmitAntennnas == 2
                    ostbc = comm.OSTBCEncoder( ...
                        NumTransmitAntennas = obj.NumTransmitAntennnas);
                else
                    ostbc = comm.OSTBCEncoder( ...
                        NumTransmitAntennas = obj.NumTransmitAntennnas, ...
                        SymbolRate = obj.ModulatorConfig.ostbcSymbolRate);
                end
                
            else
                ostbc = @(x)obj.placeHolder(x);
            end
            
        end
        
        function sampler = genSampler(obj)
            
            L = obj.SamplePerSymbol;
            M = 1;
            TW = 0.001;
            AStop = 70;
            h = designMultirateFIR(L, M, TW, AStop);
            sampler = @(x)resample(x, L, M, h);
            
        end
        
        function firstStageModulator = genFirstStageModulator(obj)
            
            if contains(lower(obj.ModulatorConfig.base.mode), 'psk')
                firstStageModulator = @(x)pskmod(x, ...
                    obj.ModulationOrder, ...
                    obj.ModulatorConfig.base.PhaseOffset, ...
                    obj.ModulatorConfig.base.SymbolOrder);
            elseif contains(lower(mode), 'qam')
                firstStageModulator = @(x)qammod(x, ...
                    obj.ModulationOrder, ...
                    'UnitAveragePower', true);
            else
                error('Not implemented %s modulator in OFDM', mode);
            end
            
        end
        
        function secondStageModulator = genSecondStageModulator(obj)
            p = obj.ModulatorConfig.ofdm;
            
            secondStageModulator = @(x)ofdmmod(x, ...
                p.FFTLength, ...
                p.CyclicPrefixLength, ...
                OversamplingFactor = p.OversamplingFactor);
            obj.SampleRate = obj.Subcarrierspacing * p.FFTLength;
            
        end
        
    end
    
    methods
        
        function modulatorHandle = genModulatorHandle(obj)
            
            obj.ostbc = obj.genOSTBC;
            obj.sampler = obj.genSampler;
            obj.firstStageModulator = obj.genFirstStageModulator;
            obj.secondStageModulator = obj.genSecondStageModulator;
            
            modulatorHandle = @(x)obj.baseModulator(x);
            obj.IsDigital = true;
            
        end
        
    end
    
end
