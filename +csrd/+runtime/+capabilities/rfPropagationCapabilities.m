function report = rfPropagationCapabilities(varargin)
%RFPROPAGATIONCAPABILITIES Inspect MATLAB RF propagation runtime support.
% 中文说明：检查当前 MATLAB 运行时是否具备 OSM 建筑射线追踪所需的站点、地图和信道对象能力。
%
% Inputs / 输入:
%   'OsmFile'  - optional OSM building file used by the smoke probe.
%   'RunSmoke' - when true, create and immediately delete a hidden siteviewer.
%
% Outputs / 输出:
%   report - struct with capability flags, symbol locations, and skip reason.
%
% References / 参考资料:
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
% 中文说明：用 which 和 exist 共同识别函数、p-code、类和对象方法，避免误判运行时能力。
% Inputs / 输入: name is a MATLAB symbol, kind is the preferred exist query.
% Outputs / 输出: symbol records availability, exist code, and which path.
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
% 中文说明：用最小化的隐藏 siteviewer 创建测试验证当前 OSM 建筑地图能力。
% Inputs / 输入: osmFile points to the selected OSM building file.
% Outputs / 输出: ok reports smoke success, message carries diagnostic detail.
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
        % 中文说明：诊断路径只做尽力资源释放，不掩盖真实探测结果。
    end
end
end


function reason = localSkipReason(report)
% localSkipReason - Produce a short human-readable environment skip reason.
% 中文说明：生成可写入测试和验证摘要的环境限制说明。
% Inputs / 输入: report is the capability report built by the public helper.
% Outputs / 输出: reason is a concise char vector suitable for skip metadata.
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
