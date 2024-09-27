function cfg = MemoryLessNonlinearityRandom(cfgFilePath)
fid = fopen(cfgFilePath, 'r');
if fid == -1
    error('Cannot open the file: %s', cfgFilePath);
end
str = fread(fid, '*char')';
fclose(fid);
cfgs = jsondecode(str);

% Get all field names of the struct
methods = fieldnames(cfgs.Methods);

% Generate a random index
randomIndex = randi(length(methods));

% Select the field name at the random index
method = methods{randomIndex};

% Get the value of the selected field
cfg = cfgs.Methods.(method);

if strcmpi(method, "Cubicpolynomial")
    cfg.Method = "Cubic polynomial";
    cfg.LinearGain = rand(1)*(cfg.LinearGain(2)-cfg.LinearGain(1))+cfg.LinearGain(1);
    cfg.TOISpecification = cfg.TOISpecification{randi(length(cfg.TOISpecification))};
    cfg.IIP3 = rand(1)*(cfg.IIP3(2)-cfg.IIP3(1))+cfg.IIP3(1);
    cfg.OIP3 = rand(1)*(cfg.OIP3(2)-cfg.OIP3(1))+cfg.OIP3(1);
    cfg.IP1dB = rand(1)*(cfg.IP1dB(2)-cfg.IP1dB(1))+cfg.IP1dB(1);
    cfg.OP1dB = rand(1)*(cfg.OP1dB(2)-cfg.OP1dB(1))+cfg.OP1dB(1);
    cfg.IPsat = rand(1)*(cfg.IPsat(2)-cfg.IPsat(1))+cfg.IPsat(1);
    cfg.OPsat = rand(1)*(cfg.OPsat(2)-cfg.OPsat(1))+cfg.OPsat(1);
    cfg.AMPMConversion = rand(1)*(cfg.AMPMConversion(2)-cfg.AMPMConversion(1))+cfg.AMPMConversion(1);
    if isstring(cfg.PowerUpperLimit) || ischar(cfg.PowerUpperLimit)
        cfg.PowerUpperLimit = inf;
    end
elseif strcmpi(method, "Hyperbolictangent")
    cfg.Method = "Hyperbolic tangent";
    cfg.LinearGain = rand(1)*(cfg.LinearGain(2)-cfg.LinearGain(1))+cfg.LinearGain(1);
    cfg.IIP3 = rand(1)*(cfg.IIP3(2)-cfg.IIP3(1))+cfg.IIP3(1);
    cfg.AMPMConversion = rand(1)*(cfg.AMPMConversion(2)-cfg.AMPMConversion(1))+cfg.AMPMConversion(1);
    if isstring(cfg.PowerUpperLimit) || ischar(cfg.PowerUpperLimit)
        cfg.PowerUpperLimit = inf;
    end
elseif strcmpi(method, "Salehmodel")
    cfg.Method = "Saleh model";
    cfg.InputScaling = rand(1)*(cfg.InputScaling(2)-cfg.InputScaling(1))+cfg.InputScaling(1);
    AMAMParameters = zeros(1, 2);
    AMAMParameters(1) = rand(1)*(cfg.AMAMParametersLeft(2)-cfg.AMAMParametersLeft(1))+cfg.AMAMParametersLeft(1);
    AMAMParameters(2) = rand(1)*(cfg.AMAMParametersRight(2)-cfg.AMAMParametersRight(1))+cfg.AMAMParametersRight(1);
    AMPMParameters = zeros(1, 2);
    AMPMParameters(1) = rand(1)*(cfg.AMPMParametersLeft(2)-cfg.AMPMParametersLeft(1))+cfg.AMPMParametersLeft(1);
    AMPMParameters(2) = rand(1)*(cfg.AMPMParametersRight(2)-cfg.AMPMParametersRight(1))+cfg.AMPMParametersRight(1);
    cfg.AMAMParameters = AMAMParameters;
    cfg.AMPMParameters = AMPMParameters;
    cfg.OutputScaling = rand(1)*(cfg.OutputScaling(2)-cfg.OutputScaling(1))+cfg.OutputScaling(1);
elseif strcmpi(method, "Ghorbanimodel")
    cfg.Method = "Ghorbani model";
    cfg.InputScaling = rand(1)*(cfg.InputScaling(2)-cfg.InputScaling(1))+cfg.InputScaling(1);
    AMAMParameters = zeros(1, 4);
    AMAMParameters(1) = rand(1)*(cfg.AMAMParametersLeft1(2)-cfg.AMAMParametersLeft1(1))+cfg.AMAMParametersLeft1(1);
    AMAMParameters(2) = rand(1)*(cfg.AMAMParametersLeft2(2)-cfg.AMAMParametersLeft2(1))+cfg.AMAMParametersLeft2(1);
    AMAMParameters(3) = rand(1)*(cfg.AMAMParametersRight1(2)-cfg.AMAMParametersRight1(1))+cfg.AMAMParametersRight1(1);
    AMAMParameters(4) = rand(1)*(cfg.AMAMParametersRight2(2)-cfg.AMAMParametersRight2(1))+cfg.AMAMParametersRight2(1);
    cfg.AMAMParameters = AMAMParameters;
    AMPMParameters = zeros(1, 4);
    AMPMParameters(1) = rand(1)*(cfg.AMAMParametersLeft1(2)-cfg.AMAMParametersLeft1(1))+cfg.AMAMParametersLeft1(1);
    AMPMParameters(2) = rand(1)*(cfg.AMAMParametersLeft2(2)-cfg.AMAMParametersLeft2(1))+cfg.AMAMParametersLeft2(1);
    AMPMParameters(3) = rand(1)*(cfg.AMAMParametersRight1(2)-cfg.AMAMParametersRight1(1))+cfg.AMAMParametersRight1(1);
    AMPMParameters(4) = rand(1)*(cfg.AMAMParametersRight2(2)-cfg.AMAMParametersRight2(1))+cfg.AMAMParametersRight2(1);
    cfg.AMPMParameters = AMPMParameters;
    cfg.OutputScaling = rand(1)*(cfg.OutputScaling(2)-cfg.OutputScaling(1))+cfg.OutputScaling(1);
elseif strcmpi(method, "ModifiedRappmodel")
    cfg.Method = "Modified Rapp model";
    cfg.LinearGain = rand(1)*(cfg.LinearGain(2)-cfg.LinearGain(1))+cfg.LinearGain(1);
    cfg.Smoothness = rand(1)*(cfg.Smoothness(2)-cfg.Smoothness(1))+cfg.Smoothness(1);
    cfg.PhaseGainRadian = rand(1)*(cfg.PhaseGainRadian(2)-cfg.PhaseGainRadian(1))+cfg.PhaseGainRadian(1);
    cfg.PhaseSaturation = rand(1)*(cfg.PhaseSaturation(2)-cfg.PhaseSaturation(1))+cfg.PhaseSaturation(1);
    cfg.PhaseSmoothness = rand(1)*(cfg.PhaseSmoothness(2)-cfg.PhaseSmoothness(1))+cfg.PhaseSmoothness(1);
    cfg.OutputSaturationLevel = rand(1)*(cfg.OutputSaturationLevel(2)-cfg.OutputSaturationLevel(1))+cfg.OutputSaturationLevel(1);
else
    error('Invalid method');
end
cfg.ReferenceImpedance = 1;

end