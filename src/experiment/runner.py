"""
Main experiment runner for cooperative tapping task.
Handles experiment flow, data collection, and console-based interactions.
ウィンドウレス実装：ミリ秒精度の時間測定に最適化
"""
import os
import datetime
import numpy as np
import pandas as pd
import sys

# PsychoPyのオーディオ設定を先に行う（ミリ秒精度の時間測定のため）
from psychopy import prefs
# PTBを最優先に設定（要件に従い、ミリ秒精度を確保）
prefs.hardware['audioLib'] = ['ptb']  # PTBのみを使用してミリ秒精度を最大化
# 音声バッファサイズを最小に設定（ミリ秒精度のため）
prefs.hardware['audioBufferSize'] = 128  # PTBでの最高精度タイミング用
# 低レイテンシーモードを最高精度に設定
prefs.hardware['audioLatencyMode'] = 0  # 最高精度モード（ミリ秒精度を確保）

# その他のpsychopyモジュールをインポート（visualは使用しない）
from psychopy import core, event, sound

# ガベージコレクションを最適化して実験中のメモリ使用を効率化
import gc
gc.disable()  # 実験中の自動GCを無効化してタイミングの乱れを防止

# プロセス優先度を最大化して実験の時間精度を向上
try:
    import platform
    if platform.system() == 'Windows':
        # Windowsの場合
        import ctypes
        process_handle = ctypes.windll.kernel32.GetCurrentProcess()
        ctypes.windll.kernel32.SetPriorityClass(process_handle, 0x00000080)  # HIGH_PRIORITY_CLASS
        print("INFO: プロセス優先度を高に設定しました")
    elif platform.system() == 'Darwin' or platform.system() == 'Linux':
        # Mac/Linuxの場合
        import os
        try:
            os.nice(-10)  # 優先度を上げる（管理者権限が必要な場合あり）
            print("INFO: プロセス優先度を上げました")
        except OSError:
            print("INFO: プロセス優先度の変更が許可されていません（管理者権限が必要な場合があります）")
except Exception as e:
    print(f"INFO: プロセス優先度の設定に失敗しましたが続行します: {e}")

from ..models import SEAModel, BayesModel, BIBModel

