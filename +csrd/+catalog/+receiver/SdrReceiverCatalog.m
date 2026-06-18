classdef SdrReceiverCatalog
    %SDRRECEIVERCATALOG Capability profiles for popular SDR monitoring receivers.
    %
    % Spectrum-sensing realism requires the monitoring receiver to behave like
    % an actual software-defined radio rather than an idealized wideband probe.
    % Each profile captures the capability axes that constrain what a real SDR
    % can observe in one capture:
    %
    %   TuningRangeHz               - RF center the front-end can be tuned to.
    %   MaxInstantaneousBandwidthHz - largest single-capture bandwidth (IBW),
    %                                 i.e. the usable complex sample rate.
    %   AdcBits                     - converter resolution (sets dynamic range).
    %   NoiseFigureDb               - receiver noise figure (link-budget input).
    %   NumChannels                 - coherent RX channels (antenna count cap).
    %
    % Values are nominal manufacturer figures used to bound scenario sampling;
    % they are engineering references, not calibrated measurements.

    methods (Static)
        function ids = supportedModelIds()
            % supportedModelIds - CSRD MATLAB declaration.
            % Outputs: cell array of supported SDR model identifiers.
            ids = {'USRP_B210', 'USRP_N310', 'BladeRF_2', ...
                'HackRF_One', 'RTL_SDR', 'Airspy_R2', 'SDRplay_RSPdx'};
        end

        function profiles = loadAll()
            % loadAll - CSRD MATLAB declaration.
            % Outputs: struct array of all supported SDR profiles.
            ids = csrd.catalog.receiver.SdrReceiverCatalog.supportedModelIds();
            profiles = repmat(emptyProfile(), 0, 1);
            for k = 1:numel(ids)
                profiles(end + 1) = csrd.catalog.receiver.SdrReceiverCatalog.load(ids{k}); %#ok<AGROW>
            end
        end

        function profile = load(modelId)
            % load - CSRD MATLAB declaration.
            % Inputs: SDR model identifier (char/string).
            % Outputs: capability profile struct for that model.
            modelId = upper(char(string(modelId)));
            ettus = {'https://www.ettus.com/'};
            switch modelId
                case 'USRP_B210'
                    profile = profileOf('USRP_B210', 'Ettus Research', ...
                        [70e6, 6e9], 56e6, 12, 8.0, 2, ...
                        {'https://www.ettus.com/all-products/ub210-kit/'});
                case 'USRP_N310'
                    profile = profileOf('USRP_N310', 'Ettus Research', ...
                        [10e6, 6e9], 100e6, 16, 5.0, 4, ...
                        {'https://www.ettus.com/all-products/usrp-n310/'});
                case 'BLADERF_2'
                    profile = profileOf('BladeRF_2', 'Nuand', ...
                        [47e6, 6e9], 56e6, 12, 8.0, 2, ...
                        {'https://www.nuand.com/bladerf-2-0-micro/'});
                case 'HACKRF_ONE'
                    profile = profileOf('HackRF_One', 'Great Scott Gadgets', ...
                        [1e6, 6e9], 20e6, 8, 10.0, 1, ...
                        {'https://greatscottgadgets.com/hackrf/one/'});
                case 'RTL_SDR'
                    profile = profileOf('RTL_SDR', 'Realtek (RTL2832U)', ...
                        [24e6, 1.766e9], 2.4e6, 8, 6.0, 1, ...
                        {'https://www.rtl-sdr.com/about-rtl-sdr/'});
                case 'AIRSPY_R2'
                    profile = profileOf('Airspy_R2', 'Airspy', ...
                        [24e6, 1.8e9], 10e6, 12, 6.0, 1, ...
                        {'https://airspy.com/airspy-r2/'});
                case 'SDRPLAY_RSPDX'
                    profile = profileOf('SDRplay_RSPdx', 'SDRplay', ...
                        [1e3, 2e9], 10e6, 14, 6.0, 1, ...
                        {'https://www.sdrplay.com/rspdx/'});
                otherwise
                    error('CSRD:Receiver:UnsupportedSdrModel', ...
                        'Unsupported SDR model "%s". Supported: %s.', ...
                        modelId, strjoin( ...
                        csrd.catalog.receiver.SdrReceiverCatalog.supportedModelIds(), ', '));
            end
            csrd.catalog.receiver.SdrReceiverCatalog.validateProfile(profile);
        end

        function validateProfile(profile)
            % validateProfile - CSRD MATLAB declaration.
            % Inputs: SDR profile struct; throws on contract violation.
            range = profile.TuningRangeHz;
            if ~isnumeric(range) || numel(range) ~= 2 || any(~isfinite(range)) || ...
                    range(1) <= 0 || range(1) >= range(2)
                error('CSRD:Receiver:InvalidTuningRange', ...
                    'SDR %s TuningRangeHz must be [min max] positive Hz.', ...
                    profile.Model);
            end
            if ~isfinite(profile.MaxInstantaneousBandwidthHz) || ...
                    profile.MaxInstantaneousBandwidthHz <= 0
                error('CSRD:Receiver:InvalidInstantaneousBandwidth', ...
                    'SDR %s MaxInstantaneousBandwidthHz must be positive.', ...
                    profile.Model);
            end
            if profile.NumChannels < 1 || mod(profile.NumChannels, 1) ~= 0
                error('CSRD:Receiver:InvalidNumChannels', ...
                    'SDR %s NumChannels must be a positive integer.', profile.Model);
            end
        end
    end
end


function profile = profileOf(model, manufacturer, tuningRangeHz, maxIbwHz, ...
        adcBits, noiseFigureDb, numChannels, refs)
    % profileOf - Assemble one SDR capability profile struct.
    profile = emptyProfile();
    profile.Model = model;
    profile.Manufacturer = manufacturer;
    profile.TuningRangeHz = double(tuningRangeHz);
    profile.MaxInstantaneousBandwidthHz = double(maxIbwHz);
    profile.AdcBits = double(adcBits);
    profile.NoiseFigureDb = double(noiseFigureDb);
    profile.NumChannels = double(numChannels);
    profile.SourceRefs = refs;
end


function profile = emptyProfile()
    % emptyProfile - Empty SDR profile template.
    profile = struct( ...
        'Model', '', ...
        'Manufacturer', '', ...
        'TuningRangeHz', [NaN NaN], ...
        'MaxInstantaneousBandwidthHz', NaN, ...
        'AdcBits', NaN, ...
        'NoiseFigureDb', NaN, ...
        'NumChannels', NaN, ...
        'SourceRefs', {{}});
end
