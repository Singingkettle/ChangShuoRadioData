function varargout = dataset_tools(action, varargin)
%DATASET_TOOLS Utilities for checking and inspecting the TWC dataset.
%   dataset_tools('check', data_root)
%   dataset_tools('stats', data_root)
%   dataset_tools('visual', data_root, version_name, item_id)
%
%   Outputs:
%     'check'  -> report struct
%     'stats'  -> stats struct
%     'visual' -> no outputs

if nargin < 1 || isempty(action)
    error('Action is required: check | stats | visual');
end

switch lower(action)
    case 'check'
        report = check_dataset(varargin{:});
        if nargout > 0
            varargout{1} = report;
        end
    case 'stats'
        stats = dataset_stats(varargin{:});
        if nargout > 0
            varargout{1} = stats;
        end
    case 'visual'
        quick_visual_check(varargin{:});
    otherwise
        error('Unknown action: %s', action);
end
end

function report = check_dataset(data_root)
%CHECK_DATASET Validate TWC dataset output consistency and quality.
%   report = CHECK_DATASET(data_root) scans dataset versions under
%   data_root (default: ./data/ChangShuo) and prints a summary report.

if nargin < 1 || isempty(data_root)
    data_root = fullfile('.', 'data', 'ChangShuo');
end

report = struct();
report.root = data_root;
report.versions = [];
report.errors = {};
report.warnings = {};
report.summary = struct();

if ~exist(data_root, 'dir')
    error('Data root not found: %s', data_root);
end

version_dirs = dir(fullfile(data_root, 'v*'));
version_dirs = version_dirs([version_dirs.isdir]);

if isempty(version_dirs)
    error('No version directories found under: %s', data_root);
end

for v = 1:length(version_dirs)
    vname = version_dirs(v).name;
    vpath = fullfile(version_dirs(v).folder, vname);
    anno_dir = fullfile(vpath, 'anno');
    iq_dir = fullfile(vpath, 'sequence_data', 'iq');

    if ~exist(anno_dir, 'dir')
        report.errors{end+1} = sprintf('Missing anno dir: %s', anno_dir);
        continue;
    end
    if ~exist(iq_dir, 'dir')
        report.errors{end+1} = sprintf('Missing iq dir: %s', iq_dir);
        continue;
    end

    json_files = dir(fullfile(anno_dir, '*.json'));
    mat_files = dir(fullfile(iq_dir, '*.mat'));

    json_names = {json_files.name};
    mat_names = {mat_files.name};

    json_ids = strip_extension(json_names, '.json');
    mat_ids = strip_extension(mat_names, '.mat');

    missing_mat = setdiff(json_ids, mat_ids);
    missing_json = setdiff(mat_ids, json_ids);

    if ~isempty(missing_mat)
        report.warnings{end+1} = sprintf('%s: %d JSON files without MAT', vname, length(missing_mat));
    end
    if ~isempty(missing_json)
        report.warnings{end+1} = sprintf('%s: %d MAT files without JSON', vname, length(missing_json));
    end

    common_ids = intersect(json_ids, mat_ids);
    vinfo = struct();
    vinfo.name = vname;
    vinfo.num_items = length(common_ids);
    vinfo.num_json = length(json_ids);
    vinfo.num_mat = length(mat_ids);
    vinfo.items = [];

    for i = 1:length(common_ids)
        item_id = common_ids{i};
        json_path = fullfile(anno_dir, [item_id '.json']);
        mat_path = fullfile(iq_dir, [item_id '.mat']);
        item_report = validate_item(json_path, mat_path);
        item_report.id = item_id;
        vinfo.items = [vinfo.items; item_report];
    end

    report.versions = [report.versions; vinfo];
end

report.summary = summarize_report(report);
print_summary(report);
end

function stats = dataset_stats(data_root)
%DATASET_STATS Compute basic statistics for the TWC dataset.
%   stats = DATASET_STATS() scans all versions under default data root
%   and returns aggregate distributions (SNR, modulation, channel).

if nargin < 1 || isempty(data_root)
    data_root = fullfile('.', 'data', 'ChangShuo');
end

version_dirs = dir(fullfile(data_root, 'v*'));
version_dirs = version_dirs([version_dirs.isdir]);
if isempty(version_dirs)
    error('No version directories found under: %s', data_root);
end

all_snr = strings(0,1);
all_mod = strings(0,1);
all_ch = strings(0,1);

for v = 1:length(version_dirs)
    vpath = fullfile(version_dirs(v).folder, version_dirs(v).name, 'anno');
    json_files = dir(fullfile(vpath, '*.json'));
    for i = 1:length(json_files)
        info = jsondecode(fileread(fullfile(vpath, json_files(i).name)));
        all_snr = [all_snr; string(info.snr(:))];
        all_mod = [all_mod; string(info.modulation(:))];
        all_ch = [all_ch; string(info.channel(:))];
    end
end

