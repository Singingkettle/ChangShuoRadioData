function report = validateRequiredToolboxes(level)
%VALIDATEREQUIREDTOOLBOXES Verify required MATLAB toolboxes are installed and licensed.
%
%   report = csrd.utils.toolbox.validateRequiredToolboxes(level)
%
%   Phase 0 (audit §17.2 / phase-0-baseline.md §2.1):
%     - Eliminate the silent "missing-toolbox" failure mode that surfaced
%       only as an obscure runtime error inside one of the factories.
%     - Provide a single source of truth for the three-tier toolbox list
%       used across CI / contributor onboarding.
%
%   level (char|string) - One of:
%       'minimal'  : the bare set required to call ChangShuo's signal chain
%                    in pure-statistical mode (no ray tracing, no maps).
%       'standard' : 'minimal' plus everything needed by the default
%                    end-to-end demo and the regression tests except OSM
%                    ray tracing (RF Propagation toolbox).
%       'full'     : 'standard' plus the toolboxes the OSM ray-tracing
%                    pipeline depends on.
%
%   Returns a struct:
%       .Level                (char)            normalized requested level
%       .Required             (cell of struct)  full required-toolbox list
%       .Missing              (cell of struct)  toolboxes not installed
%       .Unlicensed           (cell of struct)  toolboxes installed but
%                                               without a checked-out
%                                               license
%       .Ok                   (logical)         true iff Missing & Unlicensed
%                                               are both empty
%       .Diagnostics          (struct)          Matlab version / hostname /
%                                               timestamp for the manifest
%
%   On failure (~Ok), this function THROWS:
%       MException with id 'CSRD:Phase0:MissingToolbox'
%
%   The error message is ALWAYS the same shape (rule §16.5.4 / phase-0 §2.1.3):
%
%       CSRD requires the following MATLAB toolboxes to run at level "<lvl>":
%         - <Display Name> (<Identifier>) : missing
%         - <Display Name> (<Identifier>) : not licensed
%       Resolution: install via Add-On Explorer or check out a license.
%
%   We deliberately throw rather than warn so that long simulation sweeps
%   fail FAST during setupImpl rather than 4 hours into a 200-scenario run.
%
%   See also: csrd.SimulationRunner, ver, license

% --- normalize argument ----------------------------------------------------
if nargin < 1 || isempty(level)
    level = 'standard';
end
if isstring(level)
    level = char(level);
end
level = lower(level);
allowed = {'minimal', 'standard', 'full'};
if ~ismember(level, allowed)
    error('CSRD:Phase0:InvalidToolboxLevel', ...
        'validateRequiredToolboxes: level must be one of {%s}, got "%s".', ...
        strjoin(allowed, ', '), level);
end

% --- canonical toolbox catalog --------------------------------------------
% Each entry: struct('Name','Display Name','Id','Toolbox-Identifier-as-ver/license-knows-it')
% Tip: `license('inuse')` and the third column of `ver` use slightly
% different identifiers; we validate against BOTH using two helpers below.
catalog = localToolboxCatalog();

% --- tier composition ------------------------------------------------------
switch level
    case 'minimal'
        wantedKeys = {'matlab', 'comm', 'dsp', 'signal'};
    case 'standard'
        wantedKeys = {'matlab', 'comm', 'dsp', 'signal', ...
            'phased', 'antenna'};
    case 'full'
        wantedKeys = {'matlab', 'comm', 'dsp', 'signal', ...
            'phased', 'antenna', 'rf', 'rfprop', 'map'};
end

required = catalog(ismember({catalog.Key}, wantedKeys));

% --- verify each toolbox ---------------------------------------------------
missing = repmat(struct('Name', '', 'Id', '', 'Reason', ''), 0, 1);
unlicensed = repmat(struct('Name', '', 'Id', '', 'Reason', ''), 0, 1);

verInfo = ver();
installedNames = strtrim({verInfo.Name});

