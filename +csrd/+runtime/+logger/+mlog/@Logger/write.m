function varargout = write(obj, varargin)
% write a message to the log
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：提供 CSRD 生产链路中的 write 实现。
% Adds a new message to the Logger, with the specified message
% level and text
%
% Syntax:
%       logObj.write(Level, MessageText)
%       logObj.write(Level, MessageText, sprintf_args...)
%       logObj.write(MException)
%       logObj.write(Level, MException)
%       logObj.write(mlog.Message)
%       write(logObj,...)

% Copyright 2018-2022 The MathWorks Inc.


% Construct the message
msg = constructMessage(obj, varargin{:});

% Add the message to the log
if ~isempty(msg)
    obj.addMessage(msg);
end

% Send msg output if requested
if nargout
    varargout{1} = msg;
end