function loadTools(obj)
% 中文说明：提供 CSRD 生产链路中的 loadTools 实现。
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.

if isfile('tools.mat')
    load('tools.mat', 'tools');
    obj.tools = tools;
else
    obj.tools = dictionary(string.empty,string.empty);
end

end
