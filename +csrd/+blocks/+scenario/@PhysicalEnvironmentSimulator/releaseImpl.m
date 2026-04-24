function releaseImpl(obj)
    % releaseImpl - Release graphics-heavy map resources.

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
