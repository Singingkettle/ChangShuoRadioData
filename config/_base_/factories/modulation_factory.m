function config = modulation_factory()
    % modulation_factory - Modulation factory configuration
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    % DESIGN PRINCIPLE:
    %   - Scenario config: Selects modulation TYPE (e.g., 'PSK', 'QAM')
    %   - This config: Defines DETAILS for each type (orders, symbol rate, etc.)
    %
    % Structure:
    %   config.Factories.Modulation
    %   ├── digital                 % Digital modulation schemes
    %   │   ├── PSK, QAM, FSK...   % Each with handle (+ Config where consumed)
    %   └── analog                  % Analog modulation schemes
    %       ├── FM, AM, PM...      % Each with handle (+ Config where consumed)
    %
    % NOTE: Execution-time modulation order and symbol rate come from the
    % scenario plan (segment config), not from this factory config.

    %% ========== DIGITAL MODULATION SCHEMES ==========

    % APSK (Amplitude and Phase Shift Keying)
    config.Factories.Modulation.digital.APSK.handle = 'csrd.blocks.physical.modulate.digital.APSK.APSK';

    config.Factories.Modulation.digital.DVBSAPSK.handle = 'csrd.blocks.physical.modulate.digital.APSK.DVBSAPSK';

    % ASK (Amplitude Shift Keying)
    config.Factories.Modulation.digital.ASK.handle = 'csrd.blocks.physical.modulate.digital.ASK.ASK';

    % PAM (Pulse Amplitude Modulation)
    config.Factories.Modulation.digital.PAM.handle = 'csrd.blocks.physical.modulate.digital.PAM.PAM';

    % CPM (Continuous Phase Modulation)
    config.Factories.Modulation.digital.CPFSK.handle = 'csrd.blocks.physical.modulate.digital.CPM.CPFSK';

    config.Factories.Modulation.digital.GFSK.handle = 'csrd.blocks.physical.modulate.digital.CPM.GFSK';

    config.Factories.Modulation.digital.GMSK.handle = 'csrd.blocks.physical.modulate.digital.CPM.GMSK';

    config.Factories.Modulation.digital.MSK.handle = 'csrd.blocks.physical.modulate.digital.CPM.MSK';

    % FSK (Frequency Shift Keying)
    config.Factories.Modulation.digital.FSK.handle = 'csrd.blocks.physical.modulate.digital.FSK.FSK';

    % OOK (On-Off Keying)
    config.Factories.Modulation.digital.OOK.handle = 'csrd.blocks.physical.modulate.digital.OOK.OOK';

    % PSK (Phase Shift Keying)
    config.Factories.Modulation.digital.PSK.handle = 'csrd.blocks.physical.modulate.digital.PSK.PSK';
    config.Factories.Modulation.digital.PSK.Config.RolloffFactor = 0.25;

    config.Factories.Modulation.digital.OQPSK.handle = 'csrd.blocks.physical.modulate.digital.PSK.OQPSK';

    % QAM (Quadrature Amplitude Modulation)
    config.Factories.Modulation.digital.QAM.handle = 'csrd.blocks.physical.modulate.digital.QAM.QAM';
    config.Factories.Modulation.digital.QAM.Config.RolloffFactor = 0.25;

    config.Factories.Modulation.digital.Mill88QAM.handle = 'csrd.blocks.physical.modulate.digital.QAM.Mill88QAM';

    % Multi-carrier modulation schemes
    config.Factories.Modulation.digital.OFDM.handle = 'csrd.blocks.physical.modulate.digital.OFDM.OFDM';

    config.Factories.Modulation.digital.OTFS.handle = 'csrd.blocks.physical.modulate.digital.OTFS.OTFS';

    config.Factories.Modulation.digital.SCFDMA.handle = 'csrd.blocks.physical.modulate.digital.SCFDMA.SCFDMA';

    %% ========== ANALOG MODULATION SCHEMES ==========

    config.Factories.Modulation.analog.FM.handle = 'csrd.blocks.physical.modulate.analog.FM.FM';
    config.Factories.Modulation.analog.FM.Config.FrequencyDeviation = 75e3;

    config.Factories.Modulation.analog.PM.handle = 'csrd.blocks.physical.modulate.analog.PM.PM';

    config.Factories.Modulation.analog.SSBAM.handle = 'csrd.blocks.physical.modulate.analog.AM.SSBAM';

    config.Factories.Modulation.analog.DSBAM.handle = 'csrd.blocks.physical.modulate.analog.AM.DSBAM';

    config.Factories.Modulation.analog.DSBSCAM.handle = 'csrd.blocks.physical.modulate.analog.AM.DSBSCAM';

    config.Factories.Modulation.analog.VSBAM.handle = 'csrd.blocks.physical.modulate.analog.AM.VSBAM';

    % AM shortcut (points to DSBAM)
    config.Factories.Modulation.analog.AM.handle = 'csrd.blocks.physical.modulate.analog.AM.DSBAM';
end
