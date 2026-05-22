function geoPositionDeg = localMetersToGeo(positionMeters, bounds)
%LOCALMETERSTOGEO Convert local meter position to [lat lon height].
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.
[originLat, originLon] = getGeoOriginFromBounds(bounds);
earthRadiusMeters = 6371008.8;
lat0 = deg2rad(originLat);

positionMeters = double(positionMeters(:)).';
if numel(positionMeters) < 3 || any(~isfinite(positionMeters(1:3)))
    error('CSRD:Construction:InvalidMeterPosition', ...
        'Local meter position must be a finite 3-element vector.');
end

latDeg = originLat + rad2deg(positionMeters(2) / earthRadiusMeters);
lonDeg = originLon + rad2deg(positionMeters(1) / ...
    (earthRadiusMeters * cos(lat0)));
geoPositionDeg = [latDeg, lonDeg, positionMeters(3)];
end
