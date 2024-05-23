function antpar=antparset(varargin)
%ANTPARSET Antenna parameter configuration for SCM
%   ANTPAR=ANTPARSET sets default parameters for the input struct ANTPAR.
%   
%   Default parameters are [ {default} ]:
%
%   BsGainPattern       - complex BS array element field patterns [ {1} | 4D-array]
%   BsGainAnglesAz      - azimuth angles (degrees) for BsGainPattern [ {linspace(-180,180,90)} ]
%   BsGainAnglesEl      - elevation angles (not used currently)
%   BsElementPosition   - element positions for BS linear array in wavelenghts [ {0.5} ]
%   MsGainPattern       - complex MS array element field patterns [ {1} | 4D-array]
%   MsGainAnglesAz      - azimuth angles (degrees) for MsGainPattern [ {linspace(-180,180,90)} ]
%   MsGainAnglesEl      - elevation angles (not used currently)
%   MsElementPosition   - element positions for MS linear array in wavelenghts [ {0.5} ]
%   InterpFunction      - name of the interpolation function [{'interp_gain'}]
%   InterpMethod        - interpolation method used  [{'cubic'}]
%
%   Some notes about the antenna parameters:
%
%   - The complex field patterns are given in linear scale. The antenna gain 
%     is 20*log10(abs(BsGainPattern)).
%   - Field patterns should be defined over the full 360 degree azimuth 
%     angle. Unless BsGainPattern is a scalar (see below), the intermediate
%     values will be interpolated.
%   - Only linear arrays are supported currently. The element positions can
%     be given (in wavelengths) in the vectors BsElementPosition and 
%     MsElementPosition. When a scalar is given (default), uniform spacing
%     is assumed.
%   - If BsGainPattern and/or MsGainPattern field is a scalar, the antenna
%     field pattern is assumed constant (equal to the scalar) over the whole
%     azimuth angle. For example, setting BsGainPattern=SQRT(1.64) (2.15 dB)
%     would correspond to a BS dipole array with NumBsElements (see below). 
%   - When BsGainPattern (MsGainPattern) is a scalar, the number of the
%     BS (MS) antenna elements is determined from parameters NumBsElements 
%     (NumMsElements) in the input struct SCMPAR (see SCMPARSET). Otherwise, 
%     the number of elements in the link end is deduced from the dimensions 
%     of the 4D-array BsGainPattern (MsGainPattern).
%   - If BsGainPattern (MsGainPattern) is not a scalar it must be a complex
%     4D-array with dimensions NUM_ELxPOLxELxAZ, where NUM_EL is the 
%     number of array elements, POL is 1 or 2, EL is arbitrary, and AZ
%     is LENGTH(BsGainAnglesAz). If 'polarized' option is used, the 
%     (:,1,1,:)th dimension is assumed the vertical polarization and (:,2,1,:)
%     is assumed the horizontal polarization. Otherwise, only the (:,1,1,:)th 
%     dimensions are used. The size of the third dimension is unimportant 
%     as elevation is not used in the current implementation. 
%   - SIZE(BsGainPattern,4) must equal LENGTH(BsAnglesAz). In other words,
%     all element patterns are defined over the same azimuth grid. The same
%     applies for MsGainPattern and MsAnglesAz.
%   - InterpFunction defines the name of the interpolating function. One
%     can also use his own function. For syntax, see INTERP_GAIN.
%   - InterpMethod depends on the interpolating function used. INTERP_GAIN
%     uses the MATLAB's INTERP1 function to do the dirty work. Recommended
%     methods are: 'cubic' or 'linear'. For faster computation, see
%     INTERP_GAIN_C.
%     
%   See also DIPOLE, INTERP_GAIN, INTERP_GAIN_C.

%   Authors: Jari Salo (HUT), Pekka Kyösti (EBIT), Daniela Laselva (EBIT), 
%   Giovanni Del Galdo (TUI), Marko Milojevic (TUI), Christian Schneider (TUI)
%   $Revision: 0.11 $  $Date: Dec 4, 2004$




if (length(varargin)>2)
    error('No such functionality yet. Try ''antpar=antparset'' instead.')
end


antpar=struct(  'BsGainPattern',{1},...                         % in general: [Number_of_antennas, 2, Elevation_points, Azimuth_points]
                'BsGainAnglesAz',{linspace(-180,176,90)},...    % size [1 Azimuth_points]
                'BSGainAnglesEl',{0},...                        % size [1 Elevation_points] (parameter ignored)
                'BsElementPosition',[0.5],...                   % in wavelengths. When scalar, uniform spacing assumed
                'MsGainPattern',{1},...
                'MsGainAnglesAz',{linspace(-180,176,90)},...
                'MsGainAnglesEl',{0},...                
                'MsElementPosition',[0.5],...                   % in wavelengths. When scalar, uniform spacing assumed
                'InterpFunction','interp_gain',...              % name of the interpolation function
                'InterpMethod','cubic');                        % interpolation method, depends on the function used
                 
            
