classdef SCFDMA < blocks.physical.modulate.digital.OFDM.OFDM
    % SCFDMA - Single Carrier Frequency Division Multiple Access Modulator
    %
    % This class implements SC-FDMA modulation, extending the OFDM modulator
    % with additional DFT spreading. Based on MATLAB's SC-FDMA implementation:
    % https://www.mathworks.com/help/comm/ug/scfdma-vs-ofdm.html
    %
    % Properties:
    %   SubcarrierMappingInterval - Interval between mapped subcarriers (default: 1)
    %
    % Inherited Properties (from OFDM):
    %   NumDataSubcarriers - Number of data subcarriers
    %   NumSymbols - Number of OFDM symbols
    %   firstStageModulator - Primary modulation (PSK/QAM)
    %   secondStageModulator - OFDM modulation stage
    %   ostbc - Space-time block coding
    %
    % ModulatorConfig Parameters:
    %   scfdma.FFTLength - FFT size for SC-FDMA
    %   scfdma.CyclicPrefixLength - CP length
    %   scfdma.Subcarrierspacing - Spacing between subcarriers
    %   scfdma.NumDataSubcarriers - Number of data subcarriers
    %   base.mode - Modulation mode ('psk' or 'qam')
    %   base.PhaseOffset - PSK phase offset
    %   base.SymbolOrder - Symbol mapping order ('bin' or 'gray')

    properties (Nontunable)
        SubcarrierMappingInterval (1, 1) {mustBeReal, mustBePositive} = 1
        % SubcarrierMappingInterval - Spacing between mapped subcarriers
        % Determines the mapping pattern in frequency domain
        % Default: 1 (localized mapping)
    end

    methods (Access = protected)
        function [y, bw] = baseModulator(obj, x)
            % baseModulator - Implements SC-FDMA modulation
            %
            % Steps:
            % 1. First stage modulation (PSK/QAM)
            % 2. OSTBC encoding (if multiple antennas)
            % 3. DFT spreading
            % 4. Subcarrier mapping
            % 5. IFFT and CP addition
            %
            % Inputs:
            %   x - Input symbols
            %
            % Outputs:
            %   y - Modulated signal
            %   bw - Bandwidth [lower, upper] frequency bounds

            % First stage modulation and OSTBC
            x = obj.firstStageModulator(x);
            x = obj.ostbc(x);

            % Reshape input for DFT spreading
            obj.NumSymbols = fix(size(x, 1) / obj.ModulatorConfig.scfdma.NumDataSubcarriers);
            x = x(1:obj.NumSymbols * obj.ModulatorConfig.scfdma.NumDataSubcarriers, :);
            x = reshape(x, [obj.ModulatorConfig.scfdma.NumDataSubcarriers, obj.NumSymbols, obj.NumTransmitAntennas]);

            % Zero padding for FFT
            x = cat(1, x, zeros(obj.ModulatorConfig.scfdma.FFTLength - obj.ModulatorConfig.scfdma.NumDataSubcarriers, obj.NumSymbols, obj.NumTransmitAntennas));

            % DFT spreading
            x = fft(x(1:obj.ModulatorConfig.scfdma.NumDataSubcarriers, :, :), obj.ModulatorConfig.scfdma.NumDataSubcarriers);

            % Subcarrier mapping with guard bands
            x_ = zeros(obj.ModulatorConfig.scfdma.FFTLength, obj.NumSymbols, obj.NumTransmitAntennas, 'like', x);
            leftGuardBand = floor((obj.ModulatorConfig.scfdma.FFTLength - obj.NumDataSubcarriers) / 2);
            rightGuardBand = obj.ModulatorConfig.scfdma.FFTLength - obj.NumDataSubcarriers - leftGuardBand;
            x_(leftGuardBand + 1:obj.ModulatorConfig.scfdma.SubcarrierMappingInterval:leftGuardBand + obj.ModulatorConfig.scfdma.NumDataSubcarriers * obj.ModulatorConfig.scfdma.SubcarrierMappingInterval, :, :) = x;

            % Release modulator if locked
            if isLocked(obj.secondStageModulator)
                release(obj.secondStageModulator);
            end

            % OFDM modulation
            obj.secondStageModulator.NumSymbols = obj.NumSymbols;
            y = obj.secondStageModulator(x_);

            % Calculate bandwidth
            bw = zeros(1, 2);
            bw(1) = -obj.ModulatorConfig.scfdma.Subcarrierspacing * (obj.ModulatorConfig.scfdma.FFTLength / 2 - leftGuardBand);
            bw(2) = obj.ModulatorConfig.scfdma.Subcarrierspacing * (obj.ModulatorConfig.scfdma.FFTLength / 2 - rightGuardBand);
        end

        function secondStageModulator = genSecondStageModulator(obj)
            % genSecondStageModulator - Generate OFDM modulator for second stage
            %
            % Creates comm.OFDMModulator object with SC-FDMA parameters
            % Updates NumDataSubcarriers and SampleRate based on configuration

            p = obj.ModulatorConfig.scfdma;
            secondStageModulator = comm.OFDMModulator( ...
                FFTLength = p.FFTLength, ...
                NumGuardBandCarriers = [0; 0], ...
                CyclicPrefixLength = p.CyclicPrefixLength, ...
                NumTransmitAntennas = obj.NumTransmitAntennas);

            % Update system parameters
            obj.NumDataSubcarriers = (obj.ModulatorConfig.scfdma.NumDataSubcarriers -1) * obj.ModulatorConfig.scfdma.SubcarrierMappingInterval + 1;
            obj.SampleRate = obj.ModulatorConfig.scfdma.Subcarrierspacing * p.FFTLength;
        end
    end

    methods
        function modulatorHandle = genModulatorHandle(obj)
            % genModulatorHandle - Configure and return SC-FDMA modulator
            %
            % Sets up modulation parameters:
            % 1. OSTBC configuration for MIMO
            % 2. Base modulation (PSK/QAM) parameters
            % 3. SC-FDMA specific parameters
            %
            % Returns:
            %   modulatorHandle - Function handle to baseModulator

            obj.IsDigital = true;

            % Configure OSTBC for multiple antennas
            if obj.NumTransmitAntennas > 2
                if ~isfield(obj.ModulatorConfig, 'ostbcSymbolRate')
                    obj.ModulatorConfig.ostbcSymbolRate = randi([0, 1]) * 0.25 + 0.5;
                end
            end
            obj.ostbc = obj.genOSTBC;

            % Generate random configuration if not provided
            if ~isfield(obj.ModulatorConfig, 'base')
                % Configure base modulation
                obj.ModulatorConfig.base.mode = randsample(["psk", "qam"], 1);
                if strcmpi(obj.ModulatorConfig.base.mode, "psk")
                    obj.ModulatorConfig.base.PhaseOffset = rand(1) * 2 * pi;
                    obj.ModulatorConfig.base.SymbolOrder = randsample(["bin", "gray"], 1);
                end

                % Configure SC-FDMA parameters
                obj.ModulatorConfig.scfdma.FFTLength = randsample([128, 256, 512, 1024, 2048], 1);
                obj.ModulatorConfig.scfdma.CyclicPrefixLength = randi([12, 32], 1);
                obj.ModulatorConfig.scfdma.Subcarrierspacing = randsample([2, 4], 1) * 1e2;
                obj.ModulatorConfig.scfdma.SubcarrierMappingInterval = randi([1, 2], 1);
                
                % Calculate maximum number of data subcarriers
                maxNumDataSubcarriers = fix((obj.ModulatorConfig.scfdma.FFTLength - 1) / obj.ModulatorConfig.scfdma.SubcarrierMappingInterval) + 1;
                % 48 is a number randomly selected
                obj.ModulatorConfig.scfdma.NumDataSubcarriers = randi([48, maxNumDataSubcarriers], 1);
            end

            % Initialize modulators
            obj.firstStageModulator = obj.genFirstStageModulator;
            obj.secondStageModulator = obj.genSecondStageModulator;
            modulatorHandle = @(x)obj.baseModulator(x);
        end
    end
end
