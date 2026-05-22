function report = rfPropagationCapabilities(varargin)
%RFPROPAGATIONCAPABILITIES Inspect MATLAB RF propagation runtime support.
%
% Inputs:
%   'OsmFile'  - optional OSM building file used by the smoke probe.
%   'RunSmoke' - when true, create and immediately delete a hidden siteviewer.
%
% Outputs:
%   report - struct with capability flags, symbol locations, and skip reason.
%
% References:
%   MathWorks siteviewer documentation, including OpenStreetMap building files:
%   https://www.mathworks.com/help/comm/ref/siteviewer.html
%   MathWorks raytrace documentation for txsite/rxsite propagation paths:
%   https://www.mathworks.com/help/comm/ref/txsite.raytrace.html
%   MathWorks propagationModel documentation:
%   https://www.mathworks.com/help/antenna/ref/propagationmodel.html
%   MathWorks comm.RayTracingChannel documentation:
%   https://www.mathworks.com/help/comm/ref/comm.raytracingchannel-system-object.html

p = inputParser;
addParameter(p, 'OsmFile', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'RunSmoke', false, @islogical);
parse(p, varargin{:});

osmFile = char(string(p.Results.OsmFile));
runSmoke = p.Results.RunSmoke;

symbols = struct();
symbols.siteviewer = localSymbolReport('siteviewer', 'file');
symbols.txsite = localSymbolReport('txsite', 'file');
symbols.rxsite = localSymbolReport('rxsite', 'file');
symbols.propagationModel = localSymbolReport('propagationModel', 'file');
symbols.raytrace = localSymbolReport('raytrace', 'file');
symbols.RayTracingChannel = localSymbolReport('comm.RayTracingChannel', 'class');

missing = strings(0, 1);
requiredNames = fieldnames(symbols);
for idx = 1:numel(requiredNames)
    name = requiredNames{idx};
    if ~symbols.(name).IsAvailable
        missing(end + 1, 1) = string(name); %#ok<AGROW>
    end
end

report = struct();
report.Symbols = symbols;
report.Missing = missing;
report.CanUseRfSites = symbols.siteviewer.IsAvailable && ...
    symbols.txsite.IsAvailable && symbols.rxsite.IsAvailable;
report.CanUseRayTracing = report.CanUseRfSites && ...
    symbols.propagationModel.IsAvailable && symbols.raytrace.IsAvailable;
report.CanUseRayTracingChannel = symbols.RayTracingChannel.IsAvailable;
report.CanUseBuildingOsmRayTracing = report.CanUseRayTracing && ...
    report.CanUseRayTracingChannel;
report.OsmFile = string(osmFile);
report.OsmFileExists = isempty(osmFile) || isfile(osmFile);
report.SmokePassed = false;
report.SmokeMessage = "";

if ~report.OsmFileExists
    report.CanUseBuildingOsmRayTracing = false;
    missing(end + 1, 1) = "OsmFile"; %#ok<AGROW>
    report.Missing = missing;
end

if runSmoke && report.CanUseBuildingOsmRayTracing && ~isempty(osmFile)
    [report.SmokePassed, report.SmokeMessage] = localSiteviewerSmoke(osmFile);
    report.CanUseBuildingOsmRayTracing = report.SmokePassed;
elseif ~runSmoke
    report.SmokeMessage = "not requested";
end

if report.CanUseBuildingOsmRayTracing
    report.SkipReason = "";
else
    report.SkipReason = localSkipReason(report);
end
end


function symbol = localSymbolReport(name, kind)
% localSymbolReport - Resolve a MATLAB symbol without assuming exist == 2.
% Inputs: name is a MATLAB symbol, kind is the preferred exist query.
% Outputs: symbol records availability, exist code, and which path.
symbol = struct();
symbol.Name = string(name);
symbol.Kind = string(kind);
symbol.ExistCode = exist(name, kind);
symbol.Which = string(which(name));
symbol.IsAvailable = symbol.ExistCode > 0 || strlength(symbol.Which) > 0;
if strcmp(kind, 'class')
    symbol.IsAvailable = symbol.IsAvailable || exist(name, 'class') == 8;
end
end


function [ok, message] = localSiteviewerSmoke(osmFile)
% localSiteviewerSmoke - Create and delete a hidden OSM building siteviewer.
% Inputs: osmFile points to the selected OSM building file.
% Outputs: ok reports smoke success, message carries diagnostic detail.
viewer = [];
try
    viewer = siteviewer('Basemap', 'openstreetmap', ...
        'Buildings', osmFile, 'Hidden', true);
    ok = true;
    message = "siteviewer created";
catch ME
    ok = false;
    message = string(ME.message);
end

if ~isempty(viewer)
    try
        delete(viewer);
    catch
        % Best-effort cleanup only.
    end
end
end


function reason = localSkipReason(report)
% localSkipReason - Produce a short human-readable environment skip reason.
% Inputs: report is the capability report built by the public helper.
% Outputs: reason is a concise char vector suitable for skip metadata.
if ~report.OsmFileExists
    reason = "selected building OSM file is missing";
elseif ~isempty(report.Missing)
    reason = "local MATLAB runtime lacks RF propagation support: " + ...
        strjoin(report.Missing, ", ");
elseif strlength(report.SmokeMessage) > 0 && report.SmokeMessage ~= "not requested"
    reason = "local MATLAB runtime failed OSM siteviewer smoke: " + ...
        report.SmokeMessage;
else
    reason = "local MATLAB runtime lacks RF propagation support";
end
reason = char(reason);
end
