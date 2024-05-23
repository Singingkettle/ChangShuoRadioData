function [RxSig]=PassChannel(TxSig,CH_TD,Nfft,NumOFDMSyms)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [RxSig]=PassChannel(TxSig,CH_TD,Nfft,NumOFDMSyms)
%
% INPUTS:      TxSig: transmit signal
%              CH_TD: Time invariant multipath delay Channel
%              Nfft: FFT size for OFDM operation
%              NumOFDMSyms: number of OFDM symbols in each subframe(TTI)
%
% OUTPUT:      RxSig: Received signal after transmitting through the channel
%              
%
% Comments:    
% 
%
% DESCRIPTION: generate OFDM receive by transmit signal pass through the time invariant multipath delay channel.
%             
%
% AUTHOR:           Jianjun Li,
% COPYRIGHT:
% DATE:             06.10.2016
% Last Modified:    06.20.2005
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


RxSig=zeros(Nfft,NumOFDMSyms);
H_TD=squeeze(CH_TD);
[Num_delay,Temp_leng]=size(H_TD);


for OFDMSymIdx=1:NumOFDMSyms
    Rxtemp=zeros(1,Nfft);
    for sampleIdx=(OFDMSymIdx-1)*Nfft*5/4+Nfft/4+1:OFDMSymIdx*Nfft*5/4
        
        for DelayIdx=1: Num_delay
            if sampleIdx-DelayIdx+1<1
                continue;
            end
            Rxtemp(sampleIdx-(OFDMSymIdx-1)*Nfft*5/4-Nfft/4)= Rxtemp(sampleIdx-(OFDMSymIdx-1)*Nfft*5/4-Nfft/4) +H_TD(DelayIdx,sampleIdx-DelayIdx+1)*TxSig(sampleIdx-DelayIdx+1);
        end
    end
    RxSig(:,OFDMSymIdx)=Rxtemp;
end


