classdef ScenarioFactoryMapTypeBalancedRatioTest < matlab.unittest.TestCase
    %SCENARIOFACTORYMAPTYPEBALANCEDRATIOTEST Map.Ratio is scheduled, not iid.

    methods (Test)
        function mixedMapTypesRespectRatioAndOsmSubsequenceCoverage(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);

            tempRoot = tempname;
            mkdir(fullfile(tempRoot, 'Category'));
            cleanupObj = onCleanup(@() localRemoveDir(tempRoot)); %#ok<NASGU>

            osmFiles = cell(1, 3);
            for idx = 1:3
                osmFiles{idx} = fullfile(tempRoot, 'Category', ...
                    sprintf('Mixed_Map_%02d_31.0000_121.0000.osm', idx));
                localWriteTinyOsm(osmFiles{idx});
            end

            mapTypes = strings(1, 10);
            selectedOsmFiles = strings(1, 0);
            for scenarioId = 1:10
                scenarioCfg = localScenarioConfig(tempRoot, scenarioId, 10);
                scenarioCfg.PhysicalEnvironment.Map.Types = {'Statistical', 'OSM'};
                scenarioCfg.PhysicalEnvironment.Map.Ratio = [0.5, 0.5];

                [mapType, profile] = localRunAndGetMapInfo(scenarioCfg);
                mapTypes(scenarioId) = string(mapType);
                if mapTypes(scenarioId) == "OSM"
                    selectedOsmFiles(end + 1) = string(profile.OSMFile); %#ok<AGROW>
                end
            end

            testCase.verifyEqual(sum(mapTypes == "Statistical"), 5);
            testCase.verifyEqual(sum(mapTypes == "OSM"), 5);
            testCase.verifyEqual(numel(selectedOsmFiles), 5);

            counts = zeros(1, numel(osmFiles));
            for idx = 1:numel(osmFiles)
                counts(idx) = sum(selectedOsmFiles == string(osmFiles{idx}));
            end
            testCase.verifyLessThanOrEqual(max(counts) - min(counts), 1);
            testCase.verifyEqual(sum(counts), 5);
        end
    end
end

function [mapType, profile] = localRunAndGetMapInfo(scenarioCfg)
factory = csrd.factories.ScenarioFactory('Config', scenarioCfg);
cleanupFactory = onCleanup(@() release(factory)); %#ok<NASGU>
[~, ~, layout] = factory(1);
if isfield(layout.Environment, 'MapType')
    mapType = layout.Environment.MapType;
elseif isfield(layout.Environment, 'Map') && ...
        isfield(layout.Environment.Map, 'Type')
    mapType = layout.Environment.Map.Type;
else
    mapType = '';
end
profile = struct();
if isfield(layout.Environment, 'Map') && ...
        isfield(layout.Environment.Map, 'MapProfile')
    profile = layout.Environment.Map.MapProfile;
end
if isempty(mapType)
    if isfield(profile, 'OSMFile') && ~isempty(profile.OSMFile)
        mapType = 'OSM';
    else
        mapType = 'Statistical';
    end
end
end

function scenarioCfg = localScenarioConfig(osmRoot, scenarioId, totalScenarios)
cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
scenarioCfg = cfg.Factories.Scenario;
scenarioCfg.Runtime.ScenarioId = scenarioId;
scenarioCfg.Runtime.TotalScenarios = totalScenarios;
scenarioCfg.Runtime.RandomSeed = 20260508;
scenarioCfg.Runtime.WorkerId = 1;
scenarioCfg.Validator.Enabled = false;
scenarioCfg.Global.NumFramesPerScenario = 1;
scenarioCfg.Global.FrameNumSamples = 1024;
scenarioCfg.Global.FrameDuration = 1024 / 50e6;
scenarioCfg.Global.TimeResolution = 1024 / 50e6;
scenarioCfg.Global.ObservationDuration = 1024 / 50e6;
scenarioCfg.PhysicalEnvironment.Map.OSM.DataDirectory = osmRoot;
scenarioCfg.PhysicalEnvironment.Map.OSM.FilePattern = '*.osm';
scenarioCfg.PhysicalEnvironment.Map.OSM.SpecificFile = '';
if isfield(scenarioCfg.PhysicalEnvironment.Map.OSM, 'MaxFileSizeMB')
    scenarioCfg.PhysicalEnvironment.Map.OSM = ...
        rmfield(scenarioCfg.PhysicalEnvironment.Map.OSM, 'MaxFileSizeMB');
end
scenarioCfg.PhysicalEnvironment.Entities.Transmitters.Count.Min = 1;
scenarioCfg.PhysicalEnvironment.Entities.Transmitters.Count.Max = 1;
scenarioCfg.PhysicalEnvironment.Entities.Transmitters.Mobility.Model = 'Stationary';
scenarioCfg.PhysicalEnvironment.Entities.Transmitters.Mobility.MaxSpeed.Min = 0;
scenarioCfg.PhysicalEnvironment.Entities.Transmitters.Mobility.MaxSpeed.Max = 0;
scenarioCfg.PhysicalEnvironment.Entities.Receivers.Count.Min = 1;
scenarioCfg.PhysicalEnvironment.Entities.Receivers.Count.Max = 1;
scenarioCfg.CommunicationBehavior.Receiver.NumAntennas = 1;
scenarioCfg.CommunicationBehavior.Transmitter.NumAntennas.Min = 1;
scenarioCfg.CommunicationBehavior.Transmitter.NumAntennas.Max = 1;
scenarioCfg.CommunicationBehavior.Regulatory.MonitoringBand.Selection = 'Fixed';
scenarioCfg.CommunicationBehavior.Regulatory.MonitoringBand.Fixed = 'CN_ISM_24';
scenarioCfg.CommunicationBehavior.TemporalBehavior.PatternTypes = {'Continuous'};
scenarioCfg.CommunicationBehavior.TemporalBehavior.PatternDistribution = 1;
end

function localWriteTinyOsm(pathText)
fid = fopen(pathText, 'w', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '<?xml version="1.0" encoding="UTF-8"?>\n');
fprintf(fid, '<osm version="0.6">\n');
fprintf(fid, '<node id="1" lat="31.0000" lon="121.0000"/>\n');
fprintf(fid, '<node id="2" lat="31.0001" lon="121.0000"/>\n');
fprintf(fid, '<node id="3" lat="31.0001" lon="121.0001"/>\n');
fprintf(fid, '<node id="4" lat="31.0000" lon="121.0001"/>\n');
fprintf(fid, ['<way id="10"><nd ref="1"/><nd ref="2"/><nd ref="3"/>', ...
    '<nd ref="4"/><nd ref="1"/><tag k="building" v="yes"/></way>\n']);
fprintf(fid, '</osm>\n');
end

function localRemoveDir(pathText)
if isfolder(pathText)
    try
        rmdir(pathText, 's');
    catch
    end
end
end
