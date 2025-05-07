%% Convert CSRD Radio Data to COCO Format and MAT Spectrograms for Multiple Windows
%
% This script reads annotation data from JSON files and corresponding IQ data
% from .mat files, performs STFT using different window functions to generate
% spectrograms, and outputs for each window type:
%   1. COCO-style JSON annotation files split into train/val/test sets.
%   2. Spectrogram data saved as MATLAB (.mat) files.
%
% Dependencies:
%   - MATLAB Signal Processing Toolbox (for stft and window functions)
%
% Adjust STFT parameters, window configurations, and file paths as needed.

clear; close all; clc;

%% --- Configuration ---
enableVisualization = false; % Set to true to visualize bounding boxes (slows down processing)

baseDataPath = '../data/CSRD2025'; % Path to the dataset
annoDir = fullfile(baseDataPath, 'anno');
iqDir = fullfile(baseDataPath, 'sequence_data', 'iq');
outputAnnoBaseName = 'coco_annotations'; % Base name for output JSON files
outputMatDir = fullfile(baseDataPath, 'stft'); % Output dir for MAT files

% Split Ratios
trainRatio = 0.8;
valRatio = 0.1;
testRatio = 0.1; % Should sum to 1

if abs(trainRatio + valRatio + testRatio - 1.0) > 1e-6
    error('Split ratios must sum to 1.');
end

% STFT Parameters (Shared)
stftWindowLength = 256; % Window length
stftOverlapLength = 16; % Overlap length (ensure <= stftWindowLength)
stftFftLength = 512; % FFT length

% Window Configurations to Process
% Add more window functions from the Signal Processing Toolbox as needed
% Format: { 'WindowName', @windowFunctionHandle; ... }
% Example with parameters: { 'kaiser_5', {@kaiser, 5}; ... } - requires adjusting window creation logic
windowConfigs = { ...
                     'hamming', @hamming; ...
                     'hann', @hann; ...
                     'blackman', @blackman ...
% Add other windows like bartlett, triang, kaiser (handle beta param), etc.
                 };

% Create base output directory for MAT files if it doesn't exist
if ~exist(outputMatDir, 'dir')
    mkdir(outputMatDir);
    fprintf('Created base output directory for MAT files: %s\n', outputMatDir);
end

%% --- Main Loop for Each Window Type ---
overallStartTime = tic;

