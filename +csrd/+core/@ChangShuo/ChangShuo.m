classdef ChangShuo < matlab.System
    % ChangShuo - Advanced Radio Communication Simulation Engine Core
    %
    % This class implements the core simulation engine for the ChangShuoRadioData
    % (CSRD) framework, providing comprehensive radio communication system modeling
    % with factory-based architecture, scenario-driven parameter instantiation,
    % and multi-antenna MIMO support. The engine orchestrates message generation,
    % modulation, transmission, channel modeling, and reception processes for
    % realistic wireless communication system evaluation.
    %
    % The ChangShuo engine represents a paradigm shift from monolithic simulation
    % approaches to modular, factory-based architectures that enable flexible
    % configuration, reproducible results, and scalable system modeling. It supports
    % advanced features including spatial diversity, beamforming, nonlinear RF
    % impairments, and AI/ML-optimized signal generation for modern wireless research.
    %
    % Key Features:
    %   - Factory-based modular architecture for flexible component instantiation
    %   - Scenario-driven parameter randomization and configuration management
    %   - Multi-antenna MIMO system modeling with spatial diversity
    %   - Advanced RF impairment modeling (nonlinearity, phase noise, IQ imbalance)
    %   - Comprehensive logging and debugging framework integration
    %   - Support for various modulation schemes and channel models
    %   - Configurable antenna array geometries and site configurations
    %   - Frame-based simulation with detailed annotation and metadata
    %
    % Technical Architecture:
    %   - Factory Pattern: Modular component instantiation and configuration
    %   - Strategy Pattern: Configurable algorithms for different system aspects
    %   - Observer Pattern: Comprehensive logging and monitoring capabilities
    %   - Template Method: Standardized simulation workflow with customizable steps
    %
    % Supported Factory Types:
    %   - MessageFactory: Random bit generation, audio signals, custom patterns
    %   - ModulationFactory: Digital/analog modulation schemes (PSK, QAM, OFDM, etc.)
    %   - ScenarioFactory: Parameter-driven scenario instantiation and planning
    %   - TransmitFactory: RF front-end modeling with impairments
    %   - ChannelFactory: Propagation modeling (AWGN, fading, MIMO channels)
    %   - ReceiveFactory: Receiver processing and signal recovery
    %
    % Syntax:
    %   engine = ChangShuo()
    %   engine = ChangShuo('PropertyName', PropertyValue, ...)
    %   [scenarioData, scenarioAnnotation] = engine(scenarioId)
    %
    % Properties (Configuration):
    %   FactoryConfigs - Configuration structures for each factory component
    %
    % Properties (Factory Configuration):
    %   Message - Message generation factory configuration
    %   Modulate - Modulation factory configuration
    %   Scenario - Scenario instantiation factory configuration
    %   Transmit - Transmitter RF front-end factory configuration
    %   Channel - Channel modeling factory configuration
    %   Receive - Receiver processing factory configuration
    %
    % Methods:
    %   step - Execute simulation for an entire scenario (all frames)
    %   setupImpl - Initialize factories and validate configurations
    %   validateFactoryConfigs - Validate factory configuration structures
    %   getFramesPerScenarioFromConfig - Extract frame count from scenario config
    %   generateSingleFrame - Generate data for a single frame (internal method)
    %
    % Example:
    %   % Basic engine creation
    %   engine = ChangShuo();
    %
    %   % Engine with factory configurations
    %   config = initialize_csrd_configuration();
    %   engine = ChangShuo('FactoryConfigs', config.Factories);
    %
    %   % Engine with specific factory configuration
    %   msgConfig.handle = 'csrd.factories.MessageFactory';
    %   msgConfig.Config = struct('Type', 'RandomBit');
    %   engine = ChangShuo('Message', msgConfig);
    %
    % See also: csrd.SimulationRunner, csrd.blocks.scenario.ParameterDrivenPlanner,
    %           csrd.factories.MessageFactory, csrd.factories.ModulationFactory,
    %           csrd.utils.logger.Log

    properties
        % FactoryConfigs - Consolidated factory configuration structure
        % Scenario configuration is accessed via FactoryConfigs.Scenario
        FactoryConfigs struct

        % Factory Configuration Properties
        % Each factory configuration is a struct with two required fields:
        % .handle (string) - Factory class name for instantiation
        % .Config (struct) - Factory-specific configuration parameters

        % Message - Message generation factory configuration
        Message

        % Modulate - Modulation factory configuration
        Modulate

        % Scenario - Scenario instantiation factory configuration
        Scenario

        % Transmit - Transmitter RF front-end factory configuration
        Transmit

        % Channel - Channel modeling factory configuration
        Channel

        % Receive - Receiver processing factory configuration
        Receive
    end

    properties (Access = private)
        % logger - Integrated logging framework instance
        logger

        % Factory Instance Properties
        % These properties store instantiated factory objects for component processing

        % pMessageFactory - Message generation factory instance
        pMessageFactory

        % pModulationFactory - Modulation processing factory instance
        pModulationFactory

        % pScenarioFactory - Scenario instantiation factory instance
        pScenarioFactory

        % pTransmitFactory - Transmitter RF front-end factory instance
        pTransmitFactory

        % pChannelFactory - Channel modeling factory instance
        pChannelFactory

        % pReceiveFactory - Receiver processing factory instance
        pReceiveFactory
    end

    methods

        function obj = ChangShuo(varargin)
            % ChangShuo - Constructor for radio communication simulation engine
            %
            % This constructor initializes the ChangShuo simulation engine with
            % optional property-value pairs for configuration. It sets up the
            % logging framework and prepares the engine for factory instantiation.
            %
            % Syntax:
            %   obj = ChangShuo()
            %   obj = ChangShuo('PropertyName', PropertyValue, ...)
            %
            % Input Arguments (Name-Value Pairs):
            %   'FactoryConfigs' - Factory configuration structure
            %   'Message' - Message factory configuration
            %   'Modulate' - Modulation factory configuration
            %   'Scenario' - Scenario factory configuration
            %   'Transmit' - Transmitter factory configuration
            %   'Channel' - Channel factory configuration
            %   'Receive' - Receiver factory configuration

            % Initialize integrated logging framework
            obj.logger = csrd.utils.logger.GlobalLogManager.getLogger();
            obj.logger.debug('ChangShuo Engine Core Initializing...');

            % Set properties from name-value pairs
            setProperties(obj, nargin, varargin{:});
            obj.logger.debug('ChangShuo Engine Core Properties Set.');
        end

    end

    methods (Access = protected)
        % setupImpl - Initialize factories and validate configurations
        setupImpl(obj)

        % stepImpl - Execute simulation for an entire scenario
        [ScenarioData, ScenarioAnnotation] = stepImpl(obj, scenarioId)
    end

    methods (Access = private)
        % Configuration and validation methods
        validateFactoryConfigs(obj)
        framesPerScenario = getFramesPerScenarioFromConfig(obj)

        % generateSingleFrame - Generate data for a single frame (internal method)
        [FrameData, FrameAnnotation] = generateSingleFrame(obj, FrameId, scenarioId, frameInScenario)

        % Scenario processing methods
        [instantiatedTxs, instantiatedRxs, globalLayout] = processScenarioInstantiation(obj, FrameId)

        % Transmitter processing methods
        [txsSignalSegments, TxInfos] = processTransmitters(obj, FrameId, numTxThisFrame)
        [signalSegmentsPerTx, TxInfo] = processSingleTransmitter(obj, FrameId, txIdx)
        TxInfo = setupTransmitterInfo(obj, FrameId, currentTxScenario, currentTxId)
        signalSegmentsPerTx = processTransmitterSegments(obj, FrameId, currentTxScenario, currentTxId)
        modulatedSignalSegment = processSingleSegment(obj, FrameId, currentTxScenario, currentTxId, segIdx)

        % Validation methods
        isValid = validateSegmentMessageConfig(obj, currentSegmentScenario, FrameId, currentTxId, segIdx)
        isValid = validateSegmentModulationConfig(obj, currentSegmentScenario, FrameId, currentTxId, segIdx)

        % Message and modulation processing methods
        rawMessageStruct = generateSegmentMessage(obj, FrameId, currentTxId, segIdx, currentSegmentScenario)
        modulatedSignalSegment = modulateSegmentMessage(obj, FrameId, currentTxId, segIdx, currentSegmentScenario, rawMessageStruct)
        updateTransmitterAntennaConfig(obj, FrameId, currentTxId, signalSegmentsPerTx, TxInfo)

        % Impairment processing methods
        txsSignalSegments = processTransmitImpairments(obj, FrameId, txsSignalSegments, TxInfos)

        % Receiver setup and processing methods
        RxInfos = setupReceivers(obj, FrameId, numRxThisFrame)
        signalsAtReceivers = processChannelPropagation(obj, FrameId, txsSignalSegments, TxInfos, RxInfos)
        [FrameData, FrameAnnotation] = processReceiverProcessing(obj, FrameId, signalsAtReceivers, RxInfos)
    end

end
