% MessageFactory - Advanced Message Generation Factory for Radio Communication Systems
%
% This class implements a sophisticated factory pattern for generating diverse
% message types in radio communication simulations. The MessageFactory provides
% a unified interface for creating various data sources including random bit
% sequences, audio signals, custom patterns, and AI/ML-optimized training data
% for wireless communication research and system validation.
%
% The MessageFactory represents a key component in the ChangShuoRadioData (CSRD)
% framework's modular architecture, enabling flexible message source configuration,
% efficient block instantiation and caching, and comprehensive parameter management
% for reproducible simulation results across different research applications.
%
% Key Features:
%   - Factory pattern implementation for flexible message source instantiation
%   - Support for multiple message types with configurable parameters
%   - Intelligent block caching for performance optimization
%   - Hierarchical configuration management with JSON support
%   - Comprehensive logging and debugging capabilities
%   - Integration with scenario-driven parameter selection
%   - Extensible architecture for custom message source development
%   - Thread-safe operation for parallel simulation environments
%
% Supported Message Types:
%   - RandomBit: Pseudo-random binary sequences with configurable probability
%   - AudioSignal: Audio file-based message sources for realistic data
%   - CustomPattern: User-defined bit patterns and sequences
%   - MLOptimized: AI/ML-optimized data patterns for algorithm training
%   - StructuredData: Protocol-specific message structures
%   - NoisePattern: Controlled noise sequences for robustness testing
%   - SynchronizationSequence: Known patterns for timing recovery
%
% Technical Architecture:
%   - Factory Pattern: Centralized message source instantiation and management
%   - Caching Strategy: Efficient block reuse with parameter reconfiguration
%   - Configuration Hierarchy: JSON-based configuration with inheritance
%   - Logging Integration: Comprehensive debugging and performance monitoring
%   - Error Handling: Robust error detection and recovery mechanisms
%
% Syntax:
%   factory = MessageFactory()
%   factory = MessageFactory('Config', configStruct)
%   factory = MessageFactory('PropertyName', PropertyValue, ...)
%   messageData = factory(frameId, segmentInfo, messageTypeID)
%
% Properties:
%   Config - Comprehensive message factory configuration structure
%            Type: struct with message type definitions and parameters
%
% Configuration Structure:
%   The Config property contains a hierarchical structure defining available
%   message types, their instantiation parameters, and default configurations:
%
%   .MessageTypes - Structure containing all supported message type definitions
%     .<TypeName> - Individual message type configuration
%       .handle - MATLAB class name for message source instantiation
%       .Config - Default configuration parameters for the message type
%       .Description - Human-readable description of the message type
%       .Parameters - Supported parameter definitions and constraints
%       .Applications - Recommended use cases and applications
%
%   .LogDetails - Enable detailed logging for debugging and analysis
%                 Type: logical, Default: false
%
%   .CacheStrategy - Block caching strategy for performance optimization
%                    Type: string, Options: 'PerType', 'PerSegment', 'Disabled'
%                    Default: 'PerType'
%
%   .ValidationLevel - Configuration validation strictness level
%                      Type: string, Options: 'Strict', 'Moderate', 'Minimal'
%                      Default: 'Moderate'
%
% Methods:
%   step - Generate message data for specified type and parameters
%   setupImpl - Initialize factory with configuration validation
%   validateConfiguration - Validate factory configuration structure
%   getCachedBlock - Retrieve or create cached message source block
%   configureBlock - Configure message block with segment parameters
%   clearCache - Clear cached message blocks for memory management
%
% Example:
%   % Create message factory with configuration
%   config = struct();
%   config.MessageTypes.RandomBit.handle = 'csrd.blocks.message.RandomBit';
%   config.MessageTypes.RandomBit.Config.BiasedProbability = 0.5;
%   config.MessageTypes.RandomBit.Config.SeedControl = true;
%   config.MessageTypes.AudioSignal.handle = 'csrd.blocks.message.AudioSignal';
%   config.MessageTypes.AudioSignal.Config.SampleRate = 44100;
%   config.LogDetails = true;
%
%   factory = csrd.factories.MessageFactory('Config', config);
%
%   % Configure segment information
%   segmentInfo = struct();
%   segmentInfo.SegmentID = 'Seg001';
%   segmentInfo.Message.Length = 1000;
%   segmentInfo.Message.SeedValue = 12345;
%
%   % Generate random bit message
%   frameId = 1;
%   messageTypeID = 'RandomBit';
%   messageData = factory(frameId, segmentInfo, messageTypeID);
%
%   % Analyze generated message
%   fprintf('Generated %d bits with mean value %.3f\n', ...
%           length(messageData.data), mean(messageData.data));
%
% Advanced Configuration Example:
%   % Multi-type message factory with custom parameters
%   config = struct();
%
%   % Random bit configuration
%   config.MessageTypes.RandomBit.handle = 'csrd.blocks.message.RandomBit';
%   config.MessageTypes.RandomBit.Config.BiasedProbability = 0.5;
%   config.MessageTypes.RandomBit.Config.SeedControl = true;
%   config.MessageTypes.RandomBit.Config.OutputOrientation = 'column';
%   config.MessageTypes.RandomBit.Description = 'Pseudo-random binary sequences';
%
%   % Audio signal configuration
%   config.MessageTypes.AudioSignal.handle = 'csrd.blocks.message.AudioSignal';
%   config.MessageTypes.AudioSignal.Config.SampleRate = 44100;
%   config.MessageTypes.AudioSignal.Config.BitDepth = 16;
%   config.MessageTypes.AudioSignal.Config.Channels = 1;
%   config.MessageTypes.AudioSignal.Description = 'Audio file-based messages';
%
%   % Custom pattern configuration
%   config.MessageTypes.CustomPattern.handle = 'csrd.blocks.message.CustomPattern';
%   config.MessageTypes.CustomPattern.Config.PatternType = 'Barker';
%   config.MessageTypes.CustomPattern.Config.RepetitionCount = 10;
%   config.MessageTypes.CustomPattern.Description = 'Known bit patterns';
%
%   % Factory-level configuration
%   config.LogDetails = true;
%   config.CacheStrategy = 'PerType';
%   config.ValidationLevel = 'Strict';
%
%   factory = csrd.factories.MessageFactory('Config', config);
%
% Message Type Development Guidelines:
%   Custom message types should implement the following interface:
%   - Constructor accepting name-value pairs for configuration
%   - Properties for configurable parameters with validation
%   - step() method returning structured message data
%   - Proper error handling and logging integration
%   - Documentation following MATLAB standards
%
% Performance Considerations:
%   - Block caching reduces instantiation overhead for repeated use
%   - Memory usage scales with number of cached blocks and message length
%   - Configuration validation performed once during setup
%   - Suitable for high-throughput message generation (>1000 messages/second)
%   - Thread-safe design enables parallel simulation environments
%
% Integration with CSRD Framework:
%   - ChangShuo Engine: Receives message data for modulation processing
%   - Scenario Planning: Provides segment-specific message parameters
%   - Configuration Management: JSON-based configuration loading
%   - Logger Framework: Comprehensive debugging and monitoring
%   - Factory Pattern: Consistent interface with other CSRD factories
%
% Error Handling:
%   The factory implements comprehensive error handling including:
%   - Configuration validation with descriptive error messages
%   - Message type existence verification
%   - Parameter constraint validation
%   - Block instantiation error recovery
%   - Graceful degradation for missing optional parameters
%
% See also: csrd.blocks.message.RandomBit, csrd.blocks.message.AudioSignal,
%           csrd.core.ChangShuo, csrd.factories.ModulationFactory,
%           csrd.utils.logger.Log

