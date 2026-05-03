classdef MessageSubclass < mlog.Message
    % 中文说明：提供 CSRD 生产链路中的 MessageSubclass 实现。
    
    %   Copyright 2021 The MathWorks Inc.
    
    %#ok<*PROP>
    
    
    %% Properties
    properties
        CustomString (1,1) string
        CustomNumber (1,1) double
    end
    
    
    %% Public Methods
    methods
        
        function t = toTable(obj)
            % Convert array of messages to a table
            % 中文说明：toTable 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            
            % Call superclass method
            t = obj.toTable@mlog.Message();
            
            % Find any invalid handles
            idxValid = isvalid(obj);
            
            % Create variables
            CustomString(idxValid,1) = vertcat( obj(idxValid).CustomString );
            CustomNumber(idxValid,1) = vertcat( obj(idxValid).CustomNumber );
            
            % Insert Variables
            t = addvars(t, CustomString, CustomNumber, 'after', "Level");
            
        end %function
        
    end %methods
    
    
    
    %% Protected Methods
    methods (Access = {?mlog.Message, ?mlog.Logger})
        
        function str = createDisplayMessage(obj)
            % Customize the message display format
            % 中文说明：createDisplayMessage 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            
            str = sprintf("%-7s %10s, %5f, %s", obj.Level, obj.CustomString,...
                obj.CustomNumber, obj.Text);
            
        end %function
        
    end %methods
    
end %classdef

