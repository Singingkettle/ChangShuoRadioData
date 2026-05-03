function updateBufferSize(obj, newSize)
% Updates the buffer size
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：提供 CSRD 生产链路中的 updateBufferSize 实现。

% Copyright 2018-2022 The MathWorks Inc.


% Grab the messages in order
msgObj = obj.Messages;

% Crop if buffer is reduced
if numel(msgObj) > newSize
    msgObj(1:end-newSize) = [];
end

% Adjust message buffer size
obj.MessageBuffer = repmat(obj.MessageBuffer(1), newSize, 1);

% Place messages in buffer
numMsg = numel(msgObj);
obj.MessageBuffer(1:numMsg) = msgObj;

% Update counters
obj.BufferIsWrapped = false;
obj.BufferIndex = numMsg;