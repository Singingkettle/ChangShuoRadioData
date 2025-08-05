function writeToCommandWindow(obj, msgObj)
    % Writes a message to the command or console window

    % Copyright 2018-2022 The MathWorks Inc.

    % Pass obj.Name to createDisplayMessage, which now handles the full mmengine format
    fprintf("%s\n", msgObj.createDisplayMessage(obj.Name));
