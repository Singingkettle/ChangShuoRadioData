function flag = helperIsPlutoSDRInstalled
%helperIsPlutoSDRInstalled Check if ADALM-PLUTO Radio HSP is installed
%   X = helperIsPlutoSDRInstalled checks if the Communications Toolbox
%   Support Package for ADALM-PLUTO Radio is installed. The function
%   returns true if the hardware support package (HSP) is installed.

%   Copyright 2019-2023 The MathWorks, Inc.

    spkg = matlabshared.supportpkg.getInstalled;
    flag = ~isempty(spkg) && any(contains({spkg.Name},'ADALM-PLUTO', ...
      'IgnoreCase',true));
end