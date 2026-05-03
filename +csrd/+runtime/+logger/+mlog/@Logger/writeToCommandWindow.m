function writeToCommandWindow(obj, msgObj)
    % Writes a message to the command or console window
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 writeToCommandWindow 实现。

    % Copyright 2018-2022 The MathWorks Inc.

    % Pass obj.Name to createDisplayMessage, which now handles the full mmengine format
    fprintf("%s\n", msgObj.createDisplayMessage(obj.Name));
