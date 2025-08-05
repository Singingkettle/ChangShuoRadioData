function abs_path = getFullPath(relative_or_abs_path, base_path)
    % getFullPath Converts a potentially relative path to an absolute path.
    % If relative_or_abs_path is already absolute, it is returned unchanged.
    % Otherwise, it is considered relative to base_path.

    if ispc % Check if on Windows to handle drive letters

        if ~isempty(regexp(relative_or_abs_path, '^[a-zA-Z]:', 'once')) || startsWith(relative_or_abs_path, '\\') || startsWith(relative_or_abs_path, '/') % Absolute path (drive letter or UNC)
            abs_path = relative_or_abs_path;
            return;
        end

    else % Non-Windows (Linux, macOS)

        if startsWith(relative_or_abs_path, filesep) % Absolute path (starts with /)
            abs_path = relative_or_abs_path;
            return;
        end

    end

    % If not absolute, join with base_path
    % Ensure base_path is provided if path is relative
    if nargin < 2 || isempty(base_path)
        % If no base_path, try to make it absolute from current directory,
        % but this might not be what the user expects for config files.
        % It's better if base_path (project_root) is always supplied for config paths.
        warning('getFullPath: No base_path provided for relative path: %s. Resolving from pwd.', relative_or_abs_path);
        abs_path = fullfile(pwd, relative_or_abs_path);
    else
        abs_path = fullfile(base_path, relative_or_abs_path);
    end

    % Clean up path (e.g., resolve ../)
    % Create a temporary file object to use its undocumented getAbsolutePath method
    % This is a common way to achieve robust path canonicalization in MATLAB.
    % Ensure the path (even if non-existent yet) is valid for File constructor.
    try
        fileObj = java.io.File(abs_path);
        abs_path = char(fileObj.getCanonicalPath());
    catch ME_java
        warning('getFullPath: Could not use java.io.File for path canonicalization for: %s. Error: %s. Returning non-canonicalized path.', abs_path, ME_java.message);
        % Fallback: just return the joined path, it might still work if simple enough
    end

end
