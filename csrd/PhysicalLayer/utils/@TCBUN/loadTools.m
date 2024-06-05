function loadTools(obj)

    if isfile('tools.mat')
        load('tools.mat', 'tools');
        obj.tools = tools;
    else
        obj.tools = dictionary(string.empty,string.empty);
    end

end

