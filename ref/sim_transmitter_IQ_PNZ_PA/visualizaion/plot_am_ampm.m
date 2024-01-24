function plot_am_ampm(inDataPA, outDataPA)
    TransferPA = abs(outDataPA./inDataPA);
%     fig = fig + 1;
%     figure(fig)
%     clf(fig)
    figure;
    yyaxis left
    plot(abs(inDataPA),abs(outDataPA),'.')
    ylabel('Output Voltage Absolute Value(V)')
    yyaxis right
    plot(abs(inDataPA),20*log10(TransferPA),'.')
    % plot(abs(inDataPA).^2,abs(outDataPA).^2,'.')
    xlabel('Input Voltage Absolute Value(V)')
    ylabel('Magnitude Power Gain (dB)')
    title('AM/AM Transfer Function')% Power Gain Transfer Function

    %% AM/PMÌØÐÔ
    theta2 = atan(imag(outDataPA)./real(outDataPA));
    theta1 = atan(imag(inDataPA)./real(inDataPA));
    delta_theta = theta2 - theta1;
%     fig = fig + 1;
%     figure(fig)
%     clf(fig)
    figure;
    grid on
    grid minor
    plot(abs(inDataPA),delta_theta,'.')
    xlabel('Input Voltage Absolute Value(V)')
    ylabel('Phase Shift (rad)')
    title('AM/PM Transfer Function')
    ylim([-3*pi/2 3*pi/2])
    yticks([-3*pi/2 -pi -pi/2 0 pi/2 pi 3*pi/2])
    yticklabels({'-3\pi/2','\pi','-\pi/2','0','\pi/2','\pi','3\pi/2'})
end