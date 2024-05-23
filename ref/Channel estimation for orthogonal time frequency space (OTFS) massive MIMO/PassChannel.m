function [RxSig]=PassChannel(TxSig,CH_OFDM_TD,Num_BSelement,Nfft,NumOFDMSyms)

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
Num_delay=size(CH_OFDM_TD,3);
RxSig=zeros(Num_BSelement,Nfft,NumOFDMSyms);



for i_BSelement=1:1:Num_BSelement
    H_TD_Txi=squeeze(CH_OFDM_TD(1,i_BSelement,:,:,1));
for OFDMSymIdx=1:NumOFDMSyms
    Rxtemp=zeros(1,Nfft);
    for sampleIdx=(OFDMSymIdx-1)*Nfft*5/4+Nfft/4+1:OFDMSymIdx*Nfft*5/4
        
        for DelayIdx=1: Num_delay
            if sampleIdx-DelayIdx+1<1
                continue;
            end
            %??? H_TD(DelayIdx,sampleIdx)
%             y_idx=sampleIdx-(OFDMSymIdx-1)*Nfft*5/4-Nfft/4
%             x_idx=sampleIdx-DelayIdx+1
%             DelayIdx
%             t=sampleIdx-DelayIdx+1
%            y(t) = sum_tao x(t-tao)*h(t-tao,tao)
            Rxtemp(sampleIdx-(OFDMSymIdx-1)*Nfft*5/4-Nfft/4)= Rxtemp(sampleIdx-(OFDMSymIdx-1)*Nfft*5/4-Nfft/4) +H_TD_Txi(DelayIdx,sampleIdx-DelayIdx+1)*TxSig(i_BSelement,sampleIdx-DelayIdx+1);
        end
    end
    RxSig(i_BSelement,:,OFDMSymIdx)=Rxtemp;
end
end
RxSig = squeeze(sum(RxSig,1));
end

