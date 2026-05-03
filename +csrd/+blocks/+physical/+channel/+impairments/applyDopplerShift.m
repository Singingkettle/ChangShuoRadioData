function [shiftedSignal, dopplerHz, radialVelocityMps] = ...
        applyDopplerShift(signal, sampleRate, carrierFreqHz, ...
                          txPositionM, txVelocityMps, rxPositionM, options)
%APPLYDOPPLERSHIFT Apply physical Doppler frequency shift to a baseband signal.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：提供 CSRD 生产链路中的 applyDopplerShift 实现。
%
%   [shifted, fd, vRadial] = applyDopplerShift(signal, fs, fc, ...
%                                               txPos, txVel, rxPos)
%
%   Phase 4 §3.2 implementation of the audit H12 / A5 closing item:
%   compute the Tx-to-Rx LOS unit vector, project the Tx velocity onto it
%   to obtain a signed radial velocity (positive = closing), and apply the
%   classical narrowband Doppler frequency shift
%
%       f_d = v_radial * f_c / c
%
%   to the input baseband signal as a time-varying complex exponential
%
%       shifted(n) = signal(n) * exp(1j * 2 * pi * f_d * t(n))
%
%   The Rx is assumed stationary in the LOS computation; callers that model
%   two-end mobility must pre-compose the relative velocity (txVel - rxVel)
%   before calling this function. processChannelPropagation does that via
%   csrd.core.ChangShuo.resolveRelativeVelocityForDoppler.
%
% Inputs:
%   signal         : [N x M] complex baseband (M = number of antennas / streams)
%   sampleRate     : positive scalar (Hz)
%   carrierFreqHz  : positive scalar (Hz) - RF carrier
%   txPositionM    : 1x3 (or 3x1) double, Tx position [x y z] in meters
%   txVelocityMps  : 1x3 (or 3x1) double, Tx velocity [vx vy vz] in m/s
%   rxPositionM    : 1x3 (or 3x1) double, Rx position [x y z] in meters
%   options        : optional struct
%       .SkipReason : char, 'InternalDoppler' (informational; ignored)
%
% Outputs:
%   shiftedSignal     : [N x M] complex (same shape as input signal)
%   dopplerHz         : signed scalar (>0 = closing, <0 = opening)
%   radialVelocityMps : signed scalar (>0 = closing)
%
% Throws:
%   CSRD:Channel:DopplerInvalidGeometry  - Tx and Rx positions coincide
%   CSRD:Channel:DopplerInvalidSampleRate - sampleRate <= 0 or non-finite
%   CSRD:Channel:DopplerInvalidCarrier   - carrierFreqHz <= 0 or non-finite
%   CSRD:Channel:DopplerInvalidGeometryVector - any geometry vector not 3-element / non-finite
%
% Constants:
%   Speed of light c = 299792458 m/s (exact, SI)

    if nargin < 7 || isempty(options) %#ok<NASGU>
        options = struct();
    end

    if isempty(signal)
        error('CSRD:Channel:DopplerInvalidSignal', ...
            'applyDopplerShift: input signal is empty.');
    end

    if ~isnumeric(sampleRate) || ~isscalar(sampleRate) || ...
            ~isfinite(sampleRate) || sampleRate <= 0
        error('CSRD:Channel:DopplerInvalidSampleRate', ...
            'applyDopplerShift: sampleRate must be positive finite scalar (got %s).', ...
            mat2str(sampleRate));
    end

    if ~isnumeric(carrierFreqHz) || ~isscalar(carrierFreqHz) || ...
            ~isfinite(carrierFreqHz) || carrierFreqHz <= 0
        error('CSRD:Channel:DopplerInvalidCarrier', ...
            'applyDopplerShift: carrierFreqHz must be positive finite scalar (got %s).', ...
            mat2str(carrierFreqHz));
    end

    txPositionM   = validateGeometryVector(txPositionM,   'txPositionM');
    txVelocityMps = validateGeometryVector(txVelocityMps, 'txVelocityMps');
    rxPositionM   = validateGeometryVector(rxPositionM,   'rxPositionM');

    losVector = rxPositionM - txPositionM;
    losDistance = norm(losVector);
    if losDistance < eps
        error('CSRD:Channel:DopplerInvalidGeometry', ...
            'applyDopplerShift: Tx and Rx positions coincide (||rx-tx|| < eps).');
    end

    losUnit = losVector / losDistance;

    % Convention: positive radial velocity = closing.
    % Tx velocity projected onto Tx->Rx unit vector gives the rate at which
    % the Tx is moving in the direction of the Rx; positive means it is
    % approaching (closing the link), negative means it is receding.
    radialVelocityMps = dot(txVelocityMps, losUnit);

    speedOfLight = 299792458; % m/s
    dopplerHz = radialVelocityMps * carrierFreqHz / speedOfLight;

    if dopplerHz == 0
        shiftedSignal = signal;
        return;
    end

    [N, M] = size(signal);
    t = (0:N-1).' / double(sampleRate);
    phaseRotator = exp(1j * 2 * pi * dopplerHz * t);

    if M == 1
        shiftedSignal = signal .* phaseRotator;
    else
        shiftedSignal = signal .* repmat(phaseRotator, 1, M);
    end
end

% =====================================================================
function v = validateGeometryVector(v, name)
    % validateGeometryVector - Production declaration in CSRD.
    % 中文说明：validateGeometryVector 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    if ~isnumeric(v) || numel(v) ~= 3
        error('CSRD:Channel:DopplerInvalidGeometryVector', ...
            'applyDopplerShift: %s must be a 3-element numeric vector.', name);
    end
    if any(~isfinite(v(:)))
        error('CSRD:Channel:DopplerInvalidGeometryVector', ...
            'applyDopplerShift: %s contains NaN or Inf.', name);
    end
    v = double(v(:)).';
end
