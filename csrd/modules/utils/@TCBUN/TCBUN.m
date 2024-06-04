classdef TCBUN
    % Tools can be used now. 
    % 这个类的本质目标是管理一个针对各种模块（类）实例的一个预缓存
    % 因为有些类的实例，在初始化阶段会比较消耗时间，且该实例可能被重复使用，
    % 而我们信号仿真的主代码，会频繁进行重复的实例化过程，例如采样速率转换函数，
    % 这些重复实例化过程带来了比较大的运行时间开销。因此，当一个实例在初始化
    % 完成之后，我们可以将其存入字典，当有一个操作需要的时候，首先查询字典，
    % 如果有一个已经完成实例化的函数句柄，那么就可以直接来使用，避免重复实例化开销
    % 如果没有，则实例化，并将该新的实例化加入到该工具池中。
    % 这个类的设计遵循单例设计模式，参考了这个链接：
    % https://www.mathworks.com/matlabcentral/fileexchange/24911-design-pattern-singleton-creational
    properties
        tools 
    end
    
    methods(Access = private)

        function obj = TCBUN(varargin)
            obj.tools = dictionary(string.empty, string.empty);
        end
        
    end
    
    methods(Static)
      % Concrete implementation.  See Singleton superclass.
      function obj = instance()
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