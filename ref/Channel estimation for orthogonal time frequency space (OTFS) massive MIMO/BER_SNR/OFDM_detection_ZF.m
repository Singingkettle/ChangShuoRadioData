function [x_dect] = OFDM_detection_ZF(Rx_sig,CH_TD,OFDM_Parameter)
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

[Nfft,NumOFDMSyms]=size(Rx_sig);

[N_path, N_sampling]=size(CH_TD);
H_TD=zeros(Nfft,N_sampling);
H_TD_temp=CH_TD;
H_TD(1:N_path,:)=H_TD_temp;
P_starting=OFDM_Parameter.Size_of_FFT*1/4;

x_dect=zeros(OFDM_Parameter.Number_subcarrier,NumOFDMSyms);

IFH=conj(dftmtx(Nfft))/Nfft;
FH=dftmtx(Nfft);

for symbolIdx=1:NumOFDMSyms
    
    H_effect_temp=H_TD(:,(symbolIdx-1)*OFDM_Parameter.Size_of_FFT*5/4+1:symbolIdx*OFDM_Parameter.Size_of_FFT*5/4);
    H_effect=zeros(Nfft,Nfft);
    
    for rowIdx=1:Nfft
        for collumIdx=1:Nfft
            
            tao_ch=mod(rowIdx-collumIdx,Nfft)+1;
            if P_starting+rowIdx-tao_ch+1>0
                H_effect(rowIdx,collumIdx)=H_effect_temp(tao_ch,P_starting+rowIdx-tao_ch+1);
            end
        end
    end
    
    HF_effect=FH*H_effect*IFH;
    Rxtemp=sqrt(1/Nfft)*fft(Rx_sig(:,symbolIdx));
    
    x_temp=inv(HF_effect)*Rxtemp;
    
    for subcarrierIdx=1:OFDM_Parameter.Number_subcarrier
        x_dect(subcarrierIdx,symbolIdx)=sign(real(x_temp(OFDM_Parameter.Index_Fist_SC+subcarrierIdx-1)));
    end
    
end

