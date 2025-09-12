classdef TimingAnalysis
    %TIMINGANALYSIS Utility class for timing analysis
    %   This class provides static methods for analyzing timing data
    %   from the cooperative tapping experiment.
    
    methods (Static)
        function iti = calculateITI(tap_times)
            %CALCULATEITI Calculate inter-tap intervals
            %   tap_times: vector of tap timestamps
            %   Returns: vector of ITIs in milliseconds
            
            if length(tap_times) < 2
                iti = [];
                return;
            end
            
            iti = diff(tap_times) * 1000;  % Convert to milliseconds
        end
        
        function se = calculateSE(stim_tap, player_tap)
            %CALCULATESE Calculate synchronization error
            %   stim_tap: stimulus tap times
            %   player_tap: player tap times
            %   Returns: synchronization error in milliseconds
            
            % Find matching taps (simple nearest neighbor)
            se = [];
            for i = 1:length(player_tap)
                [min_diff, ~] = min(abs(stim_tap - player_tap(i)));
                if min_diff < 1.0  % Within 1 second
                    se(end+1) = min_diff * 1000;  % Convert to ms
                end
            end
        end
        
        function stats = computeStatistics(data)
            %COMPUTESTATISTICS Compute basic statistics
            %   data: vector of timing measurements
            %   Returns: struct with mean, std, median
            
            stats.mean = mean(data);
            stats.std = std(data);
            stats.median = median(data);
            stats.cv = stats.std / stats.mean;  % Coefficient of variation
        end
    end
end
