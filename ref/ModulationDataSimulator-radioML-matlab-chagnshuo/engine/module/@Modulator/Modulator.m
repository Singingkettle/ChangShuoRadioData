% =========================================================================
% Project: ModulationDataSimulator
% Script: Class-> modulator.Factory
% Author: Shuo Chang
% Email: changshuo@bupt.edu.cn
% Date: 2020-05-21
% Copyright (c) 2020-present, WTI, BUPT.
% =========================================================================

classdef Modulation < handle

    methods(Static)
        helpInfo();
        modulatorHandle = create(dataParam);
    end
end
