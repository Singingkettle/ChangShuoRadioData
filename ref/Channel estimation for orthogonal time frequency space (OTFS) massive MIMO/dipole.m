function pattern=dipole(varargin)
%DIPOLE Field pattern of half wavelength dipole
%   PAT=DIPOLE(AZ) returns the azimuth field pattern
%   at angles given in AZ (degrees). 
%
%   PAT is a 3D-array with dimensions [2 1 LENGTH(AZ)]. 
%   The first two dimensions are the V and H 
%   polarizations, respectively.
%
%   PAT=DIPOLE(AZ,SLANT) gives the pattern of a 
%   slanted dipole. The slant angle is defined as
%   the counter clock-wise angle (in degrees) seen 
%   from the front of the dipole. 
%
%   Currently elevation is not supported. 
%
%   Example: To create a 2-element BS array with 
%   45 degrees slanted dipoles:
%       g=zeros(2,2,1,100); antpar=antparset;
%       az=linspace(-180,180);
%       g(1,:,:,:)=dipole(az,45);
%       g(2,:,:,:)=dipole(az,-45);
%       antpar.BsGainPattern=g;
%       antpar.BsGainAnglesAz=az;
%
%   See also ANTPARSET.

%   Author: Jari Salo (HUT)
%   $Revision: 0.1 $  $Date: July 22, 2004$


az=varargin{1};

if (nargin>1)
    slant=varargin{2};
    slant=-slant/180*pi;    % change sign
else
    slant=0;
end

% put all angles to radians
az=az/180*pi;

siz_az=size(az);        % elevation has same size
az_vec=az(:);

% assume elevation is zero
[X Y Z]=sph2cart(az_vec, zeros(size(az_vec)), repmat(1,size(az_vec)));

% rotation matrix in cartesian coordinates
R = [1 0 0; 0 cos(slant) -sin(slant); 0 sin(slant) cos(slant) ];
XYZr=R*[X.'; Y.'; Z.'];
[az el r]=cart2sph(XYZr(1,:), XYZr(2,:), XYZr(3,:));
el=reshape(el(:),siz_az);

% our coordinate system has elevation 90 deg to the zenith
% while the standard dipole formula has zero angle in zenith
offset=-pi/2;
el=-(el+offset);   % elevation is now from -90 to 90 (directly below to zenith)


% ideal pattern of a slanted dipole 
% the dipole pattern becomes singular at {0,180} degrees elevation
tol=1e6*eps;
I1=find(abs(el)<tol);
I2=find(abs(el-pi)<tol);
I=[I1(:); I2(:)];   % set these indices to zero
patternV=zeros(size(el));
patternH=zeros(size(el));
patternV(I)=0;
patternH(I)=0;
Inot=setdiff([1:numel(el)],I);
patternV(Inot)=sqrt(1.64)*abs(cos(pi/2*cos(el(Inot)))./sin(el(Inot)))*cos(slant);
patternH(Inot)=sqrt(1.64)*abs(cos(pi/2*cos(el(Inot)))./sin(el(Inot)))*sin(slant);

pattern=zeros(2,1,numel(el));
pattern(1,1,:)=patternV;
pattern(2,1,:)=patternH;



