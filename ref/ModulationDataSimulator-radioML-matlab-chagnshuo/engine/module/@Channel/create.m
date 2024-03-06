function channelHandle = create(channelParam)
    try
        channelClassName = channelParam.channelType;
        classPointer = str2func(channelClassName);
        channelHandle = classPointer(channelParam);
    catch ME
        errorInfo = sprintf('Can not find the channelClass %s.\nThere are two cases for this reason. \n\t\t\t(1):You provide wrong name of channelType. So please check your configurtions.\n\t\t\t(2):The channel.Factory doesn''t have the channelClass %s. Please define new channelClass based on the suggestion within the file of README.md.\n', channelParam.channelType, channelParam.channelType);
        Channel.helpInfo();
        error(errorInfo);
    end

end
