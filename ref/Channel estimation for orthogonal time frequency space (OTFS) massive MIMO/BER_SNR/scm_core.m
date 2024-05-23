%SCM_CORE Channel coefficient computation for a geometric channel model
%   [H DELTA_T FINAL_PHASES FINAL_PHASES_LOS]=SCM_CORE(SCMPAR, LINKPAR,
%   ANTPAR, BULKPAR, BSGAIN, BSGAIN_LOS, MSGAIN, MSGAIN_LOS, OFFSET_TIME,
%   BSGAINISSCALAR, MSGAINISSCALAR) This is the scm_core aka the big for
%   loop. It implements the formulas in [1, Sec. 5.4] and [1, Sec. 5.5].
%
%   Outputs:
%
%   H               - [UxSxNxTxK] array of channel coefficients
%   DELTA_T         - time sampling intervals (in seconds) for all links
%   FINAL_PHASES    - final phases of all subpaths in degrees over (-180,180)
%   FINAL_PHASES_LOS- final phases for LOS paths in degrees over (-180,180)
%   
%   Inputs:
%
%   SCMPAR          - input struct, see SCMPARSET
%   LINKPAR         - input struct, see LINKPARSET
%   ANTPAR          - input struct, see ANTPARSET
%   BULKPAR         - input BULKPAR, see GENERATE_BULK_PAR
%   BSGAIN          - [KxSxNxM] array of interpolated antenna field
%                     patterns (complex)
%   BSGAIN_LOS      - [KxS] array of interpolated antenna field patterns
%                     (complex) for LOS paths. Only used with the LOS
%                     option; it is set to scalar otherwise.
%   MSGAIN          - [KxUxNxM] array of interpolated antenna field
%                     patterns (complex)
%   MSGAIN_LOS      - [KxU] array of interpolated antenna field patterns
%                     (complex) for LOS paths. Only used with the LOS
%                     option; it is set to scalar otherwise.
%   OFFSET_TIME     - time offset added to the initial phase (set to zero by default)
%   BSGAINISSCALAR  - this is 1 if BsGain is uniform over azimuth, 0 otherwise.
%   MSGAINISSCALAR  - this is 1 if MsGain is uniform over azimuth, 0 otherwise.
%
%   With 'polarized' option:
%
%   BSGAIN          - [KxSx2xNxM] array of interpolated antenna field
%                     patterns (complex), where the third dimension are
%                     the patterns for [V H] polarizations. 
%   MSGAIN          - [KxUx2xNxM] array of interpolated antenna field
%                     patterns (complex), where the third dimension are
%                     the patterns for [V H] polarizations. 
%
%   To compile the ANSI-C written optimized core, type
%
%       mex scm_mex_core.c
%
%   at MATLAB prompt. For further documentation on the ANSI-C implementation 
%   of the SCM_CORE, see SCM_MEX_CORE.

