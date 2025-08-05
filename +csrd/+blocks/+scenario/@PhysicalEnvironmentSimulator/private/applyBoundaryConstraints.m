function constrainedPosition = applyBoundaryConstraints(obj, position)
    % applyBoundaryConstraints - Apply map boundary constraints to position
    %
    % Input Arguments:
    %   position - 3D position vector [x, y, z]
    %
    % Output Arguments:
    %   constrainedPosition - Position constrained within map boundaries

    % Check if boundaries exist, if not use default
    if isfield(obj.mapData, 'Boundaries') && ~isempty(obj.mapData.Boundaries)
        bounds = obj.mapData.Boundaries;
    else
        % Use default boundaries if not set
        obj.logger.warning('Map boundaries not set, using default boundaries for position constraints');
        bounds = struct( ...
            'MinLatitude', -1000, ...
            'MaxLatitude', 1000, ...
            'MinLongitude', -1000, ...
            'MaxLongitude', 1000);
    end

    constrainedPosition = position;

    % For statistical maps, use the boundaries directly
    if isfield(bounds, 'MinLatitude')
        % OSM-style boundaries (lat/lon)
        constrainedPosition(1) = max(bounds.MinLongitude, min(bounds.MaxLongitude, position(1)));
        constrainedPosition(2) = max(bounds.MinLatitude, min(bounds.MaxLatitude, position(2)));
    else
        % Grid-style boundaries (x/y)
        constrainedPosition(1) = max(bounds(1), min(bounds(2), position(1)));
        constrainedPosition(2) = max(bounds(3), min(bounds(4), position(2)));
    end

    % Apply Z boundary (minimum height above ground)
    constrainedPosition(3) = max(5, position(3));
end
