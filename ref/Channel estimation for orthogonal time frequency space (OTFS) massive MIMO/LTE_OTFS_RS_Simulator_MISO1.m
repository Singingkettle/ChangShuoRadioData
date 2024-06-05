function [NMSE_Impulse,NMSE_Bernoul_OMP,NMSE_Bernoul_StrucOMP] = LTE_OTFS_RS_Simulator_MISO1(SNR,eta,NumBSelement,vel)
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
Num_FramePerDrop = 1;   % # of TTIs per drop (1 TTI = 1 Frame)
Num_SlotPerTTI = 2;   % # of slots per TTI
Per_TimeTTI = 1/1000; % 0.5e-3sec: period of time slot (seconds)  
% Ts=1/15000/2048;    %
delt_f=15000*2/2;
Ts=1/delt_f/2048;    % Ts=1/(delt_f*M_subcarrier)  T=1/delt_f;
Num_Subcarrier_PerRB = 12;   % # of carrier in one Resource block
Num_OFDM_symbol_per_slot=4;
Num_OFDM_symbol_per_TTI=Num_OFDM_symbol_per_slot*2;
% Per_TimeTTI = Num_OFDM_symbol_per_TTI/delt_f; % 0.5e-3sec: period of time slot (seconds)


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                   LINK LEVEL SIMULATION OF 3GPP LTE OTFS                  %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% OFDM parameters
Index_bandwith = 4;
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
scmpar.NumPaths=6;
% scmpar.NumPaths=1;
scmpar.NumSubPathsPerPath=20;
linkpar = linkparset(1);   % function of link parameters
antpar = antparset;   % parameter set for antennas
scmpar.NumTimeSamples = Num_OFDM_symbol_per_TTI*OFDM_Parameter.Size_of_FFT*5/4;   % # of channel realizations per drop
scmpar.NumBsElements = NumBSelement;   % # of BS antennas
scmpar.NumMsElements =  1;   % # of MS antennas
scmpar.CarrierFrequency = 2.15e9;   % carrier frequency
% scmpar.CarrierFrequency = 28e9;   % carrier frequency
scmpar.UniformTimeSampling = 'yes';   % uniform channel sampling for all users
scmpar.Scenario='urban_macro';
%% Calculate the channel sampling density
linkpar.MsVelocity=vel;
M_Velocity = linkpar.MsVelocity;   % velocity of the highest mobile user
scmpar.SampleDensity = round((2.99792458e8/scmpar.CarrierFrequency/M_Velocity)/2/(OFDM_Parameter.Rate_Sampling));   % sampling density (interval) per drop
%% Pilot parameters
% Num_Pilot_v = 12;  %%oven
v_max = linkpar.MsVelocity*scmpar.CarrierFrequency/3e8;
Num_Pilot_v = Num_OFDM_symbol_per_TTI*6/8;
% tao_max=1.2e-6;
tao_max = 4.5e-6;
M_max = ceil(tao_max/OFDM_Parameter.Rate_Sampling)+1;
Num_Pilot_tao= eta*OFDM_Parameter.Number_subcarrier;
Num_Pilot_tao = scmpar.NumBsElements * ceil(Num_Pilot_tao/scmpar.NumBsElements);% for inter pilot per antenna
NMSE_Impulse = zeros(length(SNR),Num_FramePerDrop);
NMSE_Bernoul_OMP = zeros(length(SNR),Num_FramePerDrop);
NMSE_Bernoul_StrucOMP = zeros(length(SNR),Num_FramePerDrop);

for SNR_Idx=1:1:length(SNR)
    %%%%%% SNR %%%%%%
%     SNR_Idx
    Es_No = power(10,SNR(SNR_Idx)/10);   % Calculate the ratio of the chip energy of BS to Gaussian noise with Var = 1
    power_pilot = 1;
    %% Generate Data Symbol
    x= sign(randn(scmpar.NumBsElements,OFDM_Parameter.Number_subcarrier,Num_OFDM_symbol_per_TTI,Num_FramePerDrop));
%     x=x*0;
    %% Generate Pilot Symbol
%     Cen_Pilot_v = ceil(Num_Pilot_v/2);
    Cen_Pilot_v = 1;
    p_Impulse= zeros(scmpar.NumBsElements,Num_Pilot_tao,Num_Pilot_v,Num_FramePerDrop);
    for i_NumBsElements=1:1:scmpar.NumBsElements
        p_Impulse(i_NumBsElements,(i_NumBsElements-1)*Num_Pilot_tao/scmpar.NumBsElements+1,Cen_Pilot_v)=1*sqrt(power_pilot*Num_Pilot_tao*Num_Pilot_v); 
    end
    p_Bernoul= sign(randn(scmpar.NumBsElements,Num_Pilot_tao,Num_Pilot_v,Num_FramePerDrop))*sqrt(power_pilot);

    %% Generate noise
    n = (randn(OFDM_Parameter.Size_of_FFT,Num_OFDM_symbol_per_TTI,Num_FramePerDrop)+1i*randn(OFDM_Parameter.Size_of_FFT,Num_OFDM_symbol_per_TTI,Num_FramePerDrop))*sqrt(1/2)/sqrt(Es_No);
