function helpInfo
            
    classFactoryInfo = containers.Map;
    classFactory = containers.Map;
    % Get the current root directory path
    currentDirectory = fileparts(mfilename('fullpath'));
    channelList = dir(fullfile(currentDirectory, '../Classes/Channel'));
    
    numChannelClass = 0;
    for folderIndex=3:length(channelList)
        folderPath = fullfile(channelList(folderIndex).folder, channelList(folderIndex).name);
        classFolderName = channelList(folderIndex).name;
        if(~isKey(classFactoryInfo, classFolderName))
            classFactoryInfo(classFolderName) = {};
        end
        channelClassNameCells = {};
        if exist(folderPath, 'dir')
            classFolderList = dir(folderPath);
            for classIndx=3:length(classFolderList)
                classPath = fullfile(classFolderList(classIndx).folder, classFolderList(classIndx).name);
                if exist(classPath, 'file')
                    channelClassName = classFolderList(classIndx).name;
                    channelClassName = erase(channelClassName, '.m');
                    if(isKey(classFactory, channelClassName))
                        error('You have defined duplicated channel classes, whose name is %s.\n' , channelClassName, ...
                              'And it''s not illegal. Please correct the code.');
                    end
                    channelClassNameCells{end+1} = channelClassName;
                    classFactory(channelClassName) = 0;
                    numChannelClass = numChannelClass + 1;
                end
            end
            classFactoryInfo(classFolderName) = channelClassNameCells;
        end
    end

    fprintf('All registered channelClass are listed as below:\n')
    classFolderNameCells = keys(classFactoryInfo);
    fprintf('\t\t.---|\n');
    for i=1:length(classFolderNameCells)
        classFolderName = classFolderNameCells{i};
        channelClassNameCells = classFactoryInfo(classFolderName);
        fprintf('\t\t\t|---%s:\n', classFolderName);
        for j=1:length(channelClassNameCells)
            fprintf('\t\t\t|       |\n');
            fprintf('\t\t\t|       |\n');
            fprintf('\t\t\t|       |---%s\n', channelClassNameCells{j});
        end
        fprintf('\n\n');
    end
    fprintf('The number of registered channelClass are %d.\n', numChannelClass);
end
    
        
