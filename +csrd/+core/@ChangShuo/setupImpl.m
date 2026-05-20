function setupImpl(obj)
    % setupImpl - Initialize all factories (one-time setup)
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 setupImpl 实现。
    %
    % Each factory is instantiated with ONLY its own configuration,
    % ensuring independence between factories. The ScenarioFactory
    % receives only scenario-level parameters (time-frequency resources,
    % physical environment), not the entire FactoryConfigs.

    obj.logger.debug('ChangShuo Engine: Initializing...');

    % Validate configurations
    if isempty(obj.FactoryConfigs) || ~isstruct(obj.FactoryConfigs)
        error('ChangShuo:ConfigurationError', 'FactoryConfigs must be a valid struct.');
    end

    if ~isfield(obj.FactoryConfigs, 'Scenario')
        error('ChangShuo:ConfigurationError', 'Scenario configuration required in FactoryConfigs.');
    end

    if isempty(obj.RuntimePlan) || ~isstruct(obj.RuntimePlan)
        error('CSRD:RuntimePlan:MissingRuntimePlan', ...
            ['ChangShuo.RuntimePlan is required. ', ...
             'Configure the engine through SimulationRunner or pass RuntimePlan explicitly.']);
    end

    validateFactoryConfigs(obj);

    % Initialize Factories container
    obj.Factories = struct();

    % Factory instantiation map: each factory gets ONLY its own config
    factoryMap = {
        'Scenario',   'csrd.factories.ScenarioFactory',   obj.FactoryConfigs.Scenario;
        'Message',    'csrd.factories.MessageFactory',    obj.FactoryConfigs.Message;
        'Modulation', 'csrd.factories.ModulationFactory', obj.FactoryConfigs.Modulation;
        'Transmit',   'csrd.factories.TransmitFactory',   obj.FactoryConfigs.Transmit;
        'Channel',    'csrd.factories.ChannelFactory',    obj.FactoryConfigs.Channel;
        'Receive',    'csrd.factories.ReceiveFactory',    obj.FactoryConfigs.Receive;
    };

    for i = 1:size(factoryMap, 1)
        name = factoryMap{i, 1};
        handle = factoryMap{i, 2};
        config = factoryMap{i, 3};

        try
            if strcmp(name, 'Scenario')
                obj.Factories.(name) = feval(handle, ...
                    'Config', config, 'RuntimePlan', obj.RuntimePlan);
            else
                obj.Factories.(name) = feval(handle, 'Config', config);
            end
            obj.logger.debug('Factory [%s] initialized with own config.', name);
        catch ME
            obj.logger.error('Failed to instantiate %s factory: %s', name, ME.message);
            rethrow(ME);
        end
    end

    obj.logger.debug('ChangShuo Engine: Initialization complete.');
end
