classdef GpuAccelerationContractTest < matlab.unittest.TestCase
    %GPUACCELERATIONCONTRACTTEST Phase 21 GPU opt-in contract.

    methods (Test)

        function rayTracingGpuPolicyIsExplicitAndSafeByDefault(testCase)
            rt = csrd.blocks.physical.channel.RayTracing();
            cleanupObj = onCleanup(@() release(rt)); %#ok<NASGU>

            testCase.verifyEqual(rt.UseGPU, 'auto');
            testCase.verifyGreaterThanOrEqual(rt.GpuMinSamples, 0);
        end

        function rayTracingSourceGuardsVersionSpecificUseGpuProperty(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            sourcePath = fullfile(root, '+csrd', '+blocks', '+physical', ...
                '+channel', 'RayTracing.m');
            code = fileread(sourcePath);

            testCase.verifyTrue(contains(code, "isprop(rtChan, 'UseGPU')"), ...
                ['comm.RayTracingChannel.UseGPU is version-specific; production ', ...
                 'code must guard the property before assignment.']);
            testCase.verifyTrue(contains(code, 'gpuIsAvailable()'), ...
                'GPU policy must probe availability before enabling GPU execution.');
        end

    end
end
