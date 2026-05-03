function test_no_dead_code_phase17_config_contracts()
%TEST_NO_DEAD_CODE_PHASE17_CONFIG_CONTRACTS Phase 17 static contract gate.
% 中文说明：禁止运行期合同旧字段和静默 fallback 回到生产链路。

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

prodFiles = [
    dir(fullfile(projectRoot, '+csrd', '**', '*.m'));
    dir(fullfile(projectRoot, 'config', '**', '*.m'));
    dir(fullfile(projectRoot, 'tools', '**', '*.m'))];

violations = {};
for k = 1:numel(prodFiles)
    path = fullfile(prodFiles(k).folder, prodFiles(k).name);
    code = fileread(path);
    rel = erase(path, [projectRoot filesep]);

    if contains(rel, fullfile('+pipeline', '+runtime', 'resolveFrameRuntimeContract.m'))
        continue;
    end
    if contains(rel, fullfile('+runtime', 'config_loader.m'))
        code = erase(code, 'FixedFrameLength');
    end
    if contains(rel, fullfile('+factories', 'MessageFactory.m'))
        code = erase(code, 'SegmentID');
        code = erase(code, 'SeedValue');
    end
    if contains(code, 'legacy_empty_frame_1ms')
        violations{end + 1} = sprintf('%s contains legacy_empty_frame_1ms', rel); %#ok<AGROW>
    end
    if contains(code, 'Global.FrameLength')
        violations{end + 1} = sprintf('%s reads/writes Global.FrameLength', rel); %#ok<AGROW>
    end
    if contains(code, 'messageLength = 1024')
        violations{end + 1} = sprintf('%s contains messageLength=1024 fallback', rel); %#ok<AGROW>
    end
    if contains(code, 'symbolRate = 100e3')
        violations{end + 1} = sprintf('%s contains symbolRate=100e3 fallback', rel); %#ok<AGROW>
    end
    if contains(code, 'Burst=frame_') || contains(code, 'frame_<frameId>')
        violations{end + 1} = sprintf('%s contains frame-id channel seed fallback', rel); %#ok<AGROW>
    end
end

assert(isempty(violations), strjoin(violations, newline));
fprintf('  [OK] Phase 17 runtime-contract static gate.\n');
end
