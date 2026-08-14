function varargout = freshAnnotationReader(action, annotationPath, varargin)
%FRESHANNOTATIONREADER Read a per-scenario annotation, proving it is not stale.
%
%   csrd.test_support.freshAnnotationReader('clear', annotationPath)
%   [annotation, meta] = csrd.test_support.freshAnnotationReader('read', annotationPath, tag)
%
%   WHY THIS EXISTS
%   Several regression tests loop over scenarios and read a hard-coded
%   `scenario_000001_annotation.json`, but the runner writes into a session
%   directory that is shared across the scenarios of one process. So when scenario
%   k fails to produce an annotation, the read silently returns scenario k-1's
%   file. Nothing errors, the source count stays plausible, and the test reports a
%   result for data it never generated.
%
%   That is not hypothetical. It produced a wrong published claim during the
%   occupied-bandwidth work: an improvement of "160 -> 44 plausibility violations"
%   was measured on repeats of one stale annotation, and the honest number was
%   160 -> 153. The generation failures behind it were invisible because the runner
%   still logged "Skipped scenarios: 0" -- the frames failed inside the engine, not
%   at the scenario level.
%
%   HOW FRESHNESS IS ESTABLISHED
%   By deleting the target before the step and requiring it to exist after, which
%   is unambiguous. Comparing timestamps would not be: `dir().datenum` resolves to
%   about a second, and two scenarios of a fast sweep can finish inside one tick,
%   so an unchanged stamp cannot be distinguished from a stale read. Comparing
%   bytes or checksums has the mirror problem -- two scenarios may legitimately
%   produce identical output.
%
%   The 'clear' action refuses any path outside an `artifacts` directory, so it can
%   only ever remove regenerable test output and never a real dataset.
%
%   Inputs:
%     action         - 'clear' or 'read'
%     annotationPath - full path to the scenario annotation JSON
%     tag            - ('read' only) short label used in the error message
%
%   Outputs ('read'):
%     annotation - the decoded struct
%     meta       - struct with .Bytes, .DatenumStr, .Path, for logging the identity
%                  of the file that was actually read
%
%   Throws:
%     CSRD:Test:UnsafeAnnotationClear    - 'clear' target is not test output
%     CSRD:Test:StaleAnnotationRead      - the file was not regenerated
%
%   See also: csrd.test_support.measuredPlausibilityViolations

switch lower(char(action))
    case 'clear'
        localAssertTestArtifact(annotationPath);
        if exist(annotationPath, 'file') == 2
            delete(annotationPath);
        end
        varargout = {};

    case 'read'
        if nargin >= 3 && ~isempty(varargin{1})
            tag = char(string(varargin{1}));
        else
            tag = 'annotation';
        end
        if exist(annotationPath, 'file') ~= 2
            error('CSRD:Test:StaleAnnotationRead', ...
                ['%s: no annotation at %s. It was cleared before this step, so ', ...
                 'its absence means generation produced nothing -- NOT that an ', ...
                 'earlier scenario''s file may be reused.'], tag, annotationPath);
        end
        d = dir(annotationPath);
        meta = struct('Bytes', d.bytes, 'DatenumStr', d.date, 'Path', annotationPath);
        annotation = jsondecode(fileread(annotationPath));
        varargout = {annotation, meta};

    otherwise
        error('CSRD:Test:UnknownFreshAnnotationAction', ...
            'freshAnnotationReader: action must be ''clear'' or ''read'' (got "%s").', ...
            char(string(action)));
end
end


function localAssertTestArtifact(annotationPath)
    % localAssertTestArtifact - refuse to delete anything but test output.
    %   A freshness helper that can reach outside artifacts/ would turn a mistyped
    %   path into data loss, so the guard is on the delete rather than on the
    %   caller's discipline.
    p = strrep(char(string(annotationPath)), '\', '/');
    parts = split(string(p), '/');
    if ~any(strcmpi(parts, 'artifacts'))
        error('CSRD:Test:UnsafeAnnotationClear', ...
            ['freshAnnotationReader(''clear'') refuses "%s": the path is not ', ...
             'under an artifacts directory, so it is not regenerable test ', ...
             'output.'], annotationPath);
    end
end
