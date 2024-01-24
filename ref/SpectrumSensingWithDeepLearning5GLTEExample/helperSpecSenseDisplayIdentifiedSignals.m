function varargout = helperSpecSenseDisplayIdentifiedSignals(rcvdSpect,segResults,classNames,sr,fc,to)
%helperSpecSenseDisplayIdentifiedSignals Label identified signals
%   helperSpecSenseDisplayIdentifiedSignals(P,SEG,C,FS,FC,TF) displays the
%   identified signals and their bands over the spectrogram, P. SEG is the
%   semantic segmentation results, C is the possible class names, FS is the
%   sampling rate, FC is the center frequency, and TF is the frame time. 
%
%   FB = helperSpecSenseDisplayIdentifiedSignals(...) returns the estimated
%   frequency bands as a cell array, where the first cell contains results
%   for C(1) and the second cell contains the results for C(2). Each cell
%   contains a 1x2 array where the first element is the minimum frequency
%   and the second element is the maximum frequency for the corresponding
%   class. 

%   Copyright 2021-2023 The MathWorks, Inc.

imageSize = size(segResults);
numClasses = numel(classNames);
cmap = cool(numClasses);

freqDim = 2;  % Put frequency on the x-axis
timeDim = 1;  % Put time on the y-axis

maskedImg = rcvdSpect;
cnt = 1;
for cn = 1:length(classNames)
  changeIdx = diff([0 mode(segResults) == categorical(classNames(cn),classNames) 0]);
  startIdx = find(changeIdx==1);
  endIdx = find(changeIdx==-1);
  for p=1:length(startIdx)
    % Find the starting frequency of the band
    fminPixel = startIdx(p);
    fmin = fminPixel * (sr/imageSize(timeDim)) - sr/2;
    % Find the ending frequency of the band
    fmaxPixel = endIdx(p);
    if fmaxPixel > size(segResults,2)
      fmaxPixel = size(segResults,2);
    end
    fmax = fmaxPixel * (sr/imageSize(timeDim)) - sr/2;
    freqBound{p} = [fmin fmax] + fc; %#ok<AGROW>

    % Add mask with label
    if ~isempty(fmin)
      maskSig = false(imageSize);
      if freqDim == 2
        loc = [fmin/1e6 -5*cn];
        maskSig(:,fminPixel:fmaxPixel) = true;
      else
        loc = [-5*cn fmin/1e6];
        maskSig(fminPixel:fmaxPixel,:) = true;
      end
      maskedImg = insertObjectMask(maskedImg,maskSig,'Color',cmap(cn,:), ...
        'Opacity',0.5,'LineOpacity',0);
      textInfo(cnt) = struct('loc',loc,'text',classNames(cn)); %#ok<AGROW>
      cnt = cnt + 1;
    end
  end
end

t = linspace(-to,0,imageSize(1)) * 1e3;
f = (linspace(-sr/2,sr/2,imageSize(2)) + fc)/1e6;

if freqDim == 2
  imagesc(f,t,maskedImg)
  xlabel('Frequency (MHz)')
  ylabel('Time (ms)')
else
  imagesc(t,f,maskedImg)
  xlabel('Time (ms)')
  ylabel('Frequency (MHz)')
end
ca = gca;
% Flip the tick labels to put the correct labels. image functions flip the
% data while displaying. Flipping the data would present the label upside
% down. 
ca.YTickLabel = flipud(ca.YTickLabel);
h = colorbar;
colormap(h,parula(256))
title('Labeled spectrogram')
for p=1:length(textInfo)
  text(textInfo(p).loc(1),textInfo(p).loc(2),textInfo(p).text)
end
if nargout > 0
  varargout{1} = freqBound;
end