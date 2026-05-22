function hasBuildings = checkOSMHasBuildings(obj, osmFile)
    % checkOSMHasBuildings - Check if selected OSM file contains building geometry.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.

    if ~exist(osmFile, 'file')
        obj.logger.warning('OSM file does not exist: %s', osmFile);
        hasBuildings = false;
        return;
    end

    obj.logger.debug('Scanning OSM file for building data: %s', osmFile);
    hasBuildings = csrd.runtime.map.osmHasBuildings(osmFile);

    if hasBuildings
        obj.logger.debug('OSM building or building:part tag found.');
    else
        obj.logger.debug('OSM scan completed with no building tags.');
    end
end
