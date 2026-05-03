% DSBAM is a class that extends DSBSCAM. It represents a Double Sideband Amplitude Modulator.
% 中文说明：提供 CSRD 生产链路中的 DSBAM 实现。
classdef DSBAM < csrd.blocks.physical.modulate.analog.AM.DSBSCAM
    % DSBAM - Double Sideband Amplitude Modulation Modulator
    % 中文职责：实现带载波双边带调幅，用于 AM 广播等模拟业务的基带包络生成。
    %
    % This class implements conventional Double Sideband Amplitude Modulation (DSB-AM)
    % as a subclass of DSBSCAM. DSB-AM is the classic amplitude modulation scheme that
    % transmits both sidebands along with the carrier component. This modulation
    % technique is widely used in AM broadcasting and represents the foundation of
    % amplitude modulation systems.
    %
    % DSB-AM provides simple demodulation through envelope detection but is less
    % power-efficient compared to suppressed carrier systems because a significant
    % portion of transmitted power is allocated to the carrier. The carrier component
    % facilitates simple receiver design but reduces overall system efficiency.
    %
    % Key Features:
    %   - Classic analog modulation with carrier transmission
    %   - Simple envelope detection at the receiver
    %   - Both upper and lower sidebands transmitted
    %   - Compatible with standard AM broadcast receivers
    %   - Bandwidth efficiency: 50% (same information in both sidebands)
    %   - Power efficiency: Variable (depends on modulation index)
    %
    % Syntax:
    %   dsbamModulator = DSBAM()
    %   dsbamModulator = DSBAM('PropertyName', PropertyValue, ...)
    %   modulatedSignal = dsbamModulator.step(inputData)
    %
    % Properties (Inherited from DSBSCAM):
    % 属性（继承自 DSBSCAM）：
    %   ModulatorConfig - Configuration structure for DSB-AM parameters
    %   ModulatorConfig - DSB-AM 参数配置结构体
    %     .carramp - Carrier amplitude coefficient
    %     .carramp - 载波幅度系数
    %     .initPhase - Initial carrier phase in radians
    %     .initPhase - 初始载波相位，单位为弧度
    %
    % Methods:
    % 方法：
    %   baseModulator - Core DSB-AM modulation implementation
    %   baseModulator - 执行 DSB-AM 核心调制并返回带宽
    %   genModulatorHandle - Generate configured modulator function handle
    %   genModulatorHandle - 生成配置完成的调制函数句柄
    %
    % Signal Equation:
    %   s(t) = A_c[1 + m(t)]cos(ω_c*t + φ)
    %   where A_c is carrier amplitude, m(t) is normalized message signal,
    %   ω_c is carrier frequency, and φ is initial phase
    %
    % Bandwidth Characteristics:
    %   B_DSB-AM = 2 * B_message
    %   where B_message is the highest frequency component of the message signal
    %
    % Example:
    %   % Create DSB-AM modulator for AM broadcast simulation
    %   dsbamMod = csrd.blocks.physical.modulate.analog.AM.DSBAM();
    %   dsbamMod.SampleRate = 48000; % Audio sampling rate
    %
    %   % Configure carrier amplitude for 100% modulation depth
    %   dsbamMod.ModulatorConfig.carramp = 1.0; % Unity carrier amplitude
    %   dsbamMod.ModulatorConfig.initPhase = 0;  % Zero initial phase
    %
    %   % Create normalized audio message signal
    %   t = (0:999)' / dsbamMod.SampleRate;
    %   messageSignal = 0.5 * sin(2*pi*1000*t); % 50% modulation depth
    %
    %   % Modulate the signal
    %   modulatedSignal = dsbamMod.step(messageSignal);
    %
    % References / 参考资料:
    %   - MathWorks obw occupied bandwidth documentation:
    %     https://www.mathworks.com/help/signal/ref/obw.html
    %
    % See also: csrd.blocks.physical.modulate.analog.AM.DSBSCAM,
    %           csrd.blocks.physical.modulate.analog.AM.SSBAM,
    %           csrd.blocks.physical.modulate.BaseModulator

    methods (Access = protected)

        function [modulatedSignal, bandWidth] = baseModulator(obj, messageSignal)
            % baseModulator - Core DSB-AM modulation implementation
            % 中文职责：将消息信号叠加载波幅度形成 DSB-AM 包络，并测量双边带占用带宽。
            %
            % This method implements conventional DSB-AM modulation by adding the
            % carrier component to the message signal. The resulting signal contains
            % both sidebands and the carrier, enabling simple envelope detection
            % at the receiver.
            %
            % Syntax:
            %   [modulatedSignal, bandWidth] = baseModulator(obj, messageSignal)
            %
            % Input Arguments:
            % 输入参数：
            %   messageSignal - Input message signal to be modulated
            %   messageSignal - 待调制的消息信号，通常应归一化以避免过调制
            %                   Type: real-valued numeric array
            %                   Range: Typically normalized to [-1, 1] for proper modulation
            %
            % Output Arguments:
            % 输出参数：
            %   modulatedSignal - DSB-AM modulated signal
            %   modulatedSignal - DSB-AM 基带包络信号，后续链路会进行载波搬移
            %                     Type: real-valued numeric array
            %   bandWidth - Total bandwidth of the modulated signal in Hz
            %   bandWidth - 调制后信号总占用带宽，单位 Hz
            %               Type: positive scalar
            %
            % Processing Steps:
            %   1. Add carrier amplitude to normalized message signal
            %   2. Calculate bandwidth as twice the message signal bandwidth
            %   3. Return modulated signal ready for carrier multiplication
            %
            % Modulation Equation:
            %   s_baseband(t) = A_c[1 + m(t)]
            %   where A_c is carrier amplitude and m(t) is message signal
            %   Final RF signal: s_RF(t) = s_baseband(t) * cos(ω_c*t + φ)
            %
            % Bandwidth Calculation:
            %   DSB-AM bandwidth equals twice the message bandwidth because
            %   both upper and lower sidebands are transmitted with identical
            %   information content.
            %
            % Modulation Depth Considerations:
            %   For proper envelope detection, ensure |m(t)| ≤ 1 to prevent
            %   overmodulation and signal distortion.
            %
            % Example:
            %   messageSignal = 0.8 * sin(2*pi*1000*(0:999)'/48000); % 80% depth
            %   [signal, bw] = obj.baseModulator(messageSignal);

            % Retrieve carrier amplitude configuration.
            % 读取载波幅度配置，它决定包络中的直流载波分量。
            carrierAmplitude = obj.ModulatorConfig.carramp;

            % Apply DSB-AM modulation: add carrier to message signal.
            % 对消息信号叠加载波幅度，形成 s(t)=Ac+m(t) 形式的包络。
            modulatedSignal = messageSignal + carrierAmplitude;

            % Calculate DSB-AM bandwidth as twice the measured message bandwidth.
            % DSB-AM 同时保留上下边带，因此总带宽按消息带宽的两倍记录。
            messageBandwidth = obw(messageSignal, obj.SampleRate);
            bandWidth = 2 * messageBandwidth;

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % genModulatorHandle - Generate configured DSB-AM modulator function handle
            % 中文职责：补齐 DSB-AM 默认调制参数，并返回供 BaseModulator 调用的函数句柄。
            %
            % This method configures the DSB-AM modulator with default parameters if not
            % specified and returns a function handle for the complete modulation process.
            % DSB-AM modulation is inherently analog and single-antenna.
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Output Arguments:
            % 输出参数：
            %   modulatorHandle - Function handle for DSB-AM modulation
            %   modulatorHandle - DSB-AM 调制函数句柄，输入消息信号并输出信号与带宽
            %                     Type: function_handle
            %                     Usage: [signal, bw] = modulatorHandle(message)
            %
            % Configuration Parameters:
            %   The method automatically configures missing parameters:
            %   - carramp: Carrier amplitude coefficient
            %   - initPhase: Initial carrier phase (typically 0)
            %
            % Default Configuration:
            %   - carramp: Random value between 1.0 and 1.5 (unity to 150% carrier)
            %   - initPhase: 0 radians (no initial phase offset)
            %   - IsDigital: false (analog modulation)
            %   - NumTransmitAntennas: 1 (single antenna)
            %
            % Carrier Amplitude Guidelines:
            %   - carramp = 1.0: Standard 100% modulation capability
            %   - carramp > 1.0: Higher carrier level, more power but better SNR
            %   - carramp < 1.0: Lower carrier level, risk of overmodulation
            %
            % Power Efficiency Considerations:
            %   DSB-AM efficiency = m²/(2+m²) where m is modulation index
            %   Maximum theoretical efficiency is 33.3% at 100% modulation
            %
            % Example:
            %   dsbamMod = csrd.blocks.physical.modulate.analog.AM.DSBAM();
            %   modHandle = dsbamMod.genModulatorHandle();
            %   [modSignal, bandwidth] = modHandle(audioData);

            % Set modulation type flags.
            % 标记为模拟调制并约束为单天线，避免后续数字/MIMO 分支误用。
            obj.IsDigital = false; % DSB-AM is analog modulation
            obj.NumTransmitAntennas = 1; % Single antenna transmission

            % Configure DSB-AM parameters if not provided.
            % 若蓝图未指定参数，则生成实际可用的 AM 载波幅度与初始相位。
            if ~isfield(obj.ModulatorConfig, 'carramp')
                % Set carrier amplitude between 1.0 and 1.5 for practical applications
                % 载波幅度取 1.0 到 1.5，为消息摆幅保留包络检测余量。
                % This range provides good modulation headroom while maintaining efficiency
                obj.ModulatorConfig.carramp = 1 + rand(1) * 0.5;

                % Set initial phase to zero (standard configuration)
                % 初始相位固定为零，避免引入额外随机相位影响复现链路。
                obj.ModulatorConfig.initPhase = 0;
            end

            % Create function handle for modulation.
            % 生成统一调制入口，供 BaseModulator.stepImpl 调用。
            modulatorHandle = @(messageSignal)obj.baseModulator(messageSignal);

        end

    end

end
