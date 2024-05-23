function [hw_taovNt,pos_table] = OMP_3D(y,pw_taovNt,Num_Pilot_tao,Num_Pilot_v,Nt,taos,vs,Nts,CH_DD0)
% inputs: 
%         y-->measurements
%         P-->mensurement matrix
%         K -->Spaserity

% output: h_est_Struc-->the recovery signal

CH_ADD= ifft(CH_DD0,[],1)*sqrt(Nt);
CH_ADD0=zeros(size(CH_ADD));
CH_ADD0(:,:,1:ceil(Num_Pilot_v/2))= CH_ADD(:,:,end-ceil(Num_Pilot_v/2)+1:end);
CH_ADD0(:,:,end-ceil(Num_Pilot_v/2)+1:end)= CH_ADD(:,:,1:ceil(Num_Pilot_v/2));
hw_Nttaov0 = CH_ADD0(:);
[N,taovNt]=size(pw_taovNt);
taov=Num_Pilot_tao*Num_Pilot_v;
err = 1e-3;  
hw_taovNt = zeros(Num_Pilot_tao*Num_Pilot_v*Nt, 1);  % Initialize the recovery signal

y_i = y - pw_taovNt * hw_taovNt;    % residual error

Phi_s = [];
pos_table=[];
i_taos=1;
stop = 0;
while ~stop             
    prod = abs(pw_taovNt'*y_i).^2;       %  Step 1): calculate the correlation between the (1+(l-1)*Nt)-th  to (l*Nt)-th  columns and the residual signal 
    prod = reshape(prod,Num_Pilot_tao,Num_Pilot_v,Nt);
    prod_tao= sum(sum(prod,3),2);      % Num_Pilot_tao*1
    [val,pos_tao]=max(prod_tao);       %  Step 2): find the value and position of the most matching columns
    prod_pos_tao = prod(pos_tao,:,:);
    prod_v =  transpose(squeeze(sum(prod_pos_tao,3)));  % Num_Pilot_v*1
    [val,pos_v]=sort(prod_v,'descend');  
    pos_vs = pos_v(1:vs);
    prod_pos_v = prod_pos_tao(1,pos_vs,:);
    prod_Nt = transpose(squeeze(sum(prod_pos_v,2)));  % 1*Nt
    L=zeros(Nt,Nt*Nts);
for i=1:1:Nt
    for j=1:1:Nts
        x1=mod(i+j-1-1,Nt)+1;
        y1=(i-1)*Nts+j;
        L(x1,y1)=1;
    end
end
    d_Nt=L'*transpose(prod_Nt);
    g_Nt=sum(reshape(d_Nt,Nts,Nt),1);
    [val,p_s]=max(g_Nt); 
    pos_Nts=zeros(1,Nts);    
    for i=1:1:Nts
        pos_Nts(i)=mod(p_s+i-1-1,Nt)+1;
    end
    [val,pos_Nt]=sort(prod_Nt,'descend');              
%      pos_Nts = pos_Nt(1:Nts); 
     pos = repmat(pos_tao + (pos_vs-1)*Num_Pilot_tao,1,Nts) + repmat((pos_Nts-1)*Num_Pilot_tao*Num_Pilot_v,vs,1);
     pos =  reshape(pos,1,Nts*vs); 
            pos_table = [pos_table,pos];
            Phi_s=[Phi_s,pw_taovNt(:,pos)];    %  Step 3): update the argment matrix and record the position,
            pos_temp = repmat(pos_tao + (pos_v-1)*Num_Pilot_tao,1,Nt) + repmat((pos_Nt-1)*Num_Pilot_tao*Num_Pilot_v,Num_Pilot_v,1);
            pos_temp =  reshape(pos_temp,1,Nt*Num_Pilot_v); 
            pw_taovNt(:,pos_temp)=zeros(N,Nt*Num_Pilot_v);                        %  remove the slice just selected
            b_s=(Phi_s'*Phi_s)\Phi_s'*y; 
                                                                    %  Step 4): solve the LS problem to obatain a new signal estimate
            y_i= y-Phi_s*b_s;                          %  Step 5): Calculate the new residual
                                                        
           i_taos = i_taos + 1;                                  %Iteration counter         
                                                               
    %Check Halting Condition
    if (i_taos >= taos + 1 ||  norm(y_i) <= err*norm(y))   % norm(r_n)<=err 
      stop = 1;
    end                                         
    
end
  hw_taovNt(pos_table) = b_s;    %  Step 7): get the recovered signal
  hw_Nttaov=zeros(size(hw_taovNt));
for i_taov=1:1:Num_Pilot_v*Num_Pilot_tao
    for i_BSelement =1:1:Nt
        hw_Nttaov((i_taov-1)*Nt+i_BSelement,1) =hw_taovNt((i_BSelement-1)*Num_Pilot_v*Num_Pilot_tao+i_taov,1);
    end
end
hw_Nt_tao_v = reshape(hw_Nttaov,Nt,Num_Pilot_tao,Num_Pilot_v);
CH_ADD(1:Nt,1:Num_Pilot_tao,1:Num_Pilot_v) = hw_Nt_tao_v;
 %End StrucOMP iteration
% NMSE_Bernoul = sum(sum(sum((abs(CH_ADD-CH_ADD0)).^2)))/sum(sum(sum((abs(CH_ADD0)).^2)));
end








