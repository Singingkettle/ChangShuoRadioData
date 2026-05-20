classdef ScenarioFactoryOsmNoSizeCapTest < matlab.unittest.TestCase
    %SCENARIOFACTORYOSMNOSIZECAPTEST Size caps are not part of OSM selection.

    methods (Test)
        function deprecatedMaxFileSizeFailsFast(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);

            tempRoot = tempname;
            mkdir(fullfile(tempRoot, 'Category'));
            cleanupObj = onCleanup(@() localRemoveDir(tempRoot)); %#ok<NASGU>

            localWriteTinyOsm(fullfile(tempRoot, 'Category', ...
                'Deprecated_Size_Cap_31.0000_121.0000.osm'));

            scenarioCfg = localScenarioConfig(tempRoot, 1, 1);
            scenarioCfg.PhysicalEnvironment.Map.Types = {'OSM'};
            scenarioCfg.PhysicalEnvironment.Map.Ratio = 1;
            scenarioCfg.PhysicalEnvironment.Map.OSM.MaxFileSizeMB = 0.01;

            testCase.verifyError( ...
                @() csrd.test_support.buildRuntimePlanForTest(scenarioCfg), ...
                'CSRD:RuntimePlan:DeprecatedRawField');
        end

        function smallAndLargeFilesBothRemainEligible(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);

            tempRoot = tempname;
            mkdir(fullfile(tempRoot, 'Category'));
            cleanupObj = onCleanup(@() localRemoveDir(tempRoot)); %#ok<NASGU>

            smallFile = fullfile(tempRoot, 'Category', ...
                'Small_Map_31.0000_121.0000.osm');
            largeFile = fullfile(tempRoot, 'Category', ...
                'Large_Map_31.0000_121.0000.osm');
            localWriteTinyOsm(smallFile);
            localWriteLargeOsm(largeFile);

            selectedFiles = strings(1, 2);
            for scenarioId = 1:2
                scenarioCfg = localScenarioConfig(tempRoot, scenarioId, 2);
                scenarioCfg.PhysicalEnvironment.Map.Types = {'OSM'};
                scenarioCfg.PhysicalEnvironment.Map.Ratio = 1;
                profile = localRunAndGetMapProfile(scenarioCfg);
                selectedFiles(scenarioId) = string(profile.OSMFile);
            end

            testCase.verifyTrue(any(selectedFiles == string(smallFile)));
            testCase.verifyTrue(any(selectedFiles == string(largeFile)));
        end

        function specificFileIsAPlainOverride(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);

            tempRoot = tempname;
            mkdir(fullfile(tempRoot, 'Category'));
            cleanupObj = onCleanup(@() localRemoveDir(tempRoot)); %#ok<NASGU>

            largeFile = fullfile(tempRoot, 'Category', ...
                'Specific_Map_31.0000_121.0000.osm');
            localWriteLargeOsm(largeFile);

            scenarioCfg = localScenarioConfig(tempRoot, 1, 1);
            scenarioCfg.PhysicalEnvironment.Map.Types = {'OSM'};
            scenarioCfg.PhysicalEnvironment.Map.Ratio = 1;
            scenarioCfg.PhysicalEnvironment.Map.OSM.SpecificFile = largeFile;
            profile = localRunAndGetMapProfile(scenarioCfg);

            testCase.verifyEqual(profile.OSMFile, largeFile);
            testCase.verifyEqual(profile.SelectionPolicy, 'SpecificFile');
            testCase.verifyFalse(isfield(profile, 'OSMRuntimeTier'));
            testCase.verifyFalse(isfield(profile, 'EffectiveMaxFileSizeMB'));
        end
    end
end

function profile = localRunAndGetMapProfile(scenarioCfg)
cfg = csrd.test_support.buildRuntimePlanForTest(scenarioCfg);
factory = csrd.factories.ScenarioFactory('Config', cfg.Factories.Scenario, ...
    'RuntimePlan', cfg.RuntimePlan);
cleanupFactory = onCleanup(@() release(factory)); %#ok<NASGU>
[~, ~, layout] = factory(1);
profile = layout.Environment.Map.MapProfile;
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

function localWriteLargeOsm(pathText)
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
fprintf(fid, '<!-- %s -->\n', repmat('x', 1, 50000));
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
