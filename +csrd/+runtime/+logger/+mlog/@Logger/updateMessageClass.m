function updateMessageClass(obj)
% Updates the class of messages if MessageConstructor changes
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：提供 CSRD 生产链路中的 updateMessageClass 实现。

% Copyright 2018-2022 The MathWorks Inc.


defaultMessage = obj.MessageConstructor();
if ~matches(class(defaultMessage), class(obj.MessageBuffer))
    sz = size(obj.MessageBuffer);
    obj.MessageBuffer = repmat(defaultMessage, sz);
    obj.BufferIndex = 0;
    obj.BufferIsWrapped = false;
end