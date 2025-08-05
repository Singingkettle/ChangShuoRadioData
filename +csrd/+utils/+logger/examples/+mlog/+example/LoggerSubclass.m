classdef LoggerSubclass < mlog.Logger
    
    %   Copyright 2021 The MathWorks Inc.
    
    
    %% Constructor / Destructor
    methods
        
        function obj = LoggerSubclass(varargin)
            % Construct the logger
            
            % Call superclass constructor with the same inputs
            obj@mlog.Logger(varargin{:});
            
            % Instruct Logger to use the message subclass
            obj.MessageConstructor = @mlog.example.MessageSubclass;
            
        end %function
        
    end %methods
    
    
    
    %% Public Methods
    methods
        
        function varargout = write(obj, customString, customNumber, varargin)
            % write a message to the log
            %
            % Syntax:
            %       logObj.write(name, type, level,...)
            
            % Check arguments
            arguments
                obj (1,1)
                customString (1,1) string
                customNumber (1,1) double
            end
            arguments (Repeating)
                varargin
            end
            
            % Construct the message
            msg = constructMessage(obj, varargin{:});
            
            % Was a message created? Note that it might be empty if the
            % level did not meet any log level thresholds.
            if ~isempty(msg)
                
                % Add custom properties
                msg.CustomString = customString;
                msg.CustomNumber = customNumber;
                
                % Add the message to the log
                obj.addMessage(msg);
                
            end %if ~isempty(msg)
            
            % Send msg output if requested
            if nargout
                varargout{1} = msg;
            end
            
        end %function
        
    end %methods
    
    
end %classdef


