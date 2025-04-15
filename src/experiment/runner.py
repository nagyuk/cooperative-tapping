"""
Main experiment runner for cooperative tapping task.
Handles experiment flow, data collection, and UI interactions.
"""
import os
import datetime
import numpy as np
import pandas as pd

# PsychoPyのオーディオ設定を先に行う
from psychopy import prefs
# サウンドバックエンドの優先順位を設定（利用可能なもので最適なものを使用）
prefs.hardware['audioLib'] = ['pygame', 'ptb', 'sounddevice', 'pyo']
# 音声バッファサイズを大きくして安定性を向上
prefs.hardware['audioBufferSize'] = 512
# 音声レイテンシーを許容
prefs.hardware['audioLatencyMode'] = 3

# その他のpsychopyモジュールをインポート
from psychopy import visual, core, event, sound

from ..models import SEAModel, BayesModel, BIBModel

class ExperimentRunner:
    """Runner for the cooperative tapping experiment."""
    
    def __init__(self, config, model_type='sea', output_dir='data/raw'):
        """Initialize experiment with configuration and model.
        
        Args:
            config: Configuration object
            model_type: Type of model to use ('sea', 'bayes', 'bib')
            output_dir: Directory to save output data
        """
        self.config = config
        self.model_type = model_type
        self.output_dir = output_dir
        
        # Initialize model based on type
        if model_type.lower() == 'sea':
            self.model = SEAModel(config)
        elif model_type.lower() == 'bayes':
            self.model = BayesModel(config)
        elif model_type.lower() == 'bib':
            self.model = BIBModel(config, l_memory=1)
        else:
            raise ValueError(f"Unknown model type: {model_type}")
        
        # Initialize experiment data
        self.reset_data()
        
        # Generate experiment ID
        t_delta = datetime.timedelta(hours=9)
        JST = datetime.timezone(t_delta, 'JST')
        now = datetime.datetime.now(JST)
        self.serial_num = now.strftime('%Y%m%d%H%M')
        
        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
        
        # UI components
        self.win = None
        self.sound_stim = None
        self.sound_player = None
        self.text = None
        self.clock = None
        self.timer = None
    
    def reset_data(self):
        """Reset experiment data."""
        # Initialize tap time lists with initial values
        self.stim_tap = [self.config.SPAN * self.config.STAGE1]
        self.player_tap = [self.config.SPAN * (self.config.STAGE1 - 1/2)]
        
        # Initialize empty lists for derived measures
        self.stim_iti = []
        self.player_iti = []
        self.stim_itiv = []
        self.player_itiv = []
        self.stim_se = []
        self.player_se = []
        self.stim_sev = []
        self.player_sev = []
        
        # For Bayesian models, store hypothesis data
        self.hypo = []
        
        # Keep original full data for research purposes
        self.full_stim_tap = []
        self.full_player_tap = []
    
    def setup_ui(self):
        """Set up UI components for the experiment."""
        # Create window with optimized settings for stable timing
        self.win = visual.Window(
            size=(800, 600), 
            monitor="testMonitor",
            color="black",
            fullscr=False,
            winType='pyglet',
            allowGUI=True,
            waitBlanking=False  # VSyncを無効化して安定したタイミングを確保
        )
        
        
        # Set up sounds with debug info
        print(f"INFO: 音声ファイルパス - 刺激音: {self.config.SOUND_STIM}")
        print(f"INFO: 音声ファイルパス - プレーヤー音: {self.config.SOUND_PLAYER}")
        
        # WAVファイルが存在するか確認
        if not os.path.exists(self.config.SOUND_STIM):
            print(f"警告: 刺激音ファイルが見つかりません: {self.config.SOUND_STIM}")
        if not os.path.exists(self.config.SOUND_PLAYER):
            print(f"警告: プレーヤー音ファイルが見つかりません: {self.config.SOUND_PLAYER}")
            
        # 音声バックエンドの情報を表示
        if hasattr(sound, 'audioLib'):
            print(f"INFO: 使用中の音声バックエンド: {sound.audioLib}")
        else:
            print("INFO: 音声バックエンド情報が取得できません")
        
        # 明示的にWAVファイルを指定して音声オブジェクトを作成
        try:
            # 絶対パスを使用してWAVファイルを直接指定
            self.sound_stim = sound.Sound(str(self.config.SOUND_STIM))
            self.sound_player = sound.Sound(str(self.config.SOUND_PLAYER))
            print("INFO: 音声オブジェクト作成成功")
        except Exception as e:
            print(f"エラー: 音声オブジェクト作成中に問題が発生しました: {e}")
        
        # Set up text
        self.text = visual.TextStim(
            self.win,
            text="Press SPACE to play rhythm",
            color="white",
            height=0.05
        )
        
        # Set up clocks
        self.clock = core.Clock()  # For measuring tap times
        self.timer = core.Clock()  # For timing events
    
    def run_stage1(self):
        """Run Stage 1 of the experiment (metronome phase)."""
        stage1_num = 0
        
        # Display instructions
        self.text.setText("Stage 1: Listen to the rhythm\nPress SPACE to start")
        self.text.draw()
        self.win.flip()
        
        # Wait for space to start
        event.waitKeys(keyList=['space'])
        
        # Start countdown
        for countdown in range(3, 0, -1):
            self.text.setText(str(countdown))
            self.text.draw()
            self.win.flip()
            core.wait(1.0)
        
        # Reset timer and clock
        self.timer.reset()
        self.clock.reset()
        
        # Display tapping instructions
        self.text.setText("Listen to the rhythm")
        
        # Event loop for Stage 1
        while True:
            # Display instructions
            self.text.draw()
            self.win.flip()
            
            # Play sound at fixed interval
            if self.timer.getTime() >= self.config.SPAN:
                stage1_num += 1
                # 音声の状態をチェック
                if hasattr(self.sound_stim, 'status') and self.sound_stim.status == 1:
                    # 既に再生中の場合は止めてから再生
                    self.sound_stim.stop()
                    # 完全に停止するまで少し待機
                    core.wait(0.02)
                    
                # 音声再生と完了を待機
                self.sound_stim.play()
                
                # より長い待機時間で安定性向上（再生が完了するのを待つ）
                core.wait(0.1)
                
                # Record stimulus tap time
                current_time = self.clock.getTime()
                self.stim_tap.append(current_time)
                self.full_stim_tap.append(current_time)
                
                self.timer.reset()
            
            # Check for key press
            keys = event.getKeys()
            if 'space' in keys:
                # Record player tap time
                current_time = self.clock.getTime()
                self.player_tap.append(current_time)
                self.full_player_tap.append(current_time)
                
                # 音声の状態をチェック
                if hasattr(self.sound_player, 'status') and self.sound_player.status == 1:
                    # 既に再生中の場合は止めてから再生
                    self.sound_player.stop()
                    # 完全に停止するまで少し待機
                    core.wait(0.02)
                    
                # 音声再生と完了を待機
                self.sound_player.play()
                
                # より長い待機時間で安定性向上（再生が完了するのを待つ）
                core.wait(0.1)
            
            if 'escape' in keys:
                self.win.close()
                core.quit()
                return False
            
            # Exit after STAGE1 sounds
            if stage1_num >= self.config.STAGE1:
                # Ensure we have at least one player tap before starting Stage 2
                if not self.player_tap:
                    # Add a dummy player tap if none were recorded
                    estimated_tap = self.stim_tap[-1] - self.config.SPAN/2
                    self.player_tap.append(estimated_tap)
                    self.full_player_tap.append(estimated_tap)
                
                # 最後のタップ時刻を記録して次のタイミングを正確に計算するため
                self.last_stim_tap_time = self.stim_tap[-1]
                
                # ステージ2のタップ回数をテスト用に30回に設定
                self.config.STAGE2 = 30
                
                return True
    
    def run_stage2(self):
        """Run Stage 2 of the experiment (interactive tapping)."""
        flag = 1  # 0: Player's turn, 1: Stimulus turn
        turn = 0
        
        # ステージ間の連続性を保つため、待機時間を削除し、テキストのみ更新
        # テキストを小さく表示してリズムの妨げにならないようにする
        self.text.setText("Stage 2: Alternating")
        self.text.setHeight(0.03)  # テキストサイズを小さく
        self.text.setPos([0, 0.8])  # 画面上部に表示
        self.text.draw()
        self.win.flip()
        
        # タイマーのリセットを行わず、run_stage1からの時間的連続性を保つ
        # 最後のタップからの時間を計算して最適なタイミングを設定
        elapsed_since_last_tap = self.clock.getTime() - self.last_stim_tap_time
        # 次のタップが最適なタイミングになるよう計算
        next_tap_due = self.config.SPAN - elapsed_since_last_tap
        
        # 次のタップまでの時間が短すぎる場合は安全マージンを追加
        if next_tap_due < 0.3:
            next_tap_due = 0.3  # 最低でも300ms待機
        
        # 元のランダム性を維持（base0.pyなどと同一）
        random_second = next_tap_due + np.random.normal(0, self.config.SCALE)
        
        # Start message
        self.text.setText("Follow the rhythm")
        self.text.setHeight(0.03)  # 小さめのテキスト
        self.text.setPos([0, 0.7])  # 画面上部寄りに配置
        
        # Event loop for Stage 2
        while True:
            # Display instructions
            self.text.draw()
            self.win.flip()
            
            # Stimulus turn
            if self.timer.getTime() >= random_second and flag == 1:
                # 音声の状態をチェック
                if hasattr(self.sound_stim, 'status') and self.sound_stim.status == 1:
                    # 既に再生中の場合は止めてから再生
                    self.sound_stim.stop()
                    # 完全に停止するまで少し待機
                    core.wait(0.02)
                    
                # 音声再生と完了を待機
                self.sound_stim.play()
                
                # より長い待機時間で安定性向上（再生が完了するのを待つ）
                core.wait(0.1)
                
                current_time = self.clock.getTime()
                self.stim_tap.append(current_time)
                self.full_stim_tap.append(current_time)
                
                # If using Bayesian models, store hypothesis data
                if hasattr(self.model, 'get_hypothesis'):
                    self.hypo.append(self.model.get_hypothesis())
                
                # Switch to player's turn
                flag = 0
                turn += 1
                
                # Exit after STAGE2 + BUFFER*2 turns
                if turn >= (self.config.STAGE2 + self.config.BUFFER*2):
                    return True
            
            if flag == 0:
                keys = event.getKeys()
                if 'space' in keys:
                    current_time = self.clock.getTime()
                    self.player_tap.append(current_time)
                    self.full_player_tap.append(current_time)
                    # 音声の状態をチェック
                    if hasattr(self.sound_player, 'status') and self.sound_player.status == 1:
                        # 既に再生中の場合は止めてから再生
                        self.sound_player.stop()
                        # 完全に停止するまで少し待機
                        core.wait(0.02)
                        
                    # 音声再生と完了を待機
                    self.sound_player.play()
                    
                    # より長い待機時間で安定性向上（再生が完了するのを待つ）
                    core.wait(0.1)
                    
                    # タップ時系列の安全な同期エラー計算
                    if len(self.player_tap) >= 2 and len(self.stim_tap) > 0:
                        # 最後の刺激タップと直近2回のプレイヤータップを使用
                        se = self.stim_tap[-1] - (self.player_tap[-1] + self.player_tap[-2])/2
                        self.stim_se.append(se)
                    else:
                        # 十分なデータがない場合は0を使用
                        se = 0.0
                        self.stim_se.append(se)
                    
                    # モデルを使用して次のタイミングを推測
                    random_second = self.model.inference(se)
                    
                    self.timer.reset()
                    flag = 1
                
                if 'escape' in keys:
                    self.win.close()
                    core.quit()
                    return False
    
    def analyze_data(self):
        """Process and analyze the collected data."""
        # Remove the first SE placeholder
        if self.stim_se:
            del self.stim_se[0]
        
        # Calculate metrics for all taps
        for t in range(1, len(self.stim_tap)):
            # Calculate ITIs
            if t < len(self.player_tap):
                self.stim_iti.append(self.stim_tap[t] - self.player_tap[t-1])
            
            if t < len(self.stim_tap) and t-1 < len(self.player_tap):
                self.player_iti.append(self.player_tap[t-1] - self.stim_tap[t-1])
            
            # Calculate player SE
            if t < len(self.player_tap):
                self.player_se.append(self.player_tap[t] - (self.stim_tap[t-1] + self.stim_tap[t])/2)
        
        # Calculate variations
        for i in range(len(self.stim_iti) - 1):
            self.stim_itiv.append(self.stim_iti[i+1] - self.stim_iti[i])
        
        for i in range(len(self.player_iti) - 1):
            self.player_itiv.append(self.player_iti[i+1] - self.player_iti[i])
        
        for i in range(len(self.stim_se) - 1):
            self.stim_sev.append(self.stim_se[i+1] - self.stim_se[i])
        
        for i in range(len(self.player_se) - 1):
            self.player_sev.append(self.player_se[i+1] - self.player_se[i])
        
        # Remove buffer data from beginning and end
        buffer = self.config.BUFFER
        self._remove_buffer_data(buffer)
        
        # Save data to CSV files
        self._save_data()
    
    def _remove_buffer_data(self, buffer):
        """Remove buffer data from beginning and end of data lists.
        
        Args:
            buffer: Number of data points to remove
        """
        # Helper function to slice lists safely
        def safe_slice(data_list, start, end=None):
            if not data_list:
                return []
            if end is None:
                return data_list[start:]
            return data_list[start:end]
        
        # Remove buffer from tap times
        self.stim_tap = safe_slice(self.stim_tap, buffer, -buffer if buffer > 0 else None)
        self.player_tap = safe_slice(self.player_tap, buffer, -buffer if buffer > 0 else None)
        
        # Remove buffer from ITIs
        self.stim_iti = safe_slice(self.stim_iti, buffer, -buffer if buffer > 0 else None)
        self.player_iti = safe_slice(self.player_iti, buffer, -buffer if buffer > 0 else None)
        
        # Remove buffer from ITI variations
        self.stim_itiv = safe_slice(self.stim_itiv, buffer, -buffer if buffer > 0 else None)
        self.player_itiv = safe_slice(self.player_itiv, buffer, -buffer if buffer > 0 else None)
        
        # Remove buffer from SEs
        self.stim_se = safe_slice(self.stim_se, buffer, -buffer if buffer > 0 else None)
        self.player_se = safe_slice(self.player_se, buffer, -buffer if buffer > 0 else None)
        
        # Remove buffer from SE variations
        self.stim_sev = safe_slice(self.stim_sev, buffer, -buffer if buffer > 0 else None)
        self.player_sev = safe_slice(self.player_sev, buffer, -buffer if buffer > 0 else None)
        
        # Remove buffer from hypothesis data
        if self.hypo:
            self.hypo = safe_slice(self.hypo, buffer, -buffer if buffer > 0 else None)
    
    def _save_data(self):
        """Save collected data to CSV files."""
        # Create base filename
        base_filename = f"{self.model_type.lower()}_{self.serial_num}"
        
        # Save full tap times (Stage 1 + Stage 2, no buffer removed)
        full_tap_df = pd.DataFrame({
            'Stim_tap': self.full_stim_tap,
            'Player_tap': self.full_player_tap
        })
        full_tap_df.to_csv(f"{self.output_dir}/{base_filename}_tap_full.csv", index=False)
        
        # Save processed tap times (Stage 2 only, buffer removed)
        tap_df = pd.DataFrame({
            'Stim_tap': self.stim_tap,
            'Player_tap': self.player_tap
        })
        tap_df.to_csv(f"{self.output_dir}/{base_filename}_tap.csv", index=False)
        
        # Save SE data
        se_df = pd.DataFrame({
            'Stim_SE': self.stim_se,
            'Player_SE': self.player_se
        })
        se_df.to_csv(f"{self.output_dir}/{base_filename}_SE.csv", index=False)
        
        # Save ITI data
        iti_df = pd.DataFrame({
            'Stim_ITI': self.stim_iti,
            'Player_ITI': self.player_iti
        })
        iti_df.to_csv(f"{self.output_dir}/{base_filename}_ITI.csv", index=False)
        
        # Save variations
        var_df = pd.DataFrame({
            'Stim_ITIv': self.stim_itiv,
            'Player_ITIv': self.player_itiv,
            'Stim_SEv': self.stim_sev,
            'Player_SEv': self.player_sev
        })
        var_df.to_csv(f"{self.output_dir}/{base_filename}_variations.csv", index=False)
        
        # Save hypothesis data if available
        if self.hypo:
            # Convert hypo data structure to a suitable format for CSV
            hypo_data = []
            for h in self.hypo:
                hypo_data.append(','.join(map(str, h)))
            
            hypo_df = pd.DataFrame({'Hypothesis': hypo_data})
            hypo_df.to_csv(f"{self.output_dir}/{base_filename}_hypo.csv", index=False)
    
    def run(self):
        """Run the complete experiment."""
        try:
            # Set up UI
            self.setup_ui()
            
            # Run Stage 1 (metronome)
            if not self.run_stage1():
                return False
            
            # Run Stage 2 (interactive tapping)
            if not self.run_stage2():
                return False
            
            # Process and save data
            self.analyze_data()
            
            # Show completion message
            self.text.setText("Experiment completed!\nThank you for participating.")
            self.text.draw()
            self.win.flip()
            core.wait(3.0)
            
            return True
            
        except Exception as e:
            print(f"Error during experiment: {e}")
            return False
            
        finally:
            # Clean up
            if self.win:
                self.win.close()