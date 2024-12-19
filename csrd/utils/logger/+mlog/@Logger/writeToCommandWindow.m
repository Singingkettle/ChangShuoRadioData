function writeToCommandWindow(obj, msgObj)
% Writes a message to the command or console window

% Copyright 2018-2022 The MathWorks Inc.


fprintf("\t%s Log: %s\n", obj.Name, ...
    msgObj.createDisplayMessage());