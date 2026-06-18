function sourceType = messageSourceForModulation(family)
    % messageSourceForModulation - Deterministic message source for a family.
    %
    %   sourceType = csrd.support.modulation.messageSourceForModulation(family)
    %
    %   Resolves the message-source type that an emitter must use for the given
    %   modulation FAMILY. The message source is a deterministic function of the
    %   modulation family, never a random choice:
    %
    %     * analog families (FM/PM/AM variants) -> 'Audio'
    %       (analog modulators integrate/scale a continuous baseband; feeding
    %        them a 0/1 bit stream produces a physically meaningless waveform)
    %     * digital families (PSK/QAM/FSK/...)  -> 'RandomBit'
    %
    %   The returned names match the registered message types in
    %   config/_base_/factories/message_factory.m.
    %
    %   Inputs:
    %     family - modulation family name (char/string).
    %
    %   Outputs:
    %     sourceType - 'Audio' or 'RandomBit'.

    if csrd.support.modulation.isAnalogModulationFamily(family)
        sourceType = 'Audio';
    else
        sourceType = 'RandomBit';
    end
end
