function msgText = convertExceptionText(mExceptionObj)
% Convert MException with stack trace to message text
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：提供 CSRD 生产链路中的 convertExceptionText 实现。

% Copyright 2018-2022 The MathWorks Inc.


% Check arguments
arguments
    mExceptionObj (1,1) MException
end

% Convert message to string
msgText = string(mExceptionObj.message);

% Include the stack
if ~isempty(mExceptionObj.stack)
    msgInputs = [{mExceptionObj.stack.name};{mExceptionObj.stack.line}];
    stackText = sprintf('\n\t\t> %s (line %d)',msgInputs{:});
    msgText = msgText + stackText;
end