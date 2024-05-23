clc;clear;
loop_num = 100;
SNR_table=0:5:20;
eta = 0.5;
NumBSelement=32; 
NMSE_Impulse_table = zeros(loop_num,length(SNR_table));
NMSE_Bernoul_OMP_table = zeros(loop_num,length(SNR_table));
NMSE_Bernoul_StrucOMP_table = zeros(loop_num,length(SNR_table));
for i_loop = 1:1:loop_num
    i_loop
    for i_SNR=1:1:length(SNR_table)
        i_SNR
[NMSE_Impulse_table(i_loop,i_SNR),NMSE_Bernoul_OMP_table(i_loop,i_SNR),NMSE_Bernoul_StrucOMP_table(i_loop,i_SNR)] = LTE_OTFS_RS_Simulator_MISO(SNR_table(i_SNR),eta,NumBSelement);
    end
end
NMSE_Impulse = mean(NMSE_Impulse_table);
NMSE_Bernoul_OMP = mean(NMSE_Bernoul_OMP_table);
NMSE_Bernoul_StrucOMP = mean(NMSE_Bernoul_StrucOMP_table);
save Plot_NMSE_SNR;
%%plot
figure;
semilogy(SNR_table,NMSE_Impulse,'ks-','LineWidth',1.5);
hold on;
semilogy(SNR_table,NMSE_Bernoul_OMP,'rd-','LineWidth',1.5);
hold on;
semilogy(SNR_table,NMSE_Bernoul_StrucOMP,'mo-','LineWidth',1.5);
hold on;
legend('Traditional impulse based technique','Traditional OMP based technique','Proposed 3D-SOMP based technique');
% axis([0 20  10^(-3) 10^(1)]);
grid on;
xlabel('SNR (dB)');
ylabel('NMSE');

