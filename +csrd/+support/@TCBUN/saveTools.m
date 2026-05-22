function saveTools(obj)
% Inputs: see signature arguments and local validation.
% Outputs: see signature return values and contract fields.

tools = obj.tools;
save('tools.mat', 'tools');

end
