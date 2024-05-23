function gains = interp_gain(field_patterns, angles, at_values, interp_method)
%INTERP_GAIN Antenna field pattern interpolation
%   G = INTERP_GAIN(PAT, ANGLES, DATA, METHOD) are the complex antenna 
%   field patterns interpolated at azimuth angles given in DATA,  given in
%   degrees. SIZE(G)=[NUM_EL SIZE(DATA)], where NUM_EL is the  number of
%   rows in matrix PAT. PAT has LENGTH(ANGLES) columns; ANGLES  is a vector
%   defining the angles (in degrees) at which the antenna  element patterns
%   in the rows of PAT have been defined. Note: LENGTH(ANGLES) must equal
%   SIZE(PAT,2), i.e. all field patterns have to be specified  over the
%   same azimuth grid. 
%   
%   METHOD is a string defining interpolation method. For a list of
%   methods, see INTERP1. It is recommended that the antenna field patterns
%   in PAT  are given so that there are no duplicate points in ANGLES and
%   that the  support of the interpolated function spans over the entire
%   azimuth angle, i.e. 360 degrees. (Note that e.g. linear interpolation
%   cannot  extrapolate values falling outside the support of the
%   interpolated  function.)
%
%   Phase and magnitude are interpolated separately. 
%
%   Elevation interpolation is not supported currently.
%   
%   See also INTERP_GAIN_C.

%   Authors: Jari Salo (HUT), Jussi Salmi (HUT), Giovanni Del Galdo (TUI)
%   $Revision: 0.1 $  $Date: July 22, 2004$


% if it's a vector, make sure that it's a row vector
if (min(size(field_patterns,2)==1))
    field_patterns=field_patterns(:).';
end

if (size(field_patterns,2) ~= length(angles(:)))
    error('Size mismatch in antenna parameters! ')
end

siz_at_values    = size(at_values);
nd               = ndims(at_values);
num_elements     = size(field_patterns,1);

at_values=prin_value(at_values);

% interpolation
% Note that extrapolation is not possible with e.g. linear interpolation
% Note also that interpolated values are in degrees
if (isreal(field_patterns)==0)  % if complex-valued do amplitude and phase separately
    int_gain = interp1(angles(:), abs(field_patterns.'), at_values(:),interp_method);
    int_phase = interp1(angles(:), unwrap(angle(field_patterns.'),1), at_values(:),interp_method);
else    % otherwise interpolate only the real part
    int_gain = interp1(angles(:), field_patterns.', at_values(:),interp_method);
    int_phase= -pi*(-0.5+0.5*sign(int_gain));   % take into account the sign of real part
end

% back to complex values, this has size [PROD(siz_at_values) num_elements] 
abs_gain=abs(int_gain);
gains=complex(abs_gain.*cos(int_phase), abs_gain.*sin(int_phase));

% make the output size [num_elements siz_at_values]
gains=reshape(gains,[siz_at_values num_elements]);
gains=permute(gains,[nd+1 1:nd]);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% A function that maps inputs from (-inf,inf) to (-180,180)
function y=prin_value(x)
y=mod(x,360);
y=y-360*floor(y/180);
