function test_no_dead_code_phase12_config_fields()
    %TEST_NO_DEAD_CODE_PHASE12_CONFIG_FIELDS Config field cleanup gate.

    fprintf('=== Phase 12 config field consumption gate ===\n');

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    channelCfg = fullfile(projectRoot, 'config', '_base_', 'factories', ...
        'channel_factory.m');
    baselineSweep = fullfile(projectRoot, 'tests', 'regression', ...
        'test_baseline_sweep_200.m');
    measuredTruth = fullfile(projectRoot, 'tests', 'regression', ...
        'test_measured_truth_coverage.m');
    initializeStatisticalMap = fullfile(projectRoot, '+csrd', '+blocks', ...
        '+scenario', '@PhysicalEnvironmentSimulator', 'private', ...
        'initializeStatisticalMap.m');

    channelCode = stripComments(fileread(channelCfg));
    statisticalMapCode = stripComments(fileread(initializeStatisticalMap));
    forbiddenChannelFields = { ...
        'Factories.Channel.Types', ...
        'Factories.Channel.SNR', ...
        'Factories.Channel.LogDetails', ...
        'Factories.Channel.Description'};
    for k = 1:numel(forbiddenChannelFields)
        assert(~contains(channelCode, forbiddenChannelFields{k}), ...
            'channel_factory.m must not expose unused field %s.', ...
            forbiddenChannelFields{k});
    end

    assert(contains(channelCode, 'Factories.Channel.ChannelModels'), ...
        'channel_factory.m must retain ChannelModels.');
    assert(contains(channelCode, 'Factories.Channel.LinkBudget'), ...
        'channel_factory.m must retain LinkBudget.');
    assert(contains(channelCode, 'Factories.Channel.DefaultModels'), ...
        'channel_factory.m must retain DefaultModels.');
    assert(contains(channelCode, 'Factories.Channel.NoValidPathFallback'), ...
        'channel_factory.m must retain NoValidPathFallback.');

    repoCode = stripComments(readAllMatlabSource(projectRoot));
    forbiddenPreferred = ['Factories.Channel.' 'PreferredType'];
    assert(~contains(repoCode, forbiddenPreferred), ...
        ['Factories.Channel.' 'PreferredType was never consumed by ', ...
         'ChannelFactory; tests must use Map.*.ChannelModel instead.']);

    assert(contains(stripComments(fileread(baselineSweep)), ...
        '.Statistical.ChannelModel'), ...
        'Baseline channel preference must apply through Map.Statistical.ChannelModel.');
    assert(contains(stripComments(fileread(measuredTruth)), ...
        '.Statistical.ChannelModel'), ...
        'Measured-truth coverage must apply channel preference through Map.Statistical.ChannelModel.');
    assert(contains(statisticalMapCode, 'obj.Config.Environment.ChannelModel'), ...
        ['initializeStatisticalMap must consume Environment.ChannelModel ', ...
         'so Map.Statistical.ChannelModel reaches MapProfile.']);
    assert(contains(statisticalMapCode, '''ChannelModel'', channelModel'), ...
        'initializeStatisticalMap must stamp the configured channel model into MapProfile.');

    fprintf('=== Phase 12 config field consumption gate PASSED ===\n');
end


function src = readAllMatlabSource(projectRoot)
    roots = { ...
        fullfile(projectRoot, '+csrd'), ...
        fullfile(projectRoot, 'config'), ...
        fullfile(projectRoot, 'tests'), ...
        fullfile(projectRoot, 'tools')};
    src = '';
    for r = 1:numel(roots)
        if ~isfolder(roots{r})
            continue;
        end
        files = dir(fullfile(roots{r}, '**', '*.m'));
        for k = 1:numel(files)
            path = fullfile(files(k).folder, files(k).name);
            src = [src, newline, fileread(path)]; %#ok<AGROW>
        end
    end
end


function code = stripComments(src)
    lines = regexp(src, '\r?\n', 'split');
    code = '';
    for k = 1:numel(lines)
        line = lines{k};
        inString = false;
        cutAt = numel(line) + 1;
        c = 1;
        while c <= numel(line)
            ch = line(c);
            if ch == ''''
                if c < numel(line) && line(c + 1) == ''''
                    c = c + 2;
                    continue;
                end
                inString = ~inString;
            elseif ch == '%' && ~inString
                cutAt = c;
                break;
            end
            c = c + 1;
        end
        code = [code, line(1:cutAt - 1), newline]; %#ok<AGROW>
    end
end