%   Authors: Giovanni Del Galdo (TUI), Jussi Salmi (HUT), Marko Milojevic (TUI), 
%   Christian Schneider (TUI), Jari Salo (HUT), Pekka Kyösti (EBIT), 
%   Daniela Laselva (EBIT)
%   $Revision: 0.3 $  $Date: Jan 13, 2005$


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%      %%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%            %%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%                  %%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%                        %%%%%%%%%%%%%%
%%%%%%%%%%%                              %%%%%%%%%%%
%%%%%%%%                                    %%%%%%%%
%%%%%                                          %%%%%
%%                   --------                     %%
function [H, delta_t, output_SubPathPhases, output_Phi_LOS] = scm_core (scmpar,linkpar,antpar,bulkpar,BsGain,BsGain_Theta_BS,MsGain,MsGain_Theta_MS,offset_time, BsGainIsScalar, MsGainIsScalar)
%%                   --------                     %%
%%%%%                                          %%%%%
%%%%%%%%                                    %%%%%%%%
%%%%%%%%%%%                              %%%%%%%%%%%
%%%%%%%%%%%%%%                        %%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%                  %%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%            %%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%      %%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% scm_core AKA the big for loop. It implements the formula in 5.4
%
%
% offset_time [samples] = defines the starting point (in samples) of the
%                         time axis
% Examples: you want to calculate 1000 time samples calling the scm_core
%           twice (everytime for 500 timesamples)
%           H1 = scm_core (..., 0)
%           H2 = scm_core (..., 500)
%
%   Revision history:
%  
% ______09-June-2004_____
% 1- now scm_core uses path_powers and not subpath_powers
% 2- fixed PHI_LOS
% 3- fixed the antenna gains for the LOS component
%
% ______15-June-2004_____
% 
% 1- the powers must be in linear scale
% 2- LOS probability has been removed since it's never used
% 3- the shadow fading will be applied outside the scm_core, thus it's
%    removed
%
% ______16-June-2004_____
% 
% 1- removed the string argument to call 'safe' 'sparse' etc.  Now it
%    always runs the 'safe' way
% 2- Giovanni: added the polarized option
% 3- removed the sqrt from the gains - they are complex and expressed in
%    tension
% 4- added the phase output
%
% ______21-June-2004_____
% 1- fixed a bug in the polarized loop. du and aoas were missing
%
% ______21-June-2004_____
% 1- fixed a bug in the polarized loop. aoas and aods are degrees! 
%
% ______19-July-2004_____
% 1- Jari: help text and minor editorial work
%
% ______26-July-2004_____ (Jari)
% 1- changed 'polarized' option so that mean power is normalized
% 2- changed the way S and U are determined
% 3- changed MsElementSpacingULA to MsElementPosition
% 4- added ANSI-C core
%
% ______29-July-2004_____ (Jari)
% 1- Added two new input args: BsGainIsScalar and MsGainIsScalar
%
% ______14-September-2004_____ (Jari)
% 1- Modifications for intra-cluster delay spread (ANSI-C part only)
% 2- Fixed delta_t so that SampleDensity means samples per ½ wavelength
%
%______21-Sep-2004_____ (Giovanni)
% 1- adding the intra-cluster DS for all cases
%
%______7-Dec-2004_____ (Jari)
% 1- Bug fix in LOS option: MsElementPosition(s) changed to
% BsElementPosition(s) in a for loop
% 2- some modifications for the public release
%
%______14-Jan-2005_____ 
% 1- (Marko) Added the option XpdIndependentPower
% 2- (Jussi) Added the option XpdIndependentPower for ANSI-C core
%


DEBUG_MODE_FLAG   = 0;
PROFILE_MODE_FLAG = 0;
DISPLAY_MODE_FLAG = 0;

S=size(BsGain,2);               % number of receiving antennas
U    = size(MsGain,2);               % number of transmitting antennas
N    = scmpar.NumPaths;           % number of paths
T    = scmpar.NumTimeSamples;     % number of time samples
K    = length(linkpar.MsNumber);  % number of links
M    = scmpar.NumSubPathsPerPath; % number of subpaths


scmpar.IntraClusterDsUsed='no';    % this is fixed in this version
if strcmpi(scmpar.IntraClusterDsUsed,'yes')
    LM = bulkpar.MidPathOrder;
    LN = bulkpar.NumSubPathsPerMidpath;
    L = length(LN);
    
    path_powers_all = bulkpar.path_powers_all;
    
    if(sum(LN) ~= M)
        error('Sum over NumSubPathsPerMidpath must equal NumSubPathsPerPath.');
    end
else    % special case, one midpath only
    LM = 1:M;
    LN=M;
    L = length(LN);
    
    path_powers_all = bulkpar.path_powers;
end


H = zeros(U,S,N,T,K);


% define element spacing vectors if scalars are given
if (length(antpar.MsElementPosition)==1)
    antpar.MsElementPosition=[0:antpar.MsElementPosition:antpar.MsElementPosition*(U-1)];
end

if (length(antpar.BsElementPosition)==1)
    antpar.BsElementPosition=[0:antpar.BsElementPosition:antpar.BsElementPosition*(S-1)];
end


