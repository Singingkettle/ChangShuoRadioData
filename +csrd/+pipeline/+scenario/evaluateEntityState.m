function state = evaluateEntityState(scenarioPlan, entityId, timeSec)
%EVALUATEENTITYSTATE Evaluate deterministic entity geometry at a scenario time.

if nargin < 1 || ~isstruct(scenarioPlan)
    error('CSRD:ScenarioPlan:MissingScenarioPlan', ...
        'ScenarioPlan is required to evaluate entity state.');
end
if nargin < 2 || isempty(entityId)
    error('CSRD:ScenarioPlan:MissingEntityId', ...
        'A non-empty entityId is required to evaluate entity state.');
end
if nargin < 3 || isempty(timeSec) || ~isnumeric(timeSec) || ...
        ~isscalar(timeSec) || ~isfinite(timeSec) || timeSec < 0
    error('CSRD:ScenarioPlan:InvalidEvaluationTime', ...
        'Entity evaluation time must be a non-negative finite scalar seconds.');
end

entity = localFindInitialEntity(scenarioPlan, char(string(entityId)));
baseTimeSec = localEntityBaseTime(entity);
if abs(baseTimeSec) > 1e-12
    error('CSRD:ScenarioPlan:InitialEntityNotAtZero', ...
        'ScenarioPlan.Entities.Initial.%s has base time %.17g; expected t=0.', ...
        char(string(entity.ID)), baseTimeSec);
end

positionM = localRequireVector(entity, 'Position');
velocityMps = localRequireVector(entity, 'Velocity');
mobilityModel = localEntityMobilityModel(entity);
if strcmpi(mobilityModel, 'Stationary')
    velocityMps = [0, 0, 0];
elseif ~strcmpi(mobilityModel, 'ConstantVelocity')
    error('CSRD:ScenarioPlan:UnsupportedStatefulMobility', ...
        ['Entity %s uses MobilityModel="%s", which cannot be evaluated ', ...
         'as a deterministic function of time.'], ...
        char(string(entity.ID)), mobilityModel);
end

positionM = positionM + velocityMps * double(timeSec);
[positionM, geoPositionDeg] = localApplyMapGeometry( ...
    positionM, entity, scenarioPlan);

state = struct();
state.EntityID = char(string(entity.ID));
state.EvaluationTimeSec = double(timeSec);
state.EvaluationPolicy = 'SegmentMidpoint';
state.Position = positionM;
state.PositionM = positionM;
state.PositionUnit = 'meters';
state.Velocity = velocityMps;
state.VelocityMps = velocityMps;
state.GeoPositionDeg = geoPositionDeg;
state.MobilityModel = mobilityModel;
end

function entity = localFindInitialEntity(scenarioPlan, entityId)
if ~isfield(scenarioPlan, 'Entities') || ~isstruct(scenarioPlan.Entities) || ...
        ~isfield(scenarioPlan.Entities, 'Initial') || ...
        isempty(scenarioPlan.Entities.Initial)
    error('CSRD:ScenarioPlan:MissingInitialEntities', ...
        'ScenarioPlan.Entities.Initial is required for geometry evaluation.');
end
entities = scenarioPlan.Entities.Initial;
if iscell(entities)
    entities = [entities{:}];
end
match = find(arrayfun(@(e) isfield(e, 'ID') && ...
    strcmp(char(string(e.ID)), entityId), entities), 1, 'first');
if isempty(match)
    error('CSRD:ScenarioPlan:EntityNotFound', ...
        'Entity "%s" is not present in ScenarioPlan.Entities.Initial.', entityId);
end
entity = entities(match);
end

function timeSec = localEntityBaseTime(entity)
timeSec = NaN;
if isfield(entity, 'CreationTime') && isnumeric(entity.CreationTime) && ...
        isscalar(entity.CreationTime)
    timeSec = double(entity.CreationTime);
elseif isfield(entity, 'LastUpdateTime') && isnumeric(entity.LastUpdateTime) && ...
        isscalar(entity.LastUpdateTime)
    timeSec = double(entity.LastUpdateTime);
end
if ~isfinite(timeSec)
    error('CSRD:ScenarioPlan:MissingInitialEntityTime', ...
        'Initial entity %s must carry CreationTime or LastUpdateTime.', ...
        char(string(entity.ID)));
end
end

