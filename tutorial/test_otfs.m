
clear;

%--------------------------------------------------------------------------
% 定义仿真参数
%--------------------------------------------------------------------------
M = 16;                         % 调制阵列大小
k = log2(M);                    % 每个符号的比特数
cpSize = 0.07;                  % OFDM循环前缀大小
scs = 15e3;                     % 子载波间距，单位赫兹
Bw = 10e6;                      % 系统带宽，单位赫兹
ofdmSym = 14;                   % 每个子帧的OFDM符号数
EbNo = (-3:1:30)';              % 每比特能量与噪声功率之比的范围
velocity = 120;                 % 移动接收机相对于发送机的速度，单位千米/小时
codeRate = 2/4;                 % 使用的FEC编码效率
maxIterations = 25;             % LDPC解码器的最大迭代次数
totalBits = 1e6;                % 模拟的总比特数
repeats = 1;                    % 仿真重复次数

%--------------------------------------------------------------------------
% 初始化仿真组件
%--------------------------------------------------------------------------

% 初始化OFDM调制/解调变量
numSC = pow2(ceil(log2(Bw/scs))); % 计算最接近的2的幂的OFDM子载波数
cpLen = floor(cpSize * numSC);    % 计算循环前缀长度
numDC = (numSC - 12);             % 计算数据载波数

% 初始化AWGN信道
awgnChannel = comm.AWGNChannel('NoiseMethod','Variance', 'VarianceSource','Input port');
errorRate = comm.ErrorRate('ResetInputPort',true);
errorRate1 = comm.ErrorRate('ResetInputPort',true);

% 初始化LDPC编码器/解码器
parityCheck_matrix = dvbs2ldpc(codeRate);
ldpcEncoder = comm.LDPCEncoder(parityCheck_matrix);
ldpcDecoder = comm.LDPCDecoder(parityCheck_matrix);
ldpcDecoder.MaximumIterationCount = maxIterations;
noCodedbits = size(parityCheck_matrix,2);

% 创建用于存储误差数据的向量
berOFDM = zeros(length(EbNo),3);
berCOFDM = zeros(length(EbNo),3);
berOTFS = zeros(length(EbNo),3);
berCOTFS = zeros(length(EbNo),3);
errorStats_coded = zeros(1,3);
errorStats_uncoded = zeros(1,3);

