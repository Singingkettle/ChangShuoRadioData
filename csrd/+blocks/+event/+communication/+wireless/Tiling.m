classdef Tiling < matlab.System
    % Tiling - Arranges wireless signals in the time and frequency domains
    %
    % This class implements a "tiling" strategy to position multiple transmitter
    % signals in both time and frequency domains with configurable overlap.
    %
    % Properties:
    %   IsOverlap - Boolean flag to enable/disable frequency overlap between signals
    %   OverlapRadio - Probability of overlap when IsOverlap is true (range: 0-1)
    %   FrequencyOverlapRadioRange - Range of overlap ratios [min, max] (range: 0-1)

    properties
        % IsOverlap - Enable/disable frequency overlap between signals
        % Default: false
        IsOverlap (1, 1) logical = false

        % OverlapRadio - Probability of overlap when IsOverlap is true
        % Range: 0-1, Default: 0.2
        OverlapRadio (1, 1) {mustBeNumeric, mustBeInRange(OverlapRadio, 0, 1)} = 0.2;

        % FrequencyOverlapRadioRange - Range of overlap ratios [min, max]
        % Range: 0-1 for each value, Default: [0, 0.1]
        FrequencyOverlapRadioRange (1, 2) {mustBeNumeric, mustBeInRange(FrequencyOverlapRadioRange, 0, 1)} = [0, 0.1];
    end

    methods

        function obj = Tiling(varargin)
            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)

        function [xs, txInfos, MasterClockRateRange, BandWidthRange] = stepImpl(obj, xs)
            % stepImpl - Positions signals in time and frequency domains
            %
            % Inputs:
            %   xs - Cell array of transmitter signals
            %        Each element is a cell array containing signal segments
            %        Each segment should have BandWidth, ModulatorType, SampleRate properties
            %
            % Outputs:
            %   xs - Updated signal array with assigned frequencies and start times
            %   txInfos - Cell array of transmitter information structures
            %             Each structure has CarrierFrequency, BandWidth, SampleRate fields
            %   MasterClockRateRange - [min, max] range for master clock rate in Hz
            %   BandWidthRange - [min, max] frequency range covered by all signals in Hz

            num_tx = length(xs);
            base_frequency = fix(10 ^ (rand(1) * 2 + 2) / 100) * 100;

            current_frequnecy_delta = 0;

            bound.left = 1e10;
            bound.right = 0;
            ts = linspace(0.001, 0.1, 100);
            max_sample_rate = 0;

            txInfos = cell(1, num_tx);

            for i = 1:num_tx
                min_left = 0;
                max_right = 0;

                for j = 1:length(xs{i})

                    if xs{i}{j}.BandWidth(1) < min_left
                        min_left = xs{i}{j}.BandWidth(1);
                    end

                    if xs{i}{j}.BandWidth(2) > max_right
                        max_right = xs{i}{j}.BandWidth(2);
                    end

                end

                current_band_width = max_right - min_left;

                % Set frequency spacing based on modulation type
                if strcmpi(xs{1}{1}.ModulatorType, 'OFDM') || strcmpi(xs{1}{1}.ModulatorType, 'SCFDMA') || strcmpi(xs{1}{1}.ModulatorType, 'OTFS') || strcmpi(xs{1}{1}.ModulatorType, 'CPFSK')
                    move_step = current_band_width + randi(100, 1) * 1e3;
                else
                    move_step = current_band_width + randi(100, 1) * 1e2;
                end

                if obj.IsOverlap

                    if rand(1) < obj.OverlapRadio && i > 1
                        % Apply overlap for signals after the first one
                        move_step = (1 - rand(1) * (obj.FrequencyOverlapRadioRange(2) - obj.FrequencyOverlapRadioRange(1))) * current_band_width;
                    end

                end

                move_step = floor(move_step / 100) * 100;
                current_frequnecy_delta = current_frequnecy_delta + move_step;

                current_start_time = 0;
                CarrierFrequency = current_frequnecy_delta + base_frequency - max_right;

                if CarrierFrequency + min_left < bound.left
                    bound.left = CarrierFrequency + min_left;
                end

                if CarrierFrequency + max_right > bound.right
                    bound.right = CarrierFrequency + max_right;
                end

                info.CarrierFrequency = CarrierFrequency;
                hbw = max(abs([min_left, max_right]));
                hbw = ceil(hbw / 100) * 100;

                if strcmpi(xs{i}{1}.ModulatorType, 'OFDM') || strcmpi(xs{i}{1}.ModulatorType, 'SCFDMA') || strcmpi(xs{i}{1}.ModulatorType, 'OTFS') || strcmpi(xs{i}{1}.ModulatorType, 'CPFSK')
                    bw = fix(hbw / 1000) * 1000 * 2;
                else
                    bw = 2 * hbw;
                end

                info.BandWidth = bw;

                for j = 1:length(xs{i})
                    x = xs{i}{j};
                    item_start_time = current_start_time + randsample(ts, 1);
                    x.StartTime = item_start_time;
                    x.CarrierFrequency = CarrierFrequency;
                    current_start_time = item_start_time + x.TimeDuration;
                    xs{i}{j} = x;
                end

                info.SampleRate = x.SampleRate;

                if max_sample_rate < x.SampleRate
                    max_sample_rate = x.SampleRate;
                end

                txInfos{i} = info;
            end

            % Set appropriate master clock rate range based on signal bandwidth
            if max_sample_rate > bound.right * 2
                MasterClockRateRange = [max_sample_rate + randi(10, 1) * 1e2, max_sample_rate + randi(10, 1) * 1e4];
            else
                MasterClockRateRange = [bound.right * 2 + randi(10, 1) * 1e2, bound.right * 2 + randi(10, 1) * 1e4];
            end

            BandWidthRange = [bound.left, bound.right];
        end

    end

end