function v = localRequireVector(entity, fieldName)
if ~isfield(entity, fieldName) || isempty(entity.(fieldName)) || ...
        ~isnumeric(entity.(fieldName)) || numel(entity.(fieldName)) ~= 3 || ...
        any(~isfinite(entity.(fieldName)(:)))
    error('CSRD:ScenarioPlan:InvalidInitialEntityState', ...
        'Initial entity %s must carry finite 3-element %s.', ...
        char(string(entity.ID)), fieldName);
end
v = double(entity.(fieldName)(:)).';
end

function mobilityModel = localEntityMobilityModel(entity)
mobilityModel = 'ConstantVelocity';
if isfield(entity, 'MobilityModel') && ~isempty(entity.MobilityModel)
    mobilityModel = char(string(entity.MobilityModel));
end
end

function [positionM, geoPositionDeg] = localApplyMapGeometry(positionM, entity, scenarioPlan)
boundaries = localScenarioBoundaries(scenarioPlan);
geoPositionDeg = [];
if isempty(boundaries)
    if isfield(entity, 'GeoPositionDeg') && ~isempty(entity.GeoPositionDeg)
        geoPositionDeg = double(entity.GeoPositionDeg(:)).';
    end
    return;
end

if isstruct(boundaries) && isfield(boundaries, 'MinLatitude')
    meterBounds = localGeoBoundsToMeters(boundaries);
    positionM(1) = max(meterBounds(1), min(meterBounds(2), positionM(1)));
    positionM(2) = max(meterBounds(3), min(meterBounds(4), positionM(2)));
    geoPositionDeg = localMetersToGeo(positionM, boundaries);
elseif isnumeric(boundaries) && numel(boundaries) >= 4
    positionM(1) = max(boundaries(1), min(boundaries(2), positionM(1)));
    positionM(2) = max(boundaries(3), min(boundaries(4), positionM(2)));
    if isfield(entity, 'GeoPositionDeg') && ~isempty(entity.GeoPositionDeg)
        geoPositionDeg = double(entity.GeoPositionDeg(:)).';
    end
else
    error('CSRD:ScenarioPlan:InvalidMapBoundaries', ...
        'ScenarioPlan.Map.Boundaries has an unsupported shape.');
end
positionM(3) = max(5, positionM(3));
end

function boundaries = localScenarioBoundaries(scenarioPlan)
boundaries = [];
if isfield(scenarioPlan, 'Map') && isstruct(scenarioPlan.Map)
    if isfield(scenarioPlan.Map, 'Boundaries')
        boundaries = scenarioPlan.Map.Boundaries;
    elseif isfield(scenarioPlan.Map, 'MapProfile') && ...
            isstruct(scenarioPlan.Map.MapProfile) && ...
            isfield(scenarioPlan.Map.MapProfile, 'Boundaries')
        boundaries = scenarioPlan.Map.MapProfile.Boundaries;
    end
end
end

function meterBounds = localGeoBoundsToMeters(bounds)
corners = [
    bounds.MinLatitude, bounds.MinLongitude
    bounds.MinLatitude, bounds.MaxLongitude
    bounds.MaxLatitude, bounds.MinLongitude
    bounds.MaxLatitude, bounds.MaxLongitude];
xy = zeros(4, 2);
for k = 1:4
    xy(k, :) = localGeoToMeters(corners(k, 1), corners(k, 2), bounds);
end
meterBounds = [min(xy(:, 1)), max(xy(:, 1)), min(xy(:, 2)), max(xy(:, 2))];
end

function xyMeters = localGeoToMeters(latDeg, lonDeg, bounds)
earthRadiusM = 6371000;
centerLat = double(bounds.CenterLatitude);
centerLon = double(bounds.CenterLongitude);
x = deg2rad(lonDeg - centerLon) * earthRadiusM * cos(deg2rad(centerLat));
y = deg2rad(latDeg - centerLat) * earthRadiusM;
xyMeters = [x, y];
end

function geo = localMetersToGeo(positionM, bounds)
earthRadiusM = 6371000;
centerLat = double(bounds.CenterLatitude);
centerLon = double(bounds.CenterLongitude);
lat = centerLat + rad2deg(positionM(2) / earthRadiusM);
lon = centerLon + rad2deg(positionM(1) / ...
    (earthRadiusM * cos(deg2rad(centerLat))));
geo = [lat, lon, positionM(3)];
end
