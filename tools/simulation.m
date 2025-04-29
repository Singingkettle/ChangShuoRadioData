function simulation(worker_id, num_workers)
    % Check if arguments were provided and assign defaults if not
    if nargin < 1
        worker_id = 1;
    end

    if nargin < 2
        num_workers = 1;
    end

    addpath(genpath('../csrd'));
    cfgs = load_config('../config/_base_/simulate/ChangShuo/CSRD2024.json');
    cfgs = cfgs.runner;
    DataCollection = sprintf("%s(NumFrames=cfgs.NumFrames, Seed=cfgs.Seed, Log=cfgs.Log, Data=cfgs.Data, Physical=cfgs.Physical)", cfgs.handle);
    DataCollection = eval(DataCollection);
    DataCollection(worker_id, num_workers)

end
