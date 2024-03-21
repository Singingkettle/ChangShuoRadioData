%
fprintf("====================================================================\n")
data = randi([0 1], 8,1);
mod1 = @(x)fskmod(x, 2, 2, 8, 32);
mod2 = comm.CPFSKModulator(BitInput=true, ModulationOrder=2);

y1 = mod1(data);
y2 = mod2(data);
sum(abs(y1-y2))

%
fprintf("====================================================================\n")
data = randi([0 1], 8,1);
mod1 = comm.CPMModulator(BitInput=true, FrequencyPulse="Rectangular");
mod2 = comm.CPFSKModulator(BitInput=true);

y1 = mod1(data);
y2 = mod2(data);
sum(abs(y1-y2))


fprintf("\n\n====================================================================\n")
% 
data = randi([0 1], 8,1);
mod1 = comm.CPMModulator(FrequencyPulse="Gaussian", ModulationOrder=2, ModulationIndex=0.5, BitInput=true, PulseLength=4);
mod2 = comm.GMSKModulator(BitInput=true);

y1 = mod1(data);
y2 = mod2(data);
sum(abs(y1-y2))


fprintf("\n\n====================================================================\n")
data = randi([0 1], 8,1);
mod1 = comm.CPMModulator(FrequencyPulse="Rectangular", ModulationOrder=2, ModulationIndex=0.5, BitInput=true, PulseLength=1);
mod2 = comm.MSKModulator(BitInput=true);

y1 = mod1(data);
y2 = mod2(data);
sum(abs(y1-y2))