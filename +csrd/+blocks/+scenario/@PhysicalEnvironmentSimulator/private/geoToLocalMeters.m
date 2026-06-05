function xyMeters = geoToLocalMeters(latDeg, lonDeg, bounds)
%GEOTOLOCALMETERS Convert latitude/longitude degrees to local meters.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.
[originLat, originLon] = getGeoOriginFromBounds(bounds);
earthRadiusMeters = 6371008.8;
lat0 = deg2rad(originLat);
xyMeters = [
    deg2rad(double(lonDeg) - originLon) * earthRadiusMeters * cos(lat0), ...
    deg2rad(double(latDeg) - originLat) * earthRadiusMeters ...
];

if any(~isfinite(xyMeters))
    error('CSRD:Construction:InvalidGeoCoordinate', ...
        'Latitude/longitude must convert to finite local meter coordinates.');
end
end
