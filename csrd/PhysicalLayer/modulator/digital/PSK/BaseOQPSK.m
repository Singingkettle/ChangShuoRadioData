classdef (StrictDefaults)BaseOQPSK < comm.internal.OQPSKBase
    %OQPSKModulator Joint OQPSK modulation and pulse filtering
    %   MOD = comm.OQPSKModulator creates a modulator object, MOD, that
    %   jointly: (i) modulates the input signal using the offset quadrature
    %   phase shift keying (OQPSK) method, and (ii) pulse shapes the waveform
    %   via filtering.
    %
    %   MOD = comm.OQPSKModulator(DEMOD) creates an OQPSK modulator
    %   object, MOD, with symmetric configuration to the OQPSK demodulator
    %   object DEMOD.
    %
    %   MOD = comm.OQPSKModulator(Name,Value) creates an OQPSK modulator
    %   object, MOD, with the specified property Name set to the specified
    %   Value. You can specify additional name-value pair arguments in any
    %   order as (Name1, Value1, ..., NameN, ValueN).
    %
    %   MOD = comm.OQPSKModulator(PHASE,Name,Value) creates an OQPSK modulator
    %   object, MOD, with the PhaseOffset property set to PHASE and other
    %   specified property Names set to the specified Values.
    %
    %   Step method syntax:
    %
    %   WAVEFORM = step(MOD,X) modulates input bits or integers, X, with the
    %   OQPSK modulator object, MOD, and returns baseband modulated output,
    %   WAVEFORM. The output waveform is pulse-shaped according to the
    %   configuration properties PulseShape and SamplesPerSymbol.
    %
    %   System objects may be called directly like a function instead of using
    %   the step method. For example, y = step(obj, x) and y = obj(x) are
    %   equivalent.
    %
    %   OQPSKModulator methods:
    %
    %   step          - Perform OQPSK modulation and filtering
    %   release       - Allow property value and input characteristics changes
    %   clone         - Create OQPSKModulator object with same property values
    %   isLocked      - Locked status (logical)
    %   reset         - Reset states of OQPSKModulator object
    %   constellation - Ideal signal constellation
    %
    %   OQPSKModulator properties:
    %
    %   PhaseOffset           - Phase of zeroth point of constellation
    %   BitInput              - Assume bit inputs
    %   SymbolMapping         - Constellation encoding
    %   PulseShape            - Pulse shape type
    %   RolloffFactor         - Rolloff factor for raised cosine pulse shapes
    %   FilterSpanInSymbols   - Filter span (in symbols) for raised cosine pulse shapes
    %   FilterNumerator       - Custom FIR filter coefficients
    %   SamplesPerSymbol      - Samples per symbol
    %   OutputDataType        - Data type of output
    %
    %   % Example #1: Generate a half-sine OQPSK waveform, as in IEEE
    %   %             802.15.4 / ZigBee at 2.4 GHz
    %   bits = randi([0, 1], 800, 1);     % message signal in bits
    %   sps = 12;
    %   rate = 4e6;
    %   modulator = comm.OQPSKModulator('BitInput', true, 'PulseShape', 'Half sine', ...
    %                                   'SamplesPerSymbol', sps, 'SymbolMapping', [3 2 0 1]);
    %   waveform = modulator(bits);     % joint oqpsk modulation and filtering
    %   % visualize 10 pulses of the OQPSK waveform
    %   timeScope = timescope('YLimits', [-1.1 1.1], ...
    %                         'SampleRate', rate, ...
    %                         'TimeSpanSource','property', ...
    %                         'TimeSpan', 10*sps/rate);
    %   timeScope(waveform);
    %
    %   % Example #2: Generate a normal raised cosine OQPSK waveform, as in
    %   %             IEEE 802.15.4 / ZigBee at 780 MHz
    %   symbols = randi([0, 3], 800/2, 1);     % message signal in integers
    %   sps = 12;
    %   rate = 4e6;
    %   modulator = comm.OQPSKModulator('PulseShape', 'Normal raised cosine', 'RolloffFactor', 0.8, ...
    %                                   'SamplesPerSymbol', sps, 'SymbolMapping', [3 2 0 1]);
    %   waveform = modulator(symbols);     % joint oqpsk modulation and filtering
    %   % visualize 50 pulses of the OQPSK waveform
    %   eyediagram(waveform, 2*sps)
    %
    %   % Example #3: End-to-end modules system, including OQPSK transmitter & receiver
    %
    %   % Transmitter:
    %   sps = 12;
    %   bits = randi([0, 1], 800, 1);     % message signal
    %   modulator = comm.OQPSKModulator('BitInput', true, 'SamplesPerSymbol', sps, 'PulseShape', 'Root raised cosine');
    %   oqpskWaveform = modulator(bits);
    %
    %   % Channel:
    %   snr = 0;
    %   received = awgn(oqpskWaveform, snr);
    %
    %   % Receiver
    %   demodulator = comm.OQPSKDemodulator(modulator);
    %   demodulated = demodulator(received);
    %
    %   % Compute BER:
    %   delay = (1+modulator.BitInput)*modulator.FilterSpanInSymbols;
    %   [~, ber] = biterr(bits(1:end-delay), demodulated(delay+1:end));
    %   fprintf('Bit error rate: %f\n', ber);
    %
    %   See also comm.OQPSKDemodulator, comm.OQPSKModulator.
    
    % Copyright 2009-2023 The MathWorks, Inc.
    
    %#codegen
    
    properties (Nontunable)
        %BitInput Bit input
        % Specify whether the input is bits or integers. The default is false.
        % When this property is set to false, the input values are integer
        % representations of two-bit input segments and range from 0 to 3. When
        % this property is set to true, the input must be a binary vector of even
        % length.
        BitInput (1, 1) logical = false;
        
        %OutputDataType Data type of output
        %   Specify the output data type as one of 'double' | 'single'. The
        %   default is 'double'.
        OutputDataType = 'double';
        NumTransmitAntennas = 1;
        ostbc
    end
    
    methods
        % Constructor
        function obj = BaseOQPSK(varargin)
            
            if nargin == 1 && isa(varargin{1}, 'comm.OQPSKDemodulator')
                demod = varargin{1};
                obj.PhaseOffset = demod.PhaseOffset;
                obj.SymbolMapping = demod.SymbolMapping;
                obj.BitInput = demod.BitOutput;
                obj.PulseShape = demod.PulseShape;
                obj.SamplesPerSymbol = demod.SamplesPerSymbol;
                obj.NumTransmitAntennas = demod.NumTransmitAntennas;
                
                if ~strcmp(demod.OutputDataType, 'uint8')
                    % double or single
                    obj.OutputDataType = demod.OutputDataType;
                else
                    % most efficient implementation
                    obj.OutputDataType = 'single';
                end
                
                if strcmp(demod.PulseShape, 'Custom')
                    obj.FilterNumerator = demod.FilterNumerator;
                    
                elseif any(strcmp(demod.PulseShape, {'Normal raised cosine', 'Root raised cosine'}))
                    obj.RolloffFactor = demod.RolloffFactor;
                    obj.FilterSpanInSymbols = demod.FilterSpanInSymbols;
                end
                
            else
                setProperties(obj, nargin, varargin{:}, 'PhaseOffset');
            end
            
        end
        
        function set.OutputDataType(obj, value)
            
            if strcmpi(value, 'Custom')
                coder.internal.warning('comm:system:OQPSKModulator:InvalidOutType', 'double', value);
                obj.OutputDataType = 'double';
            else
                value = validatestring(value, {'double', 'single'}, 'set.OutputDataType');
                obj.OutputDataType = value;
            end
            
        end
        
    end
    
    methods (Access = protected)
        
        function validateInputsImpl(~, x)
            coder.internal.errorIf(isfi(x), ...
                'comm:system:OQPSKDemodulator:FiInput');
            
            coder.internal.errorIf(size(x, 2) > 1, ...
                'dspshared:system:multChanNotSupport');
        end
        
        function resetImpl(obj)
            
            if coder.internal.is_defined(obj.pFilter)
                reset(obj.pFilter);
            end
            
            obj.pPrevHalfSymbol = zeros(obj.SamplesPerSymbol / 2, obj.NumTransmitAntennas, obj.OutputDataType);
        end
        
        function setupImpl(obj)
            obj.pPrevHalfSymbol = zeros(obj.SamplesPerSymbol / 2, obj.NumTransmitAntennas, obj.OutputDataType);
            
            % pMapping does input to phases mapping
            if strcmp(obj.SymbolMapping, 'Binary')
                obj.pMapping = [0 1 2 3];
            elseif ~strcmp(obj.SymbolMapping, 'Gray') % Custom
                % Offline, one step execution of find indices location
                
                % find [b a; c d] to phases mapping.
                obj.pMapping = zeros(1, 4);
                
                for idx = 1:4
                    
                    for symbol = 0:3
                        
                        if obj.SymbolMapping(idx) == symbol
                            obj.pMapping(symbol + 1) = idx;
                        end
                        
                    end
                    
                end
                
                % else private property not used for Gray
            end
            
            prepareFilter(obj);
        end
        
        function prepareFilter(obj)
            sps = obj.SamplesPerSymbol;
            
            switch obj.PulseShape
                
                case 'Half sine'
                    halfSinePulse = sin(0:pi / sps:pi);
                    obj.pFilter = dsp.FIRInterpolator('Numerator', halfSinePulse, ...
                        'InterpolationFactor', sps);
                    
                case 'Normal raised cosine'
                    obj.pFilter = comm.RaisedCosineTransmitFilter('Shape', 'Normal', ...
                        'RolloffFactor', obj.RolloffFactor, 'FilterSpanInSymbols', obj.FilterSpanInSymbols, ...
                        'OutputSamplesPerSymbol', sps, 'Gain', sqrt(sps / 2));
                    
                case 'Root raised cosine'
                    obj.pFilter = comm.RaisedCosineTransmitFilter('Shape', 'Square root', ...
                        'RolloffFactor', obj.RolloffFactor, 'FilterSpanInSymbols', obj.FilterSpanInSymbols, ...
                        'OutputSamplesPerSymbol', sps, 'Gain', sqrt(sps / 2));
                    
                case 'Rectangular'
                    obj.pFilter = dsp.FIRInterpolator('Numerator', ones(1, sps) / sps, ...
                        'InterpolationFactor', sps);
                    
                otherwise % Custom
                    obj.pFilter = dsp.FIRInterpolator('Numerator', obj.FilterNumerator, ...
                        'InterpolationFactor', sps);
            end
            
        end
        
        function oqpskWaveform = stepImpl(obj, in)
            
            coder.internal.errorIf(obj.BitInput && mod(length(in), 2), ...
                'comm:system:bitInVecInWrongLen', length(in), 2);
            
            if strcmp(obj.OutputDataType, 'double')
                input = double(in);
            else
                input = single(in);
            end
            
            if isempty(in)
                oqpskWaveform = complex(zeros(size(input), 'like', input));
                return;
            end
            
            if ~obj.BitInput % INTEGER INPUT
                
                coder.internal.errorIf(any(input > 3) || any(input < 0) || any(floor(input) ~= input) || ~isreal(input), ...
                    'comm:system:OQPSKModulator:InvalidInput');
                
                if strcmp(obj.SymbolMapping, 'Gray')
                    bits = int2bit(input, 2);
                else
                    phases = obj.pMapping(1 + input)';
                end
                
            else % BIT INPUT
                
                coder.internal.errorIf(any(input > 1) || any(input < 0) || any(floor(input) ~= input) || ~isreal(input), ...
                    'comm:system:OQPSKModulator:InvalidInput');
                
                if strcmp(obj.SymbolMapping, 'Gray')
                    bits = input;
                else
                    phases = obj.pMapping(1 + bit2int(input, 2))';
                end
                
            end
            
            % O-QPSK modulation (part 1)
            % split two 2 parallel streams, also map [0, 1] to [-1, 1]
            if strcmp(obj.SymbolMapping, 'Gray')
                % mapping:
                %  1 | 0        01 | 00
                % ---+---   => ----+----
                %  3 | 2        11 | 10
                symbols = bits * 2 - 1;
                re = -symbols(2:2:end);
                im = -symbols(1:2:end);
                
            else % Binary or custom symbol mapping
                
                if strcmp(obj.SymbolMapping, 'Binary')
                    rotated = exp(1i * pi / 2 * phases + 1i * pi / 4);
                else % Custom
                    rotated = exp(1i * pi / 2 * (phases - 1) + 1i * pi / 4);
                end
                
                % unit amplitude:
                re = sign(real(rotated));
                im = sign(imag(rotated));
            end
            
            % Support MIMO
            x = obj.ostbc(complex(re, im));
            re = real(x);
            im = imag(x);
            
            % Filtering
            filtered = obj.pFilter([re im]);
            filteredRe = filtered(:, 1:obj.NumTransmitAntennas);
            filteredIm = filtered(:, obj.NumTransmitAntennas + 1:2 * obj.NumTransmitAntennas);
            
            % O-QPSK modulation (part 2)
            % delay Q component:
            filteredAligned = [obj.pPrevHalfSymbol; filteredIm(1:end - obj.SamplesPerSymbol / 2, :)];
            obj.pPrevHalfSymbol = filteredIm(end - obj.SamplesPerSymbol / 2 + 1:end, :);
            oqpskWaveform = complex(filteredRe, filteredAligned);
            
            oqpskWaveform = oqpskWaveform * exp(1i * obj.PhaseOffset);
        end
        
        function flag = isInputSizeMutableImpl(~, ~)
            flag = true;
        end
        
    end
    
    methods (Static, Hidden)
        
        function a = getAlternateBlock
            a = 'commdigbbndpm3/OQPSK Modulator Baseband';
        end
        
    end
    
    methods (Static, Hidden, Access = protected)
        
        function groups = getPropertyGroupsImpl()
            
            modulationSection = matlab.system.display.Section( ...
                'PropertyList', {'PhaseOffset', 'SymbolMapping', 'BitInput'});
            
            modulationGroup = matlab.system.display.SectionGroup( ...
                'Title', getString(message('comm:system:OQPSKModulator:ModulatorTitle')), ...
                'Sections', modulationSection);
            modulationGroup.IncludeInShortDisplay = true;
            
            [filteringGroup, outTypeGroup] = getPropertyGroupsImpl@comm.internal.OQPSKBase;
            
            groups = [modulationGroup filteringGroup outTypeGroup];
        end
        
    end
    
end
