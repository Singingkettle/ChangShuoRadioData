classdef VSBAMSidebandTest < matlab.unittest.TestCase
    % VSBAMSidebandTest - Guard the VSB-AM sideband realization.
    %
    %   Regression for two residual VSBAM defects found in the physical-
    %   correctness audit:
    %     * The vestigial-filter passband edge was hard-coded at 15 kHz,
    %       ignoring the SampleRate / actual message bandwidth, so message
    %       content beyond 15 kHz lost its vestigial shaping and VSB collapsed
    %       toward DSB.
    %     * The 'upper'/'lower' quadrature sign was swapped, so 'upper'
    %       actually realized the lower sideband - the modulation label and the
    %       reported Design band disagreed with the realized spectrum (and with
    %       SSBAM's convention).
    %
    %   The measured plane re-measures OBW/center from the realized signal, so
    %   these never produced non-finite values; they corrupted the modulation
    %   label / Design band rather than tripping any finiteness gate.

    methods (Test)

        function upperKeepsPositiveSidebandLowerKeepsNegative(testCase)
            [ratioUpper, bwUpper] = localModulate('upper');
            [ratioLower, bwLower] = localModulate('lower');
            % 'upper' must place the dominant energy on positive frequencies
            % (USB), matching SSBAM and the positive reported band.
            testCase.verifyGreaterThan(ratioUpper, 3, ...
                'VSBAM upper must retain the positive (upper) sideband.');
            testCase.verifyLessThan(ratioLower, -3, ...
                'VSBAM lower must retain the negative (lower) sideband.');
            % The reported band sign must match the realized sideband side.
            testCase.verifyGreaterThan(bwUpper(2), abs(bwUpper(1)), ...
                'upper band must extend further on the positive side.');
            testCase.verifyGreaterThan(abs(bwLower(1)), bwLower(2), ...
                'lower band must extend further on the negative side.');
        end

        function passbandAdaptsBeyond15kHz(testCase)
            % A wideband audio message with content extending past the old
            % hard-coded 15 kHz edge (here up to 22 kHz, DC-spanning like real
            % audio) must still be shaped into one sideband. With the fixed
            % 15 kHz edge the 15-22 kHz content lost its vestigial shaping and
            % drifted toward DSB; the SampleRate/bandwidth-aware passband keeps
            % the whole message single-sideband.
            tones = [4e3, 10e3, 16e3, 22e3];
            ratio = localModulate('upper', 200e3, tones);
            testCase.verifyGreaterThan(ratio, 3, ...
                'Wideband (>15 kHz) audio content must still be single-sideband shaped.');
        end

    end

end

function [ratioDb, bw] = localModulate(mode, Fs, toneHz)
    if nargin < 2 || isempty(Fs)
        Fs = 200e3;
    end
    if nargin < 3
        toneHz = [];
    end
    N = 4096;
    t = (0:N - 1)' / Fs;
    if isempty(toneHz)
        m = sin(2 * pi * 3e3 * t) + 0.7 * sin(2 * pi * 9e3 * t);
    else
        m = zeros(N, 1);
        for f0 = toneHz(:)'
            m = m + sin(2 * pi * f0 * t);
        end
    end
    modulator = csrd.blocks.physical.modulate.analog.AM.VSBAM();
    modulator.SampleRate = Fs;
    modulator.ModulatorConfig.mode = mode;
    modulator.ModulatorConfig.cutoff = 300;
    handle = modulator.genModulatorHandle();
    [sig, bw] = handle(m);
    spec = fftshift(fft(sig));
    posPower = sum(abs(spec(N / 2 + 2:end)) .^ 2);
    negPower = sum(abs(spec(1:N / 2)) .^ 2);
    ratioDb = 10 * log10(posPower / max(negPower, eps));
end
