clc;clear;
D=2;
N=10;
M=8;
L=zeros(N,N*D);
z_burst=zeros(N,1);
z_burst(1)=1;
z_burst(2)=2;
z_burst(8)=8;
z_burst(9)=9;
for i=1:1:N
    for j=1:1:D
        x1=mod(i+j-1-1,N)+1;
        y1=(i-1)*D+j;
        L(x1,y1)=1;
    end
end
% z_burst=L*z_block;
phi=randn(M,N);
y=phi*z_burst;
d_Nt=abs(L'*phi'*y);
g_Nt=sum(reshape(d_Nt,D,N),1);
p_s=12;
Nt=16;
Nts=8;
pos_Nts=zeros(1,Nts);
for i=1:1:Nts
    pos_Nts(i)=mod(p_s+i-1-1,Nt)+1;
end