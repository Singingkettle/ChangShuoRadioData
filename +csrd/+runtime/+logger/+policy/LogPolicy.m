classdef LogPolicy < handle
    %LOGPOLICY Centralised log-volume policy for CSRD's mlog logger.
    % 中文说明：提供 CSRD 生产链路中的 LogPolicy 实现。
    %
    %   Phase 0 (audit §16.10 / §17.2 / phase-0-baseline.md §2.2):
    %     The original codebase sprayed `obj.logger.debug(...)` calls into
    %     every hot path of the simulation chain. On a 200-scenario sweep
    %     this produced ~1e6 lines per worker and dominated wall-clock
    %     time -- without ever giving the operator something useful to
    %     act on. LogPolicy turns logging volume into a deliberate,
    %     versioned policy choice with three official tiers:
    %
    %       'Dev'      : everything to console + file, for interactive
    %                    debugging in MATLAB IDE
    %       'Standard' : INFO+ to console, DEBUG+ to file. Default for
    %                    the regression test suite and for ad-hoc demos.
    %       'LargeMC'  : WARNING+ to console, INFO+ to file. Required
    %                    for >100 scenario sweeps and for CI.
    %
    %   The policy is applied to the singleton mlog logger held by
    %   GlobalLogManager. We intentionally only touch the two threshold
    %   properties; we do NOT delete or rotate any handlers, so an
    %   already-open log file keeps receiving entries.
    %
    %   Usage:
    %       policy = csrd.runtime.logger.policy.LogPolicy('LargeMC');
    %       policy.apply();
    %       desc = policy.describe();   % human-readable, persistable
    %
    %   Bonus: also exposes `restore(prev)` for tests that need to leave
    %   the global logger untouched.
    %
    %   See also: csrd.runtime.logger.GlobalLogManager,
    %             csrd.runtime.logger.mlog.Level

    properties (SetAccess = immutable)
        % Level - the requested policy tier ('Dev'|'Standard'|'LargeMC')
        Level (1, :) char
    end

    properties (Access = private)
        % cached resolved threshold pair for `apply()`
        consoleThreshold
        fileThreshold
    end

    methods
        function obj = LogPolicy(level)
            %LOGPOLICY Construct a policy descriptor for the given tier.
            % 中文说明：LogPolicy 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.

            if nargin < 1 || isempty(level)
                level = 'Standard';
            end
            if isstring(level)
                level = char(level);
            end

            allowed = {'Dev', 'Standard', 'LargeMC'};
            % case-insensitive match, but store the canonical spelling
            idx = find(strcmpi(allowed, level), 1);
            if isempty(idx)
                error('CSRD:Phase0:InvalidLogPolicy', ...
                    ['LogPolicy: level must be one of {%s}, got "%s". ', ...
                    'See phase-0-baseline.md §2.2 for tier semantics.'], ...
                    strjoin(allowed, ', '), level);
            end
            obj.Level = allowed{idx};

            import csrd.runtime.logger.mlog.Level
            switch obj.Level
                case 'Dev'
                    obj.consoleThreshold = Level.DEBUG;
                    obj.fileThreshold    = Level.DEBUG;
                case 'Standard'
                    obj.consoleThreshold = Level.INFO;
                    obj.fileThreshold    = Level.DEBUG;
                case 'LargeMC'
                    obj.consoleThreshold = Level.WARNING;
                    obj.fileThreshold    = Level.INFO;
            end
        end

        function previous = apply(obj)
            %APPLY Push the policy onto the global logger.
            % 中文说明：apply 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            %
            %   previous = apply(obj) returns a struct snapshot of the
            %   logger's prior thresholds, suitable to pass back to
            %   `restore`. This lets test fixtures revert mutations
            %   even when an assertion fires mid-test.

            % Be defensive: if GlobalLogManager hasn't been initialised
            % yet, calling getLogger() would auto-init with default
            % paths. That's the right thing for production, but for unit
            % tests we want to surface the misuse loudly.
            if ~csrd.runtime.logger.GlobalLogManager.getInitializationStatus()
                error('CSRD:Phase0:LogPolicyNotInitialized', ...
                    ['LogPolicy.apply() requires GlobalLogManager to be ', ...
                    'initialised first. Call ', ...
                    'csrd.runtime.logger.GlobalLogManager.initialize(...) ', ...
                    'before applying a policy.']);
            end

            logger = csrd.runtime.logger.GlobalLogManager.getLogger();
            previous = struct( ...
                'CommandWindowThreshold', logger.CommandWindowThreshold, ...
                'FileThreshold', logger.FileThreshold);
            logger.CommandWindowThreshold = obj.consoleThreshold;
            logger.FileThreshold          = obj.fileThreshold;
        end

        function desc = describe(obj)
            %DESCRIBE Return a JSON-friendly struct describing the policy.
            % 中文说明：describe 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            %
            %   This is the value SimulationRunner injects into
            %   Header.Runtime.LogPolicy so that downstream consumers
            %   (or future audits) can tell whether a sweep ran in Dev
            %   or LargeMC mode without reading the original config.
            desc = struct( ...
                'Level',                  obj.Level, ...
                'ConsoleThreshold',       char(obj.consoleThreshold), ...
                'FileThreshold',          char(obj.fileThreshold), ...
                'AppliedAt',              char(datetime('now', ...
                    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''', ...
                    'TimeZone', 'UTC')));
        end
    end

    methods (Static)
        function restore(snapshot)
            %RESTORE Re-apply a previously captured threshold snapshot.
            % 中文说明：restore 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            arguments
                snapshot (1, 1) struct
            end
            if ~csrd.runtime.logger.GlobalLogManager.getInitializationStatus()
                return;
            end
            logger = csrd.runtime.logger.GlobalLogManager.getLogger();
            if isfield(snapshot, 'CommandWindowThreshold')
                logger.CommandWindowThreshold = snapshot.CommandWindowThreshold;
            end
            if isfield(snapshot, 'FileThreshold')
                logger.FileThreshold = snapshot.FileThreshold;
            end
        end
    end
end
