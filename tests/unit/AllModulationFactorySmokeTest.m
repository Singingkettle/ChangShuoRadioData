classdef AllModulationFactorySmokeTest < matlab.unittest.TestCase
    %ALLMODULATIONFACTORYSMOKETEST Ensure every configured modulator emits.

    methods (Test)
        function allConfiguredModulatorsEmitUsableSignals(testCase)
            projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(projectRoot);

            csrd.runtime.logger.GlobalLogManager.reset();
            cleanup = onCleanup(@() csrd.runtime.logger.GlobalLogManager.reset()); %#ok<NASGU>
            csrd.runtime.logger.GlobalLogManager.initialize(struct( ...
                'Name', 'CSRD-AllModulationFactorySmoke', ...
                'Level', 'ERROR', ...
                'SaveToFile', false, ...
                'DisplayInConsole', false));

            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            modulationTypes = localConfiguredModulationTypes(cfg.Factories.Modulation);
            testCase.verifyGreaterThanOrEqual(numel(modulationTypes), 20, ...
                'Expected the configured modulation catalog to remain broad.');

            for k = 1:numel(modulationTypes)
                typeId = modulationTypes{k};
                payload = randi([0, 1], 4096, 1);
                placement = struct('TargetBandwidth', localTargetBandwidth(typeId), ...
                    'CenterFrequency', 0);
                segment = localSegmentConfig(typeId, placement.TargetBandwidth);

                factory = csrd.factories.ModulationFactory( ...
                    'Config', cfg.Factories.Modulation);
                factoryCleanup = onCleanup(@() localRelease(factory)); %#ok<NASGU>
                out = step(factory, payload, 1, 'Tx001', 1, segment, placement);

                testCase.verifyFalse(isfield(out, 'Error'), sprintf( ...
                    'Modulator %s returned Error=%s.', typeId, ...
                    localFieldOrDefault(out, 'Error', '<none>')));
                testCase.verifyTrue(isfield(out, 'Signal') && ~isempty(out.Signal), ...
                    sprintf('Modulator %s did not emit a non-empty Signal.', typeId));
                testCase.verifyTrue(isfield(out, 'SampleRate') && ...
                    isnumeric(out.SampleRate) && isscalar(out.SampleRate) && ...
                    isfinite(out.SampleRate) && out.SampleRate > 0, ...
                    sprintf('Modulator %s did not emit a positive scalar SampleRate.', typeId));
                testCase.verifyTrue(isfield(out, 'Bandwidth') && ...
                    isnumeric(out.Bandwidth) && isscalar(out.Bandwidth) && ...
                    isfinite(out.Bandwidth) && out.Bandwidth > 0, ...
                    sprintf('Modulator %s did not emit a positive scalar Bandwidth.', typeId));

                localRelease(factory);
                clear factoryCleanup;
            end
        end
    end
end

function types = localConfiguredModulationTypes(modulationConfig)
types = {};
categories = {'digital', 'analog'};
for c = 1:numel(categories)
    category = categories{c};
    if ~isfield(modulationConfig, category) || ...
            ~isstruct(modulationConfig.(category))
        continue;
    end
    names = fieldnames(modulationConfig.(category));
    for n = 1:numel(names)
        entry = modulationConfig.(category).(names{n});
        if isstruct(entry) && isfield(entry, 'handle') && ~isempty(entry.handle)
            types{end + 1} = names{n}; %#ok<AGROW>
        end
    end
end
end

function segment = localSegmentConfig(typeId, targetBandwidth)
order = localOrderForType(typeId);
rolloff = 0.25;
symbolRate = targetBandwidth / (1 + rolloff);
segment = struct( ...
    'TypeID', typeId, ...
    'Type', typeId, ...
    'Family', typeId, ...
    'Order', order, ...
    'BitsPerSymbol', max(1, log2(max(order, 2))), ...
    'RolloffFactor', rolloff, ...
    'SymbolRate', symbolRate, ...
    'SamplesPerSymbol', 4, ...
    'NumTransmitAntennas', localNumTransmitAntennas(typeId), ...
    'ModulatorConfig', localModulatorConfig(typeId, targetBandwidth));
