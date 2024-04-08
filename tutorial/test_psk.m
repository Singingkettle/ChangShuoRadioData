clc
clear
close all

ostbc = comm.OSTBCEncoder(NumTransmitAntennas = 2);
oqpskmod = BaseOQPSK('BitInput',true, 'NumTransmitAntennas', 2);
txData = randi([0 1],100,1);
modSig = oqpskmod(txData, ostbc);