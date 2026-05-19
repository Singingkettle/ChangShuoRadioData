classdef OsmInventoryToolTest < matlab.unittest.TestCase
    %OSMINVENTORYTOOLTEST OSM inventory is scoped and metadata-only.

    methods (Test)

        function inventoryReportsCoverageOrderWithoutRuntimeTiers(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);
            addpath(fullfile(root, 'tools', 'performance'));

            tempRoot = tempname;
            mkdir(fullfile(tempRoot, 'SmallCategory'));
            mkdir(fullfile(tempRoot, 'LargeCategory'));
            cleanupObj = onCleanup(@() localRemoveDir(tempRoot)); %#ok<NASGU>

            smallFile = fullfile(tempRoot, 'SmallCategory', ...
                'Small_Test_Map_31.0000_121.0000.osm');
            largeFile = fullfile(tempRoot, 'LargeCategory', ...
                'Large_Test_Map_31.0000_121.0000.osm');
            localWriteOsm(smallFile, 0);
            localWriteOsm(largeFile, 50000);

            summary = profile_osm_map_inventory( ...
                'OsmRoot', tempRoot, ...
                'CoverageSeed', 20260508, ...
                'WriteFiles', false, ...
                'Verbose', false);

            testCase.verifyEqual(summary.TotalFiles, 2);
            testCase.verifyEqual(summary.BuildingFiles, 2);
            testCase.verifyEqual(sort([summary.Entries.CoverageIndex]), [1 2]);
            testCase.verifyFalse(isfield(summary, 'DefaultEligibleFiles'));
            testCase.verifyFalse(isfield(summary, 'LargeExplicitFiles'));
            testCase.verifyFalse(isfield(summary.Entries, 'RuntimeTier'));
            testCase.verifyTrue(any([summary.Entries.SizeMB] > ...
                min([summary.Entries.SizeMB])));
            testCase.verifyEqual(summary.MatPath, '');
            testCase.verifyEqual(summary.JsonPath, '');
        end

    end
end

function localWriteOsm(pathText, paddingChars)
fid = fopen(pathText, 'w', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '<?xml version="1.0" encoding="UTF-8"?>\n');
fprintf(fid, '<osm version="0.6">\n');
fprintf(fid, '<node id="1" lat="31.0000" lon="121.0000"/>\n');
fprintf(fid, '<node id="2" lat="31.0001" lon="121.0000"/>\n');
fprintf(fid, '<node id="3" lat="31.0001" lon="121.0001"/>\n');
fprintf(fid, '<node id="4" lat="31.0000" lon="121.0001"/>\n');
fprintf(fid, '<way id="10"><nd ref="1"/><nd ref="2"/><nd ref="3"/><nd ref="4"/><nd ref="1"/><tag k="building" v="yes"/></way>\n');
if paddingChars > 0
    fprintf(fid, '<!-- %s -->\n', repmat('x', 1, paddingChars));
end
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
