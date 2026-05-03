function fcloseLogFile(obj)
% Close the log file for writing
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：提供 CSRD 生产链路中的 fcloseLogFile 实现。

% Copyright 2018-2022 The MathWorks Inc.


if obj.FileID >= 0

    try %#ok<TRYNC> 
        fclose(obj.FileID);
    end

    obj.FileID = -1;
%     obj.OpenFilePath = "";
%     obj.OpenFileStartTime = NaT;

end %if