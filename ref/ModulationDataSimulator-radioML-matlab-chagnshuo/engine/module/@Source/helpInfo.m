function helpInfo
            
    classFactoryInfo = containers.Map;
    classFactory = containers.Map;
    % Get the current root directory path
    currentDirectory = fileparts(mfilename('fullpath'));
    modulatorDataList = dir(fullfile(currentDirectory, '../Classes/Source'));
    
    numsourceClass = 0;
    for folderIndex=3:length(modulatorDataList)
        folderPath = fullfile(modulatorDataList(folderIndex).folder, modulatorDataList(folderIndex).name);
        classFolderName = modulatorDataList(folderIndex).name;
        if(~isKey(classFactoryInfo, classFolderName))
            classFactoryInfo(classFolderName) = {};
        end
        sourceClassNameCells = {};
        if exist(folderPath, 'dir')
            classFolderList = dir(folderPath);
            for classIndx=3:length(classFolderList)
                classPath = fullfile(classFolderList(classIndx).folder, classFolderList(classIndx).name);
                if exist(classPath, 'file')
                    sourceClassName = classFolderList(classIndx).name;
                    sourceClassName = erase(sourceClassName, '.m');
                    sourceClassName = erase(sourceClassName, 'source');
                    if(isKey(classFactory, sourceClassName))
                        error('You have defined duplicated input data classes, whose name is %s.\n' , sourceClassName, ...
                              'And it''s not illegal. Please correct the code.');
                    end
                    sourceClassNameCells{end+1} = sourceClassName;
                    classFactory(sourceClassName) = 0;
                    numsourceClass = numsourceClass + 1;
                end
            end
            classFactoryInfo(classFolderName) = sourceClassNameCells;
        end
    end

    fprintf('All registered sourceClass are listed as below:\n')
    classFolderNameCells = keys(classFactoryInfo);
    fprintf('\t\t.---|\n');
    for i=1:length(classFolderNameCells)
        classFolderName = classFolderNameCells{i};
        sourceClassNameCells = classFactoryInfo(classFolderName);
        fprintf('\t\t\t|---%s:\n', classFolderName);
        for j=1:length(sourceClassNameCells)
            fprintf('\t\t\t|       |\n');
            fprintf('\t\t\t|       |\n');
            fprintf('\t\t\t|       |---%s\n', sourceClassNameCells{j});
        end
        fprintf('\n\n');
    end
    fprintf('The number of registered sourceClass are %d.\n', numsourceClass);
end
    
        