for winIdx = 1:size(windowConfigs, 1)
    windowName = windowConfigs{winIdx, 1};
    windowHandle = windowConfigs{winIdx, 2};

    fprintf('\n============================================================\n');
    fprintf('Processing with window: %s\n', windowName);
    fprintf('============================================================\n');

    windowStartTime = tic;

    % Construct the STFT window for this iteration
    try
        stftWindow = windowHandle(stftWindowLength, 'periodic');
    catch ME
        warning('Failed to create window "%s". Skipping. Error: %s', windowName, ME.message);
        continue;
    end

    % --- COCO Structure Initialization (Reset for each window) ---
    cocoData = struct();
    cocoData.info = struct('description', sprintf('CSRD Spectrogram Dataset (%s window)', windowName), ...
        'version', '1.0', 'year', 2024, 'date_created', datestr(now, 'yyyy/mm/dd'));
    cocoData.licenses = {struct('id', 1, 'name', 'Default License', 'url', '')};
    cocoData.images = [];
    cocoData.annotations = [];
    cocoData.categories = [];

    categoryIdMap = containers.Map('KeyType', 'char', 'ValueType', 'int32');
    nextCategoryId = 1;
    annotationId = 1;
    imageId = 1;
    processedImageCount = 0;
    imageIdToFrameIdMap = containers.Map('KeyType', 'double', 'ValueType', 'char'); % Map image ID to Frame ID string

    % --- Process Files for the current window ---
    jsonFiles = dir(fullfile(annoDir, 'Frame_*.json'));
    numFiles = length(jsonFiles);
    fprintf('Found %d JSON files to process for window %s...\n', numFiles, windowName);

    fileLoopStartTime = tic;

    % Create different output directories for each window type
    outputMatDir_window = fullfile(outputMatDir, windowName);

    if ~exist(outputMatDir_window, 'dir')
        mkdir(outputMatDir_window);
        fprintf('Created output directory for window %s: %s\n', windowName, outputMatDir_window);
    end

    for k = 1:numFiles
        jsonFileName = jsonFiles(k).name;
        jsonFilePath = fullfile(annoDir, jsonFileName);

        % Progress indicator within window loop
        if mod(k, 100) == 0
            fprintf('  Window %s: Processing file %d/%d: %s\n', windowName, k, numFiles, jsonFileName);
        end

        try
            % --- Load Metadata ---
            jsonContent = fileread(jsonFilePath);
            meta = jsondecode(jsonContent);

            % --- Validate basic structure ---
            if ~isfield(meta, 'annotation') || ~isfield(meta.annotation, 'rx') || ~isfield(meta.annotation, 'tx')
                warning('JSON file %s missing required top-level fields (annotation.rx, annotation.tx). Skipping.', jsonFileName);
                continue;
            end

            rxInfo = meta.annotation.rx;
            txArray = meta.annotation.tx;

            % --- Extract Frame ID from filename ---
            frameIdMatch = regexp(jsonFileName, 'Frame_(\d+)_Rx_', 'tokens');

            if isempty(frameIdMatch) || isempty(frameIdMatch{1})
                warning('Could not parse Frame ID from filename: %s. Skipping.', jsonFileName);
                continue;
            end

            frameIdStr = frameIdMatch{1}{1};

            % Ensure txArray is always a cell array for consistent processing
            if isstruct(txArray) % Handle struct array case (e.g., Frame_000002_Rx_0002)
                txArray = num2cell(txArray);
            elseif ~iscell(txArray) % Handle single struct or other invalid types

                if isscalar(txArray) && isstruct(txArray) % Single struct case
                    txArray = {txArray};
                else
                    warning('Unexpected data type (%s) for annotation.tx in %s. Skipping.', class(txArray), jsonFileName);
                    continue;
                end

            end

            % Now txArray should be a cell array

            % --- Construct IQ File Path ---
            [~, baseName, ~] = fileparts(jsonFileName);
            iqFileName = [baseName, '.mat'];
            iqFilePath = fullfile(iqDir, iqFileName);

            if ~exist(iqFilePath, 'file')
                % warning('IQ file not found, skipping: %s', iqFilePath);
                continue;
            end

            % --- Load IQ Data ---
            iqData = load(iqFilePath);

            if ~isfield(iqData, 'x') || isempty(iqData.x)
                % warning('IQ data ("x" variable) not found or empty in %s, skipping.', iqFileName);
                continue;
            end

            x = iqData.x;
            % Average across receive antennas if data is multi-channel (e.g., [samples x antennas])
            if size(x, 2) > 1
                x = mean(x, 2);
            end

            % --- Perform STFT ---
            if ~isfield(rxInfo, 'MasterClockRate') || isempty(rxInfo.MasterClockRate)
                warning('SampleRate (annotation.rx.MasterClockRate) missing in %s, skipping STFT.', jsonFileName);
                continue;
            end

            sampleRate = rxInfo.MasterClockRate;

            [s, f, t] = stft(x, sampleRate, 'Window', stftWindow, 'OverlapLength', stftOverlapLength, 'FFTLength', stftFftLength, 'FrequencyRange', 'centered');

            % --- Process STFT result ---
            % Keep complex result, separate real/imag parts, and stack as channels
            realPart = real(s);
            imagPart = imag(s);
            % Create a tensor [numFreqBins x numTimeBins x 2]
            stftTensor = cat(3, realPart, imagPart);

            % Get dimensions from the original STFT result (frequency x time)
            [numFreqBins, numTimeBins] = size(s);

            % --- Save STFT Tensor as MAT ---
            matFileName = sprintf('%s.mat', baseName);
            matFilePath = fullfile(outputMatDir_window, matFileName);

            try
                % Save the 2-channel tensor, plus frequency and time axes
                save(matFilePath, 'stftTensor', 'f', 't');
            catch ME
                warning('Failed to write MAT file: %s. Error: %s.', matFileName, ME.message);
                continue; % Skip adding image/annotations if saving fails
            end

            % --- Create COCO Image Entry ---
            currentImageId = imageId;
            imageEntry = struct();
            imageEntry.id = currentImageId;
            imageEntry.width = numTimeBins;
            imageEntry.height = numFreqBins;
            imageEntry.file_name = matFileName; % Use the MAT filename
            imageEntry.license = 1;
            imageEntry.date_captured = '';
            cocoData.images = [cocoData.images, imageEntry];
            imageIdToFrameIdMap(currentImageId) = frameIdStr; % Store mapping

            % --- Create COCO Annotation Entries ---
            annotationsForThisImage = [];
            % Iterate through each transmitter's data
            for txIdx = 1:length(txArray)
                txInfo = txArray{txIdx};
                txInfo.BandWidth = reshape(txInfo.BandWidth, [], 2);

                % Check for necessary fields within this txInfo
                requiredTxFields = {'ModulatorType', 'StartTimes', 'TimeDurations', 'CarrierFrequency', 'BandWidth'};

                if ~all(isfield(txInfo, requiredTxFields))
                    warning('Tx entry %d in %s missing required fields. Skipping events for this transmitter.', txIdx, jsonFileName);
                    continue;
                end

                % Ensure event arrays are consistent length
                numEventsInTx = length(txInfo.StartTimes);

                if length(txInfo.TimeDurations) ~= numEventsInTx || size(txInfo.BandWidth, 1) ~= numEventsInTx
                    warning('Inconsistent event array lengths for Tx entry %d in %s. Skipping events for this transmitter.', txIdx, jsonFileName);
                    continue;
                end

                % Iterate through each event for this transmitter
                for eventIdx = 1:numEventsInTx

                    % --- Get or Create Category ID ---
                    originalModType = txInfo.ModulatorType; % Keep original for mapping

                    % 1. Determine Supercategory using helper function
                    supercategoryName = getModulationSupercategory(originalModType);

                    % 2. Determine Specific Category Name based on Supercategory
                    categoryName = ''; % Initialize

                    try % Wrap name generation in try-catch for missing fields

                        switch supercategoryName
                            case 'OFDM'

                                if isfield(txInfo, 'ModulatorOrder') && ~isempty(txInfo.ModulatorOrder) && ...
                                        isfield(txInfo, 'baseModulatorType') && ~isempty(txInfo.baseModulatorType)
                                    categoryName = sprintf('%d-%s-%s', txInfo.ModulatorOrder, upper(txInfo.baseModulatorType), originalModType);
                                else
                                    warning('Missing ModulatorOrder or BaseModulator for OFDM type in %s. Using "OFDM".', jsonFileName);
                                    categoryName = 'OFDM'; % Fallback name
                                end

                            case {'PSK', 'QAM', 'PAM', 'APSK', 'ASK', 'CPM', 'FSK'}

                                if isfield(txInfo, 'ModulatorOrder') && ~isempty(txInfo.ModulatorOrder)
                                    categoryName = sprintf('%d-%s', txInfo.ModulatorOrder, originalModType);
                                else
                                    warning('Missing ModulatorOrder for %s type in %s. Using original type name.', supercategoryName, jsonFileName);
                                    categoryName = originalModType; % Fallback name
                                end

                            case {'AM', 'FM', 'PM'}
                                % Use the original type name directly for these categories
                                categoryName = originalModType;
                            case 'Unknown'
                                % Handled by the check below
                                categoryName = '';
                            otherwise % Should not happen if helper covers all cases
                                warning('Unhandled supercategory "%s" encountered.', supercategoryName);
                                categoryName = originalModType; % Fallback
                        end

                    catch nameGenError
                        warning('Error generating category name for %s: %s. Skipping annotation.', originalModType, nameGenError.message);
                        continue; % Skip this annotation if name generation fails
                    end

                    % Check if category name is valid
                    if isempty(categoryName) || strcmp(supercategoryName, 'Unknown')
                        warning('Modulation type (%s) could not be properly categorized or name generated. Skipping annotation.', originalModType);
                        continue;
                    end

                    % 3. Get/Create Category ID and Entry using specific categoryName
                    if ~isKey(categoryIdMap, categoryName)
                        categoryEntry = struct('id', nextCategoryId, 'name', categoryName, 'supercategory', supercategoryName);
                        cocoData.categories = [cocoData.categories, categoryEntry];
                        categoryIdMap(categoryName) = nextCategoryId;
                        currentCategoryId = nextCategoryId;
                        nextCategoryId = nextCategoryId + 1;
                    else
                        currentCategoryId = categoryIdMap(categoryName);
                    end

                    % --- Calculate Bounding Box [x, y, width, height] ---
                    % Convert times (seconds) to sample indices
                    try
                        eventStartTimeSec = txInfo.StartTimes(eventIdx);
                        eventDurationSec = txInfo.TimeDurations(eventIdx);
                        eventStartSample = round(eventStartTimeSec * sampleRate) + 1; % 1-based indexing
                        eventEndSample = round((eventStartTimeSec + eventDurationSec) * sampleRate);
                        % Ensure End >= Start
                        eventEndSample = max(eventStartSample, eventEndSample);

                        centerFreqHz = txInfo.CarrierFrequency;
                        % Bandwidth = Upper Freq - Lower Freq
                        bandwidthHz = txInfo.BandWidth(eventIdx, 2) - txInfo.BandWidth(eventIdx, 1);

                        if isempty(eventStartSample) || isempty(eventEndSample) || isempty(centerFreqHz) || isempty(bandwidthHz)
                            warning('Calculated event parameters are empty for Tx %d, Event %d in %s. Skipping annotation.', txIdx, eventIdx, jsonFileName);
                            continue;
                        end

                    catch paramError
                        warning('Error calculating event parameters for Tx %d, Event %d in %s: %s. Skipping annotation.', txIdx, eventIdx, jsonFileName, paramError.message);
                        continue;
                    end

                    % Map sample indices to time bins
                    samplesPerTimeBin = stftWindowLength - stftOverlapLength;
                    startTimeBin = max(1, floor((eventStartSample - 1) / samplesPerTimeBin) + 1);
                    endTimeBin = min(numTimeBins, ceil((eventEndSample - 1) / samplesPerTimeBin) + 1);
                    startTimeBin = min(startTimeBin, endTimeBin);
                    bbox_x = startTimeBin;
                    bbox_width = max(1, endTimeBin - startTimeBin + 1);

                    % Map center frequency and bandwidth to frequency bins
                    freqMin = centerFreqHz - bandwidthHz / 2;
                    freqMax = centerFreqHz + bandwidthHz / 2;
                    [~, startFreqIndex] = min(abs(f - freqMin));
                    [~, endFreqIndex] = min(abs(f - freqMax));
                    if startFreqIndex > endFreqIndex, [startFreqIndex, endFreqIndex] = deal(endFreqIndex, startFreqIndex); end
                    bbox_y = startFreqIndex;
                    bbox_height = max(1, endFreqIndex - startFreqIndex + 1);

                    % Clamp bounding box to image dimensions
                    bbox_x = max(1, min(bbox_x, numTimeBins));
                    bbox_y = max(1, min(bbox_y, numFreqBins));
                    bbox_width = min(bbox_width, numTimeBins - bbox_x + 1);
                    bbox_height = min(bbox_height, numFreqBins - bbox_y + 1);

                    % --- Visualize Bounding Box (Optional) ---
                    if enableVisualization

                        try
                            fprintf('Visualizing: %s, Tx:%d, Event:%d, Cat:%s\n', jsonFileName, txIdx, eventIdx, categoryName);
                            spectrogramDb = 10 * log10(abs(s) .^ 2 + eps); % Use dB scale for visualization
                            % Pass additional parameters for boundary lines
                            visualizeBoundingBox(spectrogramDb, f, t, sampleRate, ...
                                bbox_x, bbox_y, bbox_width, bbox_height, ...
                                centerFreqHz, bandwidthHz, eventStartSample, eventEndSample, ...
                                jsonFileName, eventIdx, categoryName);
                        catch vizError
                            warning('Visualization failed for %s, Event %d: %s', jsonFileName, eventIdx, vizError.message);
                        end

                    end

                    % Create Annotation
                    annotationEntry = struct();
                    annotationEntry.id = annotationId;
                    annotationEntry.image_id = currentImageId;
                    annotationEntry.category_id = currentCategoryId;
                    annotationEntry.segmentation = [];
                    annotationEntry.area = bbox_width * bbox_height;
                    annotationEntry.bbox = [bbox_x, bbox_y, bbox_width, bbox_height];
                    annotationEntry.iscrowd = 0;

                    annotationsForThisImage = [annotationsForThisImage, annotationEntry];
                    annotationId = annotationId + 1;
                end % End event loop (within tx)

            end % End tx loop

            cocoData.annotations = [cocoData.annotations, annotationsForThisImage];

            imageId = imageId + 1;
            processedImageCount = processedImageCount + 1;

        catch ME
            warning('Error processing file %s for window %s: %s', jsonFileName, windowName, ME.message);
            % fprintf('%s\n', ME.getReport('extended', 'on', 'hyperlinks', 'off')); % Verbose error
        end

    end % End of file processing loop for one window

    fileLoopEndTime = toc(fileLoopStartTime);
    fprintf('Finished processing %d files for window %s. Successfully added %d images. Time: %.2f seconds.\n', ...
        k, windowName, processedImageCount, fileLoopEndTime);

    %% --- Data Splitting (based on unique Frame IDs for the current window) ---
    fprintf('\nSplitting data for window: %s based on Frame IDs...\n', windowName);

    if processedImageCount == 0 || isempty(keys(imageIdToFrameIdMap))
        warning('No images were successfully processed for window %s. Skipping splitting.', windowName);
        continue; % Skip to the next window
    end

    % --- Get Unique Frame IDs for this window's processed images ---
    processedImageIds = cell2mat(keys(imageIdToFrameIdMap));
    processedFrameIds = values(imageIdToFrameIdMap);
    uniqueFrameIds = unique(processedFrameIds);
    numUniqueFrames = length(uniqueFrameIds);

    if numUniqueFrames == 0
        warning('No unique frames found for window %s images. Skipping splitting.', windowName);
        continue;
    end

    % --- Shuffle and Split Frame IDs ---
    rng('default'); % for reproducibility
    shuffledFrameIndices = randperm(numUniqueFrames);
    shuffledFrameIds = uniqueFrameIds(shuffledFrameIndices);

    numTrainFrames = floor(trainRatio * numUniqueFrames);
    numValFrames = floor(valRatio * numUniqueFrames);
    numTestFrames = numUniqueFrames - numTrainFrames - numValFrames; % Ensure all frames are used

    fprintf('  Total unique frames: %d\n', numUniqueFrames);
    fprintf('    Training frames:   %d (%.1f%%)\n', numTrainFrames, trainRatio * 100);
    fprintf('    Validation frames: %d (%.1f%%)\n', numValFrames, valRatio * 100);
    fprintf('    Testing frames:    %d (%.1f%%)\n', numTestFrames, (numTestFrames / numUniqueFrames) * 100);

    % Assign Frame IDs to splits
    trainFrameIdList = shuffledFrameIds(1:numTrainFrames);
    valFrameIdList = shuffledFrameIds(numTrainFrames + 1:numTrainFrames + numValFrames);
    testFrameIdList = shuffledFrameIds(numTrainFrames + numValFrames + 1:end);

    % Create maps for quick Frame ID lookup per split
    trainFrameIdMap = containers.Map(trainFrameIdList, true(1, numTrainFrames));
    valFrameIdMap = containers.Map(valFrameIdList, true(1, numValFrames));
    testFrameIdMap = containers.Map(testFrameIdList, true(1, numTestFrames));

    % --- Determine Image IDs for each split based on Frame ID ---
    trainImageIdList = [];
    valImageIdList = [];
    testImageIdList = [];

    allProcessedImageIds = cell2mat(keys(imageIdToFrameIdMap)); % Get all image IDs processed

    for imgId = allProcessedImageIds
        frameId = imageIdToFrameIdMap(imgId);

        if isKey(trainFrameIdMap, frameId)
            trainImageIdList = [trainImageIdList, imgId];
        elseif isKey(valFrameIdMap, frameId)
            valImageIdList = [valImageIdList, imgId];
        elseif isKey(testFrameIdMap, frameId)
            testImageIdList = [testImageIdList, imgId];
        end

    end

    % Create maps for quick Image ID lookup per split
    trainImageIds = containers.Map(trainImageIdList, true(1, length(trainImageIdList)));
    valImageIds = containers.Map(valImageIdList, true(1, length(valImageIdList)));
    testImageIds = containers.Map(testImageIdList, true(1, length(testImageIdList)));

    % --- Initialize and Populate Split COCO Structures ---
    cocoTrain = struct('info', cocoData.info, 'licenses', cocoData.licenses, 'categories', cocoData.categories, 'images', [], 'annotations', []);
    cocoVal = struct('info', cocoData.info, 'licenses', cocoData.licenses, 'categories', cocoData.categories, 'images', [], 'annotations', []);
    cocoTest = struct('info', cocoData.info, 'licenses', cocoData.licenses, 'categories', cocoData.categories, 'images', [], 'annotations', []);

    % Assign images to splits based on Image ID map
    for i = 1:length(cocoData.images)
        img = cocoData.images(i);

        if isKey(trainImageIds, img.id)
            cocoTrain.images = [cocoTrain.images, img];
        elseif isKey(valImageIds, img.id)
            cocoVal.images = [cocoVal.images, img];
        elseif isKey(testImageIds, img.id)
            cocoTest.images = [cocoTest.images, img];
        end

    end

    % Assign annotations to splits based on Image ID map
    for i = 1:length(cocoData.annotations)
        ann = cocoData.annotations(i);

        if isKey(trainImageIds, ann.image_id)
            cocoTrain.annotations = [cocoTrain.annotations, ann];
        elseif isKey(valImageIds, ann.image_id)
            cocoVal.annotations = [cocoVal.annotations, ann];
        elseif isKey(testImageIds, ann.image_id)
            cocoTest.annotations = [cocoTest.annotations, ann];
        end

    end

    %% --- Save Split COCO JSON Files (for the current window) ---
    splitData = {cocoTrain, cocoVal, cocoTest};
    splitNames = {'train', 'val', 'test'};

    for i = 1:length(splitNames)
        % Include window name in the JSON filename
        outputFile = fullfile(baseDataPath, sprintf('%s_%s_%s.json', outputAnnoBaseName, windowName, splitNames{i}));
        fprintf('  Saving %s annotations (%d images, %d annotations) to %s...\n', ...
            splitNames{i}, length(splitData{i}.images), length(splitData{i}.annotations), outputFile);

        try
            jsonStr = jsonencode(splitData{i}, 'PrettyPrint', true);
            fid = fopen(outputFile, 'w');
            if fid == -1, error('Cannot open file for writing: %s', outputFile); end
            fprintf(fid, '%s', jsonStr);
            fclose(fid);
            fprintf('  %s annotation file saved successfully.\n', splitNames{i});
        catch ME
            warning('Failed to save %s JSON file for window %s: %s', splitNames{i}, windowName, ME.message);
        end

    end

    windowEndTime = toc(windowStartTime);
    fprintf('Finished processing and splitting for window %s. Time: %.2f seconds.\n', windowName, windowEndTime);

