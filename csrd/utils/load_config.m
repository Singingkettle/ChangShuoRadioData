function cfgs = load_config(cfgFilePath)

    fid = fopen(cfgFilePath, 'r');

    if fid == -1
        error('Cannot open the file: %s', cfgFilePath);
    end

    str = fread(fid, '*char')';
    fclose(fid);
    cfgs = jsondecode(str);

end
