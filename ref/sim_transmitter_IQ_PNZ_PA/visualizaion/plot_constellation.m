% function plot_constellation(a, b, title0)
% %     fig = fig + 1;
% %     figure(fig)
% %     clf(fig)
% figure;
% plot(real(a),imag(a),'x');%,'MarkerFaceColor',[0 0.4470 0.7410]
% hold on;
% legend('a')
% plot(real(b),imag(b),'o');
% hold on;
% legend('txSig','rxSig')
% xlabel('In-Phase')
% ylabel('Quadrature')
% title(title0)
% %     lim = 2.5;
% %     xlim([-lim lim])
% %     ylim([-lim lim])
% end
function plot_constellation(varargin)
%     fig = fig + 1;
%     figure(fig)
%     clf(fig)
figure;
a = varargin{1};
plot(real(a),imag(a),'x');%,'MarkerFaceColor',[0 0.4470 0.7410]
legend('txSig')
if nargin >= 3
    hold on;
    b = varargin{2};
    plot(real(b),imag(b),'.');
    legend('txSig','rxSig')
    if (nargin>3) && strcmp(varargin{4},'true')
    lim = 2.5;
    xlim([-lim lim])
    ylim([-lim lim])
    end
end
xlabel('In-Phase')
ylabel('Quadrature')
title0 = varargin{3};
title(title0)
% if (nargin>3) && strcmp(varargin{4},'true')
%     lim = 2.5;
%     xlim([-lim lim])
%     ylim([-lim lim])
% end
end