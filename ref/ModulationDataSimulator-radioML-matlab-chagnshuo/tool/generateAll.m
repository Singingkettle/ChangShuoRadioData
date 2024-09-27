%%
% =========================================================================
% Project: ModulatorDataSimulator
% Script: Class-> generate
% Author: Shuo Chang
% Email: changshuo@bupt.edu.cn
% Date: 2020-05-21
% Copyright (c) 2020-present, WTI, BUPT.
% =========================================================================
function generateAll(configFile)
    
    addpath('../utils/YAMLMatlab_0.4.3');
    addpath(genpath('../engine'));
    
    % Parse the yaml file
    params = ReadYaml(configFile);
    
    paramCells = config(params);
    
    
    for workerIndex = 1:length(paramCells)
        d = Modulator.create(paramCells{workerIndex});
        d();
    end
end
