classdef RayTracingMaterialPolicyTest < matlab.unittest.TestCase
    %RAYTRACINGMATERIALPOLICYTEST Guard OSM material override policy.

    methods (Test)

        function osmBuildingMapProfileDeclaresMaterialOverride(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            sourcePath = fullfile(root, '+csrd', '+blocks', '+scenario', ...
                '@PhysicalEnvironmentSimulator', 'private', 'initializeOSMMap.m');
            code = fileread(sourcePath);

            testCase.verifyTrue(contains(code, ...
                'OverrideUnsupportedOsmMaterials'));
            testCase.verifyTrue(contains(code, ...
                'mapProfile.BuildingsMaterial = ''concrete'''));
            testCase.verifyTrue(contains(code, ...
                'mapProfile.SurfaceMaterial = ''plasterboard'''));
            testCase.verifyTrue(contains(code, ...
                'UnsupportedOsmMaterialsBecomeConcreteCopy'));
            testCase.verifyTrue(contains(code, ...
                'NoOnlineTerrainForBatchRayTracing'), ...
                ['OSM building RayTracing must not depend on MATLAB online ', ...
                 'terrain resources during batch generation.']);
            testCase.verifyFalse(~isempty(regexp(code, ...
                'buildMapProfile\(''OSMBuildings''[\s\S]{0,220}''gmted2010''', ...
                'once')), ...
                'OSM building map profiles must use Terrain="none", not gmted2010.');
        end

        function rayTracingSetsExplicitOsmMaterials(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            sourcePath = fullfile(root, '+csrd', '+blocks', '+physical', ...
                '+channel', 'RayTracing.m');
            code = fileread(sourcePath);

            testCase.verifyTrue(contains(code, 'BuildingsMaterial'));
            testCase.verifyTrue(contains(code, 'SurfaceMaterial'));
            testCase.verifyTrue(contains(code, ...
                'MathWorks recommends explicitly overriding material'));
        end

        function internalRayTracingTypeErrorsAreHardFailures(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            sourcePath = fullfile(root, '+csrd', '+blocks', '+physical', ...
                '+channel', 'RayTracing.m');
            code = fileread(sourcePath);

            testCase.verifyTrue(contains(code, ...
                'localRayTraceErrorAllowsFallback'));
            testCase.verifyTrue(contains(code, ...
                'localAssertUsableMapArgument'));
            testCase.verifyTrue(contains(code, ...
                'InvalidPropagationModelHandle'));
            testCase.verifyTrue(contains(code, ...
                'must surface as hard failures'), ...
                ['Programming/configuration faults such as struct/isvalid ', ...
                 'must not be relabeled as no-path RF fallback.']);
            testCase.verifyTrue(contains(code, ...
                'unable to access terrain'));
            testCase.verifyTrue(contains(code, 'gmted2010'), ...
                ['Terrain access failures are configuration/runtime faults ', ...
                 'and must remain hard failures, not no-path fallbacks.']);
        end

        function productionSiteviewerUsesOriginalOsm(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            cachePath = fullfile(root, '+csrd', '+runtime', '+map', ...
                'osmSiteViewerCache.m');
            code = fileread(cachePath);

            testCase.verifyTrue(contains(code, ...
                'UTF-8-preserving copy'));
            testCase.verifyTrue(contains(code, ...
                'sanitizeOsmMaterials(key)'), ...
                ['Production RayTracing should normalize unsupported OSM ', ...
                 'material tags without touching geometry or corrupting ', ...
                 'Unicode metadata.']);
            testCase.verifyTrue(contains(code, '''Terrain'', ''none'''), ...
                ['Hidden OSM siteviewer construction must disable MATLAB''s ', ...
                 'default gmted2010 terrain dependency for offline batch runs.']);
        end

        function sanitizerWritesUtf8IgnoredCopyForUnsupportedMaterialTags(testCase)
            tempDir = tempname;
            mkdir(tempDir);
            cleanupObj = onCleanup(@() localRemoveDir(tempDir)); %#ok<NASGU>
            osmPath = fullfile(tempDir, 'blank_material.osm');
            fid = fopen(osmPath, 'w', 'n', 'UTF-8');
            fprintf(fid, '<osm>\n');
            fprintf(fid, '<node id="1" lat="0" lon="0"/>\n');
            fprintf(fid, '<way id="2"><tag k="building:material" v=""/></way>\n');
            fprintf(fid, '<way id="3"><tag k="roof:material" v="   "/></way>\n');
            fprintf(fid, '<way id="4"><tag k=''facade:material'' v=''   ''/></way>\n');
            fprintf(fid, '<way id="5"><tag k="material" v="steel"/></way>\n');
            fprintf(fid, '<way id="6"><tag k="material" v="brick"/></way>\n');
            fprintf(fid, '<way id="7"><tag k="material" v="bronze"/></way>\n');
            fprintf(fid, '<way id="8"><tag k="name:got" v="𐍃𐌾𐌹𐌺𐌰𐌲𐍉"/></way>\n');
            fprintf(fid, '</osm>\n');
            fclose(fid);

            info = csrd.runtime.map.sanitizeOsmMaterials(osmPath);

            testCase.verifyTrue(info.Changed);
            testCase.verifyTrue(isfile(info.SanitizedFile));
            fidRead = fopen(info.SanitizedFile, 'r');
            rawBytes = fread(fidRead, '*uint8').';
            fclose(fidRead);
            sanitized = native2unicode(rawBytes, 'UTF-8');
            testCase.verifyTrue(contains(sanitized, 'v="concrete"'));
            testCase.verifyFalse(contains(sanitized, 'v="   "'));
            testCase.verifyFalse(contains(sanitized, "v='   '"));
            testCase.verifyTrue(contains(sanitized, 'v="steel"'));
            testCase.verifyTrue(contains(sanitized, 'v="brick"'));
            testCase.verifyFalse(contains(sanitized, 'v="bronze"'));
            testCase.verifyTrue(contains(sanitized, '𐍃𐌾𐌹𐌺𐌰𐌲𐍉'));
        end

    end
end

function localRemoveDir(pathText)
if isfolder(pathText)
    try
        rmdir(pathText, 's');
    catch
    end
end
end
