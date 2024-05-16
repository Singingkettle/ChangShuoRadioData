clc
clear
close all

%% 
TimeDuration = 0.1;
SampleRate = 200e3;
NumTransmitAntennnas = 1;
MasterClockRate = 600e3;

CarrierFrequency = 200e3;
IqImbalanceConfig.A = 3;
IqImbalanceConfig.P = 10;
PhaseNoiseConfig.Level = -50;
PhaseNoiseConfig.FrequencyOffset = 20;
MemoryLessNonlinearityConfig.Method = 'Saleh model';
MemoryLessNonlinearityConfig.InputScaling = 0;
MemoryLessNonlinearityConfig.AMAMParameters = [2.1587 1.1517];
MemoryLessNonlinearityConfig.AMPMParameters =  [4.0033 9.1040];
MemoryLessNonlinearityConfig.OutputScaling = 0;
MemoryLessNonlinearityConfig.ReferenceImpedance = 1;
ThermalNoiseConfig.NoiseTemperature = 290;
AGCConfig.AveragingLength = 256 * 4;
AGCConfig.MaxPowerGain = 400;

txRF = TRFSimulator(StartTime=0.2, ...
    SampleRate = SampleRate, ...
    CarrierFrequency=CarrierFrequency, ...
    IqImbalanceConfig=IqImbalanceConfig, ...
    PhaseNoiseConfig=PhaseNoiseConfig, ...
    MasterClockRate = MasterClockRate, ...
    MemoryLessNonlinearityConfig=MemoryLessNonlinearityConfig);
rayChannel = Rayleigh(CarrierFrequency=CarrierFrequency, ...
    SampleRate=SampleRate, PathDelays=0, ...
    AveragePathGains=0, MaximumDopplerShift=0);

ricChannel = Rician(CarrierFrequency=CarrierFrequency, ...
    SampleRate=SampleRate, PathDelays=0, ...
    AveragePathGains=0, MaximumDopplerShift=0);

rxRF = RRFSimulator(StartTime=0, TimeDuration=2, SampleRate=SampleRate, ...
    NumReceiveAntennas=1, CenterFrequency=200e3, Bandwidth=20e3, ...
    MasterClockRate=MasterClockRate, ...
    MemoryLessNonlinearityConfig=MemoryLessNonlinearityConfig, ...
    ThermalNoiseConfig=ThermalNoiseConfig, ...
    PhaseNoiseConfig=PhaseNoiseConfig, ... 
    AGCConfig=AGCConfig, ...
    IqImbalanceConfig=IqImbalanceConfig);

source = Audio(SampleRate = SampleRate, TimeDuration = TimeDuration);
x = source();

%% Test DSBAM
ModulatorConfig.carramp = 1;
ModulatorConfig.initPhase = 0;
baseBandSignal = DSBAM(ModulatorConfig = ModulatorConfig, NumTransmitAntennnas = NumTransmitAntennnas);
x1= baseBandSignal(x);
x1 = txRF(x1);
x1 = rayChannel(x1);

%% Test DSSCBAM
ModulatorConfig.initPhase = 0;
baseBandSignal = DSBSCAM(ModulatorConfig = ModulatorConfig, NumTransmitAntennnas = NumTransmitAntennnas);
x2 = baseBandSignal(x);
txRF.StartTime = 0.4;
x2 = txRF(x2);
x2 = ricChannel(x2);

%% Test SSBAM
ModulatorConfig.fa = 3000;
ModulatorConfig.mode = 'upper';
ModulatorConfig.initPhase = 0;
baseBandSignal = SSBAM(ModulatorConfig = ModulatorConfig, NumTransmitAntennnas = NumTransmitAntennnas);

x3 = baseBandSignal(x);
txRF.StartTime = 0.6;

% demod SSB and verify
% upConv = dsp.DigitalUpConverter(... 
%  'InterpolationFactor', 5,...
%  'SampleRate', x3.SampleRate,...
%  'Bandwidth', x3.BandWidth,...
%  'StopbandAttenuation', 55,...
%  'PassbandRipple',0.2,...
%  'CenterFrequency',40e3);
% 
% dwnConv = dsp.DigitalDownConverter(...
%   'DecimationFactor',5,...
%   'SampleRate', x3.SampleRate*5,...
%   'Bandwidth', x3.BandWidth,...
%   'StopbandAttenuation', 55,...
%   'PassbandRipple',0.2,...
%   'CenterFrequency',10e3);
% 
% a = x3.data;
% b = upConv(a);
% scope1 = spectrumAnalyzer(SampleRate=x3.SampleRate*5,AveragingMethod="exponential",RBWSource="auto",SpectrumUnits="dBW");
% scope1(b);
% 
% c = dwnConv(b);
% d = ssbdemod(real(c)+imag(c), 50e3, x3.SampleRate, 0);
% e = ssbdemod(real(c)-imag(c), 50e3, x3.SampleRate, 0);
% scope2 = spectrumAnalyzer(SampleRate=x3.SampleRate,AveragingMethod="exponential",RBWSource="auto",SpectrumUnits="dBW");
% scope2(c);
% 
% scope1 = spectrumAnalyzer(SampleRate=x3.SampleRate,AveragingMethod="exponential",RBWSource="auto",SpectrumUnits="dBW");
% scope1(x3.data)

x3 = txRF(x3);
x3 = ricChannel(x3);

%% Test VSBAM
ModulatorConfig.fa = 3000;
ModulatorConfig.mode = 'upper';
ModulatorConfig.initPhase = 0;
baseBandSignal = VSBAM(ModulatorConfig = ModulatorConfig, NumTransmitAntennnas = NumTransmitAntennnas);
x4 = baseBandSignal(x);
txRF.StartTime = 1;
x4 = txRF(x4);
x4 = ricChannel(x4);
% scope = spectrumAnalyzer(SampleRate=x4.SampleRate,AveragingMethod="exponential",RBWSource="auto",SpectrumUnits="dBW");
% scope(x4.data);

% demod VSB and verify
% upConv = dsp.DigitalUpConverter(... 
%  'InterpolationFactor', 5,...
%  'SampleRate', x4.SampleRate,...
%  'Bandwidth', x4.BandWidth,...
%  'StopbandAttenuation', 55,...
%  'PassbandRipple',0.2,...
%  'CenterFrequency',40e3);
% 
% dwnConv = dsp.DigitalDownConverter(...
%   'DecimationFactor',5,...
%   'SampleRate', x4.SampleRate*5,...
%   'Bandwidth', x4.BandWidth,...
%   'StopbandAttenuation', 55,...
%   'PassbandRipple',0.2,...
%   'CenterFrequency',40e3);
% 
% a = x4.data;
% b = upConv(a);
% scope1 = spectrumAnalyzer(SampleRate=x4.SampleRate*5,AveragingMethod="exponential",RBWSource="auto",SpectrumUnits="dBW");
% scope1(b);
% 
% c = dwnConv(b);
% d = lowpass(c, x4.BandWidth/2, x4.SampleRate, ...
%                 ImpulseResponse = "fir", ...
%                 Steepness = 0.99999, StopbandAttenuation=200);
% d = real(d);
% scope2 = spectrumAnalyzer(SampleRate=x3.SampleRate,AveragingMethod="exponential",RBWSource="auto",SpectrumUnits="dBW");
% scope2(c);
% 
% 


%% 
y = rxRF({x1, x2, x3, x4});