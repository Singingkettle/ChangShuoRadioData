function meterBounds = geoBoundsToLocalMeterBounds(bounds)
%GEOBOUNDSTOLOCALMETERBOUNDS Convert OSM bounds to [xmin xmax ymin ymax].
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.
corners = [
    bounds.MinLatitude, bounds.MinLongitude
    bounds.MinLatitude, bounds.MaxLongitude
    bounds.MaxLatitude, bounds.MinLongitude
    bounds.MaxLatitude, bounds.MaxLongitude
];

xy = zeros(4, 2);
for k = 1:4
    xy(k, :) = geoToLocalMeters(corners(k, 1), corners(k, 2), bounds);
end
meterBounds = [min(xy(:, 1)), max(xy(:, 1)), min(xy(:, 2)), max(xy(:, 2))];
end
