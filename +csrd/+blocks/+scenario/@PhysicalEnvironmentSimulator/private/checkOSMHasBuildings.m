function hasBuildings = checkOSMHasBuildings(obj, osmFile)
    % checkOSMHasBuildings - Check if selected OSM file contains building geometry.
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 checkOSMHasBuildings 实现。

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
