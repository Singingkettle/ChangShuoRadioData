classdef ASK2Data<matlab.System
    %INPUTDATABPSK �˴���ʾ�йش����ժҪ
    %   �˴���ʾ��ϸ˵��
    
    properties
        M=2
        samplePerSymbol
        samplePerFrame
    end
    
    methods
        function obj = ASK2Data(dataParam)
            %INPUTDATABPSK ��������ʵ��
            %   �˴���ʾ��ϸ˵��
            obj.samplePerFrame = dataParam.samplePerFrame;
            obj.samplePerSymbol = dataParam.samplePerSymbol;
        end
    end
    
    methods(Access = protected)
        function y = stepImpl(obj)
            % Implement algorithm. Calculate y as a function of input u and
            % discrete states.
            y = randi([0 obj.M-1], ...
                2*obj.samplePerFrame/obj.samplePerSymbol, 1);
        end

    end
end