%     n=n*0;  
    %% main operation
    for TTI_Idx=1:Num_FramePerDrop
        
        %% Generate OFDM signal
        OTFS_signal_per_TTI_Impulse=OTFS_cp_pilot_symbol_generation(x(:,:,:,TTI_Idx),p_Impulse(:,:,:,TTI_Idx),OFDM_Parameter.Size_of_FFT,OFDM_Parameter.Index_Fist_SC);
        OTFS_signal_per_TTI_Bernoul=OTFS_cp_pilot_symbol_generation(x(:,:,:,TTI_Idx),p_Bernoul(:,:,:,TTI_Idx),OFDM_Parameter.Size_of_FFT,OFDM_Parameter.Index_Fist_SC);
        
        %% Generatechannell
        
        [SCM_MIMO_Ch, delays, out] = scm(scmpar,linkpar,antpar);   % channel matrix sampling for all users over a drop
%          delays./out.delta_t
        %% 4D-Tx, Rx, Path, Sample
        
        %%%OFDM Channel Maping%%%%%%%%
        
        [CH_OFDM_TD, CH_OFDM_FD,CH_OTFS_DD] = CH_Maping_OFDM (SCM_MIMO_Ch,delays,OFDM_Parameter,Num_OFDM_symbol_per_TTI);
        
        
        %% Pass the Channel
        Rx_signal_OTFS_Impulse=PassChannel(OTFS_signal_per_TTI_Impulse,CH_OFDM_TD,scmpar.NumBsElements,OFDM_Parameter.Size_of_FFT,Num_OFDM_symbol_per_TTI);
        Rx_signal_OTFS_Bernoul=PassChannel(OTFS_signal_per_TTI_Bernoul,CH_OFDM_TD,scmpar.NumBsElements,OFDM_Parameter.Size_of_FFT,Num_OFDM_symbol_per_TTI);
        
        
        %% Add noise
%         Rx_signal_OFDM=Rx_signal_OFDM+n(:,:,TTI_Idx);
        Rx_signal_OTFS_Impulse=Rx_signal_OTFS_Impulse+n(:,:,TTI_Idx);
        Rx_signal_OTFS_Bernoul=Rx_signal_OTFS_Bernoul+n(:,:,TTI_Idx);
        %% Channel Estimation
        CH_DD=reshape(CH_OTFS_DD,size(CH_OTFS_DD,2),size(CH_OTFS_DD,3),size(CH_OTFS_DD,4));  %1*Nt*Delay*Dopper 
        CH_DD_delay=CH_DD(1,:,1);   %Nt*Delay*Dopper 
        Num_delay = sum(CH_DD_delay~=0);
%         delays(6)
        CH_DD_OTFS = zeros(scmpar.NumBsElements,OFDM_Parameter.Size_of_FFT,Num_OFDM_symbol_per_TTI,Num_FramePerDrop);
        CH_DD_OTFS(1:size(CH_DD,1),1:size(CH_DD,2),1:size(CH_DD,3)) =CH_DD;
        CH_DD0 = zeros(scmpar.NumBsElements,Num_Pilot_tao,Num_Pilot_v,Num_FramePerDrop);
        CH_DD0(1:size(CH_DD,1),1:size(CH_DD,2),1:size(CH_DD,3)) = CH_DD;

        CH_DD_Impulse     = zeros(scmpar.NumBsElements,OFDM_Parameter.Size_of_FFT,Num_OFDM_symbol_per_TTI,Num_FramePerDrop);
        CH_DD_Impulse(:,:,:,TTI_Idx)    =OTFS_cha_est_Impulse_MISO(Rx_signal_OTFS_Impulse,p_Impulse,Cen_Pilot_v,OFDM_Parameter,CH_DD0); %%%        
        CH_DD_Bernoul_OMP      = zeros(scmpar.NumBsElements,OFDM_Parameter.Size_of_FFT,Num_OFDM_symbol_per_TTI,Num_FramePerDrop);
        CH_DD_Bernoul_StrucOMP = zeros(scmpar.NumBsElements,OFDM_Parameter.Size_of_FFT,Num_OFDM_symbol_per_TTI,Num_FramePerDrop);  
        [CH_DD_Bernoul_OMP(:,:,:,TTI_Idx),CH_DD_Bernoul_StrucOMP(:,:,:,TTI_Idx)]=OTFS_cha_est_Bernoul_MISO(Rx_signal_OTFS_Bernoul,p_Bernoul,OFDM_Parameter,Num_delay,CH_DD0);

       
        NMSE_Impulse(SNR_Idx,TTI_Idx)     = sum(sum(sum((abs(CH_DD_Impulse(:,:,:,TTI_Idx)-CH_DD_OTFS)).^2)))/sum(sum(sum((abs(CH_DD_OTFS)).^2)));
        NMSE_Bernoul_OMP(SNR_Idx,TTI_Idx) = sum(sum(sum((abs(CH_DD_Bernoul_OMP(:,:,:,TTI_Idx)-CH_DD_OTFS)).^2)))/sum(sum(sum((abs(CH_DD_OTFS)).^2)));
        NMSE_Bernoul_StrucOMP(SNR_Idx,TTI_Idx) = sum(sum(sum((abs(CH_DD_Bernoul_StrucOMP(:,:,:,TTI_Idx)-CH_DD_OTFS)).^2)))/sum(sum(sum((abs(CH_DD_OTFS)).^2)));

    
    end
    
end
