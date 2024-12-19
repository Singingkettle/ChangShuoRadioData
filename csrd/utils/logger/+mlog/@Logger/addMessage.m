function addMessage(obj, msgObj)
% Adds a given message to the log

% Copyright 2018-2022 The MathWorks Inc.


% Check arguments
arguments
    obj (1,1) mlog.Logger
    msgObj (1,1) mlog.Message
end

% Get the next position in the circular MessageBuffer
obj.BufferIndex = obj.BufferIndex + 1;
if obj.BufferIndex > obj.BufferSize
    obj.BufferIndex = 1;
    obj.BufferIsWrapped = true;
end

% Add the message to the buffer
obj.MessageBuffer(obj.BufferIndex) = msgObj;

% Write to file
if msgObj.Level <= obj.FileThreshold
    obj.writeToLogFile(msgObj);
end

% Log to command window
if msgObj.Level <= obj.CommandWindowThreshold
    obj.writeToCommandWindow(msgObj);
end

% Send event notifications
obj.notify("MessageAdded", msgObj);
if msgObj.Level <= obj.MessageReceivedEventThreshold
    obj.notify("MessageReceived", msgObj);
end