class ExperimentRunner:
    """Runner for the cooperative tapping experiment (windowless version)."""
    
    def __init__(self, config, model_type='sea', output_dir='data/raw', user_id='anonymous'):
        """Initialize experiment with configuration and model.
        
        Args:
            config: Configuration object
            model_type: Type of model to use ('sea', 'bayes', 'bib')
            output_dir: Directory to save output data
            user_id: Subject/participant ID for data organization
        """
        self.config = config
        self.model_type = model_type
        self.output_dir = output_dir
        self.user_id = user_id
        
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
        
        # UI components（ウィンドウレスなのでwindowとtextは不要）
        self.sound_stim = None
        self.sound_player = None
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
    
    def _display_status(self, message, timestamp=True):
        """コンソールに状態を表示する"""
        if timestamp and self.clock:
            time_str = f"[{self.clock.getTime():7.3f}s]"
            print(f"{time_str} {message}")
        else:
            print(message)
    
    def _wait_for_key(self, key='space', message=None):
        """キー入力を待つ（コンソール表示付き）"""
        if message:
            print(message)
        keys = event.waitKeys(keyList=[key, 'escape'])
        if 'escape' in keys:
            print("\n実験を中断しました")
            self._cleanup()
            sys.exit(0)
        return keys
    
    def _cleanup(self):
        """実験終了時のクリーンアップ"""
        # ガベージコレクションを再有効化
        gc.enable()
        # 音声オブジェクトのクリーンアップ
        if self.sound_stim:
            self.sound_stim.stop()
        if self.sound_player:
            self.sound_player.stop()
    
    def setup_audio(self):
        """音声環境のセットアップ（PTB最適化）"""
        print("\n=== 音声環境のセットアップ ===")
        print(f"音声バックエンド: PTB（ミリ秒精度最適化）")
        
        try:
            # WAVファイルが存在するか確認
            if not os.path.exists(self.config.SOUND_STIM):
                print(f"警告: 刺激音ファイルが見つかりません: {self.config.SOUND_STIM}")
            if not os.path.exists(self.config.SOUND_PLAYER):
                print(f"警告: プレーヤー音ファイルが見つかりません: {self.config.SOUND_PLAYER}")
            
            # 音声オブジェクトの作成 - PTB最適化設定
            try:
                # PTBバックエンドで音声を作成
                self.sound_stim = sound.Sound(
                    self.config.SOUND_STIM,
                    sampleRate=44100,  # 標準的なサンプルレート
                    stereo=True,       # ステレオを有効化
                    hamming=False,     # レイテンシー低減
                )
                self.sound_player = sound.Sound(
                    self.config.SOUND_PLAYER,
                    sampleRate=44100,
                    stereo=True,
                    hamming=False,
                )
                
                print("INFO: PTB最適化設定による音声オブジェクト作成に成功しました")
                
            except Exception as e:
                print(f"警告: PTB最適化設定での音声作成に失敗しました: {e}")
                
                # 最終的にトーン音を使用
                try:
                    self.sound_stim = sound.Sound(value=800, secs=0.2)  # 800Hz
                    self.sound_player = sound.Sound(value=600, secs=0.2)  # 600Hz
                    print("INFO: トーン音による音声オブジェクト作成成功")
                except Exception as tone_error:
                    print(f"エラー: トーン音の作成にも失敗: {tone_error}")
                    raise
                    
        except Exception as e:
            print(f"エラー: 音声環境の設定に失敗しました: {e}")
            raise
    
    def setup_ui(self):
        """実験環境をセットアップ（ウィンドウレス）"""
        print("\n=== 実験環境のセットアップ（ウィンドウレス） ===")
        
        # 音声環境のセットアップ
        self.setup_audio()
        
        # 高精度クロックの設定
        self.clock = core.Clock()  # タップ時刻測定用
        self.timer = core.Clock()  # イベントタイミング用
        
        print("INFO: 実験環境のセットアップ完了")
        print("INFO: 被験者は瞑目（目を閉じた状態）で実験を行ってください")
    
    def run_stage1(self):
        """Stage 1 メトロノーム段階（コンソールベース）"""
        print("\n" + "="*50)
        print("Stage 1: メトロノーム段階")
        print("="*50)
        
        stage1_num = 0
        player_taps = 0
        required_taps = self.config.STAGE1
        
        # 実験開始の準備
        print(f"\n設定: {required_taps}回のメトロノーム音が鳴ります")
        print("メトロノーム音に続いて交互にタップしてください")
        print("\n準備ができたらSpaceキーを押してください（ESCで中断）")
        
        # Spaceキーを待つ
        self._wait_for_key('space')
        
        # カウントダウン
        print("\n開始まで...")
        for countdown in range(3, 0, -1):
            print(f"  {countdown}...")
            core.wait(1.0)
        
        print("\n開始！\n")
        
        # Reset timer and clock
        self.timer.reset()
        self.clock.reset()
        
        # タップ記録用の変数
        last_display_time = 0
        
        # Event loop for Stage 1
        while True:
            # 一定間隔で音を鳴らす
            if self.timer.getTime() >= self.config.SPAN and stage1_num < required_taps:
                stage1_num += 1
                
                # 音を鳴らす
                if self.sound_stim:
                    self.sound_stim.play()
                
                # Record stimulus tap time
                current_time = self.clock.getTime()
                self.stim_tap.append(current_time)
                self.full_stim_tap.append(current_time)
                
                # コンソールに表示
                self._display_status(f"[刺激音 #{stage1_num}] 再生")
                
                self.timer.reset()
                
                # 全ての刺激音が再生された後
                if stage1_num >= required_taps and player_taps < required_taps:
                    remaining = required_taps - player_taps
                    if self.clock.getTime() - last_display_time > 1.0:  # 1秒ごとに更新
                        print(f"\nリズムに合わせてタップしてください（残り{remaining}回）")
                        last_display_time = self.clock.getTime()
            
            # Check for key press
            keys = event.getKeys(timeStamped=self.clock)
            for key, timestamp in keys:
                if key == 'space':
                    # Record player tap time
                    self.player_tap.append(timestamp)
                    self.full_player_tap.append(timestamp)
                    player_taps += 1
                    
                    # 音を鳴らす
                    if self.sound_player:
                        self.sound_player.play()
                    
                    # コンソールに表示
                    self._display_status(f"[プレイヤー #{player_taps}] タップ")
                    
                    # 残りタップ数の更新
                    if stage1_num >= required_taps and player_taps < required_taps:
                        remaining = required_taps - player_taps
                        if remaining > 0:
                            print(f"  → 残り{remaining}回")
                
                elif key == 'escape':
                    print("\n実験を中断しました")
                    self._cleanup()
                    return False
            
            # 両方のカウントが条件を満たした場合にのみStage1を終了
            if stage1_num >= required_taps and player_taps >= required_taps:
                print(f"\nStage 1 完了！")
                print(f"刺激音: {stage1_num}回, プレイヤータップ: {player_taps}回")
                
                # 最後の刺激タップ時刻を記録
                if len(self.stim_tap) > 0:
                    self.last_stim_tap_time = self.stim_tap[-1]
                else:
                    self.last_stim_tap_time = self.clock.getTime()
                
                # 次の予想タップ時刻を計算
                self.next_expected_tap_time = self.last_stim_tap_time + self.config.SPAN
                
                return True
    
    def run_stage2(self):
        """Stage 2 相互作用段階（コンソールベース）"""
        print("\n" + "="*50)
        print("Stage 2: 相互作用段階")
        print("="*50)
        print("交互にタップを続けてください")
        print(f"設定: {self.config.STAGE2}回の相互作用")
        print("="*50 + "\n")
        
        flag = 1  # 0: Player's turn, 1: Stimulus turn
        turn = 0
        
        # Stage1からの連続性を保つ
        current_time = self.clock.getTime()
        time_to_next_tap = self.next_expected_tap_time - current_time
        
        # 時間調整
        if time_to_next_tap <= 0:
            elapsed_spans = abs(time_to_next_tap) / self.config.SPAN
            adjustment = (1 - (elapsed_spans - int(elapsed_spans))) * self.config.SPAN
            time_to_next_tap = adjustment
        
        if time_to_next_tap < 0.3:
            time_to_next_tap = 0.3
        
        # ランダム性を加味
        random_second = time_to_next_tap + np.random.normal(0, self.config.SCALE)
        
        # タイマーリセット
        self.timer.reset()
        
        # Event loop for Stage 2
        while True:
            # Stimulus turn
            if self.timer.getTime() >= random_second and flag == 1:
                # 音を鳴らす
                if self.sound_stim:
                    self.sound_stim.play()
                
                current_time = self.clock.getTime()
                self.stim_tap.append(current_time)
                self.full_stim_tap.append(current_time)
                
                # If using Bayesian models, store hypothesis data
                if hasattr(self.model, 'get_hypothesis'):
                    self.hypo.append(self.model.get_hypothesis())
                
                # Switch to player's turn
                flag = 0
                turn += 1
                
                # 進捗表示（10回ごと）
                if turn % 10 == 0:
                    self._display_status(f"[進捗] {turn}/{self.config.STAGE2 + self.config.BUFFER*2}")
                
                # 最後のターンに達したらフラグを設定
                if turn >= (self.config.STAGE2 + self.config.BUFFER*2):
                    print(f"\n最終ターン（{turn}）に到達しました")
                    print("最後のタップを行ってください...")
                    self.final_turn_reached = True
                    
                    # プレイヤーの最後のタップを待つ
                    waiting_start = self.clock.getTime()
                    while True:
                        keys = event.getKeys(timeStamped=self.clock)
                        for key, timestamp in keys:
                            if key == 'space':
                                # 最後のタップを記録
                                self.player_tap.append(timestamp)
                                self.full_player_tap.append(timestamp)
                                
                                # 音を鳴らす
                                if self.sound_player:
                                    self.sound_player.play()
                                
                                print("\n実験完了！お疲れ様でした")
                                core.wait(1.0)
                                return True
                            
                            elif key == 'escape':
                                print("\n実験を中断しました")
                                self._cleanup()
                                return False
                        
                        # タイムアウト（10秒）
                        if self.clock.getTime() - waiting_start > 10.0:
                            print("\nタイムアウト：最後のタップが検出されませんでした")
                            return True
                        
                        core.wait(0.01)
            
            if flag == 0:
                keys = event.getKeys(timeStamped=self.clock)
                for key, timestamp in keys:
                    if key == 'space':
                        self.player_tap.append(timestamp)
                        self.full_player_tap.append(timestamp)
                        
                        # 音を鳴らす
                        if self.sound_player:
                            self.sound_player.play()
                        
                        # 同期エラーの計算
                        if len(self.player_tap) >= 2 and len(self.stim_tap) > 0:
                            se = self.stim_tap[-1] - (self.player_tap[-1] + self.player_tap[-2])/2
                            self.stim_se.append(se)
                        else:
                            se = 0.0
                            self.stim_se.append(se)
                        
                        # モデルを使用して次のタイミングを推測
                        random_second = self.model.inference(se)
                        
                        self.timer.reset()
                        flag = 1
                    
                    elif key == 'escape':
                        print("\n実験を中断しました")
                        self._cleanup()
                        return False
    
    def analyze_data(self):
        """Process and analyze the collected data."""
        print("\n=== データ分析 ===")
        print(f"刺激タップ: {len(self.stim_tap)}回, プレイヤータップ: {len(self.player_tap)}回")
        
        # オリジナルデータを保持
        self.full_stim_tap = self.stim_tap.copy()
        self.full_player_tap = self.player_tap.copy()
        
        # 配列長の調整
        stim_len = len(self.stim_tap)
        player_len = len(self.player_tap)
        
        if stim_len != player_len:
            print(f"警告: データ長の不一致を検出。調整を行います（刺激音: {stim_len}, プレイヤー: {player_len}）")
            min_len = min(stim_len, player_len)
            self.stim_tap = self.stim_tap[:min_len]
            self.player_tap = self.player_tap[:min_len]
            print(f"データ長を調整しました - 刺激タップ: {len(self.stim_tap)}回, プレイヤータップ: {len(self.player_tap)}回")
        
        # バッファーの適用（実験開始時のみ）
        buffer_start = self.config.BUFFER
        
        if len(self.stim_tap) > buffer_start:
            self.stim_tap = self.stim_tap[buffer_start:]
        if len(self.player_tap) > buffer_start:
            self.player_tap = self.player_tap[buffer_start:]
        
        print(f"バッファー除外後 - 刺激タップ: {len(self.stim_tap)}回, プレイヤータップ: {len(self.player_tap)}回")
        
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
            
            # ITIの計算
            for t in range(1, len(self.stim_tap)):
                if t-1 < len(self.player_tap):
                    self.stim_iti.append(self.stim_tap[t] - self.player_tap[t-1])
            
            for t in range(1, len(self.player_tap)):
                if t-1 < len(self.stim_tap):
                    self.player_iti.append(self.player_tap[t] - self.stim_tap[t-1])
            
            # 同期誤差(SE)の計算
            for t in range(len(self.player_tap)):
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
            
            print("データ分析完了")
            
            # データを保存
            self._save_data_organized()
            
            return True
            
        except Exception as e:
            print(f"エラー: データ分析中に例外が発生しました: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def _save_data_organized(self):
        """階層化されたディレクトリ構造でデータを保存する"""
        # 日付をデータディレクトリ名に含める
        date_str = datetime.datetime.now().strftime('%Y%m%d')
        
        # 出力ディレクトリの構造化されたパス
        experiment_dir = os.path.join(
            self.output_dir,
            f"{date_str}_{self.user_id}",
            f"{self.model_type}_{self.serial_num}"
        )
        
        # ディレクトリが存在しない場合は作成
        os.makedirs(experiment_dir, exist_ok=True)
        
        print(f"\nデータを保存中: {experiment_dir}")
        
        # 全タップデータを保存（バッファ除去なし）
        if len(self.full_stim_tap) > 0 and len(self.full_player_tap) > 0:
            min_full_len = min(len(self.full_stim_tap), len(self.full_player_tap))
            full_tap_df = pd.DataFrame({
                'Stim_tap': self.full_stim_tap[:min_full_len],
                'Player_tap': self.full_player_tap[:min_full_len]
            })
            full_tap_df.to_csv(os.path.join(experiment_dir, "raw_taps.csv"), index=False)
        
        # 処理済みのタップデータを保存（バッファ処理済み）
        if len(self.stim_tap) > 0 and len(self.player_tap) > 0:
            min_len = min(len(self.stim_tap), len(self.player_tap))
            tap_df = pd.DataFrame({
                'Stim_tap': self.stim_tap[:min_len],
                'Player_tap': self.player_tap[:min_len]
            })
            tap_df.to_csv(os.path.join(experiment_dir, "processed_taps.csv"), index=False)
        
        # SE（同期誤差）データを保存
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
        
        # 変動データを保存
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
            'ExperimentTime': datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'WindowlessMode': True,
            'AudioBackend': 'PTB'
        }
        
        config_df = pd.DataFrame([config_data])
        config_df.to_csv(os.path.join(experiment_dir, "experiment_config.csv"), index=False)
        
        # メタデータファイル
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
        
        print(f"すべてのデータが正常に保存されました")
    
    def run(self):
        """Run the complete experiment."""
        try:
            print("\n" + "="*70)
            print("協調タッピング実験システム（ウィンドウレス版）")
            print("="*70)
            print(f"モデル: {self.model_type.upper()}")
            print(f"実験ID: {self.serial_num}")
            print("被験者は瞑目（目を閉じた状態）で実験を行ってください")
            print("="*70 + "\n")
            
            # Set up UI (audio only)
            self.setup_ui()
            
            # Run Stage 1 (metronome)
            if not self.run_stage1():
                return False
            
            # 小休憩
            print("\n次のステージに移ります...")
            core.wait(2.0)
            
            # Run Stage 2 (interactive tapping)
            if not self.run_stage2():
                return False
            
            # Process and save data
            self.analyze_data()
            
            # Show completion message
            print("\n" + "="*70)
            print("実験が正常に完了しました！")
            print("ご協力ありがとうございました。")
            print("="*70 + "\n")
            
            return True
            
        except Exception as e:
            print(f"\nエラー: 実験中に問題が発生しました: {e}")
            import traceback
            traceback.print_exc()
            return False
            
        finally:
            # Clean up
            self._cleanup()
