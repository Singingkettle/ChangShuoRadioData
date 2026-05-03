classdef BaseModulator < matlab.System
    % BaseModulator - Base class for modulators in the ChangShuoRadioData project
    % 中文职责：统一模拟/数字调制器的 System object 生命周期、输出契约和多天线编码入口。
    %
    % Description:
    % 中文说明：
    %   This class implements the base functionality for all modulator types,
    %   supporting both digital and analog modulation schemes with MIMO capabilities.
    %   本类承接消息比特/模拟消息到 IQ 信号的公共处理，保证调制输出字段、带宽、
    %   采样率、持续时间和天线数量在后续发射、信道、标注链路中保持一致。
    %
    % Usage:
    %   This is an abstract base class. Create a concrete subclass by implementing
    %   the genModulatorHandle method.
    %
    % Example:
    %   % Create a custom modulator
    %   myMod = MyModulator('ModulatorOrder', 4, 'SampleRate', 1e6);
    %   output = myMod.step(input);
    %
    % Properties:
    %   ModulatorOrder       - Modulation order (e.g., 2 for BPSK, 4 for QPSK)
    %   SampleRate          - Sampling rate in Hz
    %   ModulatorConfig     - Configuration struct for modulator-specific settings
    %   NumTransmitAntennas - Number of transmit antennas (1-4)
    %   SamplePerSymbol     - Samples per symbol (for digital modulation)
    %
    % Protected Properties:
    %   modulator  - Handle to the modulation function
    %   IsDigital - Flag indicating digital/analog modulation type
    %
    % References / 参考资料:
    %   - MathWorks matlab.System documentation:
    %     https://www.mathworks.com/help/matlab/ref/matlab.system-class.html
    %   - MathWorks comm.OSTBCEncoder documentation:
    %     https://www.mathworks.com/help/comm/ref/comm.ostbcencoder-system-object.html
    %
    % See also: matlab.System, comm.OSTBCEncoder

    properties
        % ModulatorOrder - Modulation order (e.g., 2 for BPSK, 4 for QPSK)
        % Type: positive real number, Default: 1
        ModulatorOrder {mustBePositive, mustBeReal} = 1

        % SampleRate - Sampling rate in Hz
        % Type: positive real scalar, Default: 200e3
        SampleRate (1, 1) {mustBePositive, mustBeReal} = 200e3

        % ModulatorConfig - Configuration struct for modulator-specific settings
        % Type: struct, Default: empty struct
        ModulatorConfig struct = struct()

        % NumTransmitAntennas - Number of transmit antennas
        % Type: positive integer in range [1,4], Default: 1
        NumTransmitAntennas (1, 1) {mustBePositive, mustBeInteger, mustBeMember(NumTransmitAntennas, [1, 2, 3, 4])} = 1

        % SamplePerSymbol - Samples per symbol (for digital modulation)
        % For analog modulation, this is just a placeholder
        % Type: positive real scalar, Default: 1
        SamplePerSymbol (1, 1) {mustBePositive, mustBeReal} = 1
    end

    properties (Access = protected)
        % modulator - Handle to the modulation function
        modulator

        % IsDigital - Flag indicating digital/analog modulation type
        % Type: logical, Default: true
        IsDigital = true
    end

    methods

        function obj = BaseModulator(varargin)
            % BaseModulator - Constructor method for the BaseModulator class
            % 中文职责：应用名称-值参数并初始化基础调制器对象。
            %
            % Inputs:
            % 输入：
            %   varargin - Name-value pairs for object properties
            %   varargin - 对象属性的名称-值参数
            %
            % Returns:
            % 输出：
            %   obj - Initialized BaseModulator object
            %   obj - 初始化后的 BaseModulator 对象

            setProperties(obj, nargin, varargin{:});
        end

        function ostbc = genOSTBC(obj)
            % genOSTBC - Generate Orthogonal Space-Time Block Coding encoder
            % 中文职责：根据发射天线数量生成 OSTBC 编码器或单天线直通占位函数。
            %
            % Returns:
            % 输出：
            %   ostbc - Function handle to OSTBC encoder
            %   ostbc - OSTBC 编码函数句柄；单天线时为直通函数

            if obj.NumTransmitAntennas > 1

                if obj.NumTransmitAntennas == 2
                    ostbc = comm.OSTBCEncoder( ...
                        NumTransmitAntennas = obj.NumTransmitAntennas);
                else
                    ostbc = comm.OSTBCEncoder( ...
                        NumTransmitAntennas = obj.NumTransmitAntennas, ...
                        SymbolRate = obj.ModulatorConfig.ostbcSymbolRate);
                end

                ostbc = @(x)genOSTBCWithX(ostbc, x);
            else
                ostbc = @(x)obj.placeHolder(x);
            end

        end

        function y = placeHolder(obj, x)
            % placeHolder - A placeholder method for single antenna systems
            % 中文职责：为单天线链路提供无变换直通函数，保持接口与 OSTBC 分支一致。
            %
            % Inputs:
            % 输入：
            %   x - Input data
            %   x - 输入数据
            %
            % Returns:
            % 输出：
            %   y - Same as input (no transformation)
            %   y - 与输入相同的数据

            y = x;
        end

    end

    methods (Abstract)
        % genModulatorHandle - Abstract method to generate the modulate handle
        % 中文职责：由具体调制器实现，返回实际的调制函数句柄。
        %
        % Returns:
        % 输出：
        %   modulatorHandle - Function handle for modulation operation
        %   modulatorHandle - 执行具体调制的函数句柄

        modulatorHandle = genModulatorHandle(obj)

    end

    methods (Access = protected)

        function validateInputsImpl(~, x)
            % validateInputsImpl - Validates the inputs to the object
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            % 中文职责：验证调制入口输入结构体，提前拒绝不符合契约的数据。
            %
            % Inputs:
            % 输入：
            %   x - Input to validate, must be a struct
            %   x - 待验证输入，必须为结构体

            if ~isstruct(x)
                error("Input must be struct");
            end

        end

        function setupImpl(obj)
            % setupImpl - Performs setup operations for the object
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            % 中文职责：配置 OSTBC 符号率并缓存具体调制器函数句柄。
            %
            % Sets up OSTBC symbol rate and initializes the modulator handle
            % 设置多天线编码所需符号率，并初始化后续 stepImpl 调用的调制函数。

            if obj.NumTransmitAntennas > 2

                if ~isfield(obj.ModulatorConfig, 'ostbcSymbolRate')
                    obj.ModulatorConfig.ostbcSymbolRate = randi([0, 1]) * 0.25 + 0.5;
                end

            else
                obj.ModulatorConfig.ostbcSymbolRate = 1;
            end

            obj.modulator = obj.genModulatorHandle;
        end

        function out = stepImpl(obj, x)
            % stepImpl - Main modulation processing step
            % 中文职责：把消息数据转换为调制 IQ 信号，并输出带宽、采样率和天线等执行事实。
            %
            % Inputs:
            % 输入：
            %   x - Struct containing:
            %   x - 输入结构体，包含：
            %     - data: Input data to be modulated (bit array)
            %     - data: 待调制数据，比特数组或模拟消息数组
            %     - SymbolRate: Symbol rate (optional)
            %     - SymbolRate: 符号率，可选
            %     - messageLength: Length of message (optional)
            %     - messageLength: 消息长度，可选
            %
            % Returns:
            % 输出：
            %   out - Struct containing:
            %   out - 调制输出结构体，包含：
            %     - Signal: Modulated IQ signal
            %     - Signal: 调制后的 IQ 信号
            %     - Bandwidth: Signal bandwidth [min max] in Hz
            %     - Bandwidth: 信号带宽范围 [min max]，单位 Hz
            %     - SamplePerSymbol: Samples per symbol
            %     - SamplePerSymbol: 每符号采样点数
            %     - ModulatorOrder: Modulation order
            %     - ModulatorOrder: 调制阶数
            %     - IsDigital: Digital/analog flag
            %     - IsDigital: 数字/模拟调制标志
            %     - NumTransmitAntennas: Number of TX antennas
            %     - NumTransmitAntennas: 发射天线数量
            %     - ModulatorConfig: Configuration parameters
            %     - ModulatorConfig: 调制参数配置
            %     - SampleRate: Sample rate (Hz)
            %     - SampleRate: 采样率，单位 Hz
            %     - TimeDuration: Signal duration (s)
            %     - TimeDuration: 信号持续时间，单位秒
            %     - SamplePerFrame: Total samples in frame
            %     - SamplePerFrame: 当前帧总采样点数

            if sum(obj.ModulatorOrder) ~= 1
                n = log2(sum(obj.ModulatorOrder)); % Number of bits per symbol
            else
                n = 1;
            end

            % Ensure the length of the data is a multiple of n bits.
            % 确保输入比特数能整除每符号比特数，避免 bit2int 在尾部产生错位。
            dataLength = size(x.data, 1);
            remainder = mod(dataLength, n);

            if remainder ~= 0
                x.data = x.data(1:end - remainder, :); % Discard the final bits
            end

            % When the modulator is multi-carrier, enforce its minimum payload.
            % 多载波调制需要满足子载波/时延网格的最小载荷长度，否则补齐并打乱输入。
            if isfield(obj.ModulatorConfig, 'base')

                if isfield(obj.ModulatorConfig, 'ofdm')
                    min_num_bits = obj.NumDataSubcarriers * n * 2;
                elseif isfield(obj.ModulatorConfig, 'scfdma')
                    min_num_bits = obj.ModulatorConfig.scfdma.NumDataSubcarriers * n * 2;
                elseif isfield(obj.ModulatorConfig, 'otfs')
                    min_num_bits = obj.ModulatorConfig.otfs.DelayLength * n * 2;
                else
                    min_num_bits = 0;
                end

                if length(x.data) < min_num_bits
                    % Repeat and truncate input data to the required length.
                    % 重复并截断输入数据，使长度达到当前多载波调制所需最小值。
                    repeated_data = repmat(x.data, ceil(min_num_bits / length(x.data)), 1);
                    x.data = repeated_data(1:min_num_bits, :);
                    % Random permutation by row.
                    % 按行随机打乱，避免重复补齐数据形成强周期伪迹。
                    x.data = x.data(randperm(size(x.data, 1)), :);
                end

            end

            % Convert bits to integer symbols before discrete modulation.
            % 数字调制前把比特组转换为整数符号索引。
            if obj.ModulatorOrder > 1
                x.data = bit2int(x.data, n);
            end

            [y, bw] = obj.modulator(x.data);

            if isscalar(bw)
                bw = [-bw / 2, bw / 2];
            end

            if ~isfield(obj.ModulatorConfig, 'base')
                bw(1) = fix(bw(1));
                bw(2) = fix(bw(2));
            end

            out.Signal = y;
            out.Bandwidth = bw;

            if isfield(obj.ModulatorConfig, 'base')
                out.SamplePerSymbol = 1;
            else
                out.SamplePerSymbol = obj.SamplePerSymbol;
            end

            out.ModulatorOrder = obj.ModulatorOrder;
            out.IsDigital = obj.IsDigital;
            out.NumTransmitAntennas = obj.NumTransmitAntennas;
            out.ModulatorConfig = obj.ModulatorConfig;

            % The obj.SampleRate may be redefined by OFDM, SC-FDMA and OTFS.
            % OFDM、SC-FDMA 和 OTFS 可能会重定义采样率，这里写入最终执行值。
            out.SampleRate = obj.SampleRate;
            out.TimeDuration = size(y, 1) / obj.SampleRate;
            out.SamplePerFrame = size(y, 1);

        end

    end

end

function y = genOSTBCWithX(ostbc, x)
    % genOSTBCWithX - Apply OSTBC encoding to input data
    % 中文职责：按 OSTBC 有效符号率截断输入并执行空时分组编码。
    %
    % Inputs:
    % 输入：
    %   ostbc - OSTBC encoder object with properties:
    %   ostbc - OSTBC 编码器对象，包含：
    %     - SymbolRate: Rate of the OSTBC encoder (fraction)
    %     - SymbolRate: OSTBC 编码符号率
    %   x - Input data matrix to be encoded
    %   x - 待编码输入矩阵
    %
    % Returns:
    % 输出：
    %   y - OSTBC encoded data matrix
    %   y - OSTBC 编码后的数据矩阵

    rr = floor(ostbc.SymbolRate * 8);
    valid_len = floor(size(x, 1) / rr);
    valid_len = valid_len * rr;
    y = ostbc(x(1:valid_len, :));

end
