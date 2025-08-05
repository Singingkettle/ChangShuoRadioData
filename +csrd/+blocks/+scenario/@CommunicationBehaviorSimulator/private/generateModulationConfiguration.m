function modulationConfig = generateModulationConfiguration(obj, transmitter, factoryConfig)
    % generateModulationConfiguration - Generate modulation configuration
    modulationConfig = struct();
    modulationConfig.Type = factoryConfig.Types{randi(length(factoryConfig.Types))};

    % Set modulation order based on type
    switch modulationConfig.Type
            % Digital modulation schemes
        case 'PSK'
            orders = factoryConfig.digital.PSK.Order;
        case 'OQPSK'
            orders = factoryConfig.digital.OQPSK.Order;
        case 'QAM'
            orders = factoryConfig.digital.QAM.Order;
        case 'Mill88QAM'
            orders = factoryConfig.digital.Mill88QAM.Order;
        case 'FSK'
            orders = factoryConfig.digital.FSK.Order;
        case 'ASK'
            orders = factoryConfig.digital.ASK.Order;
        case 'OOK'
            orders = factoryConfig.digital.OOK.Order;
        case 'APSK'
            orders = factoryConfig.digital.APSK.Order;
        case 'DVBSAPSK'
            orders = factoryConfig.digital.DVBSAPSK.Order;
        case 'CPFSK'
            orders = factoryConfig.digital.CPFSK.Order;
        case 'GFSK'
            orders = factoryConfig.digital.GFSK.Order;
        case 'GMSK'
            orders = factoryConfig.digital.GMSK.Order;
        case 'MSK'
            orders = factoryConfig.digital.MSK.Order;

            % Multi-carrier modulation schemes with SubType
        case 'OFDM'

            if rand() > 0.5
                orders = factoryConfig.digital.OFDM.PSKOrder;
                modulationConfig.SubType = 'PSK';
            else
                orders = factoryConfig.digital.OFDM.QAMOrder;
                modulationConfig.SubType = 'QAM';
            end

        case 'OTFS'

            if rand() > 0.5
                orders = factoryConfig.digital.OTFS.PSKOrder;
                modulationConfig.SubType = 'PSK';
            else
                orders = factoryConfig.digital.OTFS.QAMOrder;
                modulationConfig.SubType = 'QAM';
            end

        case 'SCFDMA'

            if rand() > 0.5
                orders = factoryConfig.digital.SCFDMA.PSKOrder;
                modulationConfig.SubType = 'PSK';
            else
                orders = factoryConfig.digital.SCFDMA.QAMOrder;
                modulationConfig.SubType = 'QAM';
            end

            % Analog modulation schemes
        case {'FM', 'PM', 'SSBAM', 'DSBAM', 'DSBSCAM', 'VSBAM'}
            orders = factoryConfig.analog.(modulationConfig.Type).Order;

        otherwise
            orders = [2, 4, 8]; % Default orders for unknown types
    end

    % Select order from available orders
    if length(orders) == 1
        modulationConfig.Order = orders;
    else
        modulationConfig.Order = orders(randi(length(orders)));
    end

    % Set symbol rate and sampling parameters
    symbolRange = factoryConfig.SymbolRate;
    samplesRange = factoryConfig.SamplePerSymbol;

    modulationConfig.SymbolRate = randomInRange(obj, symbolRange.Min, symbolRange.Max);
    modulationConfig.SamplePerSymbol = randi([samplesRange.Min, samplesRange.Max]);
end
