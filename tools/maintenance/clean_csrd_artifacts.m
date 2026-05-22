function report = clean_csrd_artifacts(varargin)
%CLEAN_CSRD_ARTIFACTS Clean ignored CSRD generated artifacts.
%
% Inputs:
%   'DryRun' - when true, only report candidate paths.
%   'IncludeVisualChecks' - include artifacts/visual_checks in cleanup.
%
% Outputs:
%   report - candidate paths and removal status.

p = inputParser;
addParameter(p, 'DryRun', true, @islogical);
addParameter(p, 'IncludeVisualChecks', false, @islogical);
parse(p, varargin{:});

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
targets = strings(0, 1);
targets = [targets; string(fullfile(projectRoot, 'csrd_simulation_output'))];
targets = [targets; string(fullfile(projectRoot, 'artifacts', 'tests', 'tmp'))];
targets = [targets; string(fullfile(projectRoot, 'artifacts', 'tests', 'generated_configs'))];
if p.Results.IncludeVisualChecks
    targets = [targets; string(fullfile(projectRoot, 'artifacts', 'visual_checks'))];
end

legacyDirs = dir(fullfile(projectRoot, '**', 'csrd_simulation_output'));
for k = 1:numel(legacyDirs)
    if legacyDirs(k).isdir
        targets(end + 1, 1) = string(fullfile(legacyDirs(k).folder, legacyDirs(k).name)); %#ok<AGROW>
    end
end
targets = unique(targets);

records = repmat(struct('Path', "", 'Exists', false, 'Removed', false, ...
    'Message', ""), 0, 1);
for k = 1:numel(targets)
    pathName = char(targets(k));
    rec = struct('Path', targets(k), 'Exists', exist(pathName, 'dir') == 7, ...
        'Removed', false, 'Message', "");
    if rec.Exists && ~p.Results.DryRun
        assert(localIsSafeGeneratedPath(projectRoot, pathName), ...
            'CSRD:Maintenance:UnsafeCleanupPath', ...
            'Refusing to remove non-generated path: %s', pathName);
        try
            rmdir(pathName, 's');
            rec.Removed = true;
            rec.Message = "removed";
        catch ME
            rec.Message = string(ME.message);
        end
    elseif rec.Exists
        rec.Message = "dry-run";
    else
        rec.Message = "missing";
    end
    records(end + 1) = rec; %#ok<AGROW>
end

report = struct();
report.ProjectRoot = string(projectRoot);
report.DryRun = p.Results.DryRun;
report.Records = records;
report.Candidates = numel(records);
report.Removed = sum([records.Removed]);
end


function tf = localIsSafeGeneratedPath(projectRoot, pathName)
% localIsSafeGeneratedPath - Restrict cleanup to known generated roots.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.
resolvedRoot = localCanonicalFolder(projectRoot);
resolvedPath = localCanonicalFolder(pathName);
allowedRoots = { ...
    fullfile(resolvedRoot, 'artifacts', 'tests'), ...
    fullfile(resolvedRoot, 'artifacts', 'visual_checks'), ...
    fullfile(resolvedRoot, 'csrd_simulation_output')};
tf = any(cellfun(@(root) localIsInsideOrEqual(resolvedPath, root), allowedRoots));
end


function folderPath = localCanonicalFolder(pathName)
% localCanonicalFolder - Resolve an existing folder without Java.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.
oldFolder = pwd;
cleanup = onCleanup(@() cd(oldFolder));
cd(pathName);
folderPath = pwd;
end


function tf = localIsInsideOrEqual(pathName, rootName)
% localIsInsideOrEqual - Check whether a path is a root or child path.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.
rootName = char(rootName);
pathName = char(pathName);
tf = strcmpi(pathName, rootName) || startsWith(pathName, [rootName filesep], 'IgnoreCase', true);
end
