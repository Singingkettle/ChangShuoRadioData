function [CH_OFDM_TD, CH_OFDM_FD,CH_OTFS_DD] = CH_Maping_OFDM (SCM_MIMO_Ch,delays,OFDM_Parameter,Num_OFDM_symbol_per_TTI)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [CH_OFDM] = CH_Maping_OFDM(SCM_MIMO_Ch,delays,Num_Oversampling,Ior_Ioc);
%
% INPUTS: SCM_MIMO_Ch: SCM channel matrix sampling
%         delays: delays of different path of channel matrix
%         OFDM_Parameter: Parameter of OFDM

% OUTPUTS: CH_OFDM_FD: MIMO Channel matrix for OFDM in frequency domain;
%          CH_OFDM_TD: MIMO Channel matrix for OFDM in time domain;
%
%
% DESCRIPTION: l channel maping is for ofdm simulated.
%
% AUTHOR:           Jianjun Li, 
% COPYRIGHT:        Communication & Networking Lab, S.A.I.T, Suwon, Korea
% DATE:             06.10.2016
% Last Modified:    06.10.2016
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Rate_Sampling = OFDM_Parameter.Rate_Sampling;
Size_of_FFT = OFDM_Parameter.Size_of_FFT;


[Rx,Tx,N_path,Num_sampling,Num_User]=size(SCM_MIMO_Ch);

CH_OFDM_FD = zeros(Rx,Tx,Size_of_FFT,Num_sampling,Num_User);


Max_Delay_sample=ceil(delays(1,N_path)/(Rate_Sampling)+0.5)+1;
CH_OFDM_TD = zeros(Rx,Tx,Max_Delay_sample,Num_sampling,Num_User); 


% real channel maping
for userIdx=1:Num_User
    for samplingIdx=1:Num_sampling
        H=SCM_MIMO_Ch(:,:,:,samplingIdx,userIdx);
       
        for RxIdx=1:Rx
            for TxIdx=1:Tx
                Ch_Timedomain=zeros(1,Size_of_FFT);
                Ch_Frequencydomain=zeros(1,Size_of_FFT); 
                Ch_Timedomain(1)=H(RxIdx,TxIdx,1);
                for c3=2:N_path
                    Index_sample_delay=ceil(delays(1,c3)/(Rate_Sampling)+0.5);
                    Ch_Timedomain(Index_sample_delay)=Ch_Timedomain(Index_sample_delay)+H(RxIdx,TxIdx,c3);
                end
                Ch_Frequencydomain = fft(Ch_Timedomain);
                CH_OFDM_FD(RxIdx,TxIdx,:,samplingIdx,userIdx) = Ch_Frequencydomain;
                CH_OFDM_TD(RxIdx,TxIdx,:,samplingIdx,userIdx) = Ch_Timedomain(1:Max_Delay_sample);
            end
        end
    end
end

CH_OTFS_DD=fft(CH_OFDM_TD(:,:,:,Size_of_FFT*5/4*1/2:Size_of_FFT*5/4:Num_sampling,:),[],4);

% size(abs(squeeze(CH_OTFS_DD)))
% Max_Delay_sample
% Num_OFDM_symbol_per_TTI
% surf(abs(squeeze(CH_OTFS_DD)))
%surf(1:Max_Delay_sample,1:Num_OFDM_symbol_per_TTI,abs(squeeze(CH_OTFS_DD)));