function maxSpeed = getMaxSpeedForEntityType(obj, entityType, varargin)
    %GETMAXSPEEDFORENTITYTYPE Phase 4 §3.8.A cohort-driven max speed.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    %   maxSpeed = getMaxSpeedForEntityType(obj, entityType)
    %   maxSpeed = getMaxSpeedForEntityType(obj, entityType, ...
    %       'CohortMaxSpeedMps', value)
    %
    %   Phase 4 (audit §3.8.A): When the per-cohort blueprint specifies
    %   a `Mobility.MaxSpeedMps` override (Phase 3 introduced the
    %   blueprint-driven mobility slice), createEntity threads that
    %   value through here as the optional Name-Value parameter
    %   `CohortMaxSpeedMps`. When provided AND > 0 it OVERRIDES the
    %   default per-entity-type cap, enabling high-speed cohorts (e.g.
    %   the `HighSpeed_Aero_Doppler` cohort with v=200 m/s) to produce
    %   the high-velocity samples the Phase 4 Doppler regression test
    %   needs.
    %
    %   When `CohortMaxSpeedMps` is empty / 0 / absent, we fall back to
    %   the historical per-entity-type defaults (Tx 10 m/s vehicular,
    %   Rx 2 m/s pedestrian, other 5 m/s). The 0 case is treated as
    %   "use default" rather than "stationary" because callers express
    %   stationary by setting `Mobility.Model='Stationary'` upstream;
    %   forcing 0 here would silently mask configuration errors.
    %
    %   Inputs:
    %     obj         - PhysicalEnvironmentSimulator instance (unused
    %                   today; kept on the signature so the method stays
    %                   instance-bound for future per-environment
    %                   overrides like terrain-dependent caps).
    %     entityType  - 'Transmitter', 'Receiver', or any other type tag.
    %
    %   Optional Name-Value:
    %     'CohortMaxSpeedMps' (numeric scalar, default []) - Cohort
    %         override; when provided AND > 0, returned verbatim.
    %
    %   Output:
    %     maxSpeed - Per-component velocity cap in m/s (used by
    %         createEntity when sampling the initial 3-D velocity
    %         vector). The returned value is the per-axis cap; the
    %         resulting vector magnitude can therefore reach
    %         sqrt(3)*maxSpeed.

    p = inputParser();
    p.FunctionName = 'getMaxSpeedForEntityType';
    addRequired(p, 'entityType', @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(p, 'CohortMaxSpeedMps', [], ...
        @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 0));
    parse(p, entityType, varargin{:});

    cohortMax = p.Results.CohortMaxSpeedMps;
    if ~isempty(cohortMax) && cohortMax > 0
        maxSpeed = double(cohortMax);
        return;
    end

    switch char(entityType)
        case 'Transmitter'
            maxSpeed = 10; % m/s (vehicular)
        case 'Receiver'
            maxSpeed = 2;  % m/s (pedestrian)
        otherwise
            maxSpeed = 5;  % m/s (default)
    end
end
