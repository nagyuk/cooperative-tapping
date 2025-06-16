"""
Main experiment runner for cooperative tapping task.
Handles experiment flow, data collection, and UI interactions.
"""
import os
import datetime
import numpy as np
import pandas as pd

# PsychoPyのオーディオ設定を先に行う（ミリ秒精度の時間測定のため）
from psychopy import prefs
# PTBを最優先に設定（要件に従い、ミリ秒精度を確保）
prefs.hardware['audioLib'] = ['ptb']  # PTBのみを使用してミリ秒精度を最大化
# 音声バッファサイズを最小に設定（ミリ秒精度のため）
prefs.hardware['audioBufferSize'] = 128  # PTBでの最高精度タイミング用
# 低レイテンシーモードを最高精度に設定
prefs.hardware['audioLatencyMode'] = 1  # 最高精度モード（ミリ秒精度を確保）

# その他のpsychopyモジュールをインポート
from psychopy import visual, core, event, sound

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
    """Runner for the cooperative tapping experiment."""
    
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
    
    def setup_minimal_environment(self):
        """実験に必要な最小限の環境を設定（瞑目実験用）"""
        # 音声環境の設定
        self._setup_audio()
        
        # 最小限のクロック設定
        self.clock = core.Clock()  # For measuring tap times
        self.timer = core.Clock()  # For timing events
        
        # ウィンドウは作成しない
        self.win = None
        self.text = None
        
        print("INFO: 瞑目実験用の最小限環境を設定しました")
    
    def _setup_audio(self):
        """最適な音声環境を設定"""
        try:
            # PTBを優先的に使用するよう設定
            from psychopy import prefs
            prefs.hardware['audioLib'] = ['ptb', 'pygame']  # PTB優先、代替あり
            prefs.hardware['audioBufferSize'] = 512  # 安定性と精度のバランス
            prefs.hardware['audioLatencyMode'] = 3  # 高精度だが実用的
            print("INFO: 音声エンジン設定: PTBを優先的に使用します")
            
            # 音声ファイルのパスとファイルの存在確認
            print(f"INFO: 音声ファイルパス - 刺激音: {self.config.SOUND_STIM}")
            print(f"INFO: 音声ファイルパス - プレーヤー音: {self.config.SOUND_PLAYER}")
            
            if not os.path.exists(self.config.SOUND_STIM):
                print(f"警告: 刺激音ファイルが見つかりません: {self.config.SOUND_STIM}")
            if not os.path.exists(self.config.SOUND_PLAYER):
                print(f"警告: プレーヤー音ファイルが見つかりません: {self.config.SOUND_PLAYER}")
            
            # 音声バックエンドの情報を表示
            if hasattr(sound, 'audioLib'):
                print(f"INFO: 使用中の音声バックエンド: {sound.audioLib}")
            else:
                print("INFO: 音声バックエンド情報が取得できません")
            
            # 音声オブジェクトの作成 - ステレオ高音量対応
            try:
                # PTBバックエンドでステレオ音声を最大音量で作成（音量を大幅に増幅）
                self.sound_stim = sound.Sound(
                    self.config.SOUND_STIM,
                    sampleRate=44100,  # 標準的なサンプルレート
                    stereo=True,       # ステレオを有効にして左右両方から音を出力
                    hamming=False,     # レイテンシー低減
                    volume=2.0         # 通常の2倍の音量に設定
                )
                self.sound_player = sound.Sound(
                    self.config.SOUND_PLAYER,
                    sampleRate=44100,
                    stereo=True,       # ステレオを有効にして左右両方から音を出力
                    hamming=False,
                    volume=2.0         # 通常の2倍の音量に設定
                )
                
                # 作成後に明示的に音量を最大+αに設定（PTBでより強く反映される）
                try:
                    # 超大音量設定（通常の2倍の音量に設定）
                    self.sound_stim.setVolume(2.0)
                    self.sound_player.setVolume(2.0)
                    
                    # さらにPTBバックエンド固有の音量ブースト（可能な場合）
                    if hasattr(self.sound_stim, '_volumeCoeff'):
                        self.sound_stim._volumeCoeff = 1.0
                    if hasattr(self.sound_player, '_volumeCoeff'):
                        self.sound_player._volumeCoeff = 1.0
                        
                    print("INFO: 超大音量設定完了（WAVファイル98%振幅 + PsychoPy最大音量）")
                except Exception as vol_err:
                    print(f"INFO: 音量設定の確認に失敗: {vol_err}")
                
                # 音声オブジェクトが正常に作成されたか確認
                if self.sound_stim and self.sound_player:
                    print("INFO: PTB最適化設定による音声オブジェクト作成に成功しました")
                    
                    # 事前に音声の長さなどの情報を取得（デバッグ用）
                    if hasattr(self.sound_stim, 'getDuration'):
                        try:
                            stim_duration = self.sound_stim.getDuration()
                            player_duration = self.sound_player.getDuration()
                            print(f"INFO: 音声長さ - 刺激音: {stim_duration:.3f}秒, プレイヤー音: {player_duration:.3f}秒")
                        except Exception as duration_error:
                            print(f"INFO: 音声長さの取得に失敗: {duration_error}")
                else:
                    raise Exception("音声オブジェクトがNoneです")
                    
            except Exception as e:
                print(f"警告: PTB最適化設定での音声作成に失敗しました: {e}")
                
                # シンプルな方法で再試行（音量強化版）
                try:
                    self.sound_stim = sound.Sound(self.config.SOUND_STIM, volume=1.0)
                    self.sound_player = sound.Sound(self.config.SOUND_PLAYER, volume=1.0)
                    
                    # さらに音量を確実に設定
                    if hasattr(self.sound_stim, 'setVolume'):
                        self.sound_stim.setVolume(2.0)
                    if hasattr(self.sound_player, 'setVolume'):
                        self.sound_player.setVolume(2.0)
                    
                    print("INFO: シンプルなパラメータ（音量強化版）で音声オブジェクト作成に成功しました")
                except Exception as e2:
                    print(f"警告: シンプルな方法での音声作成にも失敗: {e2}")
                    
                    # 最終的にトーン音を使用
                    try:
                        self.sound_stim = sound.Sound(value=800, secs=0.3)  # 800Hz、0.3秒
                        self.sound_player = sound.Sound(value=600, secs=0.3)  # 600Hz、0.3秒
                        print("INFO: トーン音による音声オブジェクト作成成功")
                    except Exception as tone_error:
                        print(f"エラー: トーン音の作成にも失敗: {tone_error}")
                        # 音を使わないモード
                        print("警告: 音声なしでの実行を続行します")
                        self.sound_stim = None
                        self.sound_player = None
            
        except Exception as e:
            print(f"エラー: 音声環境の設定に失敗しました: {e}")
            self.sound_stim = None
            self.sound_player = None
    
    def setup_ui(self):
        """実験環境をセットアップ - ウィンドウ表示を含む完全な環境"""
        print("INFO: ウィンドウ表示を含む実験環境をセットアップします")
        
        # 音声環境のセットアップ
        self._setup_audio()
        
        # クロックの設定
        self.clock = core.Clock()  # タップ時刻測定用
        self.timer = core.Clock()  # イベントタイミング用
        
        # ウィンドウの作成（デバッグ情報付き）
        print("INFO: ウィンドウ作成を開始...")
        try:
            # ウィンドウ作成前の環境情報を出力
            from psychopy import __version__ as psychopy_version
            print(f"INFO: PsychoPy バージョン: {psychopy_version}")
            
            import platform
            print(f"INFO: OS: {platform.system()} {platform.release()}")
            print(f"INFO: Python: {platform.python_version()}")
            
            # PsychoPyの詳細ログを有効化（問題診断用）
            from psychopy import logging
            logging.console.setLevel(logging.DEBUG)
            print("INFO: PsychoPy詳細ログを有効化しました")
            
            # ウィンドウ作成（ミリ秒精度タイミング用に最適化）
            self.win = visual.Window(
                size=(800, 600),
                monitor="testMonitor",
                color="black",
                fullscr=False,
                allowGUI=True,
                screen=0,
                units='pix',
                waitBlanking=False,  # VSyncを無効化してタイミング精度を優先
                pos=(0, 0)
            )
            
            # ウィンドウ作成成功の確認
            if self.win:
                print(f"INFO: ウィンドウ作成成功: サイズ = {self.win.size}, 位置 = {self.win.pos}")
                
                # 最初のフレーム描画で初期化を確認
                self.win.flip()
                print("INFO: 初期フレーム描画成功")
            else:
                print("警告: ウィンドウオブジェクトが作成されましたが、None値です")
        
        except Exception as e:
            # ウィンドウ作成失敗時のフォールバック
            print(f"ERROR: ウィンドウ作成中にエラーが発生しました: {e}")
            print("INFO: コンソールモードにフォールバックします")
            self.win = None
        
        # テキスト表示の設定（ウィンドウが作成された場合のみ）
        if self.win:
            try:
                self.text = visual.TextStim(
                    self.win,
                    text="準備ができたらSpaceキーを押してください",
                    color="white",
                    height=30,
                    wrapWidth=700
                )
                print("INFO: テキスト表示オブジェクト作成成功")
            except Exception as e:
                print(f"ERROR: テキスト表示オブジェクト作成中にエラー: {e}")
                self.text = None
        else:
            self.text = None
    
    def run_stage1(self):
        """コンソールベースでStage 1を実行（瞑目実験用）"""
        stage1_num = 0
        player_taps = 0
        required_taps = self.config.STAGE1
        
        # コンソールに指示を表示
        print("\nStage 1: メトロノームリズムに合わせてタップしてください")
        print("準備ができたらSpaceキーを押してください")
        
        # Spaceキーを待つ
        event.waitKeys(keyList=['space'])
        
        # 開始メッセージ
        print("開始! メトロノームのリズムに交互にタップしてください")# ExperimentRunnerクラスの__init__あたりに追加
        # self.play_call_count の初期化は __init__ で行うか、run_stage1 のこの位置で行うのが適切です。
        # 現在のコードではこの位置にあります。
        self.play_call_count = 0
        # ループ外に存在していたデバッグ用のifブロックを削除します。
        # このブロックは stage1_num のスコープや timer の状態に関して問題を引き起こす可能性がありました。
        # ログに見られる最初の DEBUG: Play Call #1 はこのブロックから出力されていました。
        
        # Reset timer and clock
        self.timer.reset()
        self.clock.reset()
        
        # Event loop for Stage 1
        while True:
            # 一定間隔で音を鳴らす
            if self.timer.getTime() >= self.config.SPAN and stage1_num < required_taps:
                # このブロック内のデバッグコードは、音声再生の直前に実行されるべきものです。
                current_timer_val = self.timer.getTime() 
                stage1_num += 1
                # タイマーリセット
                self.timer.reset()
                time_after_reset = self.timer.getTime() 

                self.play_call_count += 1
                print(f"DEBUG: Play Call #{self.play_call_count}")
                print(f"DEBUG: Condition met. Timer val: {current_timer_val:.4f}, SPAN: {self.config.SPAN}")
                print(f"DEBUG: Timer reset. Val after reset: {time_after_reset:.4f}")

                # 音声再生前の状態確認と強制停止
                if self.sound_stim and hasattr(self.sound_stim, 'status'):
                    print(f"DEBUG: Sound_stim status BEFORE play: {self.sound_stim.status}")
                    if self.sound_stim.status == 1: # 1は再生中 (PLAYING)
                        print("DEBUG: Sound_stim (Stage1) was playing, stopping it now.")
                        self.sound_stim.stop()
                        # PTBが停止を処理する時間を増やす
                        core.wait(0.05) # 50ms
                
                # 音声再生
                if self.sound_stim:
                    print(f"DEBUG: Playing sound_stim.")
                    if hasattr(self.sound_stim, 'setVolume'): self.sound_stim.setVolume(2.0)
                    self.sound_stim.play()
                    if hasattr(self.sound_stim, 'status'):
                        print(f"DEBUG: Sound_stim status AFTER play issued: {self.sound_stim.status}")
                    
                    # 音声が確実に再生されるよう適切な待機時間を設定
                    # 0.3秒の音声ファイルに対して十分な再生時間を確保
                    core.wait(0.35)  # 音声長さ + マージン
                else:
                    print("DEBUG: sound_stim is None, cannot play.")
                
                print(f"[{stage1_num}回目の刺激音]")
                # 刺激タップ時刻を記録
                current_time = self.clock.getTime()
                self.stim_tap.append(current_time)
                self.full_stim_tap.append(current_time)
            
            # キー入力をチェック
            keys = event.getKeys()
            if 'space' in keys:
                # プレイヤータップ時刻を記録
                current_time = self.clock.getTime()
                self.player_tap.append(current_time)
                self.full_player_tap.append(current_time)
                player_taps += 1
                
                # プレイヤー音声再生
                if self.sound_player:
                    try:
                        # すでに再生中なら停止
                        if hasattr(self.sound_player, 'status') and self.sound_player.status == 1: # PLAYING
                            print("DEBUG: Sound_player (Stage1) was playing, stopping it now.")
                            self.sound_player.stop()
                            core.wait(0.05)  # 停止待機時間を調整 (50ms)
                        
                        # 即時再生
                        if hasattr(self.sound_player, 'setVolume'): self.sound_player.setVolume(2.0)
                        self.sound_player.play()
                        print(f"[{player_taps}回目のプレイヤータップ音]")
                    except Exception as play_err:
                        print(f"警告: 音声再生に失敗しましたが続行します: {play_err}")
                
                # 刺激音の再生終了後、残りのタップ数を更新
                if stage1_num >= required_taps and player_taps < required_taps:
                    remaining = required_taps - player_taps
                    print(f"リズムに合わせてタップしてください。あと {remaining} 回")
            
            # Escapeキーで中断
            if 'escape' in keys:
                print("実験が中断されました")
                return False
            
            # Stage1完了条件
            if stage1_num >= required_taps and player_taps >= required_taps:
                print("INFO: Stage1完了。Stage2へ移行します")
                
                # 最後の刺激タップ時刻を記録
                if len(self.stim_tap) > 0:
                    self.last_stim_tap_time = self.stim_tap[-1]
                else:
                    # 代替として現在時刻を使用
                    self.last_stim_tap_time = self.clock.getTime()
                    print("警告: Stage1で刺激タップデータが記録されていません。現在時刻を使用します。")
                
                # データ確認
                print(f"INFO: Stage1終了時点での記録データ - 刺激タップ: {len(self.stim_tap)}回, プレイヤータップ: {len(self.player_tap)}回")
                
                # 次のタップ予測時刻を計算
                self.next_expected_tap_time = self.last_stim_tap_time + self.config.SPAN
                print(f"INFO: 次の予想タップ時刻: {self.next_expected_tap_time:.3f}秒")
                
                return True
    
    def run_stage2(self):
        """コンソールベースでStage 2を実行（瞑目実験用）"""
        flag = 1  # 0: Player's turn, 1: Stimulus turn
        turn = 0
        
        # ステージ間の連続性を保つため、コンソールに指示を表示
        print("\nStage 2: 交互タッピング開始")
        print("刺激音に合わせてタップしてください")
        
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
        
        # ログ出力
        print(f"INFO: Stage2開始 - 次のタップまでの待機時間: {random_second:.3f}秒")
        
        # Stage 2の主要ループ
        while True:
            # 刺激側のターン
            if self.sound_stim and self.timer.getTime() >= random_second and flag == 1:
                # 音声の状態をチェック
                if hasattr(self.sound_stim, 'status') and self.sound_stim.status == 1: # PLAYING
                    # 既に再生中の場合は止めてから再生
                    print("DEBUG: Sound_stim (Stage2) was playing, stopping it now.")
                    self.sound_stim.stop()
                    # 完全に停止するまで少し待機
                    core.wait(0.05) # 50ms
                    
                # 音声の即時再生（待機なしで高精度を維持）
                if self.sound_stim is not None:
                    # 安全にsetVolumeを呼び出す（あれば）
                    if hasattr(self.sound_stim, 'setVolume'):
                        try:
                            self.sound_stim.setVolume(2.0)  # 音量を最大に設定
                        except Exception as vol_err:
                            print(f"警告: 音量設定に失敗しましたが続行します: {vol_err}")
                    
                    # 最小レイテンシーでplay()を呼び出し
                    try:
                        self.sound_stim.play()
                        print(f"[{turn+1}回目の刺激音]")
                    except Exception as play_err:
                        print(f"警告: 音声再生に失敗しましたが続行します: {play_err}")
                
                current_time = self.clock.getTime()
                self.stim_tap.append(current_time)
                self.full_stim_tap.append(current_time)
                
                # If using Bayesian models, store hypothesis data
                if hasattr(self.model, 'get_hypothesis'):
                    self.hypo.append(self.model.get_hypothesis())
                
                # プレイヤーのターンに切り替え
                flag = 0
                turn += 1
                
                # 最後のターンに達したら終了
                if turn >= (self.config.STAGE2 + self.config.BUFFER*2):
                    # 終了メッセージを表示
                    print(f"INFO: 最終ターン({turn})に到達しました。最後のタップを行ってください")
                    self.final_turn_reached = True
                    
                    # プレイヤーがタップするまで待機
                    waiting_for_final_tap = True
                    while waiting_for_final_tap:
                        # コンソールで最後のタップを促す
                        print("最後のタップを行ってください (Spaceキー) または 終了 (Escキー)", end="\r")
                        
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
                            print("\n実験完了！お疲れ様でした")
                            
                            # 待機ループを終了
                            waiting_for_final_tap = False
                            print("INFO: プレイヤーの最終タップを記録しました")
                        
                        elif 'escape' in final_keys:
                            # エスケープキーで中断
                            print("\n実験が中断されました")
                            return False
                        
                        # 短い待機で処理負荷を軽減
                        core.wait(0.01)
                    
                    # 実験を終了
                    return True
            
            # プレイヤーのターン
            if self.sound_player and flag == 0:
                keys = event.getKeys()
                if 'space' in keys:
                    current_time = self.clock.getTime()
                    self.player_tap.append(current_time)
                    self.full_player_tap.append(current_time)
                    
                    # プレイヤー音声再生
                    if self.sound_player is not None:
                        # 安全に状態をチェックして停止（必要な場合）
                        if hasattr(self.sound_player, 'status') and self.sound_player.status == 1: # PLAYING
                            print("DEBUG: Sound_player (Stage2) was playing, stopping it now.")
                            self.sound_player.stop()
                            core.wait(0.05)  # 停止完了を待機 (50ms)
                            
                        # 再生
                        try:
                            if hasattr(self.sound_player, 'setVolume'): self.sound_player.setVolume(2.0)
                            self.sound_player.play()
                            print(f"[{turn}回目のプレイヤータップ音]")
                        except Exception as play_err:
                            print(f"警告: 音声再生に失敗しましたが続行します: {play_err}")
                    
                    # 最小限の待機時間で高精度を維持
                    core.wait(0.1)  # タイミング精度向上のため待機時間を短縮
                    
                    # 同期エラー計算
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
                    print("\n実験が中断されました")
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
            
            for t in range(len(self.player_tap)):
                # プレイヤーのITI計算: 現在のプレイヤータップと対応する刺激タップの差
                # 交互タッピングでは同じインデックス同士が対応するタップペア
                if t < len(self.stim_tap):
                    self.player_iti.append(self.player_tap[t] - self.stim_tap[t])
            
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
            
            # ITIの統計情報を出力（デバッグ用）
            if len(self.stim_iti) > 0:
                print(f"INFO: 刺激ITI - 個数: {len(self.stim_iti)}, 平均: {sum(self.stim_iti)/len(self.stim_iti):.3f}秒, 最小: {min(self.stim_iti):.3f}秒, 最大: {max(self.stim_iti):.3f}秒")
            
            if len(self.player_iti) > 0:
                print(f"INFO: プレイヤーITI - 個数: {len(self.player_iti)}, 平均: {sum(self.player_iti)/len(self.player_iti):.3f}秒, 最小: {min(self.player_iti):.3f}秒, 最大: {max(self.player_iti):.3f}秒")
            
            # データを保存
            self._save_data_organized()
            
            return True
            
        except Exception as e:
            print(f"エラー: データ分析中に例外が発生しました: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    # def _remove_buffer_data(self, buffer):
    #     """Remove buffer data from beginning only (not end) of primary data lists.
    #     
    #     Args:
    #         buffer: Number of data points to remove from beginning
    #     """
    #     # Helper function to slice lists safely (only from beginning)
    #     def safe_slice_start(data_list, start):
    #         if not data_list:
    #             return []
    #         if start >= len(data_list):
    #             return []
    #         return data_list[start:]
    #     
    #     # Only remove buffer from the beginning of tap times
    #     print(f"INFO: バッファー処理前 - 刺激タップ: {len(self.stim_tap)}回, プレイヤータップ: {len(self.player_tap)}回")
    #     self.stim_tap = safe_slice_start(self.stim_tap, buffer)
    #     self.player_tap = safe_slice_start(self.player_tap, buffer)
    #     print(f"INFO: バッファー処理後 - 刺激タップ: {len(self.stim_tap)}回, プレイヤータップ: {len(self.player_tap)}回")
    #     
    #     # Hypothesis data (raw data) should also have buffer removed from beginning
    #     if self.hypo:
    #         self.hypo = safe_slice_start(self.hypo, buffer)
    #     
    #     # Note: The derived measures (SE, ITI, etc.) are calculated AFTER removing buffers,
    #     # so we don't need to remove buffer from those arrays.
    
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
            
            # 完了メッセージ（コンソールベース）
            print("\n実験が正常に完了しました！お疲れ様でした")
            
            # GUIがある場合（将来の拡張のために残しておく）
            if self.win is not None and self.text is not None:
                try:
                    self.text.setText("Experiment completed!\nThank you for participating.")
                    self.text.draw()
                    self.win.flip()
                    core.wait(3.0)
                except Exception as e:
                    print(f"注: GUI表示に失敗しましたが、実験は正常に完了しています: {e}")
            
            # 実験終了時にガベージコレクションを再有効化
            gc.enable()
            gc.collect()  # 明示的にGCを実行して実験中に溜まったメモリを解放
            
            return True
            
        except Exception as e:
            print(f"Error during experiment: {e}")
            return False
            
        finally:
            # 実験中断時もガベージコレクションを再有効化
            gc.enable()
            
            # Clean up
            if self.win:
                self.win.close()