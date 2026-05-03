classdef Log < handle
% 中文说明：提供 CSRD 生产链路中的 Log 实现。

    properties (Access = private)
        Name = "logger" % Default logger name
        Instance % mlog instance
    end

    methods (Access = private)
        % Private constructor
        function obj = Log(name)
            % Log - Production declaration in CSRD.
            % 中文说明：Log 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.

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
            % 中文说明：getInstance 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.

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
