classdef USBData<matlab.System
    %INPUTDATABPSK 此处显示有关此类的摘要
    %   此处显示详细说明
    
    properties
        sampleRate
        samplePerFrame
    end
    
    methods
        function obj = USBData(dataParam)
            %INPUTDATABPSK 构造此类的实例
            %   此处显示详细说明
            
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

