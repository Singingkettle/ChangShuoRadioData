classdef BaseModulator < matlab.System
    % BaseModulator - Base class for modulators in the ChangShuoRadioData project
    %
    % Description:
    %   This class implements the base functionality for all modulator types,
    %   supporting both digital and analog modulation schemes with MIMO capabilities.
    %
    % Usage:
    %   This is an abstract base class. Create a concrete subclass by implementing
    %   the genModulatorHandle method.
    %
    % Example:
    %   % Create a custom modulator
    %   myMod = MyModulator('ModulatorOrder', 4, 'SampleRate', 1e6);
    %   output = myMod.step(input);
    %
    % Properties:
    %   ModulatorOrder       - Modulation order (e.g., 2 for BPSK, 4 for QPSK)
    %   SampleRate          - Sampling rate in Hz
    %   ModulatorConfig     - Configuration struct for modulator-specific settings
    %   NumTransmitAntennas - Number of transmit antennas (1-4)
    %   SamplePerSymbol     - Samples per symbol (for digital modulation)
    %
    % Protected Properties:
    %   modulator  - Handle to the modulation function
    %   IsDigital - Flag indicating digital/analog modulation type
    %
    % See also: matlab.System, comm.OSTBCEncoder

    properties
        % ModulatorOrder - Modulation order (e.g., 2 for BPSK, 4 for QPSK)
        % Type: positive real number, Default: 1
        ModulatorOrder {mustBePositive, mustBeReal} = 1

        % SampleRate - Sampling rate in Hz
        % Type: positive real scalar, Default: 200e3
        SampleRate (1, 1) {mustBePositive, mustBeReal} = 200e3

        % ModulatorConfig - Configuration struct for modulator-specific settings
        % Type: struct, Default: empty struct
        ModulatorConfig struct = struct()

        % NumTransmitAntennas - Number of transmit antennas
        % Type: positive integer in range [1,4], Default: 1
        NumTransmitAntennas (1, 1) {mustBePositive, mustBeInteger, mustBeMember(NumTransmitAntennas, [1, 2, 3, 4])} = 1

        % SamplePerSymbol - Samples per symbol (for digital modulation)
        % For analog modulation, this is just a placeholder
        % Type: positive real scalar, Default: 1
        SamplePerSymbol (1, 1) {mustBePositive, mustBeReal} = 1
    end

    properties (Access = protected)
        % modulator - Handle to the modulation function
        modulator

        % IsDigital - Flag indicating digital/analog modulation type
        % Type: logical, Default: true
        IsDigital = true
    end

    methods

        function obj = BaseModulator(varargin)
            % BaseModulator - Constructor method for the BaseModulator class
            %
            % Inputs:
            %   varargin - Name-value pairs for object properties
            %
            % Returns:
            %   obj - Initialized BaseModulator object

            setProperties(obj, nargin, varargin{:});
        end

        function ostbc = genOSTBC(obj)
            % genOSTBC - Generate Orthogonal Space-Time Block Coding encoder
            %
            % Returns:
            %   ostbc - Function handle to OSTBC encoder

            if obj.NumTransmitAntennas > 1

                if obj.NumTransmitAntennas == 2
                    ostbc = comm.OSTBCEncoder( ...
                        NumTransmitAntennas = obj.NumTransmitAntennas);
                else
                    ostbc = comm.OSTBCEncoder( ...
                        NumTransmitAntennas = obj.NumTransmitAntennas, ...
                        SymbolRate = obj.ModulatorConfig.ostbcSymbolRate);
                end

                ostbc = @(x)genOSTBCWithX(ostbc, x);
            else
                ostbc = @(x)obj.placeHolder(x);
            end

        end

        function y = placeHolder(obj, x)
            % placeHolder - A placeholder method for single antenna systems
            %
            % Inputs:
            %   x - Input data
            %
            % Returns:
            %   y - Same as input (no transformation)

            y = x;
        end

    end

    methods (Abstract)
        % genModulatorHandle - Abstract method to generate the modulate handle
        %
        % Returns:
        %   modulatorHandle - Function handle for modulation operation

        modulatorHandle = genModulatorHandle(obj)

    end

    methods (Access = protected)

        function validateInputsImpl(~, x)
            % validateInputsImpl - Validates the inputs to the object
            %
            % Inputs:
            %   x - Input to validate, must be a struct

            if ~isstruct(x)
                error("Input must be struct");
            end

        end

        function setupImpl(obj)
            % setupImpl - Performs setup operations for the object
            %
            % Sets up OSTBC symbol rate and initializes the modulator handle

            if obj.NumTransmitAntennas > 2

                if ~isfield(obj.ModulatorConfig, 'ostbcSymbolRate')
                    obj.ModulatorConfig.ostbcSymbolRate = randi([0, 1]) * 0.25 + 0.5;
                end

            else
                obj.ModulatorConfig.ostbcSymbolRate = 1;
            end

            obj.modulator = obj.genModulatorHandle;
        end

        function out = stepImpl(obj, x)
            % stepImpl - Main modulation processing step
            %
            % Inputs:
            %   x - Struct containing:
            %     - data: Input data to be modulated (bit array)
            %     - SymbolRate: Symbol rate (optional)
            %     - messageLength: Length of message (optional)
            %
            % Returns:
            %   out - Struct containing:
            %     - data: Modulated signal
            %     - BandWidth: Signal bandwidth [min max]
            %     - SamplePerSymbol: Samples per symbol
            %     - ModulatorOrder: Modulation order
            %     - IsDigital: Digital/analog flag
            %     - NumTransmitAntennas: Number of TX antennas
            %     - ModulatorConfig: Configuration parameters
            %     - SampleRate: Sample rate (Hz)
            %     - TimeDuration: Signal duration (s)
            %     - SamplePerFrame: Total samples in frame

            if sum(obj.ModulatorOrder) ~= 1
                n = log2(sum(obj.ModulatorOrder)); % Number of bits per symbol
            else
                n = 1;
            end

            % Ensure the length of the data is a multiple of n bits
            dataLength = size(x.data, 1);
            remainder = mod(dataLength, n);

            if remainder ~= 0
                x.data = x.data(1:end - remainder, :); % Discard the final bits
            end

            % When the modulator is a multi-carrier modulation, ensure that the input data length
            % is greater than or equal to the minimum number of subcarriers * bits per symbol
            if isfield(obj.ModulatorConfig, 'base')

                if isfield(obj.ModulatorConfig, 'ofdm')
                    min_num_bits = obj.NumDataSubcarriers * n * 2;
                elseif isfield(obj.ModulatorConfig, 'scfdma')
                    min_num_bits = obj.ModulatorConfig.scfdma.NumDataSubcarriers * n * 2;
                elseif isfield(obj.ModulatorConfig, 'otfs')
                    min_num_bits = obj.ModulatorConfig.otfs.DelayLength * n * 2;
                else
                    min_num_bits = 0;
                end

                if length(x.data) < min_num_bits
                    % Copy x.data and truncate to ensure length equals min_num_bits
                    repeated_data = repmat(x.data, ceil(min_num_bits / length(x.data)), 1);
                    x.data = repeated_data(1:min_num_bits, :);
                    % Random permutation by row
                    x.data = x.data(randperm(size(x.data, 1)), :);
                end

            end

            % Convert bits to integer
            if obj.ModulatorOrder > 1
                x.data = bit2int(x.data, n);
            end

            [y, bw] = obj.modulator(x.data);

            if isscalar(bw)
                bw = [-bw / 2, bw / 2];
            end

            if ~isfield(obj.ModulatorConfig, 'base')
                bw(1) = fix(bw(1));
                bw(2) = fix(bw(2));
            end

            out.data = y;
            out.BandWidth = bw;

            if isfield(obj.ModulatorConfig, 'base')
                out.SamplePerSymbol = 1;
            else
                out.SamplePerSymbol = obj.SamplePerSymbol;
            end

            out.ModulatorOrder = obj.ModulatorOrder;
            out.IsDigital = obj.IsDigital;
            out.NumTransmitAntennas = obj.NumTransmitAntennas;
            out.ModulatorConfig = obj.ModulatorConfig;

            % The obj.SampleRate are redefined in
            % OFDM, SCDMA and OTFS
            out.SampleRate = obj.SampleRate;
            out.TimeDuration = size(y, 1) / obj.SampleRate;
            out.SamplePerFrame = size(y, 1);

        end

    end

end

function y = genOSTBCWithX(ostbc, x)
    % genOSTBCWithX - Apply OSTBC encoding to input data
    %
    % Inputs:
    %   ostbc - OSTBC encoder object with properties:
    %     - SymbolRate: Rate of the OSTBC encoder (fraction)
    %   x - Input data matrix to be encoded
    %
    % Returns:
    %   y - OSTBC encoded data matrix

    rr = floor(ostbc.SymbolRate * 8);
    valid_len = floor(size(x, 1) / rr);
    valid_len = valid_len * rr;
    y = ostbc(x(1:valid_len, :));

end
