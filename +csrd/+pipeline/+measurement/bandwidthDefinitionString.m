function definitionText = bandwidthDefinitionString(percentage)
%BANDWIDTHDEFINITIONSTRING The one place the published bandwidth definition is worded.
%
%   definitionText = bandwidthDefinitionString()            % 99 %, the default
%   definitionText = bandwidthDefinitionString(percentage)
%
%   The sentence is published per source (Truth.Measured.*.BandwidthDefinition) and
%   per annotation (Header.Runtime.MeasurementContract.BandwidthDefinition), so it
%   exists in one function rather than being written out at each site. Two copies
%   of a definition drift, and a definition that drifts is worse than no definition:
%   a consumer would have no way to tell which of the two a given field followed.
%
%   Inputs:
%     percentage - optional power-containment percentage, default 99.
%
%   Outputs:
%     definitionText - char row vector naming the quantity and its standard.

if nargin < 1 || isempty(percentage)
    percentage = 99;
end
definitionText = sprintf( ...
    'ITU-R SM.328 occupied bandwidth (%.4g%% power)', double(percentage));
end
