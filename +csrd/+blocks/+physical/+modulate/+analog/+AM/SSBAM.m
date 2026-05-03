classdef SSBAM < csrd.blocks.physical.modulate.analog.AM.DSBSCAM
    % SSBAM - Single Sideband Amplitude Modulation Modulator
    % 中文职责：实现单边带调幅，生成只保留 USB 或 LSB 的高频谱效率模拟基带信号。
    %
    % This class implements Single Sideband Amplitude Modulation (SSB-AM) as a
    % subclass of DSBSCAM. SSB-AM is an efficient form of amplitude modulation
    % that transmits only one sideband (upper or lower) while suppressing both
    % the carrier and the other sideband. This approach provides optimal
    % bandwidth efficiency by utilizing only half the bandwidth of conventional
    % double sideband AM systems.
    %
    % SSB-AM is widely used in amateur radio, military communications, and
    % point-to-point links where spectrum efficiency is critical. The technique
    % achieves maximum bandwidth efficiency but requires more complex modulation
    % and demodulation processes compared to conventional AM systems.
    %
    % Key Features:
    %   - Maximum bandwidth efficiency (bandwidth = message bandwidth)
    %   - Upper Sideband (USB) and Lower Sideband (LSB) operation modes
    %   - Hilbert transform-based sideband generation
    %   - Carrier and unwanted sideband suppression
    %   - Power efficient transmission (no carrier power waste)
    %   - Complex envelope generation for frequency translation
    %
    % Technical Specifications:
    %   - Bandwidth Efficiency: 100% (optimal for analog modulation)
    %   - Sideband Selection: Upper or Lower via Hilbert transform
    %   - Carrier Suppression: Complete (no carrier transmitted)
    %   - Spectral Occupancy: Equal to message signal bandwidth
    %   - Implementation: Complex envelope with quadrature components
    %
    % Syntax:
    %   ssbamModulator = SSBAM()
    %   ssbamModulator = SSBAM('PropertyName', PropertyValue, ...)
    %   modulatedSignal = ssbamModulator.step(inputData)
    %
    % Properties (Inherited from DSBSCAM):
    % 属性（继承自 DSBSCAM）：
    %   SampleRate - Sampling rate in Hz for signal processing
    %   SampleRate - 信号处理采样率，单位 Hz
    %   NumTransmitAntennas - Number of transmit antennas (fixed at 1)
    %   NumTransmitAntennas - 发射天线数量，SSB-AM 固定为 1
    %   ModulatorConfig - Configuration structure for SSB-AM parameters
    %   ModulatorConfig - SSB-AM 参数配置结构体
    %     .mode - Sideband selection ('upper' for USB, 'lower' for LSB)
    %     .mode - 边带选择，'upper' 表示上边带，'lower' 表示下边带
    %
    % Methods:
    %   baseModulator - Core SSB-AM modulation implementation
    %   genModulatorHandle - Generate configured modulator function handle
    %
    % Signal Generation Process:
    %   1. Generate analytic signal using Hilbert transform
    %   2. Select desired sideband through complex envelope manipulation
    %   3. Suppress carrier and unwanted sideband components
    %   4. Output complex baseband signal for frequency translation
    %
    % Bandwidth Characteristics:
    %   - USB Mode: Bandwidth = [0, B_message]
    %   - LSB Mode: Bandwidth = [-B_message, 0]
    %   - Total Bandwidth = B_message (optimal efficiency)
    %
    % Example:
    %   % Create SSB-AM modulator for amateur radio communication
    %   ssbamMod = csrd.blocks.physical.modulate.analog.AM.SSBAM();
    %   ssbamMod.SampleRate = 48000; % Audio sampling rate
    %
    %   % Configure for Upper Sideband operation
    %   ssbamMod.ModulatorConfig.mode = 'upper';
    %
    %   % Create audio message signal (voice bandwidth ~3 kHz)
    %   t = (0:2399)' / ssbamMod.SampleRate; % 50 ms audio segment
    %   messageSignal = sin(2*pi*1000*t) + 0.5*sin(2*pi*2000*t); % Multi-tone
    %
    %   % Modulate the signal
    %   modulatedSignal = ssbamMod.step(messageSignal);
    %
    % Applications:
    %   - Amateur radio voice communications
    %   - Military and tactical communications
    %   - Point-to-point microwave links
    %   - Satellite communication uplinks
    %   - High-frequency (HF) radio systems
    %
    % Performance Advantages:
    %   - 50% bandwidth reduction compared to DSB-AM
    %   - No power wasted in carrier transmission
    %   - Improved spectral efficiency in crowded bands
    %   - Better performance in fading channels
    %
    % Implementation Considerations:
    %   - Requires precise frequency and phase synchronization
    %   - More complex receiver design compared to envelope detection
    %   - Sensitive to frequency offset and phase noise
    %   - Hilbert transform introduces processing delay
    %
    % References / 参考资料:
    %   - MathWorks hilbert analytic signal documentation:
    %     https://www.mathworks.com/help/signal/ref/hilbert.html
    %   - MathWorks obw occupied bandwidth documentation:
    %     https://www.mathworks.com/help/signal/ref/obw.html
    %
    % See also: csrd.blocks.physical.modulate.analog.AM.DSBSCAM,
    %           csrd.blocks.physical.modulate.analog.AM.DSBAM,
    %           csrd.blocks.physical.modulate.analog.AM.VSBAM,
    %           csrd.blocks.physical.modulate.BaseModulator, hilbert

    methods (Access = protected)

        function [modulatedSignal, bandWidth] = baseModulator(obj, messageSignal)
            % baseModulator - Core SSB-AM modulation implementation
            % 中文职责：使用 Hilbert 变换生成解析信号，并按配置输出上边带或下边带复包络。
            %
            % This method implements SSB-AM modulation using the Hilbert transform
            % to generate the analytic signal representation. The method creates
            % a complex envelope that, when frequency translated, produces either
            % the upper or lower sideband while suppressing the carrier and
            % unwanted sideband.
            %
            % Syntax:
            %   [modulatedSignal, bandWidth] = baseModulator(obj, messageSignal)
            %
            % Input Arguments:
            % 输入参数：
            %   messageSignal - Input message signal to be modulated
            %   messageSignal - 待调制消息信号
            %                   Type: real-valued numeric array
            %
            % Output Arguments:
            % 输出参数：
            %   modulatedSignal - SSB-AM modulated complex signal
            %   modulatedSignal - SSB-AM 调制后的复基带信号
            %                     Type: complex-valued numeric array
            %   bandWidth - Bandwidth of the modulated signal in Hz
            %   bandWidth - 选定边带的频率范围，单位 Hz
            %               Type: 1x2 numeric array [min_freq max_freq]
            %
            % Processing Steps:
            %   1. Calculate message signal bandwidth for spectrum allocation
            %   2. Generate Hilbert transform for quadrature component
            %   3. Create complex envelope based on sideband selection
            %   4. Determine bandwidth based on sideband mode
            %
            % Sideband Generation:
            %   - Upper Sideband: s(t) = m(t) + j*H{m(t)}
            %   - Lower Sideband: s(t) = m(t) - j*H{m(t)}
            %   where H{m(t)} is the Hilbert transform of message signal m(t)
            %
            % Complex Envelope Properties:
            %   - Real part: Original message signal
            %   - Imaginary part: ±Hilbert transform (sign determines sideband)
            %   - Frequency translation: s_RF(t) = Re{s(t) * exp(j*ω_c*t)}
            %
            % Bandwidth Allocation:
            %   - USB: Positive frequencies [0, B_message]
            %   - LSB: Negative frequencies [-B_message, 0]
            %
            % Example:
            %   messageSignal = sin(2*pi*1000*(0:999)'/48000); % 1 kHz tone
            %   [signal, bw] = obj.baseModulator(messageSignal);

            % Calculate message signal bandwidth for spectrum planning.
            % 先测量消息带宽，后续按 USB/LSB 方向写入带宽区间。
            messageBandwidth = obw(messageSignal, obj.SampleRate);

            % Generate complex envelope based on sideband selection mode.
            % 根据边带模式构造解析信号的正/负频率分量。
            if strcmp(obj.ModulatorConfig.mode, 'upper')
                % Upper Sideband (USB) Generation:
                % 上边带生成：虚部取 Hilbert 正交分量，保留正频率信息。
                % Complex envelope = m(t) + j*H{m(t)}
                % Results in positive frequency spectrum after upconversion
                modulatedSignal = complex(messageSignal, imag(hilbert(messageSignal)));

                % USB bandwidth: spans from DC to message bandwidth
                % USB 带宽从直流到消息带宽。
                bandWidth = [0, messageBandwidth];

            else % Lower sideband mode
                % Lower Sideband (LSB) Generation:
                % 下边带生成：反转 Hilbert 正交分量，保留负频率信息。
                % Complex envelope = m(t) - j*H{m(t)}
                % Results in negative frequency spectrum after upconversion
                modulatedSignal = complex(messageSignal, -imag(hilbert(messageSignal)));

                % LSB bandwidth: spans from negative message bandwidth to DC
                % LSB 带宽从负消息带宽到直流。
                bandWidth = [-messageBandwidth, 0];
            end

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % genModulatorHandle - Generate configured SSB-AM modulator function handle
            % 中文职责：补齐 SSB-AM 边带模式和模拟单天线约束，并返回调制函数句柄。
            %
            % This method configures the SSB-AM modulator with default parameters if not
            % specified and returns a function handle for the complete modulation process.
            % SSB-AM modulation is inherently analog and single-antenna due to the
            % complex envelope processing requirements.
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Output Arguments:
            % 输出参数：
            %   modulatorHandle - Function handle for SSB-AM modulation
            %   modulatorHandle - SSB-AM 调制函数句柄，输入消息信号并输出复包络与带宽
            %                     Type: function_handle
            %                     Usage: [signal, bw] = modulatorHandle(message)
            %
            % Configuration Parameters:
            %   The method automatically configures missing parameters:
            %   - mode: Sideband selection ('upper' or 'lower')
            %
            % Default Configuration:
            %   - mode: Random selection between 'upper' and 'lower' sideband
            %   - IsDigital: false (analog modulation)
            %   - NumTransmitAntennas: 1 (single antenna constraint)
            %
            % Sideband Selection Guidelines:
            %   - Upper Sideband (USB): Traditional choice for frequencies above 9 MHz
            %   - Lower Sideband (LSB): Traditional choice for frequencies below 9 MHz
            %   - Selection often depends on band plan and regional conventions
            %
            % System Compatibility:
            %   SSB-AM systems must maintain consistent sideband selection
            %   between transmitter and receiver for proper demodulation.
            %   Mismatched sideband selection results in spectral inversion.
            %
            % Performance Considerations:
            %   - Hilbert transform introduces computational complexity
            %   - Filter design affects sideband suppression performance
            %   - Phase accuracy critical for carrier suppression
            %
            % Example:
            %   ssbamMod = csrd.blocks.physical.modulate.analog.AM.SSBAM();
            %   ssbamMod.ModulatorConfig.mode = 'upper'; % Force USB mode
            %   modHandle = ssbamMod.genModulatorHandle();
            %   [modSignal, bandwidth] = modHandle(voiceData);

            % Set modulation type flags.
            % 标记为模拟调制，并固定为单天线复包络生成。
            obj.IsDigital = false; % SSB-AM is analog modulation
            obj.NumTransmitAntennas = 1; % Single antenna (complex envelope constraint)

            % Configure sideband selection mode if not provided.
            % 若蓝图未指定边带，随机选择 USB/LSB 以覆盖两类 SSB 行为。
            if ~isfield(obj.ModulatorConfig, 'mode')
                % Random sideband selection for simulation variety
                % 仿真中随机选择边带；真实业务可由法规/业务蓝图固定。
                % In practice, this would be determined by band plan or application
                obj.ModulatorConfig.mode = randsample(["upper", "lower"], 1);
            end

            % Create function handle for modulation.
            % 生成统一调制入口，供 BaseModulator.stepImpl 调用。
            modulatorHandle = @(messageSignal)obj.baseModulator(messageSignal);

        end

    end

end
