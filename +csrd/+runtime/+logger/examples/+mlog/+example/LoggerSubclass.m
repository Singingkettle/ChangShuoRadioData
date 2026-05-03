classdef LoggerSubclass < mlog.Logger
    % 中文说明：提供 CSRD 生产链路中的 LoggerSubclass 实现。
    
    %   Copyright 2021 The MathWorks Inc.
    
    
    %% Constructor / Destructor
    methods
        
        function obj = LoggerSubclass(varargin)
            % Construct the logger
            % 中文说明：LoggerSubclass 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            
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
            % 中文说明：write 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
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


