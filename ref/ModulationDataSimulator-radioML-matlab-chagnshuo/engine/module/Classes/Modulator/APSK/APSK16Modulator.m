classdef APSK16Modulator<baseModulator
    %BPSKMODULATOR 此处显示有关此类的摘要
    %   此处显示详细说明
    
    properties
        modulatorType = 'APSK16'
        filterCoefficients
    end
    
    methods
        function obj = APSK16Modulator(modulatorParam)
            %BPSKMODULATOR 构造此类的实例
            %   此处显示详细说明
            
            % 构造数据生成器句柄
            obj.sourceHandle = ...
                Source.create(modulatorParam.sourceParam);
            
            % 构造信道句柄
            obj.channelHandle = ...
                Channel.create(modulatorParam.channelParam);
            
            % 生成平方根升余玄滚降滤波器的系数值
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

                M = [8 8];
                radii = [0.5 1];
                phOff = [0 pi/6];
                % Modulate
                syms = apskmod(x,M,radii,phOff);
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

