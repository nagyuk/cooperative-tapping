% run_cooperative_tapping.m
% Simple script to test the cooperative tapping experiment in MATLAB

% Clear workspace
clear all;
close all;
clc;

% Add paths
addpath('../src');
addpath('../utils');

% Create configuration struct
config = struct();
config.SPAN = 500;      % 500ms target ITI
config.STAGE1 = 10;     % 10 taps in Stage 1
config.STAGE2 = 50;     % 50 taps in Stage 2
config.SHOW_TAP = true; % Show tap feedback
config.WRITE_OUTPUT = true;
config.LOG_DIR = '../logs';

% Select model type
model_types = {'sea', 'bayes', 'bib'};
fprintf('Select model type:\n');
for i = 1:length(model_types)
    fprintf('%d. %s\n', i, model_types{i});
end
choice = input('Enter choice (1-3): ');
model_type = model_types{choice};

% Create and run experiment
fprintf('\nInitializing experiment with %s model...\n', model_type);
exp = CooperativeTappingExperiment(config, model_type);

fprintf('Running experiment...\n');
fprintf('Press SPACE to tap, ESC to quit\n\n');
exp.runExperiment();

% Extract and analyze results
stim_tap = exp.stim_tap;
player_tap = exp.player_tap;

% Calculate metrics
stim_iti = TimingAnalysis.calculateITI(stim_tap);
player_iti = TimingAnalysis.calculateITI(player_tap);
se = TimingAnalysis.calculateSE(stim_tap, player_tap);

% Display results
fprintf('\n=== Experiment Results ===\n');
fprintf('Total taps: %d stimulus, %d player\n', length(stim_tap), length(player_tap));
fprintf('Mean ITI: %.2f ms (stimulus), %.2f ms (player)\n', ...
    mean(stim_iti), mean(player_iti));
fprintf('Mean SE: %.2f ms\n', mean(se));

% Save results
if config.WRITE_OUTPUT
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    filename = sprintf('%s/matlab_experiment_%s_%s.mat', ...
        config.LOG_DIR, model_type, timestamp);
    
    % Create log directory if it doesn't exist
    if ~exist(config.LOG_DIR, 'dir')
        mkdir(config.LOG_DIR);
    end
    
    % Save data
    save(filename, 'stim_tap', 'player_tap', 'stim_iti', 'player_iti', ...
        'se', 'config', 'model_type');
    fprintf('\nData saved to: %s\n', filename);
end

% Basic visualization
figure('Name', 'Cooperative Tapping Results');

% Plot ITIs
subplot(2,1,1);
plot(stim_iti, 'b-', 'LineWidth', 1.5);
hold on;
plot(player_iti, 'r-', 'LineWidth', 1.5);
xlabel('Tap Number');
ylabel('ITI (ms)');
title('Inter-Tap Intervals');
legend('Stimulus', 'Player');
grid on;

% Plot synchronization error
subplot(2,1,2);
plot(se, 'k-', 'LineWidth', 1.5);
xlabel('Tap Number');
ylabel('SE (ms)');
title('Synchronization Error');
grid on;

fprintf('\nExperiment complete!\n');
