function varargout = warning(obj, varargin)
% Shortcut to write log message of given level
% Inputs: see signature arguments and local validation.
% Outputs: see signature return values and contract fields.

% Copyright 2018-2022 The MathWorks Inc.


% Construct the message
level = csrd.runtime.logger.mlog.Level.WARNING;
msg = constructMessage(obj, level, varargin{:});

% Add the message to the log
if ~isempty(msg)
    obj.addMessage(msg);
end

% Send msg output if requested
if nargout
    varargout{1} = msg;
end