function [originLat, originLon] = getGeoOriginFromBounds(bounds)
%GETGEOORIGINFROMBOUNDS Resolve OSM local tangent-plane origin.
% 中文说明：从 OSM 边界解析本地米制坐标原点，经纬度单位为 degree。
if ~isstruct(bounds) || ~isfield(bounds, 'MinLatitude') || ...
        ~isfield(bounds, 'MaxLatitude') || ~isfield(bounds, 'MinLongitude') || ...
        ~isfield(bounds, 'MaxLongitude')
    error('CSRD:Construction:InvalidGeoBounds', ...
        'OSM boundaries must carry Min/MaxLatitude and Min/MaxLongitude.');
end

if isfield(bounds, 'CenterLatitude') && isfield(bounds, 'CenterLongitude') && ...
        ~isempty(bounds.CenterLatitude) && ~isempty(bounds.CenterLongitude)
    originLat = double(bounds.CenterLatitude);
    originLon = double(bounds.CenterLongitude);
else
    originLat = (double(bounds.MinLatitude) + double(bounds.MaxLatitude)) / 2;
    originLon = (double(bounds.MinLongitude) + double(bounds.MaxLongitude)) / 2;
end

if any(~isfinite([originLat, originLon]))
    error('CSRD:Construction:InvalidGeoBounds', ...
        'OSM boundary origin must be finite latitude/longitude degrees.');
end
end
