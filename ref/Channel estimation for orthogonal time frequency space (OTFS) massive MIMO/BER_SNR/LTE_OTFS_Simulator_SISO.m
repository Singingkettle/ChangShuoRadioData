function [BER_OFDM, BER_OFDM_MMSE, BER_OTFS_MMSE] = LTE_OTFS_Simulator_SISO
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [BER_OTFS,BER_OFDM] = 3GPPLTE_MIMO_System_Simulator(Num_User,Num_TxAnt,Num_RxAnt)
%
% INPUTS:      Num_User: # of users
%              Num_TxAnt: # of transmit antennas (BS)
%              Num_RxAnt: # of receive antennas (MS)
%
% OUTPUT:      BER_OTFS_ZF: BER of OTFS with zero forcing equalization
%              BER_OTFS_MMSE: BER of OTFS with MMSE equalization
%              BER_OFDM: BER of OFDM
%
% Comments:
%
% DESCRIPTION: 3GPP LTE based SISO link level performance is simulated. 
%              SCM channel model,
%              Compare OFDM and OTFS
%
% AUTHOR:           Jianjun Li,
% COPYRIGHT:
% DATE:             06.10.2016
% Last Modified:    06.12.2005

% Modified by:       Wenqian Shen
% Last Modified:     2019/05/28
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% General Table

Table_Num_PRB= [6,15,25,50,75,100];
Table_FFT_Size=[128,256,512,1024,2048,2048];
Table_sampling_Rate=[2048/128,8,4,2048/1024,1,1];



%% General system parameters
Num_FramePerDrop = 1000;   % # of TTIs per drop (1 TTI = 1 Frame)
Num_SlotPerTTI = 2;   % # of slots per TTI
Per_TimeTTI = 1/1000; % 0.5e-3sec: period of time slot (seconds)
Ts=1/15000/2048;
Num_Subcarrier_PerRB = 12;   % # of carrier in one Resource block
Num_OFDM_symbol_per_slot=6;
Num_OFDM_symbol_per_TTI=Num_OFDM_symbol_per_slot*2;



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                   LINK LEVEL SIMULATION OF 3GPP LTE OTFS                  %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% OFDM parameters
Index_bandwith = 1;
Num_PRB = Table_Num_PRB(Index_bandwith);
OFDM_Parameter=struct(  'Rate_Sampling',Ts*Table_sampling_Rate(Index_bandwith),...
    'Size_of_FFT', Table_FFT_Size(Index_bandwith),...
    'Index_Fist_SC',(Table_FFT_Size(Index_bandwith)-Num_PRB*12)/2,...
    'Number_subcarrier', Num_PRB*12);
%OFDM_Parameter.Rate_Sampling

%%%%%% SCM channel %%%%%%
%% Scm parameters
%% SCM parameters
scmpar = scmparset;   % function of default set of SCM (System parameters for SCM)
linkpar = linkparset(1);   % function of link parameters
antpar = antparset;   % parameter set for antennas
scmpar.NumTimeSamples = Num_OFDM_symbol_per_TTI*OFDM_Parameter.Size_of_FFT*5/4;   % # of channel realizations per drop
scmpar.NumBsElements = 1;   % # of BS antennas
scmpar.NumMsElements = 1;   % # of MS antennas
scmpar.CarrierFrequency = 2.15e9;   % carrier frequency
scmpar.UniformTimeSampling = 'yes';   % uniform channel sampling for all users

%% Calculate the channel sampling density
linkpar.MsVelocity=100;
M_Velocity = linkpar.MsVelocity;   % velocity of the highest mobile user
scmpar.SampleDensity = round((2.99792458e8/scmpar.CarrierFrequency/M_Velocity)/2/(OFDM_Parameter.Rate_Sampling));   % sampling density (interval) per drop


