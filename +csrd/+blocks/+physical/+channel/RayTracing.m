classdef RayTracing < matlab.System

    properties
        MapFilename
        % MapFilename - Path to the OpenStreetMap file (.osm) containing building data.

        TxInfos cell = {}
        % TxInfos - Cell array of txsite objects used for ray tracing setup.

        RxInfos cell = {}
        % RxInfos - Cell array of rxsite objects used for ray tracing setup.

        SampleRate (1, 1) {mustBePositive, mustBeFinite} = 1e6 % Default 1 MHz
        % SampleRate - Sample rate of the input signal (Hz).

        PropagationModelConfig struct = struct()
        % PropagationModelConfig - Configuration for the propagation model.

        siteViewer % Site viewer object holding the map
    end

    properties (SetAccess = private)
        GeneratedTxSites % Store the generated txsite objects
        GeneratedRxSites % Store the generated rxsite objects
    end

    properties (Access = private)
        ComputedRays % Cell array storing results from raytrace
        MaxPropagationDelay = 0 % Maximum delay across all paths in seconds
    end

    methods

        function obj = RayTracing(varargin)
            % RayTracing - Constructor
            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)

        function setupImpl(obj)

            try
                % Attempt to create site viewer
                viewerInitialized = false;

                if ~isempty(obj.MapFilename) && isfile(obj.MapFilename)

                    try
                        % First, try with buildings if file exists
                        obj.siteViewer = siteviewer(Basemap = "openstreetmap", Buildings = obj.MapFilename, Hidden = true);
                        viewerInitialized = true;
                    catch ME_buildings
                        % If loading with buildings failed, issue warning and try without
                        warning('RayTracing:BuildingLoadFailed', ...
                            'Failed to load buildings from %s. Attempting to load map without buildings. Error: %s', ...
                            obj.MapFilename, ME_buildings.message);
                        % Fallback: Try loading map without buildings
                        obj.siteViewer = siteviewer(Basemap = "openstreetmap", Hidden = true);
                        viewerInitialized = true; % Assume this works if the previous failed due to buildings
                    end

                else
                    % If no MapFilename or file doesn't exist, load without buildings directly
                    obj.siteViewer = siteviewer(Basemap = "openstreetmap", Hidden = true);
                    viewerInitialized = true;
                end

                % Final check if siteViewer was successfully created
                if ~viewerInitialized || isempty(obj.siteViewer)
                    error('RayTracing:SiteViewerCreationFailed', 'Could not initialize the site viewer object.');
                end

            catch ME_setup
                % Catch any error during the siteviewer creation process
                error('RayTracing:SetupFailed', 'Initial site viewer setup failed. Check Basemap, map file path, and Antenna Toolbox availability. Original Error: %s', ME_setup.message);
            end

            % Generate Transmitters
            NumTx = length(obj.TxInfos);
            siteNames = cell(1, NumTx);
            lats = zeros(1, NumTx);
            lons = zeros(1, NumTx);
            heights = zeros(1, NumTx);
            antennas = cell(1, NumTx);

            for i = 1:NumTx
                info = obj.TxInfos{i};
                n = info.SiteConfig.Name;
                lat = info.SiteConfig.Antenna.Latitude;
                lon = info.SiteConfig.Antenna.Longitude;
                h = info.SiteConfig.Antenna.Height;
                a = info.SiteConfig.Antenna.Array;
                t = info.SiteConfig.Antenna.NumTransmitAntennas;

                siteNames{i} = n;
                lats(i) = lat;
                lons(i) = lon;
                heights(i) = h;

                if strcmp(a, 'URA')
                    antennas{i} = arrayConfig("Size", [t / 2, 2], "ElementSpacing", 0.5);
                else
                    antennas{i} = arrayConfig("Size", [t, 1], "ElementSpacing", 0.5);
                end

            end

            obj.GeneratedTxSites = txsite('Name', siteNames, 'Latitude', lats, 'Longitude', lons, 'AntennaHeight', heights, 'Antenna', antennas);

            % Generate Receivers
            NumRx = length(obj.RxInfos);
            siteNames = cell(1, NumRx);
            lats = zeros(1, NumRx);
            lons = zeros(1, NumRx);
            heights = zeros(1, NumRx);
            antennas = cell(1, NumRx);

            for i = 1:NumRx
                info = obj.RxInfos{i};
                n = info.SiteConfig.Name;
                lat = info.SiteConfig.Antenna.Latitude;
                lon = info.SiteConfig.Antenna.Longitude;
                h = info.SiteConfig.Antenna.Height;
                a = info.SiteConfig.Antenna.Array;
                r = info.SiteConfig.Antenna.NumReceiveAntennas;

                siteNames{i} = n;
                lats(i) = lat;
                lons(i) = lon;
                heights(i) = h;

                if strcmp(a, 'URA')
                    antennas{i} = arrayConfig("Size", [r / 2, 2], "ElementSpacing", 0.5);
                else
                    antennas{i} = arrayConfig("Size", [r, 1], "ElementSpacing", 0.5);
                end

            end

            obj.GeneratedRxSites = rxsite('Name', siteNames, 'Latitude', lats, 'Longitude', lons, 'AntennaHeight', heights, 'Antenna', antennas);

            % --- Define Propagation Model ---
            pm = propagationModel("raytracing", ...
                "Method", obj.PropagationModelConfig.Method, ...
                "MaxNumReflections", obj.PropagationModelConfig.MaxNumReflections, ...
                "MaxNumDiffractions", obj.PropagationModelConfig.MaxNumDiffractions);

            % --- Perform Ray Tracing with Generated Sites ---
            try
                obj.ComputedRays = raytrace(obj.GeneratedTxSites, obj.GeneratedRxSites, pm);

            catch ME
                error('RayTracing:ExecutionFailed', 'Initial ray tracing failed. Error: %s', ME.message);
            end

            if NumTx == 1 && NumRx == 1
                obj.ComputedRays = {obj.ComputedRays};
            end

        end

        function out = stepImpl(obj, x, TxId, RxId)

            if isempty(obj.ComputedRays{TxId, RxId})
                out = [];
            else
                rtChan = comm.RayTracingChannel(obj.ComputedRays{TxId, RxId}, obj.GeneratedTxSites(TxId), obj.GeneratedRxSites(RxId));
                rtChan.SampleRate = obj.SampleRate;
                y = rtChan(x.data);

                out = x;
                out.data = y;
            end

        end

    end

end
