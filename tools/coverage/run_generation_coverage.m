function results = run_generation_coverage(varargin)
%RUN_GENERATION_COVERAGE Exhaustive per-band data-generation coverage sweep.
%
%   results = run_generation_coverage('Name', value, ...)
%
%   Forces the regulatory monitoring band to every band of every supported
%   region, picks an SDR model whose tuning range and instantaneous bandwidth
%   can host that band, and generates scenarios for each requested channel
%   model. Every scenario is audited for hard failures, annotation-schema
%   validity, and illegal NaN/Inf on live measured fields. The goal is to
%   exercise every service class / modulation family / bandwidth / temporal
%   pattern in the catalog and surface generation bugs.
%
%   Name-value options:
%     'ScenariosPerCell'  - scenarios per (band, channel) cell (default 2).
%     'TransmittersPerScenario' - Tx count (default 3).
%     'ChannelModels'     - cellstr subset of {'AWGN','Rayleigh','Rician'}
%                           (default {'AWGN'}). 'RayTracing' is not covered
%                           here (needs OSM assets); use the OSM regressions.
%     'Regions'           - cellstr subset of supported regions (default all).
%     'Seed'              - base RNG seed (default 20260620).
%     'ReceiverSampleRate'- requested IBW before SDR capping (default 50e6).
%     'Verbose'           - print per-cell progress (default false).
%
%   results is a struct array, one row per scenario, with fields:
%     Region, BandId, ServiceClass, Sdr, ChannelModel, Seed, Status,
%     ErrorId, ErrorMessage, AnnotationValid, LiveNanFields, NumSources.

p = inputParser();
p.FunctionName = 'run_generation_coverage';
addParameter(p, 'ScenariosPerCell', 2, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'TransmittersPerScenario', 3, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'ChannelModels', {'AWGN'}, @iscell);
addParameter(p, 'Regions', {}, @iscell);
addParameter(p, 'Seed', 20260620, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'ReceiverSampleRate', 50e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'Verbose', false, @(x) islogical(x) || isnumeric(x));
parse(p, varargin{:});
opt = p.Results;

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot);

regions = opt.Regions;
if isempty(regions)
    regions = csrd.catalog.spectrum.RegionSpectrumCatalog.supportedRegionIds();
end
sdrProfiles = csrd.catalog.receiver.SdrReceiverCatalog.loadAll();

runRoot = fullfile(projectRoot, 'artifacts', 'coverage', ...
    sprintf('generation_%d', opt.Seed));
if ~exist(runRoot, 'dir'); mkdir(runRoot); end

csrd.runtime.logger.GlobalLogManager.reset();
csrd.runtime.toolbox.validateRequiredToolboxes('minimal');
csrd.runtime.logger.GlobalLogManager.initialize(struct( ...
    'Name', 'CSRD-Coverage', 'Level', 'ERROR', ...
    'SaveToFile', false, 'DisplayInConsole', false), runRoot);

results = struct('Region', {}, 'BandId', {}, 'ServiceClass', {}, ...
    'Sdr', {}, 'ChannelModel', {}, 'Seed', {}, 'Status', {}, ...
    'ErrorId', {}, 'ErrorMessage', {}, 'AnnotationValid', {}, ...
    'LiveNanFields', {}, 'NumSources', {});

seed = double(opt.Seed);
for r = 1:numel(regions)
    region = regions{r};
    catalog = csrd.catalog.spectrum.RegionSpectrumCatalog.load(region);
    for b = 1:numel(catalog.Bands)
        band = catalog.Bands(b);
        sdrModel = localPickSdr(band, sdrProfiles, opt.ReceiverSampleRate);
        for c = 1:numel(opt.ChannelModels)
            channelModel = opt.ChannelModels{c};
            for s = 1:opt.ScenariosPerCell
                seed = seed + 1;
                if isempty(sdrModel)
                    results(end+1) = localResult(region, band, '', ...
                        channelModel, seed, 'NoCompatibleSdr', '', ...
                        'no SDR tuning range hosts this band', true, {}, 0); %#ok<AGROW>
                    continue;
                end
                rec = localRunAndAudit(projectRoot, runRoot, region, ...
                    band, sdrModel, channelModel, seed, opt);
                results(end+1) = rec; %#ok<AGROW>
                if opt.Verbose
                    fprintf('%-3s %-22s %-10s %-12s seed%d -> %s\n', ...
                        region, band.BandId, sdrModel, channelModel, seed, rec.Status);
                end
            end
        end
    end
