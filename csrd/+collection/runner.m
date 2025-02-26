classdef runner < matlab.System

    properties
        NumFrames
        Seed
        Log
        Data
        Physical
    end

    properties (Access = private)
        % The configuration file
        run
        logger
    end

    methods

        function obj = runner(varargin)

            setProperties(obj, nargin, varargin{:});

        end

    end

    methods (Access = protected)

        function obj = setupImpl(obj)
            % Load the configuration file
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

            % Init the obj.logger
            currentTime = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
            log_name = sprintf("%s_%s", obj.Log.Name, currentTime);
            obj.logger = Log.getInstance(log_name);
            obj.logger.FileThreshold = obj.Log.FileThreshold;
            obj.logger.CommandWindowThreshold = obj.Log.CommandWindowThreshold;
            obj.logger.MessageReceivedEventThreshold = obj.Log.MessageReceivedEventThreshold;
            obj.logger.LogFolder = obj.Data.SaveFolder;
            obj.logger.RotationPeriod = "none";

            obj.logger.info("Start Radio Data Collection by using %s.", obj.Physical.handle);
            % Set the number of frames
            obj.logger.info("The total number of frames: %d.", obj.NumFrames);
            % Set the seed
            rng(obj.Seed);
            obj.logger.info("Random seed set to %d.", obj.Seed);

            % Verify and create save directory first
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

            % Create required subdirectories
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
                    % delete the directory
                    rmdir(fullPath, 's');
                    % create the directory
                    mkdir(fullPath);
                end

            end

        end

        function stepImpl(obj)
            % 添加时间跟踪变量
            frameProcessTimes = zeros(1, obj.NumFrames);
            simulationStartTime = tic;

            % modulate
            for FrameId = 1:obj.NumFrames
                % 记录帧开始时间
                frameStartTime = tic;

                % 执行原有逻辑
                out = obj.run(FrameId);

                for RxId = 1:length(out)
                    x = out{RxId}.data;
                    % struct delete field
                    info = rmfield(out{RxId}, 'data');
                    info.filePrefix = sprintf("Frame_%06d_Rx_%04d", FrameId, RxId);
                    % save the info as json
                    s = jsonencode(info, 'PrettyPrint', true);
                    fid = fopen(sprintf("%s/anno/%s.json", obj.Data.SaveFolder, info.filePrefix), 'w');
                    fprintf(fid, s);
                    fclose(fid);
                    % save the x as a matrix
                    save(sprintf("%s/sequence_data/iq/%s.mat", obj.Data.SaveFolder, info.filePrefix), "x");
                end

                % 计算并记录帧处理时间
                frameTime = toc(frameStartTime);
                frameProcessTimes(FrameId) = frameTime;

                % 计算平均帧处理时间和估计剩余时间
                avgFrameTime = mean(frameProcessTimes(1:FrameId));
                remainingFrames = obj.NumFrames - FrameId;
                estimatedTimeRemaining = remainingFrames * avgFrameTime;

                % 计算已运行时间
                elapsedTime = toc(simulationStartTime);

                % 格式化时间显示（内联代码代替函数调用）
                % 格式化剩余时间
                remainHours = floor(estimatedTimeRemaining / 3600);
                remainMinutes = floor((estimatedTimeRemaining - remainHours * 3600) / 60);
                remainSeconds = round(estimatedTimeRemaining - remainHours * 3600 - remainMinutes * 60);

                if remainHours > 0
                    remainTimeStr = sprintf('%d:%02d:%02d', remainHours, remainMinutes, remainSeconds);
                else
                    remainTimeStr = sprintf('%02d:%02d', remainMinutes, remainSeconds);
                end

                % 格式化已运行时间
                elapsedHours = floor(elapsedTime / 3600);
                elapsedMinutes = floor((elapsedTime - elapsedHours * 3600) / 60);
                elapsedSeconds = round(elapsedTime - elapsedHours * 3600 - elapsedMinutes * 60);

                if elapsedHours > 0
                    elapsedTimeStr = sprintf('%d:%02d:%02d', elapsedHours, elapsedMinutes, elapsedSeconds);
                else
                    elapsedTimeStr = sprintf('%02d:%02d', elapsedMinutes, elapsedSeconds);
                end

                % 计算进度百分比
                progressPercent = (FrameId / obj.NumFrames) * 100;

                % 使用固定宽度格式化输出进度信息
                obj.logger.info("Frame %3d/%-3d [%3.1f%%] | Time: %8.2fs | Elapsed: %10s | Remain: %10s | Avg: %8.2fs", ...
                    FrameId, obj.NumFrames, progressPercent, frameTime, elapsedTimeStr, remainTimeStr, avgFrameTime);
            end

            % 输出总运行时间
            totalTime = toc(simulationStartTime);
            totalHours = floor(totalTime / 3600);
            totalMinutes = floor((totalTime - totalHours * 3600) / 60);
            totalSeconds = round(totalTime - totalHours * 3600 - totalMinutes * 60);

            if totalHours > 0
                totalTimeStr = sprintf('%d:%02d:%02d', totalHours, totalMinutes, totalSeconds);
            else
                totalTimeStr = sprintf('%02d:%02d', totalMinutes, totalSeconds);
            end

            % 输出总运行时间，保持格式一致
            obj.logger.info("Simulation complete | Total time: %10s | Average frame time: %8.2fs", ...
                totalTimeStr, mean(frameProcessTimes));
        end

    end

end
