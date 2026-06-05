function [originLat, originLon] = getGeoOriginFromBounds(bounds)
%GETGEOORIGINFROMBOUNDS Resolve OSM local tangent-plane origin.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.
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
