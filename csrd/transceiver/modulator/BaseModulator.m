classdef BaseModulator < matlab.System
    % https://www.mathworks.com/help/comm/ug/design-a-deep-neural-network-with-simulated-data-to-detect-wlan-router-impersonation.html

    properties

        ModulationOrder {mustBePositive, mustBeReal} = 2

        TimeDuration (1, 1) {mustBePositive, mustBeReal} = 1
        SampleRate (1, 1) {mustBePositive, mustBeReal} = 200e3

        % Modulate parameters
        ModulatorConfig struct

        % Transmit parameters
        NumTransmitAntennnas (1, 1) {mustBePositive, mustBeInteger, mustBeMember(NumTransmitAntennnas, [1, 2, 3, 4])} = 1

        % Digital Sign
        IsDigital (1, 1) logical = true

    end

    properties (Access = protected)
        SamplePerFrame
    end

    properties (Access = private)
        % Modulate Handle
        modulator
    end

    methods

        function obj = BaseModulator(varargin)

            setProperties(obj, nargin, varargin{:});

        end

        function y = placeHolder(obj, x)
            y = x;
        end

    end

    methods (Abstract)
        % In the sub class, this method should be defined
        modulatorHandle = genModulatorHandle(obj)

    end

    methods (Access = protected)

        % Validate the inputs to the object
        function validateInputsImpl(~, x)

            if ~isnumeric(x)
                error("Input must be numeric");
            end

        end

        function setupImpl(obj)
            obj.SamplePerFrame = round(obj.SampleRate * obj.TimeDuration);
            obj.modulator = obj.genModulatorHandle;

        end

        function y = stepImpl(obj, x)

            y = obj.modulator(x);

        end

    end

end
