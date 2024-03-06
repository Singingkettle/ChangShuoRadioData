function paramCells = config(params)

    paramCells = {};
    modulatorTypeList = params.modulatorType;
    filePrefix = params.filePrefix;
    for i = 1:length(modulatorTypeList)
        paramCells{end+1} = generate_single_config(filePrefix, ...
            modulatorTypeList{i});
    end

end

function modulatorParam = generate_single_config(filePrefix, modulatorType)

% The param for simulate data
    
    % The source data param
    sourceParam.modulatorType = modulatorType;
    sourceParam.samplePerSymbol = 8;
    sourceParam.samplePerFrame = 1024;

    channelParam.snr = 30;
    channelParam.centerFrequency = 902e6;
    channelParam.sampleRate = 200e3;
    channelParam.pathDelays = [0 1.8 3.4] / 200e3;
    channelParam.averagePathGains = [0 -2 -10];
    channelParam.kfactor = 4;
    channelParam.maximumDopplerShift = 4;
    channelParam.maximumClockOffset = 5;
    channelParam.channelType = 'whiteGaussian';

    filterParam.rolloffFactor = 0.35;
    filterParam.numSymbol = 4;
    filterParam.samplePerSymbol = sourceParam.samplePerSymbol;
    filterParam.shape = 'sqrt';
    
    modulatorParam.filterCoefficients = generate_coeff_rcos(filterParam);
    modulatorParam.rolloffFactor = filterParam.rolloffFactor;
    modulatorParam.numSymbol = filterParam.numSymbol;
    modulatorParam.sourceParam = sourceParam;
    modulatorParam.channelParam = channelParam;
    modulatorParam.modulatorType = modulatorType;    
    modulatorParam.samplePerSymbol = sourceParam.samplePerSymbol;
    modulatorParam.samplePerFrame = sourceParam.samplePerFrame;
    modulatorParam.symbolRate = channelParam.sampleRate;
    modulatorParam.sampleRate = channelParam.sampleRate;
    modulatorParam.windowLength = sourceParam.samplePerFrame;
    modulatorParam.stepSize = sourceParam.samplePerFrame;
    modulatorParam.offset = 50;
    modulatorParam.filePrefix = filePrefix;
    modulatorParam.repeatedNumber = 1;

end

function f = generate_coeff_rcos(filterParam)
%GENERATE_ 此处显示有关此函数的摘要
%   此处显示详细说明

f = rcosdesign(filterParam.rolloffFactor, filterParam.numSymbol, ...
    filterParam.samplePerSymbol, filterParam.shape);

end