SNR=0:5:30;
sigma_OTFS1=10.^[0:-0.2:-1.2];
sigma_OTFS2=10.^[-1:-0.5:-4];
BER_OFDM = zeros(1,length(SNR));
% BER_OFDM_ZF = zeros(1,length(SNR));
BER_OFDM_MMSE = zeros(1,length(SNR));
% BER_OTFS_ZF = zeros(1,length(SNR));
BER_OTFS_MMSE = zeros(1,length(SNR));
BER_OTFS_MMSE_est1 = zeros(1,length(SNR));
BER_OTFS_MMSE_est2 = zeros(1,length(SNR));
for SNR_Idx=1:1:length(SNR)
    %%%%%% SNR %%%%%%
    SNR_Idx
    Es_No = power(10,SNR(SNR_Idx)/10);   % Calculate the ratio of the chip energy of BS to Gaussian noise with Var = 1
    
    %% Generate Data Symbol
    x= sign(randn(OFDM_Parameter.Number_subcarrier,Num_OFDM_symbol_per_TTI,Num_FramePerDrop));

    x_dect_OFDM=x*0;
    x_dect_OFDM_MMSE=x*0;
    x_dect_OTFS_MMSE=x*0;
    x_dect_OTFS_MMSE_est1=x*0;
    x_dect_OTFS_MMSE_est2=x*0;
    %% Generate noise
    n = (randn(OFDM_Parameter.Size_of_FFT,Num_OFDM_symbol_per_TTI,Num_FramePerDrop)+i*randn(OFDM_Parameter.Size_of_FFT,Num_OFDM_symbol_per_TTI,Num_FramePerDrop))*sqrt(1/2)/sqrt(Es_No);
    
    
    %% main operation
    for TTI_Idx=1:Num_FramePerDrop
        
        %% Generate OFDM signal
        OFDM_signal_per_TTI=OFDM_cp_symbol_generation(x(:,:,TTI_Idx),OFDM_Parameter.Size_of_FFT,OFDM_Parameter.Index_Fist_SC);
        OTFS_signal_per_TTI=OTFS_cp_symbol_generation(x(:,:,TTI_Idx),OFDM_Parameter.Size_of_FFT,OFDM_Parameter.Index_Fist_SC);
        
        
        
        
        %% Generatechannell
        
        [SCM_MIMO_Ch, delays, out] = scm(scmpar,linkpar,antpar);   % channel matrix sampling for all users over a drop
        %%%OFDM Channel Maping%%%%%%%%
        [CH_OFDM_TD, CH_OFDM_FD,CH_OTFS_DD] = CH_Maping_OFDM (SCM_MIMO_Ch,delays,OFDM_Parameter,Num_OFDM_symbol_per_TTI);
        
        
        %% Pass the Channel
        %squeeze(CH_OFDM_TD)
        CH_TD=squeeze(CH_OFDM_TD(1,1,:,:,1));
        Rx_signal_OFDM=PassChannel(OFDM_signal_per_TTI,CH_TD,OFDM_Parameter.Size_of_FFT,Num_OFDM_symbol_per_TTI);
        
        Rx_signal_OTFS=PassChannel(OTFS_signal_per_TTI,CH_TD,OFDM_Parameter.Size_of_FFT,Num_OFDM_symbol_per_TTI);
        
        
        %% Add noise
        Rx_signal_OFDM=Rx_signal_OFDM+n(:,:,TTI_Idx);
        Rx_signal_OTFS=Rx_signal_OTFS+n(:,:,TTI_Idx);
        
        %% Signal Detection
        CH_FD= squeeze(CH_OFDM_FD(1,1,:,:,1));
        x_dect_OFDM(:,:,TTI_Idx)=OFDM_detection(Rx_signal_OFDM,CH_FD,OFDM_Parameter);
        
        CH_TD= squeeze(CH_OFDM_TD(1,1,:,:,1));
        x_dect_OFDM_MMSE(:,:,TTI_Idx)=OFDM_detection_MMSE(Rx_signal_OFDM,CH_TD,OFDM_Parameter,1/Es_No);
        
        CH_OTFS_DD= squeeze(CH_OTFS_DD(1,1,:,:,1));
        x_dect_OTFS_MMSE(:,:,TTI_Idx)=OTFS_detection_MMSEE(Rx_signal_OTFS,CH_OTFS_DD,OFDM_Parameter,1/Es_No);
       
        CH_OTFS_DD_est1 = CH_OTFS_DD+sqrt(sigma_OTFS1(SNR_Idx)).*(randn(size(CH_OTFS_DD,1),size(CH_OTFS_DD,2))+1i*randn(size(CH_OTFS_DD,1),size(CH_OTFS_DD,2)))/sqrt(2);
        x_dect_OTFS_MMSE_est1(:,:,TTI_Idx)=OTFS_detection_MMSEE(Rx_signal_OTFS,CH_OTFS_DD_est1,OFDM_Parameter,1/Es_No);
        
        CH_OTFS_DD_est2 = CH_OTFS_DD+sqrt(sigma_OTFS2(SNR_Idx)).*(randn(size(CH_OTFS_DD,1),size(CH_OTFS_DD,2))+1i*randn(size(CH_OTFS_DD,1),size(CH_OTFS_DD,2)))/sqrt(2);
        x_dect_OTFS_MMSE_est2(:,:,TTI_Idx)=OTFS_detection_MMSEE(Rx_signal_OTFS,CH_OTFS_DD_est2,OFDM_Parameter,1/Es_No);
        
    end
    
    
    %% Calculate the error bit
    en_OFDM=x-x_dect_OFDM;
    en_OFDM_MMSE=x-x_dect_OFDM_MMSE;
    en_OTFS_MMSE=x-x_dect_OTFS_MMSE;
    en_OTFS_MMSE_est1=x-x_dect_OTFS_MMSE_est1;
    en_OTFS_MMSE_est2=x-x_dect_OTFS_MMSE_est2;
    %% Results
    
    BER_OFDM(SNR_Idx)=sum(sum(sum(abs(en_OFDM))))/2/OFDM_Parameter.Number_subcarrier/Num_OFDM_symbol_per_TTI/Num_FramePerDrop;
    BER_OFDM_MMSE(SNR_Idx)=sum(sum(sum(abs(en_OFDM_MMSE))))/2/OFDM_Parameter.Number_subcarrier/Num_OFDM_symbol_per_TTI/Num_FramePerDrop;
    BER_OTFS_MMSE_est1(SNR_Idx)=sum(sum(sum(abs(en_OTFS_MMSE_est1))))/2/OFDM_Parameter.Number_subcarrier/Num_OFDM_symbol_per_TTI/Num_FramePerDrop;
    BER_OTFS_MMSE_est2(SNR_Idx)=sum(sum(sum(abs(en_OTFS_MMSE_est2))))/2/OFDM_Parameter.Number_subcarrier/Num_OFDM_symbol_per_TTI/Num_FramePerDrop;
    BER_OTFS_MMSE(SNR_Idx)=sum(sum(sum(abs(en_OTFS_MMSE))))/2/OFDM_Parameter.Number_subcarrier/Num_OFDM_symbol_per_TTI/Num_FramePerDrop;

end

save BER_OTFS_OFDM;

%%plot
figure;
semilogy(SNR, BER_OFDM,'ks-','LineWidth',1.5);
hold on;
semilogy(SNR, BER_OFDM_MMSE,'rd-','LineWidth',1.5);
hold on;
semilogy(SNR, BER_OTFS_MMSE_est1,'mo-','LineWidth',1.5);
hold on;
semilogy(SNR, BER_OTFS_MMSE_est2,'b^-','LineWidth',1.5);
hold on;
semilogy(SNR, BER_OTFS_MMSE,'g<-','LineWidth',1.5);
hold on;
legend('OFDM','OFDM with perfect CSI','OTFS with Impulse','OTFS with 3D-SOMP','OTFS with perfect CSI');
% axis([N_min N_max 10^(-2)  10^(0) ]);
grid on;
xlabel('SNR');
ylabel('BER');

end
