function varargout = write(obj, varargin)
% write a message to the log
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