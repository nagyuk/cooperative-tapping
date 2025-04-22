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
# サウンドバックエンドの優先順位を設定（様々なバックエンドを試行）
prefs.hardware['audioLib'] = ['pygame', 'sounddevice', 'pyo', 'ptb']
# 音声バッファサイズを小さくして高速応答を実現
prefs.hardware['audioBufferSize'] = 512  # より安定性を重視
# 低レイテンシーモードに設定（ミリ秒精度を確保）
prefs.hardware['audioLatencyMode'] = 3  # より安定性を重視

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
        
        # 実験終了を管理するフラグ
        self.final_turn_reached = False
        
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
        # すべて空の配列から開始（初期値なし）
        self.stim_tap = []
        self.player_tap = []
        
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
        
        # 音声オブジェクトの作成（複数の方法を試行）
        self.sound_stim = None
        self.sound_player = None
        
        sound_creation_methods = [
            # 方法1: 標準の初期化（backendパラメータなし）
            lambda file_path: sound.Sound(file_path),
            
            # 方法2: 相対パスと標準初期化
            lambda file_path: sound.Sound(os.path.basename(file_path)),
            
            # 方法3: 辞書による初期化
            lambda file_path: sound.Sound(value=file_path),
            
            # 方法4: Numpy配列にする
            lambda file_path: sound.Sound(value='C', secs=0.2),
        ]
        
        # 音声ファイルの試行順序
        sound_files = [
            (self.config.SOUND_STIM, "刺激音"),
            (self.config.SOUND_PLAYER, "プレーヤー音")
        ]
        
        # 各方法を試す
        for method_index, creation_method in enumerate(sound_creation_methods):
            success = True
            
            try:
                print(f"INFO: 方法{method_index+1}で音声オブジェクトの作成を試みます")
                
                for file_path, file_type in sound_files:
                    try:
                        if file_type == "刺激音":
                            self.sound_stim = creation_method(file_path)
                        else:
                            self.sound_player = creation_method(file_path)
                    except Exception as file_error:
                        print(f"警告: {file_type}の作成に失敗: {file_error}")
                        success = False
                        break
                
                # 両方の音声が作成できたら成功
                if success and self.sound_stim is not None and self.sound_player is not None:
                    print(f"INFO: 方法{method_index+1}で音声オブジェクト作成成功")
                    break
                    
            except Exception as method_error:
                print(f"警告: 方法{method_index+1}が失敗: {method_error}")
                continue
        
        # 音声オブジェクトの作成確認と代替方法
        if self.sound_stim is None or self.sound_player is None:
            print("警告: 音声ファイル（stim_beat.wav/player_beat.wav）での音声オブジェクト作成に失敗しました。トーン生成を使用します")
            try:
                # 純粋なトーン音を使用
                self.sound_stim = sound.Sound(value='C', secs=0.1)
                self.sound_player = sound.Sound(value='E', secs=0.1)
                print("INFO: トーン音による音声オブジェクト作成成功")
            except Exception as tone_error:
                print(f"エラー: トーン音の作成にも失敗: {tone_error}")
                # 音を使わないモード
                print("警告: 音声なしでの実行を続行します")
                self.sound_stim = None
                self.sound_player = None
        
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
        player_taps = 0
        required_taps = self.config.STAGE1
        
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
            
            # Play sound at fixed interval (only until required number of stimuli)
            if self.timer.getTime() >= self.config.SPAN and stage1_num < required_taps:
                stage1_num += 1
                # 音声の状態をチェック
                if self.sound_stim:
                    if hasattr(self.sound_stim, 'status') and self.sound_stim.status == 1:
                        # 既に再生中の場合は止めてから再生
                        self.sound_stim.stop()
                        # 完全に停止するまで少し待機
                        core.wait(0.02)
                    
                    # 音声の即時再生（音量の調整なし、待機なしで高精度を維持）
                    try:
                        self.sound_stim.play()
                    except Exception as play_err:
                        print(f"警告: 音声再生に失敗しましたが続行します: {play_err}")
                
                # Record stimulus tap time
                current_time = self.clock.getTime()
                self.stim_tap.append(current_time)
                self.full_stim_tap.append(current_time)
                
                self.timer.reset()
                
                # 全ての刺激音が再生された後に指示文を変更
                if stage1_num >= required_taps:
                    # 刺激音が完了したら、プレイヤーにリズムに合わせるよう指示
                    if player_taps < required_taps:
                        remaining = required_taps - player_taps
                        self.text.setText(f"リズムに合わせてタップしてください\nあと {remaining} 回")
            
            # Check for key press
            keys = event.getKeys()
            if 'space' in keys:
                # Record player tap time
                current_time = self.clock.getTime()
                self.player_tap.append(current_time)
                self.full_player_tap.append(current_time)
                player_taps += 1
                
                # 音声の状態をチェック
                if hasattr(self.sound_player, 'status') and self.sound_player.status == 1:
                    # 既に再生中の場合は止めてから再生
                    self.sound_player.stop()
                    # 完全に停止するまで少し待機
                    core.wait(0.02)
                    
                # 音声再生と完了を待機
                if self.sound_player is not None:  # Noneでないことを確認
                    try:
                        self.sound_player.play()
                    except Exception as play_err:
                        print(f"警告: 音声再生に失敗しましたが続行します: {play_err}")
                
                # 刺激音の再生が完了した後は、残りのタップ数を更新して表示
                if stage1_num >= required_taps and player_taps < required_taps:
                    remaining = required_taps - player_taps
                    self.text.setText(f"リズムに合わせてタップしてください\nあと {remaining} 回")
            
            if 'escape' in keys:
                self.win.close()
                core.quit()
                return False
            
            # 両方のカウントが条件を満たした場合にのみStage1を終了
            if stage1_num >= required_taps and player_taps >= required_taps:
                # Stage1完了のログ出力
                print("INFO: Stage1完了。Stage2へ移行します")
                
                # 最後の刺激タップ時刻を記録（存在する場合）
                if len(self.stim_tap) > 0:
                    self.last_stim_tap_time = self.stim_tap[-1]
                else:
                    # 代替として現在時刻を使用
                    self.last_stim_tap_time = self.clock.getTime()
                    print("警告: Stage1で刺激タップデータが記録されていません。現在時刻を使用します。")
                
                # データ確認（実際のタップ時刻のみを記録）
                print(f"INFO: Stage1終了時点での記録データ - 刺激タップ: {len(self.stim_tap)}回, プレイヤータップ: {len(self.player_tap)}回")
                
                # リズム連続性を保証するために次のタップ予測時刻を計算
                # 一定間隔で演奏していた最後のタップから次の理想的なタップタイミングを予測
                self.next_expected_tap_time = self.last_stim_tap_time + self.config.SPAN
                print(f"INFO: 次の予想タップ時刻: {self.next_expected_tap_time:.3f}秒")
                
                return True
    
    def run_stage2(self):
        """Run Stage 2 of the experiment (interactive tapping)."""
        flag = 1  # 0: Player's turn, 1: Stimulus turn
        turn = 0
        
        # ステージ間の連続性を保つため、テキストを控えめに表示
        self.text.setText("Stage 2: Alternating")
        self.text.setHeight(0.03)  # テキストサイズを小さく
        self.text.setPos([0, 0.8])  # 画面上部に表示
        self.text.draw()
        self.win.flip()
        
        # ステージ1から連続的なリズムを維持するための設定
        # この時点での経過時間を計算
        current_time = self.clock.getTime()
        
        # Stage1の最後のタップからの理想的な間隔でタイミングを設定
        # 次の予測タップ時刻（next_expected_tap_time）はrun_stage1で計算済み
        time_to_next_tap = self.next_expected_tap_time - current_time
        
        # 時間がすでに過ぎている場合は、次の間隔に調整
        if time_to_next_tap <= 0:
            # 経過時間をSPANで割った余りを計算
            elapsed_spans = abs(time_to_next_tap) / self.config.SPAN
            adjustment = (1 - (elapsed_spans - int(elapsed_spans))) * self.config.SPAN
            time_to_next_tap = adjustment
        
        # 短すぎる待機時間の場合は安全マージンを確保
        if time_to_next_tap < 0.3:
            time_to_next_tap = 0.3
        
        # ランダム性を加味（自然なリズム変動を実現）
        random_second = time_to_next_tap + np.random.normal(0, self.config.SCALE)
        
        # 状態をリセットして次のタップに備える
        self.timer.reset()
        
        # Start message
        self.text.setText("Follow the rhythm")
        self.text.setHeight(0.03)  # 小さめのテキスト
        self.text.setPos([0, 0.7])  # 画面上部寄りに配置
        
        # ログ出力
        print(f"INFO: Stage2開始 - 次のタップまでの待機時間: {random_second:.3f}秒")
        
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
                    
                # 音声の即時再生（待機なしで高精度を維持）
                if self.sound_stim is not None:
                    # 安全にsetVolumeを呼び出す（あれば）
                    if hasattr(self.sound_stim, 'setVolume'):
                        try:
                            self.sound_stim.setVolume(1.0)  # 音量を最大に設定
                        except Exception as vol_err:
                            print(f"警告: 音量設定に失敗しましたが続行します: {vol_err}")
                    
                    # 引数なしでplay()を呼び出し（より広く互換性がある）
                    try:
                        self.sound_stim.play()
                    except Exception as play_err:
                        print(f"警告: 音声再生に失敗しましたが続行します: {play_err}")
                
                current_time = self.clock.getTime()
                self.stim_tap.append(current_time)
                self.full_stim_tap.append(current_time)
                
                # If using Bayesian models, store hypothesis data
                if hasattr(self.model, 'get_hypothesis'):
                    self.hypo.append(self.model.get_hypothesis())
                
                # Switch to player's turn
                flag = 0
                turn += 1
                
                # 最後のターンに達したらフラグを設定するが、すぐには終了しない
                if turn >= (self.config.STAGE2 + self.config.BUFFER*2):
                    # ログメッセージを安全に表示
                    print(f"INFO: 最終ターン({turn})に到達しました。プレイヤーの最後のタップを待機中...")
                    self.final_turn_reached = True
                    
                    # プレイヤーがタップするまで待機
                    waiting_for_final_tap = True
                    while waiting_for_final_tap:
                        # テキスト表示を更新して最後のタップを促す
                        self.text.setText("最後のタップを行ってください")
                        self.text.setHeight(0.08)  # より大きく表示
                        self.text.setColor("yellow")  # 目立つ色に
                        self.text.draw()
                        self.win.flip()
                        
                        # キー入力をチェック
                        final_keys = event.getKeys()
                        if 'space' in final_keys:
                            # 最後のタップを記録
                            final_time = self.clock.getTime()
                            self.player_tap.append(final_time)
                            self.full_player_tap.append(final_time)
                            
                            # 音を鳴らす
                            if self.sound_player is not None:
                                try:
                                    self.sound_player.play()
                                except Exception as play_err:
                                    print(f"警告: 最終タップの音声再生に失敗: {play_err}")
                            
                            # 完了メッセージを表示
                            self.text.setText("実験完了！\nお疲れ様でした")
                            self.text.setColor("green")
                            self.text.draw()
                            self.win.flip()
                            
                            # 少し待機して確認
                            core.wait(1.0)
                            
                            # 待機ループを終了
                            waiting_for_final_tap = False
                            print("INFO: プレイヤーの最終タップを記録しました")
                        
                        elif 'escape' in final_keys:
                            # エスケープキーで中断
                            self.win.close()
                            core.quit()
                            return False
                        
                        # 短い待機で処理負荷を軽減
                        core.wait(0.01)
                    
                    # 実験を終了
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
                        
                    # 音声再生と完了を待機（音量を大きくして確実に再生されるようにする）
                    if self.sound_player is not None:
                        # 安全にsetVolumeを呼び出す（あれば）
                        if hasattr(self.sound_player, 'setVolume'):
                            try:
                                self.sound_player.setVolume(1.0)  # 音量を最大に設定
                            except Exception as vol_err:
                                print(f"警告: 音量設定に失敗しましたが続行します: {vol_err}")
                        
                        # 引数なしでplay()を呼び出し（より広く互換性がある）
                        try:
                            self.sound_player.play()
                        except Exception as play_err:
                            print(f"警告: 音声再生に失敗しましたが続行します: {play_err}")
                    
                    # より長い待機時間で安定性向上（再生が完了するのを待つ）
                    core.wait(0.2)  # 待機時間を延長
                    
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
        print(f"INFO: データ分析開始 - 刺激タップ: {len(self.stim_tap)}回, プレイヤータップ: {len(self.player_tap)}回")
        
        # オリジナルデータを保持（バッファ処理前のデータを保持）
        self.full_stim_tap = self.stim_tap.copy()
        self.full_player_tap = self.player_tap.copy()
        
        # 配列長が一致していない場合は調整
        stim_len = len(self.stim_tap)
        player_len = len(self.player_tap)
        
        if stim_len != player_len:
            print(f"警告: データ長の不一致を検出。調整を行います（刺激音: {stim_len}, プレイヤー: {player_len}）")
            min_len = min(stim_len, player_len)
            self.stim_tap = self.stim_tap[:min_len]
            self.player_tap = self.player_tap[:min_len]
            print(f"INFO: データ長を調整しました - 刺激タップ: {len(self.stim_tap)}回, プレイヤータップ: {len(self.player_tap)}回")
        
        # バッファーの適用（実験開始時のみ）
        buffer_start = self.config.BUFFER
        buffer_end = 0  # 終了部分は除外しない
        
        # 実験開始時のバッファーのみを除外
        if len(self.stim_tap) > buffer_start:
            self.stim_tap = self.stim_tap[buffer_start:]
        if len(self.player_tap) > buffer_start:
            self.player_tap = self.player_tap[buffer_start:]
        
        print(f"INFO: バッファー除外後 - 刺激タップ: {len(self.stim_tap)}回, プレイヤータップ: {len(self.player_tap)}回")
        
        # 配列長が十分かチェック
        if len(self.stim_tap) < 2 or len(self.player_tap) < 2:
            print("警告: 十分なデータがないため、分析を中止します")
            return False
        
        try:
            # 派生データのリスト初期化
            self.stim_iti = []
            self.player_iti = []
            self.stim_itiv = []
            self.player_itiv = []
            self.player_se = []
            self.stim_sev = []
            self.player_sev = []
            
            # Remove the first SE placeholder if it exists
            if self.stim_se and len(self.stim_se) > 0:
                del self.stim_se[0]
            
            # ITIの計算（バッファー除外後のデータから計算）
            for t in range(1, len(self.stim_tap)):
                # 刺激のITI計算: 現在の刺激タップと前回のプレイヤータップの差
                if t-1 < len(self.player_tap):
                    self.stim_iti.append(self.stim_tap[t] - self.player_tap[t-1])
            
            for t in range(1, len(self.player_tap)):
                # プレイヤーのITI計算: 現在のプレイヤータップと前回の刺激タップの差
                if t-1 < len(self.stim_tap):
                    self.player_iti.append(self.player_tap[t] - self.stim_tap[t-1])
            
            # 同期誤差(SE)の計算
            for t in range(len(self.player_tap)):
                # プレイヤーSE計算: プレイヤータップと前後の刺激タップの中間点との差
                if t < len(self.stim_tap) and t > 0:
                    self.player_se.append(self.player_tap[t] - (self.stim_tap[t-1] + self.stim_tap[t])/2)
            
            # ITI変動の計算
            for i in range(len(self.stim_iti) - 1):
                self.stim_itiv.append(self.stim_iti[i+1] - self.stim_iti[i])
            
            for i in range(len(self.player_iti) - 1):
                self.player_itiv.append(self.player_iti[i+1] - self.player_iti[i])
            
            # SE変動の計算
            for i in range(len(self.stim_se) - 1):
                self.stim_sev.append(self.stim_se[i+1] - self.stim_se[i])
            
            for i in range(len(self.player_se) - 1):
                self.player_sev.append(self.player_se[i+1] - self.player_se[i])
            
            # ベイズモデル用の仮説データのバッファー処理
            if self.hypo and len(self.hypo) > buffer_start:
                self.hypo = self.hypo[buffer_start:]
            
            # データを保存
            self._save_data_organized()
            
            return True
            
        except Exception as e:
            print(f"エラー: データ分析中に例外が発生しました: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def _remove_buffer_data(self, buffer):
        """Remove buffer data from beginning only (not end) of primary data lists.
        
        Args:
            buffer: Number of data points to remove from beginning
        """
        # Helper function to slice lists safely (only from beginning)
        def safe_slice_start(data_list, start):
            if not data_list:
                return []
            if start >= len(data_list):
                return []
            return data_list[start:]
        
        # Only remove buffer from the beginning of tap times
        print(f"INFO: バッファー処理前 - 刺激タップ: {len(self.stim_tap)}回, プレイヤータップ: {len(self.player_tap)}回")
        self.stim_tap = safe_slice_start(self.stim_tap, buffer)
        self.player_tap = safe_slice_start(self.player_tap, buffer)
        print(f"INFO: バッファー処理後 - 刺激タップ: {len(self.stim_tap)}回, プレイヤータップ: {len(self.player_tap)}回")
        
        # Hypothesis data (raw data) should also have buffer removed from beginning
        if self.hypo:
            self.hypo = safe_slice_start(self.hypo, buffer)
        
        # Note: The derived measures (SE, ITI, etc.) are calculated AFTER removing buffers,
        # so we don't need to remove buffer from those arrays.
    
    def _save_data_organized(self):
        """階層化されたディレクトリ構造でデータを保存する"""
        # 日付をデータディレクトリ名に含める
        date_str = datetime.datetime.now().strftime('%Y%m%d')
        
        # 被験者IDを使用（設定されていない場合はデフォルト値を使用）
        user_id = getattr(self, 'user_id', 'anonymous')
        
        # 出力ディレクトリの構造化されたパス
        experiment_dir = os.path.join(
            self.output_dir,
            f"{date_str}_{user_id}",
            f"{self.model_type}_{self.serial_num}"
        )
        
        # ディレクトリが存在しない場合は作成
        os.makedirs(experiment_dir, exist_ok=True)
        
        print(f"INFO: データを階層化されたディレクトリに保存: {experiment_dir}")
        
        # 全タップデータを保存（バッファ除去なし）
        if len(self.full_stim_tap) > 0 and len(self.full_player_tap) > 0:
            # 配列長の整合性をチェック
            min_full_len = min(len(self.full_stim_tap), len(self.full_player_tap))
            full_tap_df = pd.DataFrame({
                'Stim_tap': self.full_stim_tap[:min_full_len],
                'Player_tap': self.full_player_tap[:min_full_len]
            })
            full_tap_df.to_csv(os.path.join(experiment_dir, "raw_taps.csv"), index=False)
        
        # 処理済みのタップデータを保存（バッファ処理済み）
        if len(self.stim_tap) > 0 and len(self.player_tap) > 0:
            # 配列長の整合性をチェック
            min_len = min(len(self.stim_tap), len(self.player_tap))
            tap_df = pd.DataFrame({
                'Stim_tap': self.stim_tap[:min_len],
                'Player_tap': self.player_tap[:min_len]
            })
            tap_df.to_csv(os.path.join(experiment_dir, "processed_taps.csv"), index=False)
        
        # SE（同期誤差）データを保存 - 修正部分
        # 各SEデータを別々のファイルに保存
        if len(self.stim_se) > 0:
            stim_se_df = pd.DataFrame({'Stim_SE': self.stim_se})
            stim_se_df.to_csv(os.path.join(experiment_dir, "stim_synchronization_errors.csv"), index=False)
        
        if len(self.player_se) > 0:
            player_se_df = pd.DataFrame({'Player_SE': self.player_se})
            player_se_df.to_csv(os.path.join(experiment_dir, "player_synchronization_errors.csv"), index=False)
        
        # ITI（タップ間隔）データを保存
        if len(self.stim_iti) > 0:
            stim_iti_df = pd.DataFrame({'Stim_ITI': self.stim_iti})
            stim_iti_df.to_csv(os.path.join(experiment_dir, "stim_intertap_intervals.csv"), index=False)
        
        if len(self.player_iti) > 0:
            player_iti_df = pd.DataFrame({'Player_ITI': self.player_iti})
            player_iti_df.to_csv(os.path.join(experiment_dir, "player_intertap_intervals.csv"), index=False)
        
        # 変動データを保存 - 同様に別々のファイルに保存
        if len(self.stim_itiv) > 0:
            stim_itiv_df = pd.DataFrame({'Stim_ITIv': self.stim_itiv})
            stim_itiv_df.to_csv(os.path.join(experiment_dir, "stim_iti_variations.csv"), index=False)
        
        if len(self.player_itiv) > 0:
            player_itiv_df = pd.DataFrame({'Player_ITIv': self.player_itiv})
            player_itiv_df.to_csv(os.path.join(experiment_dir, "player_iti_variations.csv"), index=False)
        
        if len(self.stim_sev) > 0:
            stim_sev_df = pd.DataFrame({'Stim_SEv': self.stim_sev})
            stim_sev_df.to_csv(os.path.join(experiment_dir, "stim_se_variations.csv"), index=False)
        
        if len(self.player_sev) > 0:
            player_sev_df = pd.DataFrame({'Player_SEv': self.player_sev})
            player_sev_df.to_csv(os.path.join(experiment_dir, "player_se_variations.csv"), index=False)
        
        # 仮説データを保存（モデルの状態データ）
        if self.hypo:
            # 仮説データを文字列に変換して保存
            hypo_data = []
            for h in self.hypo:
                hypo_data.append(','.join(map(str, h)))
            
            hypo_df = pd.DataFrame({'Hypothesis': hypo_data})
            hypo_df.to_csv(os.path.join(experiment_dir, "model_hypotheses.csv"), index=False)
        
        # 実験設定情報を保存
        config_data = {
            'Model': self.model_type,
            'SPAN': self.config.SPAN,
            'STAGE1': self.config.STAGE1,
            'STAGE2': self.config.STAGE2,
            'BUFFER': self.config.BUFFER,
            'SCALE': self.config.SCALE,
            'ExperimentTime': datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
        
        config_df = pd.DataFrame([config_data])
        config_df.to_csv(os.path.join(experiment_dir, "experiment_config.csv"), index=False)
        
        # メタデータファイル - データの長さ情報を含む
        metadata = {
            'full_stim_tap_length': len(self.full_stim_tap),
            'full_player_tap_length': len(self.full_player_tap),
            'stim_tap_length': len(self.stim_tap),
            'player_tap_length': len(self.player_tap),
            'stim_se_length': len(self.stim_se),
            'player_se_length': len(self.player_se),
            'stim_iti_length': len(self.stim_iti),
            'player_iti_length': len(self.player_iti),
            'stim_itiv_length': len(self.stim_itiv),
            'player_itiv_length': len(self.player_itiv),
            'stim_sev_length': len(self.stim_sev),
            'player_sev_length': len(self.player_sev),
            'hypo_length': len(self.hypo) if self.hypo else 0
        }
        
        metadata_df = pd.DataFrame([metadata])
        metadata_df.to_csv(os.path.join(experiment_dir, "data_metadata.csv"), index=False)
        
        print(f"INFO: すべてのデータが {experiment_dir} に正常に保存されました")
    
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