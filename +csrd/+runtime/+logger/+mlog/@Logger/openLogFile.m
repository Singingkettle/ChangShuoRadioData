function openLogFile(obj)
% Open the log file for viewing
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：提供 CSRD 生产链路中的 openLogFile 实现。

% Copyright 2018-2022 The MathWorks Inc.


% Does it exist?
if isfile(obj.LogFile)

    try
        if ispc
            winopen(obj.LogFile);
        else
            open(obj.LogFile);
        end
    catch err
        warning("mlog:openLogFail",...
            "The log file could not be opened: %s", err.message);
    end

else

    warning("mlog:openLogFileNotFound",...
        "The log file does not exist: %s", obj.LogFile);

end %if isfile(obj.LogFile)