for k = 1:numel(required)
    entry = required(k);
    isInstalled = any(strcmpi(installedNames, entry.Name));

    if ~isInstalled
        rec = struct('Name', entry.Name, 'Id', entry.LicenseId, ...
            'Reason', 'missing');
        missing(end + 1) = rec; %#ok<AGROW>
        continue;
    end

    % Some toolboxes (notably 'matlab' itself) have no separate license to
    % check out, so skip the license probe in that case.
    if isempty(entry.LicenseId) || strcmpi(entry.LicenseId, 'matlab')
        continue;
    end

    canCheckout = false;
    try
        canCheckout = logical(license('test', entry.LicenseId));
    catch
        % license() failed (e.g. unknown feature name on this MATLAB
        % release); leave canCheckout at its initialized false.
    end
    if ~canCheckout
        rec = struct('Name', entry.Name, 'Id', entry.LicenseId, ...
            'Reason', 'not licensed');
        unlicensed(end + 1) = rec; %#ok<AGROW>
    end
end

ok = isempty(missing) && isempty(unlicensed);

% --- assemble report -------------------------------------------------------
report = struct();
report.Level = level;
report.Required = required;
report.Missing = missing;
report.Unlicensed = unlicensed;
report.Ok = ok;
report.Diagnostics = struct( ...
    'MatlabVersion', version(), ...
    'Hostname', localHostname(), ...
    'Timestamp', char(datetime('now', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''', 'TimeZone', 'UTC')));

% --- fail loudly on bad state ---------------------------------------------
if ~ok
    lines = {sprintf( ...
        'CSRD requires the following MATLAB toolboxes to run at level "%s":', ...
        level)};
    for k = 1:numel(missing)
        lines{end + 1} = sprintf('  - %s (%s) : missing', ...
            missing(k).Name, missing(k).Id); %#ok<AGROW>
    end
    for k = 1:numel(unlicensed)
        lines{end + 1} = sprintf('  - %s (%s) : not licensed', ...
            unlicensed(k).Name, unlicensed(k).Id); %#ok<AGROW>
    end
    lines{end + 1} = ['Resolution: install via Add-On Explorer or ', ...
        'check out a license.'];
    error('CSRD:Phase0:MissingToolbox', '%s', strjoin(lines, newline));
end
end % function

% =========================================================================
function catalog = localToolboxCatalog()
% Authoritative list of toolboxes CSRD may need. Keep aligned with the
% blueprint refactor doc §16.5.2 / phase-0-baseline.md Appendix A.
%
% Field map:
%   Key        - short tier-composition key
%   Name       - exact string returned by `ver` (case-insensitive compare)
%   LicenseId  - feature name used by `license('test', id)`
catalog = struct( ...
    'Key',         {}, ...
    'Name',        {}, ...
    'LicenseId',   {});

catalog(end + 1) = struct( ...
    'Key', 'matlab', ...
    'Name', 'MATLAB', ...
    'LicenseId', 'MATLAB');

catalog(end + 1) = struct( ...
    'Key', 'comm', ...
    'Name', 'Communications Toolbox', ...
    'LicenseId', 'Communication_Toolbox');

catalog(end + 1) = struct( ...
    'Key', 'dsp', ...
    'Name', 'DSP System Toolbox', ...
    'LicenseId', 'Signal_Blocks');

catalog(end + 1) = struct( ...
    'Key', 'signal', ...
    'Name', 'Signal Processing Toolbox', ...
    'LicenseId', 'Signal_Toolbox');

catalog(end + 1) = struct( ...
    'Key', 'phased', ...
    'Name', 'Phased Array System Toolbox', ...
    'LicenseId', 'Phased_Array_System_Toolbox');

catalog(end + 1) = struct( ...
    'Key', 'antenna', ...
    'Name', 'Antenna Toolbox', ...
    'LicenseId', 'Antenna_Toolbox');

catalog(end + 1) = struct( ...
    'Key', 'rf', ...
    'Name', 'RF Toolbox', ...
    'LicenseId', 'RF_Toolbox');

catalog(end + 1) = struct( ...
    'Key', 'rfprop', ...
    'Name', 'RF Propagation Toolbox', ...
    'LicenseId', 'RF_Propagation_Toolbox');

catalog(end + 1) = struct( ...
    'Key', 'map', ...
    'Name', 'Mapping Toolbox', ...
    'LicenseId', 'MAP_Toolbox');
end

% =========================================================================
function name = localHostname()
% Tiny cross-platform hostname helper; no external dependencies.
name = '';
try
    [status, raw] = system('hostname');
    if status == 0
        name = strtrim(raw);
    end
catch
    name = '';
end
if isempty(name)
    name = char(getenv('COMPUTERNAME'));
end
if isempty(name)
    name = char(getenv('HOSTNAME'));
end
if isempty(name)
    name = 'unknown-host';
end
end