for repetition=1:repeats                                % 使用每次不同信道重复仿真
    
    % 生成和编码数据
    [dataIn, dataBits_in, codedData_in, packetSize, numPackets, numCB] = dataGen(k,numDC,ofdmSym,totalBits,codeRate,ldpcEncoder);
    
    % 生成瑞利衰落信道脉冲响应
    txSig_size = zeros((numSC+cpLen),ofdmSym);
    rayChan = multipathChannel(cpSize, scs, txSig_size, velocity);
    
    % QAM调制
    qamTx = qammod(dataIn,M,'InputType','bit','UnitAveragePower',true);
    parallelTx = reshape(qamTx,[numDC,ofdmSym*packetSize]);
    guardbandTx = [zeros(1,ofdmSym*packetSize); parallelTx];
    guardbandTx = [guardbandTx(1:(numDC/2),:); zeros(11,ofdmSym*packetSize); guardbandTx((numDC/2)+1:end,:)];
    
    %--------------------------------------------------------------------------
    %                       OFDM误码率计算
    %--------------------------------------------------------------------------
    
    % 计算信噪比
    snr = EbNo + 10*log10(codeRate*k) + 10*log10(numDC/((numSC)));
    
    % 多载波调制
    frameBuffer = guardbandTx;
    txframeBuffer = [];
    for w = 1:packetSize
        ofdmTx = modOFDM(frameBuffer(:,1:ofdmSym),numSC,cpLen,ofdmSym);
        frameBuffer(:, 1:ofdmSym) = [];
        txframeBuffer = [txframeBuffer;ofdmTx];
    end
    
    % 循环不同的EbNo值
    for m = 1:length(EbNo)
        % 循环传输的数据包
        for j = 1:numPackets
            rxframeBuffer = [];
            
            % 逐个传输每个子帧
            for u = 1:packetSize
                
                txSig = txframeBuffer( ((u-1)*numel(ofdmTx)+1) : u*numel(ofdmTx) );
                
                % 将信道应用到输入信号
                %                 fadedSig1 = zeros(size(txSig));
                %                 for i = 1:size(txSig,1)
                %                     for j = 1:size(txSig,2)
                %                         fadedSig1(i,j) = txSig(i,j).*rayChan(i,j);
                %                     end
                %                 end
                fadedSig=txSig;
                
                % AWGN信道
                release(awgnChannel);
                powerDB = 10*log10(var(fadedSig));
                noiseVar = 10.^(0.1*(powerDB-snr(m)));
                rxSig = awgnChannel(fadedSig,noiseVar);
                
                % 均衡
                eqSig = equaliser(rxSig,fadedSig,txSig,ofdmSym);
                
                % 解调
                rxSubframe = demodOFDM(eqSig,cpLen,ofdmSym);
                rxframeBuffer = [rxframeBuffer';rxSubframe']';
            end
            
            parallelRx = rxframeBuffer;
            parallelRx((numDC/2)+1:(numDC/2)+11, :) = [];
            parallelRx(1:1, :) = [];
            qamRx = reshape(parallelRx,[numel(parallelRx),1]);
            dataOut = qamdemod(qamRx,M,'OutputType','bit','UnitAveragePower',true);
            codedData_out = randdeintrlv(dataOut,4831);
            codedData_out(numel(codedData_in)+1:end) = [];
            errorStats_uncoded = errorRate(codedData_in,codedData_out,0);
            
            powerDB = 10*log10(var(qamRx));
            noiseVar = 10.^(0.1*(powerDB-(EbNo(m) + 10*log10(codeRate*k) - 10*log10(sqrt(numDC)))));
            dataOut = qamdemod(qamRx,M,'OutputType', 'approxllr','UnitAveragePower',true,'NoiseVariance',noiseVar);
            codedData_out1 = randdeintrlv(dataOut,4831);
            codedData_out1(numel(codedData_in)+1:end) = [];
            dataBits_out = [];
            dataOut_buffer = codedData_out1;
            for q = 1:numCB
                dataBits_out = [dataBits_out;ldpcDecoder(dataOut_buffer(1:noCodedbits))];
                dataOut_buffer(1:noCodedbits) = [];
            end
            dataBits_out = double(dataBits_out);
            errorStats_coded = errorRate1(dataBits_in,dataBits_out,0);
            
        end
        berOFDM(m,:) = errorStats_uncoded;
        berCOFDM(m,:) = errorStats_coded;
        errorStats_uncoded = errorRate(codedData_in,codedData_out,1);
        errorStats_coded = errorRate1(dataBits_in,dataBits_out,1);
    end
    %--------------------------------------------------------------------------
    %                       OTFS误码率计算
    %--------------------------------------------------------------------------
    
    % 计算信噪比
    snr = EbNo + 10*log10(codeRate*k) + 10*log10(numDC/((numSC))) + 10*log10(sqrt(ofdmSym));
    
    % 多载波调制
    frameBuffer = guardbandTx;          % 创建一个“缓冲区”，以便可以单独调制子帧
    txframeBuffer = [];                 % 初始化矩阵
    for w = 1:packetSize
        otfsTx = ISFFT(frameBuffer(:,1:ofdmSym));       % 对数据的子帧应用OTFS调制
        ofdmTx = modOFDM(otfsTx,numSC,cpLen,ofdmSym);    % 应用OFDM调制
        frameBuffer(:, 1:ofdmSym) = [];                  % 从frameBuffer中删除调制后的数据
        txframeBuffer = [txframeBuffer;ofdmTx];          % 将调制后的子帧添加到传输缓冲区
    end
    
    % 循环遍历不同的EbNo值
    for m = 1:length(EbNo)
        % 循环遍历要传输的数据包
        for j = 1:numPackets
            rxframeBuffer = [];                 % 初始化矩阵
            
            % 单独传输每个子帧
            for u = 1:packetSize
                
                % 从传输缓冲区中移除下一个子帧
                txSig = txframeBuffer( ((u-1)*numel(ofdmTx)+1) : u*numel(ofdmTx) );
                
                % 将信道应用到输入信号
                fadedSig = zeros(size(txSig));                    % 预先分配向量大小
                for i = 1:size(txSig,1)                           % 执行逐元素...
                    for j = 1:size(txSig,2)                       % ...矩阵乘法
                        fadedSig(i,j) = txSig(i,j).*rayChan(i,j);
                    end
                end
                fadedSig = txSig.*rayChan;
                % AWGN信道
                release(awgnChannel);
                powerDB = 10*log10(var(fadedSig));                 % 计算发送信号功率
                noiseVar = 10.^(0.1*(powerDB-snr(m)));             % 计算噪声方差
                rxSig = awgnChannel(fadedSig,noiseVar);            % 通过有噪声的信道传递信号
                
                % 均衡
                eqSig = equaliser(rxSig,fadedSig,txSig,ofdmSym);
                
                % 解调
                otfsRx = demodOFDM(eqSig,cpLen,ofdmSym);           % 应用OFDM解调
                rxSubframe = SFFT(otfsRx);                         % 应用OTFS解调
                rxframeBuffer = [rxframeBuffer';rxSubframe']';     % 将解调后的子帧存储在rx缓冲区中
            end
            % 移除所有空载波
            parallelRx = rxframeBuffer;
            parallelRx((numDC/2)+1:(numDC/2)+11, :) = [];         % 移除中心DC周围的空载波
            parallelRx(1:1, :) = [];                              % 移除索引1处的空载波
            qamRx = reshape(parallelRx,[numel(parallelRx),1]);    % 转换为串行
            
            % 对整个数据包进行无编码解调
            dataOut = qamdemod(qamRx,M,'OutputType','bit','UnitAveragePower',true);% 应用QAM解调
            codedData_out = randdeintrlv(dataOut,4831);                            % 反交织数据
            codedData_out(numel(codedData_in)+1:end) = [];                         % 移除填充位
            errorStats_uncoded = errorRate(codedData_in,codedData_out,0);          % 收集误码统计信息
            
            % 对整个数据包进行编码解调
            powerDB = 10*log10(var(qamRx));                                   % 计算接收信号功率
            noiseVar = 10.^(0.1*(powerDB-(EbNo(m) + 10*log10(codeRate*k) - 10*log10(sqrt(numDC)))));            % 计算噪声方差
            dataOut = qamdemod(qamRx,M,'OutputType', 'approxllr','UnitAveragePower',true,'NoiseVariance',noiseVar);% 应用QAM解调
            codedData_out1 = randdeintrlv(dataOut,4831);                      % 反交织数据
            codedData_out1(numel(codedData_in)+1:end) = [];                   % 移除填充位
            
            % 解码各个码块
            dataBits_out = [];                                                % 初始化矩阵
            dataOut_buffer = codedData_out1;
            for q = 1:numCB
                dataBits_out = [dataBits_out;ldpcDecoder(dataOut_buffer(1:noCodedbits))]; % 解码数据并将其添加到数据位输出矩阵中
                dataOut_buffer(1:noCodedbits) = [];                                       % 从缓冲区中删除已解码的数据
            end
            dataBits_out = double(dataBits_out);                              % 转换为与errorStats兼容的double类型
            errorStats_coded = errorRate1(dataBits_in,dataBits_out,0);     % 收集误码统计信息
            
        end
        berOTFS(m,:) = errorStats_uncoded;                                  % 保存无编码BER数据
        berCOTFS(m,:) = errorStats_coded;                                   % 保存编码BER数据
        errorStats_uncoded = errorRate(codedData_in,codedData_out,1);       % 重置误码率计算器
        errorStats_coded = errorRate1(dataBits_in,dataBits_out,1);          % 重置误码率计算器
        
    end
    
end

%--------------------------------------------------------------------------
%                           图表
%--------------------------------------------------------------------------

% 绘制BER / EbNo曲线
plotGraphs(berOFDM, berCOFDM, berOTFS, berCOTFS, M, numSC, EbNo);
