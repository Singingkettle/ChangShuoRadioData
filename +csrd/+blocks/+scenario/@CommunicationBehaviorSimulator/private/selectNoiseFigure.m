function noiseFigure = selectNoiseFigure(obj, receiver, factoryConfig)
    % selectNoiseFigure - Select receiver noise figure
    range = factoryConfig.Parameters.NoiseFigure;
    noiseFigure = randomInRange(obj, range.Min, range.Max);
end
