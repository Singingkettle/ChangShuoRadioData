classdef Channel < matlab.System

    properties
        % config for modulate
        Config {mustBeFile} = fullfile(fileparts(mfilename('fullpath')), '..', '..', '..', '..', ...
            'config', '_base_', 'simulate', 'channel', 'channel.json')

        TxInfos
        RxInfos
        ChannelInfos
        Radios
        BoxSizeKM = 1
        forward
        use_raytracing
    end

    properties (Access = private)
        logger
        cfgs
        FadingDistribution
    end

    methods

        function obj = Channel(varargin)

            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)

        function setupImpl(obj)
            obj.logger = Log.getInstance();
            obj.cfgs = load_config(obj.Config);

            if isempty(obj.ChannelInfos)
                obj.logger.error("ChannelInfos cannot be empty");
                exit(1);
            end

            TxNum = size(obj.ChannelInfos, 1);
            RxNum = size(obj.ChannelInfos, 2);
            obj.forward = cell(TxNum, RxNum);
            obj.FadingDistribution = cell(TxNum, RxNum);

            parentType = "Simulate";
            channelConfigs = obj.cfgs.(parentType);

            % --- Weighted Random Channel Selection based on configured probabilities ---
            if ~isfield(channelConfigs, 'probabilities')
                error('Channel:ConfigError', 'Configuration for ""%s"" missing required ""probabilities"" field defining selection ratios.', parentType);
            end

            probabilitiesStruct = channelConfigs.probabilities;
            channelNames = fieldnames(rmfield(channelConfigs, 'probabilities')); % Get actual channel config names

            if isempty(channelNames)
                error('Channel:ConfigError', 'No actual channel configurations (besides "probabilities") found under ""%s"".', parentType);
            end

            % Prepare lists of valid channel names and their probabilities
            validNames = {};
            probs = [];

            for k = 1:numel(channelNames)
                name = channelNames{k};

                if isfield(probabilitiesStruct, name)
                    validNames{end + 1} = name; %#ok<AGROW>
                    probs(end + 1) = probabilitiesStruct.(name); %#ok<AGROW>
                else
                    warning('Channel:ConfigWarning', 'Probability not defined for channel ""%s"" under ""%s"". It will not be selected.', name, parentType);
                end

            end

            if isempty(validNames)
                error('Channel:ConfigError', 'No channels with defined probabilities found under ""%s"".', parentType);
            end

            % Normalize probabilities if they don't sum to 1
            probSum = sum(probs);

            if abs(probSum - 1.0) > 1e-6 % Tolerance for floating point inaccuracies
                warning('Channel:ConfigWarning', 'Probabilities under ""%s"" do not sum to 1 (Sum=%.4f). Normalizing.', parentType, probSum);

                if probSum <= 0
                    error('Channel:ConfigError', 'Probabilities under ""%s"" sum to zero or less. Cannot select a channel.', parentType);
                end

                probs = probs / probSum;
            end

            % Perform weighted random selection
            cumProbs = cumsum(probs);
            r = rand();
            selectedIndex = find(r <= cumProbs, 1, 'first');
            selectedChannelName = validNames{selectedIndex};

            % Get the configuration for the selected channel
            kwargs = channelConfigs.(selectedChannelName);
            % --- End of Channel Selection ---

            % Validate the selected channel config has a handle
            if ~isfield(kwargs, 'handle') || isempty(kwargs.handle)
                error('Channel:ConfigError', 'Selected channel ""%s"" is missing a required ""handle"" field.', selectedChannelName);
            end

            % Proceed with instantiation based on handle (RayTracing or statistical)
            if ~exist(kwargs.handle, 'class') && ~contains(kwargs.handle, '.') % Allow handles like RayTracing directly
                handleToCheck = str2func(kwargs.handle);

                if ~exist(func2str(handleToCheck), 'class')
                    obj.logger.error("Channel handle %s does not exist.", kwargs.handle);
                    exit(1);
                end

            elseif contains(kwargs.handle, '.')
                % Handle package-based classes if needed, check existence carefully
                % This part might need adjustment based on how you reference handles
                try
                    meta.class.fromName(strrep(kwargs.handle, '.', '+')); % Example check
                catch
                    obj.logger.error("Channel handle %s does not seem to exist.", kwargs.handle);
                    exit(1);
                end

            end

            if contains(kwargs.handle, 'RayTracing')
                obj.use_raytracing = true;
                % --- RayTracing Channel Instantiation ---
                % Random select a map file
                MapFolder = kwargs.MapFolder;

                if ~isfolder(MapFolder)
                    error('Channel:RayTracingConfigError', 'MapFolder value "%s" is not a valid directory.', MapFolder);
                end

                osmFileStructs = dir(fullfile(MapFolder, '**/*.osm')); % Recursive search

                if isempty(osmFileStructs)
                    error('Channel:RayTracingConfigError', 'No .osm files found in directory: %s', MapFolder);
                end

                % Create a cell array of full file paths
                osmFilePaths = cell(1, numel(osmFileStructs));

                for k = 1:numel(osmFileStructs)
                    osmFilePaths{k} = fullfile(osmFileStructs(k).folder, osmFileStructs(k).name);
                end

                mapFile = osmFilePaths{randperm(numel(osmFilePaths), 1)};

                [~, fname, ~] = fileparts(mapFile);
                % Regex to find last two numbers (potentially negative, with decimals) before .osm
                pattern = '_(-?\d+\.?\d*)_(-?\d+\.?\d*)$';
                tokens = regexp(fname, pattern, 'tokens');

                if isempty(tokens) || numel(tokens{1}) ~= 2
                    error('RayTracing:FilenameParseError', 'Could not parse latitude and longitude from filename: %s. Expected format like *_LAT_LON.osm', fname);
                end

                centerLat = str2double(tokens{1}{1});
                centerLon = str2double(tokens{1}{2});

                if isnan(centerLat) || isnan(centerLon)
                    error('RayTracing:FilenameParseError', 'Parsed coordinates from filename are not valid numbers.');
                end

                [minLat, minLon, maxLat, maxLon] = obj.calculateBoundingBox(centerLat, centerLon, obj.BoxSizeKM);

                for i = 1:TxNum
                    obj.TxInfos{i}.SiteConfig.Antenna.Latitude = minLat + rand() * (maxLat - minLat);
                    obj.TxInfos{i}.SiteConfig.Antenna.Longitude = minLon + rand() * (maxLon - minLon);
                end

                for i = 1:RxNum
                    obj.RxInfos{i}.SiteConfig.Antenna.Latitude = minLat + rand() * (maxLat - minLat);
                    obj.RxInfos{i}.SiteConfig.Antenna.Longitude = minLon + rand() * (maxLon - minLon);
                end

                channelClass = str2func(kwargs.handle);
                % Instantiate RayTracing class
                obj.forward = channelClass( ...
                    'MapFilename', mapFile, ...
                    'TxInfos', obj.TxInfos, ...
                    'RxInfos', obj.RxInfos, ...
                    'PropagationModelConfig', kwargs.PropagationModelConfig ...
                );

            else
                obj.use_raytracing = false;
                obj.forward = cell(TxNum, RxNum);
                obj.FadingDistribution = cell(TxNum, RxNum);
                % --- Existing Statistical Channel Instantiation ---
                channelClass = str2func(kwargs.handle);

                for TxIndex = 1:TxNum

                    for RxIndex = 1:RxNum
                        delay_num = randi(kwargs.MaxPaths, 1);
                        PathDelays = zeros(1, delay_num + 1);
                        PathDelays(1) = 0;

                        if randi(100) <= kwargs.MaxDistance.Ratio
                            % indoor
                            Distance = randi(kwargs.MaxDistance.Indoor, 1); % m
                            PathDelays(2:end) = 10 .^ (sort(randi(3, 1, delay_num)) - 10);
                        else
                            % outdoor
                            Distance = randi(kwargs.MaxDistance.Outdoor, 1); % m
                            PathDelays(2:end) = 10 .^ (sort(randi(3, 1, delay_num)) - 8);
                        end

                        % The dB values in a vector of average path gains often decay roughly linearly as a function of delay, but the specific delay profile depends on the propagation environment.
                        AveragePathGains = linspace(0, -10, delay_num + 1); % Example: decay from 0 dB to -20 dB

                        % 28m/s is the max speed about car in 100Km/s
                        % 1m/s is the 1.5m/s
                        Speed = rand(1) * (kwargs.SpeedRange(2) - kwargs.SpeedRange(1)) + kwargs.SpeedRange(1);
                        MaximumDopplerShift = obj.ChannelInfos{TxIndex, RxIndex}.CarrierFrequency * Speed / 3/10 ^ 8;

                        % https://www.mathworks.com/help/comm/ug/fading-channels.html
                        if randi(100) <= kwargs.Fading.Ratio
                            KFactor = rand(1) * kwargs.MaxKFactor + 1;
                            obj.FadingDistribution{TxIndex, RxIndex} = "Rician";
                        else
                            KFactor = 0;
                            obj.FadingDistribution{TxIndex, RxIndex} = "Rayleigh";
                        end

                        obj.forward{TxIndex, RxIndex} = channelClass(PathDelays = PathDelays, AveragePathGains = AveragePathGains, ...
                            MaximumDopplerShift = MaximumDopplerShift, KFactor = KFactor, Distance = Distance, ...
                            FadingTechnique = "Sum of sinusoids", InitialTimeSource = "Input port", ...
                            NumTransmitAntennas = obj.ChannelInfos{TxIndex, RxIndex}.NumTransmitAntennas, NumReceiveAntennas = obj.ChannelInfos{TxIndex, RxIndex}.NumReceiveAntennas, ...
                            FadingDistribution = obj.FadingDistribution{TxIndex, RxIndex});
                        % Store Distance if needed by the model or for info
                        obj.ChannelInfos{TxIndex, RxIndex}.SiteConfig.Distance = Distance;
                        obj.ChannelInfos{TxIndex, RxIndex}.SiteConfig.Speed = Speed;
                    end

                end

                for i = 1:TxNum
                    obj.TxInfos{i}.SiteConfig.Antenna.Latitude = 0;
                    obj.TxInfos{i}.SiteConfig.Antenna.Longitude = 0;
                end

                for i = 1:RxNum
                    obj.RxInfos{i}.SiteConfig.Antenna.Latitude = 0;
                    obj.RxInfos{i}.SiteConfig.Antenna.Longitude = 0;
                end

            end

        end

        function out = stepImpl(obj, x, FrameId, RxId, TxId, SegmentId)
            % channel
            if obj.use_raytracing
                out = obj.forward(x, TxId, RxId);
            else
                out = obj.forward{TxId, RxId}(x);
            end

            if isempty(out)
                out = [];
            else
                out.SiteConfig = obj.TxInfos{TxId}.SiteConfig;
                out.RxSiteConfig = obj.RxInfos{RxId}.SiteConfig;

                % Determine antenna configuration type
                numTx = obj.ChannelInfos{TxId, RxId}.NumTransmitAntennas;
                numRx = obj.ChannelInfos{TxId, RxId}.NumReceiveAntennas;

                if numTx > 1 && numRx > 1
                    antennaConfig = "MIMO";
                elseif numTx > 1 && numRx == 1
                    antennaConfig = "MISO";
                elseif numTx == 1 && numRx > 1
                    antennaConfig = "SIMO";
                else
                    antennaConfig = "SISO";
                end

                obj.logger.debug("Pass Channel of Frame-Rx-Tx-Segment %06d:%02d:%02d:%02d by %d*%d-%s-%s", ...
                    FrameId, RxId, TxId, SegmentId, ...
                    numTx, numRx, obj.FadingDistribution{TxId, RxId}, antennaConfig);
            end

        end

    end

    methods (Static, Access = private)

        function [minLat, minLon, maxLat, maxLon] = calculateBoundingBox(lat_deg, lon_deg, size_km)
            % Calculates an approximate bounding box centered at lat/lon.
            % Based on Python implementation logic.
            lat_rad = deg2rad(lat_deg);
            earth_radius_km = 6371.0;

            % Calculate latitude delta
            delta_lat_rad = (size_km / 2.0) / earth_radius_km;
            delta_lat_deg = rad2deg(delta_lat_rad);

            % Calculate longitude delta
            parallel_radius_km = earth_radius_km * cos(lat_rad);

            if parallel_radius_km < 0.1 % Near poles
                warning('RayTracing:NearPole', 'Calculating longitude delta near pole for Lat %.4f. Using approximation.', lat_deg);
                delta_lon_deg = rad2deg((size_km / 2.0) / (earth_radius_km * cos(deg2rad(1))));
            else
                delta_lon_rad = (size_km / 2.0) / parallel_radius_km;
                delta_lon_deg = rad2deg(delta_lon_rad);
            end

            minLat = lat_deg - delta_lat_deg;
            maxLat = lat_deg + delta_lat_deg;
            minLon = lon_deg - delta_lon_deg;
            maxLon = lon_deg + delta_lon_deg;
        end

    end

end
