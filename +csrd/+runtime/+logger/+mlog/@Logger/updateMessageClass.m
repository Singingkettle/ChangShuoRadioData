function updateMessageClass(obj)
% Updates the class of messages if MessageConstructor changes
% Inputs: see signature arguments and local validation.
% Outputs: see signature return values and contract fields.

% Copyright 2018-2022 The MathWorks Inc.


defaultMessage = obj.MessageConstructor();
if ~matches(class(defaultMessage), class(obj.MessageBuffer))
    sz = size(obj.MessageBuffer);
    obj.MessageBuffer = repmat(defaultMessage, sz);
    obj.BufferIndex = 0;
    obj.BufferIsWrapped = false;
end