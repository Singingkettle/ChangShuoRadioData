function constrainedPosition = applyBoundaryConstraints(obj, position)
    % applyBoundaryConstraints - Apply map boundary constraints to position
    %
    % Input Arguments:
    %   position - 3D position vector [x, y, z]
    %
    % Output Arguments:
    %   constrainedPosition - Position constrained within map boundaries

    if ~isfield(obj.mapData, 'Boundaries') || isempty(obj.mapData.Boundaries)
        error('CSRD:Construction:MissingMapBoundaries', ...
            'applyBoundaryConstraints requires explicit map boundaries.');
    end
    bounds = obj.mapData.Boundaries;

    constrainedPosition = position;

    if isfield(bounds, 'MinLatitude')
        meterBounds = geoBoundsToLocalMeterBounds(bounds);
        constrainedPosition(1) = max(meterBounds(1), min(meterBounds(2), position(1)));
        constrainedPosition(2) = max(meterBounds(3), min(meterBounds(4), position(2)));
    else
        constrainedPosition(1) = max(bounds(1), min(bounds(2), position(1)));
        constrainedPosition(2) = max(bounds(3), min(bounds(4), position(2)));
    end

    % Apply Z boundary (minimum height above ground)
    constrainedPosition(3) = max(5, position(3));
end
