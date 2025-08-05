function fcloseLogFile(obj)
% Close the log file for writing

% Copyright 2018-2022 The MathWorks Inc.


if obj.FileID >= 0

    try %#ok<TRYNC> 
        fclose(obj.FileID);
    end

    obj.FileID = -1;
%     obj.OpenFilePath = "";
%     obj.OpenFileStartTime = NaT;

end %if