function provenance = extractProvenanceFromGlobalLayout(globalLayout)
    %EXTRACTPROVENANCEFROMGLOBALLAYOUT Phase 3 provenance dataflow helper.
    % 中文说明：提供 CSRD 生产链路中的 extractProvenanceFromGlobalLayout 实现。
    %
    %   Phase 3 (audit §3.5 / §17.5 P3-7) replaces the legacy
    %   `ChangShuo.getScenarioBlueprintProvenance` Hidden accessor (which
    %   poked at `Factories.Scenario.LastBlueprintHash` etc with three
    %   try/catch blocks) with a direct read off the `globalLayout` struct
    %   that ScenarioFactory.stepImpl built. The contract is:
    %
    %     - globalLayout.BlueprintHash         → BlueprintHash         (char)
    %     - globalLayout.NumBlueprintAttempts  → BlueprintResamples    (>=0)
    %     - globalLayout.ValidationReport.Provenance.ValidatorVersion
    %                                          → ValidatorVersion      (char)
    %
    %   `BlueprintResamples` is the number of *additional* attempts beyond
    %   the first (i.e. NumBlueprintAttempts - 1, clamped at zero) so it
    %   matches the historical `LastBlueprintResamples` semantics that
    %   downstream baseline scripts (test_baseline_sweep_200,
    %   BlueprintProvenanceCoverage) already pin.
    %
    %   Returns a fully-populated struct with the three Phase 2 keys even
    %   when the input is empty / missing fields, so the saver path stays
    %   schema-stable (stampRuntimeHeader can write empty strings instead
    %   of crashing or omitting the key).
    %
    %   Static / Hidden so ProvenanceDataflowTest can hit the same code
    %   path SimulationRunner uses without instantiating the whole engine.

    provenance = struct( ...
        'BlueprintHash',     '', ...
        'BlueprintResamples', 0, ...
        'ValidatorVersion',  '');

    if ~isstruct(globalLayout) || isempty(globalLayout)
        return;
    end

    if isfield(globalLayout, 'BlueprintHash') && ~isempty(globalLayout.BlueprintHash)
        provenance.BlueprintHash = char(string(globalLayout.BlueprintHash));
    end

    if isfield(globalLayout, 'NumBlueprintAttempts') ...
            && ~isempty(globalLayout.NumBlueprintAttempts) ...
            && isnumeric(globalLayout.NumBlueprintAttempts) ...
            && isscalar(globalLayout.NumBlueprintAttempts)
        provenance.BlueprintResamples = ...
            max(0, double(globalLayout.NumBlueprintAttempts) - 1);
    end

    if isfield(globalLayout, 'ValidationReport') ...
            && isstruct(globalLayout.ValidationReport) ...
            && isfield(globalLayout.ValidationReport, 'Provenance') ...
            && isstruct(globalLayout.ValidationReport.Provenance) ...
            && isfield(globalLayout.ValidationReport.Provenance, 'ValidatorVersion') ...
            && ~isempty(globalLayout.ValidationReport.Provenance.ValidatorVersion)
        provenance.ValidatorVersion = ...
            char(string(globalLayout.ValidationReport.Provenance.ValidatorVersion));
    end
end
