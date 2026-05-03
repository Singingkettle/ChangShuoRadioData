function occ = frequencyOccupancy(occupiedBwHz, observableBwHz)
%FREQUENCYOCCUPANCY Ratio of occupied bandwidth to observable bandwidth.
% 中文说明：提供 CSRD 生产链路中的 frequencyOccupancy 实现。
%
% Phase 4 §3.1 measurement helper. Returns occupiedBwHz/observableBwHz
% clipped to [0, 1]. If observableBwHz is non-positive (no receiver
% window declared), returns NaN so the caller can decide whether to skip
% the metric (NaN propagates through Truth.Measured.* without claiming a
% valid measurement).
%
% Inputs:
%   occupiedBwHz   : non-negative finite scalar (Hz). NaN -> returns NaN.
%   observableBwHz : non-negative scalar (Hz); 0 returns NaN.
%
% Outputs:
%   occ            : double in [0, 1] or NaN
%
% Throws:
%   CSRD:Measurement:NegativeBandwidth - occupiedBwHz < 0 or observableBwHz < 0
%   CSRD:Measurement:NonScalarInput    - non-scalar input

    if ~isnumeric(occupiedBwHz) || ~isscalar(occupiedBwHz)
        error('CSRD:Measurement:NonScalarInput', ...
            'frequencyOccupancy: occupiedBwHz must be a scalar (got %s).', ...
            class(occupiedBwHz));
    end
    if ~isnumeric(observableBwHz) || ~isscalar(observableBwHz)
        error('CSRD:Measurement:NonScalarInput', ...
            'frequencyOccupancy: observableBwHz must be a scalar (got %s).', ...
            class(observableBwHz));
    end

    if isnan(observableBwHz) || observableBwHz <= 0
        occ = NaN;
        return;
    end

    if isnan(occupiedBwHz)
        occ = NaN;
        return;
    end

    if occupiedBwHz < 0 || observableBwHz < 0
        error('CSRD:Measurement:NegativeBandwidth', ...
            'frequencyOccupancy: bandwidths must be non-negative (occ=%g, obs=%g).', ...
            occupiedBwHz, observableBwHz);
    end

    if ~isfinite(occupiedBwHz) || ~isfinite(observableBwHz)
        error('CSRD:Measurement:NegativeBandwidth', ...
            'frequencyOccupancy: bandwidths must be finite.');
    end

    occ = double(occupiedBwHz) / double(observableBwHz);
    if occ > 1
        occ = 1;
    end
end
