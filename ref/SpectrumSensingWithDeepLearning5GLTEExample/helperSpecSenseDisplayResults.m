function helperSpecSenseDisplayResults(signal,trueLabels,predictedLabels, ...
  classNames,sr,fc,to)
%helperSpecSenseDisplayResults Spectrum sensing results
%   helperSpecSenseDisplayResults(P,TL,PL,C,FS,FC,TF) displays the receive
%   spectrogram, P, together with true labels, TL, and predicted labels,
%   TP. Possible class names are, C, sampling rate is FS, center frequency
%   is FC, and frame time is TF. 

%   Copyright 2021 The MathWorks, Inc.

numClasses = numel(classNames);
cmap = cool(numClasses);

if ~isempty(trueLabels)
  trueLabels = double(trueLabels);
end

predictedLabels = double(predictedLabels);

t = linspace(-to,0,size(signal,1)) * 1e3;
f = (linspace(-sr/2,sr/2,size(signal,2)) + fc)/1e6;
freqDim = 2; % Put frequency on the x-axis

N = numel(classNames);
ticks = 1:N;
if ~isempty(trueLabels)
  subplot(311)
else
  subplot(211)
end
% Flip the data. image functions will flip it again. Then by setting YDir
% to normal, we flip it back to the correct orientation.
signal = flipud(signal);
if freqDim == 2
  imagesc(f,t,signal)
  xlabel('Frequency (MHz)')
  ylabel('Time (ms)')
else
  imagesc(t,f,signal)
  xlabel('Time (ms)')
  ylabel('Frequency (MHz)')
end
set(gca,'YDir','normal')
a = colorbar;
colormap(a,parula(256))
title("Received Spectrogram")
if ~isempty(trueLabels)
  subplot(312)
  if freqDim == 2
    im = imagesc(f,t,trueLabels,[1 numClasses]);
    xlabel('Frequency (MHz)')
    ylabel('Time (ms)')
  else
    im = imagesc(t,f,trueLabels,[1 numClasses]);
    xlabel('Time (ms)')
    ylabel('Frequency (MHz)')
  end
  set(gca,'YDir','normal')
  im.Parent.Colormap = cmap;
  colorbar('TickLabels',cellstr(classNames),'Ticks',ticks,...
    'TickLength',0,'TickLabelInterpreter','none');
  title('True signal labels')
end
if ~isempty(trueLabels)
  subplot(313)
else
  subplot(212)
end
predictedLabels = flipud(predictedLabels);
if freqDim == 2
  im = imagesc(f,t,predictedLabels,[1 numClasses]);
  xlabel('Frequency (MHz)')
  ylabel('Time (ms)')
else
  im = imagesc(t,f,predictedLabels,[1 numClasses]);
  xlabel('Time (ms)')
  ylabel('Frequency (MHz)')
end
set(gca,'YDir','normal')
im.Parent.Colormap = cmap;
colorbar('TickLabels',cellstr(classNames),'Ticks',ticks,...
  'TickLength',0,'TickLabelInterpreter','none');
title('Estimated signal labels')
end