if DISPLAY_MODE_FLAG
    disp('  ');disp('  ');disp('  ')
    disp('          _______________________ ');
    disp('         ''                       ''');
    disp('         |                       |');
    disp('         |  Welcome              |');
    disp('         |      to the SCM core  |');
    disp('         |                       |');
    disp('         |                       |');    
    disp('         ''-----------------------''');    
    disp('  ')
    disp('  ')
    disp('  ')
end    


% Set internal parameters
speed_of_light=2.99792458e8;
wavelength=speed_of_light/scmpar.CenterFrequency;

% dummy
output_Phi_LOS       = zeros(K,1);

% let's make the time axis - for that we need to check UniformTimeSampling
% and the MSs' velocities
% Note: SampleDensity is samples per half wavelength.
if strcmp(scmpar.UniformTimeSampling,'yes')
    
    max_vel = max(linkpar.MsVelocity);
    delta_t = repmat((wavelength / max_vel)/2/scmpar.SampleDensity,K,1);
    
else % 'UniformTimeSampling' is 'no'
    
    delta_t = (wavelength ./ linkpar.MsVelocity.')./2/scmpar.SampleDensity ;
    
end
t = repmat(delta_t,1,T).*repmat([0:T-1]+offset_time,K,1); % matrix containing the time axes for all links [KxT]
% t = repmat(delta_t,1,T).*repmat([1:T],K,1); % matrix containing the time axes for all links [KxT]

%%%%%%
if DEBUG_MODE_FLAG
    figure
    plot(t.')
    xlabel('samples')
    ylabel('time [sec]')
    grid on
    delta_t
end
%%%%%%

%%%%%%
if PROFILE_MODE_FLAG
    profile on -detail builtin -history
end
%%%%%%



k_CONST = 2*pi/wavelength;

%%%%%%%%%%%%%%%%%%ANSI-C core part%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%check if ANSI-C core is used
if strcmp(lower(scmpar.AnsiC_core),'yes')
    
    % different modes
    GENERAL = 1;
    POLARIZED = 2;
    LOS = 3;   
    
    look_up_points = scmpar.LookUpTable; % set if look-up table is used for sin/cos
    
    
    if (BsGainIsScalar && MsGainIsScalar)
        GainsAreScalar = 1;
    else 
        GainsAreScalar = 0;
    end
    
    if ~strcmpi(scmpar.ScmOptions,'polarized')
        
        if DISPLAY_MODE_FLAG
            disp('entering main loop...');
        end
        
        % adjusting parameters for calling the C routine
        d_u = antpar.MsElementPosition*wavelength;
        d_s = antpar.BsElementPosition*wavelength;
        aod = bulkpar.aods(1:K,1:N,1:M)*pi/180;
        aoa = bulkpar.aoas(1:K,1:N,1:M)*pi/180;  
        phase = bulkpar.subpath_phases(1:K,1:N,1:M)*pi/180;
        v = linkpar.MsVelocity(1:K);
        theta_v = linkpar.MsDirection(1:K)*pi/180;
        sq_Pn = sqrt(path_powers_all(1:K,1:N*L));
        
        % calling the C-mex routine for general coefficients 
        [H output_SubPathPhases] = scm_mex_core(GENERAL, BsGain, MsGain, aod, aoa, d_s, d_u, phase, t, k_CONST, v, theta_v, sq_Pn, look_up_points, U, S, N, M, K, T, GainsAreScalar);
        
        %output_SubPathPhases = prin_value((output_SubPathPhases*180/pi + bulkpar.subpath_phases)); %changed due tests
        output_SubPathPhases = prin_value((output_SubPathPhases*180/pi + bulkpar.subpath_phases(1:K,1:N,1:M)));
        
    else % it's polarized!
        if DISPLAY_MODE_FLAG
            disp('entering polarized option...');
        end    
        
        output_SubPathPhases = zeros(K,4,N,M);
        %temp_output_SubPathPhases = zeros(K,N,M);
        
        % BsGain must have size: [K x S x 2 x N x M]
        % the first dimension in the polarization must be vertical
        %
        % MsGain must have size: [K x U x 2 x N x M]
        % the first dimension in the polarization must be vertical
        %
        % subpath_phases has size: [K x 4 x N x M]
        % check that vv and vh etc are the ones we think they are 
        %
        % bulkpar.xpd has size: [K,2,N]
        % keyboard
        % temp = zeros(M,T);    
        %     keyboard
        % adjusting parameters for calling the C routine
        d_u = antpar.MsElementPosition * wavelength;
        d_s = antpar.BsElementPosition * wavelength;
        
        X_BS_v = reshape(BsGain(:,:,1,:,:),K,S,N,M); 
        X_BS_h = reshape(BsGain(:,:,2,:,:),K,S,N,M); 
        X_MS_v = reshape(MsGain(:,:,1,:,:),K,U,N,M); 
        X_MS_h = reshape(MsGain(:,:,2,:,:),K,U,N,M);     
        aod = bulkpar.aods(1:K,1:N,1:M)*pi/180;
        aoa = bulkpar.aoas(1:K,1:N,1:M)*pi/180;  
        phase_v_v = reshape(bulkpar.subpath_phases(1:K,1,1:N,1:M),K,N,M)*pi/180;
        phase_v_h = reshape(bulkpar.subpath_phases(1:K,2,1:N,1:M),K,N,M)*pi/180;
        phase_h_v = reshape(bulkpar.subpath_phases(1:K,3,1:N,1:M),K,N,M)*pi/180;
        phase_h_h = reshape(bulkpar.subpath_phases(1:K,4,1:N,1:M),K,N,M)*pi/180;
        %sq_r_n1 = reshape(sqrt(1/bulkpar.xpd(1:K,1,1:N)),K,N);
        %sq_r_n2 = reshape(sqrt(1/bulkpar.xpd(1:K,2,1:N)),K,N);
        r_n1 = 1 ./ reshape(bulkpar.xpd(1:K,1,1:N),K,N);
        r_n2 = 1 ./ reshape(bulkpar.xpd(1:K,2,1:N),K,N);    
        v = linkpar.MsVelocity(1:K);
        theta_v = linkpar.MsDirection(1:K)*pi/180;
        sq_Pn = sqrt(path_powers_all(1:K,1:N*L));
        XpdIndependentPower_mex = 0;
        if strcmpi(scmpar.XpdIndependentPower,'yes')
            XpdIndependentPower_mex = 1;
        end
        % the ANSI-C function call
        [H temp_output_SubPathPhases] = scm_mex_core(POLARIZED, X_BS_v, X_BS_h, X_MS_v, X_MS_h, aod, aoa, d_s, d_u, phase_v_v, phase_v_h, phase_h_v, phase_h_h, r_n1, r_n2, t, k_CONST, v, theta_v, sq_Pn, look_up_points, U, S, N, M, K, T, GainsAreScalar, XpdIndependentPower_mex);
        
        output_SubPathPhases(:,1,:,:) = temp_output_SubPathPhases;
        output_SubPathPhases(:,2,:,:) = temp_output_SubPathPhases;
        output_SubPathPhases(:,3,:,:) = temp_output_SubPathPhases;
        output_SubPathPhases(:,4,:,:) = temp_output_SubPathPhases;
        
        output_SubPathPhases = prin_value((output_SubPathPhases*180/pi + bulkpar.subpath_phases));
        
        
        
    end % is it polarized?
    
    %%%%%%
    if PROFILE_MODE_FLAG
        profile report
    end
    %%%%%%
    
    % LOS OPTION
    
    if strcmp(lower(scmpar.ScmOptions),'los')
        
        
        if DISPLAY_MODE_FLAG
            disp('entering LOS option...');
        end
        
        % Take the values of K factors and probability of having LOS case
        K_factors       = bulkpar.K_factors;
        
        %indx            = (K_factors.'~=0)';
        
        ThetaBs      = linkpar.ThetaBs; ThetaBs=ThetaBs(:).';
        ThetaMs      = linkpar.ThetaMs; ThetaMs=ThetaMs(:).';
        
        % if strcmp(str,'safe') % we only do it 'safe' for this option
        
        %adjusting parameters for calling the C-language routine
        output_Phi_LOS  = zeros(K,1);
        d_u = antpar.MsElementPosition * wavelength;
        d_s = antpar.BsElementPosition * wavelength;
        
        
        % the ANSI-C function call
        [H output_Phi_LOS] = scm_mex_core(LOS, BsGain_Theta_BS, MsGain_Theta_MS, ThetaBs*pi/180, ThetaMs*pi/180, d_s, d_u, bulkpar.Phi_LOS(:,1)* pi/180, t, k_CONST, linkpar.MsVelocity(:), linkpar.MsDirection(1,:)*pi/180, H, output_Phi_LOS, K_factors, U, S, N*L, K, T);
        
        % adjusting angles
        output_Phi_LOS = prin_value((output_Phi_LOS*180/pi + bulkpar.Phi_LOS));
        
    end % if 'LOS' option is activated   
    %%%%%%%%%%%%%%%%%%ANSI-C core part ends%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    
else % if ANSI-C is not used
    if ~strcmpi(scmpar.ScmOptions,'polarized')
        if DISPLAY_MODE_FLAG
            disp('entering main loop...');
        end
        
        output_SubPathPhases = zeros(K,N,M);
        
        for u = 1:U % cycles (MS) antennas
            %du = antpar.MsElementSpacingULA * (u-1) * wavelength;
            du = antpar.MsElementPosition(u)*wavelength;
            for s = 1:S % cycles Tx (BS) atennas
                %ds = antpar.BsElementSpacingULA * (s-1) * wavelength;
                ds = antpar.BsElementPosition(s)*wavelength;
                for k = 1:K % cycles links
                    for n = 1:N % cycles paths
                        
                        LM_index = 0; % 
                        
                        for km = 1:L % cycles midpaths
                            
                            temp                 = zeros(M,T);   % oversized, just to keep it always the same size
                            
                            for m=1:LN(km) % cycles subpaths
                                
                                LM_index = LM_index+1;
                                
                                temp(m,:) =  BsGain(k,s,n,LM(LM_index)) *...
                                    exp(j * (...
                                    k_CONST * ds * sin((bulkpar.aods(k,n,LM(LM_index)))*pi/180) +...
                                (bulkpar.subpath_phases(k,n,LM(LM_index))*pi/180)+...
                                    k_CONST * du * sin((bulkpar.aoas(k,n,LM(LM_index)))*pi/180)...
                                )) *...
                                    MsGain(k,u,n,LM(LM_index)) * ...
                                    exp(j * k_CONST * linkpar.MsVelocity(k) * cos((bulkpar.aoas(k,n,LM(LM_index)) - linkpar.MsDirection(k))*pi/180) * t(k,:));
                                
                            end % subpaths
                            
                            H(u,s,(n-1)*L+km,:,k) =  sqrt(path_powers_all(k,(n-1)*L+km) / LN(km)) * sum(temp,1);
                            
                        end % midpaths
                        
                    end % paths 
                    
                end % links 
            end % Tx antennas 
        end % Rx antennas 
        
        
        for k = 1:K % cycles links  % Of course the for loop could be avoided. 
            for n = 1:N % cycles paths
                for m=1:M % cycles supaths
                    
                    % SIMPLE LOOP
                    output_SubPathPhases(k,n,m) =  k_CONST * linkpar.MsVelocity(k) * cos((bulkpar.aoas(k,n,m) - linkpar.MsDirection(k))*pi/180) * (delta_t(k)*T);   
                    
                end % subpaths
            end % paths 
        end % links 
        
        output_SubPathPhases = prin_value((output_SubPathPhases*180/pi + bulkpar.subpath_phases));
        
    else % it's polarized!
        if DISPLAY_MODE_FLAG
            disp('entering polarized option...');
        end    
        
        output_SubPathPhases = zeros(K,4,N,M);
        
        
        % BsGain has must have size: [K x S x 2 x N x M]
        % the first dimension in the polarization must be vertical
        %
        % MsGain has must have size: [K x U x 2 x N x M]
        % the first dimension in the polarization must be vertical
        %
        % subpath_phases has size: [K x 4 x N x M]
        % bulkpar.xpd has size: [K,2,N]
        temp = zeros(M,T);    
        for u = 1:U % cycles (MS) antennas
            %du = antpar.MsElementSpacingULA * (u-1) * wavelength;
            du = antpar.MsElementPosition(u)*wavelength;
            for s = 1:S % cycles Tx (BS) atennas
                %ds = antpar.BsElementSpacingULA * (s-1) * wavelength;
                ds = antpar.BsElementPosition(s)*wavelength;
                for k = 1:K % cycles links
                    for n = 1:N % cycles paths
                        
                        LM_index = 0; % 
                        
                        for km = 1:L % cycles midpaths
                            
                            temp                 = zeros(M,T);   % oversized, just to keep it always the same size
                            
                            for m=1:LN(km) % cycles subpaths
                                
                                LM_index = LM_index+1;
                                
                                if strcmpi(scmpar.XpdIndependentPower,'yes')
                                
                                    temp(m,:) =  [BsGain(k,s,1,n,LM(LM_index)) BsGain(k,s,2,n,LM(LM_index))] * ...
                                        [sqrt(bulkpar.xpd(k,1,n)/(1+bulkpar.xpd(k,1,n))) *exp(j*bulkpar.subpath_phases(k,1,n,LM(LM_index))*pi/180)     , sqrt(1/(1+bulkpar.xpd(k,1,n))) * exp(j*bulkpar.subpath_phases(k,2,n,LM(LM_index))*pi/180);...
                                            sqrt(1/(1+bulkpar.xpd(k,2,n))) * exp(j*bulkpar.subpath_phases(k,3,n,LM(LM_index))*pi/180),      sqrt(bulkpar.xpd(k,2,n)/(1+bulkpar.xpd(k,2,n))) * exp(j*bulkpar.subpath_phases(k,4,n,LM(LM_index))*pi/180)] *...
                                        [MsGain(k,u,1,n,LM(LM_index)); MsGain(k,u,2,n,LM(LM_index))] * ...
                                        exp(j * (k_CONST * ds * sin((bulkpar.aods(k,n,LM(LM_index)))*pi/180))) * ...
                                        exp(j * (k_CONST * du * sin((bulkpar.aoas(k,n,LM(LM_index)))*pi/180))) * ...                    
                                        exp(j * k_CONST * linkpar.MsVelocity(k) * cos((bulkpar.aoas(k,n,LM(LM_index)) - linkpar.MsDirection(k))*pi/180) * t(k,:));
                                    
                                else 
                                    
                                    temp(m,:) =  [BsGain(k,s,1,n,LM(LM_index)) BsGain(k,s,2,n,LM(LM_index))] * ...
                                        [ exp(j*bulkpar.subpath_phases(k,1,n,LM(LM_index))*pi/180)     , sqrt(1/bulkpar.xpd(k,1,n)) * exp(j*bulkpar.subpath_phases(k,2,n,LM(LM_index))*pi/180);...
                                            sqrt(1/bulkpar.xpd(k,2,n)) * exp(j*bulkpar.subpath_phases(k,3,n,LM(LM_index))*pi/180),      exp(j*bulkpar.subpath_phases(k,4,n,LM(LM_index))*pi/180)] *...
                                        [MsGain(k,u,1,n,LM(LM_index)); MsGain(k,u,2,n,LM(LM_index))] * ...
                                        exp(j * (k_CONST * ds * sin((bulkpar.aods(k,n,LM(LM_index)))*pi/180))) * ...
                                        exp(j * (k_CONST * du * sin((bulkpar.aoas(k,n,LM(LM_index)))*pi/180))) * ...                    
                                        exp(j * k_CONST * linkpar.MsVelocity(k) * cos((bulkpar.aoas(k,n,LM(LM_index)) - linkpar.MsDirection(k))*pi/180) * t(k,:));
                                    
                                end
                                
                            end % subpaths
                            
                            H(u,s,(n-1)*L+km,:,k) =  sqrt(path_powers_all(k,(n-1)*L+km) / LN(km)) * sum(temp,1);
                            
                        end % midpaths
                    end % paths 
                end % links 
            end % Tx antennas 
        end % Rx antennas 
        
        for k = 1:K % cycles links  % Of course the for loop could be avoided. 
            for n = 1:N % cycles paths
                for m=1:M % cycles supaths
                    
                    
                    output_SubPathPhases(k,:,n,m) =  (k_CONST * linkpar.MsVelocity(k) * cos((bulkpar.aoas(k,n,m) - linkpar.MsDirection(k))*pi/180) * (t(k,end)+delta_t(k))) * ones(1,4);
                    
                end % subpaths
            end % paths 
        end % links 
        
        output_SubPathPhases = prin_value((output_SubPathPhases*180/pi + bulkpar.subpath_phases));
        
        
    end % is it polarized?
    
    
    
    %%%%%%
    if PROFILE_MODE_FLAG
        profile report
    end
    %%%%%%
    
    
    % LOS OPTION
    
    if strcmpi(scmpar.ScmOptions,'los')
        
%         if ~ strcmpi(scmpar.Scenario,'urban_micro')
%             error('LOS option is possible only for URBAN MICRO scenario') % assumption-all the users are in the same scenario
%         end
        if DISPLAY_MODE_FLAG
            disp('entering LOS option...');
        end
        
        % Take the values of K factors and probability of having LOS case
        K_factors       = bulkpar.K_factors;
        
        indx            = (K_factors.'~=0)';
        
        ThetaBs      = linkpar.ThetaBs; ThetaBs=ThetaBs(:).';
        ThetaMs      = linkpar.ThetaMs; ThetaMs=ThetaMs(:).';
        
        
        %temp = zeros(M,T);    
        
        
        
        for k = 1:K % cycles links
            if indx(k)~=0
                
                for u = 1:U % cycles (MS) antennas
                    %du = antpar.MsElementSpacingULA * (u-1) * wavelength;
                    du = antpar.MsElementPosition(u)*wavelength;
                    for s = 1:S % cycles (BS) atennas
                        %ds = antpar.BsElementSpacingULA * (s-1) * wavelength;
                        ds = antpar.BsElementPosition(s)*wavelength;
                        temp =  BsGain_Theta_BS(k,s) * exp(j * k_CONST * ds * sin( ThetaBs(k)*pi/180))* ...
                            MsGain_Theta_MS(k,u) * exp(j * (k_CONST * du * sin( ThetaMs(k)*pi/180  ) + bulkpar.Phi_LOS(k,1) * pi/180 )) * ...
                            exp(j * k_CONST * linkpar.MsVelocity(k) * cos((ThetaMs(k) - linkpar.MsDirection(k))*pi/180) * t(k,:));
                        
                        % all the parameters are fixed within one drop
                        
                        H(u,s,1,:,k) = (sqrt(1/(K_factors(k)+1)) * squeeze(H(u,s,1,:,k)) + sqrt(K_factors(k)/(K_factors(k)+1)) * temp.').';
                        
                    end % Rx antennas
                end % Tx antennas
                
                H(:,:,2:end,:,k)= sqrt(1/(K_factors(k)+1)) *  H(:,:,2:end,:,k);    
                
            end % if there is LOS
            
        end % links
        
        output_Phi_LOS       = zeros(K,1);
        
        for k = 1:K % cycles links
            if indx(k)~=0      
                output_Phi_LOS(k,1) = k_CONST * linkpar.MsVelocity(k) * cos((ThetaMs(k) - linkpar.MsDirection(k))*pi/180) * (t(k,end)+delta_t(k));                    
            end % if there is LOS        
        end % links 
        
        output_Phi_LOS = prin_value((output_Phi_LOS*180/pi + bulkpar.Phi_LOS));
        
    end % if 'LOS' option is activated
    
end

%%%%%%%%%%%%%%%%
%%%%%%%%%%%
%%%%%%%%
%%%%%        That's all folks !!!
%%
%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% A function that maps inputs from (-inf,inf) to (-180,180)
function y=prin_value(x)
y=mod(x,360);
y=y-360*floor(y/180);