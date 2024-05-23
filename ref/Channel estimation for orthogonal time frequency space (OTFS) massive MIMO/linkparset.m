function linkpar=linkparset(varargin)
%LINKPARSET Link parameter configuration for SCM
%   LINKPAR=LINKPARSET(K) is a struct consisting of randomly generated link
%   parameters for K links. LINKPAR=LINKPARSET(K,RMAX) uses cell radius
%   RMAX for generation of MS-BS distances (default: 500 meters).
%
%   LINKPAR=LINKPARSET(...,SEED) sets the random seed used in link
%   parameter generation. 
%
%   The parameters and their defaults are:
%
%   MsBsDistance    - see below
%   ThetaBs         - U(-180,180) degrees, U denotes uniform pdf
%   ThetaMs         - U(-180,180) degrees
%   OmegaBs         - NaN, this parameter is not currently used
%   OmegaMs         - NaN, this parameter is not currently used
%   MsVelocity      - 10 meters per second 
%   MsDirection     - U(-180,180) degrees with respect to broadside
%   MsHeight        - 1.5 meters
%   BsHeight        - 32 meters
%   MsNumber        - [1:K], i.e. all simulated links are different MSs
%
%   See [1, Fig. 5.2].
%
%   The pdf of the random variable (RV) MsBsDistance is R+RMIN, where R is
%   an RV with pdf p(r)=2*r/r0^2, where r0 defaults to (RMAX-RMIN) meters.
%   Hence, MsBsDistance is an RV such that users are approximately
%   uniformly distributed in a circular disk over [RMIN,RMAX] meters. RMIN
%   is fixed to 35 meters because some path loss models do not support
%   distances smaller than this. RMAX defaults to 500 meters as this is the
%   radius of microcell given in [1]. For usability, the same default is
%   used for all scenarios.
%   
%   Some further notes about the parameters:
%
%   - OmegaBs and OmegaMs define the orientation of antenna broadside with
%     respect to north. This parameter is currently redundant.
%   - MsHeight and BsHeight defaults are based on [1, Table 5.1].
%   - MsNumber is a positive integer defining the index number of MS for 
%     each link. This parameter is used in generation of inter-site
%     correlated shadow fading values; shadow fading is correlated for
%     links between a single MS and multiple BSs. There is no correlation
%     in shadow fading between different MSs. Examples: The default value
%     is the case where all links in a call to the SCM function correspond
%     to different MSs. Setting MsNumber=ones(1,K) corresponds to the case
%     where the links from a single MS to K different BSs are simulated. 
%
%     
%   Ref. [1]: 3GPP TR 25.996 v6.1.0 (2003-09)
%
%   See also SCM, SCMPARSET, ANTPARSET.

%   Authors: Jari Salo (HUT), Pekka Kyösti (EBIT), Daniela Laselva (EBIT), 
%   Giovanni Del Galdo (TUI), Marko Milojevic (TUI), Christian Schneider (TUI)
%   $Revision: 0.31$  $Date: Jan 14, 2005$


% defaults
num=1;      % number of links
rmax=500;   % cell radius

rmin=35;    % to prevent warnings from path loss models.

ni=length(varargin);
if ni>0, if (~isempty(varargin{1})), num=varargin{1}; end, end
if ni>1, if (~isempty(varargin{2})), rmax=varargin{2}; end, end
if ni>2, if (~isempty(varargin{3})), seed=varargin{3}; rand('state',floor(seed)); end, end
if ni>3, error('Too many input arguments!'), end



linkpar=struct( 'MsBsDistance',distrnd(num,rmax-rmin)+rmin,...
                'ThetaBs',360*(rand(1,num)-0.5),...
                'ThetaMs',360*(rand(1,num)-0.5),...
                'OmegaBs',repmat(NaN,1,num),...         
                'OmegaMs',repmat(NaN,1,num),...
                'MsVelocity',repmat(10,1,num),...
                'MsDirection',360*(rand(1,num)-0.5),...
                'MsHeight',repmat(1.5,1,num),...              
                'BsHeight',repmat(32,1,num),...               
                'MsNumber',1:num);                          
            
                
                
                
                
function d=distrnd(num,rmax)
% DISTRND Distance from BS in a circular cell
%   D=DISTRND(K,RMAX) generates K random variables from the pdf
%   p(r)=2*r/RMAX^2. This is the pdf of distance from base station when
%   users are uniformly (in area) distributed in a cell with radius RMAX.

%   Authors: Jari Salo (HUT), Marko Milojevic (TUI) 
%   $Revision: 0.1$  $Date: Sep 30, 2004$

% create random variables from triangular pdf whose width is 2*rmax
a=sum(rmax*rand(2,num));

% fold the random variables about the rmax
inds=find(a>rmax);
a(inds)=-a(inds)+2*rmax;

d=a(:).';

                
                
                
                
                
