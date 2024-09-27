% =========================================================================
% Project: ModulatorDataSimulator
% Script: Class-> Factory
% Author: Shuo Chang
% Email: changshuo@bupt.edu.cn
% Date: 2020-05-21
% Copyright (c) 2020-present, WTI, BUPT.
% =========================================================================

classdef Source < handle

    methods(Static)
        helpInfo();
        sourceHandle = create(dataParam);
    end
end
