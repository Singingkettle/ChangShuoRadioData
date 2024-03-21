clc
clear
close all

fs = 200;
t = 0:1/fs:1;
i = sin(2*pi*10*t) + randn(size(t))/10;
q = sin(2*pi*20*t) + randn(size(t))/10;

y = modulate(i, 70, fs, 'am');