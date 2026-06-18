function tf = isAnalogModulationFamily(family)
    % isAnalogModulationFamily - Canonical analog vs digital classification.
    %
    %   tf = csrd.support.modulation.isAnalogModulationFamily(family)
    %
    %   Returns true when FAMILY names an analog modulation scheme and false
    %   when it names a digital one. This is the single source of truth for
    %   the analog/digital split across the pipeline. The analog set mirrors
    %   the `analog.*` registry in config/_base_/factories/modulation_factory.m;
    %   every other modulation family registered under `digital.*` is digital.
    %
    %   The classification drives the message-source contract: analog families
    %   are driven by a continuous (audio) source, digital families by a random
    %   bit source. See csrd.support.modulation.messageSourceForModulation.
    %
    %   Inputs:
    %     family - modulation family name (char/string), e.g. 'FM', 'PSK'.
    %
    %   Outputs:
    %     tf - logical scalar; true for analog families.

    name = upper(strtrim(char(string(family))));
    if isempty(name)
        error('CSRD:Modulation:MissingModulationFamily', ...
            ['isAnalogModulationFamily requires a non-empty modulation ', ...
             'family name; the caller must resolve the family before ', ...
             'classifying it.']);
    end

    analogFamilies = csrd.support.modulation.analogModulationFamilies();
    tf = any(strcmp(name, analogFamilies));
end
