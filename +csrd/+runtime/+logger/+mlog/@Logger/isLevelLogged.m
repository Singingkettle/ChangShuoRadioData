function tf = isLevelLogged(obj, level)
% Determines if the specified level is logged
% Inputs: see signature arguments and local validation.
% Outputs: see signature return values and contract fields.

% Copyright 2018-2022 The MathWorks Inc.


% Check arguments
arguments
    obj
    level (1,1) csrd.runtime.logger.mlog.Level
end

tf = level <= obj.FileThreshold || ...
    level <= obj.CommandWindowThreshold || ...
    level <= obj.MessageReceivedEventThreshold;