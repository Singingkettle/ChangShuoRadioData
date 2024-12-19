function fopenLogFile(obj, permission)
% Open the log file for writing

% Copyright 2018-2022 The MathWorks Inc.


%% Open the file

[obj.FileID, openMsg] = fopen(obj.LogFile, permission);
% obj.OpenFilePath = filePath;
% obj.OpenFileStartTime = curTime;

if obj.FileID == -1
    msg = "Unable to open log file for writing: ''%s''\n%s\n";
    error(msg, obj.LogFile, openMsg);
end

