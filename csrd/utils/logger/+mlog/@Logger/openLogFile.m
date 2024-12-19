function openLogFile(obj)
% Open the log file for viewing

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