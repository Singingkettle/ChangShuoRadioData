classdef TCBUN
    % Tools can be used now.
    % References:
    % https://www.mathworks.com/matlabcentral/fileexchange/24911-design-pattern-singleton-creational
    properties
        tools
    end
    
    methods(Access = private)
        
        function obj = TCBUN(varargin)
            % TCBUN - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            obj.tools = dictionary(string.empty, string.empty);
        end
        
    end
    
    methods(Static)
        % Concrete implementation.  See Singleton superclass.
        function obj = instance()
            % instance - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            persistent uniqueInstance
            if isempty(uniqueInstance)
                obj = TCBUN();
                uniqueInstance = obj;
            else
                obj = uniqueInstance;
            end
        end
        
    end
    
    methods
        
        addTool(obj, name, handle);
        removeTool(obj, name, handle);
        saveTools(obj);
        loadTools(obj);
        
    end
    
end