function baselinePath = run_phase5_mc_validation(varargin)
%RUN_PHASE5_MC_VALIDATION Phase 5 MC baseline entry point.
%
%   run_phase5_mc_validation() runs the canonical 1000-scenario Phase 5
%   sweep and writes docs/baselines/2026-04-final-v04.json.
%
%   run_phase5_mc_validation(N, 'Mode', 'smoke') runs a small validation
%   of the Phase 5 wrapper without overwriting the canonical final file.

p = inputParser;
addOptional(p, 'numScenarios', 1000, ...
    @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'Mode', 'full', ...
    @(x) any(strcmpi(x, {'smoke', 'full'})));
addParameter(p, 'Resume', [], ...
    @(x) isempty(x) || islogical(x));
parse(p, varargin{:});

numScenarios = double(p.Results.numScenarios);
mode = lower(p.Results.Mode);

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot);
addpath(fullfile(projectRoot, 'tests', 'regression'));

if strcmp(mode, 'full') && numScenarios < 1000
    error('CSRD:Phase5:CanonicalRequires1000', ...
        ['Phase 5 canonical MC requires at least 1000 scenarios. ', ...
         'Use Mode="smoke" for smaller entry-point validation.']);
end

if strcmp(mode, 'full')
    baselineFilename = '2026-04-final-v04.json';
    runLabel = 'baseline_v04_1000';
else
    baselineFilename = '2026-04-final-v04.smoke.json';
    runLabel = 'baseline_v04_smoke';
end

resumeRun = p.Results.Resume;
if isempty(resumeRun)
    resumeRun = strcmp(mode, 'full');
end

test_baseline_sweep_200(numScenarios, ...
    'Mode', mode, ...
    'BaselineFilename', baselineFilename, ...
    'RunLabel', runLabel, ...
    'SchemaVersion', 'baseline-v04', ...
    'Resume', resumeRun);

baselinePath = fullfile(projectRoot, 'docs', 'baselines', baselineFilename);
end