end

localPrintSummary(results);
end


function rec = localRunAndAudit(projectRoot, runRoot, region, band, ...
        sdrModel, channelModel, seed, opt)
% localRunAndAudit - Generate one scenario and audit it.
rec = localResult(region, band, sdrModel, channelModel, seed, ...
    'Unknown', '', '', false, {}, 0);
try
    rng(seed, 'twister');
    cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
    cfg.Runner.NumScenarios = 1;
    cfg.Runner.RandomSeed = seed;
    cfg.Runner.Toolbox.Level = 'minimal';
    % Each cell writes to its own directory. A shared directory lets a failed
    % cell (which writes no annotation) read the previous cell's stale
    % annotation and report a false OK; per-cell isolation makes a missing
    % annotation an unambiguous failure signal.
    cellRoot = fullfile(runRoot, sprintf('cell_%d', seed));
    cfg.Runner.Data.OutputDirectory = cellRoot;
    cfg.Runner.Data.CompressData = false;
    cfg.Factories.Scenario.PhysicalEnvironment.Map.Types = {'Statistical'};
    cfg.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1.0;
    cfg.Factories.Scenario.PhysicalEnvironment.Map.Statistical.ChannelModel = channelModel;
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min = opt.TransmittersPerScenario;
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max = opt.TransmittersPerScenario;
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min = 1;
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max = 2;
    cfg.Factories.Scenario.CommunicationBehavior.Receiver.SampleRate = opt.ReceiverSampleRate;
    cfg.Factories.Scenario.CommunicationBehavior.Receiver.Sdr.Model = sdrModel;
    cfg = csrd.test_support.applyCanonicalFrameContract(cfg, 0.005, 1);
    % The forced band belongs to this region's catalog, so the regulatory
    % region must be pinned to it; otherwise the selector loads the default
    % region catalog, cannot find the band, and the cell fails spuriously.
    cfg.Factories.Scenario.CommunicationBehavior.Regulatory.Region.Fixed = region;
    cfg.Factories.Scenario.CommunicationBehavior.Regulatory.MonitoringBand.FixedBandId = band.BandId;
    % Forcing a specific band must elevate the service tier to that band's
    % own tier; otherwise a Tier2 band (e.g. 6 GHz IMT) is filtered out by the
    % tier gate before anchor selection and the cell fails spuriously.
    cfg.Factories.Scenario.CommunicationBehavior.Regulatory.ServiceTier = band.ServiceTier;
    cfg = csrd.test_support.buildRuntimePlanForTest(cfg);

    runner = csrd.SimulationRunner('RunnerConfig', cfg.Runner, ...
        'FactoryConfigs', cfg.Factories, 'RuntimePlan', cfg.RuntimePlan);
    setup(runner);
    cleanup = onCleanup(@() localRelease(runner));
    warnState = warning('off', 'MATLAB:structOnObject');
    s = struct(runner);
    warning(warnState);
    annPath = fullfile(s.actualOutputDirectory, 'annotations', ...
        'scenario_000001_annotation.json');
    % The runner can write every cell into one shared session directory, so a
    % stale annotation from a previous cell would mask a failed cell as OK.
    % Clear the target before stepping; its presence afterwards is then an
    % unambiguous, output-path-independent success signal.
    if exist(annPath, 'file') == 2
        delete(annPath);
    end
    step(runner, 1, 1);
    if exist(annPath, 'file') ~= 2
        rec.Status = 'Failed';
        rec.ErrorId = 'CSRD:Coverage:NoAnnotation';
        rec.ErrorMessage = 'scenario produced no annotation (failed/skipped)';
        return;
    end
    [rec.AnnotationValid, rec.LiveNanFields, rec.NumSources, auditErr] = ...
        localAuditAnnotation(annPath);
    if ~rec.AnnotationValid
        rec.Status = 'BadAnnotation';
        rec.ErrorId = 'CSRD:Coverage:AnnotationInvalid';
        rec.ErrorMessage = auditErr;
    elseif ~isempty(rec.LiveNanFields)
        rec.Status = 'LiveNaN';
        rec.ErrorId = 'CSRD:Coverage:LiveNaN';
        rec.ErrorMessage = strjoin(rec.LiveNanFields, ', ');
    else
        rec.Status = 'OK';
    end
catch ME
    rec.Status = 'Error';
    rec.ErrorId = ME.identifier;
    rec.ErrorMessage = ME.message;
end
end


