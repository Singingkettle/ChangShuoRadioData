classdef PI4DQPSKModulation<baseModulation
    %BPSKMODULATOR �˴���ʾ�йش����ժҪ
    %   �˴���ʾ��ϸ˵��
    
    properties
        modulatorType = 'PI4DQPSK'
        filterCoefficients
    end
    
    methods
        function obj = PI4DQPSKModulation(modulatorParam)
            %BPSKMODULATOR ��������ʵ��
            %   �˴���ʾ��ϸ˵��
            
            % �����������������
            obj.sourceHandle = ...
                Source.create(modulatorParam.sourceParam);
            
            % �����ŵ����
            obj.channelHandle = ...
                Channel.create(modulatorParam.channelParam);
            
            % ����ƽ���������������˲�����ϵ��ֵ
            obj.filterCoefficients = modulatorParam.filterCoefficients;
            
            %
            obj.samplePerSymbol = modulatorParam.samplePerSymbol;
            obj.samplePerFrame = modulatorParam.samplePerFrame;
            obj.windowLength = modulatorParam.windowLength;
            obj.stepSize = modulatorParam.stepSize;
            obj.offset = modulatorParam.offset;
            obj.filePrefix = modulatorParam.filePrefix;
            obj.repeatedNumber = modulatorParam.repeatedNumber;
        end
    end
    
    methods(Access = protected)
        function y = stepImpl(obj)
            % Implement algorithm. Calculate y as a function of input u and
            % discrete states.
            % Modulate
            % Generate random data
            for i=1:obj.repeatedNumber
                x = obj.sourceHandle();

                % Modulate
                M = 4; % modulation order
                syms = dpskmod(x, M, pi/4);
                y = filter(obj.filterCoefficients, 1, upsample(syms, ...
                    obj.samplePerSymbol));

                % Pass through independent channels
                y = obj.channelHandle(y);

                % Remove transients from the beginning, trim to size, 
                % and normalize
                y = obj.clean(y, obj.windowLength, obj.stepSize, ...
                    obj.offset, obj.samplePerSymbol);

                % Save as file
                is_success = obj.save(y, fullfile(obj.filePrefix, ...
                    [obj.modulatorType sprintf('%06d', i)]));
                if(~is_success) 
                    error('Something Wrong with the Save Process!!!');
                end
            end
        end

    end
end

