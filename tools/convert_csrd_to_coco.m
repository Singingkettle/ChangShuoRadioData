%% Convert CSRD annotation v2 to COCO format
%
% Phase 5 deliberately removes the legacy implementation of this tool.
% The previous script parsed the pre-v0.4 layout:
%
%   meta.annotation.rx
%   meta.annotation.tx
%
% Current CSRD annotations are v2 records under:
%
%   Frames[*].SignalSources[*].Truth.{Design,Execution,Measured}
%
% Reusing the old converter would silently drop or mislabel generated IQ
% data. Until the v2 converter is implemented, fail fast with an actionable
% error rather than producing partial COCO labels.

error('CSRD:Tools:CocoConverterV2NotImplemented', ...
    ['tools/convert_csrd_to_coco.m legacy pre-v0.4 parsing has been ', ...
     'removed. Implement a v2 converter that reads ', ...
     'Frames[*].SignalSources[*].Truth.{Design,Execution,Measured} before ', ...
     'exporting COCO labels.']);
