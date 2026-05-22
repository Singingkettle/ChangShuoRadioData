classdef ThrowingChannelBlock < matlab.System
    %THROWINGCHANNELBLOCK Test-only channel block that always raises.
    %
    %   Used by regression tests to verify that scenario-skip exceptions
    %   propagate through ``csrd.factories.ChannelFactory`` and the
    %   ChangShuo private chain. Lives under ``+csrd/+test_support`` so
    %   the helper is co-located with the production code it instruments
    %   without polluting the runtime namespace.

    properties
        % Mode: which kind of error to raise.
        %   'throwSkip'    - raise RayTracing:NoValidPaths
        %   'throwGeneric' - raise CSRD:Test:GenericError
        Mode (1, :) char = 'throwSkip'
    end

    methods (Access = protected)

        function setupImpl(~, ~)
            % setupImpl - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
        end

        function out = stepImpl(obj, inputSignalStruct, varargin)
            % stepImpl - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            switch obj.Mode
                case 'throwSkip'
                    error('RayTracing:NoValidPaths', ...
                        'Stub: simulating a NoValidPaths failure.');
                case 'throwGeneric'
                    error('CSRD:Test:GenericError', ...
                        'Stub: simulating a generic transient failure.');
                otherwise
                    out = inputSignalStruct;
            end
        end

    end

end
