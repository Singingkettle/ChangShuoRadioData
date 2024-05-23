function [bulk_parameters]=generate_bulk_par(scmpar,linkpar,antpar)
%GENERATE_BULK_PAR Generation of SCM bulk parameters
%   [BULK_PAR]=GENERATE_BULK_PAR(SCMPAR,LINKPAR,ANTPAR) generates the
%   "bulk" parameters according to 3GPP TR 25.996. For explanation of
%   the input structs, see SCMPARSET, LINKPARSET, and ANTPARSET. 
%   Denoting with K the number of links, N the number of paths, 
%   M the number of subpaths, the fields BULK_PAR are as follows: 
%
%   When scmpar.ScmOptions is 'none' or 'urban_canyon':
%   delays          - path delays in seconds [KxN]
%   path_powers     - relative path powers [KxN]
%   aods            - angles of departure in degrees over (-180,180) [KxNxM]
%   aoas            - angles of arrival in degrees over (-180,180) [KxNxM]
%   subpath_phases  - random phases for subpaths in degrees over (0,360) [KxNxM]
%   path_losses     - path losses in linear scale [Kx1]
%   shadow_fading   - shadow fading losses in linear scale [Kx1]
% 
%   In addition, when scmpar.ScmOptions is 'los' (in addition to the above):
%   K_factors       - K factors for all links [Kx1]
%   Phi_LOS         - random phases for LOS paths in degrees over (-180,180) [Kx1]
%
%   When scmpar.ScmOptions is 'polarized' (in addition to scmpar.ScmOptions='none'):
%   subpath_phases  - random phases for subpaths in degrees over (0,360)
%                     [Kx4xNxM], where the second dimension are the [VV VH HV HH]
%                     components (iid).
%   xpd             - cross-polarization ratios in linear scale [Kx2xN],
%                     where the (:,1,:)th dimension is the V-to-H power coupling, 
%                     and (:,2,:)th dimension is the H-to-V power coupling.
%
%   Ref. [1]: 3GPP TR 25.996 v6.1.0 (2003-09)
%
%   See also SCM.

%   Authors: Jari Salo (HUT), Daniela Laselva (EBIT), Giovanni Del Galdo (TUI),
%   Marko Milojevic (TUI), Pekka Kyösti (EBIT), Christian Schneider (TUI)
%   $Revision: 0.21 $  $Date: Dec 14, 2004$


% Input parameter validity checking is done in the main function.


% extract certain parameters from the input structs
Scenario=scmpar.Scenario;


switch lower(Scenario)
    
    % SUBURBAN MACRO AND URBAN MACRO, [1, Sec. 5.3.1]
    case {'suburban_macro','urban_macro'}
        
        bulk_parameters=macro(scmpar,linkpar,antpar);
        
        
        % URBAN MICRO, [1, Sec. 5.3.2]    
    case {'urban_micro'}        
        
        bulk_parameters=micro(scmpar,linkpar,antpar);
        
end     % end of user parameter generation main program








% FUNCTION DEFINITIONS
%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% A function to generate sigma_as, sigma_ds and sigma_sf for all links
% Step 3 in [1, Sec 5.3.1], see also [1, Sec 5.6].
% Here Section 5.6 in [1] is interpreted so that it describes the channel matrix
% generation for a single MS only. Hence, there is inter-site correlation
% only between radio links between a single MS and multiple BSs.
function sigmas=step3(scmpar,linkpar)

% extract certain parameters from the input structs
MsNumber=linkpar.MsNumber(:);  
Scenario=scmpar.Scenario;
ScmOptions=scmpar.ScmOptions;

NumLinks=length(MsNumber);

% matrices from [1,Sec. 5.6]
%alfa_beta=0.5; 
%gamma_beta=-0.6; 
%gamma_alfa=-0.6;
%A=[1 alfa_beta gamma_alfa; alfa_beta 1 gamma_beta;gamma_alfa gamma_beta 1];
%B=[0 0 0; 0 0 0; 0 0 0.5];
Bsq=[0 0 0; 0 0 0; 0 0 0.7071];
bsq=0.7071;     % Bsq(3,3)
% pre-computed value: C=sqrtm(A-B)
C = [0.8997 0.1926 -0.3917; 0.1926 0.8997 -0.3917; -0.3917 -0.3917  0.4395];

