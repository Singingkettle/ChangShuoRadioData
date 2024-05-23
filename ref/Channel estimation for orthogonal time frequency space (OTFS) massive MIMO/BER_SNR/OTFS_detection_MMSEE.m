function [x_dect] = OTFS_detection_MMSEE(Rx_sig,CH_DD,OFDM_Parameter,theta)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [x_dect] = OFDM_detection(Rx_sig,CH_FD,OFDM_Parameter)
%
% INPUTS:      Rx_sig: received signal
%              CH_FD: timr invariant channel in frequency 
%              OFDM_Parameter: parameter related to OFDM 
%              
%
% OUTPUT:      x_dect: the detect data symbol.
%              
%
% Comments:   
% 
% 
%
% DESCRIPTION: Recover the original data symbol from the received OFDM signal.
%             
%
% AUTHOR:           Jianjun Li,
% COPYRIGHT:
% DATE:             06.10.2016
% Last Modified:    06.20.2005
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Nfft=OFDM_Parameter.Size_of_FFT;

[Nfft,NumOFDMsubframe]=size(Rx_sig);

x_dect=zeros(OFDM_Parameter.Number_subcarrier,NumOFDMsubframe);

[N_path, N_sampling]=size(CH_DD);
H_DD=zeros(Nfft,N_sampling);
HD_DD_temp=CH_DD;
H_DD(1:N_path,:)=HD_DD_temp;

Rx_sig_temp=fft(Rx_sig,[],2)*sqrt(NumOFDMsubframe);

y=reshape(Rx_sig_temp,NumOFDMsubframe*Nfft,1);

H_effect=zeros(NumOFDMsubframe*Nfft,NumOFDMsubframe*Nfft);

for rowIdx=1:NumOFDMsubframe*Nfft
    for collumIdx=1:NumOFDMsubframe*Nfft
        v_y=floor((rowIdx-1)/Nfft)+1;
        tao_y=mod(rowIdx-1,Nfft)+1;
        v_x=floor((collumIdx-1)/Nfft)+1;
        tao_x=mod(collumIdx-1,Nfft)+1;
        
        v_ch=mod(v_y-v_x,NumOFDMsubframe)+1;
        tao_ch=mod(tao_y-tao_x,Nfft)+1;
        
        H_effect(rowIdx,collumIdx)=H_DD(tao_ch,v_ch);
    end
end

I=eye(NumOFDMsubframe*Nfft);
W=inv(H_effect'*H_effect+I*theta)*H_effect';
x_temp=W*y;
x_temp=reshape(x_temp,Nfft,NumOFDMsubframe);

for symbolIdx=1:NumOFDMsubframe
    
    for subcarrierIdx=1:OFDM_Parameter.Number_subcarrier
        x_dect(subcarrierIdx,symbolIdx)=sign(real(x_temp(OFDM_Parameter.Index_Fist_SC+subcarrierIdx-1,symbolIdx)));
    end
    
end




