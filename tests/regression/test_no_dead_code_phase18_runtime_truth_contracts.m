function test_no_dead_code_phase18_runtime_truth_contracts()
%TEST_NO_DEAD_CODE_PHASE18_RUNTIME_TRUTH_CONTRACTS Phase 18 static gate.

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

prodFiles = [
    dir(fullfile(projectRoot, '+csrd', '**', '*.m'));
    dir(fullfile(projectRoot, 'config', '**', '*.m'));
    dir(fullfile(projectRoot, 'tools', '**', '*.m'))];

violations = {};
for k = 1:numel(prodFiles)
    path = fullfile(prodFiles(k).folder, prodFiles(k).name);
    rel = erase(path, [projectRoot filesep]);
    code = fileread(path);

    if contains(rel, fullfile('+blocks', '+physical', '+txRadioFront', 'TRFSimulator.m')) && ...
            contains(code, 'TRFSimulator:ResampleError')
        violations{end + 1} = sprintf('%s still warns on bad TRF resample.', rel); %#ok<AGROW>
    end
    if contains(rel, fullfile('+factories', 'TransmitFactory.m')) && ...
            contains(code, 'TargetSampleRate = inputSignalStruct.SampleRate')
        violations{end + 1} = sprintf('%s still falls back to input sample rate.', rel); %#ok<AGROW>
    end
    if contains(rel, fullfile('+factories', 'ReceiveFactory.m')) && ...
            contains(code, 'struct(''Error''')
        violations{end + 1} = sprintf('%s still returns Error structs.', rel); %#ok<AGROW>
    end
    if contains(rel, fullfile('+factories', 'ModulationFactory.m')) && ...
            contains(code, 'struct(''Error''')
        violations{end + 1} = sprintf('%s still returns Error structs.', rel); %#ok<AGROW>
    end
    if contains(rel, fullfile('+factories', 'ModulationFactory.m')) && ...
            (contains(code, 'Auto-calculated SymbolRate') || ...
             contains(code, 'forcing to 2') || ...
             contains(code, 'No ModulatorOrder value available'))
        violations{end + 1} = sprintf('%s still contains modulation execution fallback.', rel); %#ok<AGROW>
    end
    if contains(rel, fullfile('+factories', 'ChannelFactory.m')) && ...
            (contains(code, 'obj.logger.warning(''Could not set channel property') || ...
             contains(code, 'obj.logger.warning(''Could not update channel Distance') || ...
             contains(code, 'obj.logger.warning(''Could not update NumTransmitAntennas') || ...
             contains(code, 'obj.logger.warning(''Could not update NumReceiveAntennas') || ...
             contains(code, 'carrierFreq = 2.4e9') || ...
             contains(code, 'resolveNoiseBandwidth(') && contains(code, '50e6'))
        violations{end + 1} = sprintf('%s still contains channel fallback/warning downgrade.', rel); %#ok<AGROW>
    end
end

assert(isempty(violations), strjoin(violations, newline));
fprintf('  [OK] Phase 18 runtime-truth static gate.\n');
end