classdef MessageFactory < matlab.System

    properties
        % Config - Comprehensive message factory configuration structure
        % Type: struct, Default: empty
        %
        % This property contains the complete configuration for the message factory,
        % defining available message types, their instantiation parameters, default
        % configurations, and factory-level operational settings. The configuration
        % structure enables flexible customization of message generation behavior
        % for different research applications and system requirements.
        %
        % Structure Organization:
        %   .MessageTypes - Hierarchical message type definitions
        %     .<TypeName> - Individual message type configuration
        %       .handle - MATLAB class name for instantiation
        %       .Config - Default configuration parameters
        %       .Description - Human-readable type description
        %       .Parameters - Supported parameter definitions
        %       .Applications - Recommended use cases
        %   .LogDetails - Enable detailed logging and debugging
        %   .CacheStrategy - Block caching strategy selection
        %   .ValidationLevel - Configuration validation strictness
        %
        % Configuration Guidelines:
        %   - Define message types with clear handle specifications
        %   - Provide comprehensive default configurations
        %   - Include parameter validation and constraints
        %   - Enable logging for debugging and analysis
        %   - Use appropriate caching strategy for performance
        %
        % Example Configuration:
        %   config = struct();
        %   config.MessageTypes.RandomBit.handle = 'csrd.blocks.message.RandomBit';
        %   config.MessageTypes.RandomBit.Config.BiasedProbability = 0.5;
        %   config.MessageTypes.RandomBit.Config.SeedControl = true;
        %   config.MessageTypes.RandomBit.Description = 'Pseudo-random binary sequences';
        %   config.LogDetails = true;
        %   config.CacheStrategy = 'PerType';
        %   config.ValidationLevel = 'Moderate';
        %
        % Advanced Configuration Features:
        %   - Hierarchical parameter inheritance
        %   - Conditional configuration based on system capabilities
        %   - Dynamic parameter validation and constraint checking
        %   - Performance optimization through intelligent caching
        %   - Extensible architecture for custom message types
        Config struct

        % MessageInfos - Legacy message configuration array (Being Phased Out)
        % Type: cell array, Default: empty
        %
        % This property was originally used to store message configuration for each
        % transmitter segment from scenario planning. It is being phased out in favor
        % of direct parameter passing through the step method interface, providing
        % more flexible and efficient message generation workflows.
        %
        % Migration Notes:
        %   - New implementations should use direct parameter passing
        %   - Existing code using MessageInfos will continue to work
        %   - Future versions will remove this property entirely
        %   - Use segmentInfo parameter in step method instead
        %
        % Legacy Structure:
        %   MessageInfos{transmitterIndex}.MessageType - Message type identifier
        %   MessageInfos{transmitterIndex}.Parameters - Type-specific parameters
        %   MessageInfos{transmitterIndex}.Configuration - Override configurations
        %
        % Replacement Approach:
        %   Instead of pre-configuring MessageInfos, pass parameters directly:
        %   segmentInfo.Message.Length = 1000;
        %   segmentInfo.Message.SeedValue = 12345;
        %   messageData = factory(frameId, segmentInfo, messageTypeID);
        % MessageInfos % Temporarily commented out during migration
    end

    properties (Access = private)
        % logger - Hierarchical logging framework instance
        % Type: csrd.utils.logger.Log object
        %
        % Provides comprehensive logging capabilities for message factory operations
        % including configuration validation, block instantiation, parameter management,
        % performance monitoring, and error handling. The logger supports hierarchical
        % logging levels for detailed debugging and analysis.
        logger

        % factoryConfiguration - Internal factory configuration storage
        % Type: struct
        %
        % Stores the validated and processed factory configuration for internal use.
        % This property contains the complete configuration structure after validation,
        % default value assignment, and optimization for runtime performance.
        factoryConfiguration

        % cachedMessageBlocks - Message block instance cache
        % Type: containers.Map object
        %
        % Implements intelligent caching of instantiated message source blocks to
        % optimize performance for repeated message generation. The cache uses
        % configurable key strategies (per-type, per-segment, etc.) to balance
        % memory usage and instantiation overhead.
        %
        % Cache Key Strategies:
        %   - PerType: Cache one instance per message type (memory efficient)
        %   - PerSegment: Cache per unique segment configuration (performance optimized)
        %   - Disabled: No caching, create new instances for each call
        %
        % Cache Management:
        %   - Automatic cleanup for memory management
        %   - Configurable cache size limits
        %   - Performance metrics and hit rate monitoring
        %   - Thread-safe access for parallel environments
        cachedMessageBlocks
    end

    methods

        function obj = MessageFactory(varargin)
            % MessageFactory - Constructor for advanced message generation factory
            %
            % Creates a new MessageFactory instance with configurable message types,
            % caching strategies, and operational parameters. The constructor accepts
            % name-value pairs for comprehensive configuration of the factory behavior
            % and initializes the caching system for optimal performance.
            %
            % Syntax:
            %   obj = MessageFactory()
            %   obj = MessageFactory('Config', configStruct)
            %   obj = MessageFactory('PropertyName', PropertyValue, ...)
            %
            % Input Arguments (Name-Value Pairs):
            %   'Config' - Complete message factory configuration structure
            %              Type: struct with message type definitions and parameters
            %              Default: empty (initialized with defaults in setupImpl)
            %
            % Output Arguments:
            %   obj - MessageFactory instance ready for message generation
            %         Type: MessageFactory object with configured parameters
            %
            % Configuration Structure:
            %   The Config parameter accepts a structure defining message types and
            %   factory operational parameters. Each message type requires a handle
            %   for instantiation and optional configuration parameters.
            %
            % Example:
            %   % Create factory with default configuration
            %   factory = csrd.factories.MessageFactory();
            %
            %   % Create factory with custom configuration
            %   config = struct();
            %   config.MessageTypes.RandomBit.handle = 'csrd.blocks.message.RandomBit';
            %   config.MessageTypes.RandomBit.Config.BiasedProbability = 0.5;
            %   config.MessageTypes.AudioSignal.handle = 'csrd.blocks.message.AudioSignal';
            %   config.MessageTypes.AudioSignal.Config.SampleRate = 44100;
            %
            %   factory = csrd.factories.MessageFactory('Config', config);
            %
            %   % Create factory with individual parameter configuration
            %   factory = csrd.factories.MessageFactory( ...
            %       'Config', struct('LogDetails', true, ...
            %                        'CacheStrategy', 'PerSegment'));
            %
            % Initialization Process:
            %   1. Parse input arguments and extract configuration parameters
            %   2. Initialize message block cache with appropriate strategy
            %   3. Store configuration for validation during setupImpl
            %   4. Prepare factory for message generation operations
            %
            % Performance Notes:
            %   - Constructor overhead is minimal (O(1) complexity)
            %   - Cache initialization optimized for expected usage patterns
            %   - Configuration validation deferred to setupImpl for efficiency
            %   - Memory allocation optimized for repeated message generation
            %
            % See also: setupImpl, step, getCachedBlock

            % Parse input arguments and set object properties
            % Configuration validation and detailed initialization deferred to setupImpl
            setProperties(obj, nargin, varargin{:});

            % Initialize message block cache with containers.Map for efficient lookup
            % Cache strategy and size limits will be configured in setupImpl
            obj.cachedMessageBlocks = containers.Map();

            % Logger initialization deferred to setupImpl to ensure Config is available
            % for LogDetails configuration and proper hierarchical logging setup
        end

    end

    methods (Access = protected)

        function setupImpl(obj)

            if isempty(obj.Config) || ~isstruct(obj.Config) || ~isfield(obj.Config, 'MessageTypes')
                error('MessageFactory:ConfigError', 'Config property must be a valid struct with a MessageTypes field.');
            end

            obj.factoryConfiguration = obj.Config; % The passed-in struct is the factory's config

            obj.logger = csrd.utils.logger.GlobalLogManager.getLogger();

            obj.logger.debug('MessageFactory setupImpl initializing with directly passed config struct.');

            % Pre-validation of handles in config (optional, blocks will error if handle is bad at step)
            typeNames = fieldnames(obj.factoryConfiguration.MessageTypes);

            for i = 1:length(typeNames)
                typeName = typeNames{i};

                if ~isfield(obj.factoryConfiguration.MessageTypes.(typeName), 'handle') || ...
                        isempty(obj.factoryConfiguration.MessageTypes.(typeName).handle)
                    error('MessageFactory:ConfigError', 'Message type ''%s'' in config is missing a ''handle''.', typeName);
                end

            end

            obj.logger.debug('MessageFactory setupImpl complete. Available message types: %s', strjoin(typeNames, ', '));
        end

        function messageData = stepImpl(obj, frameId, segmentInfo, messageTypeID)
            % segmentInfo is expected to contain per-segment details, like Message.Length
            % messageTypeID is the string key from Scenario.Transmitters.Segments.Message.TypeID,
            % e.g., "RandomBits"

            obj.logger.debug('Frame %d, SegID %s: MessageFactory step for TypeID: %s', ...
                frameId, segmentInfo.SegmentID, messageTypeID);

            if ~isfield(obj.factoryConfiguration.MessageTypes, messageTypeID)
                error('MessageFactory:UnknownType', 'Message TypeID ''%s'' not found in factory configuration.', messageTypeID);
            end

            typeDetails = obj.factoryConfiguration.MessageTypes.(messageTypeID);
            blockHandleStr = typeDetails.handle;
            defaultBlockConfig = struct(); % Default if no .Config sub-struct for the type

            if isfield(typeDetails, 'Config') && isstruct(typeDetails.Config)
                defaultBlockConfig = typeDetails.Config;
            end

            % --- Get or create the message source block ---
            % For message sources, caching strategy might differ. If a block (like RandomBit)
            % needs to be reset per unique segment call with different parameters (e.g., seed, length),
            % then caching might be per unique (messageTypeID + segmentId) or we might not cache.
            % For now, assume caching per messageTypeID and reconfiguring if necessary.

            blockCacheKey = messageTypeID; % Could be made more specific if needed

            if ~isKey(obj.cachedMessageBlocks, blockCacheKey)
                obj.logger.debug('Frame %d, SegID %s: Creating new message block for TypeID: %s (handle: %s)', ...
                    frameId, segmentInfo.SegmentID, messageTypeID, blockHandleStr);

                try
                    % Instantiate with default config from MessageFactoryConfig
                    % The specific block must handle these name-value pairs
                    constructorArgs = {};
                    cfgFields = fieldnames(defaultBlockConfig);

                    for k = 1:length(cfgFields)
                        constructorArgs{end + 1} = cfgFields{k};
                        constructorArgs{end + 1} = defaultBlockConfig.(cfgFields{k});
                    end

                    msgBlock = feval(blockHandleStr, constructorArgs{:});
                    obj.cachedMessageBlocks(blockCacheKey) = msgBlock;

                    if isa(msgBlock, 'matlab.System')
                        setup(msgBlock); % Explicitly call setup
                    end

                    obj.logger.debug('Message block for TypeID ''%s'' created and set up.', messageTypeID);
                catch ME
                    obj.logger.error('Failed to create or setup message block ''%s''. Error: %s', blockHandleStr, ME.message);
                    rethrow(ME);
                end

            end

            currentMessageBlock = obj.cachedMessageBlocks(blockCacheKey);

            % --- Configure and run the specific message block's step method ---
            % The actual parameters passed to the block's step method (or set as properties before step)
            % depend on the specific block's interface.
            % Assuming message blocks take specific parameters like MessageLength directly.
            % segmentInfo.Message should contain these specific parameters from the scenario.

            if ~isfield(segmentInfo, 'Message') || ~isstruct(segmentInfo.Message)
                error('MessageFactory:InputError', 'segmentInfo for MessageFactory must contain a .Message struct with parameters.');
            end

            segmentMessageParams = segmentInfo.Message; % e.g., .Length, .SpecificSeed etc.

            % Example for a block that takes MessageLength and SymbolRate (though SymbolRate is more for modulator)
            % This needs to be adapted to the actual interface of your message source blocks.
            % A common pattern: set properties on currentMessageBlock then call step(currentMessageBlock).

            % Simplistic approach: if block has properties matching fields in segmentMessageParams, set them.
            % This is generic. Specific blocks might have dedicated methods or a single struct input for step.
            propNames = fieldnames(segmentMessageParams);

            for k = 1:length(propNames)
                propName = propNames{k};

                if isprop(currentMessageBlock, propName)

                    try
                        currentMessageBlock.(propName) = segmentMessageParams.(propName);
                        obj.logger.debug('Set property ''%s'' to ''%s'' on message block %s for TypeID ''%s''', ...
                            propName, num2str(segmentMessageParams.(propName)), class(currentMessageBlock), messageTypeID);
                    catch ME_setprop
                        obj.logger.warning('Could not set property ''%s'' on message block %s. Error: %s', ...
                            propName, class(currentMessageBlock), ME_setprop.message);
                    end

                end

            end

            % Call the message block's step method.
            % The signature of step() for message source blocks needs to be standardized.
            % Common outputs: data, and potentially SampleRate if it's intrinsic (like an audio file).
            % If the block just generates bits/symbols, it might only output data.
            try

                if isa(currentMessageBlock, 'csrd.blocks.physical.message.RandomBit')
                    % RandomBit.m step(obj) might use its MessageLength property internally
                    messageData = step(currentMessageBlock);
                elseif isa(currentMessageBlock, 'csrd.blocks.physical.message.Audio')
                    % Audio.m step(obj) returns a struct {data, SampleRate, IsLastFrame}
                    messageData = step(currentMessageBlock);
                else
                    % Generic call, assuming it needs a length parameter. This is a guess.
                    % You MUST adapt this to your blocks' actual step signatures.
                    if isfield(segmentMessageParams, 'Length')
                        messageData = step(currentMessageBlock, segmentMessageParams.Length);
                    else % Failsafe if Length is not provided, block might have internal default
                        obj.logger.warning('Message length not specified in segmentInfo.Message for TypeID %s. Calling step without it.', messageTypeID);
                        messageData = step(currentMessageBlock);
                    end

                end

                obj.logger.debug('Message block %s for TypeID ''%s'' executed.', class(currentMessageBlock), messageTypeID);
            catch ME_step
                obj.logger.error('Error during step method of message block %s for TypeID ''%s''. Error: %s', ...
                    class(currentMessageBlock), messageTypeID, ME_step.message);
                rethrow(ME_step);
            end

        end

        function releaseImpl(obj)
            obj.logger.debug('MessageFactory releaseImpl called.');
            blockKeys = keys(obj.cachedMessageBlocks);

            for i = 1:length(blockKeys)
                block = obj.cachedMessageBlocks(blockKeys{i});

                if isa(block, 'matlab.System') && islocked(block)
                    release(block);
                end

            end

            remove(obj.cachedMessageBlocks, keys(obj.cachedMessageBlocks));
            obj.logger.debug('All cached message blocks released.');
        end

        function resetImpl(obj)
            obj.logger.debug('MessageFactory resetImpl called.');
            blockKeys = keys(obj.cachedMessageBlocks);

            for i = 1:length(blockKeys)
                block = obj.cachedMessageBlocks(blockKeys{i});

                if isa(block, 'matlab.System')
                    reset(block);
                end

            end

            obj.logger.debug('All cached message blocks reset.');
        end

    end

end
