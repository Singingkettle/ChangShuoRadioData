txData = randi([0 1],100,1);
dbpskmod = comm.DBPSKModulator;
y1 = dpskmod(txData, 2);
y2 = dbpskmod(txData);
c = y1-y2;
sum(abs(c))

