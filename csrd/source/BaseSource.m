classdef BaseSource < matlab.System
    
    properties
        TimeDuration (1, 1) {mustBePositive, mustBeReal} = 1
        SampleRate (1, 1) {mustBePositive, mustBeReal} = 200e3
        SamplePerSymbol (1, 1) {mustBePositive, mustBeReal} = 1
    end
    
    properties (Access = protected)
        SamplePerFrame
    end
    
    methods
        
        function obj = BaseSource(varargin)
            
            setProperties(obj, nargin, varargin{:});
            
        end
        
    end
    
    methods (Access = protected)
        
        function setupImpl(obj)
            obj.SamplePerFrame = round(obj.SampleRate * obj.TimeDuration);
        end
        
    end
    
end
