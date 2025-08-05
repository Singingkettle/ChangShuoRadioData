function hasBuildings = checkOSMHasBuildings(obj, osmFile)
    % checkOSMHasBuildings - Check if OSM file contains building data through fast text search
    %
    % This method performs a fast line-by-line search to determine if the OSM file
    % contains building elements before attempting to load it with siteviewer.
    % This prevents crashes when loading OSM files without building data.
    %
    % Input Arguments:
    %   osmFile - Path to OSM file
    %
    % Output Arguments:
    %   hasBuildings - true if OSM file contains 'k="building"' string, false otherwise
    %
    % Note: This method is fast and memory-efficient, but less robust than XML parsing.
    % It may produce false positives if matching items are found in comments (though unlikely).

    hasBuildings = false;

    if ~exist(osmFile, 'file')
        obj.logger.warning('OSM file does not exist: %s', osmFile);
        return;
    end

    % Open file in read-only mode
    fileID = fopen(osmFile, 'r', 'n', 'UTF-8');

    if fileID == -1
        obj.logger.warning('Cannot open OSM file for reading: %s', osmFile);
        return;
    end

    % Create cleanup object to ensure file is closed regardless of how function exits
    cleanupObj = onCleanup(@() fclose(fileID));

    obj.logger.debug('Scanning OSM file line by line for building data: %s', osmFile);

    % Read file line by line
    while ~feof(fileID)
        line = fgetl(fileID);

        % Check if current line contains the specific string we're looking for
        if contains(line, 'k="building"')
            hasBuildings = true;
            obj.logger.debug('Found "k="building"" string in OSM file');
            return; % Exit immediately after finding
        end

    end

    obj.logger.debug('Scan completed, no "k="building"" string found in OSM file');
end
