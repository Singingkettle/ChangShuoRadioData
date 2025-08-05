classdef RandomBit < matlab.System
    % RandomBit - Random Binary Message Generator
    %
    % This class implements a configurable random binary message generator
    % for digital communication system simulations. The generator produces
    % sequences of random bits (0s and 1s) with controllable probability
    % distributions, seed values for reproducibility, and flexible output
    % formatting for various communication protocols.
    %
    % Random bit generation is fundamental to communication system testing,
    % providing uncorrelated data sources for evaluating modulation schemes,
    % error correction codes, and system performance under realistic traffic
    % conditions. This implementation supports both uniform and biased bit
    % generation with comprehensive statistical control.
    %
    % Key Features:
    %   - Configurable bit probability for biased sequences
    %   - Reproducible generation with seed control
    %   - Flexible output formatting (column/row vectors)
    %   - Statistical validation and monitoring
    %   - Integration with communication system workflows
    %   - Support for burst and streaming generation modes
    %
    % Technical Specifications:
    %   - Bit Values: 0 and 1 (binary)
    %   - Probability Range: [0, 1] for P(bit = 1)
    %   - Sequence Length: Arbitrary (limited by memory)
    %   - Random Generator: MATLAB's default (mersenne twister)
    %   - Output Format: Integer array (0/1 values)
    %
    % Syntax:
    %   randomGen = RandomBit()
    %   randomGen = RandomBit('PropertyName', PropertyValue, ...)
    %   messageData = randomGen(messageLength, symbolRate)
    %
    % Properties:
    %   BitProbability - Probability of generating a '1' bit
    %                    Type: real scalar, Default: 0.5, Range: [0, 1]
    %   Seed - Random number generator seed for reproducibility
    %          Type: non-negative integer, Default: [] (auto-seed)
    %   OutputOrientation - Output vector orientation
    %                       Type: string, Default: 'column'
    %   EnableStatistics - Enable statistical monitoring
    %                      Type: logical, Default: false
    %
    % Methods:
    %   step - Generate random binary message sequence
    %   reset - Reset internal random number generator state
    %   getStatistics - Get generation statistics (if enabled)
    %
    % Example:
    %   % Create balanced random bit generator
    %   bitGen = csrd.blocks.physical.message.RandomBit();
    %   bitGen.BitProbability = 0.5; % Equal probability for 0 and 1
    %   bitGen.Seed = 12345; % Reproducible sequences
    %   bitGen.EnableStatistics = true; % Monitor generation statistics
    %
    %   % Generate random message for QPSK modulation
    %   messageLength = 2000; % 2000 bits
    %   symbolRate = 1e6; % 1 Mbps
    %   messageData = bitGen(messageLength, symbolRate);
    %
    %   fprintf('Generated %d bits\n', length(messageData.data));
    %   fprintf('Actual P(1) = %.3f\n', mean(messageData.data));
    %   fprintf('Symbol rate: %.0f bps\n', messageData.SymbolRate);
    %
    % Advanced Examples:
    %   % Biased bit generation for unequal symbol probability testing
    %   biasedGen = csrd.blocks.physical.message.RandomBit();
    %   biasedGen.BitProbability = 0.3; % 30% probability for '1'
    %   biasedData = biasedGen(10000, 1e6);
    %
    %   % Statistical analysis
    %   actualBias = mean(biasedData.data);
    %   fprintf('Configured P(1): %.1f, Actual P(1): %.3f\n', ...
    %           biasedGen.BitProbability, actualBias);
    %
    % Applications:
    %   - Digital modulation scheme testing and validation
    %   - Bit error rate (BER) performance analysis
    %   - Channel coding algorithm evaluation
    %   - System capacity and throughput measurements
    %   - Protocol stack testing with random payloads
    %   - Monte Carlo simulation data sources
    %   - Educational demonstrations of digital systems
    %
    % Statistical Properties:
    %   For large sequences (N >> 100), the generated bits approach:
    %   - Mean: BitProbability
    %   - Variance: BitProbability × (1 - BitProbability)
    %   - Standard deviation: √(BitProbability × (1 - BitProbability))
    %
    % Performance Considerations:
    %   - Memory usage: O(messageLength) for storage
    %   - Generation time: O(messageLength) linear complexity
    %   - Suitable for sequences up to 10^6-10^7 bits in typical systems
    %
    % See also: randi, rand, RandStream, csrd.blocks.physical.message.Audio

    properties
        % BitProbability - Probability of generating a '1' bit
        % Type: real scalar, Default: 0.5, Range: [0, 1]
        %
        % This property controls the statistical bias of the generated
        % bit sequence. A value of 0.5 produces unbiased (balanced) bits,
        % while other values create biased sequences useful for testing
        % system robustness under non-uniform data conditions.
        %
        % Configuration Guidelines:
        %   - 0.5: Balanced bits (maximum entropy, typical use case)
        %   - 0.0: All zeros (extreme case, minimum entropy)
        %   - 1.0: All ones (extreme case, minimum entropy)
        %   - 0.1-0.9: Biased sequences for robustness testing
        %
        % Statistical Impact:
        %   - Mean of sequence ≈ BitProbability (for large N)
        %   - Affects spectral properties of generated data
        %   - Influences modulation constellation usage patterns
        BitProbability (1, 1) {mustBeInRange(BitProbability, 0, 1)} = 0.5

        % Seed - Random number generator seed for reproducibility
        % Type: non-negative integer or empty, Default: []
        %
        % This property controls the random number generator seed for
        % reproducible bit sequence generation. When empty, MATLAB's
        % default random state is used, providing different sequences
        % each time the generator is used.
        %
        % Seed Selection:
        %   - [] (empty): Auto-seeding, different each run
        %   - Integer: Fixed seed, reproducible sequences
        %   - Use same seed for identical sequences across runs
        %   - Use different seeds for independent sequences
        %
        % Reproducibility Benefits:
        %   - Debugging and validation of algorithms
        %   - Consistent results in publications and reports
        %   - Comparative analysis with controlled data
        Seed (:, :) {mustBeInteger, mustBeNonnegative} = []

        % OutputOrientation - Output vector orientation
        % Type: string, Default: 'column'
        %
        % This property determines whether the generated bit sequence
        % is returned as a column vector or row vector, providing
        % flexibility for different system interfaces.
        %
        % Available Options:
        %   'column' - Column vector [N×1] (typical for signal processing)
        %   'row'    - Row vector [1×N] (typical for data analysis)
        %
        % Integration Notes:
        %   Most communication system blocks expect column vectors,
        %   making 'column' the recommended default setting.
        OutputOrientation {mustBeMember(OutputOrientation, {'column', 'row'})} = 'column'

        % EnableStatistics - Enable statistical monitoring
        % Type: logical, Default: false
        %
        % This property enables internal tracking of generation statistics
        % such as actual bit probabilities, sequence length history, and
        % cumulative generation counts for analysis and verification.
        %
        % When enabled, statistics can be retrieved using getStatistics()
        % method. Disabling improves performance for high-throughput
        % applications where monitoring is not required.
        %
        % Tracked Statistics:
        %   - Total bits generated
        %   - Actual bit probability (running average)
        %   - Generation call count
        %   - Sequence length statistics
        EnableStatistics (1, 1) logical = false
    end

    properties (Access = private)
        % pRandomStream - Internal random number stream
        pRandomStream

        % pStatistics - Internal statistics tracking
        pStatistics
    end

    methods

        function obj = RandomBit(varargin)
            % RandomBit - Constructor for random binary message generator
            %
            % This constructor creates a RandomBit object with optional
            % property-value pairs for initial configuration.
            %
            % Syntax:
            %   obj = RandomBit()
            %   obj = RandomBit('PropertyName', PropertyValue, ...)
            %
            % Input Arguments (Name-Value Pairs):
            %   'BitProbability' - Probability of '1' bits (default: 0.5)
            %   'Seed' - Random generator seed (default: [])
            %   'OutputOrientation' - 'column' or 'row' (default: 'column')
            %   'EnableStatistics' - Statistical monitoring (default: false)
            %
            % Example:
            %   % Create biased generator with statistics
            %   gen = RandomBit('BitProbability', 0.3, ...
            %                   'EnableStatistics', true, ...
            %                   'Seed', 42);

            % Set properties from name-value pairs
            setProperties(obj, nargin, varargin{:});

        end

        function statistics = getStatistics(obj)
            % getStatistics - Get generation statistics
            %
            % This method returns statistical information about the bit
            % generation process when EnableStatistics is true.
            %
            % Syntax:
            %   statistics = getStatistics(obj)
            %
            % Output Arguments:
            %   statistics - Structure with fields:
            %     .TotalBitsGenerated - Total number of bits generated
            %     .ActualBitProbability - Observed probability of '1' bits
            %     .GenerationCount - Number of generation calls
            %     .AverageSequenceLength - Average sequence length
            %     .ConfiguredProbability - Target bit probability
            %
            % Example:
            %   gen = RandomBit('EnableStatistics', true);
            %   data1 = gen(1000, 1e6);
            %   data2 = gen(2000, 1e6);
            %   stats = gen.getStatistics();
            %   fprintf('Generated %d total bits\n', stats.TotalBitsGenerated);

            if ~obj.EnableStatistics
                warning('ChangShuoRadioData:RandomBit:StatisticsDisabled', ...
                'Statistics are disabled. Enable with EnableStatistics = true.');
                statistics = struct();
                return;
            end

            % Return current statistics
            if isempty(obj.pStatistics)
                statistics = struct( ...
                    'TotalBitsGenerated', 0, ...
                    'ActualBitProbability', NaN, ...
                    'GenerationCount', 0, ...
                    'AverageSequenceLength', NaN, ...
                    'ConfiguredProbability', obj.BitProbability);
            else
                statistics = obj.pStatistics;
                statistics.ConfiguredProbability = obj.BitProbability;
            end

        end

    end

    methods (Access = protected)

        function setupImpl(obj)
            % setupImpl - Initialize the random bit generator
            %
            % This method sets up the random number generator with the
            % specified seed and initializes statistics tracking.

            % Initialize random stream
            if isempty(obj.Seed)
                % Use default random stream
                obj.pRandomStream = [];
            else
                % Create seeded random stream
                obj.pRandomStream = RandStream('mt19937ar', 'Seed', obj.Seed);
            end

            % Initialize statistics if enabled
            if obj.EnableStatistics
                obj.pStatistics = struct( ...
                    'TotalBitsGenerated', 0, ...
                    'ActualBitProbability', 0, ...
                    'GenerationCount', 0, ...
                    'AverageSequenceLength', 0, ...
                    'CumulativeOnes', 0);
            end

        end

        function messageOutput = stepImpl(obj, messageLength, symbolRate)
            % stepImpl - Generate random binary message sequence
            %
            % This method generates a random binary sequence with the
            % specified length and symbol rate, applying the configured
            % bit probability and updating statistics if enabled.
            %
            % Syntax:
            %   messageOutput = stepImpl(obj, messageLength, symbolRate)
            %
            % Input Arguments:
            %   messageLength - Number of bits to generate
            %                   Type: positive integer
            %   symbolRate - Symbol rate for the message in symbols/second
            %                Type: positive scalar
            %
            % Output Arguments:
            %   messageOutput - Structure containing:
            %     .data - Random binary sequence [messageLength × 1] or [1 × messageLength]
            %     .SymbolRate - Symbol rate (copied from input)
            %     .messageLength - Actual length of generated sequence
            %     .BitProbability - Applied bit probability
            %     .GenerationTimestamp - Time when sequence was generated
            %
            % Generation Process:
            %   1. Validate input parameters
            %   2. Generate random sequence with specified probability
            %   3. Apply output orientation formatting
            %   4. Update statistics if enabled
            %   5. Package output structure

            % Validate input arguments
            if ~isscalar(messageLength) || messageLength <= 0 || mod(messageLength, 1) ~= 0
                error('ChangShuoRadioData:RandomBit:InvalidMessageLength', ...
                'messageLength must be a positive integer scalar.');
            end

            if ~isscalar(symbolRate) || symbolRate <= 0
                error('ChangShuoRadioData:RandomBit:InvalidSymbolRate', ...
                'symbolRate must be a positive scalar.');
            end

            % Generate random binary sequence based on bit probability
            if isempty(obj.pRandomStream)
                % Use default random stream
                randomValues = rand(messageLength, 1);
            else
                % Use seeded random stream
                randomValues = rand(obj.pRandomStream, messageLength, 1);
            end

            % Convert to binary based on probability threshold
            binarySequence = randomValues < obj.BitProbability;
            generatedBits = double(binarySequence); % Convert logical to double (0/1)

            % Apply output orientation
            if strcmp(obj.OutputOrientation, 'row')
                generatedBits = generatedBits.';
            end

            % Update statistics if enabled
            if obj.EnableStatistics
                obj.updateStatistics(generatedBits, messageLength);
            end

            % Create comprehensive output structure
            messageOutput = struct();
            messageOutput.data = generatedBits;
            messageOutput.SymbolRate = symbolRate;
            messageOutput.messageLength = messageLength;
            messageOutput.BitProbability = obj.BitProbability;
            messageOutput.GenerationTimestamp = datetime('now');

        end

        function resetImpl(obj)
            % resetImpl - Reset the random bit generator state
            %
            % This method resets the internal random number generator and
            % statistics to their initial states.

            % Reset random stream
            if ~isempty(obj.pRandomStream)
                reset(obj.pRandomStream);
            end

            % Reset statistics
            if obj.EnableStatistics && ~isempty(obj.pStatistics)
                obj.pStatistics.TotalBitsGenerated = 0;
                obj.pStatistics.ActualBitProbability = 0;
                obj.pStatistics.GenerationCount = 0;
                obj.pStatistics.AverageSequenceLength = 0;
                obj.pStatistics.CumulativeOnes = 0;
            end

        end

    end

    methods (Access = private)

        function updateStatistics(obj, generatedBits, messageLength)
            % updateStatistics - Update internal generation statistics
            %
            % This private method updates running statistics about the
            % bit generation process for monitoring and analysis.

            % Count ones in current sequence
            currentOnes = sum(generatedBits(:));

            % Update cumulative counters
            obj.pStatistics.TotalBitsGenerated = obj.pStatistics.TotalBitsGenerated + messageLength;
            obj.pStatistics.CumulativeOnes = obj.pStatistics.CumulativeOnes + currentOnes;
            obj.pStatistics.GenerationCount = obj.pStatistics.GenerationCount + 1;

            % Calculate running averages
            obj.pStatistics.ActualBitProbability = ...
                obj.pStatistics.CumulativeOnes / obj.pStatistics.TotalBitsGenerated;

            obj.pStatistics.AverageSequenceLength = ...
                obj.pStatistics.TotalBitsGenerated / obj.pStatistics.GenerationCount;

        end

    end

end
