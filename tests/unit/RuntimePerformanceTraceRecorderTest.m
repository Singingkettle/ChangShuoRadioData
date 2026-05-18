classdef RuntimePerformanceTraceRecorderTest < matlab.unittest.TestCase
    %RUNTIMEPERFORMANCETRACERECORDERTEST Phase 22 runtime counter sink.

    methods (Test)

        function disabledRecorderIgnoresCounters(testCase)
            csrd.runtime.performance.trace('reset');
            csrd.runtime.performance.trace('count', 'RayTracing.SiteviewerConstruct');
            snapshot = csrd.runtime.performance.trace('snapshot');

            testCase.verifyFalse(snapshot.Enabled);
            testCase.verifyEqual(fieldnames(snapshot.Counters), cell(0, 1));
        end

        function enabledRecorderCapturesCountersAndEvents(testCase)
            cleanupObj = onCleanup(@() csrd.runtime.performance.trace('reset')); %#ok<NASGU>
            csrd.runtime.performance.trace('start', tempdir);
            csrd.runtime.performance.trace('count', 'RayTracing.SiteviewerConstruct', ...
                1, struct('OSMFile', 'demo.osm'));
            csrd.runtime.performance.trace('event', 'RayTracing.RaytraceCall', ...
                0.25, struct('MapMode', 'OSMBuildings'));
            snapshot = csrd.runtime.performance.trace('snapshot');

            testCase.verifyTrue(snapshot.Enabled);
            testCase.verifyEqual(snapshot.Counters.RayTracing_SiteviewerConstruct, 1);
            testCase.verifyEqual(snapshot.CounterNames.RayTracing_SiteviewerConstruct, ...
                'RayTracing.SiteviewerConstruct');
            testCase.verifyEqual(snapshot.Events(1).Name, 'RayTracing.RaytraceCall');
            testCase.verifyEqual(snapshot.Events(1).Metadata.MapMode, 'OSMBuildings');
        end

        function recorderCapsRawEventLists(testCase)
            cleanupObj = onCleanup(@() csrd.runtime.performance.trace('reset')); %#ok<NASGU>
            csrd.runtime.performance.trace('start', tempdir);
            for idx = 1:5010
                csrd.runtime.performance.trace('count', 'RayTracing.SiteConstruct');
                csrd.runtime.performance.trace('event', 'RayTracing.RaytraceCall', 0.01);
            end
            snapshot = csrd.runtime.performance.trace('snapshot');

            testCase.verifyEqual(numel(snapshot.CounterEvents), snapshot.MaxCounterEvents);
            testCase.verifyEqual(numel(snapshot.Events), snapshot.MaxEvents);
            testCase.verifyEqual(snapshot.Counters.RayTracing_SiteConstruct, 5010);
            testCase.verifyEqual(snapshot.DroppedCounterEventCount, 10);
            testCase.verifyEqual(snapshot.DroppedEventCount, 10);
        end

        function osmSiteviewerCacheCanBeClearedWithoutViewer(testCase)
            csrd.runtime.map.osmSiteViewerCache('retain', false);
            cleared = csrd.runtime.map.osmSiteViewerCache('clear');
            snapshot = csrd.runtime.map.osmSiteViewerCache('snapshot');

            testCase.verifyEqual(cleared.Cleared, 0);
            testCase.verifyEqual(snapshot.Count, 0);
            testCase.verifyFalse(snapshot.RetainAcrossReleases);
        end

    end
end
