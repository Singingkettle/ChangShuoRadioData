function diag_phase4_c8()
%DIAG_PHASE4_C8 Walk the latest baseline session for each scenario and
%   list bandwidth-difference outliers driving the C8 metric.

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot);

runRoot = fullfile(projectRoot, 'artifacts', 'tests', 'runs', 'baseline_v0');
scenarioDirs = dir(fullfile(runRoot, 'scenario_*'));
scenarioDirs = scenarioDirs([scenarioDirs.isdir]);

records = struct( ...
    'Scenario', {}, ...
    'TxID', {}, ...
    'ModType', {}, ...
    'ChannelModel', {}, ...
    'PlannedBwHz', {}, ...
    'ExecutionBwHz', {}, ...
    'AnalyticalBwHz', {}, ...
    'MeasuredBwHz', {}, ...
    'AppliedSnrDb', {}, ...
    'AbsRelDiff', {});

for k = 1:numel(scenarioDirs)
    sname = scenarioDirs(k).name;
    sessions = dir(fullfile(scenarioDirs(k).folder, sname, 'session_*'));
    sessions = sessions([sessions.isdir]);
    if isempty(sessions), continue; end
    names = {sessions.name};
    [~, idx] = sort(names);
    idx = idx(end);
    annPath = fullfile(sessions(idx).folder, sessions(idx).name, ...
        'annotations', 'scenario_000001_annotation.json');
    if ~exist(annPath, 'file'), continue; end
    try
        ann = jsondecode(fileread(annPath));
    catch
        continue;
    end
    if ~isfield(ann, 'Frames') || isempty(ann.Frames), continue; end
    frames = ann.Frames;
    if iscell(frames)
        for f = 1:numel(frames)
            records = scanFrame(records, frames{f}, sname);
        end
    else
        for f = 1:numel(frames)
            records = scanFrame(records, frames(f), sname);
        end
    end
end

if isempty(records)
    fprintf('No records collected.\n');
    return;
end

snr = [records.AppliedSnrDb];
diffs = [records.AbsRelDiff];

fprintf('Total records: %d\n', numel(records));
fprintf('SNR distribution (all records):\n');
fprintf('  P5=%.2f  P25=%.2f  P50=%.2f  P75=%.2f  P95=%.2f  Min=%.2f  Max=%.2f\n', ...
    prctile(snr, 5), prctile(snr, 25), prctile(snr, 50), prctile(snr, 75), ...
    prctile(snr, 95), min(snr), max(snr));

fprintf('\nC8 P95 per SNR floor:\n');
for floorDb = [3.0, 6.0, 9.0, 12.0, 15.0, 18.0, 21.0]
    m = isfinite(snr) & snr >= floorDb & isfinite(diffs);
    if ~any(m)
        fprintf('  floor=%.1f dB  N=0  (no samples)\n', floorDb);
        continue;
    end
    d = diffs(m);
    fprintf('  floor=%5.1f dB  N=%4d  P50=%.4f  P90=%.4f  P95=%.4f  P99=%.4f  Max=%.4f\n', ...
        floorDb, numel(d), prctile(d, 50), prctile(d, 90), prctile(d, 95), ...
        prctile(d, 99), max(d));
end

mask = isfinite(snr) & snr >= 6.0 & isfinite(diffs);
sub = records(mask);
diffs2 = [sub.AbsRelDiff];

mods = string({sub.ModType});
[u, ~, gi] = unique(mods);
fprintf('\nBy ModulationType (SNR>=6):\n');
for i = 1:numel(u)
    g = diffs2(gi == i);
    fprintf('  %-22s  N=%4d  P50=%.4f  P95=%.4f  Max=%.4f\n', ...
        u(i), numel(g), prctile(g, 50), prctile(g, 95), max(g));
end

chans = string({sub.ChannelModel});
[u, ~, gi] = unique(chans);
fprintf('\nBy ChannelModel (SNR>=6):\n');
for i = 1:numel(u)
    g = diffs2(gi == i);
    fprintf('  %-22s  N=%4d  P50=%.4f  P95=%.4f  Max=%.4f\n', ...
        u(i), numel(g), prctile(g, 50), prctile(g, 95), max(g));
end

