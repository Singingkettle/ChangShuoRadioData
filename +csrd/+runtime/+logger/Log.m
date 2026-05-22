classdef Log < handle
% Log - CSRD MATLAB declaration.

    properties (Access = private)
        Name = "logger" % Default logger name
        Instance % mlog instance
    end

    methods (Access = private)
        % Private constructor
        function obj = Log(name)
            % Log - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.

            if nargin > 0
                obj.Name = name;
            end

            % Add validation to ensure mlog package is available
            if ~exist('csrd.runtime.logger.mlog.Logger', 'class')
                error('Log:DependencyError', 'mlog package is required but not found');
            end

            obj.Instance = csrd.runtime.logger.mlog.Logger(obj.Name);
        end

    end

    methods (Static)

        function logger = getInstance(name)
            % getInstance - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.

            persistent globalInstance

            if isempty(globalInstance)

                if nargin > 0
                    globalInstance = csrd.runtime.logger.Log(name);
                else
                    globalInstance = csrd.runtime.logger.Log();
                end

            elseif nargin > 0

                if ~strcmp(globalInstance.Instance.Name, name)
                    globalInstance = csrd.runtime.logger.Log(name);
                end

            end

            logger = globalInstance.Instance;
        end

    end

end