function [valid, liveNanFields, numSources, auditErr] = localAuditAnnotation(annPath)
% localAuditAnnotation - Schema-validate and scan live measured fields.
valid = false; liveNanFields = {}; numSources = 0; auditErr = '';
try
    ann = csrd.pipeline.annotation.readAnnotation(annPath, ...
        'RequireSources', true, 'RequireRuntimeHeader', true);
    valid = true;
    numSources = numel(ann.Sources);
    seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    for k = 1:numel(ann.Sources)
        src = ann.Sources{k};
        sp = src.Truth.Measured.SourcePlane;
        status = '';
        if isfield(sp, 'MeasurementStatus'); status = char(string(sp.MeasurementStatus)); end
        if strcmpi(status, 'NoSignal'); continue; end
        fields = {'OccupiedBandwidthHz', 'CenterFrequencyHz', ...
            'TimeOccupancy', 'FrequencyOccupancy'};
        for f = 1:numel(fields)
            if isfield(sp, fields{f})
                v = sp.(fields{f});
                if isnumeric(v) && ~isempty(v) && any(~isfinite(v(:)))
                    seen(fields{f}) = true;
                end
            end
        end
    end
    liveNanFields = keys(seen);
catch ME
    auditErr = sprintf('%s: %s', ME.identifier, ME.message);
end
end


function model = localPickSdr(band, sdrProfiles, requestedSampleRate)
% localPickSdr - First SDR whose tuning range and IBW can host the band.
model = '';
rangeHz = band.FrequencyRangeHz;
minBw = inf;
for k = 1:numel(band.RecommendedBandwidthsHz)
    minBw = min(minBw, double(band.RecommendedBandwidthsHz{k}));
end
% Prefer wideband general-purpose models first.
order = {'USRP_B210', 'USRP_N310', 'USRP_X410', 'BladeRF_2', ...
    'HackRF_One', 'Airspy_R2', 'SDRplay_RSPdx', 'RTL_SDR'};
for o = 1:numel(order)
    prof = localFindProfile(sdrProfiles, order{o});
    if isempty(prof); continue; end
    tune = prof.TuningRangeHz;
    if rangeHz(1) < tune(1) || rangeHz(2) > tune(2); continue; end
    ibw = min(requestedSampleRate, prof.MaxInstantaneousBandwidthHz);
    if ibw * 0.8 < minBw; continue; end  % cannot fit the narrowest channel
    model = prof.Model;
    return;
end
end


function prof = localFindProfile(profiles, model)
prof = [];
for k = 1:numel(profiles)
    if strcmp(profiles(k).Model, model); prof = profiles(k); return; end
end
end


function rec = localResult(region, band, sdrModel, channelModel, seed, ...
        status, errId, errMsg, valid, liveNan, numSources)
serviceClass = '';
bandId = '';
if isstruct(band)
    if isfield(band, 'ServiceClass'); serviceClass = band.ServiceClass; end
    if isfield(band, 'BandId'); bandId = band.BandId; end
end
rec = struct('Region', region, 'BandId', bandId, ...
    'ServiceClass', serviceClass, 'Sdr', sdrModel, ...
    'ChannelModel', channelModel, 'Seed', seed, 'Status', status, ...
    'ErrorId', errId, 'ErrorMessage', errMsg, 'AnnotationValid', valid, ...
    'LiveNanFields', {liveNan}, 'NumSources', numSources);
end


function localRelease(runner)
if isLocked(runner); release(runner); end
end


function localPrintSummary(results)
n = numel(results);
statuses = {results.Status};
ok = sum(strcmp(statuses, 'OK'));
fprintf('\n==== Generation coverage summary ====\n');
fprintf('Total cells: %d  OK: %d  Problems: %d\n', n, ok, n - ok);
uniqStatus = unique(statuses);
for k = 1:numel(uniqStatus)
    c = sum(strcmp(statuses, uniqStatus{k}));
    fprintf('  %-16s %d\n', uniqStatus{k}, c);
end
problems = results(~strcmp(statuses, 'OK') & ~strcmp(statuses, 'NoCompatibleSdr'));
if ~isempty(problems)
    fprintf('\n---- Problem cells ----\n');
    for k = 1:numel(problems)
        pr = problems(k);
        fprintf('%-3s %-22s %-12s %-10s seed%d [%s] %s | %s\n', ...
            pr.Region, pr.BandId, pr.Sdr, pr.ChannelModel, pr.Seed, ...
            pr.Status, pr.ErrorId, pr.ErrorMessage);
    end
end
end