[~, ord] = sort(diffs2, 'descend');
ord = ord(1:min(25, numel(ord)));
fprintf('\nTOP 25 worst (SNR>=6):\n');
for j = 1:numel(ord)
    r = sub(ord(j));
    fprintf('  %-22s tx=%-8s mod=%-18s ch=%-12s exec=%9.0f meas=%9.0f snr=%5.2f diff=%7.2f%%\n', ...
        r.Scenario, r.TxID, r.ModType, r.ChannelModel, ...
        r.ExecutionBwHz, r.MeasuredBwHz, r.AppliedSnrDb, ...
        100 * r.AbsRelDiff);
end
end


function records = scanFrame(records, frame, sname)
if ~isstruct(frame), return; end
if ~isfield(frame, 'SignalSources'), return; end
srcs = frame.SignalSources;
if iscell(srcs)
    for k = 1:numel(srcs)
        records = scanSource(records, srcs{k}, sname);
    end
else
    for k = 1:numel(srcs)
        records = scanSource(records, srcs(k), sname);
    end
end
end


function records = scanSource(records, src, sname)
if ~isstruct(src) || ~isfield(src, 'Truth'), return; end
truth = src.Truth;
if ~isstruct(truth), return; end

execBw = NaN; analyticalBw = NaN; measBw = NaN; snrDb = NaN; plannedBw = NaN;
modType = 'Unknown';
chanModel = 'Unknown';

if isfield(truth, 'Execution') && isstruct(truth.Execution)
    e = truth.Execution;
    if isfield(e, 'ModulatedBandwidthHz') && isnumeric(e.ModulatedBandwidthHz) && isscalar(e.ModulatedBandwidthHz)
        execBw = double(e.ModulatedBandwidthHz);
    end
    if isfield(e, 'AnalyticalBandwidthHz') && isnumeric(e.AnalyticalBandwidthHz) && isscalar(e.AnalyticalBandwidthHz)
        analyticalBw = double(e.AnalyticalBandwidthHz);
    end
    if isfield(e, 'AppliedSNRdB') && isnumeric(e.AppliedSNRdB) && isscalar(e.AppliedSNRdB)
        snrDb = double(e.AppliedSNRdB);
    end
    if isfield(e, 'ChannelModel')
        chanModel = char(string(e.ChannelModel));
    end
    if isfield(e, 'ModulationType')
        modType = char(string(e.ModulationType));
    end
end
if isfield(truth, 'Measured') && isstruct(truth.Measured) ...
        && isfield(truth.Measured, 'SourcePlane') ...
        && isstruct(truth.Measured.SourcePlane) ...
        && isfield(truth.Measured.SourcePlane, 'OccupiedBandwidthHz') ...
        && isnumeric(truth.Measured.SourcePlane.OccupiedBandwidthHz) ...
        && isscalar(truth.Measured.SourcePlane.OccupiedBandwidthHz)
    measBw = double(truth.Measured.SourcePlane.OccupiedBandwidthHz);
end
if isfield(truth, 'Design') && isstruct(truth.Design)
    d = truth.Design;
    if isfield(d, 'PlannedBandwidthHz') && isnumeric(d.PlannedBandwidthHz) && isscalar(d.PlannedBandwidthHz)
        plannedBw = double(d.PlannedBandwidthHz);
    end
    if strcmp(modType, 'Unknown') && isfield(d, 'ModulationType')
        modType = char(string(d.ModulationType));
    end
end
if strcmp(modType, 'Unknown') && isfield(src, 'ModulationType')
    modType = char(string(src.ModulationType));
end

if ~(isfinite(execBw) && execBw > 0 && isfinite(measBw))
    return;
end
diff = abs(measBw - execBw) / execBw;
txid = '';
if isfield(src, 'TxID')
    txid = char(string(src.TxID));
end
records(end + 1) = struct( ...
    'Scenario', sname, ...
    'TxID', txid, ...
    'ModType', modType, ...
    'ChannelModel', chanModel, ...
    'PlannedBwHz', plannedBw, ...
    'ExecutionBwHz', execBw, ...
    'AnalyticalBwHz', analyticalBw, ...
    'MeasuredBwHz', measBw, ...
    'AppliedSnrDb', snrDb, ...
    'AbsRelDiff', diff); %#ok<AGROW>
end
