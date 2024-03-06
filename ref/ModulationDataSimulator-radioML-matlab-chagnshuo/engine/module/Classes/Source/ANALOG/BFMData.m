classdef BFMData<matlab.System
    %INPUTDATABPSK 此处显示有关此类的摘要
    %   此处显示详细说明
    
    properties
        samplePerFrame
        sampleRate
    end
    
    methods
        function obj = BFMData(dataParam)
            %INPUTDATABPSK 构造此类的实例
            %   此处显示详细说明
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

