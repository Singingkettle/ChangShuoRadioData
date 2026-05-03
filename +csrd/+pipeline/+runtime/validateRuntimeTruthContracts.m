function contract = validateRuntimeTruthContracts(factoryConfigs, runnerConfig)
%VALIDATERUNTIMETRUTHCONTRACTS Validate global runtime truth authorities.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：集中校验运行真值合同，禁止下游 block 反向补运行事实。
%
% This validator is intentionally narrow: it checks the cross-module facts
% that can make signal, scene state, and annotation disagree when silently
% defaulted downstream.

if nargin < 2 || isempty(runnerConfig)
    runnerConfig = struct();
end
if nargin < 1 || isempty(factoryConfigs) || ~isstruct(factoryConfigs)
    error('CSRD:RuntimeTruth:MissingFactoryConfigs', ...
        'FactoryConfigs must be a nonempty struct.');
end
if ~isfield(factoryConfigs, 'Scenario') || ~isstruct(factoryConfigs.Scenario)
    error('CSRD:RuntimeTruth:MissingScenarioConfig', ...
        'FactoryConfigs.Scenario is required.');
end

frame = csrd.pipeline.runtime.resolveFrameRuntimeContract( ...
    factoryConfigs, runnerConfig);
scenario = factoryConfigs.Scenario;

receiver = localRequireStructPath(scenario, ...
    {'CommunicationBehavior', 'Receiver'}, ...
    'FactoryConfigs.Scenario.CommunicationBehavior.Receiver');
sampleRateHz = localRequirePositiveScalar(receiver, 'SampleRate', ...
    'FactoryConfigs.Scenario.CommunicationBehavior.Receiver.SampleRate');
localAssertClose(sampleRateHz, frame.SampleRateHz, ...
    'CSRD:RuntimeTruth:SampleRateFrameMismatch', ...
    ['Receiver.SampleRate=%g but frame contract SampleRateHz=%g. ', ...
     'Receiver sample rate is the frame-time authority.']);

realCarrierHz = localRequirePositiveScalar(receiver, 'RealCarrierFrequency', ...
    'FactoryConfigs.Scenario.CommunicationBehavior.Receiver.RealCarrierFrequency');
centerFrequencyHz = localRequireFiniteScalar(receiver, 'CenterFrequency', ...
    'FactoryConfigs.Scenario.CommunicationBehavior.Receiver.CenterFrequency');
numRxAntennas = localRequirePositiveInteger(receiver, 'NumAntennas', ...
    'FactoryConfigs.Scenario.CommunicationBehavior.Receiver.NumAntennas');

observableRange = [];
if isfield(receiver, 'ObservableRange') && ~isempty(receiver.ObservableRange)
    observableRange = localRequireIncreasingRange(receiver.ObservableRange, ...
        'FactoryConfigs.Scenario.CommunicationBehavior.Receiver.ObservableRange');
    observableBandwidthHz = observableRange(2) - observableRange(1);
    localAssertClose(observableBandwidthHz, sampleRateHz, ...
        'CSRD:RuntimeTruth:ObservableRangeSampleRateMismatch', ...
        ['Receiver.ObservableRange width=%g but Receiver.SampleRate=%g. ', ...
         'The receiver observation window must describe the same sampled bandwidth.']);
end

contract = struct();
contract.Frame = frame;
contract.Receiver = struct( ...
    'SampleRateHz', sampleRateHz, ...
    'CenterFrequencyHz', centerFrequencyHz, ...
    'RealCarrierFrequencyHz', realCarrierHz, ...
    'ObservableRangeHz', observableRange, ...
    'NumAntennas', numRxAntennas);

if isfield(factoryConfigs, 'Channel') && isstruct(factoryConfigs.Channel)
    contract.Channel = localValidateChannelContract(factoryConfigs.Channel, realCarrierHz);
else
    error('CSRD:RuntimeTruth:MissingChannelConfig', ...
        'FactoryConfigs.Channel is required.');
end

if isfield(factoryConfigs, 'Transmit') && isstruct(factoryConfigs.Transmit)
    contract.Transmit = localValidateTransmitContract(factoryConfigs.Transmit);
else
    error('CSRD:RuntimeTruth:MissingTransmitConfig', ...
        'FactoryConfigs.Transmit is required.');
end

if isfield(factoryConfigs, 'Modulation') && isstruct(factoryConfigs.Modulation)
    contract.Modulation = localValidateRegistryContract( ...
        factoryConfigs.Modulation, 'Modulation');
else
    error('CSRD:RuntimeTruth:MissingModulationConfig', ...
        'FactoryConfigs.Modulation is required.');
