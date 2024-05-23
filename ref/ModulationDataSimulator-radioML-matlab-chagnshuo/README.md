## Modulation Data Simulator

With the help of this project , You can simulate different kinds of data for modulation classification and RF.
Surprisingly, you can start multi-process to generate data for speed consideration. Cheers.

## Requirements

* Linux
* Matlab≥2019a

## Diagram

There are mainly three kinds of Classes to control the generation process. Their relationship is:

![relationship](./img/relationship.svg)

The whole generation pipeline is defined in the ModulatorClass file, for example **BPSKModulator.m**.:

```matlab
    methods(Access = protected)
        function y = stepImpl(obj)
            % Implement algorithm. Calculate y as a function of input u and
            % discrete states.
            % Modulate
            % Generate random data
            x = obj.sourceHandle();

            % Modulate
            syms = pskmod(x, 2);
            y = filter(obj.filterCoefficients, 1, upsample(syms, ...
                obj.samplePerSymbol));
            
            % Pass through independent channels
            y = obj.channelHandle(y);
            
            % Remove transients from the beginning, trim to size, 
            % and normalize
            y = obj.clean(y, obj.windowLength, obj.stepSize, ...
                obj.offset, obj.samplePerSymbol);
            
            % Save as file
            is_success = obj.save(y, fullfile(obj.filePrefix, ...
                obj.modulatorType));
            if(~is_success) 
                error('Something Wrong with the Save Process!!!');
            end
        end

    end
```

## Usage

It's very convenient for you to generate data by the tool. You can drink a cup of milk-tea or whatever, then everything
is ok.

#### Run Demo

Before you get start, you can glance the whole project by running the [demo.m](./tool/demo.m) script.

```bash
cd {PROJECT_FOLDER}/ModulationDataSimulator/tool
YOUR_MATLAB_INSTALL_FOLDER/bin/matlab -nosplash -r "run demo.m" 
```

After that, the generated data is saved in the [data](./data) folder. The saved data is a two column matrix. The first
column is real data. The second column is imag data.

#### Generate Your Own Data

1. Write your own [**.yaml]() file in the folder [config](./config), for example:

```yaml
# The parameter filePrefix sets the folder location, where the generated data should be saved. 
filePrefix: 'D:\Projects\AMC\ModulationDataSimulator\data\'
# The parameter modulatorType defines the different modulators.
modulatorType: ['BPSK', 'QPSK']
```

2. Run the bash script to start generation:

```bash
cd {PROJECT_FOLDER}/ModulationDataSimulator/tool
# The config file path is defined in the first step.
bash multi.sh 
```

## Add New Modulator

You can add new modulator very simple. There are two steps:

1. Add new **source** class in the folder "engine/module/Classes/Source".

    * Make sure the new modulator belongs to PSK or other types. If it cannot be classified, you should make new folder:

      ```bash
      mkdir NEW_FOLDER
      ```
    * Write new class script "NEWData.m", for example:
      ```matlab
      classdef BPSKData<matlab.System
          %INPUTDATABPSK 此处显示有关此类的摘要
          %   此处显示详细说明
     
          properties
         M=2
              samplePerSymbol
              samplePerFrame
          end
          
          methods
              function obj = BPSKData(dataParam)
                  %INPUTDATABPSK 构造此类的实例
                  %   此处显示详细说明
                  obj.samplePerFrame = dataParam.samplePerFrame;
                  obj.samplePerSymbol = dataParam.samplePerSymbol;
              end
          end
          
          methods(Access = protected)
              function y = stepImpl(obj)
                  % Implement algorithm. Calculate y as a function of input u and
                  % discrete states.
                  y = randi([0 obj.M-1], ...
                      2*obj.samplePerFrame/obj.samplePerSymbol, 1);
              end
      
          end
      end
      ```

2. Add new **modulator** class in the folder "engine/module/Classes/Modulator".

    * Make sure the new modulator belongs to PSK or other types. If it cannot be classified, you should make new folder:

      ```bash
      mkdir NEW_FOLDER
      ```
    * Write new class script "NEWModulator.m", for example:
      ```matlab
      classdef BPSKModulator<baseModulator
          %BPSKMODULATOR 此处显示有关此类的摘要
          %   此处显示详细说明
          
          properties
              modulatorType = 'BPSK'
              sourceHandle
              channelHandle
              filterCoefficients
              samplePerSymbol
              samplePerFrame
              windowLength
              stepSize
              offset
              filePrefix 
          end
          
          methods
              function obj = BPSKModulator(modulatorParam)
                  %BPSKMODULATOR 构造此类的实例
                  %   此处显示详细说明
                  
                  % 构造数据生成器句柄
                  obj.sourceHandle = ...
                      Source.create(modulatorParam.sourceParam);
                  
                  % 构造信道句柄
                  obj.channelHandle = ...
                      Channel.create(modulatorParam.channelParam);
                  
                  % 生成平方根升余玄滚降滤波器的系数值
                  obj.filterCoefficients = modulatorParam.filterCoefficients;
                  
                  %
                  obj.samplePerSymbol = modulatorParam.samplePerSymbol;
                  obj.samplePerFrame = modulatorParam.samplePerFrame;
                  obj.windowLength = modulatorParam.windowLength;
                  obj.stepSize = modulatorParam.stepSize;
                  obj.offset = modulatorParam.offset;
                  obj.filePrefix = modulatorParam.filePrefix;
      
              end
          end
          
          methods(Access = protected)
              function y = stepImpl(obj)
                  % Implement algorithm. Calculate y as a function of input u and
                  % discrete states.
                  % Modulate
                  % Generate random data
                  x = obj.sourceHandle();
      
                  % Modulate
                  syms = pskmod(x, 2);
                  y = filter(obj.filterCoefficients, 1, upsample(syms, ...
                      obj.samplePerSymbol));
                  
                  % Pass through independent channels
                  y = obj.channelHandle(y);
                  
                  % Remove transients from the beginning, trim to size, 
                  % and normalize
                  y = obj.clean(y, obj.windowLength, obj.stepSize, ...
                      obj.offset, obj.samplePerSymbol);
                  
                  % Save as file
                  is_success = obj.save(y, fullfile(obj.filePrefix, ...
                      obj.modulatorType));
                  if(~is_success) 
                      error('Something Wrong with the Save Process!!!');
                  end
              end
      
          end
      end
      
      
      ```

## TODO

* Add handcrafted Feature
* Add comments

## Thanks

The whole project use the factory mod to design the generation process of modulator data.

## Ref

[1] [Matlab工厂模式(Factory)](https://blog.csdn.net/u014595589/article/details/90191317)

## Citing AMC

If you use AMC in your research, please use the following BibTeX entry.

```BibTeX
@misc{WTI2020amc,
  author =       {Shuo Chang},
  title =        {AMC},
  howpublished = {\url{}},
  year =         {2020}
}
```

