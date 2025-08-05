function hasOverlap = checkFrequencyOverlap(obj, range1, range2)
    % checkFrequencyOverlap - Check if two frequency ranges overlap
    separation = obj.Config.FrequencyAllocation.MinSeparation;
    hasOverlap = (range1(1) < range2(2) + separation) && (range1(2) > range2(1) - separation);
end
