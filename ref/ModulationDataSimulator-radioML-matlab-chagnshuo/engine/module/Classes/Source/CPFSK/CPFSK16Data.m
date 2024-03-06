classdef CPFSK16Data<matlab.System
    %INPUTDATABPSK 此处显示有关此类的摘要
    %   此处显示详细说明
    
    properties
        M=16
        samplePerSymbol
        samplePerFrame
    end
    
    methods
        function obj = CPFSK16Data(dataParam)
            %INPUTDATABPSK 构造此类的实例
            %   此处显示详细说明
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

