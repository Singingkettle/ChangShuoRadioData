classdef USBData<matlab.System
    %INPUTDATABPSK �˴���ʾ�йش����ժҪ
    %   �˴���ʾ��ϸ˵��
    
    properties
        sampleRate
        samplePerFrame
    end
    
    methods
        function obj = USBData(dataParam)
            %INPUTDATABPSK ��������ʵ��
            %   �˴���ʾ��ϸ˵��
            
            obj.sampleRate = dataParam.sampleRate;
            obj.samplePerFrame = dataParam.samplePerFrame;
        end
    end
    
    methods(Access = protected)
        function y = stepImpl(obj)
            % Implement algorithm. Calculate y as a function of input u and
            % discrete states.
            y = getAudio(2*obj.samplePerFrame, obj.sampleRate);
        end
    end
end

