function nonlinearityConfig = MemoryLessNonlinearityRandom(configTemplates)
    % MemoryLessNonlinearityRandom - Random Power Amplifier Nonlinearity Configuration Generator
    %
    % This function generates randomized configurations for memoryless nonlinearity
    % models used in power amplifier (PA) simulations. It supports multiple PA
    % modeling approaches including polynomial, hyperbolic tangent, Saleh, Ghorbani,
    % and modified Rapp models with realistic parameter randomization for Monte
    % Carlo simulations and system robustness testing.
    %
    % Power amplifier nonlinearity is a critical impairment in wireless communication
    % systems, affecting signal quality, spectral efficiency, and out-of-band emissions.
    % This function provides standardized randomization of PA model parameters for
    % comprehensive system evaluation under various amplifier conditions.
    %
    % Syntax:
    %   nonlinearityConfig = MemoryLessNonlinearityRandom(configTemplates)
    %
    % Input Arguments:
    %   configTemplates - Structure containing configuration templates for different
    %                     nonlinearity models. Each field represents a different model
    %                     with parameter ranges for randomization.
    %                     Type: struct
    %
    % Output Arguments:
    %   nonlinearityConfig - Randomly selected and configured nonlinearity model
    %                        Type: struct with model-specific parameters
    %
    % Supported Models and Parameters:
    %
    % 1. Cubic Polynomial Model:
    %    - LinearGain: Linear amplification gain (dB)
    %    - TOISpecification: Third-order intercept specification type
    %    - IIP3/OIP3: Input/Output third-order intercept points (dBm)
    %    - IP1dB/OP1dB: Input/Output 1-dB compression points (dBm)
    %    - IPsat/OPsat: Input/Output saturation levels (dBm)
    %    - AMPMConversion: AM-to-PM conversion factor (deg/dB)
    %
    % 2. Hyperbolic Tangent Model:
    %    - LinearGain: Linear amplification gain (dB)
    %    - IIP3: Input third-order intercept point (dBm)
    %    - AMPMConversion: AM-to-PM conversion factor (deg/dB)
    %
    % 3. Saleh Model:
    %    - InputScaling: Input signal scaling factor
    %    - AMAMParameters: AM-to-AM conversion parameters [α_a, β_a]
    %    - AMPMParameters: AM-to-PM conversion parameters [α_φ, β_φ]
    %    - OutputScaling: Output signal scaling factor
    %
    % 4. Ghorbani Model:
    %    - InputScaling: Input signal scaling factor
    %    - AMAMParameters: AM-to-AM parameters [x1, x2, x3, x4]
    %    - AMPMParameters: AM-to-PM parameters [y1, y2, y3, y4]
    %    - OutputScaling: Output signal scaling factor
    %
    % 5. Modified Rapp Model:
    %    - LinearGain: Linear amplification gain (dB)
    %    - Smoothness: Amplitude smoothness parameter
    %    - PhaseGainRadian: Phase gain in radians
    %    - PhaseSaturation: Phase saturation level
    %    - PhaseSmoothness: Phase smoothness parameter
    %    - OutputSaturationLevel: Output saturation level
    %
    % Example:
    %   % Define configuration templates
    %   templates.Cubicpolynomial.LinearGain = [10, 30]; % 10-30 dB range
    %   templates.Cubicpolynomial.TOISpecification = {'IIP3', 'OIP3'};
    %   templates.Cubicpolynomial.IIP3 = [5, 15]; % 5-15 dBm range
    %   templates.Cubicpolynomial.OIP3 = [20, 40]; % 20-40 dBm range
    %   % ... (additional parameters)
    %
    %   % Generate random configuration
    %   paConfig = csrd.utils.MemoryLessNonlinearityRandom(templates);
    %   fprintf('Selected model: %s\n', paConfig.Method);
    %   fprintf('Linear gain: %.1f dB\n', paConfig.LinearGain);
    %
    % Applications:
    %   - Monte Carlo simulation of PA nonlinearity effects
    %   - System robustness testing under various PA conditions
    %   - Performance evaluation across different amplifier types
    %   - Statistical analysis of nonlinearity impact on signal quality
    %   - Automated test case generation for PA modeling validation
    %
    % Model Selection Guidelines:
    %   - Cubic Polynomial: General-purpose, good for mild-to-moderate nonlinearity
    %   - Hyperbolic Tangent: Simplified model, computationally efficient
    %   - Saleh: Traveling wave tube amplifiers (TWTA), satellite applications
    %   - Ghorbani: Solid-state power amplifiers (SSPA), improved accuracy
    %   - Modified Rapp: Enhanced Rapp model with phase nonlinearity
    %
    % References:
    %   - MATLAB Communications Toolbox Memoryless Nonlinearity documentation
    %   - Saleh, A.A.M. "Frequency-Independent and Frequency-Dependent Nonlinear Models"
    %   - Ghorbani, A. and Sheikhan, M. "The Effect of Solid State Power Amplifiers"
    %   - Rapp, C. "Effects of HPA-Nonlinearity on a 4-DPSK/OFDM-Signal"
    %
    % See also: comm.MemorylessNonlinearity, csrd.blocks.physical.txRadioFront.TRFSimulator

    % Validate input arguments
    if nargin < 1
        error('ChangShuoRadioData:MemoryLessNonlinearityRandom:InsufficientInputs', ...
        'Function requires configTemplates structure as input.');
    end

    if ~isstruct(configTemplates)
        error('ChangShuoRadioData:MemoryLessNonlinearityRandom:InvalidInput', ...
        'configTemplates must be a structure with nonlinearity model templates.');
    end

    % Get available nonlinearity model names
    availableModels = fieldnames(configTemplates);

    if isempty(availableModels)
        error('ChangShuoRadioData:MemoryLessNonlinearityRandom:EmptyTemplates', ...
        'configTemplates structure is empty. Must contain at least one model template.');
    end

    % Randomly select a nonlinearity model
    randomModelIndex = randi(length(availableModels));
    selectedModelName = availableModels{randomModelIndex};

    % Get the configuration template for the selected model
    selectedTemplate = configTemplates.(selectedModelName);

    % Generate random configuration based on the selected model
    switch lower(selectedModelName)
        case 'cubicpolynomial'
            nonlinearityConfig = generateCubicPolynomialConfig(selectedTemplate);

        case 'hyperbolictangent'
            nonlinearityConfig = generateHyperbolicTangentConfig(selectedTemplate);

        case 'salehmodel'
            nonlinearityConfig = generateSalehModelConfig(selectedTemplate);

        case 'ghorbanimodel'
            nonlinearityConfig = generateGhorbaniModelConfig(selectedTemplate);

        case 'modifiedrappmodel'
            nonlinearityConfig = generateModifiedRappModelConfig(selectedTemplate);

        otherwise
            error('ChangShuoRadioData:MemoryLessNonlinearityRandom:UnsupportedModel', ...
                'Unsupported nonlinearity model ''%s''. Supported models: %s', ...
                selectedModelName, strjoin(availableModels, ', '));
    end

    % Set standard reference impedance (50 ohms is industry standard)
    nonlinearityConfig.ReferenceImpedance = 50; % Standard RF impedance

