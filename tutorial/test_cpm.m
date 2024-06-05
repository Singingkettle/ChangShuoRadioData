%
fprintf("====================================================================\n")
data = randi([0 1], 8, 1);
mod1 = @(x)fskmod(x, 2, 2, 16, 64);
mod2 = comm.CPFSKModulation(BitInput = true, ModulationOrder = 2, SamplesPerSymbol=16);

y1 = mod1(data);
y2 = mod2(data);
sum(abs(y1 - y2))

%
fprintf("====================================================================\n")
data = randi([0 1], 8, 1);
mod1 = comm.CPMModulation(BitInput = true, FrequencyPulse = "Rectangular");
mod2 = comm.CPFSKModulation(BitInput = true);

y1 = mod1(data);
y2 = mod2(data);
sum(abs(y1 - y2))

fprintf("\n\n====================================================================\n")
%
data = randi([0 1], 8, 1);
mod1 = comm.CPMModulation(FrequencyPulse = "Gaussian", ModulationOrder = 2, ModulationIndex = 0.5, BitInput = true, PulseLength = 4);
mod2 = comm.GMSKModulation(BitInput = true);

y1 = mod1(data);
y2 = mod2(data);
sum(abs(y1 - y2))

fprintf("\n\n====================================================================\n")
data = randi([0 1], 8, 1);
mod1 = comm.CPMModulation(FrequencyPulse = "Rectangular", ModulationOrder = 2, ModulationIndex = 0.5, BitInput = true, PulseLength = 1);
mod2 = comm.MSKModulation(BitInput = true);

y1 = mod1(data);
y2 = mod2(data);
sum(abs(y1 - y2))
