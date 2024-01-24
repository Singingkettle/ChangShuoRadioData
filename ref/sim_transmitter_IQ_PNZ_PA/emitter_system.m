classdef emitter_system < handle
    properties(Access = public)
        %%% transmit
        % signal
        numBits = 10040;
        modOrder = 16;
        baudrate = 1e6;
        fc = 433e6;
        % txfilter
        rolloff = 0.25;
        span = 10;
        sps = 8;
        % modulator
        ampImb = 3;
        phImb = 3;
        dcOffset = 5;
        phaseNoise_level = -70;
        phaseNoise_freq_offset = 1e3;
        % PA
        nonlinear_order = 7;
        memory_depth = 4;
        % txAnt
        dia = 0.4;
        eff = 0.55;
        
        %%% channel
        % air
        dist = 1;% m
        atmosCond = 'fs'; 
        % dopplor
        freq_offset = 1e3;
        % AWGN
        snr = 20;
        
        %%% receiver
        % rxAnt
%         dia = 0.4;
%         eff = 0.55;
        % DCcorrection
        % AGC
        % rxfilter
%         rolloff = 0.25;
%         span = 10;
%         sps = 8;
        % symbolSyn
        symbolSyn_sps = 4;
        % freqcorrection
        % IQimbalancecorrection
        
        % others
        flag_plot = false;%true;
    end
    properties(Dependent)
        fs
        txAntGain
        freeSpacePL
        pathLoss
    end
    
    methods
        function obj = transmitter(txParams)
            if nargin ~= 0
                % txfilter
                if isfield(txParams,'rolloff')
                    obj.rolloff = txParams.rolloff;
                end
                % modulator
                if isfield(txParams,'ampImb')
                    obj.ampImb = txParams.ampImb;
                end
                if isfield(txParams,'phImb')
                    obj.phImb = txParams.phImb;
                end
                if isfield(txParams,'dcOffset')
                    obj.dcOffset = txParams.dcOffset;
                end
                if isfield(txParams,'phaseNoise_level')
                    obj.phaseNoise_level = txParams.phaseNoise_level;
                end
                if isfield(txParams,'phaseNoise_freq_offset')
                    obj.phaseNoise_freq_offset = txParams.phaseNoise_freq_offset;
                end
                % PA
                if isfield(txParams,'nonlinear_order')
                    obj.nonlinear_order = txParams.nonlinear_order;
                end
                if isfield(txParams,'memory_depth')
                    obj.memory_depth = txParams.memory_depth;
                end
                % txAnt
                if isfield(txParams,'dia')
                    obj.dia = txParams.dia;
                end
                if isfield(txParams,'eff')
                    obj.eff = txParams.eff;
                end
            end
            
            if mod(obj.nonlinear_order,2) == 0
                error('Order must be odd.');
            end
        end
        function fs = get.fs(obj)
            fs = obj.baudrate*obj.sps;
            % disp("get.fs called");
        end
        function txAntGain = get.txAntGain(obj)
            lightSpeed = physconst('light');
            waveLength = lightSpeed/obj.fc;
            txAntGain = sqrt(obj.eff)*pi*obj.dia/waveLength;
            % disp("get.txAntGain called");
        end
        function freeSpacePL = get.freeSpacePL(obj)
            lightSpeed = physconst('light');
            waveLength = lightSpeed/obj.fc;
            freeSpacePL = fspl(obj.dist, waveLength);% freq是以Hz为单位，dist是以m为单位
            % disp("get.freeSpacePL called");
        end
        function pathLoss = get.pathLoss(obj)
            switch obj.atmosCond % Get path loss in dB
                case 'fg'   % Fog
                    den = .05; % Liquid water density in g/m^3
                    % Approximate maximum 18km for fog/cloud
                    pathLoss = obj.freeSpacePL + ...
                        fogpl( min(obj.dist, 18)*1000, obj.fc, T, den); 
                case 'fs'   % Free space
                    pathLoss = obj.freeSpacePL;  
                case 'gs'   % Gas
                    P = 101.325e3; % Dry air pressure in Pa
                    den = 7.5;     % Water vapor density in g/m^3
                    % Approximate maximum 100km for atmospheric gases
                    pathLoss = obj.freeSpacePL + ...
                        gaspl( min(obj.dist, 100)*1000, obj.fc, T, P, den);
                otherwise   % Rain
                    RR = 3; % Rain rate in mm/h
                    % Approximate maximum 2km for rain
                    pathLoss = obj.freeSpacePL + ...
                        rainpl(min(obj.dist, 2)*1000, obj.fc, RR);
            end
            % disp("get.pathLoss called");
        end

        
        function [txSig, dataIn] = get_signal_tx(obj)
            dataIn = randi([0 1], obj.numBits, 1);
            modData = qammod(dataIn, obj.modOrder, ...
              'InputType', 'bit', 'UnitAveragePower', true);
            % Filter signal
            TX_FILT = comm.RaisedCosineTransmitFilter(...
                'RolloffFactor',obj.rolloff, ...
                'FilterSpanInSymbols',obj.span, ...
                'OutputSamplesPerSymbol',obj.sps, ...
                'Gain',sqrt(obj.sps));
            txFiltOut = TX_FILT(modData); 
            % Add an I/Q imbalance to the signal.
            dcOffsetPh = pi*(2*rand-1);
            dcOffsetV = obj.dcOffset/100*max(abs(txFiltOut))* ...
                exp(1i*dcOffsetPh); % Convert percentage to voltage
            txImbalance = rfIQImbalance(txFiltOut,obj.ampImb,obj.phImb,dcOffsetV);
            % Add phase 
            PHASENOISE = comm.PhaseNoise('Level',obj.phaseNoise_level, ...
                'FrequencyOffset',obj.phaseNoise_freq_offset,'SampleRate',obj.fs);
            txPhaseNoise = PHASENOISE(txImbalance); 
            % In order to obtain the proper input value, the maximum input should be 0.8V.
            hapIn = txPhaseNoise/max(abs(txPhaseNoise))*0.8;
            % Amplify signal with HPA
            params.order = obj.nonlinear_order;
            params.memory_depth = obj.memory_depth;
            HPA = PowerAmplifier(params);
            hpaOut = HPA.transmit(hapIn); 
            % Apply transmit antenna gain
            txSig = obj.txAntGain*hpaOut;
            if obj.flag_plot == 1
                plot_constellation(txFiltOut, txImbalance, 'Add IQ imbalance');
                plot_constellation(txImbalance, txPhaseNoise, 'Add phase noise');
                plot_constellation(hapIn, hpaOut, 'HPA');
                plot_am_ampm(hapIn, hpaOut);
                plot_psd(hapIn,hpaOut,obj.fs,'');
            end
        end
        function rxSigAWGN = get_signal_channel(obj, txSig)
            % Channel operations
            rxSig = txSig/10^(obj.pathLoss/20); % Apply free-space loss
            PF_OFFSET = comm.PhaseFrequencyOffset(...
                'FrequencyOffsetSource','Input port','SampleRate',obj.fs);
            rxSigShift = PF_OFFSET(rxSig, obj.freq_offset); % Doppler shift
            rxSigAWGN = awgn(rxSigShift,obj.snr,'measured');
            if obj.flag_plot == 1
                plot_constellation(rxSig, rxSigShift, 'Doppler shift');
                plot_constellation(rxSigShift, rxSigAWGN, 'Add AWGN');
            end
        end
        function dataOut = get_signal_bits(obj, RF_IQ)
            % Create a DC Blocker object to remove the DC offset.
            DCBLOCK = dsp.DCBlocker('Order',6,'NormalizedBandwidth',0.0005);
            % Create an AGC object.
            AGC = comm.AGC('AveragingLength',256, 'MaxPowerGain',400);
            RX_FILT = comm.RaisedCosineReceiveFilter(...
                'RolloffFactor',obj.rolloff, ...
                'FilterSpanInSymbols',obj.span, ...
                'InputSamplesPerSymbol',obj.sps,...
                'DecimationFactor',obj.sps/obj.symbolSyn_sps, ...
                'Gain',1/sqrt(obj.sps));
            symbolSync = comm.SymbolSynchronizer( ...
                'SamplesPerSymbol',obj.symbolSyn_sps);
            coarse = comm.CoarseFrequencyCompensator(...
                'Modulation','QAM',...
                'FrequencyResolution',1,...
                'SampleRate',obj.fs);
            IQCOMP = comm.IQImbalanceCompensator('CoefficientSource','Input port');
            
            % correct DCOffset
            dcBlockerOut = DCBLOCK(RF_IQ);
            % Apply AGC
            AGCOut = AGC(dcBlockerOut);
            % Receive filter
            rxFiltOut = RX_FILT(AGCOut); % Receive filter
            % Symbol Synchronize
            rxFiltOut_syn = symbolSync(rxFiltOut);
            % Correct for Doppler
            doppCompOut = coarse(rxFiltOut_syn);
            % correct IQImbalance
            compCoef = iqimbal2coef(obj.ampImb,obj.phImb);
            iqCompOut = step(IQCOMP,doppCompOut,compCoef);
            % stepSize = 1e-2;
            % iqCompOut = IQCOMP(doppCompOut, stepSize); % Correct for I/Q imbalance
            dataOut = qamdemod(iqCompOut, obj.modOrder, ...
              'OutputType', 'bit', 'UnitAveragePower', true);  % Demodulate
            if obj.flag_plot == 1
                plot_constellation(RF_IQ, dcBlockerOut, 'correctDCOffset_{RECEIVE}');
                plot_constellation(dcBlockerOut, AGCOut, 'AGC_{RECEIVE}');
                plot_constellation(AGCOut, rxFiltOut, 'Receive Filter_{RECEIVE}','true');
                plot_constellation(rxFiltOut, rxFiltOut_syn, 'Symbol Synchronize_{RECEIVE}','true');
                plot_constellation(rxFiltOut_syn, doppCompOut, 'Correct for Doppler_{coarse}_{RECEIVE}','true');
                plot_constellation(doppCompOut, iqCompOut, 'correctIQImbalance_{RECEIVE}','true');
            end
        end
        function errStats = cal_BER(obj, dataIn, dataOut)
            delay = obj.span*log2(obj.modOrder);
            ERRCNT = comm.ErrorRate('ReceiveDelay',delay,...
                'ComputationDelay',0);
            % Calculate the error statistics.
            errStats = ERRCNT(dataIn,dataOut(1:size(dataIn,1)));
        end
        

        function cut_save(obj, input, sigargs, transmitterargs, SNR)
            num = size(input, 1)/sigargs.length_seg;
            for generate_num = 1:num
                a = (generate_num-1)*sigargs.length_seg+1;
                b = generate_num*sigargs.length_seg;
                seg0 = input(a:b);
                E_max=max( sqrt(seg0.*conj(seg0)) );
                norm_seg=seg0/E_max;

                if sigargs.format.output == "pic"
        %             pic_save(seg)
                    if sigargs.format.preprocess == "density"

                        num_rect = 200;
                        gray_matrix=zeros(num_rect);
                        len_rect = 2;
                        len_win = len_rect/num_rect;
                        for row=1:num_rect
                            for col=1:num_rect
                                gray_matrix(row,col) = obj.samps_in_windows(norm_seg,row,col,len_win)/length(norm_seg);
                            end
                        end
                        img=1-mat2gray(gray_matrix);

                    elseif sigargs.format.preprocess == "constellation"
                        plot(real(norm_seg(:)),imag(norm_seg(:)),'.');
                        axis([-1 1 -1 1])
                        axis off;
                        F = getframe;
                        fcdata = F.cdata(:,:,1);
                        img = im2double(fcdata);
                        img = rescale(imresize(img,[512 512]));
                    end
                    % 生成目录
                    directory = [...
                        './sim_pic/',char(sigargs.format.preprocess),...
                        '_snr',num2str(SNR),'_',num2str(num/1000),'kpics',...
                        '_',num2str(sigargs.length_seg),char(sigargs.label)];
                    if ~exist(directory,'dir')==1
                        disp(['directory is not exist, it will make dirs.'])
                        for i = transmitterargs.index
                            mkdir(directory, num2str(i))
                        end
                        directory
                    end
                    savePath = [directory,...
                        '/',num2str(transmitterargs.choice),...
                        '/',num2str(transmitterargs.choice),'_',num2str(generate_num),'.jpg'];
