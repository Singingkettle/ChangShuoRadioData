function xyMeters = geoToLocalMeters(latDeg, lonDeg, bounds)
%GEOTOLOCALMETERS Convert latitude/longitude degrees to local meters.
% 中文说明：采用局部等距近似，把经纬度坐标转换为以地图中心为原点的米制 x/y。
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
