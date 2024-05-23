function [sigma_DS, excess_delay]=ds(tau,P)
%DS RMS delay spread 
%   SIGMA_DS=DS(TAU,P) returns the rms delay spread SIGMA_DS. TAU are the
%   delays of paths and P are the powers of the corresponding paths. If P
%   is a matrix, SIGMA_DS is computed for each column; in this case TAU can
%   be either a matrix with SIZE(TAU)=SIZE(P) or a column vector with the
%   same number of rows as P. If TAU is a column vector the same delays are
%   used for each column of P.
%   
%   [SIGMA_DS ED]=DS(TAU,P) returns also the excess delay in ED.
% 
%   Note that if P is an impulse response, SIGMA_DS is its sample rms delay
%   spread. 

%   Author: Jari Salo (HUT)
%   $Revision: 0.11 $  $Date: September 30, 2004$


if (ndims(tau) > 2 | ndims(P) > 2)
    error('Input arguments must be vectors or matrices!')
end


if (min(size(tau))==1)  % if tau is a vector
    tau=tau(:);
elseif (size(P,1) ~= size(tau,1) | size(P,2) ~= size(tau,2) )  
    error('Input argument size mismatch!')
end

% if P is a vector
if (min(size(P))==1)
    P=P(:);
end



% make the minimum delay of each column zero
if (min(size(tau))==1) % if tau is a vector
    tau=repmat(tau,1,size(P,2))-min(tau);
else    % if tau is matrix
    tau=tau-repmat(min(tau),size(tau,1),1);
end


Dvec=sum(tau.*P)./sum(P);
D=repmat(Dvec,size(tau,1),1);

% compute std of delay spread
sigma_DS=sqrt( sum((tau-D).^2.*P)./sum(P) );


if (nargout>1)
    excess_delay=max(tau);
end

