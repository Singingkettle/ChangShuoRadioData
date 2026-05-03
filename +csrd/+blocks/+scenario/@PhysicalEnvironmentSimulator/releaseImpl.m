function releaseImpl(obj)
    % releaseImpl - Release graphics-heavy map resources.
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 releaseImpl 实现。

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
