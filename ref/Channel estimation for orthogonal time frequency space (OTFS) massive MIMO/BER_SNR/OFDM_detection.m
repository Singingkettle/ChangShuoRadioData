function [x_dect] = OFDM_detection(Rx_sig,CH_FD,OFDM_Parameter)
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

x_dect=zeros(OFDM_Parameter.Number_subcarrier,NumOFDMSyms);

for symbolIdx=1:NumOFDMSyms
    
    H_FD=CH_FD(:,(symbolIdx-1/2)*OFDM_Parameter.Size_of_FFT*5/4);
   
    Rxtemp=Rx_sig(:,symbolIdx);
    
    x_temp=sqrt(1/Nfft)*fft(Rxtemp);
    
    for subcarrierIdx=1:OFDM_Parameter.Number_subcarrier
        x_dect(subcarrierIdx,symbolIdx)=sign(real(x_temp(OFDM_Parameter.Index_Fist_SC+subcarrierIdx-1)/H_FD(OFDM_Parameter.Index_Fist_SC+subcarrierIdx-1)));
    end
    
end


