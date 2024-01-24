function plot_time_domain(inDataPA, outDataPA)
    % 绘制功放前后信号时域图
%     fig = 0;
%     fig = fig + 1;
%     figure(fig)
    figure;
    grid on
    plot(1:length(inDataPA),inDataPA, 'DisplayName', 'TxPA');
    if nargin==2
        hold on;
        plot(1:length(outDataPA),outDataPA, 'DisplayName', 'RxPA');
    end
    legend;
    xlabel('Sample (s)')
    ylabel('Voltage (V)')
    title('Absolute Values of Input and Output Voltage Signals')
%     xlim([0 1e5])
end