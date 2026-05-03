function hasBuildings = osmHasBuildings(osmFile)
    % osmHasBuildings - Fast read-only check for building tags in an OSM file.
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 osmHasBuildings 实现。

    hasBuildings = false;

    if nargin < 1 || isempty(osmFile) || ~isfile(osmFile)
        return;
    end

    fileID = fopen(osmFile, 'r', 'n', 'UTF-8');
    if fileID == -1
        return;
    end

    cleanupObj = onCleanup(@() fclose(fileID)); %#ok<NASGU>
    buildingTags = {'k="building"', 'k="building:part"', ...
                    'k=''building''', 'k=''building:part'''};

    while ~feof(fileID)
        line = fgetl(fileID);
        if ~ischar(line) && ~isstring(line)
            continue;
        end

        for idx = 1:numel(buildingTags)
            if contains(line, buildingTags{idx})
                hasBuildings = true;
                return;
            end
        end
    end
end
