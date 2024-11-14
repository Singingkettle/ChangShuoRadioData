function modulatorHandle = create(modulatorParam)
    % Return the modulate handle based the modulatorParam.
modulatorClassName = [modulatorParam.modulatorType 'Modulator'];
classPointer = str2func(modulatorClassName);
modulatorHandle = classPointer(modulatorParam);
    try
        modulatorClassName = [modulatorParam.modulatorType 'Modulator'];
        classPointer = str2func(modulatorClassName);
        modulatorHandle = classPointer(modulatorParam);
    catch ME
        errorInfo = sprintf('Can not find the modulatorClass %s.\nThere are two cases for this reason. \n\t\t\t(1):You provide wrong name of modulatorType. So please check your configurtions.\n\t\t\t(2):The channel.Factory doesn''t have the modulatorClass %s. Please define new modulatorClass based on the suggestion within the file of README.md.\n', modulatorParam.modulatorType, modulatorParam.modulatorType);
        Modulator.helpInfo();
        error(errorInfo);
    end

end
