%SCM_MEX_CORE SCM_CORE written in ANSI-C 
%   This function calculates the channel coefficients for
%   a geometric MIMO channel model. To compile the C-function 
%   in MATLAB, type 
%
%       mex scm_mex_core.c
% 
%   at MATLAB prompt. The function has three modes, set with 
%   the first input argument. The amount of arguments depends 
%   on the used mode as follows:
%
%   Mode 1: General channel coefficients (GENERAL)
%
%   [H, OUTPUT_SUBPATHPHASE] = SCM_MEX_CORE(mode, G_BS, G_MS, AOD, AOA,
%   D_S, D_U, PHASE, TS, k_CONST, V, THETA_V, SQ_PN, look_up_points, u, s,
%   n, m, k, tn, GainsAreScalar)
%
%   Mode 2: Polarized arrays (POLARIZED)
%
%   [H, OUTPUT_SUBPATHPHASE] = SCM_MEX_CORE(mode, X_BS_v, X_BS_h, X_MS_v,
%   X_MS_h, AOD, AOA, D_S, D_U, PHASE_V_V, PHASE_V_H, PHASE_H_V, PHASE_H_H,
%   R_N1, R_N2, TS, k_CONST, V, THETA_V, SQ_PN, look_up_points, 
%   u, s, n, m, k, tn, GainsAreScalar)
%
%   Mode 3: Line of sight (LOS)
%
%   [H, OUTPUT_PHASE_LOS] = SCM_MEX_CORE(mode, G_BS, G_MS, THETA_BS,
%   THETA_MS, D_S, D_U, PHASE_LOS, TS, k_CONST, V, THETA_V, H_IN,
%   INPUT_PHASE_LOS, K_FACTOR, u, s, n, k, tn)
%
%       Argument            Description
%
%       [Output arguments]
%
%       H               =   Array of SCM channel coefficients (size = [u s n tn k])
%       OUTPUT_SUBPATHPHASE =   output phases (size = [k n m])
%       OUTPUT_PHASE_LOS    =   output phases of LOS components (size = [k])
%
%       [Input arguments]
%
%       mode            =   integer value, set the function mode. Options:
%                           1 (GENERAL), 2 (POLARIZED) or 3 (LOS)
%
%       [Mode 1] (GENERAL)
%       G_BS            =   complex BS_antenna gains (size = [k s n m])
%       G_MS            =   complex MS_antenna gains (size = [k u n m])
%       AOD             =   angles of departure (size = [k n m])
%       AOA             =   angles of arrival (size = [k n m])
%       D_S             =   distances of BS antenna s from ref. antenna (s=1), (size = [s])
%       D_U             =   distance of MS antenna u from ref. antenna (u=1), (size = [u])
%       PHASE           =   phase of the mth subpath of the nth path (size = [k n m])
%       TS              =   time samples (size = [k tn])
%       k_CONST         =   wave number
%       V               =   magnitude of the MS velocity vector (size = [k])
%       THETA_V         =   angle of the MS velocity vector (size = [k])
%       SQ_PN           =   square root of Pn (size = [k n])
%       look_up_points  =   Switch for look-up table for sin/cos functions. Options:
%                           0 (not used), -1 (default number of points),
%                           otherwise the wanted number of points.
%       u               =   number of MS antennas
%       s               =   number of BS antennas
%       n               =   number of multipaths
%       m               =   number of subpaths
%       k               =   number of individual links
%       tn              =   number of time samples
%       GainsAreScalar  =   nonzero if gains are scalar
%
%       [Mode 2] (POLARIZED)
%       X_BS_v          =   BS antenna V-pol component response (size = [k s n m])
%       X_BS_h          =   BS antenna H-pol component response (size = [k s n m])
%       X_MS_v          =   MS antenna V-pol component response (size = [k u n m])
%       X_MS_h          =   MS antenna H-pol component response (size = [k u n m])
%       AOD             =   angles of departure (size = [k n m])
%       AOA             =   angles of arrival (size = [k n m])
%       D_S             =   distances of BS antenna s from ref. antenna (s=1), (size = [s])
%       D_U             =   distance of MS antenna u from ref. antenna (u=1), (size = [u])
%       PHASE_V_V       =   Phase offset of the mth subpath of the nth path between vertical
%                           components of BS and MS (size = [k n m])
%       PHASE_V_H       =   same for vertical components of BS and horizontal components of MS
%       PHASE_H_V       =   same for horizontal components of BS and vertical components of MS
%       PHASE_H_H       =   same for horizontal components of BS and MS
%       R_N1            =   power ratio of (v-h)/(v-v) (size = [k n])
%       R_N2            =   power ratio of (h-v)/(v-v) (size = [k n])
%       TS              =   time sample vectors (size = [k tn])
%       k_CONST         =   wave number
%       V               =   magnitude of the MS velocity vector (size = [k])
%       THETA_V         =   angle of the MS velocity vector (size = [k])
%       SQ_PN           =   square root of Pn (size = [k n*l])
%       look_up_points  =   Switch for look-up table for sin/cos functions. Options:
%                           0 (not used), -1 (default number of points),
%                           otherwise the wanted number of points.
%       u               =   number of MS antennas
%       s               =   number of BS antennas
%       n               =   number of multipaths
%       m               =   number of subpaths
%       k               =   number of individual links
%       tn              =   number of time samples
%       GainsAreScalar  =   nonzero if gains are scalar
%       XpdIndependentPower = nonzero if powers are independent of XPD
%
%       [Mode 3] (LOS)
%       G_BS_THETA      =   complex BS_antenna gains (size = [k s])
%       G_MS_THETA      =   complex MS_antenna gains (size = [k u])
%       THETA_BS        =   angles of departure (size = [k])
%       THETA_MS        =   angles of arrival (size = [k])
%       D_S             =   distances of BS antenna s from ref. antenna (s=1), (size = [s])
%       D_U             =   distance of MS antenna u from ref. antenna (u=1), (size = [u])
%       PHASE_LOS       =   phase of LOS component (size = [k])
%       TS              =   time sample vector (size = [k tn])
%       k_CONST         =   wave number
%       V               =   magnitude of the MS velocity vector (size = [k])
%       THETA_V         =   angle of the MS velocity vector (size = [k])
%       H_IN            =   input channel coefficient matrices (size = [u s n tn k])
%       INPUT_PHASE_LOS =   input LOS phases (size = [k])
%       K_FACTOR        =   Ricean K factor (size = [k])
%       u               =   number of MS antennas
%       s               =   number of BS antennas
%       n               =   number of multipaths
%       k               =   number of links
%       tn              =   number of time samples
%
%
%   Ref: [1] Spatial channel model, 3GPP TR 25.996 V6.1.0 (2003-09)
%

%   Author: Jussi Salmi (HUT)
%   $Revision: 0.21 $  $Date: December 07, 2004$ 


