function msg = constructMessage(obj, argA, argB, varargin)
% Constructs a mlog.Message object, with the same class as the existing
% Logger

% Copyright 2018-2024 The MathWorks Inc.


% Default new message to empty
msg = obj.MessageBuffer([]);

% Check input format
if nargin == 3 && ( ischar(argB) || isStringScalar(argB) )
    %logObj.write(Level, MessageText)

    if obj.isLevelLogged(argA)
        msg = obj.MessageConstructor();
        msg.Level = argA;
        msg.Text = argB;
    end

elseif nargin > 3
    %logObj.write(Level, MessageText, sprintf_args...)

    if obj.isLevelLogged(argA)
        msg = obj.MessageConstructor();
        msg.Level = argA;
        msg.Text = sprintf(argB, varargin{:});
    end

elseif nargin == 2 && isa(argA, "mlog.Message")
    %logObj.write(mlog.Message)

    if obj.isLevelLogged(argA.Level)
        msg = argA;
    end

elseif nargin == 2 && isa(argA,'MException')
    %logObj.write(MException)

    if obj.isLevelLogged(mlog.Level.ERROR)
        msg = obj.MessageConstructor();
        msg.Level = mlog.Level.ERROR;
        msg.Text = obj.convertExceptionText(argA);
    end

elseif nargin == 3 && isa(argB,'MException')
    %logObj.write(Level, MException)

    if obj.isLevelLogged(argA)
        msg = obj.MessageConstructor();
        msg.Level = argA;
        msg.Text = obj.convertExceptionText(argB);
    end

else
    error("mlog:invalidWriteInputs",...
        "Invalid inputs to write method.")
end