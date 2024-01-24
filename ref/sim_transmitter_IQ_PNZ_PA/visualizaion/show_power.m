function SignalMeanPower = show_power(dataname, data)
    SignalMeanPower = mean(abs(data).^2);
    fprintf([dataname, ' signal power is = %.3f\n'],SignalMeanPower);
end