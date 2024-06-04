pnoise = comm.PhaseNoise('Level',-50,'FrequencyOffset',20);
M = 16; % From 16-QAM
data = randi([0 M-1],100,1);
modData = qammod(data,M);
tic
y = pnoise(modData);
toc
tic
y = pnoise(modData(1:100));
toc

save myFile pnoise

load myFile a

tic
y = a(modData(1:100));
toc