end

function config = generateCubicPolynomialConfig(template)
    % generateCubicPolynomialConfig - Generate cubic polynomial PA model configuration
    %
    % The cubic polynomial model is suitable for general-purpose PA modeling
    % with configurable third-order intercept points and compression characteristics.

    config = struct();
    config.Method = 'Cubic polynomial';

    % Randomize linear gain within specified range
    config.LinearGain = randomizeParameter(template.LinearGain, 'LinearGain');

    % Randomly select TOI specification method
    if isfield(template, 'TOISpecification') && iscell(template.TOISpecification)
        config.TOISpecification = template.TOISpecification{randi(length(template.TOISpecification))};
    else
        config.TOISpecification = 'IIP3'; % Default specification
    end

    % Randomize intercept and compression point parameters
    config.IIP3 = randomizeParameter(template.IIP3, 'IIP3');
    config.OIP3 = randomizeParameter(template.OIP3, 'OIP3');
    config.IP1dB = randomizeParameter(template.IP1dB, 'IP1dB');
    config.OP1dB = randomizeParameter(template.OP1dB, 'OP1dB');
    config.IPsat = randomizeParameter(template.IPsat, 'IPsat');
    config.OPsat = randomizeParameter(template.OPsat, 'OPsat');
    config.AMPMConversion = randomizeParameter(template.AMPMConversion, 'AMPMConversion');

    % Handle power upper limit specification
    if isfield(template, 'PowerUpperLimit')

        if isstring(template.PowerUpperLimit) || ischar(template.PowerUpperLimit)
            config.PowerUpperLimit = inf; % No upper limit
        else
            config.PowerUpperLimit = randomizeParameter(template.PowerUpperLimit, 'PowerUpperLimit');
        end

    else
        config.PowerUpperLimit = inf; % Default: no limit
    end

