function varargout = message(obj, varargin)
% Shortcut to write log message of given level
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：提供 CSRD 生产链路中的 message 实现。

% Copyright 2018-2022 The MathWorks Inc.


% Construct the message
level = csrd.runtime.logger.mlog.Level.MESSAGE;
msg = constructMessage(obj, level, varargin{:});

% Add the message to the log
if ~isempty(msg)
    obj.addMessage(msg);
end

% Send msg output if requested
if nargout
    varargout{1} = msg;
end