end

if isfield(factoryConfigs, 'Receive') && isstruct(factoryConfigs.Receive)
    contract.Receive = localValidateRegistryContract( ...
        factoryConfigs.Receive, 'Receive');
else
    error('CSRD:RuntimeTruth:MissingReceiveConfig', ...
        'FactoryConfigs.Receive is required.');
end

if isfield(factoryConfigs, 'Message') && isstruct(factoryConfigs.Message)
    contract.Message = localValidateRegistryContract( ...
        factoryConfigs.Message, 'Message');
else
    error('CSRD:RuntimeTruth:MissingMessageConfig', ...
        'FactoryConfigs.Message is required.');
end
end

function channelContract = localValidateChannelContract(channelConfig, receiverCarrierHz)
    % localValidateChannelContract - Production declaration in CSRD.
    % 中文说明：localValidateChannelContract 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
channelContract = struct();
if isfield(channelConfig, 'LinkBudget') && isstruct(channelConfig.LinkBudget)
    linkBudget = channelConfig.LinkBudget;
    if isfield(linkBudget, 'CarrierFrequency') && ~isempty(linkBudget.CarrierFrequency)
        error('CSRD:RuntimeTruth:DeprecatedCarrierFrequencyAuthority', ...
            ['FactoryConfigs.Channel.LinkBudget.CarrierFrequency is forbidden. ', ...
             'Carrier frequency authority is receiver RealCarrierFrequency / rxInfo.RealCarrierFrequency.']);
    end
    carrierHz = receiverCarrierHz;
    if isfield(linkBudget, 'NoiseBandwidth') && ~isempty(linkBudget.NoiseBandwidth)
        noiseBandwidthHz = localRequirePositiveScalar(linkBudget, 'NoiseBandwidth', ...
            'FactoryConfigs.Channel.LinkBudget.NoiseBandwidth');
    else
        noiseBandwidthHz = [];
    end
    channelContract.LinkBudget = struct( ...
        'CarrierFrequencyHz', carrierHz, ...
        'NoiseBandwidthHz', noiseBandwidthHz);
end
if isfield(channelConfig, 'DefaultModels') && isstruct(channelConfig.DefaultModels)
    channelContract.DefaultModels = channelConfig.DefaultModels;
else
    error('CSRD:RuntimeTruth:MissingChannelDefaultModels', ...
        'FactoryConfigs.Channel.DefaultModels is required; channel model selection cannot fall back implicitly.');
end
end

function txContract = localValidateTransmitContract(transmitConfig)
    % localValidateTransmitContract - Production declaration in CSRD.
    % 中文说明：localValidateTransmitContract 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
txContract = struct();
if isfield(transmitConfig, 'Power') && isstruct(transmitConfig.Power)
    powerCfg = transmitConfig.Power;
    minPower = localRequireFiniteScalar(powerCfg, 'Min', ...
        'FactoryConfigs.Transmit.Power.Min');
    maxPower = localRequireFiniteScalar(powerCfg, 'Max', ...
        'FactoryConfigs.Transmit.Power.Max');
    if maxPower < minPower
        error('CSRD:RuntimeTruth:InvalidTransmitPowerRange', ...
            'FactoryConfigs.Transmit.Power.Max must be >= Power.Min.');
    end
    txContract.PowerRange = [minPower, maxPower];
end
end

function registryContract = localValidateRegistryContract(factoryConfig, label)
    % localValidateRegistryContract - Production declaration in CSRD.
    % 中文说明：localValidateRegistryContract 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
registryContract = struct();
types = {};
if strcmp(label, 'Message') && isfield(factoryConfig, 'MessageTypes') && ...
        isstruct(factoryConfig.MessageTypes)
    types = localValidateNamedHandleStruct(factoryConfig.MessageTypes, ...
        'FactoryConfigs.Message.MessageTypes');
elseif strcmp(label, 'Modulation')
    if isfield(factoryConfig, 'digital') && isstruct(factoryConfig.digital)
        types = [types; localValidateNamedHandleStruct(factoryConfig.digital, ...
            'FactoryConfigs.Modulation.digital')]; %#ok<AGROW>
    end
    if isfield(factoryConfig, 'analog') && isstruct(factoryConfig.analog)
        types = [types; localValidateNamedHandleStruct(factoryConfig.analog, ...
            'FactoryConfigs.Modulation.analog')]; %#ok<AGROW>
    end
