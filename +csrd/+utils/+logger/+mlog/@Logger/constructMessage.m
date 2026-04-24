function msg = constructMessage(obj, argA, argB, varargin)
% Constructs a csrd.utils.logger.mlog.Message object, with the same class as the existing
% Logger

% Copyright 2018-2024 The MathWorks Inc.


% Default new message to empty
msg = obj.MessageBuffer([]);

% Get caller information from call stack
callerInfo = getCallerInfo();

% Check input format
if nargin == 3 && ( ischar(argB) || isStringScalar(argB) )
    %logObj.write(Level, MessageText)

    if obj.isLevelLogged(argA)
        msg = obj.MessageConstructor();
        msg.Level = argA;
        msg.Text = argB;
        msg.Caller = callerInfo;
    end

elseif nargin > 3
    %logObj.write(Level, MessageText, sprintf_args...)

    if obj.isLevelLogged(argA)
        msg = obj.MessageConstructor();
        msg.Level = argA;
        msg.Text = sprintf(argB, varargin{:});
        msg.Caller = callerInfo;
    end

elseif nargin == 2 && isa(argA, "csrd.utils.logger.mlog.Message")
    %logObj.write(csrd.utils.logger.mlog.Message)

    if obj.isLevelLogged(argA.Level)
        msg = argA;
        % Keep existing caller info if already set, otherwise use current
        if strlength(msg.Caller) == 0
            msg.Caller = callerInfo;
        end
    end

elseif nargin == 2 && isa(argA,'MException')
    %logObj.write(MException)

    if obj.isLevelLogged(csrd.utils.logger.mlog.Level.ERROR)
        msg = obj.MessageConstructor();
        msg.Level = csrd.utils.logger.mlog.Level.ERROR;
        msg.Text = obj.convertExceptionText(argA);
        msg.Caller = callerInfo;
    end

elseif nargin == 3 && isa(argB,'MException')
    %logObj.write(Level, MException)

    if obj.isLevelLogged(argA)
        msg = obj.MessageConstructor();
        msg.Level = argA;
        msg.Text = obj.convertExceptionText(argB);
        msg.Caller = callerInfo;
    end

else
    error("mlog:invalidWriteInputs",...
        "Invalid inputs to write method.")
end

end

function callerInfo = getCallerInfo()
% Get the caller's full qualified name and line number from the call stack
% Skip internal logger functions to find the actual caller
% Returns format like: csrd.core.ChangShuo.setupImpl:45

    callerInfo = "";
    
    try
        % Get the full call stack
        stack = dbstack('-completenames');
        
        % Skip frames that are part of the logger package
        loggerPackagePatterns = {'+mlog', '@Logger', 'logger.Log', 'GlobalLogManager'};
        
        for i = 1:length(stack)
            isLoggerInternal = false;
            
            for j = 1:length(loggerPackagePatterns)
                if contains(stack(i).file, loggerPackagePatterns{j})
                    isLoggerInternal = true;
                    break;
                end
            end
            
            if ~isLoggerInternal && ~isempty(stack(i).name)
                % Found the actual caller - extract full qualified name
                fullPath = extractFullQualifiedName(stack(i).file, stack(i).name);
                callerInfo = sprintf('%s:%d', fullPath, stack(i).line);
                break;
            end
        end
        
    catch
        % If anything goes wrong, just return empty string
        callerInfo = "";
    end
    
end

function fullName = extractFullQualifiedName(filePath, funcName)
% Extract full qualified name from file path
% e.g., C:\...\+csrd\+core\@ChangShuo\setupImpl.m -> csrd.core.ChangShuo.setupImpl

    fullName = funcName; %#ok<NASGU> - default fallback value
    
    try
        % Normalize path separators
        filePath = strrep(filePath, '\', '/');
        
        % Split path into parts
        pathParts = strsplit(filePath, '/');
        
        % Find package (+) and class (@) components
        qualifiedParts = {};
        
        for i = 1:length(pathParts)
            part = pathParts{i};
            
            if startsWith(part, '+')
                % Package folder: +csrd -> csrd
                qualifiedParts{end+1} = part(2:end); %#ok<AGROW>
            elseif startsWith(part, '@')
                % Class folder: @ChangShuo -> ChangShuo
                qualifiedParts{end+1} = part(2:end); %#ok<AGROW>
            end
        end
        
        % Add the function/method name (from stack, handles nested functions)
        if ~isempty(qualifiedParts)
            % Check if funcName already contains class name (for methods)
            % e.g., funcName might be "ChangShuo.setupImpl" or just "setupImpl"
            if contains(funcName, '.')
                % Function name already has class prefix, use as-is
                fullName = strjoin([qualifiedParts, {funcName}], '.');
            else
                % Add function name
                qualifiedParts{end+1} = funcName;
                fullName = strjoin(qualifiedParts, '.');
            end
        else
            % No package/class structure, just use function name
            fullName = funcName;
        end
        
    catch
        % If parsing fails, return the original function name
        fullName = funcName;
    end
    
end