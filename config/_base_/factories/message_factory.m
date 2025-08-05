function config = message_factory()
    % message_factory - Message factory configuration
    %
    % Configuration for message generation components.

    config.Factories.Message.Types = {'RandomBits', 'CustomPattern'};

    % Message length ranges
    config.Factories.Message.Length.Min = 512;
    config.Factories.Message.Length.Max = 2048;

    % RandomBits configuration
    config.Factories.Message.MessageTypes.RandomBits.handle = 'csrd.blocks.physical.message.RandomBit';
    config.Factories.Message.MessageTypes.RandomBits.Config.MessageLength = 1024;
    config.Factories.Message.MessageTypes.RandomBits.Config.Preamble = [1 0 1 0 1 0 1 0];
    config.Factories.Message.MessageTypes.RandomBits.Config.Seed = 'shuffle';

    % CustomPattern configuration
    config.Factories.Message.MessageTypes.CustomPattern.handle = 'csrd.blocks.physical.message.PatternGenerator';
    config.Factories.Message.MessageTypes.CustomPattern.Config.Pattern = [1, 0, 1, 0, 1, 1, 0, 0];
    config.Factories.Message.MessageTypes.CustomPattern.Config.RepeatCount = 128;

    % Metadata
    config.Factories.Message.LogDetails = true;
    config.Factories.Message.Description = 'Message source factory configuration';
end
