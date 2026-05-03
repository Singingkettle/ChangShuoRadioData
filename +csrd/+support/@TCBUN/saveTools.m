function saveTools(obj)
% 中文说明：提供 CSRD 生产链路中的 saveTools 实现。
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.

tools = obj.tools;
save('tools.mat', 'tools');

end

