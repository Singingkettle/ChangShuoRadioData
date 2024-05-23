function h_Nt_tao_v = OMP_h_Reshape(hw_taovNt,Num_BSelement,Num_Pilot_tao,Num_Pilot_v)

hw_Nttaov=zeros(size(hw_taovNt));
for i_taov=1:1:Num_Pilot_v*Num_Pilot_tao
    for i_BSelement =1:1:Num_BSelement
        hw_Nttaov((i_taov-1)*Num_BSelement+i_BSelement,1) =hw_taovNt((i_BSelement-1)*Num_Pilot_v*Num_Pilot_tao+i_taov,1);
    end
end
hw_Nt_taov=reshape(hw_Nttaov,Num_BSelement,Num_Pilot_tao*Num_Pilot_v);
h_Nt_taov = fft(hw_Nt_taov,[],1)/sqrt(Num_BSelement);
h_Nt_tao_v = reshape(h_Nt_taov,Num_BSelement,Num_Pilot_tao,Num_Pilot_v);
% F=dftmtx(Num_BSelement)/sqrt(Num_BSelement);
% FD= kron(eye(Num_Pilot_v*Num_Pilot_tao),F);
% hw_Nttaov=zeros(size(hw_taovNt));
% for i_taov=1:1:Num_Pilot_v*Num_Pilot_tao
%     for i_BSelement =1:1:Num_BSelement
%         hw_Nttaov((i_taov-1)*Num_BSelement+i_BSelement,1) =hw_taovNt((i_BSelement-1)*Num_Pilot_v*Num_Pilot_tao+i_taov,1);
%     end
% end
% h_Nttaov=FD*hw_Nttaov;
% h_Nt_tao_v = reshape(h_Nttaov,Num_BSelement,Num_Pilot_tao,Num_Pilot_v);
end
