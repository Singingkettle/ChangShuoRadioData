function [sigma_AS]=cas(theta,P,units)
%CAS Circular angle spread (3GPP TR 25.996)
%   SIGMA_AS=CAS(THETA,P) returns the circular angle spread  SIGMA_AS as
%   defined in Annex A of 3GPP TR 25.996 v6.1.0.  THETA are the angles (in
%   radians) of paths and P are powers  of the paths. THETA and P must be
%   of same size and the (i,j)th element of P must be the power
%   corresponding to the (i,j)th  angle. In 3GPP notation both THETA and P
%   are N X M matrices,  where N is the number of paths and M is the number
%   of subpaths. 
%
%   With SIGMA_AS=CAS(THETA,P,'deg') input and output angles are  given in
%   degrees.

%   Author: Jari Salo (HUT)
%   $Revision: 0.1 $  $Date: July 20, 2004$


% check that input args have same size
if (any(size(theta)-size(P))==1)
    error('cas: Input argument size mismatch!')
end

deg_flag=0; % unit is radians
if (nargin>2)
    if (strcmp(lower(units),'deg')==1)
        theta=theta/180*pi;     % computation is in radians
        deg_flag=1; % unit is degrees
    end
end


% vectorize inputs
P=P(:);
theta=theta(:);

len_theta=length(theta);

delta=linspace(-pi,pi);     % a 100-point grid for minimization
delta_mat=repmat(delta,len_theta,1);
theta_mat=repmat(theta,1,length(delta));
theta_mat=prin_value(theta_mat+delta_mat);
P_mat=repmat(P,1,length(delta));

% mean values over the grid
mu_thetas=sum( theta_mat.*P_mat )./sum(P_mat);

% demeaned angles
theta_nm_mus=theta_mat-repmat(mu_thetas,len_theta,1);
theta_nm_mus=prin_value(theta_nm_mus);
cas_vec= sqrt(sum(theta_nm_mus.^2.*P_mat)./sum(P_mat));

sigma_AS=min(cas_vec);

if (deg_flag==1)    % map back to degrees
    sigma_AS=sigma_AS/pi*180;
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% A function to map inputs from (-inf,inf) to (-pi,pi)
function y=prin_value(x)
y=mod(x,2*pi);
y=y-2*pi*floor(y/pi);

