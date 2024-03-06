classdef BFMData<matlab.System
    %INPUTDATABPSK �˴���ʾ�йش����ժҪ
    %   �˴���ʾ��ϸ˵��
    
    properties
        samplePerFrame
        sampleRate
    end
    
    methods
        function obj = BFMData(dataParam)
            %INPUTDATABPSK ��������ʵ��
            %   �˴���ʾ��ϸ˵��
            obj.samplePerFrame = dataParam.samplePerFrame;
            obj.sampleRate = dataParam.sampleRate;
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

