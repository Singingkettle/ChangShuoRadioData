function helperSpecSenseDownloadData(generateTrainData,trainNow,baseNetwork,imageSize)
%helperSpecSenseDownloadData Download data files
%   helperSpecSenseDownloadData(GEN,TRAIN,NET,SIZE) downloads data files
%   and trained networks used by the spectrum sensing for 5G and LTE
%   signals examples. If GEN is true, then training data is not downloaded.
%   If TRAIN is true, then trained networks are not downloaded. NET is the
%   base network and SIZE is the image size.

%   Copyright 2021-2023 The MathWorks, Inc.

downloadFileName = "";
expFileNames = "";
if ~generateTrainData
  if isequal(imageSize, [128 128])
    downloadFileName = "SpectrumSensingTrainingData128x128.tgz";
    expFileNames = [
      "license.txt"
      fullfile("TrainingData","128x128","NR_frame_103.png")
      fullfile("TrainingData","128x128","NR_frame_103.hdf")
      fullfile("TrainingData","128x128","LTE_NR","LTE_NR_frame_862.png")
      fullfile("TrainingData","128x128","LTE_NR","LTE_NR_frame_862.hdf")
      ];
  else
    downloadFileName = "SpectrumSensingTrainingData256x256.tgz";
    expFileNames = [
      "license.txt"
      fullfile("TrainingData","256x256","LTE_frame_54.png")
      fullfile("TrainingData","256x256","LTE_frame_54.hdf")
      fullfile("TrainingData","256x256","LTE_NR","LTE_NR_frame_862.png")
      fullfile("TrainingData","256x256","LTE_NR","LTE_NR_frame_862.hdf")
      ];
  end
end
if ~trainNow
  switch baseNetwork
    case "custom"
      downloadFileName = [downloadFileName
        "SpectrumSensingTrainedCustom.zip"];
      expFileNames = [expFileNames
        "license_semantic_segmentation_network.txt"
        "specSenseTrainedNetCustom.mat"
        ];
    case "resnet18"
      downloadFileName = [downloadFileName
        "SpectrumSensingTrainedResnet18.zip"];
      expFileNames = [expFileNames
        "license_semantic_segmentation_network.txt"
        "specSenseTrainedNetResnet18.mat"
        ];
    case "resnet50"
      downloadFileName = [downloadFileName
        "SpectrumSensingTrainedResnet50.zip"];
      expFileNames = [expFileNames
        "license_semantic_segmentation_network.txt"
        "specSenseTrainedNetResnet50.mat"
        ];
    case "mobilenetv2"
      downloadFileName = [downloadFileName
        "SpectrumSensingTrainedMobileNetv2.zip"];
      expFileNames = [expFileNames
        "specSenseTrainedNetMobileNetv2.mat"
        ];
  end
end

urlBase = "https://www.mathworks.com/supportfiles/spc/SpectrumSensing/";

dstFolder = pwd;

helperDownloadDataFile(urlBase, ...
  downloadFileName, ...
  expFileNames, ...
  dstFolder);
end

function helperDownloadDataFile(urlBase, archive, expFileNames, dstFolder)
%helperDownloadDataFile Download and uncompress data file from URL
%   helperDownloadDataFile(URL,DATAFILE,EXPFILES,DST) downloads and
%   uncompresses DATAFILE from URL to DST folder. EXPFILES is a list of
%   expected uncompressed files.

for p=1:length(archive)
  url = urlBase + archive(p);
  
  [~, ~, fExt] = fileparts(archive(p));

  skipDownloadExtract = true;
  for q=1:length(expFileNames)
    tmpFileName = fullfile(dstFolder, expFileNames{q});
    if ~exist(tmpFileName, 'file')
      skipDownloadExtract = false;
      break
    end
  end

  if skipDownloadExtract
    disp("Files already exist. Skipping download and extract.")
  else
    fprintf("Starting download of data files from:\n\t%s\n", url)
    fileFullPath = matlab.internal.examples.downloadSupportFile('spc/SpectrumSensing',...
      archive(p));
    disp('Extracting files.')
    switch fExt
      case '.zip'
        unzip(fileFullPath, dstFolder);
      case '.tgz'
        untar(fileFullPath, dstFolder);
    end
    disp("Extract complete.")
  end
end
end