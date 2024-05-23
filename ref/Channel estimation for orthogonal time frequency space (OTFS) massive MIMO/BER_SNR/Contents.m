% SCM channel model
% Version 1.2, Jan 11, 2005
%
% Channel model functions
%   scm               - 3GPP Spatial Channel Model (3GPP TR 25.996)
%   scmparset         - Model parameter configuration for SCM
%   linkparset        - Link parameter configuration for SCM
%   antparset         - Antenna parameter configuration for SCM
%   pathloss          - Pathloss model for 2GHz 
%   
% Miscellaneous functions
%   cas               - Circular angle spread (3GPP TR 25.996)
%   ds                - RMS delay spread 
%   dipole            - Field pattern of half wavelength dipole
%
% Utility functions
%   interp_gain       - Antenna field pattern interpolation
%   interp_gain_c     - Antenna field pattern interpolation (requires GSL)
%   scm_core          - Channel coefficient computation for a geometric channel model
%   scm_mex_core      - SCM_CORE written in ANSI-C 
%   generate_bulk_par - Generation of SCM bulk parameters
%   

% $Revision: 1.1 $ $Date: Dec 12, 2004$
