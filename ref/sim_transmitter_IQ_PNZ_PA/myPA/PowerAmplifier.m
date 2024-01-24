classdef PowerAmplifier
    % PowerAmplifier_ch构建了一个功放。
    % 主要功能：1）可以使用此功放输入输出数据。2）对功放进行建模
    
    properties
        poly_coeffs  %记忆多项式MP的系数矩阵。其中每行是非线性的系数，每列是记忆效应的系数。
        order        % 可供考虑最大的非线性阶数。阶数必须为奇数。
        memory_depth % 记忆效应的最大深度。
        nmse_of_fit  % 对输入输出数据拟合功放模型时，自动计算产生的NMSE。
    end
    
    methods
        function obj = PowerAmplifier(params)
            if nargin == 0
                params.order = 7;
                params.memory_depth = 4;
            end
            if mod(params.order,2) == 0
                error('Order must be odd.');
            end
            
            obj.order = params.order;
            obj.memory_depth = params.memory_depth;
            
            % 从WARP板上导入的默认多项式系数。
            cof  = 1;%10倍
            default_poly_coeffs = zeros(4,4);
            default_poly_coeffs(1:4,1:4) = ...
            [ 0.9295 - 0.0001i, 0.2939 + 0.0005i, -0.1270 + 0.0034i, 0.0741 - 0.0018i;  % 1st order coeffs
            0.1419 - 0.0008i, -0.0735 + 0.0833i, -0.0535 + 0.0004i, 0.0908 - 0.0473i; % 3rd order coeffs
            0.0084 - 0.0569i, -0.4610 + 0.0274i, -0.3011 - 0.1403i, -0.0623 - 0.0269i;% 5th order coeffs
            0.1774 + 0.0265i, 0.0848 + 0.0613i, -0.0362 - 0.0307i, 0.0415 + 0.0429i].*cof; % 7th order coeffs
%             default_poly_coeffs = [1,-0.1+0.1i,-0.001+0.001i, -0.0007-0.0007i;
%                 1,-0.1+0.1i,-0.001+0.001i, -0.0007-0.0007i;
%                 1,-0.1+0.1i,-0.001+0.001i, -0.0007-0.0007i;
%                 1,-0.1+0.1i,-0.001+0.001i, -0.0007-0.0007i].';
%             default_poly_coeffs(1:4,1:4) = ...
%             [temp*1,temp*0,temp*0,temp*0];
            obj.poly_coeffs = default_poly_coeffs(1:obj.convert_order_to_number_of_coeffs, 1:obj.memory_depth);
        end
        
        function pa_output = transmit(obj, in)
            X = obj.setup_basis_matrix(in);
            coeffs = reshape(obj.poly_coeffs.',[],1);%重载运算符：a.'<==>transpose(a)<==>矩阵转置
            pa_output = X * coeffs;
        end
        
        function obj = make_pa_model(obj, in, out)
            % make_pa_model函数：习得一个功放模型。
            % 描述：用最小二乘法拟合PH模型的功放。in是输入功放的列向量，out是真实功放的输出。
            % 这个模型会将习得的参数保存到obj.poly_coeffs。
            % 这个模型同时会将导出功放模型的归一化均方误差(NMSE)
            % 
            % 最小二乘法的解是标准的。它能通过sum_i [y_i - (beta_0 x_i + beta_1 x_i)^2]优化推导
            % 获得。功放模型关于系数是线性的。
            % 
            % 其中加入了正则化：使用了一个很小的lambda。它可以帮助改善矩阵条件。
            %  http://www.signal.uu.se/Research/PCCWIP/Visbyrefs/Viberg_Visby04.pdf
            y = out;
            X = obj.setup_basis_matrix(in);
            
            %coeffs = (X'*X) \ (X'*y);
            lambda = 0.001;
            coeffs = ( X'*X + lambda*eye(size((X'*X))) ) \ (X'*y);
            
            %Reshape for easier to understand matrix of coeffs
            coeffs_transpose = reshape(coeffs, [obj.memory_depth, obj.convert_order_to_number_of_coeffs]);
            obj.poly_coeffs = coeffs_transpose.';
            
            model_pa_output = obj.transmit(in);
            obj.nmse_of_fit = obj.calculate_nmse(y, model_pa_output)
        end
        
        function nmse = calculate_nmse(desired, actual)
            % NMSE计算归一化均方误差
            % equivalent to sum (error)2 / sum(desired)^2
%             nmse = norm(desired - actual)^2 / norm(desired)^2;
            
            difference = abs(desired-actual)./abs(desired);
            nmse = std(difference)*100;
        end  
        
        function X = setup_basis_matrix(obj, x)
            % 设置基函数。为最小二乘法LS和transmit函数设置基函数。
            % 输入：
            %   x - 功放输入信号的列向量。
            % 输出：
            %   X - 其中每列是时延版本的信号和通过非线性后的信号组成的矩阵。
            %
            
            number_of_basis_vectors = obj.memory_depth * obj.convert_order_to_number_of_coeffs;
            X = zeros(length(x), number_of_basis_vectors);
            
            count = 1;
            for i = 1:2:obj.order
                branch = x .* abs(x).^(i-1);
                for j = 1:obj.memory_depth
                    delayed_version = zeros(size(branch));
                    delayed_version(j:end) = branch(1:end - j + 1);
                    X(:, count) = delayed_version;
                    count = count + 1;
                end
            end
        end   
        
        function number_of_coeffs = convert_order_to_number_of_coeffs(obj, order)
            % 阶数转换矩阵。可以方便的将非线性的阶数转换成系数个数。因为我们的模型需要奇数阶数。
            if nargin == 1%如果只有一个参数obj
                order = obj.order;
            end
            number_of_coeffs = (order + 1) / 2;
        end
    end
end
