clear
clc
close all

% 关于如何设置OFDM有效参数范围的参考https://www.mathworks.com/help/comm/ug/ofdm-transmitter-and-receiver.html

% rng(0)
% M = 4;                 % Modulation alphabet
% k = log2(M);           % Bits/symbol
% numSC = 128;           % Number of OFDM subcarriers
% cpLen = 32;            % OFDM cyclic prefix length
% maxBitErrors = 100;    % Maximum number of bit errors
% maxNumBits = 1e7;      % Maximum number of bits transmitted
% numDC = 117;
% frameSize = [k*numDC 1];
% qpskMod = comm.QPSKModulator('BitInput',true);
% ofdmMod = comm.OFDMModulator( ...
%     FFTLength=numSC, ...
%     CyclicPrefixLength=cpLen, ...
%     Windowing=true, ...
%     WindowLength=16);
% ofdmDemod = comm.OFDMDemodulator( ...
%     FFTLength=numSC, ...
%     CyclicPrefixLength=cpLen);
% errorRate = comm.ErrorRate(ResetInputPort=true);
%
% dataIn = randi([0,1],frameSize);              % Generate binary data
% qpskTx = pskmod(dataIn,M,InputType="bit");    % Apply QPSK modulation
% txSig = ofdmMod(qpskTx);
%
% h1 = designMultirateFIR(5,1, 1000);
% txsig1 = resample(double(txSig),5,1,h1);
%
% h2 = designMultirateFIR(1,5, 1000);
% txsig2 = resample(double(txsig1),1,5,h2);
%
%
% sum(abs(txsig2-txSig))
%
%
% qpskRx = ofdmDemod(txSig);
% dataOut = pskdemod(qpskRx,M,OutputType="bit");
% errorStats = errorRate(dataIn,dataOut,0);
%
%
% qpskRx1 = ofdmDemod(txsig2);
% dataOut1 = pskdemod(qpskRx1,M,OutputType="bit");
% errorStats1 = errorRate(dataIn,dataOut1,0);
%
%
% sum(abs(dataOut1-dataOut))

clc
clear
close all

iqImbalanceConfig.A = 0;
iqImbalanceConfig.P = 0;

phaseNoiseConfig.Level = -50;
phaseNoiseConfig.FrequencyOffset = 20;
phaseNoiseConfig.RandomStream = 'Global stream';
phaseNoiseConfig.Seed = 2137;

memoryLessNonlinearityConfig.Method = 'Cubic polynomial';
memoryLessNonlinearityConfig.LinearGain = 10;
memoryLessNonlinearityConfig.TOISpecification = 'IIP3';
memoryLessNonlinearityConfig.IIP3 = 30;
memoryLessNonlinearityConfig.AMPMConversion = 10;
memoryLessNonlinearityConfig.PowerLowerLimit = 10;
memoryLessNonlinearityConfig.PowerUpperLimit = inf;
memoryLessNonlinearityConfig.ReferenceImpedance = 1;

modulatorConfig.mode = 'QPSK';
modulatorConfig.order = 4;
modulatorConfig.ofdm.fftLength = 128;
modulatorConfig.ofdm.numGuardBandCarriers = [6; 5];
modulatorConfig.ofdm.insertDCNull = false;
modulatorConfig.ofdm.pilotInputPort = false;
modulatorConfig.ofdm.pilotCarrierIndices = [12; 26; 40; 54];
modulatorConfig.ofdm.cyclicPrefixLength = 16;
modulatorConfig.ofdm.windowing = false;
modulatorConfig.ofdm.windowLength = 1;
modulatorConfig.ofdm.oversamplingFactor = 1;
modulatorConfig.ofdm.numSymbols = 1;
modulatorConfig.ofdm.numTransmitAntennnas = 1;

param.iqImbalanceConfig = iqImbalanceConfig;
param.phaseNoiseConfig = phaseNoiseConfig;
param.memoryLessNonlinearityConfig = memoryLessNonlinearityConfig;
param.carrierFrequency = 60000;
param.timeDuration = 1;
param.sampleRate = 200e3;
param.modulatorConfig = modulatorConfig;
param.samplePerSymbol = 8;

source = RandomSource(param);

modualtor = OFDM(param);

x = source();
y = modualtor(x);
