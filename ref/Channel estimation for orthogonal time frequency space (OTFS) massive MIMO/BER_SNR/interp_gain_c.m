function gains = interp_gain_c(field_patterns, angles, at_values, interp_method)
%INTERP_GAIN_C Antenna field pattern interpolation (requires GSL)
%   G = INTERP_GAIN_C(PAT, ANGLES, DATA, METHOD) are the
%   complex antenna field patterns interpolated at azimuth angles given in DATA, 
%   given in degrees. SIZE(G)=[NUM_EL SIZE(DATA)], where NUM_EL is the 
%   number of rows in matrix PAT. PAT has LENGTH(ANGLES) columns; ANGLES 
%   is a vector defining the angles (in degrees) at which the antenna 
%   element patterns in the rows of PAT have been defined. Note: LENGTH(ANGLES)
%   must equal SIZE(PAT,2), i.e. all field patterns have to be specified 
%   over the same azimuth grid. 
%   
%   METHOD is a string defining interpolation method. The recommended methods
%   are:
%   'linear'        =   linear interpolation   
%   'cspline'       =   cubic spline with periodic boundary conditions
%   'nearest'       =   rounds to nearest known point
%
%   The default method is 'cspline'. Note that 'linear' cannot extrapolate
%   values falling outside the support of the interpolated function and 
%   'nearest' requires that ANGLES is uniformly sampled in angular domain.
%
%   Usage of this function requires that interp_gain_mex.c is compiled. 
%   To compile, type 
%
%       mex -lgsl -lgslcblas -lm interp_gain_mex.c 
%
%   The compilation requires that GNU Scientific Library (GSL) is properly
%   installed in your system and the mex compiler is able to use it.  
%   
%   It is recommended that the antenna field patterns in PAT are given 
%   so that there are no duplicate points in ANGLES and that the 
%   support of the interpolated function spans over the entire azimuth
%   angle, i.e. 360 degrees. 
%
%   Real and imaginary parts are interpolated separately. Elevation 
%   interpolation is not supported currently.
%
%   Ref.: http://www.gnu.org/software/gsl/
%
%   See also INTERP_GAIN.
 
%   Authors: Jussi Salmi (HUT), Jari Salo (HUT)
%   $Revision: 0.1 $  $Date: Aug 11, 2004$


% field_pattern - complex field patterns of the antennas, SIZE()=[NUM_EL AZ_VALUES] 
% angles        - a vector with LENGTH(AZ_VALUES)
% at_values     - an N-D array
% gains         - interpolated complex gains, SIZE()=[NUM_EL SIZE(at_values)]


if (size(field_patterns,2) ~= numel(angles))
    error('Size mismatch in antenna parameters! ')
end

siz_at_values    = size(at_values);
nd               = ndims(at_values);
num_elements     = size(field_patterns,1);

tol = 1e-5; % tolerance to be added if dublicate angles exist

% next lines sort the interpolation values in ascending order and 
% check if there are same values more than once.
[angles I] = sort(angles);
Id = 1;
while (~isempty(Id))
    y_diff = diff(angles); 
    Id = find(y_diff==0);
    angles(Id) = angles(Id) - tol;
end

% check interpolation method
% Additional methods are:
% 'csplinenat'    =   cubic spline with natural boundary conditions
% 'akima'         =   Non-rounded Akima spline with natural boundary conditions.
% 'akimap'        =   Non-rounded Akima spline with periodic boundary conditions.

if isequal(lower(interp_method),'linear')
    type = 1;
else
    if isequal(lower(interp_method),'cspline')
        type = 2;
    else
        if isequal(lower(interp_method),'nearest')
            type = 3;
        else
            if isequal(lower(interp_method),'csplinenat')
                type = 4;
            else
                if isequal(lower(interp_method),'akima')
                    type = 5;
                else
                    if isequal(lower(interp_method),'akimap')
                        type = 6;
                    else
                        type = 2; % default is 'cspline'
                    end
                end
            end
        end
    end
end
        
% interpolate real part values 
% extrapolate values outside the user-defined antenna pattern 
interp_real = interp_gain_mex(angles(:), real(field_patterns(:,I).'), at_values(:),type);

if isreal(field_patterns) % check if fieldpatterns is real valued
    gains = interp_real;
    
else    % fieldpatterns is complex
    
    % Interpolate imaginary part. Note that interpolated values are in degrees
    % extrapolate values outside the user-defined antenna pattern
    interp_imag = interp_gain_mex(angles(:), imag(field_patterns(:,I).'), at_values(:),type);
    
    % back to complex values, this has size [PROD(siz_at_values) num_elements] 
    gains=complex(interp_real,interp_imag);
end

% make the output size [num_elements siz_at_values]
gains=reshape(gains,[siz_at_values num_elements]);
gains=permute(gains,[nd+1 1:nd]);
