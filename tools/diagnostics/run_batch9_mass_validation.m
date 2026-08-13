function run_batch9_mass_validation()
    % run_batch9_mass_validation - Batch-9 mass-validation driver.
    % Inputs: none (paths derived from this file's location).
    % Outputs: none (writes verdict CSV + summary log under
    %          artifacts/tests/runs/batch9/, regenerates the canonical
    %          docs/baselines/2026-04-baseline-v0.json at N=250 full mode).
    %
    % One driver so the whole final sweep runs in a single serialized MATLAB
    % process (parallel MATLAB instances against this repo produce transient
    % false anomalies): the full suite with PER-ITEM verdicts (the suite
    % summary's bare "FAIL (t)" lines for script tests are a known parsing
    % trap -- the returned records struct is the truth), the 24-scenario
    % plausibility gate, the noise-independence gate, and the one-time
    % canonical baseline regeneration.
    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    cd(projectRoot);
    addpath(projectRoot);
    addpath(fullfile(projectRoot, 'tests'));
    addpath(fullfile(projectRoot, 'tests', 'regression'));
    addpath(fullfile(projectRoot, 'tests', 'unit'));

    outDir = fullfile(projectRoot, 'artifacts', 'tests', 'runs', 'batch9');
    if ~exist(outDir, 'dir'); mkdir(outDir); end
    logPath = fullfile(outDir, 'batch9_summary.log');
    fid = fopen(logPath, 'w');
    closer = onCleanup(@() fclose(fid));
    stamp = @() char(datetime('now', 'Format', 'HH:mm:ss'));

    % --- 1. Full suite with per-item verdicts --------------------------
    fprintf(fid, '[%s] full suite start\n', stamp());
    records = run_all_tests('all');
    verdictPath = fullfile(outDir, 'suite_verdicts.csv');
    vfid = fopen(verdictPath, 'w');
    fprintf(vfid, 'name,category,passed,duration_s,error\n');
    for k = 1:numel(records)
        err = '';
        if isfield(records, 'Error') && ~isempty(records(k).Error)
            err = strrep(strrep(char(records(k).Error), newline, ' '), '"', '''');
        end
        fprintf(vfid, '"%s",%s,%d,%.2f,"%s"\n', char(records(k).Name), ...
            char(records(k).Category), records(k).Passed, ...
            records(k).DurationSeconds, err(1:min(300, end)));
    end
    fclose(vfid);
    numFailed = sum(~[records.Passed]);
    fprintf(fid, '[%s] full suite done: %d tests, %d failed\n', ...
        stamp(), numel(records), numFailed);
    if numFailed > 0
        bad = records(~[records.Passed]);
        for k = 1:numel(bad)
            fprintf(fid, '  FAILED %s (%s)\n', char(bad(k).Name), ...
                char(bad(k).Category));
        end
    end

    % --- 2. Plausibility at 24 scenarios --------------------------------
    fprintf(fid, '[%s] plausibility(24) start\n', stamp());
    try
        test_measured_truth_plausibility(24);
        fprintf(fid, '[%s] plausibility(24): PASS\n', stamp());
    catch e
        fprintf(fid, '[%s] plausibility(24): FAIL %s | %s\n', stamp(), ...
            e.identifier, strrep(e.message, newline, ' '));
    end

    % --- 3. Noise independence ------------------------------------------
    fprintf(fid, '[%s] noise independence start\n', stamp());
    try
        test_measured_plane_is_noise_independent();
        fprintf(fid, '[%s] noise independence: PASS\n', stamp());
    catch e
        fprintf(fid, '[%s] noise independence: FAIL %s | %s\n', stamp(), ...
            e.identifier, strrep(e.message, newline, ' '));
    end

    % --- 4. Canonical baseline regeneration (ONE time, N=250 full) ------
    fprintf(fid, '[%s] baseline(250, full) start\n', stamp());
    try
        test_baseline_sweep_200(250, 'Mode', 'full');
        fprintf(fid, '[%s] baseline(250, full): PASS\n', stamp());
    catch e
        fprintf(fid, '[%s] baseline(250, full): FAIL %s | %s\n', stamp(), ...
            e.identifier, strrep(e.message, newline, ' '));
    end

    fprintf(fid, '[%s] batch9 driver done\n', stamp());
end
