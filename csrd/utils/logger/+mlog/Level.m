classdef Level < uint8
    %LEVEL Enumeration of log levels
    %   This class enumerates log message threshholds
    %
    % Syntax:
    %           mlog.Level.<MEMBER>
    %
    % Caution: Use the text form to indicate message levels in code. Do not
    % rely on the numeric enumerations, as new levels may be added or
    % inserted.
    
    %   Copyright 2018-2022 The MathWorks Inc.
    
    
    %% Enumerations
    enumeration
        
        % No messages logged at all
        NONE (0)
        
        % Fatal errors are logged
        FATAL (1)
        
        % Critical errors and above are logged
        CRITICAL (2)
        
        % Only error level messages and above are logged
        ERROR (3)
        
        % Only warning messages and above are logged
        WARNING (4)
        
        % Informational messages are logged, plus all the above
        INFO (5)
        
        % Messages to the user are logged, plus all of the above
        MESSAGE (6)
        
        % Debugging info messages are logged, plus all of the above
        DEBUG (7)

        % Detailed debugging info messages are logged, plus all of the above
        DETAIL (8)

        % Trace info messages are logged, plus all of the above
        TRACE (9)

    end %enumeration
    
end % classdef