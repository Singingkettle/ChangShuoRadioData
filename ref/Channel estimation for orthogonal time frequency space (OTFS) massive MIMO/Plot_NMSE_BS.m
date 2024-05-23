clc;clear;
loop_num =100;
SNR=5;
NumBSelement_table=[1,8:8:64];
eta = 1/2;
NMSE_Impulse_table = zeros(loop_num,length(SNR));
NMSE_Bernoul_OMP_table = zeros(loop_num,length(SNR));
NMSE_Bernoul_StrucOMP_table = zeros(loop_num,length(SNR));
for i_loop = 1:1:loop_num
    i_loop
    for i_BS=1:1:length(NumBSelement_table)
        i_BS
[NMSE_Impulse_table(i_loop,i_BS),NMSE_Bernoul_OMP_table(i_loop,i_BS),NMSE_Bernoul_StrucOMP_table(i_loop,i_BS)] = LTE_OTFS_RS_Simulator_MISO(SNR,eta,NumBSelement_table(i_BS));
    end
end
NMSE_Impulse = mean(NMSE_Impulse_table);
NMSE_Bernoul_OMP = mean(NMSE_Bernoul_OMP_table);
NMSE_Bernoul_StrucOMP = mean(NMSE_Bernoul_StrucOMP_table);
save Plot_NMSE_BS;

%%plot
figure;
semilogy(NumBSelement_table,NMSE_Impulse,'ks-','LineWidth',1.5);
hold on;
semilogy(NumBSelement_table,NMSE_Bernoul_OMP,'rd-','LineWidth',1.5);
hold on;
semilogy(NumBSelement_table,NMSE_Bernoul_StrucOMP,'mo-','LineWidth',1.5);
hold on;
legend('Traditional impulse based technique','Traditional OMP based technique','Proposed 3D-SOMP based technique');
axis([1 64  10^(-2) 10^(1)]);
grid on;
xlabel('Number of BS antennas (N_t)');
ylabel('NMSE');