elseif isfield(factoryConfig, 'Types') && iscell(factoryConfig.Types)
    types = factoryConfig.Types(:);
    for k = 1:numel(types)
        typeName = char(string(types{k}));
        if ~isfield(factoryConfig, typeName) || ~isstruct(factoryConfig.(typeName)) || ...
                ~localHasHandle(factoryConfig.(typeName))
            error('CSRD:RuntimeTruth:MissingFactoryHandle', ...
                'FactoryConfigs.%s.%s.handle is required.', label, typeName);
        end
    end
elseif isfield(factoryConfig, 'Types') && isstruct(factoryConfig.Types)
    types = localValidateNamedHandleStruct(factoryConfig.Types, ...
        sprintf('FactoryConfigs.%s.Types', label));
end
if isempty(types)
    error('CSRD:RuntimeTruth:MissingFactoryTypes', ...
        'FactoryConfigs.%s must contain at least one explicit typed handle.', label);
end
registryContract.TypeIds = types(:).';
end

function types = localValidateNamedHandleStruct(typeStruct, label)
    % localValidateNamedHandleStruct - Production declaration in CSRD.
    % 中文说明：localValidateNamedHandleStruct 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
types = fieldnames(typeStruct);
for k = 1:numel(types)
    typeConfig = typeStruct.(types{k});
    if ~isstruct(typeConfig) || ~localHasHandle(typeConfig)
        error('CSRD:RuntimeTruth:MissingFactoryHandle', ...
            '%s.%s.handle is required.', label, types{k});
    end
end
end

function tf = localHasHandle(typeConfig)
    % localHasHandle - Production declaration in CSRD.
    % 中文说明：localHasHandle 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
tf = (isfield(typeConfig, 'handle') && ~isempty(typeConfig.handle)) || ...
    (isfield(typeConfig, 'Handle') && ~isempty(typeConfig.Handle));
end

function sub = localRequireStructPath(root, pathParts, label)
    % localRequireStructPath - Production declaration in CSRD.
    % 中文说明：localRequireStructPath 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
sub = root;
for k = 1:numel(pathParts)
    key = pathParts{k};
    if ~isstruct(sub) || ~isfield(sub, key) || ~isstruct(sub.(key))
        error('CSRD:RuntimeTruth:MissingStructPath', '%s is required.', label);
    end
    sub = sub.(key);
end
end

function value = localRequirePositiveInteger(root, fieldName, label)
    % localRequirePositiveInteger - Production declaration in CSRD.
    % 中文说明：localRequirePositiveInteger 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
value = localRequirePositiveScalar(root, fieldName, label);
rounded = round(value);
if abs(value - rounded) > 0
    error('CSRD:RuntimeTruth:InvalidInteger', '%s must be a positive integer.', label);
end
value = rounded;
end

function value = localRequirePositiveScalar(root, fieldName, label)
    % localRequirePositiveScalar - Production declaration in CSRD.
    % 中文说明：localRequirePositiveScalar 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
value = localRequireFiniteScalar(root, fieldName, label);
if value <= 0
    error('CSRD:RuntimeTruth:InvalidPositiveScalar', ...
        '%s must be positive.', label);
end
end

function value = localRequireFiniteScalar(root, fieldName, label)
    % localRequireFiniteScalar - Production declaration in CSRD.
    % 中文说明：localRequireFiniteScalar 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
if ~isfield(root, fieldName) || isempty(root.(fieldName)) || ...
        ~isnumeric(root.(fieldName)) || ~isscalar(root.(fieldName)) || ...
        ~isfinite(root.(fieldName))
    error('CSRD:RuntimeTruth:InvalidFiniteScalar', ...
        '%s must be a finite numeric scalar.', label);
end
value = double(root.(fieldName));
end

function range = localRequireIncreasingRange(rawRange, label)
    % localRequireIncreasingRange - Production declaration in CSRD.
    % 中文说明：localRequireIncreasingRange 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
if ~isnumeric(rawRange) || numel(rawRange) ~= 2
    error('CSRD:RuntimeTruth:InvalidRange', ...
        '%s must be a numeric 1x2 [low high] range.', label);
end
range = double(reshape(rawRange, 1, 2));
if any(~isfinite(range)) || range(2) <= range(1)
    error('CSRD:RuntimeTruth:InvalidRange', ...
        '%s must be finite and strictly increasing.', label);
end
end

function localAssertClose(actual, expected, errorId, message)
    % localAssertClose - Production declaration in CSRD.
    % 中文说明：localAssertClose 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
tolerance = max(1e-9 * max(abs([actual, expected])), 1e-6);
if abs(actual - expected) > tolerance
    error(errorId, message, actual, expected);
end
end
