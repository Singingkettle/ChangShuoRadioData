classdef runner < matlab.System
    % runner Radio Data Collection Runner
    % Manages and executes radio data collection simulations with progress tracking
    % and data storage capabilities.
    %
    % Properties:
    %   NumFrames - Number of frames to simulate
    %   Seed      - Random seed for reproducibility
    %   Log       - Logging configuration
    %   Data      - Data storage configuration
    %   Physical  - Physical layer simulation parameters
    %   UseParallel - Flag to enable parallel processing
    %   ParallelBatchSize - Number of frames to process in each parallel batch
    %   NumWorkers - Total number of workers for distributed processing
    %   WorkerId - Current worker ID (1 to NumWorkers)
    %
    % Methods:
    %   runner    - Constructor
    %   setupImpl - Initialize simulation environment
    %   stepImpl  - Execute simulation frames

    properties
        % Number of frames to simulate
        NumFrames

        % Random seed for reproducibility
        Seed

        % Logging configuration structure
        Log

        % Data storage configuration structure
        Data

        % Physical layer simulation parameters
        Physical

        % UseParallel - Flag to enable parallel processing
        % When true, uses parfor for frame processing
        UseParallel (1, 1) logical = false

        % ParallelBatchSize - Number of frames to process in each parallel batch
        % Smaller batches may improve load balancing but increase overhead
        ParallelBatchSize (1, 1) {mustBePositive, mustBeInteger} = 6

        % Total number of workers for distributed processing
        NumWorkers (1, 1) {mustBePositive, mustBeInteger} = 1

        % Current worker ID (1 to NumWorkers)
        WorkerId (1, 1) {mustBePositive, mustBeInteger} = 1
    end

    properties (Access = private)
        % The simulation engine configuration
        run

        % Logger instance for tracking simulation progress
        logger
    end

    methods

        function obj = runner(varargin)
            % Constructor for runner class
            % Args:
            %   varargin: Name-value pairs for setting object properties
            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)

        function obj = setupImpl(obj)
            % Initialize simulation environment
            % Sets up simulation engine, logging system, and directory structure

            % Configure simulation engine with physical layer parameters
            simEngine = sprintf("%s( " + ...
                "NumMaxTx=obj.Physical.NumMaxTx, " + ...
                "NumMaxRx=obj.Physical.NumMaxRx, " + ...
                "NumMaxTransmitTimes=obj.Physical.NumMaxTransmitTimes, " + ...
                "NumTransmitAntennasRange=obj.Physical.NumTransmitAntennasRange, " + ...
                "NumReceiveAntennasRange=obj.Physical.NumReceiveAntennasRange, " + ...
                "ADRatio=obj.Physical.ADRatio, " + ...
                "SymbolRateRange=obj.Physical.SymbolRateRange, " + ...
                "SymbolRateStep=obj.Physical.SymbolRateStep, " + ...
                "SamplePerSymbolRange=obj.Physical.SamplePerSymbolRange, " + ...
                "MessageLengthRange=obj.Physical.MessageLengthRange, " + ...
                "Message=obj.Physical.Message, " + ...
                "Event=obj.Physical.Event, " + ...
                "Modulate=obj.Physical.Modulate, " + ...
                "Transmit=obj.Physical.Transmit, " + ...
                "Channel=obj.Physical.Channel, " + ...
                "Receive=obj.Physical.Receive)", obj.Physical.handle);
            obj.run = eval(simEngine);

            % Initialize logger with timestamp
            currentTime = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
            log_name = sprintf("%s_%s", obj.Log.Name, currentTime);
            obj.logger = Log.getInstance(log_name);
            obj.logger.FileThreshold = obj.Log.FileThreshold;
            obj.logger.CommandWindowThreshold = obj.Log.CommandWindowThreshold;
            obj.logger.MessageReceivedEventThreshold = obj.Log.MessageReceivedEventThreshold;
            obj.logger.LogFolder = obj.Data.SaveFolder;
            obj.logger.RotationPeriod = "none";

            % Log initialization information
            obj.logger.info("Start Radio Data Collection by using %s.", obj.Physical.handle);
            obj.logger.info("The total number of frames: %d.", obj.NumFrames);

            % Set random seed for reproducibility
            rng(obj.Seed);
            obj.logger.info("Random seed set to %d.", obj.Seed);

            % Create and verify directory structure
            if ~exist(obj.Data.SaveFolder, 'dir')

                try
                    [status, msg] = mkdir(obj.Data.SaveFolder);

                    if ~status
                        obj.logger.error('Failed to create save directory: %s', msg);
                        error('Failed to create save directory');
                    end

                catch ME
                    obj.logger.error('Error creating save directory: %s', ME.message);
                    rethrow(ME);
                end

            end

            % Create required subdirectories for data storage
            subDirs = {'sequence_data', 'sequence_data/iq', 'anno'};

            for dirName = subDirs
                fullPath = fullfile(obj.Data.SaveFolder, dirName{1});

                if ~exist(fullPath, 'dir')

                    try
                        [status, msg] = mkdir(fullPath);

                        if ~status
                            obj.logger.error('Failed to create directory %s: %s', fullPath, msg);
                            error('Failed to create required directory');
                        end

                        obj.logger.debug('Created directory: %s', fullPath);
                    catch ME
                        obj.logger.error('Error creating directory %s: %s', fullPath, ME.message);
                        rethrow(ME);
                    end

                else
                    obj.logger.warning('Directory %s already exists', fullPath);
                end

            end

        end

        function stepImpl(obj, worker_id, num_workers)
            % Execute simulation frames distributed across workers
            % Args:
            %   worker_id: Optional worker ID (overrides obj.WorkerId if provided)
            %   num_workers: Total number of workers for distributed processing

            obj.WorkerId = worker_id;
            obj.NumWorkers = num_workers;

            % Validate worker configuration
            if obj.WorkerId > obj.NumWorkers
                error('Worker ID cannot be greater than total number of workers');
            end

            % Handle case where number of workers exceeds number of frames
            if obj.NumWorkers > obj.NumFrames
                obj.logger.warning('Number of workers (%d) exceeds number of frames (%d)', ...
                    obj.NumWorkers, obj.NumFrames);

                % If this worker's ID is greater than the number of frames, exit early
                if obj.WorkerId > obj.NumFrames
                    obj.logger.info('Worker %d: No frames to process (worker ID > total frames)', obj.WorkerId);
                    return;
                end

                % Adjust to one frame per worker for workers that have work
                startFrame = obj.WorkerId;
                endFrame = startFrame;
                workerFrames = 1;
            else
                % Normal case: Calculate frame range for this worker
                framesPerWorker = ceil(obj.NumFrames / obj.NumWorkers);
                startFrame = (obj.WorkerId - 1) * framesPerWorker + 1;
                endFrame = min(obj.WorkerId * framesPerWorker, obj.NumFrames);
                workerFrames = endFrame - startFrame + 1;
            end

            % Create necessary directories if they don't exist
            if ~exist(sprintf("%s/anno", obj.Data.SaveFolder), 'dir')
                mkdir(sprintf("%s/anno", obj.Data.SaveFolder));
            end

            if ~exist(sprintf("%s/sequence_data/iq", obj.Data.SaveFolder), 'dir')
                mkdir(sprintf("%s/sequence_data/iq", obj.Data.SaveFolder));
            end

            % Initialize timing tracking variables
            frameProcessTimes = zeros(1, workerFrames);
            simulationStartTime = tic;

            % Initialize progress bar
            barWidth = 50;

            % Check if parallel processing is enabled for local frames
            if obj.UseParallel
                % Initialize parallel pool if not already running
                if isempty(gcp('nocreate'))
                    obj.logger.info("Worker %d: Starting parallel pool...", obj.WorkerId);
                    parpool('local');
                end

                % Process frames in batches for better parallel performance
                numBatches = ceil(workerFrames / obj.ParallelBatchSize);

                for batchIdx = 1:numBatches
                    % Determine frame range for this batch
                    batchStartIdx = (batchIdx - 1) * obj.ParallelBatchSize + 1;
                    batchEndIdx = min(batchIdx * obj.ParallelBatchSize, workerFrames);
                    batchLocalFrames = batchStartIdx:batchEndIdx;
                    numBatchFrames = length(batchLocalFrames);

                    % Convert local frame indices to global frame indices
                    batchGlobalFrames = batchLocalFrames + startFrame - 1;

                    % Pre-allocate results for this batch
                    batchResults = cell(numBatchFrames, 1);
                    batchTimes = zeros(numBatchFrames, 1);

                    % Record batch start time
                    batchStartTime = tic;

                    % Process frames in parallel
                    parfor (i = 1:numBatchFrames, 0)
                        frameStartTime = tic;

                        % Execute frame simulation with global frame ID
                        frameResult = obj.run(batchGlobalFrames(i));

                        % Store results and timing
                        batchResults{i} = frameResult;
                        batchTimes(i) = toc(frameStartTime);
                    end

                    % Save results for each frame in the batch
                    for i = 1:numBatchFrames
                        globalFrameId = batchGlobalFrames(i);
                        localFrameId = batchLocalFrames(i);
                        out = batchResults{i};
                        frameTime = batchTimes(i);

                        % Save frame results
                        for RxId = 1:length(out)
                            x = out{RxId}.data;
                            % Remove data field from info structure
                            info = rmfield(out{RxId}, 'data');
                            info.filePrefix = sprintf("Frame_%06d_Rx_%04d", globalFrameId, RxId);

                            % Save metadata as JSON
                            s = jsonencode(info, 'PrettyPrint', true);
                            fid = fopen(sprintf("%s/anno/%s.json", obj.Data.SaveFolder, info.filePrefix), 'w');
                            fprintf(fid, s);
                            fclose(fid);

                            % Save IQ data as MAT file
                            save(sprintf("%s/sequence_data/iq/%s.mat", obj.Data.SaveFolder, info.filePrefix), "x");
                        end

                        % Update timing metrics
                        frameProcessTimes(localFrameId) = frameTime;
                    end

                    % Calculate batch statistics
                    batchTime = toc(batchStartTime);
                    avgFrameTime = mean(frameProcessTimes(1:batchEndIdx));
                    remainingFrames = workerFrames - batchEndIdx;
                    estimatedTimeRemaining = remainingFrames * avgFrameTime;
                    elapsedTime = toc(simulationStartTime);

                    % Format time strings for display
                    [remainTimeStr, elapsedTimeStr] = obj.formatTimeStrings(estimatedTimeRemaining, elapsedTime);

                    % Calculate progress percentage for this worker
                    progressPercent = (batchEndIdx / workerFrames) * 100;

                    % Create progress bar
                    completedWidth = round(progressPercent * barWidth / 100);
                    progressBar = ['[', repmat('=', 1, completedWidth), '>', repmat(' ', 1, barWidth - completedWidth), ']'];

                    % Log batch progress information
                    obj.logger.info("Worker %d: %s Batch %2d/%2d - Frames %3d-%-3d [%6.1f%%] | Batch Time: %8.2fs | Elapsed: %10s | Remain: %10s | Avg: %8.2fs", ...
                        obj.WorkerId, progressBar, batchIdx, numBatches, batchGlobalFrames(1), batchGlobalFrames(end), ...
                        progressPercent, batchTime, elapsedTimeStr, remainTimeStr, avgFrameTime);
                end

            else
                % Serial processing for this worker's frames
                for localFrameId = 1:workerFrames
                    % Calculate global frame ID
                    globalFrameId = localFrameId + startFrame - 1;

                    % Record frame start time
                    frameStartTime = tic;

                    % Execute frame simulation
                    out = obj.run(globalFrameId);

                    % Save frame results
                    for RxId = 1:length(out)
                        x = out{RxId}.data;
                        % Remove data field from info structure
                        info = rmfield(out{RxId}, 'data');
                        info.filePrefix = sprintf("Frame_%06d_Rx_%04d", globalFrameId, RxId);

                        % Save metadata as JSON
                        s = jsonencode(info, 'PrettyPrint', true);
                        fid = fopen(sprintf("%s/anno/%s.json", obj.Data.SaveFolder, info.filePrefix), 'w');
                        fprintf(fid, s);
                        fclose(fid);

                        % Save IQ data as MAT file
                        save(sprintf("%s/sequence_data/iq/%s.mat", obj.Data.SaveFolder, info.filePrefix), "x");
                    end

                    % Calculate timing metrics
                    frameTime = toc(frameStartTime);
                    frameProcessTimes(localFrameId) = frameTime;
                    avgFrameTime = mean(frameProcessTimes(1:localFrameId));
                    remainingFrames = workerFrames - localFrameId;
                    estimatedTimeRemaining = remainingFrames * avgFrameTime;
                    elapsedTime = toc(simulationStartTime);

                    % Format time strings for display
                    [remainTimeStr, elapsedTimeStr] = obj.formatTimeStrings(estimatedTimeRemaining, elapsedTime);

                    % Calculate progress percentage for this worker
                    progressPercent = (localFrameId / workerFrames) * 100;

                    % Create progress bar
                    completedWidth = round(progressPercent * barWidth / 100);
                    progressBar = ['[', repmat('=', 1, completedWidth), '>', repmat(' ', 1, barWidth - completedWidth), ']'];

                    % Log progress information with progress bar
                    obj.logger.info("Worker %d: %s Frame %3d/%-3d [%6.1f%%] | Time: %8.2fs | Elapsed: %10s | Remain: %10s | Avg: %8.2fs", ...
                        obj.WorkerId, progressBar, globalFrameId, endFrame, progressPercent, frameTime, elapsedTimeStr, remainTimeStr, avgFrameTime);
                end

            end

            % Log final worker statistics
            totalTime = toc(simulationStartTime);
            totalTimeStr = obj.formatTotalTime(totalTime);
            obj.logger.info("Worker %d complete | Frames %d-%d | Total time: %10s | Average frame time: %8.2fs", ...
                obj.WorkerId, startFrame, endFrame, totalTimeStr, mean(frameProcessTimes));
        end

    end

    methods (Access = private)

        function totalTimeStr = formatTotalTime(~, totalTime)
            % Format total simulation time
            % Returns formatted string for total runtime

            totalHours = floor(totalTime / 3600);
            totalMinutes = floor((totalTime - totalHours * 3600) / 60);
            totalSeconds = round(totalTime - totalHours * 3600 - totalMinutes * 60);

            if totalHours > 0
                totalTimeStr = sprintf('%d:%02d:%02d', totalHours, totalMinutes, totalSeconds);
            else
                totalTimeStr = sprintf('%02d:%02d', totalMinutes, totalSeconds);
            end

        end

        function [remainTimeStr, elapsedTimeStr] = formatTimeStrings(~, estimatedTimeRemaining, elapsedTime)
            % Format time strings for remaining and elapsed time
            % Returns formatted strings for display

            % Format remaining time
            remainHours = floor(estimatedTimeRemaining / 3600);
            remainMinutes = floor((estimatedTimeRemaining - remainHours * 3600) / 60);
            remainSeconds = round(estimatedTimeRemaining - remainHours * 3600 - remainMinutes * 60);

            if remainHours > 0
                remainTimeStr = sprintf('%d:%02d:%02d', remainHours, remainMinutes, remainSeconds);
            else
                remainTimeStr = sprintf('%02d:%02d', remainMinutes, remainSeconds);
            end

            % Format elapsed time
            elapsedHours = floor(elapsedTime / 3600);
            elapsedMinutes = floor((elapsedTime - elapsedHours * 3600) / 60);
            elapsedSeconds = round(elapsedTime - elapsedHours * 3600 - elapsedMinutes * 60);

            if elapsedHours > 0
                elapsedTimeStr = sprintf('%d:%02d:%02d', elapsedHours, elapsedMinutes, elapsedSeconds);
            else
                elapsedTimeStr = sprintf('%02d:%02d', elapsedMinutes, elapsedSeconds);
            end

        end

    end

end
