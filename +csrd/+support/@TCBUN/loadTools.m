function loadTools(obj)
% Inputs: see signature arguments and local validation.
% Outputs: see signature return values and contract fields.

if isfile('tools.mat')
    load('tools.mat', 'tools');
    obj.tools = tools;
else
    obj.tools = dictionary(string.empty,string.empty);
end

end
