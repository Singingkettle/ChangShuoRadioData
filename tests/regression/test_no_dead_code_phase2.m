function test_no_dead_code_phase2()
    %TEST_NO_DEAD_CODE_PHASE2 Phase 2 dead-code reverse-sample regression.
    %
    %   Maps to docs/audits/phases/phase-2-blueprint.md §3.5.4 bullet 5.
    %
    %   Phase 2 (audit D7) deletes the silent-fallback frequency allocation
    %   wrappers `allocateFrequenciesRandom.m` and
    %   `allocateFrequenciesOptimized.m`. To prevent these wrappers from
    %   sneaking back in via copy-paste or partial reverts, this regression
    %   test asserts that:
    %
    %     (a) neither file exists on disk under +csrd/, and
    %     (b) no source file under +csrd/ contains a textual reference to
    %         the wrapper function names.
    %
    %   Profile loaders, validators, ScenarioFactory and the Phase 2 audit
    %   prescription rely on the assumption that the only supported
    %   FrequencyAllocation.Strategy is 'ReceiverCentric'. Reintroducing
    %   either wrapper would silently re-enable the H6 / D7 dead-strategy
    %   defect and bypass the new fail-fast strategy gate
    %   (CommunicationBehaviorSimulator.validateFrequencyAllocationStrategy).

    fprintf('\n=== Phase 2 dead-code reverse-sample (D7) ===\n');

    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    csrdRoot = fullfile(projectRoot, '+csrd');

    deletedFiles = {
        fullfile(csrdRoot, '+blocks', '+scenario', '@CommunicationBehaviorSimulator', ...
            'private', 'allocateFrequenciesRandom.m')
        fullfile(csrdRoot, '+blocks', '+scenario', '@CommunicationBehaviorSimulator', ...
            'private', 'allocateFrequenciesOptimized.m')
        };

    for i = 1:numel(deletedFiles)
        assert(~isfile(deletedFiles{i}), ...
            'CSRD:Tests:DeadCodeResurrected', ...
            ['Phase 2 (D7) deleted file has reappeared:\n  %s\n' ...
             'See docs/audits/phases/phase-2-blueprint.md §3.5.'], ...
            deletedFiles{i});
    end
    fprintf('  [OK] both Phase 2-deleted wrapper files are absent.\n');

    % D7: forbidden symbol references for the deleted frequency
    %     allocation wrapper functions.
    %
    % D5: forbidden source pattern for the deleted ChannelFactory
    %     `modelNames{1}` arbitrary-first-key silent fallback. The
    %     pattern is matched as a literal substring (no regex) so the
    %     comment "removed `modelNames{1}` ..." in the canonical Phase 2
    %     gate does NOT count as a resurrection: only files outside the
    %     test/docs surface area are scanned, and we strip MATLAB line
    %     comments before matching.
    forbiddenSymbols = {'allocateFrequenciesRandom', 'allocateFrequenciesOptimized', 'modelNames{1}'};
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
        msgLines = {'Phase 2 dead-code references resurfaced under +csrd/:'};
        for k = 1:numel(offenders)
            msgLines{end + 1} = sprintf('  %s:%d -> %s [%s]', ...
                offenders(k).File, offenders(k).LineNumber, ...
                strtrim(offenders(k).Line), offenders(k).Symbol); %#ok<AGROW>
        end
        msgLines{end + 1} = ['Use the Hidden static gates ' ...
            'csrd.blocks.scenario.CommunicationBehaviorSimulator' ...
            '.validateFrequencyAllocationStrategy (D7) and ' ...
            'csrd.factories.ChannelFactory' ...
            '.resolveChannelModelNameFromConfig (D5) instead.'];
        error('CSRD:Tests:DeadCodeResurrected', '%s', strjoin(msgLines, newline));
    end
    fprintf('  [OK] grep across +csrd/ produced 0 hits for forbidden symbols.\n');

    fprintf('All Phase 2 dead-code reverse-sample assertions passed.\n');
end


function files = collectMatlabSources(rootDir)
    %COLLECTMATLABSOURCES Recursively gather *.m files under rootDir.
    listing = dir(fullfile(rootDir, '**', '*.m'));
    files = cell(numel(listing), 1);
    for i = 1:numel(listing)
        files{i} = fullfile(listing(i).folder, listing(i).name);
    end
end


function hits = scanFileForSymbol(filePath, symbol)
    %SCANFILEFORSYMBOL Return struct array of {LineNumber, Line} for every
    %line in `filePath` whose CODE portion (before any `%` comment
    %marker) contains `symbol`.
    %
    %   Comments are intentionally excluded so that docstrings explaining
    %   *why* the dead code was removed do not trip the regression. The
    %   stripping is a simple "first %% / % wins" heuristic; that is good
    %   enough for the Phase 2 invariant because none of the targeted
    %   forbidden symbols would legally appear inside a string literal in
    %   any source file under +csrd/ (verified manually 2026-04-25).
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
    %STRIPMATLABLINECOMMENT Return the source-code prefix of a MATLAB
    %line up to (but not including) the first '%' that starts a comment.
    %A leading '%%' section header still produces an empty code portion,
    %which is the desired behaviour.
    idx = strfind(line, '%');
    if isempty(idx)
        code = line;
    else
        code = line(1:idx(1) - 1);
    end
end
