classdef PowerAmplifier
    % PowerAmplifier_ch������һ�����š�
    % ��Ҫ���ܣ�1������ʹ�ô˹�������������ݡ�2���Թ��Ž��н�ģ
    
    properties
        poly_coeffs  %�������ʽMP��ϵ����������ÿ���Ƿ����Ե�ϵ����ÿ���Ǽ���ЧӦ��ϵ����
        order        % �ɹ��������ķ����Խ�������������Ϊ������
        memory_depth % ����ЧӦ�������ȡ�
        nmse_of_fit  % ���������������Ϲ���ģ��ʱ���Զ����������NMSE��
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
            
            % ��WARP���ϵ����Ĭ�϶���ʽϵ����
            cof  = 1;%10��
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
            coeffs = reshape(obj.poly_coeffs.',[],1);%�����������a.'<==>transpose(a)<==>����ת��
            pa_output = X * coeffs;
        end
        
        function obj = make_pa_model(obj, in, out)
            % make_pa_model������ϰ��һ������ģ�͡�
            % ����������С���˷����PHģ�͵Ĺ��š�in�����빦�ŵ���������out����ʵ���ŵ������
            % ���ģ�ͻὫϰ�õĲ������浽obj.poly_coeffs��
            % ���ģ��ͬʱ�Ὣ��������ģ�͵Ĺ�һ���������(NMSE)
            % 
            % ��С���˷��Ľ��Ǳ�׼�ġ�����ͨ��sum_i [y_i - (beta_0 x_i + beta_1 x_i)^2]�Ż��Ƶ�
            % ��á�����ģ�͹���ϵ�������Եġ�
            % 
            % ���м��������򻯣�ʹ����һ����С��lambda�������԰������ƾ���������
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
            % NMSE�����һ���������
            % equivalent to sum (error)2 / sum(desired)^2
%             nmse = norm(desired - actual)^2 / norm(desired)^2;
            
            difference = abs(desired-actual)./abs(desired);
            nmse = std(difference)*100;
        end  
        
        function X = setup_basis_matrix(obj, x)
            % ���û�������Ϊ��С���˷�LS��transmit�������û�������
            % ���룺
            %   x - ���������źŵ���������
            % �����
            %   X - ����ÿ����ʱ�Ӱ汾���źź�ͨ�������Ժ���ź���ɵľ���
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
            % ����ת�����󡣿��Է���Ľ������ԵĽ���ת����ϵ����������Ϊ���ǵ�ģ����Ҫ����������
            if nargin == 1%���ֻ��һ������obj
                order = obj.order;
            end
            number_of_coeffs = (order + 1) / 2;
        end
    end
end
