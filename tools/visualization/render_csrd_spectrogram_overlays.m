function summary = render_csrd_spectrogram_overlays(varargin)
%RENDER_CSRD_SPECTROGRAM_OVERLAYS Render IQ spectrograms with GT boxes.
% 中文说明：把 CSRD 生成的接收 IQ 数据渲染为频谱图，并叠加 annotation v2 的时频真值矩形框。
%
% Inputs / 输入:
%   'DataRoot' - generated dataset root containing session/scenarios/*.mat.
%   'OutputRoot' - artifact directory for PNG images and contact sheet.
%   'MaxImages' - maximum receiver-frame images to render.
%   'RequireRectangles' - assert every rendered image has at least one GT box.
%
% Outputs / 输出:
%   summary - struct with rendered image paths and rectangle counts.

p = inputParser;
addParameter(p, 'DataRoot', fullfile(pwd, 'data'), @(x) ischar(x) || isstring(x));
addParameter(p, 'OutputRoot', fullfile(pwd, 'artifacts', 'visual_checks', 'csrd'), ...
    @(x) ischar(x) || isstring(x));
addParameter(p, 'MaxImages', 12, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'RequireRectangles', true, @islogical);
addParameter(p, 'SelectionMode', 'first', @(x) ischar(x) || isstring(x));
addParameter(p, 'MinRectangles', 1, @(x) isnumeric(x) && isscalar(x) && x >= 0);
parse(p, varargin{:});

dataRoot = char(string(p.Results.DataRoot));
outputRoot = char(string(p.Results.OutputRoot));
maxImages = double(p.Results.MaxImages);
selectionMode = lower(char(string(p.Results.SelectionMode)));
minRectangles = double(p.Results.MinRectangles);

assert(exist(dataRoot, 'dir') == 7, ...
    'CSRD:VisualCheck:MissingDataRoot', ...
    'DataRoot does not exist: %s', dataRoot);
if ~exist(outputRoot, 'dir')
    mkdir(outputRoot);
end

matFiles = dir(fullfile(dataRoot, '**', 'scenarios', 'scenario_*_data.mat'));
assert(~isempty(matFiles), ...
    'CSRD:VisualCheck:NoScenarioData', ...
    'No scenario data .mat files found under %s.', dataRoot);
matFiles = localOrderMatFiles(matFiles, selectionMode);

records = repmat(struct('ImagePath', "", 'AnnotationPath', "", ...
    'DataPath', "", 'FrameIndex', 0, 'ReceiverID', "", ...
    'RectangleCount', 0), 0, 1);

for m = 1:numel(matFiles)
    if numel(records) >= maxImages
        break;
    end
    dataPath = fullfile(matFiles(m).folder, matFiles(m).name);
    annotationPath = localAnnotationPathForDataPath(dataPath);
    if exist(annotationPath, 'file') ~= 2
        continue;
    end

    loaded = load(dataPath, 'scenarioData');
    result = csrd.pipeline.annotation.readAnnotationV2(annotationPath, ...
        'RequireSources', true, 'RequireRuntimeHeader', true);
    frameCells = localFrameCells(loaded.scenarioData);

    for frameIdx = 1:numel(frameCells)
        if numel(records) >= maxImages
            break;
        end
        rxCells = localReceiverCells(frameCells{frameIdx});
        for rxIdx = 1:numel(rxCells)
            if numel(records) >= maxImages
                break;
            end
            rxFrame = rxCells{rxIdx};
            if ~isstruct(rxFrame) || ~isfield(rxFrame, 'Signal') || isempty(rxFrame.Signal)
                continue;
            end
            fs = localSampleRate(rxFrame);
            duration = numel(rxFrame.Signal) / fs;
            receiverId = localReceiverId(rxFrame, rxIdx);
            sources = localSourcesForFrame(result.Frames, frameIdx, receiverId);
            rectEstimate = localCountRectangles(sources, fs);
            if rectEstimate < minRectangles
                continue;
            end
            imageName = sprintf('%03d_%s_frame%03d_rx%s.png', ...
                numel(records) + 1, localSafeName(localCaseName(dataPath)), ...
                frameIdx, localSafeName(receiverId));
            imagePath = fullfile(outputRoot, imageName);
            rectCount = localRenderOne(rxFrame.Signal, fs, duration, sources, imagePath);
            if p.Results.RequireRectangles
                assert(rectCount > 0, ...
                    'CSRD:VisualCheck:NoRectangles', ...
                    'Rendered %s without any annotation rectangles.', imagePath);
            end
            records(end + 1) = struct( ... %#ok<AGROW>
                'ImagePath', string(imagePath), ...
                'AnnotationPath', string(annotationPath), ...
                'DataPath', string(dataPath), ...
                'FrameIndex', frameIdx, ...
                'ReceiverID', string(receiverId), ...
                'RectangleCount', rectCount);
        end
    end
end

assert(~isempty(records), ...
    'CSRD:VisualCheck:NoRenderedImages', ...
    'No spectrogram overlay images were rendered from %s.', dataRoot);

summary = struct();
summary.DataRoot = string(dataRoot);
summary.OutputRoot = string(outputRoot);
summary.ImagesRendered = numel(records);
summary.RectanglesDrawn = sum([records.RectangleCount]);
summary.Records = records;

localWriteContactSheet(outputRoot, summary);
end


function matFiles = localOrderMatFiles(matFiles, selectionMode)
% localOrderMatFiles - Prefer visually rich cases when requested.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：在 diverse 模式下优先选择多 Tx/多 burst、OSM building/flat 和调制覆盖样本。
if ~strcmp(selectionMode, 'diverse')
    return;
end
scores = zeros(numel(matFiles), 1);
for k = 1:numel(matFiles)
    fullPath = lower(fullfile(matFiles(k).folder, matFiles(k).name));
    score = 0;
    if contains(fullPath, 'multi_burst'); score = score + 100; end
    if contains(fullPath, 'multi_tx'); score = score + 90; end
    if contains(fullPath, 'osm_rt_building'); score = score + 60; end
    if contains(fullPath, 'osm_rt_flatterrain'); score = score + 45; end
    if contains(fullPath, '\mod_') || contains(fullPath, '/mod_'); score = score + 20; end
    scores(k) = score;
end
[~, order] = sortrows([-scores, (1:numel(matFiles)).']);
matFiles = matFiles(order);
end


function annotationPath = localAnnotationPathForDataPath(dataPath)
% localAnnotationPathForDataPath - Resolve sibling annotation path.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：根据 scenarios/scenario_x_data.mat 找到同 session 下的 annotation JSON。
[sessionScenariosDir, fileName] = fileparts(dataPath);
sessionDir = fileparts(sessionScenariosDir);
scenarioId = regexp(fileName, 'scenario_(\d+)_data', 'tokens', 'once');
assert(~isempty(scenarioId), ...
    'CSRD:VisualCheck:BadDataName', ...
    'Unexpected scenario data filename: %s', dataPath);
annotationPath = fullfile(sessionDir, 'annotations', ...
    sprintf('scenario_%s_annotation.json', scenarioId{1}));
end


function frames = localFrameCells(scenarioData)
% localFrameCells - Normalize scenarioData into a row cell array of frames.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：把保存的 scenarioData 标准化为按帧索引的 cell 数组。
if iscell(scenarioData)
    frames = scenarioData;
else
    frames = {scenarioData};
end
frames = reshape(frames, 1, []);
end


function rxCells = localReceiverCells(frameData)
% localReceiverCells - Normalize one frame into receiver cells.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：把单帧数据标准化为按接收机索引的 cell 数组。
if iscell(frameData)
    rxCells = frameData;
elseif isstruct(frameData)
    rxCells = num2cell(frameData);
else
    rxCells = {};
end
rxCells = reshape(rxCells, 1, []);
end


function fs = localSampleRate(rxFrame)
% localSampleRate - Read sample rate from a receiver frame.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：从接收机帧结构读取采样率并做正数校验。
assert(isfield(rxFrame, 'SampleRate') && isnumeric(rxFrame.SampleRate) && ...
    isscalar(rxFrame.SampleRate) && isfinite(rxFrame.SampleRate) && ...
    rxFrame.SampleRate > 0, ...
    'CSRD:VisualCheck:MissingSampleRate', ...
    'Receiver frame is missing a positive SampleRate.');
fs = double(rxFrame.SampleRate);
end


function receiverId = localReceiverId(rxFrame, rxIdx)
% localReceiverId - Resolve receiver identifier for annotation matching.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：读取接收机 ID，缺失时回退到 Rx<index>。
if isfield(rxFrame, 'ReceiverID') && ~isempty(rxFrame.ReceiverID)
    receiverId = char(string(rxFrame.ReceiverID));
else
    receiverId = sprintf('Rx%d', rxIdx);
end
end


function sources = localSourcesForFrame(frames, frameIdx, receiverId)
% localSourcesForFrame - Select annotation sources for one frame/receiver.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：按 FrameId 和 ReceiverID 匹配 annotation v2 中的信号源。
sources = {};
for k = 1:numel(frames)
    frame = frames{k};
    if ~isstruct(frame) || ~isfield(frame, 'FrameId') || ~isfield(frame, 'ReceiverID')
        continue;
    end
    if round(double(frame.FrameId)) ~= frameIdx || ...
            ~strcmp(char(string(frame.ReceiverID)), receiverId)
        continue;
    end
    sources = localFlattenSources(frame.SignalSources);
    return;
end
end


function sources = localFlattenSources(value)
% localFlattenSources - Normalize SignalSources into a cell array.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：把 SignalSources 的 struct/cell 形态标准化，便于绘制矩形框。
sources = {};
if isempty(value)
    return;
end
if isstruct(value)
    cells = num2cell(value);
    sources = reshape(cells, 1, []);
elseif iscell(value)
    for k = 1:numel(value)
        sources = [sources, localFlattenSources(value{k})]; %#ok<AGROW>
    end
end
end


function rectCount = localRenderOne(signal, fs, duration, sources, imagePath)
% localRenderOne - Render one spectrogram with time-frequency GT boxes.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：渲染单个接收机帧的频谱图，并叠加每个源的帧内时间-频率真值框。
signal = double(signal(:));
if ~isreal(signal)
    signal = complex(real(signal), imag(signal));
end
[t, f, powerDb] = localStft(signal, fs);

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1200, 700]);
cleanupFig = onCleanup(@() close(fig)); %#ok<NASGU>
imagesc(t, f / 1e6, powerDb);
axis xy;
colormap turbo;
colorbar;
xlabel('Time (s)');
ylabel('Frequency offset (MHz)');
title('CSRD received IQ spectrogram with annotation v2 time-frequency boxes');
hold on;

rectCount = 0;
for s = 1:numel(sources)
    src = sources{s};
    if ~isstruct(src) || ~isfield(src, 'ReceiverView') || ~isstruct(src.ReceiverView)
        continue;
    end
    rv = src.ReceiverView;
    if isfield(rv, 'IsVisible') && ~logical(rv.IsVisible)
        continue;
    end
    if ~isfield(rv, 'ProjectedLowerEdgeHz') || ~isfield(rv, 'ProjectedUpperEdgeHz')
        continue;
    end
    lowerHz = double(rv.ProjectedLowerEdgeHz);
    upperHz = double(rv.ProjectedUpperEdgeHz);
    if ~isfinite(lowerHz) || ~isfinite(upperHz) || upperHz <= lowerHz
        continue;
    end
    assert(lowerHz >= -fs / 2 - 1 && upperHz <= fs / 2 + 1, ...
        'CSRD:VisualCheck:RectangleOutOfBounds', ...
        'Annotation rectangle [%.3f, %.3f] Hz is outside receiver view +/- %.3f Hz.', ...
        lowerHz, upperHz, fs / 2);
    [x0, x1] = localSourceTimeBounds(src, duration);
    if x1 <= x0
        continue;
    end
    y = lowerHz / 1e6;
    h = (upperHz - lowerHz) / 1e6;
    rectangle('Position', [x0, y, x1 - x0, h], 'EdgeColor', 'r', ...
        'LineWidth', 1.5);
    label = localSourceLabel(src);
    text(max(x0 + duration * 0.005, eps), y + h, label, 'Color', 'w', ...
        'BackgroundColor', 'r', 'FontSize', 8, 'Interpreter', 'none');
    rectCount = rectCount + 1;
end
hold off;
exportgraphics(fig, imagePath, 'Resolution', 130);
end


function [x0, x1] = localSourceTimeBounds(src, duration)
% localSourceTimeBounds - Read frame-relative source time limits.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：从 annotation v2 的 Design/Execution 字段读取帧内 burst 起止时间。
x0 = 0;
x1 = duration;
if isfield(src, 'Truth') && isstruct(src.Truth)
    if isfield(src.Truth, 'Execution') && isstruct(src.Truth.Execution) && ...
            isfield(src.Truth.Execution, 'StartTimeSec') && ...
            isfield(src.Truth.Execution, 'EndTimeSec')
        x0 = double(src.Truth.Execution.StartTimeSec);
        x1 = double(src.Truth.Execution.EndTimeSec);
    elseif isfield(src.Truth, 'Design') && isstruct(src.Truth.Design) && ...
            isfield(src.Truth.Design, 'StartTimeSec') && ...
            isfield(src.Truth.Design, 'EndTimeSec')
        x0 = double(src.Truth.Design.StartTimeSec);
        x1 = double(src.Truth.Design.EndTimeSec);
    end
end
if ~isfinite(x0); x0 = 0; end
if ~isfinite(x1); x1 = duration; end
x0 = max(0, min(duration, x0));
x1 = max(0, min(duration, x1));
end


function [t, f, powerDb] = localStft(signal, fs)
% localStft - Minimal toolbox-light STFT for visual QA.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：用基础 FFT 实现轻量 STFT，避免频谱图工具依赖额外 toolbox。
n = numel(signal);
winLen = min(512, max(64, 2 ^ floor(log2(max(64, min(n, 512))))));
winLen = min(winLen, n);
if winLen < 16
    winLen = n;
end
hop = max(1, floor(winLen / 4));
nfft = max(256, 2 ^ nextpow2(winLen));
numFrames = max(1, floor((n - winLen) / hop) + 1);
window = 0.5 - 0.5 * cos(2 * pi * (0:winLen-1)' / max(winLen - 1, 1));
spec = zeros(nfft, numFrames);
t = zeros(1, numFrames);
for k = 1:numFrames
    idx = (1:winLen) + (k - 1) * hop;
    chunk = signal(idx) .* window;
    spec(:, k) = fftshift(abs(fft(chunk, nfft)).^2);
    t(k) = ((idx(1) + idx(end)) / 2 - 1) / fs;
end
f = ((-nfft/2):(nfft/2-1))' / nfft * fs;
powerDb = 10 * log10(spec + eps);
end


function label = localSourceLabel(src)
% localSourceLabel - Build a compact overlay label.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：为频谱图矩形框生成简短标签，包含 Tx、调制和业务/频段信息。
tx = localText(src, 'TxID', 'Tx');
modulation = '';
band = '';
if isfield(src, 'Truth') && isstruct(src.Truth) && ...
        isfield(src.Truth, 'Design') && isstruct(src.Truth.Design)
    modulation = localText(src.Truth.Design, 'ModulationFamily', '');
    if isfield(src.Truth.Design, 'Regulatory') && isstruct(src.Truth.Design.Regulatory)
        band = localText(src.Truth.Design.Regulatory, 'BandId', '');
    end
end
parts = {tx, modulation, band};
parts = parts(~cellfun(@isempty, parts));
label = strjoin(parts, ' / ');
end


function value = localText(s, fieldName, fallback)
% localText - Return a scalar text field or fallback.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：读取标注文本字段，缺失时返回默认文本。
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = char(string(s.(fieldName)));
else
    value = fallback;
end
end


function caseName = localCaseName(dataPath)
% localCaseName - Extract run folder name for output filenames.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：从数据路径中提取 run/case 名称，便于追踪图片来源。
parts = strsplit(dataPath, filesep);
caseName = 'case';
for k = 1:numel(parts)
    if strcmp(parts{k}, 'runs') && k < numel(parts)
        caseName = parts{k + 1};
        return;
    end
end
end


function safe = localSafeName(value)
% localSafeName - Make a filesystem-safe lowercase name.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：把 case/receiver 名称转为适合作为文件名的安全字符串。
safe = regexprep(char(string(value)), '[^A-Za-z0-9_]', '_');
safe = regexprep(safe, '_+', '_');
safe = lower(safe);
end


function rectCount = localCountRectangles(sources, fs)
% localCountRectangles - Count drawable annotation boxes before rendering.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：渲染前统计可绘制真值框数量，用于筛选多源/多 burst 目视样本。
rectCount = 0;
for s = 1:numel(sources)
    src = sources{s};
    if ~isstruct(src) || ~isfield(src, 'ReceiverView') || ~isstruct(src.ReceiverView)
        continue;
    end
    rv = src.ReceiverView;
    if isfield(rv, 'IsVisible') && ~logical(rv.IsVisible)
        continue;
    end
    if ~isfield(rv, 'ProjectedLowerEdgeHz') || ~isfield(rv, 'ProjectedUpperEdgeHz')
        continue;
    end
    lowerHz = double(rv.ProjectedLowerEdgeHz);
    upperHz = double(rv.ProjectedUpperEdgeHz);
    [x0, x1] = localSourceTimeBounds(src, 1);
    if isfinite(lowerHz) && isfinite(upperHz) && upperHz > lowerHz && ...
            lowerHz >= -fs / 2 - 1 && upperHz <= fs / 2 + 1 && x1 > x0
        rectCount = rectCount + 1;
    end
end
end


function localWriteContactSheet(outputRoot, summary)
% localWriteContactSheet - Write a Markdown index for visual inspection.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：写出 Markdown 目视检查索引，列出每张频谱图和矩形框数量。
sheetPath = fullfile(outputRoot, 'contact_sheet.md');
fid = fopen(sheetPath, 'w');
assert(fid > 0, 'Could not write visual contact sheet: %s', sheetPath);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '# CSRD Spectrogram Overlay Contact Sheet\n\n');
fprintf(fid, '- Data root: `%s`\n', summary.DataRoot);
fprintf(fid, '- Images rendered: %d\n', summary.ImagesRendered);
fprintf(fid, '- Rectangles drawn: %d\n\n', summary.RectanglesDrawn);
for k = 1:numel(summary.Records)
    [~, name, ext] = fileparts(summary.Records(k).ImagePath);
    fprintf(fid, '## %s%s\n\n', name, ext);
    fprintf(fid, '- Rectangles: %d\n', summary.Records(k).RectangleCount);
    fprintf(fid, '- Annotation: `%s`\n\n', summary.Records(k).AnnotationPath);
    fprintf(fid, '![%s](%s%s)\n\n', name, name, ext);
end
end
