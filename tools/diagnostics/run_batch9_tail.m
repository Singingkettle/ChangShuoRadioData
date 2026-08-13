function run_batch9_tail()
    % run_batch9_tail - Batch-9 steps 2-4 (after the full suite already ran).
    % Inputs: none. Outputs: none (appends to the batch9 summary log,
    % regenerates the canonical baseline at N=250 full mode).
    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    cd(projectRoot);
    addpath(projectRoot);
    addpath(fullfile(projectRoot, 'tests'));
    addpath(fullfile(projectRoot, 'tests', 'regression'));
    outDir = fullfile(projectRoot, 'artifacts', 'tests', 'runs', 'batch9');
    if ~exist(outDir, 'dir'); mkdir(outDir); end
    fid = fopen(fullfile(outDir, 'batch9_summary.log'), 'a');
    closer = onCleanup(@() fclose(fid));
    stamp = @() char(datetime('now', 'Format', 'HH:mm:ss'));

    fprintf(fid, '[%s] plausibility(24) start\n', stamp());
    try
        test_measured_truth_plausibility(24);
        fprintf(fid, '[%s] plausibility(24): PASS\n', stamp());
    catch e
        fprintf(fid, '[%s] plausibility(24): FAIL %s | %s\n', stamp(), ...
            e.identifier, strrep(e.message, newline, ' '));
    end

    fprintf(fid, '[%s] noise independence start\n', stamp());
    try
        test_measured_plane_is_noise_independent();
        fprintf(fid, '[%s] noise independence: PASS\n', stamp());
    catch e
        fprintf(fid, '[%s] noise independence: FAIL %s | %s\n', stamp(), ...
            e.identifier, strrep(e.message, newline, ' '));
    end

    fprintf(fid, '[%s] baseline(250, full) start\n', stamp());
    try
        test_baseline_sweep_200(250, 'Mode', 'full');
        fprintf(fid, '[%s] baseline(250, full): PASS\n', stamp());
    catch e
        fprintf(fid, '[%s] baseline(250, full): FAIL %s | %s\n', stamp(), ...
            e.identifier, strrep(e.message, newline, ' '));
    end

    % The two suite entries that need the canonical must pass again now.
    fprintf(fid, '[%s] canonical-dependent gates re-run\n', stamp());
    try
        test_phase6_performance_diagnostics();
        fprintf(fid, '[%s] performance diagnostics: PASS\n', stamp());
    catch e
        fprintf(fid, '[%s] performance diagnostics: FAIL %s | %s\n', ...
            stamp(), e.identifier, strrep(e.message, newline, ' '));
    end
    try
        test_phase6_release_ci_readiness();
        fprintf(fid, '[%s] release ci readiness: PASS\n', stamp());
    catch e
        fprintf(fid, '[%s] release ci readiness: FAIL %s | %s\n', ...
            stamp(), e.identifier, strrep(e.message, newline, ' '));
    end
    fprintf(fid, '[%s] batch9 tail done\n', stamp());
end
