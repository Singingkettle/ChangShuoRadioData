function [minLat, minLon, maxLat, maxLon] = calculateBoundingBox(obj, lat_deg, lon_deg, size_km)
    % calculateBoundingBox - Calculate bounding box coordinates
    %
    % This method calculates the bounding box coordinates centered at
    % the given latitude and longitude, with the specified size in kilometers.
    %
    % Input Arguments:
    %   lat_deg - Center latitude in degrees
    %   lon_deg - Center longitude in degrees
    %   size_km - Size of the bounding box in kilometers
    %
    % Output Arguments:
    %   minLat - Minimum latitude
    %   minLon - Minimum longitude
    %   maxLat - Maximum latitude
    %   maxLon - Maximum longitude

    lat_rad = deg2rad(lat_deg);
    earth_radius_km = 6371.0;

    % Calculate latitude delta
    delta_lat_rad = (size_km / 2.0) / earth_radius_km;
    delta_lat_deg = rad2deg(delta_lat_rad);

    % Calculate longitude delta
    parallel_radius_km = earth_radius_km * cos(lat_rad);

    if parallel_radius_km < 0.1 % Near poles
        obj.logger.warning('Calculating longitude delta near pole for Lat %.4f. Using approximation.', lat_deg);
        delta_lon_deg = rad2deg((size_km / 2.0) / (earth_radius_km * cos(deg2rad(1))));
    else
        delta_lon_rad = (size_km / 2.0) / parallel_radius_km;
        delta_lon_deg = rad2deg(delta_lon_rad);
    end

    minLat = lat_deg - delta_lat_deg;
    maxLat = lat_deg + delta_lat_deg;
    minLon = lon_deg - delta_lon_deg;
    maxLon = lon_deg + delta_lon_deg;
end
