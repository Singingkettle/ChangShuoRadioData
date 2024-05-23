function [OTFS_signal_TTI] = OTFS_cp_symbol_generation(x_input,Size_FFT,Index_Fist_Subcarrier)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% [OTFS_signal_TTI] = OTFS_cp_symbol_generation(x_input,Size_FFT,Index_Fist_Subcarrier)
%
% INPUTS:      x_input: # information date symbol
%              Size_FFT: # FFT size for OFDM operation
%              Index_Fist_Subcarrier: the index of the first subcarrier to carry data
%              
%
% OUTPUT:      OTFS_signal_TTI: OTFS signal in one TTI(subframe)
%              
%
% Comments:   In LTE, there is guard band to reduce the
% interference to the out band. So the subcarriers of the two side should
% be left empty.
% 
% 
%
% DESCRIPTION: generate OTFS signal based on 3GPP LTE.
%             
%
% AUTHOR:           Jianjun Li,
% COPYRIGHT:
% DATE:             06.10.2016
% Last Modified:    06.20.2005
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


[Num_date_persymbol,Num_symbol]=size(x_input);

Stx_temp=ifft(x_input,[],2)*sqrt(Num_symbol);

OTFS_signal_TTI=zeros(1,Num_symbol*Size_FFT*5/4);

for c_symbol=1:Num_symbol
    x=zeros(1,Size_FFT);
    for c_subcarrier=Index_Fist_Subcarrier:Index_Fist_Subcarrier+Num_date_persymbol-1
        x(c_subcarrier)=Stx_temp(c_subcarrier-Index_Fist_Subcarrier+1,c_symbol);
    end
    
    Stx=fft(x)/sqrt(Size_FFT);
    Stx=[Stx(Size_FFT*3/4+1:Size_FFT),Stx];
    OTFS_signal_TTI((c_symbol-1)*Size_FFT*5/4+1:c_symbol*Size_FFT*5/4)=Stx;
end

