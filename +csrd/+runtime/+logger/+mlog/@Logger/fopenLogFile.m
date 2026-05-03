function fopenLogFile(obj, permission)
% Open the log file for writing
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：提供 CSRD 生产链路中的 fopenLogFile 实现。

% Copyright 2018-2022 The MathWorks Inc.


%% Open the file

[obj.FileID, openMsg] = fopen(obj.LogFile, permission);
% obj.OpenFilePath = filePath;
% obj.OpenFileStartTime = curTime;

if obj.FileID == -1
    msg = "Unable to open log file for writing: ''%s''\n%s\n";
    error(msg, obj.LogFile, openMsg);
end

