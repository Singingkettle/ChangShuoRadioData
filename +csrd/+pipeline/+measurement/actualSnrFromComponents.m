function snrDb = actualSnrFromComponents(signalPowerW, noisePowerW)
%ACTUALSNRFROMCOMPONENTS Explicit-power SNR in dB (no estimation).
%
% Phase 4 §3.1 measurement helper. Returns 10*log10(signalPowerW/noisePowerW)
% with strict input hygiene. Caller passes already-known component powers
% (in Watts) and this function only does the dB conversion + sanity checks.
%
% Inputs:
%   signalPowerW : non-negative finite scalar (Watts)
%   noisePowerW  : positive finite scalar (Watts)
%
% Outputs:
%   snrDb        : 10*log10(signalPowerW/noisePowerW)
%                  signalPowerW == 0 -> -Inf (legitimate, not an error)
%
% Throws:
%   CSRD:Measurement:InvalidPower     - non-finite or negative input
%   CSRD:Measurement:NonPositiveNoise - noisePowerW <= 0 (cannot divide)

    if ~isnumeric(signalPowerW) || ~isscalar(signalPowerW) || ...
            ~isfinite(signalPowerW) || signalPowerW < 0
        error('CSRD:Measurement:InvalidPower', ...
            'actualSnrFromComponents: signalPowerW must be non-negative finite scalar (got %s).', ...
            mat2str(signalPowerW));
    end

    if ~isnumeric(noisePowerW) || ~isscalar(noisePowerW) || ...
            ~isfinite(noisePowerW)
        error('CSRD:Measurement:InvalidPower', ...
            'actualSnrFromComponents: noisePowerW must be positive finite scalar (got %s).', ...
            mat2str(noisePowerW));
    end

    if noisePowerW <= 0
        error('CSRD:Measurement:NonPositiveNoise', ...
            'actualSnrFromComponents: noisePowerW must be > 0 (got %g).', ...
            noisePowerW);
    end

    if signalPowerW == 0
        snrDb = -Inf;
        return;
    end

    snrDb = 10 * log10(double(signalPowerW) / double(noisePowerW));
end
