function msgText = convertExceptionText(mExceptionObj)
% Convert MException with stack trace to message text

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