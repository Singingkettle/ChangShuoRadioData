classdef RegionSpectrumCatalogTest < matlab.unittest.TestCase
    %REGIONSPECTRUMCATALOGTEST Phase 8 regional catalog schema tests.

    methods (Test)
        function loadsAllSupportedRegions(testCase)
            ids = csrd.catalog.spectrum.RegionSpectrumCatalog.supportedRegionIds();
            testCase.verifyEqual(ids, {'CN','US','EU','JP','KR'});
            for k = 1:numel(ids)
                catalog = csrd.catalog.spectrum.RegionSpectrumCatalog.load(ids{k});
                testCase.verifyEqual(catalog.RegionId, ids{k});
                testCase.verifyNotEmpty(catalog.Bands);
                testCase.verifyNotEmpty(catalog.SourceRefs);
            end
        end

        function everyBandHasSourceRefsAndEvidence(testCase)
            catalogs = csrd.catalog.spectrum.RegionSpectrumCatalog.loadAll();
            for c = 1:numel(catalogs)
                bands = catalogs{c}.Bands;
                for k = 1:numel(bands)
                    testCase.verifyNotEmpty(bands(k).SourceRefs, ...
                        sprintf('%s source refs missing', bands(k).BandId));
                    testCase.verifyNotEmpty(bands(k).EvidenceLevel, ...
                        sprintf('%s evidence missing', bands(k).BandId));
                    testCase.verifyGreaterThan(bands(k).FrequencyRangeHz(2), ...
                        bands(k).FrequencyRangeHz(1), bands(k).BandId);
                    testCase.verifyGreaterThan(bands(k).PriorityWeight, 0, ...
                        sprintf('%s must be selectable with positive weight', bands(k).BandId));
                end
            end
        end

        function radarServicesAreExcludedFromCatalogs(testCase)
            catalogs = csrd.catalog.spectrum.RegionSpectrumCatalog.loadAll();
            tokens = {'radar','radiolocation','radionavigation'};
            for c = 1:numel(catalogs)
                bands = catalogs{c}.Bands;
                for k = 1:numel(bands)
                    text = lower([bands(k).ServiceClass ' ' bands(k).Application]);
                    for t = 1:numel(tokens)
                        testCase.verifyFalse(contains(text, tokens{t}), ...
                            sprintf('%s contains excluded token %s', ...
                            bands(k).BandId, tokens{t}));
                    end
                end
            end
        end

        function unsupportedRegionFailsFast(testCase)
            testCase.verifyError( ...
                @() csrd.catalog.spectrum.RegionSpectrumCatalog.load('NOPE'), ...
                'CSRD:Spectrum:UnsupportedRegion');
        end
    end
end
