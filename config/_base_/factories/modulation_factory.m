function config = modulation_factory()
    % modulation_factory - Modulation factory configuration
    %
    % DESIGN PRINCIPLE:
    %   - Scenario config: Selects modulation TYPE (e.g., 'PSK', 'QAM')
    %   - This config: Defines DETAILS for each type (orders, symbol rate, etc.)
    %
    % Structure:
    %   config.Factories.Modulation
    %   ├── Parameters              % Common parameter ranges for all types
    %   │   ├── SymbolRate          % Symbol rate range
    %   │   └── SamplesPerSymbol    % Samples per symbol range
    %   ├── digital                 % Digital modulation schemes
    %   │   ├── PSK, QAM, FSK...   % Each with handle, Order, Config
    %   ├── analog                  % Analog modulation schemes
    %   │   ├── FM, AM, PM...      % Each with handle, Config
    %   └── Description

    %% ========== COMMON PARAMETERS ==========
    % NOTE: SymbolRate is CALCULATED based on allocated bandwidth, not configured!
    %   SymbolRate ≈ Bandwidth / (1 + RolloffFactor)
    % These are constraints/limits, not selection ranges
    
    config.Factories.Modulation.Parameters.RolloffFactor = 0.25;     % For bandwidth calculation
    config.Factories.Modulation.Parameters.SamplesPerSymbol.Min = 2;
    config.Factories.Modulation.Parameters.SamplesPerSymbol.Max = 8;

    %% ========== DIGITAL MODULATION SCHEMES ==========

    % APSK (Amplitude and Phase Shift Keying)
    config.Factories.Modulation.digital.APSK.handle = 'csrd.blocks.physical.modulate.digital.APSK.APSK';
    config.Factories.Modulation.digital.APSK.Order = [16, 32, 64, 128, 256];

    config.Factories.Modulation.digital.DVBSAPSK.handle = 'csrd.blocks.physical.modulate.digital.APSK.DVBSAPSK';
    config.Factories.Modulation.digital.DVBSAPSK.Order = [16, 32, 64, 128, 256];

    % ASK (Amplitude Shift Keying)
    config.Factories.Modulation.digital.ASK.handle = 'csrd.blocks.physical.modulate.digital.ASK.ASK';
    config.Factories.Modulation.digital.ASK.Order = [4, 8, 16, 32, 64];

    % CPM (Continuous Phase Modulation)
    config.Factories.Modulation.digital.CPFSK.handle = 'csrd.blocks.physical.modulate.digital.CPM.CPFSK';
    config.Factories.Modulation.digital.CPFSK.Order = [4, 8];

    config.Factories.Modulation.digital.GFSK.handle = 'csrd.blocks.physical.modulate.digital.CPM.GFSK';
    config.Factories.Modulation.digital.GFSK.Order = [4, 8];

    config.Factories.Modulation.digital.GMSK.handle = 'csrd.blocks.physical.modulate.digital.CPM.GMSK';
    config.Factories.Modulation.digital.GMSK.Order = 2;

    config.Factories.Modulation.digital.MSK.handle = 'csrd.blocks.physical.modulate.digital.CPM.MSK';
    config.Factories.Modulation.digital.MSK.Order = 2;

    % FSK (Frequency Shift Keying)
    config.Factories.Modulation.digital.FSK.handle = 'csrd.blocks.physical.modulate.digital.FSK.FSK';
    config.Factories.Modulation.digital.FSK.Order = [2, 4, 8];
    config.Factories.Modulation.digital.FSK.Config.FrequencyDeviation = 50e3;

    % OOK (On-Off Keying)
    config.Factories.Modulation.digital.OOK.handle = 'csrd.blocks.physical.modulate.digital.OOK.OOK';
    config.Factories.Modulation.digital.OOK.Order = 2;

    % PSK (Phase Shift Keying)
    config.Factories.Modulation.digital.PSK.handle = 'csrd.blocks.physical.modulate.digital.PSK.PSK';
    config.Factories.Modulation.digital.PSK.Order = [2, 4, 8, 16, 32, 64];
    config.Factories.Modulation.digital.PSK.Config.PulseShaping = 'RRC';
    config.Factories.Modulation.digital.PSK.Config.RolloffFactor = 0.25;

    config.Factories.Modulation.digital.OQPSK.handle = 'csrd.blocks.physical.modulate.digital.PSK.OQPSK';
    config.Factories.Modulation.digital.OQPSK.Order = 4;

    % QAM (Quadrature Amplitude Modulation)
    config.Factories.Modulation.digital.QAM.handle = 'csrd.blocks.physical.modulate.digital.QAM.QAM';
    config.Factories.Modulation.digital.QAM.Order = [8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096];
    config.Factories.Modulation.digital.QAM.Config.PulseShaping = 'RRC';
    config.Factories.Modulation.digital.QAM.Config.RolloffFactor = 0.25;

    config.Factories.Modulation.digital.Mill88QAM.handle = 'csrd.blocks.physical.modulate.digital.QAM.Mill88QAM';
    config.Factories.Modulation.digital.Mill88QAM.Order = [16, 32, 64, 256];

    % Multi-carrier modulation schemes
    config.Factories.Modulation.digital.OFDM.handle = 'csrd.blocks.physical.modulate.digital.OFDM.OFDM';
    config.Factories.Modulation.digital.OFDM.PSKOrder = [2, 4, 8, 16, 32, 64];
    config.Factories.Modulation.digital.OFDM.QAMOrder = [8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096];
    config.Factories.Modulation.digital.OFDM.Config.SubcarrierSpacing = 15e3;
    config.Factories.Modulation.digital.OFDM.Config.NumSubcarriers = 64;
    config.Factories.Modulation.digital.OFDM.Config.CyclicPrefixLength = 16;
    config.Factories.Modulation.digital.OFDM.Config.PilotCarrierIndices = [7; 21; 43; 57];

    config.Factories.Modulation.digital.OTFS.handle = 'csrd.blocks.physical.modulate.digital.OTFS.OTFS';
    config.Factories.Modulation.digital.OTFS.PSKOrder = [2, 4, 8, 16, 32, 64];
    config.Factories.Modulation.digital.OTFS.QAMOrder = [8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096];

    config.Factories.Modulation.digital.SCFDMA.handle = 'csrd.blocks.physical.modulate.digital.SCFDMA.SCFDMA';
    config.Factories.Modulation.digital.SCFDMA.PSKOrder = [2, 4, 8, 16, 32, 64];
    config.Factories.Modulation.digital.SCFDMA.QAMOrder = [8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096];

    %% ========== ANALOG MODULATION SCHEMES ==========

    config.Factories.Modulation.analog.FM.handle = 'csrd.blocks.physical.modulate.analog.FM.FM';
    config.Factories.Modulation.analog.FM.Order = 1;
    config.Factories.Modulation.analog.FM.Config.FrequencyDeviation = 75e3;

    config.Factories.Modulation.analog.PM.handle = 'csrd.blocks.physical.modulate.analog.PM.PM';
    config.Factories.Modulation.analog.PM.Order = 1;

    config.Factories.Modulation.analog.SSBAM.handle = 'csrd.blocks.physical.modulate.analog.AM.SSBAM';
    config.Factories.Modulation.analog.SSBAM.Order = 1;

    config.Factories.Modulation.analog.DSBAM.handle = 'csrd.blocks.physical.modulate.analog.AM.DSBAM';
    config.Factories.Modulation.analog.DSBAM.Order = 1;

    config.Factories.Modulation.analog.DSBSCAM.handle = 'csrd.blocks.physical.modulate.analog.AM.DSBSCAM';
    config.Factories.Modulation.analog.DSBSCAM.Order = 1;

    config.Factories.Modulation.analog.VSBAM.handle = 'csrd.blocks.physical.modulate.analog.AM.VSBAM';
    config.Factories.Modulation.analog.VSBAM.Order = 1;
    
    % AM shortcut (points to DSBAM)
    config.Factories.Modulation.analog.AM.handle = 'csrd.blocks.physical.modulate.analog.AM.DSBAM';
    config.Factories.Modulation.analog.AM.Order = 1;

    %% ========== METADATA ==========
    config.Factories.Modulation.LogDetails = true;
    config.Factories.Modulation.Description = 'Modulation factory (class handles + type-specific details)';
end
