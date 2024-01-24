function [I,P] = helperSpecSenseSpectrogramImage(x,Nfft,sr,imgSize)
%helperSpecSenseSpectrogramImage Spectrogram image from baseband signal
%   I = helperSpecSenseSpectrogramImage(X,NFFT,FS,IMGSZ) calculates the
%   spectrogram of baseband signal X, using NFFT length FFT and assuming
%   sample rate of FS. 

%   Copyright 2021-2023 The MathWorks, Inc.

% Generate spectrogram
window = hann(256);
overlap = 10;
[~,~,~,P] = spectrogram(x,window,overlap,...
  Nfft,sr,'centered','psd');

% Convert to logarithmic scale
P = 10*log10(abs(P')+eps);

% Rescale pixel values to the interval [0,1]. Resize the image to imgSize
% using nearest-neighbor interpolation.
im = imresize(im2uint8(rescale(P)),imgSize,"nearest");

% Convert to RGB image with parula colormap. 
I = im2uint8(flipud(ind2rgb(im,parula(256))));
end