end % End of window type loop

overallEndTime = toc(overallStartTime);
fprintf('\n============================================================\n');
fprintf('Finished processing all window types. Total script time: %.2f seconds.\n', overallEndTime);
fprintf('============================================================\n');

%% --- Helper Functions ---

function supercat = getModulationSupercategory(modType)
    % Maps a specific modulation type string to a broader supercategory.
    if isempty(modType), supercat = 'Unknown'; return; end

    modTypeUpper = upper(modType);

    switch modTypeUpper
        case {'DSBAM', 'SSBAM', 'VSBAM'}
            supercat = 'AM';
        case {'FM', 'PM', 'FSK'}
            supercat = modTypeUpper;
        case {'ASK', 'OOK', '2ASK', '4ASK', '8ASK'}
            supercat = 'ASK';
        case {'CPFSK', 'GFSK', 'GMSK', 'MSK'}
            supercat = 'CPM';
        case {'APSK', 'APSK2', 'APSK4', 'APSK8', 'APSK16', 'APSK32', 'APSK64', 'APSK128', 'APSK256', 'DVBSAPSK'}
            supercat = 'APSK';
        case {'PSK', 'BPSK', 'QPSK', '8PSK', '16PSK', 'DPSK', 'OQPSK'}
            supercat = 'PSK';
        case {'QAM', '16QAM', '32QAM', '64QAM', '128QAM', '256QAM', 'Mill88QAM'}
            supercat = 'QAM';
        case {'PAM', '4PAM', '8PAM'}
            supercat = 'PAM';
        case {'OFDM', 'OTFS', 'SCFDMA'}
            supercat = 'OFDM';
            % Add more specific cases or pattern matching if needed
        otherwise
            % Attempt basic pattern matching for common prefixes
            if startsWith(modTypeUpper, 'QAM'), supercat = 'QAM';
            elseif startsWith(modTypeUpper, 'PSK'), supercat = 'PSK';
            elseif startsWith(modTypeUpper, 'FSK'), supercat = 'FSK';
            elseif startsWith(modTypeUpper, 'ASK'), supercat = 'ASK';
            elseif startsWith(modTypeUpper, 'PAM'), supercat = 'PAM';
            else
                supercat = 'Unknown';
                warning('Unknown modulation type for supercategory mapping: %s', modType);
            end

    end