stats = struct();
stats.snr = count_strings(all_snr);
stats.modulation = count_strings(all_mod);
stats.channel = count_strings(all_ch);

fprintf('\n=== TWC Dataset Stats ===\n');
print_table('SNR', stats.snr);
print_table('Modulation', stats.modulation);
print_table('Channel', stats.channel);
fprintf('=========================\n');
end

function quick_visual_check(data_root, version_name, item_id)
%QUICK_VISUAL_CHECK Quick visualization for one dataset item.
%   QUICK_VISUAL_CHECK() uses default data root and picks first item.
%   QUICK_VISUAL_CHECK(data_root, version_name, item_id) shows time,
%   spectrum, and constellation for a selected item.

if nargin < 1 || isempty(data_root)
    data_root = fullfile('.', 'data', 'ChangShuo');
end

if nargin < 2 || isempty(version_name)
    version_dirs = dir(fullfile(data_root, 'v*'));
    version_dirs = version_dirs([version_dirs.isdir]);
    if isempty(version_dirs)
        error('No version directories found under: %s', data_root);
    end
    version_name = version_dirs(1).name;
end

anno_dir = fullfile(data_root, version_name, 'anno');
iq_dir = fullfile(data_root, version_name, 'sequence_data', 'iq');

if nargin < 3 || isempty(item_id)
    json_files = dir(fullfile(anno_dir, '*.json'));
    if isempty(json_files)
        error('No json files found in: %s', anno_dir);
    end
    item_id = erase(json_files(1).name, '.json');
end

json_path = fullfile(anno_dir, [item_id '.json']);
mat_path = fullfile(iq_dir, [item_id '.mat']);

info = jsondecode(fileread(json_path));
data = load(mat_path);

signal_data = data.signal_data;
iq = complex(squeeze(signal_data(:,1,:)), squeeze(signal_data(:,2,:)));
num_signals = size(iq, 1);
num_samples = size(iq, 2);

if isfield(data, 'wideband_data')
    wb = complex(squeeze(data.wideband_data(1,1,:)), ...
        squeeze(data.wideband_data(1,2,:)));
else
    wb = sum(iq, 1).';
end

sr = info.sample_rate(1);
t = (0:num_samples-1) / sr;

figure('Name', sprintf('TWC Quick Check: %s/%s', version_name, item_id), ...
    'Color', 'w');

subplot(3,2,1);
plot(t, real(wb));
title('Wideband Time (Real)');
xlabel('Time (s)'); ylabel('Amplitude'); grid on;

subplot(3,2,2);
plot(t, imag(wb));
title('Wideband Time (Imag)');
xlabel('Time (s)'); ylabel('Amplitude'); grid on;

subplot(3,2,3);
plot_spectrum(wb, sr);
title('Wideband Spectrum');

subplot(3,2,4);
plot(real(wb), imag(wb), '.');
title('Wideband Constellation');
xlabel('I'); ylabel('Q'); axis equal; grid on;

