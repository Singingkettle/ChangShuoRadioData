function [CH_DD] = OTFS_cha_est_Impulse_MISO(Rx_sig,p_Impulse,Cen_Pilot_v,OFDM_Parameter,CH_DD0)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%           
%
% AUTHOR:           Jianjun Li,
% COPYRIGHT:
% DATE:             06.10.2016
% Last Modified:    06.20.2005

% Modified by:       Wenqian Shen
% Last Modified:     2019/05/28
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[Num_BsElement,Num_Pilot_tao,Num_Pilot_v]=size(p_Impulse);
[Nfft,NumOFDMsubframe]=size(Rx_sig);    %delay-time
[Num_BsElement,Tao_max,Num_OFDM_symbol_per_slot]=size(CH_DD0);
Tao_max=min(Tao_max,Num_Pilot_tao/Num_BsElement);
CH_DD=zeros(Num_BsElement,Nfft,NumOFDMsubframe);
Rx_sig_temp=fft(Rx_sig,[],2)/sqrt(NumOFDMsubframe);  % y_f=1/N H_f*x_f

% if Num_Pilot_v ~= NumOFDMsubframe
%     for taoIdx = 1:1:Num_Pilot_tao
%         for vIdx = 1:1:Cen_Pilot_v
%         RowIdx = taoIdx;
%         CollumIdx = mod(floor(vIdx-(Cen_Pilot_v+1)/2),NumOFDMsubframe)+1; 
%         CH_DD(RowIdx,CollumIdx)= Rx_sig_temp(OFDM_Parameter.Index_Fist_SC-1+RowIdx,vIdx+floor((Cen_Pilot_v+1)/2)-1)/p_Impulse(1,Cen_Pilot_v);
%         end
%     end
% else
% if Num_BsElement==1
%     Tao_max=Num_Pilot_tao/8;   
% else
%      Tao_max=Num_Pilot_tao/Num_BsElement;
% end
% Tao_max=Num_Pilot_tao/Num_BsElement;
for BsElementIdx=1:1:Num_BsElement
for taoIdx = 1:1:Tao_max
    for vIdx = 1:1:Num_Pilot_v
        RowIdx =  taoIdx; 
        CollumIdx = mod(vIdx-Cen_Pilot_v,NumOFDMsubframe)+1; 
        CH_DD(BsElementIdx,RowIdx,CollumIdx)= Rx_sig_temp(OFDM_Parameter.Index_Fist_SC-1+RowIdx+(BsElementIdx-1)*Num_Pilot_tao/Num_BsElement,vIdx)/p_Impulse(1,Cen_Pilot_v);
    end
end
end

% NMSE_Impulse = sum(sum(sum((abs(CH_DD-CH_DD0)).^2)))/sum(sum(sum((abs(CH_DD0)).^2)));

end



