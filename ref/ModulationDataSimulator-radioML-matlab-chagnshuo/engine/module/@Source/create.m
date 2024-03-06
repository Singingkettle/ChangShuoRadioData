function dataHandle = create(sourceParam)

    try
        sourceClassName = [sourceParam.modulatorType 'Data'];
        classPointer = str2func(sourceClassName);
        dataHandle = classPointer(sourceParam);
    catch ME
        errorInfo = sprintf('Can not find the sourceClass for the modulator type %s.\nThere are two cases for this reason. \n\t\t\t(1):You provide wrong name of modulatorType. So please check your configurtions.\n\t\t\t(2):The sourceFactory doesn''t have the sourceClass of the modulator type %s. Please define new sourceClass based on the suggestion within the file of README.md.\n', sourceParam.modulatorType, sourceParam.modulatorType);
        Source.helpInfo();
        error(errorInfo);
    end

end
