function [OFDM_signal_TTI] = OFDM_cp_symbol_generation(x_input,Size_FFT,Index_Fist_Subcarrier)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [OFDM_signal_TTI] = OFDM_cp_symbol_generation(x_input,Size_FFT,Index_Fist_Subcarrier)
%
% INPUTS:      x_input: # information date symbol
%              Size_FFT: # FFT size for OFDM operation
%              Index_Fist_Subcarrier: the index of the first subcarrier to carry data
%              
%
% OUTPUT:      OFDM_signal_TTI: OFDM signal in one TTI(subframe)
%              
%
% Comments:   In LTE, for OFDM, there is guard band to reduce the
% interference to the out band. So the subcarriers of the two side should
% be left empty.
% 
% 
%
% DESCRIPTION: generate OFDM signal based on 3GPP LTE.
%             
%
% AUTHOR:           Jianjun Li,
% COPYRIGHT:
% DATE:             06.10.2016
% Last Modified:    06.20.2005
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[Num_BSelement,Num_date_persymbol,Num_symbol]=size(x_input);
% x_input_temp=zeros(Num_date_persymbol,Num_symbol);
% x_input_temp(:,1:1:Num_symbol/2)=fft(x_input(:,1:1:Num_symbol/2))/sqrt(Num_symbol/2);
% x_input_temp(:,end-Num_symbol/2+1:1:end)=fft(x_input(:,end-Num_symbol/2+1:1:end))/sqrt(Num_symbol/2);

OFDM_signal_TTI=zeros(Num_BSelement,Num_symbol*Size_FFT*5/4);
for i_BSelement=1:1:Num_BSelement
for c_symbol=1:Num_symbol
    x=zeros(1,Size_FFT);
    for c_subcarrier=Index_Fist_Subcarrier:Index_Fist_Subcarrier+Num_date_persymbol-1
        x(c_subcarrier)=x_input(i_BSelement,c_subcarrier-Index_Fist_Subcarrier+1,c_symbol);
    end
    
    Stx=ifft(x)*sqrt(Size_FFT);
    Stx=[Stx(Size_FFT*3/4+1:Size_FFT),Stx];
    OFDM_signal_TTI(i_BSelement,(c_symbol-1)*Size_FFT*5/4+1:c_symbol*Size_FFT*5/4)=Stx;
end
end
