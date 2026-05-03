function addMessage(obj, msgObj)
% Adds a given message to the log
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：提供 CSRD 生产链路中的 addMessage 实现。

% Copyright 2018-2022 The MathWorks Inc.


% Check arguments
arguments
    obj (1,1) csrd.runtime.logger.mlog.Logger
    msgObj (1,1) csrd.runtime.logger.mlog.Message
end

% Get the next position in the circular MessageBuffer
obj.BufferIndex = obj.BufferIndex + 1;
if obj.BufferIndex > obj.BufferSize
    obj.BufferIndex = 1;
    obj.BufferIsWrapped = true;
end

% Add the message to the buffer
obj.MessageBuffer(obj.BufferIndex) = msgObj;

% Log to command window
if msgObj.Level <= obj.CommandWindowThreshold
    obj.writeToCommandWindow(msgObj);
end

% Write to file
if msgObj.Level <= obj.FileThreshold
    obj.writeToLogFile(msgObj);
end

% Send event notifications
obj.notify("MessageAdded", msgObj);
if msgObj.Level <= obj.MessageReceivedEventThreshold
    obj.notify("MessageReceived", msgObj);
end