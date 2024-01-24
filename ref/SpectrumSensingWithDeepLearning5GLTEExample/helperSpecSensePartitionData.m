function [imdsTrain,pxdsTrain,imdsVal,pxdsVal,imdsTest,pxdsTest] = ...
  helperSpecSensePartitionData(imds,pxds,parts)
%helperSpecSensePartitionData Partition training data
%   [IDSTR,PDSTR,IDSVL,PDSVL,IDSTS,PDSTS]=helperSpecSensePartitionData(IDS,PDS,P)
%   paritions the image data store, IDS, and pixel label data store, PDS,
%   into training image data store, IDSTR, training pixel data store,
%   PDSTR, validation image data store, IDSVL, and validation pixel label
%   data store, PDSVL, test image data store, IDSTS, and test pixel label
%   data store, PDSTS, based on the partitioning percentages set in P,
%   where P is a 1x3 vector with sum of the elements equal to 100.

%   Copyright 2021-2023 The MathWorks, Inc.

validateattributes(parts,{'numeric'},{'size',[1 3]}, ...
  'helperSpecSensePartitionData','P',3)
assert(sum(parts)==100, 'Sum of parts must be 100')

% Set initial random state for example reproducibility.
s = RandStream('mt19937ar',Seed=0); 
numFiles = numel(imds.Files);
shuffledIndices = randperm(s,numFiles);

numTrain = floor(numFiles*parts(1)/100);
numVal = floor(numFiles*parts(2)/100);

imdsTrain = subset(imds, shuffledIndices(1:numTrain));
imdsVal = subset(imds, shuffledIndices(numTrain+(1:numVal)));
imdsTest = subset(imds, shuffledIndices(numTrain+numVal+1:end));

pxdsTrain = subset(pxds, shuffledIndices(1:numTrain));
pxdsVal = subset(pxds, shuffledIndices(numTrain+(1:numVal)));
pxdsTest = subset(pxds, shuffledIndices(numTrain+numVal+1:end));

end