classdef Log < handle

    properties (Access = private)
        Name = "logger" % Default logger name
        Instance % mlog instance
    end

    methods (Access = private)
        % Private constructor
        function obj = Log(name)

            if nargin > 0
                obj.Name = name;
            end

            % Add validation to ensure mlog package is available
            if ~exist('mlog.Logger', 'class')
                error('Log:DependencyError', 'mlog package is required but not found');
            end

            obj.Instance = mlog.Logger(obj.Name);
        end

    end

    methods (Static)

        function logger = getInstance(name)

            persistent globalInstance

            if isempty(globalInstance)

                if nargin > 0
                    globalInstance = csrd.utils.logger.Log(name);
                else
                    globalInstance = csrd.utils.logger.Log();
                end

            elseif nargin > 0

                if ~strcmp(globalInstance.Instance.Name, name)
                    globalInstance = csrd.utils.logger.Log(name);
                end

            end

            logger = globalInstance.Instance;
        end

    end

end