end

function config = generateHyperbolicTangentConfig(template)
    % generateHyperbolicTangentConfig - Generate hyperbolic tangent PA model configuration
    %
    % The hyperbolic tangent model provides a simplified but effective approach
    % for modeling soft-limiting amplifier characteristics.

    config = struct();
    config.Method = 'Hyperbolic tangent';

    % Randomize model parameters
    config.LinearGain = randomizeParameter(template.LinearGain, 'LinearGain');
    config.IIP3 = randomizeParameter(template.IIP3, 'IIP3');
    config.AMPMConversion = randomizeParameter(template.AMPMConversion, 'AMPMConversion');

    % Handle power upper limit
    if isfield(template, 'PowerUpperLimit')

        if isstring(template.PowerUpperLimit) || ischar(template.PowerUpperLimit)
            config.PowerUpperLimit = inf;
        else
            config.PowerUpperLimit = randomizeParameter(template.PowerUpperLimit, 'PowerUpperLimit');
        end

    else
        config.PowerUpperLimit = inf;
    end

end

function config = generateSalehModelConfig(template)
    % generateSalehModelConfig - Generate Saleh PA model configuration
    %
    % The Saleh model is particularly suitable for traveling wave tube amplifiers
    % (TWTA) commonly used in satellite communication systems.

    config = struct();
    config.Method = 'Saleh model';

    % Randomize scaling parameters
    config.InputScaling = randomizeParameter(template.InputScaling, 'InputScaling');
    config.OutputScaling = randomizeParameter(template.OutputScaling, 'OutputScaling');

    % Generate AM-to-AM conversion parameters [α_a, β_a]
    amamParameters = zeros(1, 2);
    amamParameters(1) = randomizeParameter(template.AMAMParametersLeft, 'AMAMParametersLeft');
    amamParameters(2) = randomizeParameter(template.AMAMParametersRight, 'AMAMParametersRight');
    config.AMAMParameters = amamParameters;

    % Generate AM-to-PM conversion parameters [α_φ, β_φ]
    ampmParameters = zeros(1, 2);
    ampmParameters(1) = randomizeParameter(template.AMPMParametersLeft, 'AMPMParametersLeft');
    ampmParameters(2) = randomizeParameter(template.AMPMParametersRight, 'AMPMParametersRight');
    config.AMPMParameters = ampmParameters;

end