%                     imwrite(img, savePath);

                elseif sigargs.format.output == "seq"
                    if sigargs.format.preprocess == "RI"
                        oneterm = norm_seg;
                    elseif sigargs.format.preprocess == "AP"
                        amplitude = abs(norm_seg);
                        phase = angle(norm_seg);
                        seg_AP = amplitude + phase*(1i);
                        oneterm = seg_AP;
                    elseif sigargs.format.preprocess == "APsorted"
                        % 如果是采样后的信号（没通过接收滤波器），则不能排序
                        amplitude = abs(norm_seg);
                        phase = angle(norm_seg);
                        [phase_sorted,Index] = sort(phase);
                        amplitude_sorted = amplitude(Index);
                        seg_AP_sorted = amplitude_sorted + phase_sorted*(1i);
                        oneterm = seg_AP_sorted;
                    end

                    % oneterm = fft(oneterm);
                    oneterm_real = real(oneterm)';
                    oneterm_imag = imag(oneterm)';
                    oneterm = [oneterm_real; oneterm_imag];

                    % 生成目录
                    directory = [...
                        './sim_seq/',char(sigargs.format.preprocess),...
                        '_snr',num2str(SNR),'_',num2str(num/1000),'kitems',...
                        '_',num2str(sigargs.length_seg),char(sigargs.label)];
                    if ~exist(directory,'dir')==1
                        disp(['directory is not exist, it will make dirs.'])
                        for i = transmitterargs.index
                            mkdir(directory, num2str(i))
                        end
                        directory
                    end
                    savePath = [directory,...
                        '/',num2str(transmitterargs.choice),...
                        '/',num2str(transmitterargs.choice),'_',num2str(generate_num),'.mat'];
%                     save(savePath, 'oneterm');
                end
            end
        end
        function [total_nums]=samps_in_windows(~,sig_array,row,col,len_win)
            total_nums=length(find( ...
                real(sig_array)>=-1+(col-1)*len_win  &  ...
                real(sig_array)< -1+col*len_win      &  ...
                imag(sig_array)<=1-(row-1)*len_win   &  ...
                imag(sig_array)>1-row*len_win           ...
                ));
        end
        
        
    end
        
    methods(Static)


    end
    
end









