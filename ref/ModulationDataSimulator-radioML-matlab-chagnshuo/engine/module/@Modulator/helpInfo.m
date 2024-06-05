function helpInfo
            
    classFactoryInfo = containers.Map;
    classFactory = containers.Map;
    % Get the current root directory path
    currentDirectory = fileparts(mfilename('fullpath'));
    modulatorList = dir(fullfile(currentDirectory, '../Classes/Modulation'));
    
    numModulationClass = 0;
    for folderIndex=3:length(modulatorList)
        folderPath = fullfile(modulatorList(folderIndex).folder, modulatorList(folderIndex).name);
        classFolderName = modulatorList(folderIndex).name;
        
        modulatorClassNameCells = {};
        if exist(folderPath, 'dir')
            classFolderList = dir(folderPath);
            if(~isKey(classFactoryInfo, classFolderName))
                classFactoryInfo(classFolderName) = {};
            end
            for classIndx=3:length(classFolderList)
                classPath = fullfile(classFolderList(classIndx).folder, classFolderList(classIndx).name);
                if exist(classPath, 'file')
                    modulatorClassName = classFolderList(classIndx).name;
                    modulatorClassName = erase(modulatorClassName, '.m');
                    if(isKey(classFactory, modulatorClassName))
                        error('You have defined duplicated modulator classes, whose name is %s.\n' , modulatorClassName, ...
                              'And it''s not illegal. Please correct the code.');
                    end
                    if(strcmp(modulatorClassName, 'baseModulation'))
                        continue;
                    end
                    modulatorClassNameCells{end+1} = modulatorClassName;
                    classFactory(modulatorClassName) = 0;
                    numModulationClass = numModulationClass + 1;
                end
            end
            classFactoryInfo(classFolderName) = modulatorClassNameCells;
        end
    end

    fprintf('All registered modulatorClass are listed as below:\n')
    classFolderNameCells = keys(classFactoryInfo);
    fprintf('\t\t.---|\n');
    for i=1:length(classFolderNameCells)
        classFolderName = classFolderNameCells{i};
        modulatorClassNameCells = classFactoryInfo(classFolderName);
        fprintf('\t\t\t|---%s:\n', classFolderName);
        for j=1:length(modulatorClassNameCells)
            fprintf('\t\t\t|       |\n');
            fprintf('\t\t\t|       |\n');
            fprintf('\t\t\t|       |---%s\n', modulatorClassNameCells{j});
        end
        fprintf('\n\n');
    end
    fprintf('The number of registered modulatorClass are %d.\n', numModulationClass);
end
    
        
