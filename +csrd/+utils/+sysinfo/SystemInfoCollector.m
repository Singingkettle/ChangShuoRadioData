classdef SystemInfoCollector < handle
    % SystemInfoCollector - System configuration information collector for CSRD framework
    %
    % This class provides comprehensive system configuration collection capabilities
    % including hardware (CPU, memory, disk, GPU) and software (MATLAB, OS, toolboxes)
    % information for CSRD simulation sessions.
    %
    % Key Features:
    %   - Hardware configuration detection (CPU, Memory, GPU, Disk)
    %   - Software environment analysis (MATLAB, OS, Toolboxes)
    %   - Simulation environment setup verification
    %   - Beautifully formatted log output with proper alignment
    %   - Cross-platform compatibility (Windows, Linux, macOS)
    %
    % Usage:
    %   % Collect and log system information
    %   collector = csrd.utils.sysinfo.SystemInfoCollector();
    %   collector.collectAndLog(logger);
    %
    %   % Get system information as struct
    %   sysInfo = collector.getSystemInfo();
    %
    % See also: csrd.utils.logger.GlobalLogManager

    properties (Access = private)
        % Cached system information
        systemInfo struct

        % Collection timestamp
        collectionTime datetime
    end

    methods

        function obj = SystemInfoCollector()
            % SystemInfoCollector - Constructor
            %
            % Creates a new SystemInfoCollector instance ready for
            % system configuration information collection.

            obj.systemInfo = struct();
            obj.collectionTime = datetime('now');
        end

        function collectAndLog(obj, logger)
            % collectAndLog - Collect and log comprehensive system configuration
            %
            % This method collects detailed system configuration information and
            % logs it using the provided logger with beautiful formatting.
            %
            % Input Arguments:
            %   logger - GlobalLogManager logger object
            %
            % See also: csrd.utils.logger.GlobalLogManager

            try
                logger.info('=== CSRD System Configuration Report ===');
                logger.info('');

                % === HARDWARE CONFIGURATION ===
                logger.info('┌─────────────────────────────────────────────────────┐');
                logger.info('│                HARDWARE CONFIGURATION               │');
                logger.info('└─────────────────────────────────────────────────────┘');

                obj.collectHardwareInfo(logger);

                logger.info('');

                % === SOFTWARE CONFIGURATION ===
                logger.info('┌─────────────────────────────────────────────────────┐');
                logger.info('│                SOFTWARE CONFIGURATION               │');
                logger.info('└─────────────────────────────────────────────────────┘');

                obj.collectSoftwareInfo(logger);

                logger.info('');

                % === SIMULATION ENVIRONMENT ===
                logger.info('┌─────────────────────────────────────────────────────┐');
                logger.info('│              SIMULATION ENVIRONMENT                 │');
                logger.info('└─────────────────────────────────────────────────────┘');

                obj.collectSimulationEnvironmentInfo(logger);

                logger.info('');
                logger.info('=== End System Configuration Report ===');

            catch infoError
                logger.warning('Failed to collect complete system information: %s', infoError.message);
            end

        end

        function sysInfo = getSystemInfo(obj)
            % getSystemInfo - Get system information as struct
            %
            % Returns the collected system information as a structured data.
            %
            % Output Arguments:
            %   sysInfo - Comprehensive system information structure

            if isempty(fieldnames(obj.systemInfo))
                obj.collectSystemInfoSilent();
            end

            sysInfo = obj.systemInfo;
        end

    end

    methods (Access = private)

        function collectHardwareInfo(obj, logger)
            % collectHardwareInfo - Collect hardware configuration information

            try
                % CPU Information
                if ispc
                    [~, cpuInfo] = system('wmic cpu get name,numberofcores,numberoflogicalprocessors /format:list');
                    cpuLines = splitlines(cpuInfo);
                    cpuName = '';
                    cores = '';
                    threads = '';

                    for i = 1:length(cpuLines)
                        line = strtrim(cpuLines{i});

                        if startsWith(line, 'Name=')
                            cpuName = extractAfter(line, 'Name=');
                        elseif startsWith(line, 'NumberOfCores=')
                            cores = extractAfter(line, 'NumberOfCores=');
                        elseif startsWith(line, 'NumberOfLogicalProcessors=')
                            threads = extractAfter(line, 'NumberOfLogicalProcessors=');
                        end

                    end

                    if ~isempty(cpuName)
                        logger.info('  CPU Model:        %s', strtrim(cpuName));
                        obj.systemInfo.Hardware.CPU.Model = strtrim(cpuName);

                        if ~isempty(cores)
                            logger.info('  CPU Cores:        %s', cores);
                            obj.systemInfo.Hardware.CPU.Cores = str2double(cores);
                        end

                        if ~isempty(threads)
                            logger.info('  CPU Threads:      %s', threads);
                            obj.systemInfo.Hardware.CPU.Threads = str2double(threads);
                        end

                    end

                elseif ismac
                    [~, cpuInfo] = system('sysctl -n machdep.cpu.brand_string');
                    logger.info('  CPU Model:        %s', strtrim(cpuInfo));
                    obj.systemInfo.Hardware.CPU.Model = strtrim(cpuInfo);

                    [~, coreInfo] = system('sysctl -n hw.ncpu');
                    logger.info('  CPU Cores:        %s', strtrim(coreInfo));
                    obj.systemInfo.Hardware.CPU.Cores = str2double(strtrim(coreInfo));
                else
                    % Linux
                    [~, cpuInfo] = system('lscpu | grep "Model name" | cut -d: -f2');

                    if ~isempty(cpuInfo)
                        logger.info('  CPU Model:        %s', strtrim(cpuInfo));
                        obj.systemInfo.Hardware.CPU.Model = strtrim(cpuInfo);
                    end

                    [~, coreInfo] = system('nproc');

                    if ~isempty(coreInfo)
                        logger.info('  CPU Cores:        %s', strtrim(coreInfo));
                        obj.systemInfo.Hardware.CPU.Cores = str2double(strtrim(coreInfo));
                    end

                end

                % Memory Information
                memInfo = memory;

                if isfield(memInfo, 'MemAvailableAllArrays')
                    totalMemGB = memInfo.MemAvailableAllArrays / (1024 ^ 3);
                    logger.info('  Available Memory: %.2f GB', totalMemGB);
                    obj.systemInfo.Hardware.Memory.Available = totalMemGB;
                end

                if isfield(memInfo, 'MemUsedMATLAB')
                    usedMemMB = memInfo.MemUsedMATLAB / (1024 ^ 2);
                    logger.info('  MATLAB Memory:    %.2f MB', usedMemMB);
                    obj.systemInfo.Hardware.Memory.MATLABUsed = usedMemMB;
                end

                % Disk Information for simulation directory
                currentDir = pwd;
                obj.systemInfo.Hardware.Disk.SimulationPath = currentDir;

                if ispc
                    driveLetter = currentDir(1:2);
                    logger.info('  Simulation Drive: %s', driveLetter);
                    obj.systemInfo.Hardware.Disk.Drive = driveLetter;

                    % Get disk space information
                    [~, diskSpace] = system(sprintf('dir "%s" /-c', driveLetter));
                    diskLines = splitlines(diskSpace);

                    for i = 1:length(diskLines)
                        line = diskLines{i};

                        if contains(line, 'bytes free')
                            logger.info('  Disk Space:       %s', strtrim(line));
                            obj.systemInfo.Hardware.Disk.FreeSpace = strtrim(line);
                            break;
                        end

                    end

                else
                    [~, diskInfo] = system(['df -h "' currentDir '"']);
                    diskLines = splitlines(diskInfo);

                    if length(diskLines) >= 2
                        logger.info('  Disk Space:       %s', strtrim(diskLines{2}));
                        obj.systemInfo.Hardware.Disk.FreeSpace = strtrim(diskLines{2});
                    end

                end

                % GPU Information
                try
                    gpuDevices = gpuDeviceTable;

                    if ~isempty(gpuDevices)
                        gpuCount = height(gpuDevices);
                        logger.info('  GPU Devices:      %d device(s) detected', gpuCount);
                        obj.systemInfo.Hardware.GPU.Count = gpuCount;
                        obj.systemInfo.Hardware.GPU.Devices = {};

                        for i = 1:min(gpuCount, 3) % Show up to 3 GPUs
                            gpuInfo = gpuDevices(i, :);
                            logger.info('    GPU %d:          %s', i, gpuInfo.Name{1});
                            logger.info('    GPU %d Memory:   %.2f GB', i, gpuInfo.TotalMemory / (1024 ^ 3));

                            obj.systemInfo.Hardware.GPU.Devices{i}.Name = gpuInfo.Name{1};
                            obj.systemInfo.Hardware.GPU.Devices{i}.Memory = gpuInfo.TotalMemory / (1024 ^ 3);
                        end

                    else
                        logger.info('  GPU Devices:      No GPU devices detected');
                        obj.systemInfo.Hardware.GPU.Count = 0;
                    end

                catch
                    logger.info('  GPU Devices:      GPU information unavailable');
                    obj.systemInfo.Hardware.GPU.Count = -1; % Unknown
                end

            catch hwError
                logger.warning('Failed to collect hardware information: %s', hwError.message);
            end

        end

        function collectSoftwareInfo(obj, logger)
            % collectSoftwareInfo - Collect software configuration information

            try
                % MATLAB Version Information
                matlabVer = version('-release');
                matlabVersionFull = version;
                logger.info('  MATLAB Version:   %s (%s)', matlabVersionFull, matlabVer);
                obj.systemInfo.Software.MATLAB.Version = matlabVersionFull;
                obj.systemInfo.Software.MATLAB.Release = matlabVer;

                % Operating System Information
                if ispc
                    [~, osInfo] = system('ver');
                    osInfo = strtrim(osInfo);
                    logger.info('  Operating System: %s', osInfo);
                    obj.systemInfo.Software.OS.Basic = osInfo;

                    % Get more detailed Windows version
                    [~, winVer] = system('wmic os get caption,version /format:list');
                    winLines = splitlines(winVer);

                    for i = 1:length(winLines)
                        line = strtrim(winLines{i});

                        if startsWith(line, 'Caption=')
                            caption = extractAfter(line, 'Caption=');

                            if ~isempty(caption)
                                logger.info('  Windows Edition:  %s', caption);
                                obj.systemInfo.Software.OS.Edition = caption;
                            end

                        elseif startsWith(line, 'Version=')
                            osVersion = extractAfter(line, 'Version=');

                            if ~isempty(osVersion)
                                logger.info('  Windows Version:  %s', osVersion);
                                obj.systemInfo.Software.OS.Version = osVersion;
                            end

                        end

                    end

                else
                    [~, osInfo] = system('uname -a');
                    osInfo = strtrim(osInfo);
                    logger.info('  Operating System: %s', osInfo);
                    obj.systemInfo.Software.OS.Basic = osInfo;
                end

                % MATLAB Toolboxes
                installedToolboxes = ver;
                toolboxCount = length(installedToolboxes);
                logger.info('  MATLAB Toolboxes: %d toolboxes installed', toolboxCount);
                obj.systemInfo.Software.MATLAB.ToolboxCount = toolboxCount;

                % List key toolboxes relevant to simulation
                keyToolboxes = {'Signal Processing Toolbox', 'Communications Toolbox', ...
                                    'DSP System Toolbox', 'Parallel Computing Toolbox', ...
                                    'Statistics and Machine Learning Toolbox', 'Simulink'};

                obj.systemInfo.Software.MATLAB.KeyToolboxes = struct();

                % Create a lookup map of installed toolboxes for efficient searching
                installedToolboxMap = containers.Map();

                for i = 1:length(installedToolboxes)
                    installedToolboxMap(installedToolboxes(i).Name) = installedToolboxes(i);
                end

                for i = 1:length(keyToolboxes)
                    toolboxName = keyToolboxes{i};
                    fieldName = matlab.lang.makeValidName(toolboxName);

                    if isKey(installedToolboxMap, toolboxName)
                        toolboxInfo = installedToolboxMap(toolboxName);
                        logger.info('    ✓ %s: %s', toolboxName, toolboxInfo.Version);
                        obj.systemInfo.Software.MATLAB.KeyToolboxes.(fieldName).Installed = true;
                        obj.systemInfo.Software.MATLAB.KeyToolboxes.(fieldName).Version = toolboxInfo.Version;
                    else
                        logger.info('    ✗ %s: Not installed', toolboxName);
                        obj.systemInfo.Software.MATLAB.KeyToolboxes.(fieldName).Installed = false;
                        obj.systemInfo.Software.MATLAB.KeyToolboxes.(fieldName).Version = '';
                    end

                end

                % Java Version
                javaVer = version('-java');
                logger.info('  Java Version:     %s', javaVer);
                obj.systemInfo.Software.Java.Version = javaVer;

            catch swError
                logger.warning('Failed to collect software information: %s', swError.message);
            end

        end

        function collectSimulationEnvironmentInfo(obj, logger)
            % collectSimulationEnvironmentInfo - Collect simulation-specific environment info

            try
                % Current working directory
                workDir = pwd;
                logger.info('  Working Directory: %s', workDir);
                obj.systemInfo.Environment.WorkingDirectory = workDir;

                % MATLAB path entries related to CSRD
                matlabPath = path;
                pathEntries = split(matlabPath, pathsep);
                csrdPaths = pathEntries(contains(pathEntries, 'CSRD', 'IgnoreCase', true) | ...
                    contains(pathEntries, 'ChangShuo', 'IgnoreCase', true));

                if ~isempty(csrdPaths)
                    logger.info('  CSRD Path Entries: %d entries found', length(csrdPaths));
                    obj.systemInfo.Environment.CSRDPaths = csrdPaths;

                    for i = 1:min(length(csrdPaths), 3) % Show first 3 entries
                        logger.info('    %s', csrdPaths{i});
                    end

                else
                    logger.info('  CSRD Path Entries: No CSRD-related paths found');
                    obj.systemInfo.Environment.CSRDPaths = {};
                end

                % Log directory information
                logDir = csrd.utils.logger.GlobalLogManager.getLogDirectory();

                if ~isempty(logDir)
                    logger.info('  Log Directory:     %s', logDir);
                    obj.systemInfo.Environment.LogDirectory = logDir;
                end

                % Session timestamp
                sessionTime = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
                logger.info('  Session Started:   %s', sessionTime);
                obj.systemInfo.Environment.SessionStartTime = sessionTime;

                % MATLAB process information
                processId = feature('getpid');
                logger.info('  MATLAB Process ID: %d', processId);
                obj.systemInfo.Environment.ProcessID = processId;

                % Random number generator state
                rngInfo = rng;
                logger.info('  RNG Algorithm:     %s', rngInfo.Type);
                logger.info('  RNG Seed:          %d', rngInfo.Seed);
                obj.systemInfo.Environment.RNG.Algorithm = rngInfo.Type;
                obj.systemInfo.Environment.RNG.Seed = rngInfo.Seed;

            catch envError
                logger.warning('Failed to collect simulation environment information: %s', envError.message);
            end

        end

        function collectSystemInfoSilent(obj)
            % collectSystemInfoSilent - Collect system information without logging
            %
            % This method collects system information and stores it in the
            % systemInfo property without producing log output.

            try
                % Create a dummy logger or collect info directly
                % For simplicity, we'll just populate basic info
                obj.systemInfo.CollectionTime = char(obj.collectionTime);
                obj.systemInfo.MATLAB.Version = version;
                obj.systemInfo.MATLAB.Release = version('-release');

                if ispc
                    [~, osInfo] = system('ver');
                    obj.systemInfo.OS = strtrim(osInfo);
                else
                    [~, osInfo] = system('uname -a');
                    obj.systemInfo.OS = strtrim(osInfo);
                end

            catch
                % If silent collection fails, just set basic info
                obj.systemInfo.CollectionTime = char(obj.collectionTime);
                obj.systemInfo.MATLAB.Version = version;
            end

        end

    end

    methods (Static)

        function collector = getInstance()
            % getInstance - Get a singleton instance of SystemInfoCollector
            %
            % Returns a singleton instance for consistent system information
            % collection across the application.
            %
            % Output Arguments:
            %   collector - SystemInfoCollector singleton instance

            persistent instance

            if isempty(instance) || ~isvalid(instance)
                instance = csrd.utils.sysinfo.SystemInfoCollector();
            end

            collector = instance;
        end

    end

end
