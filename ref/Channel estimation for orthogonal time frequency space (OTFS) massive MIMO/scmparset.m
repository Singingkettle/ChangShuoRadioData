function scmpar=scmparset(varargin)
%SCMPARSET Model parameter configuration for SCM
%   SCMPAR=SCMPARSET sets default parameters for the input struct SCMPAR 
%   (see SCM). 
%
%   SCMPARSET parameters [ {default} ]:
%
%   NumBsElements           - Number of BS array antenna elements [ {2} ]
%   NumMsElements           - Number of MS array antenna elements [ {2} ]
%   Scenario                - SCM scenario [ suburban_macro | urban_macro | {urban_micro} ]
%   SampleDensity           - number of time samples per half wavelength [ {2} ]
%   NumTimeSamples          - number of time samples [ {100} ]
%   UniformTimeSampling     - Use same time sampling grid for all links [ yes | {no} ] 
%   BsUrbanMacroAs          - BS angle spread for urban macro in degrees [ {eight} | fifteen ]
%   NumPaths                - number of paths [ {6} ]
%   NumSubPathsPerPath      - number of subpaths per path [ {20} ] (cannot be changed)
%   CarrierFrequency         - carrier frequency in Herz [ {2e9} ]
%   ScmOptions              - SCM optional features [ {none} | polarized | los | urban_canyon ]
%   DelaySamplingInterval   - delay sampling grid [ {1.6276e-008} ]
%   XpdIndependentPower     - power normalization with polarization [ yes | {no} ] 
%   PathLossModelUsed       - usage of path loss model [ yes | {no} ]
%   ShadowingModelUsed      - usage of shadow fading model [ yes | {no} ]
%   PathLossModel           - path loss model function name [ {pathloss} ]
%   AnsiC_core              - use optimized computation [ yes | {no} ]
%   LookUpTable             - look up EXP(j*THETA) from a table [{0}]
%   RandomSeed              - sets random seed [ {[empty]} ]
%
%   Notes about parameters:
%   - The number of BS and MS elements is normally extracted from ANTPAR.
%     The values of NumBsElements and NumMsElements are used only if a single
%     scalar is given as the antenna field pattern in ANTPAR (see ANTPARSET).
%   - For successful Doppler analysis, one should select SampleDensity > 1.
%     The time sample interval is calculated from CarrierFrequency and
%     MsVelocity (see LINKPARSET) according to wavelength/(2*MsVelocity*SampleDensity).
%     The calculated time sample interval for each link is included in the optional 
%     output argument (delta_t) of SCM. 
%   - If UniformTimeSampling is 'yes' all links will be sampled at
%     simultaneous time instants. In this case, the time sample interval is
%     the same for all links it is calculated by replacing MsVelocity with
%     MAX(MsVelocity), where the maximum is over all links. 
%   - Number of paths can be changed at will, although [1] supports only
%     six paths. The delays and mean AoD/AoAs are generated according to
%     [1]. Subpath AoD/AoAs are always taken from [1, Table 5.2].
%   - Number of subpaths is fixed to 20. This is because the AoD/AoAs for
%     subpaths in SCM have fixed angle spread given in [1, Table 5.2].
%   - CarrierFrequency affects path loss and time sampling interval.
%   - DelaySamplingInterval determines the sampling grid in delay domain.
%     All path delays are rounded to the nearest grid point. It can also 
%     be set to zero. Default value is 1/(16*3.84e6) seconds [1]. 
%   - With XpdIndependentPower='yes' the power of the channel matrices
%     is normalized to a constant. Otherwise, it depends on the random XPD
%     ratios, and incorporates the polarization dependent part of the path
%     loss. The default value 'no' complies with [1]. 
%   - When PathLossModelUsed is 'no' the path losses are still computed for
%     each link but they are not multiplied into the channel matrices. If
%     ShadowingModelUsed is also 'no', each channel matrix element has unit
%     mean power (summed over all paths). In other words,
%     MEAN(MEAN(ABS(SUM(H,3)).^2,4),5) is a matrix of (approximately) ones 
%     when isotropic unit-gain antennas are used. Exception: with
%     'polarized' option the power normalization is by default random
%     (depends on XPDs). See parameter scmpar.XpdIndependentPower.
%   - Path loss model is implemented in a separate function, whose name is
%     defined in PathLossModel. For syntax, see PATHLOSS. 
%   - The C-function must be compiled before usage. For more information 
%     of the ANSI-C core function, see SCM_MEX_CORE. 
%   - The LookUpTable parameter defines the number of points used in the
%     cosine look-up table; a power-of-2 should be given. The look-up table 
%     is used only in the ANSI-C optimized core function. Value 0 indicates
%     that look-up table is not used. Value -1 uses the default number of 
%     points, which is 2^14=16384. Since a large part of computation in SCM 
%     involves repeated evaluation of a complex exponential, the look-up 
%     table can speed up computation on certain platforms and C compilers.
%   - Even fixing the random seed may not result in fully repeatable
%     simulations due to differences in e.g. MATLAB versions. 
%
%   Ref. [1]: 3GPP TR 25.996 v6.1.0 (2003-09)
%
%   See also SCM, LINKPARSET, ANTPARSET.

%   Authors: Jari Salo (HUT), Pekka Ky�sti (EBIT), Daniela Laselva (EBIT), 
%   Giovanni Del Galdo (TUI), Marko Milojevic (TUI), Christian Schneider (TUI)
%   $Revision: 0.41 $  $Date: Jan 14, 2005$




if length(varargin)>0
    error('No such functionality. Try ''scmpar=scmparset'' instead.')
end

% Set the default values
scmpar=struct(  'NumBsElements',2,...                   
                'NumMsElements',2,...                   
                'Scenario','urban_macro',...
                'SampleDensity', 2,...                  % in samples/half-wavelength
                'NumTimeSamples',100,...                
                'UniformTimeSampling','no',...           
                'BsUrbanMacroAS','eight',...            % choices: 'eight' and 'fifteen'. 
                'NumPaths',6,...
                'NumSubPathsPerPath',20,...             % only value supported is 20.
                'CarrierFrequency',2e9,...               % in Herz
                'ScmOptions','none',...                 % 'none','polarized','los','urban_canyon'
                'DelaySamplingInterval',1.6276e-008,... % default=1/(16*3.84e6), see [1]
                'XpdIndependentPower','no',...          % with 'yes' normalizes matrix power with polarized arrays
                'PathLossModelUsed','no',...            
                'ShadowingModelUsed','no',...           
                'PathLossModel','pathloss',...   
                'AnsiC_core','no',...                   
                'LookUpTable',0,...                     % number of points in Ansi-C core look-up table for cosine, 0 if not used
                'RandomSeed',[]);                       % if empty, seed is not set.                                                                  



