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

SampleRate = 200e3;
TimeDuration = 1;
ModulationOrder = 4;
SamplePerSymbol = 8;
NumTransmitAntennnas = 1;

ModulatorConfig.base.mode = 'QPSK';
ModulatorConfig.base.PhaseOffset = pi/8;
ModulatorConfig.base.SymbolOrder = 'gray';
ModulatorConfig.ofdm.FFTLength = 128;
ModulatorConfig.ofdm.NumGuardBandCarriers = [6; 5];
ModulatorConfig.ofdm.InsertDCNull = false;
ModulatorConfig.ofdm.PilotInputPort = false;
ModulatorConfig.ofdm.PilotCarrierIndices = [12; 26; 40; 54];
ModulatorConfig.ofdm.CyclicPrefixLength = 16;
ModulatorConfig.ofdm.Windowing = false;
ModulatorConfig.ofdm.WindowLength = 1;
ModulatorConfig.ofdm.OversamplingFactor = 1;

source = RandomSource(SampleRate = SampleRate, ...
    TimeDuration = TimeDuration, ...
    ModulationOrder = ModulationOrder, ...
    SamplePerSymbol = SamplePerSymbol);

modualtor = OFDM(SampleRate = SampleRate, ...
    TimeDuration = TimeDuration, ...
    ModulationOrder = ModulationOrder, ...
    SamplePerSymbol = SamplePerSymbol, ...
    ModulatorConfig = ModulatorConfig);

x = source();
y = modualtor(x);
