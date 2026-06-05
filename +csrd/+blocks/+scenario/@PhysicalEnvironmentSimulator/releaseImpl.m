function releaseImpl(obj)
    % releaseImpl - Release graphics-heavy map resources.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.

    if ~isempty(obj.siteViewer)
        try
            delete(obj.siteViewer);
        catch
            % Best-effort cleanup only.
        end
    end

    obj.siteViewer = [];
    obj.mapInitialized = false;
end
