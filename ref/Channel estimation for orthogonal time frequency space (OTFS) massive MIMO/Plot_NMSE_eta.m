clc;clear;
loop_num =100;
eta_min=0.2;
eta_max=0.6;
eta_table=eta_min:0.05:eta_max;
SNR=5;
NumBSelement=16;
NMSE_Impulse_table = zeros(loop_num,length(eta_table));
NMSE_Bernoul_OMP_table = zeros(loop_num,length(eta_table));
NMSE_Bernoul_StrucOMP_table = zeros(loop_num,length(eta_table));
for i_loop = 1:1:loop_num
    i_loop
    for i_eta=1:1:length(eta_table)
        i_eta
[NMSE_Impulse_table(i_loop,i_eta),NMSE_Bernoul_OMP_table(i_loop,i_eta),NMSE_Bernoul_StrucOMP_table(i_loop,i_eta)] = LTE_OTFS_RS_Simulator_MISO(SNR,eta_table(i_eta),NumBSelement);
    end
end
NMSE_Impulse = mean(NMSE_Impulse_table);
NMSE_Bernoul_OMP = mean(NMSE_Bernoul_OMP_table);
NMSE_Bernoul_StrucOMP = mean(NMSE_Bernoul_StrucOMP_table);
save Plot_NMSE_eta;
%%plot
figure;
semilogy(eta_table,NMSE_Impulse,'ks-','LineWidth',1.5);
hold on;
semilogy(eta_table,NMSE_Bernoul_OMP,'rd-','LineWidth',1.5);
hold on;
semilogy(eta_table,NMSE_Bernoul_StrucOMP,'mo-','LineWidth',1.5);
hold on;
legend('Traditional impulse based technique','Traditional OMP based technique','Proposed 3D-SOMP based technique');
axis([eta_min eta_max 10^(-2)  10^(0) ]);
grid on;
xlabel('Pilot overhead ratio (\eta)');
ylabel('NMSE');

