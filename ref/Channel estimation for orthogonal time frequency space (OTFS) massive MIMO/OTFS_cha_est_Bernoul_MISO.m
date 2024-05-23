 function [CH_DD_OMP,CH_DD_StrucOMP] = OTFS_cha_est_Bernoul_MISO(Rx_sig,p_Bernoul,OFDM_Parameter,Num_delay,CH_DD0)
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

%Nfft=OFDM_Parameter.Size_of_FFT;
[Nfft,NumOFDMsubframe]=size(Rx_sig);
[Num_BSelement,Num_Pilot_tao,Num_Pilot_v]=size(p_Bernoul);
[temp,Tao_max,Num_OFDM_symbol_per_slot]=size(CH_DD0);
Tao_max=min(Tao_max,Num_Pilot_tao);
Idx_Pilot_tao_start = OFDM_Parameter.Index_Fist_SC;
Idx_Pilot_tao_end= OFDM_Parameter.Index_Fist_SC+Num_Pilot_tao-1;
Idx_Pilot_v_start = 1;
Idx_Pilot_v_end = Num_Pilot_v;
Idx_Pilot_v_start_temp = 1-ceil(Num_Pilot_v/2);
Idx_Pilot_v_end_temp = Num_Pilot_v-ceil(Num_Pilot_v/2);
CH_DD_OMP=zeros(Num_BSelement,Nfft,NumOFDMsubframe);
CH_DD_StrucOMP=zeros(Num_BSelement,Nfft,NumOFDMsubframe);
Rx_sig_temp=fft(Rx_sig,[],2)/sqrt(NumOFDMsubframe);
Rx_pilot_temp =Rx_sig_temp(Idx_Pilot_tao_start:Idx_Pilot_tao_end,Idx_Pilot_v_start:Idx_Pilot_v_end);
p_temp=reshape(Rx_pilot_temp,Num_Pilot_tao*Num_Pilot_v,1);
p_effect=zeros(Num_Pilot_v*Num_Pilot_tao,Num_Pilot_v*Num_Pilot_tao,Num_BSelement);
p_DD = zeros(Num_BSelement,Nfft,NumOFDMsubframe);
p_DD(:,Idx_Pilot_tao_start:Idx_Pilot_tao_end,Idx_Pilot_v_start:Idx_Pilot_v_end) = p_Bernoul;
for i_BSelement=1:1:Num_BSelement
for rowIdx=1:NumOFDMsubframe*Nfft
    for collumIdx=1:NumOFDMsubframe*Nfft
        v_y=floor((rowIdx-1)/Nfft)+1;
        tao_y=mod(rowIdx-1,Nfft)+1;
        v_x=floor((collumIdx-1)/Nfft)+1;
        tao_x=mod(collumIdx-1,Nfft)+1;
%         v_ch=mod(v_y-v_x,N_sampling)+1;
        v_ch=mod(v_y-v_x,NumOFDMsubframe)+1;
        tao_ch=mod(tao_y-tao_x,Nfft)+1;    
        v_x_temp = mod(v_x-1-ceil(NumOFDMsubframe/2),NumOFDMsubframe)+1-ceil(NumOFDMsubframe/2);
        if 1<=tao_x && tao_x<=Num_Pilot_tao && Idx_Pilot_tao_start<=tao_y && tao_y<=Idx_Pilot_tao_end && Idx_Pilot_v_start_temp <=v_x_temp && v_x_temp<=Idx_Pilot_v_end_temp && 1 <=v_y && v_y<=Num_Pilot_v
            p_rowIdx=(v_y-Idx_Pilot_v_start+1-1)*Num_Pilot_tao+tao_y-Idx_Pilot_tao_start+1;
            p_collumIdx=(v_x_temp-Idx_Pilot_v_start_temp+1-1)*Num_Pilot_tao+tao_x;
%             v_x,v_x_temp,tao_x
%             tao_ch,v_ch
            p_effect(p_rowIdx,p_collumIdx,i_BSelement)=p_DD(i_BSelement,tao_ch,v_ch);
        end
    end
end
end

p_effect = OMP_p_Reshape(p_effect,Num_BSelement,Num_Pilot_v, Num_Pilot_tao);
% Sparsity = min(6*Num_Pilot_v*Num_BSelement,size(p_temp,1));
Sparsity = 6;
% Sparsity = Num_delay;
Nvs=Num_Pilot_v*1/1;
if Num_BSelement<=32
    Nts=Num_BSelement;
else
    Nts=min(round(Num_BSelement/3)+8,Num_BSelement);
end
[h_temp_OMP,supp_h] = OMP(p_temp,p_effect,Sparsity*Nvs*Num_BSelement);
% [h_temp_StrucOMP,supp_h] = StrucOMP(p_temp,p_effect,Num_Pilot_v*Num_BSelement,Sparsity);
[h_temp_StrucOMP,supp_h] = OMP_3D(p_temp,p_effect,Num_Pilot_tao,Num_Pilot_v,Num_BSelement,Sparsity,Nvs,Nts,CH_DD0);
h_temp_OMP = OMP_h_Reshape(h_temp_OMP,Num_BSelement,Num_Pilot_tao,Num_Pilot_v);
h_temp_StrucOMP = OMP_h_Reshape(h_temp_StrucOMP,Num_BSelement,Num_Pilot_tao,Num_Pilot_v);

CH_DD_OMP(:,1:Tao_max,1:ceil(Num_Pilot_v/2))= h_temp_OMP(:,1:Tao_max,end-ceil(Num_Pilot_v/2)+1:end);
CH_DD_OMP(:,1:Tao_max,end-ceil(Num_Pilot_v/2)+1:end)= h_temp_OMP(:,1:Tao_max,1:ceil(Num_Pilot_v/2));
CH_DD_StrucOMP(:,1:Tao_max,1:ceil(Num_Pilot_v/2))= h_temp_StrucOMP(:,1:Tao_max,end-ceil(Num_Pilot_v/2)+1:end);
CH_DD_StrucOMP(:,1:Tao_max,end-ceil(Num_Pilot_v/2)+1:end)= h_temp_StrucOMP(:,1:Tao_max,1:ceil(Num_Pilot_v/2));
end


