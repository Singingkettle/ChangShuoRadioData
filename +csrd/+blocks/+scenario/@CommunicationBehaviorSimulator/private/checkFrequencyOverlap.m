function hasOverlap = checkFrequencyOverlap(obj, range1, range2)
    % checkFrequencyOverlap - Check if two frequency ranges overlap
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 checkFrequencyOverlap 实现。
    separation = obj.Config.FrequencyAllocation.MinSeparation;
    hasOverlap = (range1(1) < range2(2) + separation) && (range1(2) > range2(1) - separation);
end
