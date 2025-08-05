classdef DVBSAPSK < csrd.blocks.physical.modulate.digital.APSK.APSK
    % DVBSAPSK - Digital Video Broadcasting Satellite APSK Modulator
    %
    % This class implements DVB-S2/S2X/SH (Digital Video Broadcasting Satellite)
    % compliant APSK modulation as a subclass of the APSK modulator. DVB-S APSK
    % provides improved spectral efficiency and power efficiency for satellite
    % communication systems compared to conventional PSK modulation.
    %
    % DVB-S APSK uses amplitude and phase shift keying with constellation points
    % arranged in concentric circles to optimize the peak-to-average power ratio
    % (PAPR) and improve performance in non-linear satellite amplifiers. This
    % implementation supports DVB-S2, DVB-S2X, and DVB-SH standards.
    %
    % Key Features:
    %   - DVB-S2/S2X/SH standard compliance
    %   - Multiple modulation orders (8, 16, 32, 64, 128, 256-APSK)
    %   - Configurable code identifiers and frame lengths
    %   - Unit average power normalization for satellite links
    %   - OSTBC encoding support for MIMO transmission
    %   - Pulse shaping with raised cosine filters
    %
    % Standards Reference:
    %   DVB-S APSK modulation parameters specification:
    %   https://www.mathworks.com/help/comm/ref/dvbsapskmod.html
    %
    % Syntax:
    %   dvbsModulator = DVBSAPSK()
    %   dvbsModulator = DVBSAPSK('PropertyName', PropertyValue, ...)
    %   modulatedSignal = dvbsModulator.step(inputData)
    %
    % Properties (Inherited from APSK):
    %   ModulatorOrder - Number of constellation points (8, 16, 32, 64, 128, 256)
    %   SamplePerSymbol - Number of samples per symbol for pulse shaping
    %   SampleRate - Sample rate of the modulated signal in Hz
    %   NumTransmitAntennas - Number of transmit antennas for MIMO
    %   ModulatorConfig - Configuration structure for DVB-S parameters
    %     .stdSuffix - DVB standard suffix ('s2', 's2x', 'sh')
    %     .codeIDF - Code identifier (e.g., '2/3', '3/4', '4/5', '5/6')
    %     .frameLength - Frame length ('normal' or 'short')
    %     .beta - Roll-off factor for pulse shaping (0 to 1)
    %     .span - Filter span in symbols
    %
    % Methods:
    %   baseModulator - Core DVB-S APSK modulation implementation
    %   genModulatorHandle - Generate configured modulator function handle
    %
    % Example:
    %   % Create DVB-S2 16-APSK modulator for satellite communication
    %   dvbsMod = csrd.blocks.physical.modulate.digital.APSK.DVBSAPSK();
    %   dvbsMod.ModulatorOrder = 16;
    %   dvbsMod.SamplePerSymbol = 4;
    %   dvbsMod.SampleRate = 1e6;
    %
    %   % Configure for DVB-S2 with specific code rate
    %   dvbsMod.ModulatorConfig.stdSuffix = 's2';
    %   dvbsMod.ModulatorConfig.codeIDF = '3/4';
    %   dvbsMod.ModulatorConfig.frameLength = 'normal';
    %
    %   % Create input data structure
    %   inputData.data = randi([0 1], 4000, 1); % Random bits
    %
    %   % Modulate the signal
    %   modulatedSignal = dvbsMod.step(inputData);
    %
    % See also: csrd.blocks.physical.modulate.digital.APSK.APSK,
    %           csrd.blocks.physical.modulate.BaseModulator, dvbsapskmod

    methods (Access = protected)

        function [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            % baseModulator - Core DVB-S APSK modulation implementation
            %
            % This method performs DVB-S compliant APSK modulation with the configured
            % standard suffix, code identifier, and frame length parameters, followed
            % by OSTBC encoding for MIMO and pulse shaping for bandwidth efficiency.
            %
            % Syntax:
            %   [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            %
            % Input Arguments:
            %   inputSymbols - Input symbol sequence to be modulated
            %                  Type: numeric array (integers 0 to ModulatorOrder-1)
            %
            % Output Arguments:
            %   modulatedSignal - DVB-S APSK modulated and pulse-shaped signal
            %                     Type: complex array
            %   bandWidth - Occupied bandwidth of the modulated signal in Hz
            %               Type: positive scalar or vector (for MIMO)
            %
            % Processing Steps:
            %   1. Apply DVB-S APSK modulation with configured parameters
            %   2. Apply OSTBC encoding for multiple antennas
            %   3. Apply pulse shaping filter with upsampling
            %   4. Calculate occupied bandwidth using obw function
            %
            % DVB-S APSK Features:
            %   - Standard-compliant constellation arrangements
            %   - Optimized for satellite channel characteristics
            %   - Unit average power normalization
            %   - Support for multiple code rates and frame lengths
            %
            % Example:
            %   symbols = [0 1 2 3 4 5]; % 16-APSK symbols
            %   [signal, bw] = obj.baseModulator(symbols);

            % Apply DVB-S APSK modulation with configured parameters
            modulatedSymbols = dvbsapskmod(inputSymbols, obj.ModulatorOrder, ...
                obj.ModulatorConfig.stdSuffix, ...
                obj.ModulatorConfig.codeIDF, ...
                obj.ModulatorConfig.frameLength, ...
                'UnitAveragePower', true);

            % Apply OSTBC encoding for MIMO transmission
            encodedSymbols = obj.ostbc(modulatedSymbols);

            % Apply pulse shaping with upsampling for bandwidth efficiency
            modulatedSignal = filter(obj.filterCoeffs, 1, upsample(encodedSymbols, obj.SamplePerSymbol));

            % Calculate occupied bandwidth
            bandWidth = obw(modulatedSignal, obj.SampleRate);

            % For MIMO systems, take maximum bandwidth across antennas
            if obj.NumTransmitAntennas > 1
                bandWidth = max(bandWidth);
            end

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % genModulatorHandle - Generate configured DVB-S APSK modulator function handle
            %
            % This method configures the DVB-S APSK modulator with valid parameters
            % according to DVB standards if not specified and returns a function handle
            % for the complete modulation process. The configuration follows DVB-S2/S2X/SH
            % specifications for valid parameter combinations.
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Output Arguments:
            %   modulatorHandle - Function handle for DVB-S APSK modulation
            %                     Type: function_handle
            %                     Usage: [signal, bw] = modulatorHandle(symbols)
            %
            % Configuration Parameters:
            %   The method automatically configures valid parameter combinations:
            %   - stdSuffix: DVB standard ('s2', 's2x', 'sh') based on modulation order
            %   - frameLength: Frame length ('normal', 'short') per standard constraints
            %   - codeIDF: Code identifier validated against DVB specifications
            %   - beta: Roll-off factor for raised cosine filter (random 0 to 1)
            %   - span: Filter span in symbols (random even number 4-16)
            %
            % DVB Standard Constraints:
            %   - DVB-S2: Supports 16, 32-APSK with specific code rates
            %   - DVB-S2X: Supports 8, 16, 32, 64, 128, 256-APSK
            %   - DVB-SH: Supports lower modulation orders with specific code rates
            %   - Frame length dependencies vary by standard and modulation order
            %
            % Note about MATLAB Documentation:
            %   The official MATLAB documentation for dvbsapskmod contains
            %   inconsistencies with the actual implementation. This code follows
            %   the official MATLAB implementation behavior for parameter validation.
            %
            % Example:
            %   dvbsMod = csrd.blocks.physical.modulate.digital.APSK.DVBSAPSK();
            %   dvbsMod.ModulatorOrder = 32; % 32-APSK
            %   modHandle = dvbsMod.genModulatorHandle();
            %   [modSignal, bandwidth] = modHandle([0 1 2 3 4 5]);

            % Configure DVB-S APSK parameters if not provided
            % Note: Parameter validation follows MATLAB implementation, not documentation
            if ~isfield(obj.ModulatorConfig, "stdSuffix")

                % Select valid DVB standard based on modulation order
                if obj.ModulatorOrder <= 16
                    obj.ModulatorConfig.stdSuffix = randsample(["s2", "s2x", "sh"], 1);
                elseif obj.ModulatorOrder <= 32
                    obj.ModulatorConfig.stdSuffix = randsample(["s2x", "s2"], 1);
                else
                    % Higher orders only supported in DVB-S2X
                    obj.ModulatorConfig.stdSuffix = "s2x";
                end

                % Initial frame length selection
                obj.ModulatorConfig.frameLength = randsample(["normal", "short"], 1);

                % Apply DVB-S2X specific constraints for frame length
                if strcmpi(obj.ModulatorConfig.stdSuffix, "s2x")

                    if ((obj.ModulatorOrder == 16) || (obj.ModulatorOrder == 32))
                        % 16 and 32-APSK in S2X require short frames
                        obj.ModulatorConfig.frameLength = "short";
                    else
                        % Other orders in S2X use normal frames
                        obj.ModulatorConfig.frameLength = "normal";
                    end

                end

                % Select valid code identifier based on standard and frame length
                obj.ModulatorConfig.codeIDF = randomSelectCodeIdentifier(obj.ModulatorOrder, ...
                    obj.ModulatorConfig.stdSuffix, obj.ModulatorConfig.frameLength);

                % Configure pulse shaping parameters
                obj.ModulatorConfig.beta = rand(1); % Random roll-off factor [0,1]
                % Product of SamplePerSymbol and span must be even for DVB-S
                obj.ModulatorConfig.span = randi([2, 8]) * 2; % Random even span [4,16]
            end

            % Set modulator type flag
            obj.IsDigital = true;

            % Generate pulse shaping filter coefficients
            obj.filterCoeffs = obj.genFilterCoeffs;

            % Generate OSTBC encoder for MIMO support
            obj.ostbc = obj.genOSTBC;

            % Create function handle for modulation
            modulatorHandle = @(inputSymbols)obj.baseModulator(inputSymbols);

        end

    end

end

function codeIdentifier = randomSelectCodeIdentifier(modulationOrder, standardSuffix, frameLength)
    % randomSelectCodeIdentifier - Select valid code identifier for DVB-S APSK
    %
    % This function selects a random valid code identifier based on the DVB
    % standard suffix, modulation order, and frame length according to the
    % DVB-S2/S2X/SH specifications.
    %
    % Syntax:
    %   codeIdentifier = randomSelectCodeIdentifier(order, stdSuffix, frameLength)
    %
    % Input Arguments:
    %   modulationOrder - APSK modulation order (8, 16, 32, 64, 128, 256)
    %   standardSuffix - DVB standard ('s2', 's2x', 'sh')
    %   frameLength - Frame length ('normal', 'short')
    %
    % Output Arguments:
    %   codeIdentifier - Valid code identifier string (e.g., '2/3', '3/4')

    if strcmpi(standardSuffix, 'sh')
        % DVB-SH valid code identifiers
        validSHCodeIdentifiers = {'1/5', '2/9', '1/4', '2/7', '1/3', '2/5', '1/2', '2/3'};
        codeIdentifier = randsample(validSHCodeIdentifiers, 1);

    elseif strcmpi(standardSuffix, 's2')
        % DVB-S2 standard code identifiers
        modulationIndex = modulationOrder / 16; % Index for 16-APSK (1) or 32-APSK (2)

        % Code identifiers for DVB-S2 normal frame length
        % First cell: 16-APSK, Second cell: 32-APSK
        validS2NormalFrameIds = {{'2/3', '3/4', '4/5', '5/6', '8/9', '9/10'}; ...
                                      {'3/4', '4/5', '5/6', '8/9', '9/10'}};

        % Code identifiers for DVB-S2 short frame length
        % First cell: 16-APSK, Second cell: 32-APSK
        validS2ShortFrameIds = {{'2/3', '3/4', '4/5', '5/6', '8/9'}; ...
                                     {'3/4', '4/5', '5/6', '8/9'}};

        if strcmpi(frameLength, 'short')
            codeIdentifier = randsample(validS2ShortFrameIds{modulationIndex}, 1);
        else
            codeIdentifier = randsample(validS2NormalFrameIds{modulationIndex}, 1);
        end

    else % DVB-S2X standard

        % Calculate indices for DVB-S2X code identifier arrays
        normalFrameIndex = log2(double(modulationOrder)) - 2; % For 8,16,32,64,128,256-APSK
        isModulation16or32 = (modulationOrder == 16) || (modulationOrder == 32);

        if isModulation16or32
            shortFrameIndex = modulationOrder / 16; % 1 for 16-APSK, 2 for 32-APSK
        else
            shortFrameIndex = cast(1, 'like', modulationOrder);
        end

        % Code identifiers for DVB-S2X normal frame length
        % Indexed by: 8, 16, 32, 64, 128, 256-APSK
        validS2XNormalFrameIds = {{'100/180', '104/180'}; % 8-APSK
                                   {'2/3', '3/4', '4/5', '5/6', '8/9', '9/10', '90/180', '96/180', ...
             '100/180', '26/45', '3/5', '18/30', '28/45', '23/36', '20/30', ...
             '25/36', '13/18', '140/180', '154/180'}; % 16-APSK
        {'3/4', '4/5', '5/6', '8/9', '9/10', '2/3', '128/180', '132/180', '140/180'}; % 32-APSK
        {'128/180', '132/180', '7/9', '4/5', '5/6'}; % 64-APSK
        {'135/180', '140/180'}; % 128-APSK
        {'116/180', '20/30', '124/180', '128/180', '22/30', '135/180'}}; % 256-APSK

        % Code identifiers for DVB-S2X short frame length
        % Only for 16 & 32-APSK
        validS2XShortFrameIds = {{'2/3', '3/4', '4/5', '5/6', '8/9', '7/15', '8/15', '26/45', ...
                                      '3/5', '32/45'}; % 16-APSK
        {'3/4', '4/5', '5/6', '8/9', '2/3', '32/45'}}; % 32-APSK

        if strcmpi(frameLength, 'short')
            codeIdentifier = randsample(validS2XShortFrameIds{shortFrameIndex}, 1);
        else
            codeIdentifier = randsample(validS2XNormalFrameIds{normalFrameIndex}, 1);
        end

    end

    % Extract string from cell array
    codeIdentifier = codeIdentifier{1};

end