end

function visualizeBoundingBox(spectrogramData, f, t, sampleRate, ...
        bbox_x, bbox_y, bbox_width, bbox_height, ...
        centerFreqHz, bandwidthHz, eventStartSample, eventEndSample, ...
        fileName, eventIdx, categoryName)
    % Displays the spectrogram and the calculated bounding box for an event.

    figure; % Create a new figure for each visualization
    imagesc(t, f, spectrogramData); % Use imagesc for better performance with large data
    axis xy; % Ensure frequency axis is oriented correctly (low to high)
    colorbar;
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    titleStr = sprintf('%s - Event %d (%s)', strrep(fileName, '_', '\_'), eventIdx, categoryName);
    title(titleStr);

    % --- Draw Bounding Box Rectangle (from bin indices) ---
    hold on; % Ensure subsequent plots are overlaid

    try
        % Start time and frequency from indices
        rect_x = t(bbox_x);
        rect_y = f(bbox_y);

        % End time and frequency bins
        end_time_bin = min(bbox_x + bbox_width - 1, length(t));
        end_freq_bin = min(bbox_y + bbox_height - 1, length(f));

        % Width and height in data units
        time_step = mean(diff(t)); if isnan(time_step) || time_step == 0, time_step = t(end); end % Handle single time bin
        freq_step = mean(diff(f)); if isnan(freq_step) || freq_step == 0, freq_step = f(end) - f(1); end % Handle single freq bin

        rect_w = t(end_time_bin) - t(bbox_x) + time_step / 2;
        rect_h = f(end_freq_bin) - f(bbox_y) + freq_step / 2;
        rect_w = max(rect_w, time_step / 2);
        rect_h = max(rect_h, freq_step / 2);

        % Draw the rectangle (Red, Solid)
        rectangle('Position', [rect_x, rect_y, rect_w, rect_h], ...
            'EdgeColor', 'r', ...
            'LineWidth', 1.5, ...
            'LineStyle', '-');

        fprintf('  Rectangle Time: [%.4f, %.4f], Freq: [%.1f, %.1f]\n', rect_x, rect_x + rect_w, rect_y, rect_y + rect_h);

    catch rectError
        warning('Could not draw rectangle for event %d in %s: %s', eventIdx, fileName, rectError.message);
    end

    % --- Draw Nominal Boundary Lines (from metadata) ---
    try
        % Calculate nominal time boundaries from samples
        timeStartMeta = (eventStartSample - 1) / sampleRate; % Time of first sample
        timeEndMeta = (eventEndSample -1) / sampleRate; % Time of last sample

        % Calculate nominal frequency boundaries
        freqLowMeta = centerFreqHz - bandwidthHz / 2;
        freqHighMeta = centerFreqHz + bandwidthHz / 2;

        % Get plot limits
        xLims = xlim;
        yLims = ylim;

        % Plot vertical time lines (Magenta, Dashed)
        line([timeStartMeta timeStartMeta], yLims, 'Color', 'm', 'LineStyle', '--', 'LineWidth', 1);
        line([timeEndMeta timeEndMeta], yLims, 'Color', 'm', 'LineStyle', '--', 'LineWidth', 1);

        % Plot horizontal frequency lines (Magenta, Dashed)
        line(xLims, [centerFreqHz centerFreqHz], 'Color', 'm', 'LineStyle', '--', 'LineWidth', 1);
        line(xLims, [freqLowMeta freqLowMeta], 'Color', 'm', 'LineStyle', '--', 'LineWidth', 1);
        line(xLims, [freqHighMeta freqHighMeta], 'Color', 'm', 'LineStyle', '--', 'LineWidth', 1);

        fprintf('  Nominal   Time: [%.4f, %.4f], Freq: [%.1f, %.1f, %.1f]\n', timeStartMeta, timeEndMeta, freqLowMeta, centerFreqHz, freqHighMeta);

    catch lineError
        warning('Could not draw boundary lines for event %d in %s: %s', eventIdx, fileName, lineError.message);
    end

    hold off;

    drawnow; % Ensure the plot is displayed

end
