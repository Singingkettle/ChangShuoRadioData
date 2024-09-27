classdef baseModulator<matlab.System
    %BASEMODULATOR �˴���ʾ�йش����ժҪ
    %   �˴���ʾ��ϸ˵��
    
    properties
        sourceHandle
        channelHandle
        samplePerSymbol
        samplePerFrame
        windowLength
        stepSize
        offset
        filePrefix 
        repeatedNumber
    end
    
    methods
        function y = clean(obj, x, windowLength, stepSize, offset, samplePerSymbol)
            
            numSamples = length(x);
            numFrames = ...
              floor(((numSamples-offset)-(windowLength-stepSize))/stepSize);

            y = zeros([windowLength,numFrames],class(x));

            startIdx = offset + randi([0 samplePerSymbol]);
            frameCnt = 1;
            while startIdx + windowLength < numSamples
              xWindowed = x(startIdx+(0:windowLength-1),1);
              framePower = sum(abs(xWindowed).^2);
              xWindowed = xWindowed / sqrt(framePower);
              y(:,frameCnt) = xWindowed;
              frameCnt = frameCnt + 1;
              startIdx = startIdx + stepSize;
            end
        end
        
        function is_success = save(obj, x, filePrefix)
            try
                % Save as two column vector
                real_x = real(x);
                imag_x = imag(x);
                x_ = [real_x; imag_x]';
                dlmwrite([filePrefix '.txt'], x_, '-append');
                % Save as Image
                % ������⻹�Ǻܶ࣬��û��ͳһ��Ҫ�󣬺�����Ҫ��������ʵ�飬������˵����֤
                % TODO
                is_success = true;
            catch ME
                is_success = false;
            end
        end
    end
end