% the number of different MS
NumOfMs= max(MsNumber); % MsNumber is a vector! 
if (NumOfMs>10*NumLinks)
    warning('MATLAB:SparseMsNumberVector','Max index of linkpar.MsNumber is large compared to number of links!')
end

switch lower(Scenario)
    
    case {'suburban_macro'}
        
        % general environment parameters for suburban macro [1, Table 5.1]
        mu_as      =  0.69 ;
        epsilon_as =  0.13 ;
        mu_ds      = -6.80 ;
        epsilon_ds =  0.288;
        sigma_sf_ave   =  8    ; % in dB
        
        % generate alphas, betas and gammas for all links
        abc = C*randn(3,NumLinks);
        
        % inter-site correlation terms for all different MSs 
        gamma= bsq*randn(1,NumOfMs);    % bsq*ksi_3 for all different MSs
        gammas=gamma(MsNumber); gammas=gammas(:).';  % so that works also when NumOfMs==1
        abc(3,:)=abc(3,:) + gammas;    % add inter-site correlation term
      
        sigma_ds = 10.^(epsilon_ds*abc(1,:).' + mu_ds);       
        sigma_as = 10.^(epsilon_as*abc(2,:).' + mu_as);
        sigma_sf = 10.^(0.1*sigma_sf_ave*abc(3,:).');
        
        % output
        sigmas=[sigma_ds sigma_as sigma_sf];
        
        
    case {'urban_macro'}    
        
        % general environment parameters for urban macro [1, Table 5.1]
        if strcmp(scmpar.BsUrbanMacroAS,'fifteen')
            mu_as      =  1.18 ;
            epsilon_as =  0.210;
        else     % Note: 8 degree angle spread is set automatically if no match to 'fifteen'
            mu_as      =  0.810;
            epsilon_as =  0.34 ;
        end    
            mu_ds      = -6.18 ;        
            sigma_sf_ave   =  8    ; % in dB            
            epsilon_ds =  0.18 ;            
        
        % generate alphas, betas and gammas for all links
        abc = C*randn(3,NumLinks);
        
        % inter-site correlation terms for all different MSs 
        gamma= bsq*randn(1,NumOfMs);    % bsq*ksi_3 for all different MSs
        gammas=gamma(MsNumber); gammas=gammas(:).';     % so that works also when NumOfMs==1
        abc(3,:)=abc(3,:) + gammas;    % add inter-site correlation term
      
        sigma_ds = 10.^(epsilon_ds*abc(1,:).' + mu_ds);       
        sigma_as = 10.^(epsilon_as*abc(2,:).' + mu_as);
        sigma_sf = 10.^(0.1*sigma_sf_ave*abc(3,:).');
        
        % output
        sigmas=[sigma_ds sigma_as sigma_sf];

        
        
    case {'urban_micro'}
        
        if strcmpi(ScmOptions,'los')
            sigma_sf_ave = 4;    % in dB
        else    % NLOS
            sigma_sf_ave = 10;    % in dB
        end
        
        % inter-site correlation terms for all different MSs 
        gamma_intersite= bsq*randn(1,NumOfMs);    % bsq*ksi_3 for all different MSs
        gamma_intersites=gamma_intersite(MsNumber); gamma_intersites=gamma_intersites(:).';
        gamma= C(3,:)*randn(3,NumLinks)+ gamma_intersites;    % add inter-site correlation term
      
        sigma_sf = 10.^(0.1*sigma_sf_ave*gamma);
        
        % output
        sigmas=[sigma_sf];

end





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% A function that maps inputs from (-inf,inf) to (-180,180)
function y=prin_value(x)
y=mod(x,360);
y=y-360*floor(y/180);





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% A function to generate bulk parameters for suburban and urban macro cells
% See [1, Sec.5.3.1].
function bulk_parameters=macro(scmpar,linkpar,antpar)

% extract the number of users from the first field of linkpar struct
NumLinks = length(linkpar.MsBsDistance);

% extract certain parameters from the input structs
Scenario              = scmpar.Scenario;
ScmOptions            = scmpar.ScmOptions;
N                     = scmpar.NumPaths;
M                     = scmpar.NumSubPathsPerPath;
DelaySamplingInterval = scmpar.DelaySamplingInterval;

% check that M=20
% if (M ~= 20)
%     M=20;
%     warning('MATLAB:NumSubPathsChanged','NumSubPathsPerPath is not 20! Using NumSubPathsPerPath=20 instead.')
% end

% make sure that user-specific parameters are row vectors
ThetaBs      = linkpar.ThetaBs(:).'; 
ThetaMs      = linkpar.ThetaMs(:).'; 



% general environment parameters for suburban macro [1, Table 5.1]
switch lower(Scenario)
    case {'suburban_macro'}
        r_as      = 1.2;        
        r_ds      = 1.4;        
        sigma_rnd = 3;    % per-path shadowing std in dB, needed in step 5
        
    case {'urban_macro'}
        r_as      = 1.3;        
        r_ds      = 1.7;        
        sigma_rnd = 3;    % per-path shadowing std in dB, needed in step 5
        
end



% step 3: determine DS, AS and SF for all users
% This step takes into account channel scenario automatically
% Note: path loss is computed in step 13
sigmas   = step3(scmpar,linkpar);   % a (NumLinks x 3) matrix
sigma_ds = sigmas(:,1);    
sigma_as = sigmas(:,2);
sigma_sf = sigmas(:,3);


% step 4: generate delays in a (NumLinks x N) matrix
% The unit of taus is seconds
sigma_ds     = repmat(sigma_ds,1,N);                % delay spreads for all users
taus         = sort(-r_ds*sigma_ds.*log(rand(NumLinks,N)),2);
taus_sorted  = taus - repmat(taus(:,1),1,N );       % normalize min. delay to zero
if (DelaySamplingInterval>0)
    taus_rounded=DelaySamplingInterval*floor( taus_sorted/DelaySamplingInterval + 0.5);
else 
    taus_rounded=taus_sorted;
end



% step 5: determine random average powers in a (NumLinks x N) matrix
ksi    = randn(NumLinks,N)*sigma_rnd;           % per-path shadowing        
Pprime = exp((1-r_ds)/r_ds*taus_sorted./sigma_ds ).*10.^(-ksi/10);
P      = Pprime./repmat(sum(Pprime,2),1,N);     % power normalization     
%Psub   = repmat(P,[1 1 M])/M;                   % a (NumLinks x N x M) array



% step 6: determine AoDs
sigma_aod     = r_as*sigma_as;                              % AoD angle spreads for all users
deltas        = abs(randn(NumLinks,N).*repmat(sigma_aod,1,N));   
deltas_sorted = sort(deltas,2);
delta_aod     = sign(rand(NumLinks,N)-0.5).*deltas_sorted;  % a (NumLinks x N) matrix of path AoDs
delta_aod     = reshape(delta_aod.',NumLinks*N,1);
delta_aod     = repmat(delta_aod,1,M).';                    % a (M x (NumLinks*N)) matrix


% step 7: associate the path delays with AoDs (a dummy step)



% step 8: determine the powers, phases and offset AoDs at the BS
% The phases are computed in step 13
aod_2deg     = [0.0894 0.2826 0.4984 0.7431 1.0257 1.3594 1.7688 2.2961 3.0389 4.3101];     % [1, Table 5.2]
delta_nm_aod = [aod_2deg; -aod_2deg];
delta_nm_aod = delta_nm_aod(:);   % this (M x 1) vector is the same for all users and paths
delta_nm_aod = repmat(delta_nm_aod,1,N*NumLinks);  % a (NumLinks x N) matrix




% step 9: determine the AoAs 
% If urban_canyon option is selected steps 9a-9d replace step 9
if (strcmp(ScmOptions,'urban_canyon')==1)
    
    % STEPS 9a-9d  [1, Sec. 5.5.4]
    % Note that MsDirection below effectively overrides the one given in
    % the input struct LINKPAR. Note also that MS array orientation is not
    % actually needed anywhere.
    MsDirection = 360*(rand(NumLinks,1)-0.5);     % step 9a: generate MS DoT = Street Orientation
    %MsArrayDir  = 360*(rand(NumLinks,1)-0.5);     % step 9b: generate MS Array orientation
    alpha       = 0.9;                            % percentage of links experiencing urban canyon effect                                     
    p_DoT       = 0.5;
    offset      = 180;                    
    
    
    % Select the links that experience urban canyon
    beta        = rand(1,NumLinks);         % step 9c
    uc_links    = find(beta<=alpha);
    nuc_links   = find(beta>alpha);         % these links do not experience the canyon
    
    % Generate the AoAs for the urban canyon links
    delta_aoa               = MsDirection;
    offset_links            = uc_links(find(rand(length(uc_links),1)>p_DoT));
    delta_aoa(offset_links) = MsDirection(offset_links)+offset;
    delta_aoa               = repmat(delta_aoa,1,N);

    % Generate the AoAs for non-canyon links
    P_nuc_links             = P(nuc_links,:);
    sigma_aoa_nuc_links     = 104.12*(1-exp(-0.2175*abs(10*log10(P_nuc_links))));
    delta_aoa(nuc_links,:)  = randn(length(nuc_links),N).*sigma_aoa_nuc_links;     % a (NumLinks x N) matrix of path AoAs
    delta_aoa               = reshape(delta_aoa.',NumLinks*N,1);
    delta_aoa               = repmat(delta_aoa,1,M).';           % a (M x (NumLinks*N)) matrix
    
    
else    % Urban Canyon option not used
    % step 9
    sigma_aoa = 104.12*(1-exp(-0.2175*abs(10*log10(P))));
    delta_aoa = randn(NumLinks,N).*sigma_aoa;     % a (NumLinks x N) matrix of path AoAs
    delta_aoa = reshape(delta_aoa.',NumLinks*N,1);
    delta_aoa = repmat(delta_aoa,1,M).';          % a (M x (NumLinks*N)) matrix
    
    
end





% step 10: determine the offset AoAs at the MS 
aoa_35deg    = [1.5679 4.9447 8.7224 13.0045 17.9492 23.7899 30.9538 40.1824 53.1816 75.4274];      % [1, Table 5.2]
delta_nm_aoa = [aoa_35deg; -aoa_35deg];
delta_nm_aoa = delta_nm_aoa(:);       % these are the same for all users and paths
delta_nm_aoa = repmat(delta_nm_aoa,1,N*NumLinks); % a (M x N*NumLinks) matrix





% step 11: pair AoA subpaths randomly with AoD subpaths (within a path)
[dummy h]           = sort(rand(M,N*NumLinks),1);       % create N*NumLinks random permutations of integers [1:M]
inds                = h+repmat([1:M:M*N*NumLinks],M,1)-1;       
delta_nm_aoa_paired = delta_nm_aoa(inds);    % random permutation of columns, a (M x N*NumLinks) matrix



% step 12: determine angles depending on array orientation
ThetaBs      = repmat(ThetaBs,N,1); ThetaBs=ThetaBs(:).';
ThetaBs      = repmat(ThetaBs,M,1);      % a (M x N*NumLinks) matrix
% theta_nm_aod = ThetaBs+delta_aod+delta_nm_aod;
theta_nm_aod = ThetaBs+delta_aod+delta_nm_aod(1:M,:);   % variable M
ThetaMs      = repmat(ThetaMs,N,1); ThetaMs=ThetaMs(:).';
ThetaMs      = repmat(ThetaMs,M,1);      % a (M x N*NumLinks) matrix
% theta_nm_aoa = ThetaMs + delta_aoa+delta_nm_aoa_paired;
theta_nm_aoa = ThetaMs + delta_aoa+delta_nm_aoa_paired(1:M,:);   % variable M;

% Values of theta_nm_aoa and theta_nm_aod may be outside (-180,180).
% This is corrected in the following.
theta_nm_aoa=prin_value(theta_nm_aoa);
theta_nm_aod=prin_value(theta_nm_aod); 


% put AoDs, AoAs, and power gains into a 3D-array with dims [NumLinks N M]
theta_nm_aod=reshape(theta_nm_aod,M,N,NumLinks);                
theta_nm_aod=permute(theta_nm_aod,[3 2 1]);   
theta_nm_aoa=reshape(theta_nm_aoa,M,N,NumLinks);                
theta_nm_aoa=permute(theta_nm_aoa,[3 2 1]);   



% step 13: Path loss and shadowing 
% employ the user-defined path loss model
path_losses=feval(scmpar.PathLossModel,scmpar,linkpar); 
path_losses=10.^(-path_losses(:)/10);    % a (NumLinks x 1) vector


% optional steps for polarized arrays and output generation
if (strcmp(lower(ScmOptions),'polarized')==1)   % [1, Sec. 5.5.1]
    % Step 13 - dummy step
    
    % Step 14 - dummy step
    
    % Step 15 - generates random phases
    phi = 360*rand(NumLinks,4,N,M);      % random phases for all users: [NumLinks pol path subpath]
    
    % Step 16 - dummy step
    
    % Step 17 - generate XPD ratios 
    A           = 0.34*10*log10(P)+7.2; % in dB
    B           = 5.5;  % in dB
    xpd_in_db   = zeros(NumLinks,2,N);

    xpd_in_db(:,1,:)=A+B*randn(size(A));   % V-to-H coupling 
    xpd_in_db(:,2,:)=A+B*randn(size(A));   % H-to-V coupling
    
    xpd=10.^(xpd_in_db/10);                 % size()=[NumLinks pol N], xpd(:,1,:) is V-to-H coupling
    
    % output
    bulk_parameters=struct( 'delays',taus_rounded,...
                            'path_powers',P,...             % before: 'subpath_powers',Psub,...
                            'aods',theta_nm_aod,...         % in degrees
                            'aoas',theta_nm_aoa,...         % in degrees
                            'subpath_phases',phi,...        % in degrees
                            'xpd',xpd,...                   % in linear scale
                            'path_losses',path_losses,...   % in linear scale 
                            'shadow_fading',sigma_sf);      % in linear scale          

else
    phi= 360*rand(NumLinks,N,M);        % random phases for all users
    
    % output
    bulk_parameters=struct( 'delays',taus_rounded,...
                            'path_powers',P,...             % before: 'subpath_powers',Psub,...
                            'aods',theta_nm_aod,...         % in degrees
                            'aoas',theta_nm_aoa,...         % in degrees
                            'subpath_phases',phi,...        % in degrees
                            'path_losses',path_losses,...   % in linear scale 
                            'shadow_fading',sigma_sf);      % in linear scale          

end





% end of function 'macro'







%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% A function to generate urban micro cell parameters
function bulk_parameters=micro(scmpar,linkpar,antpar)


% extract the number of users from the first field of linkpar struct
MsBsDistance    =linkpar.MsBsDistance;
NumLinks        =length(MsBsDistance);

% extract certain parameters from the input structs
ScmOptions              =scmpar.ScmOptions;
N                       =scmpar.NumPaths;
M                       =scmpar.NumSubPathsPerPath;
DelaySamplingInterval   =scmpar.DelaySamplingInterval;


% check that M=20
% if (M ~= 20)
%     M=20;
%     warning('MATLAB:NumSubPathsChanged','NumSubPaths is not 20! Using NumSubPaths=20 instead.')
% end


% make sure that user-specific parameters are row vectors
MsBsDistance=linkpar.MsBsDistance(:).';
ThetaBs     =linkpar.ThetaBs(:).'; 
ThetaMs     =linkpar.ThetaMs(:).'; 


% general environment parameters for urban micro [1, Table 5.1]
max_ds      =1.2e-6;  % maximum excess delay in seconds
max_aod     =40;     % maximum AoD angle in degrees
sigma_rnd   =3;    % per-path shadowing std in dB, needed in step 6


% step 3: determine DS, AS and SF for all users
% This step takes into account channel scenario automatically
% path loss is computed in step 13
sigma_sf=step3(scmpar,linkpar);   % a (NumLinks x 1) matrix
sigma_sf=sigma_sf(:);


% step 4: generate delays in a (NumLinks x N) matrix
% The unit of taus is seconds
taus=max_ds*rand(NumLinks,N);  % path delays for all users



% step 5
taus=sort(taus,2);
taus=taus-repmat(taus(:,1),1,N );       % normalize min. delay to zero
if (DelaySamplingInterval>0)
    taus_rounded=DelaySamplingInterval*floor( taus/DelaySamplingInterval + 0.5);
else 
    taus_rounded=taus;
end


% step 6: determine random average powers in a (NumLinks x N) matrix
z=randn(NumLinks,N)*sigma_rnd;       % per-path shadowing
Pprime=10.^( -(taus/1e-6 + z/10) );
P=Pprime./repmat(sum(Pprime,2),1,N);    % power normalization     
%Psub=repmat(P,[1 1 M])/M;       % a (NumLinks x N x M) array of subpath powers for all users


% step 7: determine AoDs
delta_aod=2*max_aod*(rand(NumLinks,N)-0.5);
delta_aod=reshape(delta_aod.',NumLinks*N,1);
delta_aod=repmat(delta_aod,1,M).';      % a (M x (NumLinks*N)) matrix



% step 8: associate the path delays with AoDs (a dummy step)



% step 9: determine the powers, phases and offset AoDs at the BS
aod_5deg=[0.2236 0.7064 1.2461 1.8578 2.5642 3.3986 4.4220 5.7403 7.5974 10.7753]; % [1, Table 5.2]
delta_nm_aod = [aod_5deg; -aod_5deg];
delta_nm_aod=delta_nm_aod(:);   % this (M x 1) vector is the same for all users and paths
delta_nm_aod=repmat(delta_nm_aod,1,N*NumLinks);  % a (NumLinks x N) matrix






% step 10: determine the AoAs
% If urban_canyon option is selected steps 10a-10d replace step 10
if (strcmp(ScmOptions,'urban_canyon')==1)
    
    % STEPS 10a-10d  [1, Sec. 5.5.4]
    % Note that MsDirection below effectively overrides the one given in
    % the input struct LINKPAR. Note also that MS array orientation is not
    % actually needed anywhere.
    MsDirection = 360*(rand(NumLinks,1)-0.5);     % step 10a: generate MS DoT = Street Orientation
    %MsArrayDir  = 360*(rand(NumLinks,1)-0.5);     % step 10b: generate MS Array orientation
    alpha       = 0.9;                            % percentage of links experiencing urban canyon effect                                     
    p_DoT       = 0.5;
    offset      = 180;                    
   
    
    
    % Select the links that experience urban canyon
    beta        = rand(1,NumLinks);         % step 10c
    uc_links    = find(beta<=alpha);
    nuc_links   = find(beta>alpha);         % these links do not experience the canyon
    
    % Generate the AoAs for the urban canyon links
    delta_aoa               =MsDirection;
    offset_links            =uc_links(find(rand(length(uc_links),1)>p_DoT));
    delta_aoa(offset_links) =MsDirection(offset_links)+offset;
    delta_aoa               =repmat(delta_aoa,1,N);

    % Generate the AoAs for non-canyon links
    P_nuc_links             = P(nuc_links,:);
    sigma_aoa_nuc_links     = 104.12*(1-exp(-0.265*abs(10*log10(P_nuc_links))));
    delta_aoa(nuc_links,:)  = randn(length(nuc_links),N).*sigma_aoa_nuc_links;     % a (NumLinks x N) matrix of path AoAs
    delta_aoa               = reshape(delta_aoa.',NumLinks*N,1);
    delta_aoa               = repmat(delta_aoa,1,M).';           % a (M x (NumLinks*N)) matrix
    
    
else    % Urban Canyon option not used
    % step 10
    sigma_aoa = 104.12*(1-exp(-0.265*abs(10*log10(P))));
    delta_aoa = randn(NumLinks,N).*sigma_aoa;     % a (NumLinks x N) matrix of path AoAs
    delta_aoa = reshape(delta_aoa.',NumLinks*N,1);
    delta_aoa = repmat(delta_aoa,1,M).';          % a (M x (NumLinks*N)) matrix
    
    
end







% step 11: determine the offset AoAs at the MS 
aoa_35deg       =[1.5679 4.9447 8.7224 13.0045 17.9492 23.7899 30.9538 40.1824 53.1816 75.4274];      % [1, Table 5.2]
delta_nm_aoa    = [aoa_35deg; -aoa_35deg];
delta_nm_aoa    =delta_nm_aoa(:);       % these are the same for all users and paths
delta_nm_aoa    =repmat(delta_nm_aoa,1,N*NumLinks); % a (M x N*NumLinks) matrix



% step 12: pair AoA subpaths randomly with AoD subpaths (within a path)
[dummy h]           = sort(rand(M,N*NumLinks));       % create N*NumLinks random permutations of integers [1:M]
inds                =h+repmat([1:M:M*N*NumLinks],M,1)-1;       
delta_nm_aoa_paired =delta_nm_aoa(inds);    % random permutation of columns, a (M x N*NumLinks) matrix




% step 13: determine the antenna gains of BS and MS 
% determine angles depending on array orientation
ThetaBs     =repmat(ThetaBs,N,1); ThetaBs=ThetaBs(:).';
ThetaBs     =repmat(ThetaBs,M,1);      % a (M x N*NumLinks) matrix
theta_nm_aod=ThetaBs+delta_aod+delta_nm_aod;
ThetaMs     =repmat(ThetaMs,N,1); ThetaMs=ThetaMs(:).';
ThetaMs     =repmat(ThetaMs,M,1);      % a (M x N*NumLinks) matrix
theta_nm_aoa= ThetaMs + delta_aoa+delta_nm_aoa_paired;

% Values of theta_nm_aoa and theta_nm_aod may be outside (-180,180).
% This is corrected in the following.
theta_nm_aoa=prin_value(theta_nm_aoa);          
theta_nm_aod=prin_value(theta_nm_aod); 

% put AoDs, AoAs, and power gains into a 3D-array with dims [NumLinks N M]
theta_nm_aod=reshape(theta_nm_aod,M,N,NumLinks);                
theta_nm_aod=permute(theta_nm_aod,[3 2 1]);   
theta_nm_aoa=reshape(theta_nm_aoa,M,N,NumLinks);                
theta_nm_aoa=permute(theta_nm_aoa,[3 2 1]);   

 
% employ the user-defined path loss model
path_losses=feval(scmpar.PathLossModel,scmpar,linkpar); 
path_losses=10.^(-path_losses(:)/10);    % a (NumLinks x 1) vector



% optional steps 
switch (lower(ScmOptions))   % [1, Sec. 5.5.1]
    
    case ('los')
        LOS_probability=max([zeros(size(MsBsDistance)); (300-MsBsDistance)./300]);
        prob=rand(size(LOS_probability));
        LOS_probability=LOS_probability.*(prob<=LOS_probability);
        
        % calculate K factors of the links --  K factor > 0 only if LOS_probability>0
        K_factors=10.^((13-0.03*MsBsDistance)/10); % [1, Sec. 5.5.3]
        K_factors=K_factors.*(LOS_probability~=0);  % in linear scale
        K_factors=K_factors(:);
        % set the LOS phase randomly
        Phi_LOS=360*(rand(NumLinks,1)-0.5);

        phi= 360*rand(NumLinks,N,M);        % random phases for all users

        
        % output
        bulk_parameters=struct( 'delays',taus_rounded,...
                                'path_powers',P,...                 % before: 'subpath_powers',Psub,...
                                'aods',theta_nm_aod,...
                                'aoas',theta_nm_aoa,...
                                'subpath_phases',phi,...
                                'K_factors',K_factors,...           % in linear scale
                                'Phi_LOS',Phi_LOS,...               % phases for LOS paths, in degrees
                                'path_losses',path_losses,...       % in linear scale 
                                'shadow_fading',sigma_sf);          % in linear scale          
        
    
    
    case ('polarized')
        % Step 13 - dummy step
        
        % Step 14 - dummy step
        
        % Step 15 - generates random phases
        phi= 360*rand(NumLinks,4,N,M);      % random phases for all users: [NumLinks pol path subpath]
        
        % Step 16 - dummy step
        
        % Step 17 - generate XPD ratios 
        A=8;       % in dB
        B=8;       % in dB
        xpd_in_db=zeros(NumLinks,2,N);

        xpd_in_db(:,1,:)=A+B*randn(NumLinks,N);    % V-to-H coupling 
        xpd_in_db(:,2,:)=A+B*randn(NumLinks,N);    % H-to-V coupling

        xpd=10.^(xpd_in_db/10);                     % size()=[NumLinks pol N], xpd(:,1,:) is V-to-H coupling
        
        % output
        bulk_parameters=struct( 'delays',taus_rounded,...
                                'path_powers',P,...             % before: 'subpath_powers',Psub,...
                                'aods',theta_nm_aod,...         % in degrees
                                'aoas',theta_nm_aoa,...         % in degrees
                                'subpath_phases',phi,...        % in degrees
                                'xpd',xpd,...                   % in linear scale
                                'path_losses',path_losses,...   % in linear scale 
                                'shadow_fading',sigma_sf);      % in linear scale          
        
    
        
        
    case {'none','urban_canyon'}
        phi= 360*rand(NumLinks,N,M);        % random phases for all users
        
        % output
        bulk_parameters=struct( 'delays',taus_rounded,...
                                'path_powers',P,...             % before: 'subpath_powers',Psub,...
                                'aods',theta_nm_aod,...
                                'aoas',theta_nm_aoa,...
                                'subpath_phases',phi,...
                                'path_losses',path_losses,...   % in dB 
                                'shadow_fading',sigma_sf);      % in linear scale          
        
end



% end of function 'micro'



