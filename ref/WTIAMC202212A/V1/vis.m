clc 
clear
close all
load("data\test_00.mat");

a = test.x_(1, 1, 1, :) + i * test.x_(1, 1, 2, :);
a = reshape(a, [1, 1024]);

b = test.x_(1, 2, 1, :) + i * test.x_(1, 2, 2, :);
b = reshape(b, [1, 1024]);

c = test.x_(1, 3, 1, :) + i * test.x_(1, 3, 2, :);
c = reshape(c, [1, 1024]);

d = test.x_(1, 4, 1, :) + i * test.x_(1, 4, 2, :);
d = reshape(d, [1, 1024]);

e = test.x_(1, 5, 1, :) + i * test.x_(1, 5, 2, :);
e = reshape(e, [1, 1024]);

% f = test.x_(1, 6, 1, :) + i * test.x_(1, 6, 2, :);
% f = reshape(f, [1, 1024]);
% 
% g = test.x_(1, 7, 1, :) + i * test.x_(1, 7, 2, :);
% g = reshape(g, [1, 1024]);