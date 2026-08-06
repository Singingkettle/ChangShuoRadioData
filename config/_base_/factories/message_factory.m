function config = message_factory()
    % message_factory - Message factory configuration
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    % DESIGN PRINCIPLE:
    %   - Scenario config: Selects message TYPE (e.g., 'RandomBit', 'Audio')
    %   - This config: Defines DETAILS for each type (length, preamble, etc.)
    %
    % Structure:
    %   config.Factories.Message
    %   ├── Parameters              % Common parameter ranges
    %   │   └── Length              % Message length range
    %   ├── MessageTypes            % Type-specific configurations
    %   │   ├── RandomBit          % Digital modulation - random bit source
    %   │   └── Audio              % Analog modulation - audio file source
    %   └── Description

    %% ========== MESSAGE SOURCE TYPES ==========
    % NOTE: MessageLength is CALCULATED based on symbol rate and transmission
    % duration (bounds default in code; override via
    % Factories.Scenario.CommunicationBehavior.Message.Length).

    % RandomBit configuration (for digital modulation)
    % Note: RandomBit class properties: BitProbability, Seed, OutputOrientation, EnableStatistics
    config.Factories.Message.MessageTypes.RandomBit.handle = 'csrd.blocks.physical.message.RandomBit';
    config.Factories.Message.MessageTypes.RandomBit.Config.BitProbability = 0.5;

    % Audio configuration (for analog modulation like FM, AM)
    % Note: AudioFile defaults to the built-in audio file if not specified
    config.Factories.Message.MessageTypes.Audio.handle = 'csrd.blocks.physical.message.Audio';
    % Don't pass AudioFile - let Audio class use its default
end
