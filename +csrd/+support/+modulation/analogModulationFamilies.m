function families = analogModulationFamilies()
    % analogModulationFamilies - Canonical list of analog modulation families.
    %
    %   families = csrd.support.modulation.analogModulationFamilies()
    %
    %   Returns the upper-case analog modulation family names. This list is the
    %   single source of truth for the analog/digital split and mirrors the
    %   `analog.*` registry in config/_base_/factories/modulation_factory.m
    %   (FM, PM, and the AM variants). Any family not in this list is digital.
    %
    %   Outputs:
    %     families - 1xN cell array of upper-case char family names.

    families = {'FM', 'PM', 'AM', 'SSBAM', 'DSBAM', 'DSBSCAM', 'VSBAM'};
end
