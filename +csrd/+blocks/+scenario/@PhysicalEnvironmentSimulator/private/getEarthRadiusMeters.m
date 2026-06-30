function earthRadiusMeters = getEarthRadiusMeters()
%GETEARTHRADIUSMETERS Shared mean Earth radius for geo<->local conversions.
% Inputs: none.
% Outputs:
%   earthRadiusMeters - IUGG mean Earth radius (6371008.8 m). Single source of
%       truth for every geographic<->local-metre and bounding-box helper so all
%       boundary consumers stay calibrated to the same sphere. Use
%       getEarthRadiusMeters() / 1000 where a kilometre radius is required.
earthRadiusMeters = 6371008.8;
end
