%%
% =========================================================================
% Project: ModulationDataSimulator
% Script: Class-> generate
% Author: Shuo Chang
% Email: changshuo@bupt.edu.cn
% Date: 2020-05-21
% Copyright (c) 2020-present, WTI, BUPT.
% =========================================================================
function generate(workerIndex, numWorkers, configFile)
    
    addpath('../utils/YAMLMatlab_0.4.3');
    addpath(genpath('../engine'));
    
    % Parse the yaml file
    params = ReadYaml(configFile);
    
    paramCells = config(params);
    
    step = floor(numel(paramCells)/numWorkers);
    outs = numel(paramCells)-numWorkers*step;
    if outs > 0
        startIndexs1 = 1:(step+1):(outs*(step+1));
        endIndexs1 = (step+1):(step+1):(outs*(step+1));
        startIndexs2 = (outs*(step+1)+1):step:numel(paramCells);
        endIndexs2 = (outs*(step+1)+step):step:numel(paramCells);
        startIndexs = [startIndexs1, startIndexs2];
        endIndexs = [endIndexs1, endIndexs2];
    else
        startIndexs = 1:step:numel(paramCells);
        endIndexs = step:step:numel(paramCells);
    end

    if workerIndex <= length(startIndexs) 
    	for workerIndex = startIndexs(workerIndex):endIndexs(workerIndex)
            d = Modulation.create(paramCells{workerIndex});
            d();
    	end
    end
    
end
