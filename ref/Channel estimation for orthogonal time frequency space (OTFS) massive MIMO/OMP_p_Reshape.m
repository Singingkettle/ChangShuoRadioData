function pw_taovNt = OMP_p_Reshape(p_taov_Nt,Num_BSelement,Num_Pilot_v, Num_Pilot_tao)
pw_taov_Nt=fft(p_taov_Nt,[],3)/sqrt(Num_BSelement);
pw_taovNt = reshape(pw_taov_Nt,Num_Pilot_v*Num_Pilot_tao,Num_Pilot_v*Num_Pilot_tao*Num_BSelement);

% F=dftmtx(Num_BSelement)/sqrt(Num_BSelement);
% FD= kron(eye(Num_Pilot_v*Num_Pilot_tao),F);
% p_taovNt = reshape(p_taov_Nt,Num_Pilot_v*Num_Pilot_tao,Num_Pilot_v*Num_Pilot_tao*Num_BSelement);
% p_Nttaov = zeros(size(p_taovNt));
% pw_taovNt = zeros(size(p_taovNt));
% for i_taov=1:1:Num_Pilot_v*Num_Pilot_tao
%     for i_BSelement =1:1:Num_BSelement
%         p_Nttaov(:,(i_taov-1)*Num_BSelement+i_BSelement) =p_taovNt(:,(i_BSelement-1)*Num_Pilot_v*Num_Pilot_tao+i_taov);
%     end
% end
% pw_Nttaov=p_Nttaov*FD;
% for i_taov=1:1:Num_Pilot_v*Num_Pilot_tao
%     for i_BSelement =1:1:Num_BSelement
%         pw_taovNt(:,(i_BSelement-1)*Num_Pilot_v*Num_Pilot_tao+i_taov) =pw_Nttaov(:,(i_taov-1)*Num_BSelement+i_BSelement);
%     end
% end
end