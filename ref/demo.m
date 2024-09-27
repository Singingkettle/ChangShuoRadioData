clear all;                                  %Clear all variables
close all;                                  %Close all figures

l=1e6;                                      %Number of bits or symbols
EbNodB=0:2:10;                              %Range of EbNo in dB

ricianchan1 = comm.RicianChannel('SampleRate',10^6, ...
    'MaximumDopplerShift',80, ...
    'RandomStream','mt19937ar with seed', ...
    'Seed',17, ...
    'FadingTechnique','Sum of sinusoids');

ricianchan1.InitialTimeSource = 'Input port';

for n=1:length(EbNodB)
    s=2*(round(rand(1,l))-0.5);             %Random symbol generation
    s=s';
    w=(1/sqrt(2*10^(EbNodB(n)/10)))*randn(1,l);  %Random noise generation
    m = ricianchan1(s, 0.5+n);
    r=m+w;                                  %Received signal
    s_est=sign(r);                          %Demodulation
    BER(n)=(l-sum(s==s_est))/l;             %BER calculation
end

semilogy(EbNodB, BER,'o-');                 %Plot 
xlabel('EbNo(dB)')                          %Label for x-axis    
ylabel('BER')                               %Label for y-axis
grid on