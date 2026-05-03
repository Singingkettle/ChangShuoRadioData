function test_no_dead_code_phase3()
    %TEST_NO_DEAD_CODE_PHASE3 Phase 3 dead-code reverse-sample regression.
    %
    %   Maps to docs/audits/phases/phase-3-construction.md §3.6.C and §7
    %   exit conditions C3 / C4 / C5 / C6.
    %
    %   Phase 3 strictifies the construction layer:
    %     - P3-2  buildSegmentConfig PSK / RandomBit / 100k / 1024 / 4 magic
    %             defaults removed from processSingleSegment.m.
    %     - P3-3  processTransmitImpairments `2.5 * plannedBW` derive +
    %             localResolvePlannedBandwidth helper deleted.
    %     - P3-4  processChannelPropagation Planned passthrough deleted +
    %             three-tier SampleRate fallback collapsed to single fail-fast.
    %     - P3-5  setupReceivers magic defaults (50e6 / [-25e6, 25e6] / 0 /
    %             2.4e9) deleted; createEntity ±1000 boundary fallback +
    %             `cell(1, 100)` 100-frame hard cap deleted.
    %     - P3-6  4 catch-swallow sites converted to rethrow:
    %             Status='Error_TransmitterProcessing' / 'ReceiverBlockStepFailed'
    %             / TransmitError = true / signalSegmentsPerTx{k} = []
    %             must not reappear.
    %     - P3-7  ChangShuo.getScenarioBlueprintProvenance Hidden accessor
    %             deleted in favour of the LastGlobalLayout property +
    %             extractProvenanceFromGlobalLayout static helper.
    %     - P3-5C Mobility random selection (`models{randi(length(models))}`)
    %             removed from PhysicalEnvironmentSimulator.assignMobilityModel.
    %
    %   This regression scans every .m file under +csrd/ (excluding tests
    %   and docs) and asserts that none of the Phase 3 forbidden symbols
    %   appear in CODE (comments are stripped via stripMatlabLineComment so
    %   docstrings explaining *why* something was removed do not trip the
    %   gate).

    fprintf('\n=== Phase 3 dead-code reverse-sample (P3-2..7) ===\n');

    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    csrdRoot = fullfile(projectRoot, '+csrd');

    % Files Phase 3 deleted outright.
    deletedFiles = {
        fullfile(csrdRoot, '+blocks', '+scenario', ...
            '@PhysicalEnvironmentSimulator', 'private', 'assignMobilityModel.m')
        };

    for i = 1:numel(deletedFiles)
        assert(~isfile(deletedFiles{i}), ...
            'CSRD:Tests:DeadCodeResurrected', ...
            ['Phase 3 (S5) deleted file has reappeared:\n  %s\n' ...
             'See docs/audits/phases/phase-3-construction.md §3.3.C.'], ...
            deletedFiles{i});
    end
    fprintf('  [OK] Phase 3-deleted helper files are absent.\n');

    forbiddenSymbols = { ...
        'getScenarioBlueprintProvenance', ...
        'localResolvePlannedBandwidth', ...
        '2.5 * plannedBW', ...
        '''Error_TransmitterProcessing''', ...
        '''ReceiverBlockStepFailed''', ...
        'TransmitError = true', ...
        'models{randi(length(models))}'};

    sourceFiles = collectMatlabSources(csrdRoot);
    offenders = struct('Symbol', {}, 'File', {}, 'LineNumber', {}, 'Line', {});

    for s = 1:numel(forbiddenSymbols)
        symbol = forbiddenSymbols{s};
        for f = 1:numel(sourceFiles)
            hits = scanFileForSymbol(sourceFiles{f}, symbol);
            for h = 1:numel(hits)
                offenders(end + 1) = struct( ...
                    'Symbol', symbol, ...
                    'File', sourceFiles{f}, ...
                    'LineNumber', hits(h).LineNumber, ...
                    'Line', hits(h).Line); %#ok<AGROW>
            end
        end
    end

    if ~isempty(offenders)
        msgLines = {'Phase 3 dead-code references resurfaced under +csrd/:'};
        for k = 1:numel(offenders)
            msgLines{end + 1} = sprintf('  %s:%d -> %s [%s]', ...
                offenders(k).File, offenders(k).LineNumber, ...
                strtrim(offenders(k).Line), offenders(k).Symbol); %#ok<AGROW>
        end
        msgLines{end + 1} = ['Use the Phase 3 strict-construction APIs ' ...
            'instead: ChangShuo.LastGlobalLayout + ' ...
            'ChangShuo.extractProvenanceFromGlobalLayout (P3-7); ' ...
            'ChangShuo.assertSegmentSignalReadyForImpairments (P3-3); ' ...
            'isScenarioSkipException + rethrow (P3-6); ' ...
            'PhysicalEnvironmentSimulator.assignMobilityModel ' ...
            'static / Hidden (P3-5).'];
        error('CSRD:Tests:DeadCodeResurrected', '%s', strjoin(msgLines, newline));
    end
    fprintf('  [OK] grep across +csrd/ produced 0 hits for forbidden symbols.\n');

    fprintf('All Phase 3 dead-code reverse-sample assertions passed.\n');
end


function files = collectMatlabSources(rootDir)
    listing = dir(fullfile(rootDir, '**', '*.m'));
    files = cell(numel(listing), 1);
    for i = 1:numel(listing)
        files{i} = fullfile(listing(i).folder, listing(i).name);
    end
end


function hits = scanFileForSymbol(filePath, symbol)
    hits = struct('LineNumber', {}, 'Line', {});
    fid = fopen(filePath, 'r');
    if fid < 0
        return;
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    lineNumber = 0;
    while true
        line = fgetl(fid);
        if ~ischar(line)
            return;
        end
        lineNumber = lineNumber + 1;
        codePortion = stripMatlabLineComment(line);
        if contains(codePortion, symbol)
            hits(end + 1) = struct('LineNumber', lineNumber, 'Line', line); %#ok<AGROW>
        end
    end
end


function code = stripMatlabLineComment(line)
    idx = strfind(line, '%');
    if isempty(idx)
        code = line;
    else
        code = line(1:idx(1) - 1);
    end
end
