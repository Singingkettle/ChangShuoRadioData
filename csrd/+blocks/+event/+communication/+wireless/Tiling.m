classdef Tiling < matlab.System

    properties

        IsOverlap (1, 1) = false
        OverlapRadio = 0.2;
        FrequencyOverlapRadioRange = [0, 0.1];

    end

    methods

        function obj = Tiling(varargin)
            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)

        function [xs, MasterClockRateRange, BandWidth] = stepImpl(obj, xs)
            % 打乱顺序
            % 本质上采取的是一种类似贴瓷砖的策略，针对单个发射机，按照时域将数据依次排开
            % 紧接着，按照频域将数据依次排开
            num_tx = length(xs);
            base_frequency = fix(10 ^ (rand(1) * 2 + 2) / 100) * 100;

            current_frequnecy_delta = 0;

            bound.left = 1e10;
            bound.right = 0;
            ts = linspace(0.001, 0.1, 100);
            max_sample_rate = 0;

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
                % randi(100, 1)*1e2 随机设置的两个信号间的频率间隔
                move_step = current_band_width + randi(100, 1) * 1e2;

                if obj.IsOverlap

                    if rand(1) < obj.OverlapRadio
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

                for j = 1:length(xs{i})
                    x = xs{i}{j};
                    item_start_time = current_start_time + randsample(ts, 1);
                    x.StartTime = item_start_time;
                    x.CarrierFrequency = CarrierFrequency;
                    current_start_time = item_start_time + x.TimeDuration;
                    xs{i}{j} = x;
                end

                if max_sample_rate < x.SampleRate
                    max_sample_rate = x.SampleRate;
                end

            end

            if max_sample_rate * 2 > bound.right * 2
                MasterClockRateRange = [max_sample_rate * 2 + randi(10, 1) * 1e2, max_sample_rate * 2 + randi(10, 1) * 1e4];
            else
                MasterClockRateRange = [bound.right * 2 + randi(10, 1) * 1e2, bound.right * 2 + randi(10, 1) * 1e4];
            end

            BandWidth = [bound.left, bound.right];

        end

    end

end
