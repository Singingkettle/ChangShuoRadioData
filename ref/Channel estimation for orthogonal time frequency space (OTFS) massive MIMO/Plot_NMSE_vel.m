clc;clear;
loop_num = 1000;
vel_min=10;
vel_max=160;
vel_table=[vel_min:30:vel_max];
SNR=5;
eta=0.5;
NumBSelement=1;
NMSE_Impulse_table = zeros(loop_num,length(vel_table));
NMSE_Bernoul_OMP_table = zeros(loop_num,length(vel_table));
NMSE_Bernoul_StrucOMP_table = zeros(loop_num,length(vel_table));
for i_loop = 1:1:loop_num
    i_loop
    for i_vel=1:1:length(vel_table)
        i_vel
[NMSE_Impulse_table(i_loop,i_vel),NMSE_Bernoul_OMP_table(i_loop,i_vel),NMSE_Bernoul_StrucOMP_table(i_loop,i_vel)] = LTE_OTFS_RS_Simulator_MISO1(SNR,eta,NumBSelement,vel_table(i_vel));
    end
end
NMSE_Impulse = mean(NMSE_Impulse_table);
NMSE_Bernoul_OMP = mean(NMSE_Bernoul_OMP_table);
NMSE_Bernoul_StrucOMP = mean(NMSE_Bernoul_StrucOMP_table);
save Plot_NMSE_vel;

%%plot
figure;
semilogy(vel_table,NMSE_Impulse,'ks-','LineWidth',1.5);
hold on;
semilogy(vel_table,NMSE_Bernoul_OMP,'rd-','LineWidth',1.5);
hold on;
semilogy(vel_table,NMSE_Bernoul_StrucOMP,'mo-','LineWidth',1.5);
hold on;
legend('Traditional impulse based technique','Traditional OMP based technique','Proposed 3D-SOMP based technique');
axis([vel_min vel_max 10^(-2)  10^(0) ]);
grid on;
xlabel('User velocity (m/s)');
ylabel('NMSE');

