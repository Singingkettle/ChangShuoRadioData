function meterBounds = geoBoundsToLocalMeterBounds(bounds)
%GEOBOUNDSTOLOCALMETERBOUNDS Convert OSM bounds to [xmin xmax ymin ymax].
% 中文说明：把 OSM 经纬度边界转换为本地米制边界，用于移动约束。
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
