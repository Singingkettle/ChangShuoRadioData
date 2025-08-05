function writeToLogFile(obj, msgObj)
    % Writes a message to the log file

    % Copyright 2018-2024 The MathWorks Inc.

    % Validate inputs
    arguments
        obj
        msgObj (1, 1) mlog.Message
    end

    %% Check if we need a new log file

    if obj.RotationPeriod == "none" && strlength(obj.LogFile)
        % Legacy behavior - file is specified directly

        % No action

    else

        % Get the current time
        curTime = datetime("now", "TimeZone", "local");

        % Is a log file rotation needed?
        if ~(strlength(obj.LogFile)) || (curTime > obj.NextRotation) || ...
                ~isSameFolder(fileparts(obj.LogFile), obj.LogFolder)

            % Name part
            namePart = matlab.lang.makeValidName(obj.Name, 'ReplacementStyle', 'delete');

            % Date Part
            if obj.RotationPeriod == "none"
                dateSuffix = "";
            else
                dateSuffix = string(datetime(curTime, 'Format', obj.RotationPeriod.DateFormat));
            end

            obj.NextRotation = obj.RotationPeriod.getNextPeriod(curTime);

            % Formulate file path
            if strlength(dateSuffix)
                fileName = namePart + "_" + dateSuffix + ".log";
            else
                fileName = namePart + ".log";
            end

            obj.LogFile = fullfile(obj.LogFolder, fileName);

        end

    end %if obj.RotationPeriod =="none" && strlength(obj.LogFile)

    %% Open the log file for writing
    if verLessThan('matlab', '24.1') %#ok<VERLESSMATLAB>
        allOpenFiles = fopen('all');
    else
        allOpenFiles = openedFiles();
    end

    if ~ismember(obj.FileID, allOpenFiles)

        % Make the log folder if needed
        if ~isfolder(obj.LogFolder)
            [status, message] = mkdir(obj.LogFolder);

            if ~status
                [~, fileName, fileExt] = fileparts(obj.LogFile);
                newLogFile = fullfile(tempdir, fileName + fileExt);
                warning("mlog:unableCreateLogFolder", ...
                    "Unable to create log folder: %s\n" + ...
                    "Defaulting to temp directory: %s\n" + ...
                    "Message: %s", ...
                    obj.LogFolder, newLogFile, message);
                obj.LogFolder = tempdir;
                obj.LogFile = newLogFile;
            end

        end

        % Open the log file for writing
        obj.fopenLogFile("a");

    end

    %% Attempt to write the message
    try
        fprintf(obj.FileID, '%s\r\n', msgObj.createLogFileMessage(obj.Name));
    catch err
        warning(err.identifier, '%s', err.message);
    end %try

end

function isSameFolder = isSameFolder(folder1, folder2)
    % 获取文件夹的绝对路径
    folder1 = what(folder1);
    folder2 = what(folder2);

    % 判断两个路径是否相同
    isSameFolder = isequal(folder1.path, folder2.path);
end
