classdef CooperativeTappingExperiment < handle
    %COOPERATIVETAPPINGEXPERIMENT Main experiment class for cooperative tapping
    %   This class implements the cooperative tapping experiment using
    %   Psychtoolbox for precise timing and audio control.
    
    properties
        % Configuration
        config          % Experiment configuration struct
        model_type      % Type of model ('sea', 'bayes', 'bib')
        
        % PTB handles
        window          % PTB window handle
        audio_device    % PsychPortAudio device handle
        
        % Timing data
        clock_offset    % Clock synchronization offset
        stim_tap        % Stimulus tap times
        player_tap      % Player tap times
        
        % Experiment state
        current_stage   % Current stage (1 or 2)
        trial_count     % Number of trials completed
        is_running      % Experiment running flag
    end
    
    properties (Constant)
        % Audio parameters
        SAMPLE_RATE = 44100;
        N_CHANNELS = 2;
        LATENCY_BIAS = 0.005;  % 5ms latency bias for audio
        
        % Key mappings
        RESPONSE_KEY = 'space';
        QUIT_KEY = 'escape';
    end
    
    methods
        function obj = CooperativeTappingExperiment(config, model_type)
            %COOPERATIVETAPPINGEXPERIMENT Constructor
            %   config: struct with experiment parameters
            %   model_type: string ('sea', 'bayes', or 'bib')
            
            % Store configuration
            obj.config = config;
            obj.model_type = model_type;
            
            % Initialize arrays
            obj.stim_tap = [];
            obj.player_tap = [];
            
            % Initialize state
            obj.current_stage = 1;
            obj.trial_count = 0;
            obj.is_running = false;
            
            % Initialize PTB
            obj.initializePTB();
        end
        
        function initializePTB(obj)
            %INITIALIZEPTB Initialize Psychtoolbox components
            
            % Set up PTB with default settings
            PsychDefaultSetup(2);
            
            % Set verbosity to minimal
            Screen('Preference', 'Verbosity', 1);
            
            % Initialize audio
            InitializePsychSound(1);  % Low-latency mode
            
            % Open audio device with minimal latency
            obj.audio_device = PsychPortAudio('Open', [], ...
                1+8, ...  % Master mode + minimal latency
                1, ...    % Mono output
                obj.SAMPLE_RATE, ...
                1, ...    % Single channel
                [], ...
                obj.LATENCY_BIAS);
            
            % Set high priority
            Priority(MaxPriority(0));
            
            % Warm up timing functions
            GetSecs;
            WaitSecs(0.001);
        end
        
        function runExperiment(obj)
            %RUNEXPERIMENT Main experiment execution method
            
            try
                obj.is_running = true;
                
                % Stage 1: Solo tapping
                fprintf('Starting Stage 1: Solo tapping\n');
                obj.runStage1();
                
                % Brief pause between stages
                WaitSecs(2.0);
                
                % Stage 2: Cooperative tapping
                fprintf('Starting Stage 2: Cooperative tapping\n');
                obj.current_stage = 2;
                obj.runStage2();
                
                fprintf('Experiment completed successfully\n');
                
            catch ME
                obj.cleanup();
                rethrow(ME);
            end
            
            obj.is_running = false;
            obj.cleanup();
        end
        
        function cleanup(obj)
            %CLEANUP Clean up PTB resources
            
            % Close audio device
            if ~isempty(obj.audio_device)
                PsychPortAudio('Close', obj.audio_device);
            end
            
            % Reset priority
            Priority(0);
            
            % Close any open screens
            sca;
        end
        
        function delete(obj)
            %DELETE Destructor
            obj.cleanup();
        end
    end
    
    methods (Access = protected)
        function runStage1(obj)
            %RUNSTAGE1 Implementation placeholder for Stage 1
            % To be implemented in next iteration
            fprintf('Stage 1 implementation pending...\n');
        end
        
        function runStage2(obj)
            %RUNSTAGE2 Implementation placeholder for Stage 2
            % To be implemented in next iteration
            fprintf('Stage 2 implementation pending...\n');
        end
    end
end
