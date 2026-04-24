function [TxInfo, didChange, finalNumAntennas, arrayType] = applyAntennaConfigFromSegments(TxInfo, signalSegmentsPerTx)
    %APPLYANTENNACONFIGFROMSEGMENTS Reconcile TxInfo antenna config with the modulator's actual output.
    %
    %   [TxInfo, didChange, finalNumAntennas, arrayType] = ...
    %       csrd.utils.core.applyAntennaConfigFromSegments(TxInfo, signalSegmentsPerTx)
    %
    %   The modulation factory may upgrade a planned SISO transmitter to
    %   a MIMO configuration (e.g. when the chosen modulator implies
    %   spatial multiplexing). The downstream channel/RF blocks must be
    %   informed by mutating ``TxInfo.NumTransmitAntennas`` and the
    %   matching ``TxInfo.SiteConfig.Antenna`` fields. MATLAB structs are
    %   value types, so the previous in-place mutation inside the @ChangShuo
    %   private method was silently dropped on return; this helper makes
    %   the contract explicit and unit-testable.
    %
    %   Inputs:
    %     TxInfo                 : transmitter info struct (must contain NumTransmitAntennas).
    %     signalSegmentsPerTx    : 1xN cell of per-segment outputs from ModulationFactory.
    %                              Only the *last* segment's NumTransmitAntennas
    %                              field is consulted (matches existing behaviour).
    %
    %   Outputs:
    %     TxInfo            : possibly updated TxInfo struct.
    %     didChange         : logical, true iff antenna count was modified.
    %     finalNumAntennas  : the resolved antenna count (=TxInfo.NumTransmitAntennas).
    %     arrayType         : the resolved array type ('Isotropic'|'ULA'|'URA').

    didChange = false;
    finalNumAntennas = TxInfo.NumTransmitAntennas;
    arrayType = 'Isotropic';
    if isfield(TxInfo, 'SiteConfig') && isstruct(TxInfo.SiteConfig) && ...
            isfield(TxInfo.SiteConfig, 'Antenna') && isstruct(TxInfo.SiteConfig.Antenna) && ...
            isfield(TxInfo.SiteConfig.Antenna, 'Array')
        arrayType = TxInfo.SiteConfig.Antenna.Array;
    end

    if isempty(signalSegmentsPerTx)
        return;
    end
    lastSegment = signalSegmentsPerTx{end};
    if isempty(lastSegment) || ~isstruct(lastSegment) || ~isfield(lastSegment, 'NumTransmitAntennas')
        return;
    end

    finalNumAntennas = lastSegment.NumTransmitAntennas;
    if TxInfo.NumTransmitAntennas == finalNumAntennas
        return;
    end

    didChange = true;
    TxInfo.NumTransmitAntennas = finalNumAntennas;

    if ~isfield(TxInfo, 'SiteConfig') || ~isstruct(TxInfo.SiteConfig)
        TxInfo.SiteConfig = struct();
    end
    if ~isfield(TxInfo.SiteConfig, 'Antenna') || ~isstruct(TxInfo.SiteConfig.Antenna)
        TxInfo.SiteConfig.Antenna = struct();
    end
    TxInfo.SiteConfig.Antenna.NumAntennas = finalNumAntennas;

    if finalNumAntennas == 1
        arrayType = 'Isotropic';
    elseif mod(finalNumAntennas, 2) == 0 && finalNumAntennas > 2
        arrayType = 'URA';
    else
        arrayType = 'ULA';
    end
    TxInfo.SiteConfig.Antenna.Array = arrayType;
end
