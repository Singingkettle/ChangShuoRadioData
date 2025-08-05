function tf = isLevelLogged(obj, level)
% Determines if the specified level is logged

% Copyright 2018-2022 The MathWorks Inc.


% Check arguments
arguments
    obj
    level (1,1) mlog.Level
end

tf = level <= obj.FileThreshold || ...
    level <= obj.CommandWindowThreshold || ...
    level <= obj.MessageReceivedEventThreshold;