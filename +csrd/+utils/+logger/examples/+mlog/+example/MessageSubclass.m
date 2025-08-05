classdef MessageSubclass < mlog.Message
    
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
            
            str = sprintf("%-7s %10s, %5f, %s", obj.Level, obj.CustomString,...
                obj.CustomNumber, obj.Text);
            
        end %function
        
    end %methods
    
end %classdef