end

function order = localOrderForType(typeId)
switch char(string(typeId))
    case {'APSK', 'DVBSAPSK', 'QAM', 'Mill88QAM', 'OFDM', 'OTFS', 'SCFDMA'}
        order = 16;
    case {'ASK', 'PSK', 'OQPSK'}
        order = 4;
    case {'CPFSK', 'GFSK', 'GMSK', 'MSK', 'FSK', 'OOK'}
        order = 2;
    otherwise
        order = 1;
end
end

function bw = localTargetBandwidth(typeId)
if any(strcmp(char(string(typeId)), {'OFDM', 'OTFS', 'SCFDMA'}))
    bw = 1.5e6;
elseif any(strcmp(char(string(typeId)), {'FM', 'PM', 'AM', 'SSBAM', ...
        'DSBAM', 'DSBSCAM', 'VSBAM'}))
    bw = 200e3;
else
    bw = 500e3;
end
end

function n = localNumTransmitAntennas(typeId)
if any(strcmp(char(string(typeId)), {'OFDM', 'OTFS', 'SCFDMA'}))
    n = 2;
else
    n = 1;
end
end

function modulatorConfig = localModulatorConfig(typeId, bandwidth)
modulatorConfig = struct();
switch char(string(typeId))
    case 'OFDM'
        fftLength = 512;
        guard = 32;
        subcarrierSpacing = max(15e3, ceil(bandwidth / ...
            max(1, fftLength - 2 * guard) / 1e3) * 1e3);
        modulatorConfig.base.mode = "qam";
        modulatorConfig.ofdm.FFTLength = fftLength;
        modulatorConfig.ofdm.NumGuardBandCarriers = [guard; guard];
        modulatorConfig.ofdm.InsertDCNull = true;
        modulatorConfig.ofdm.CyclicPrefixLength = 64;
        modulatorConfig.ofdm.Subcarrierspacing = subcarrierSpacing;
        modulatorConfig.ofdm.Windowing = false;
    case 'OTFS'
        delayLength = 512;
        subcarrierSpacing = max(15e3, ceil(bandwidth / ...
            max(1, delayLength - 8) / 1e3) * 1e3);
        modulatorConfig.base.mode = "qam";
        modulatorConfig.otfs.DelayLength = delayLength;
        modulatorConfig.otfs.Subcarrierspacing = subcarrierSpacing;
        modulatorConfig.otfs.padType = "CP";
        modulatorConfig.otfs.padLen = 16;
    case 'SCFDMA'
        dataSubcarriers = 300;
        subcarrierSpacing = max(15e3, ceil(bandwidth / dataSubcarriers / 1e3) * 1e3);
        modulatorConfig.base.mode = "qam";
        modulatorConfig.scfdma.FFTLength = 512;
        modulatorConfig.scfdma.CyclicPrefixLength = 64;
        modulatorConfig.scfdma.Subcarrierspacing = subcarrierSpacing;
        modulatorConfig.scfdma.SubcarrierMappingInterval = 1;
        modulatorConfig.scfdma.NumDataSubcarriers = dataSubcarriers;
    case 'OQPSK'
        modulatorConfig.beta = 0.25;
        modulatorConfig.span = 10;
        modulatorConfig.SymbolMapping = "Gray";
        modulatorConfig.PhaseOffset = 0;
    otherwise
        modulatorConfig.beta = 0.25;
        modulatorConfig.span = 10;
end
end

function value = localFieldOrDefault(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName)
    value = s.(fieldName);
else
    value = defaultValue;
end
end

function localRelease(factory)
if isa(factory, 'matlab.System') && isLocked(factory)
    release(factory);
end
end
