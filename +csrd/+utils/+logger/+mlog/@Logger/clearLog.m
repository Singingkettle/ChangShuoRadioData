function clearLog(obj)
% Clear the messages in the log and the log file

% Copyright 2018-2022 The MathWorks Inc.


% Clear the messages with the buffer index
obj.BufferIndex = 0;
obj.BufferIsWrapped = false;

% Close the log file
obj.fcloseLogFile();

% Attempt to delete the log file
if isfile(obj.LogFile)
    try %#ok<TRYNC>
        delete(obj.LogFile)
    end
end