function config = generateGhorbaniModelConfig(template)
    % generateGhorbaniModelConfig - Generate Ghorbani PA model configuration
    %
    % The Ghorbani model provides improved accuracy for solid-state power
    % amplifiers (SSPA) with enhanced parameter flexibility.

    config = struct();
    config.Method = 'Ghorbani model';

    % Randomize scaling parameters
    config.InputScaling = randomizeParameter(template.InputScaling, 'InputScaling');
    config.OutputScaling = randomizeParameter(template.OutputScaling, 'OutputScaling');

    % Generate 4-parameter AM-to-AM conversion [x1, x2, x3, x4]
    amamParameters = zeros(1, 4);
    amamParameters(1) = randomizeParameter(template.AMAMParametersLeft1, 'AMAMParametersLeft1');
    amamParameters(2) = randomizeParameter(template.AMAMParametersLeft2, 'AMAMParametersLeft2');
    amamParameters(3) = randomizeParameter(template.AMAMParametersRight1, 'AMAMParametersRight1');
    amamParameters(4) = randomizeParameter(template.AMAMParametersRight2, 'AMAMParametersRight2');
    config.AMAMParameters = amamParameters;

    % Generate 4-parameter AM-to-PM conversion [y1, y2, y3, y4]
    % Note: Using same template fields as AM-AM for parameter generation
    ampmParameters = zeros(1, 4);
    ampmParameters(1) = randomizeParameter(template.AMAMParametersLeft1, 'AMPMParametersLeft1');
    ampmParameters(2) = randomizeParameter(template.AMAMParametersLeft2, 'AMPMParametersLeft2');
    ampmParameters(3) = randomizeParameter(template.AMAMParametersRight1, 'AMPMParametersRight1');
    ampmParameters(4) = randomizeParameter(template.AMAMParametersRight2, 'AMPMParametersRight2');
    config.AMPMParameters = ampmParameters;

end

function config = generateModifiedRappModelConfig(template)
    % generateModifiedRappModelConfig - Generate modified Rapp PA model configuration
    %
    % The modified Rapp model extends the classical Rapp model with additional
    % phase nonlinearity modeling for enhanced accuracy.

    config = struct();
    config.Method = 'Modified Rapp model';

    % Randomize amplitude nonlinearity parameters
    config.LinearGain = randomizeParameter(template.LinearGain, 'LinearGain');
    config.Smoothness = randomizeParameter(template.Smoothness, 'Smoothness');
    config.OutputSaturationLevel = randomizeParameter(template.OutputSaturationLevel, 'OutputSaturationLevel');

    % Randomize phase nonlinearity parameters
    config.PhaseGainRadian = randomizeParameter(template.PhaseGainRadian, 'PhaseGainRadian');
    config.PhaseSaturation = randomizeParameter(template.PhaseSaturation, 'PhaseSaturation');
    config.PhaseSmoothness = randomizeParameter(template.PhaseSmoothness, 'PhaseSmoothness');

end

function randomValue = randomizeParameter(parameterRange, parameterName)
    % randomizeParameter - Generate random value within specified range
    %
    % This helper function generates a random value within the specified range
    % with proper error handling for invalid parameter specifications.
    %
    % Input Arguments:
    %   parameterRange - [min, max] range for parameter randomization
    %   parameterName - Name of parameter for error reporting
    %
    % Output Arguments:
    %   randomValue - Randomly generated value within the specified range

    if ~isfield(struct('field', parameterRange), 'field') || isempty(parameterRange)
        error('ChangShuoRadioData:MemoryLessNonlinearityRandom:MissingParameter', ...
            'Parameter ''%s'' is not defined in the template.', parameterName);
    end

    if ~isnumeric(parameterRange) || length(parameterRange) ~= 2
        error('ChangShuoRadioData:MemoryLessNonlinearityRandom:InvalidParameterRange', ...
            'Parameter ''%s'' must be a numeric array [min, max].', parameterName);
    end

    minValue = parameterRange(1);
    maxValue = parameterRange(2);

    if minValue > maxValue
        error('ChangShuoRadioData:MemoryLessNonlinearityRandom:InvalidRange', ...
            'For parameter ''%s'', minimum value (%.3f) must be <= maximum value (%.3f).', ...
            parameterName, minValue, maxValue);
    end

    % Generate random value within the specified range
    randomValue = rand * (maxValue - minValue) + minValue;

end