subplot(3,2,5);
sig_idx = min(1, num_signals);
plot_spectrum(iq(sig_idx, :).', sr);
title(sprintf('Signal %d Spectrum', sig_idx));

subplot(3,2,6);
plot(real(iq(sig_idx, :)), imag(iq(sig_idx, :)), '.');
title(sprintf('Signal %d Constellation', sig_idx));
xlabel('I'); ylabel('Q'); axis equal; grid on;
end

function item_report = validate_item(json_path, mat_path)
item_report = struct();
item_report.json_path = json_path;
item_report.mat_path = mat_path;
item_report.errors = {};
item_report.warnings = {};
item_report.stats = struct();

try
    info = jsondecode(fileread(json_path));
catch
    item_report.errors{end+1} = 'Failed to parse JSON';
    return;
end

try
    data = load(mat_path);
catch
    item_report.errors{end+1} = 'Failed to load MAT file';
    return;
end

if ~isfield(data, 'signal_data')
    item_report.errors{end+1} = 'Missing signal_data';
    return;
end

signal_data = data.signal_data;
sz = size(signal_data);
if numel(sz) ~= 3 || sz(2) ~= 2
    item_report.errors{end+1} = 'signal_data size is not [N x 2 x T]';
    return;
end

num_signals = sz(1);
num_samples = sz(3);

required_fields = {'center_frequency','bandwidth','snr','modulation', ...
    'channel','sample_rate','sample_num','sample_per_symbol'};
for k = 1:length(required_fields)
    if ~isfield(info, required_fields{k})
        item_report.errors{end+1} = sprintf('Missing field in JSON: %s', required_fields{k});
    end
end

field_lengths = [ ...
    length(info.center_frequency), ...
    length(info.bandwidth), ...
    length(info.snr), ...
    length(info.modulation), ...
    length(info.channel), ...
    length(info.sample_rate), ...
    length(info.sample_num), ...
    length(info.sample_per_symbol) ...
];

if any(field_lengths ~= num_signals)
    item_report.errors{end+1} = 'Metadata length does not match signal_data count';
end

iq = complex(squeeze(signal_data(:,1,:)), squeeze(signal_data(:,2,:)));
if any(isnan(iq(:))) || any(isinf(iq(:)))
    item_report.errors{end+1} = 'signal_data contains NaN/Inf';
end

power_per_signal = mean(abs(iq).^2, 2);
item_report.stats.power_min = min(power_per_signal);
item_report.stats.power_max = max(power_per_signal);
item_report.stats.power_mean = mean(power_per_signal);

if isfield(data, 'wideband_data')
    wideband_data = data.wideband_data;
    wbsz = size(wideband_data);
    if numel(wbsz) ~= 3 || wbsz(1) ~= 1 || wbsz(2) ~= 2 || wbsz(3) ~= num_samples
        item_report.errors{end+1} = 'wideband_data size is not [1 x 2 x T]';
    else
        wb = complex(squeeze(wideband_data(1,1,:)), squeeze(wideband_data(1,2,:)));
        if any(isnan(wb(:))) || any(isinf(wb(:)))
            item_report.errors{end+1} = 'wideband_data contains NaN/Inf';
        end
        item_report.stats.wideband_power = mean(abs(wb).^2);
    end
end

if isfield(info, 'sample_num') && any(info.sample_num ~= info.sample_num(1))
    item_report.warnings{end+1} = 'Inconsistent sample_num across signals';
end
if isfield(info, 'sample_rate') && any(info.sample_rate ~= info.sample_rate(1))
    item_report.warnings{end+1} = 'Inconsistent sample_rate across signals';
end

if isfield(info, 'center_frequency')
    cf = info.center_frequency;
    sr = info.sample_rate(1);
    if any(abs(cf) > sr/2)
        item_report.warnings{end+1} = 'center_frequency out of [-sr/2, sr/2]';
    end
end
if isfield(info, 'bandwidth') && any(info.bandwidth <= 0)
    item_report.warnings{end+1} = 'Non-positive bandwidth detected';
end
end

function summary = summarize_report(report)
summary = struct();
summary.total_items = 0;
summary.total_errors = length(report.errors);
summary.total_warnings = length(report.warnings);

for v = 1:length(report.versions)
    summary.total_items = summary.total_items + report.versions(v).num_items;
    for i = 1:length(report.versions(v).items)
        summary.total_errors = summary.total_errors + length(report.versions(v).items(i).errors);
        summary.total_warnings = summary.total_warnings + length(report.versions(v).items(i).warnings);
    end
end
end

function print_summary(report)
fprintf('\n=== TWC Dataset Check Summary ===\n');
fprintf('Root: %s\n', report.root);
fprintf('Versions: %d\n', length(report.versions));
fprintf('Items checked: %d\n', report.summary.total_items);
fprintf('Errors: %d, Warnings: %d\n', ...
    report.summary.total_errors, report.summary.total_warnings);

if ~isempty(report.errors)
    fprintf('\nTop-level errors:\n');
    for i = 1:length(report.errors)
        fprintf('- %s\n', report.errors{i});
    end
end

if ~isempty(report.warnings)
    fprintf('\nTop-level warnings:\n');
    for i = 1:length(report.warnings)
        fprintf('- %s\n', report.warnings{i});
    end
end

for v = 1:length(report.versions)
    vinfo = report.versions(v);
    fprintf('\n[%s] json=%d mat=%d checked=%d\n', ...
        vinfo.name, vinfo.num_json, vinfo.num_mat, vinfo.num_items);
    item_errors = 0;
    item_warnings = 0;
    for i = 1:length(vinfo.items)
        item_errors = item_errors + length(vinfo.items(i).errors);
        item_warnings = item_warnings + length(vinfo.items(i).warnings);
    end
    fprintf('  Item errors: %d, Item warnings: %d\n', item_errors, item_warnings);
end
fprintf('=================================\n');
end

function ids = strip_extension(names, ext)
ids = cell(size(names));
for i = 1:length(names)
    name = names{i};
    if endsWith(name, ext)
        ids{i} = name(1:end-length(ext));
    else
        ids{i} = name;
    end
end
end

function table_struct = count_strings(values)
u = unique(values);
counts = zeros(size(u));
for i = 1:length(u)
    counts(i) = sum(values == u(i));
end
table_struct = struct('value', u, 'count', counts);
end

function print_table(title_str, table_struct)
fprintf('\n%s:\n', title_str);
for i = 1:length(table_struct.value)
    fprintf('  %-24s %d\n', table_struct.value(i), table_struct.count(i));
end
end

function plot_spectrum(x, sr)
n = length(x);
window = hann(n);
xf = fftshift(fft(x .* window));
f = (-n/2:n/2-1) * (sr/n);
psd = 20*log10(abs(xf) + eps);
plot(f, psd);
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)'); grid on;
end
