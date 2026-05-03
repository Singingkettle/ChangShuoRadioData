function tf = isLevelLogged(obj, level)
% Determines if the specified level is logged
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：提供 CSRD 生产链路中的 isLevelLogged 实现。

% Copyright 2018-2022 The MathWorks Inc.


% Check arguments
arguments
    obj
    level (1,1) csrd.runtime.logger.mlog.Level
end

tf = level <= obj.FileThreshold || ...
    level <= obj.CommandWindowThreshold || ...
    level <= obj.MessageReceivedEventThreshold;