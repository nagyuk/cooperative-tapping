from psychopy import visual, core, event, sound
from scipy.stats import norm
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import datetime

# 基準の間隔
span = 2

#Stage1のtap回数
stage1 = 10

#Stage2のtap回数
stage2 = 100

#データ除外分
buffer = 10

#分散
scale = 0.1

# YYYYMMDDhhmmss形式に書式化
t_delta = datetime.timedelta(hours=9)
JST = datetime.timezone(t_delta, 'JST')
now = datetime.datetime.now(JST)
d = now.strftime('%Y%m%d%H%M')

#実験番号
serial_num = d

# ウィンドウを作成
win = visual.Window(size=(800, 600), monitor="testMonitor", color="black")

# サウンドのファイルパスを指定
sound_file_02a = "button02a.mp3" 
sound_file_03a = "button03a.mp3"

# サウンドオブジェクトを作成
sound_02a = sound.Sound(sound_file_02a) #stim
sound_03a = sound.Sound(sound_file_03a) #Player

# テキストを表示
text = visual.TextStim(win, text="Press SPACE to play rythm", color="white")

# 時間計測用のクロックを作成
clock = core.Clock()

# 2秒ごとに音を鳴らすためのクロックを作成
timer = core.Clock()

# 最初の音を鳴らす回数を数える変数
stage1_num = 0

#どちらのターンかの判定,0ならPlyaer,1ならstim
flag = 0 

#ターン数の計測
turn = 0

#修正値
bayes0 = 0

#時間を保存するリスト
stim_tap = [span * stage1] #stimが鳴らした時刻を記録するリスト
player_tap = [span * (stage1 - 1/2)] 

#ITI_A(n) = Tap_A(n) - Tap_B(n-1)
stim_ITI = []
player_ITI = []

#ITIv(n) = ITI(n + 1) - ITI(n)
stim_ITIv = []
player_ITIv = []

#SE_A(n) = Tap_B(n)-{(Tap_A(n) + Tap_A(n-1))/2}
stim_SE = []
player_SE = []

#SEv(n) = SE(n) - SE(n-1)
stim_SEv = []
player_SEv = []

#仮説
hypo = []

#r2を求める関数
def r2_score_manual(y_true, y_pred):
    y_mean = np.mean(y_true)
    ss_total = np.sum((y_true - y_mean) ** 2)
    ss_residual = np.sum((y_true - y_pred) ** 2)
    r2 = 1 - (ss_residual / ss_total)
    return r2

#クラス ContBayes
class ContBayes(object):
    def __init__(self, x_min, x_max, n_hypothesis, l_memory, scale):
        # x_min:最小値, x_max:最大値, n_hypothesis:仮説の個数, l_memory:逆ベイズの記憶長, scale:分散
        # l_memory を 0 にすると、単純なベイズ推論ができる。>= 1 で逆ベイズ推論を行う。
        self.scale = scale
        self.n_hypothesis = int(n_hypothesis)
        self.l_memory = int(l_memory)
        self.likelihood = np.linspace(x_min, x_max, n_hypothesis)
        self.h_prov = np.ones(self.n_hypothesis) / self.n_hypothesis
        if l_memory > 0:
            self.memory = np.random.normal(loc=0.0, scale=self.scale, size=self.l_memory)

    def inference(self, data):  # 推論を行うメソッド。推論値を返す。
        if self.l_memory > 0:  # 逆ベイズの学習をする
            new_hypo = np.mean(self.memory)
            inv_h_prov = (1 - self.h_prov) / (self.n_hypothesis - 1)
            self.likelihood[np.random.choice(np.arange(self.n_hypothesis), p=inv_h_prov)] = new_hypo
            self.memory = np.roll(self.memory, -1)
            self.memory[-1] = data

        # ベイズ学習をする
        post_prov = [norm(self.likelihood[i], 0.3).pdf(data) for i in range(self.n_hypothesis)] * self.h_prov
        post_prov /= np.sum(post_prov)
        self.h_prov = post_prov

        # 予測に基づいて値を返す
        return np.random.normal(loc=np.random.choice(self.likelihood, p=self.h_prov), scale=0.3)

    def get_likelihood(self):
        return self.likelihood

    def get_hypothesis(self):
        return self.h_prov

#クラスの生成
b0 = ContBayes(-3, 3, 20, 0, scale)

#データ分析
def analysis():
    del stim_SE[0]
    
    for t in range(1, turn):
        #データ分析
        #stim
        stim_ITI.append(stim_tap[t] - player_tap[t])
        
        #player
        player_ITI.append(player_tap[t] - stim_tap[t-1])
        player_SE.append(player_tap[t] - (stim_tap[t-1]+stim_tap[t])/2)
        
    for i in range(len(stim_ITI) - 1):
        stim_ITIv.append(stim_ITI[i+1] - stim_ITI[i])
    
    for i in range(len(player_ITI) - 1):
        player_ITIv.append(player_ITI[i + 1] - player_ITI[i])
    
    for i in range(len(stim_SE) - 1):
        stim_SEv.append(stim_SE[i+1] - stim_SE[i])
    
    for i in range(len(player_SE) - 1):
        player_SEv.append(player_SE[i + 1] - player_SE[i])
    
    #バッファの削除
    del stim_tap[:buffer]
    del stim_tap[-buffer:]
    del stim_ITI[:buffer]
    del stim_ITI[-buffer:]
    del stim_ITIv[:buffer]
    del stim_ITIv[-buffer:]
    del stim_SE[:buffer]
    del stim_SE[-buffer:]
    del stim_SEv[:buffer]
    del stim_SEv[-buffer:]
    del player_tap[:buffer]
    del player_tap[-buffer:]
    del player_ITI[:buffer]
    del player_ITI[-buffer:]
    del player_ITIv[:buffer]
    del player_ITIv[-buffer:]
    del player_SE[:buffer]
    del player_SE[-buffer:]
    del player_SEv[:buffer]
    del player_SEv[-buffer:]
    del hypo[:buffer]
    del hypo[-buffer:]
    
    #csvで出力
    df = pd.DataFrame({'Player_tap': player_tap, 'Stim_tap': stim_tap})
    df.to_csv(f'bayes0_tap_{serial_num}.csv')
    
    df = pd.DataFrame({'Player_SE': player_SE, 'Stim_SE' : stim_SE})
    df.to_csv(f'bayes0_SE_{serial_num}.csv')
    
    df = pd.DataFrame({'Hypothesis': hypo})
    df.to_csv(f'bayes0_hypo_{serial_num}.csv')
    
    #グラフ
    #ITIの時間毎の推移
    plt.xlabel("Tap Number", fontsize = 24)
    plt.ylabel("ITI", fontsize = 24)
    plt.grid(True) #目盛線表示
    plt.tick_params(labelsize = 18) #目盛線ラベルサイズ
    plt.plot(stim_ITI, color = 'b', label = 'stim')
    plt.plot(player_ITI, color = 'r', label = 'PLAYER')
    plt.legend(loc = 'upper left', fontsize = '13')
    plt.savefig(f"bayes0_ITI_{serial_num}.pdf", bbox_inches = 'tight')
    plt.show()
    
    
    #ITIvの時間毎の推移
    plt.xlabel("Tap Number", fontsize = 24)
    plt.ylabel("ITIv", fontsize = 24)
    plt.grid(True) #目盛線表示
    plt.tick_params(labelsize = 18) #目盛線ラベルサイズ
    plt.plot(stim_ITIv, color = 'b', label = 'stim')
    plt.plot(player_ITIv, color = 'r', label = 'PLAYER')
    plt.legend(loc = 'upper left', fontsize = '13')
    plt.savefig(f"bayes0_ITIv_{serial_num}.pdf", bbox_inches = 'tight')
    plt.show()
    
    #SEの時間毎の推移
    plt.xlabel("Tap Number", fontsize = 24)
    plt.ylabel("SE", fontsize = 24)
    plt.grid(True) #目盛線表示
    plt.tick_params(labelsize = 18) #目盛線ラベルサイズ
    plt.plot(stim_SE, color = 'b', label = 'stim')
    plt.plot(player_SE, color = 'r', label = 'PLAYER')
    plt.legend(loc = 'upper left', fontsize = '13')
    plt.savefig(f"bayes0_SE_{serial_num}.pdf", bbox_inches = 'tight')
    plt.show()
    
    #SEvの時間毎の推移
    plt.xlabel("Tap Number", fontsize = 24)
    plt.ylabel("SEv", fontsize = 24)
    plt.grid(True) #目盛線表示
    plt.tick_params(labelsize = 18) #目盛線ラベルサイズ
    plt.plot(stim_SEv, color = 'b', label = 'stim')
    plt.plot(player_SEv, color = 'r', label = 'PLAYER')
    plt.legend(loc = 'upper left', fontsize = '13')
    plt.savefig(f"bayes0_SEv_{serial_num}.pdf", bbox_inches = 'tight')
    plt.show()
    
    #stim,playerのITIのヒストグラム
    plt.xlabel("Second", fontsize = 20)
    plt.ylabel("Frequency", fontsize = 20)
    plt.grid(True)
    plt.tick_params(labelsize = 12) #目盛線ラベルサイズ
    plt.hist(stim_ITI, alpha = 0.5, range = (0, 2.0), color = 'b', label = 'stim')
    plt.hist(player_ITI, alpha = 0.5, range = (0, 2.0), color = 'r', label = 'PLAYER')
    plt.legend(loc = 'upper left', fontsize = '13')
    plt.savefig(f"bayes0_ITI_hist_{serial_num}.pdf", bbox_inches = 'tight')
    plt.show()
    
    #StimのSEとITIの散布図
    plt.xlabel('SE')
    plt.ylabel('ITI')
    stim_SE_tmp = stim_SE.copy()
    del stim_SE_tmp[-1]
    stim_ITI_tmp = stim_ITI.copy()
    del stim_ITI_tmp[0]
    stim_SE_ITI_standard_curve = np.polyfit(stim_SE_tmp, stim_ITI_tmp, 1)
    plt.scatter(stim_SE_tmp, stim_ITI_tmp)
    y_pred = np.poly1d(np.polyfit(stim_SE_tmp, stim_ITI_tmp, 1))(stim_SE_tmp)
    plt.plot(stim_SE_tmp, y_pred)
    r2 = r2_score_manual(stim_ITI_tmp, y_pred)
    plt.legend([f'ITI = {stim_SE_ITI_standard_curve[0]:.2f}SE + {stim_SE_ITI_standard_curve[1]:.2f}',
    f'R2 = {r2:.3f}'])
    plt.savefig(f"bayes0_stim_SE_ITI_{serial_num}.pdf", bbox_inches = 'tight')
    plt.show()
    
    #StimのSEとITIvの散布図
    plt.xlabel('SE')
    plt.ylabel('ITIv')
    stim_SE_ITIv_standard_curve = np.polyfit(stim_SE_tmp, stim_ITIv, 1)
    plt.scatter(stim_SE_tmp, stim_ITIv)
    y_pred = np.poly1d(np.polyfit(stim_SE_tmp, stim_ITIv, 1))(stim_SE_tmp)
    plt.plot(stim_SE_tmp, y_pred)
    r2 = r2_score_manual(stim_ITIv, y_pred)
    plt.legend([f'ITIv = {stim_SE_ITIv_standard_curve[0]:.2f}SE + {stim_SE_ITIv_standard_curve[1]:.2f}',
    f'R2 = {r2:.3f}'])
    plt.savefig(f"bayes0_stim_SE_ITIv_{serial_num}.pdf", bbox_inches = 'tight')
    plt.show()
    
    #StimのSEvとITIの散布図
    plt.xlabel('SEv')
    plt.ylabel('ITI')
    stim_SEv_tmp = stim_SEv.copy()
    del stim_SEv_tmp[-1]
    stim_ITI_tmp = stim_ITI.copy()
    del stim_ITI_tmp[:2]
    stim_SEv_ITI_standard_curve = np.polyfit(stim_SEv_tmp, stim_ITI_tmp, 1)
    y_pred = np.poly1d(np.polyfit(stim_SEv_tmp, stim_ITI_tmp, 1))(stim_SEv_tmp)
    plt.scatter(stim_SEv_tmp, stim_ITI_tmp)
    plt.plot(stim_SEv_tmp, y_pred)
    r2 = r2_score_manual(stim_ITI_tmp, y_pred)
    plt.legend([f'ITI = {stim_SEv_ITI_standard_curve[0]:.2f}SEv + {stim_SEv_ITI_standard_curve[1]:.2f}',
    f'R2 = {r2:.3f}'])
    plt.savefig(f"bayes0_stim_SEv_ITI_{serial_num}.pdf", bbox_inches = 'tight')
    plt.show()
    
    #StimのSEvとITIvの散布図
    plt.xlabel('SEv')
    plt.ylabel('ITIv')
    stim_ITIv_tmp = stim_ITIv.copy()
    del stim_ITIv_tmp[0]
    stim_SEv_ITIv_standard_curve = np.polyfit(stim_SEv_tmp, stim_ITIv_tmp, 1)
    y_pred = np.poly1d(np.polyfit(stim_SEv_tmp, stim_ITIv_tmp, 1))(stim_SEv_tmp)
    plt.scatter(stim_SEv_tmp, stim_ITIv_tmp)
    plt.plot(stim_SEv_tmp, y_pred)
    r2 = r2_score_manual(stim_ITIv_tmp, y_pred)
    plt.legend([f'ITIv = {stim_SE_ITIv_standard_curve[0]:.2f}SEv + {stim_SE_ITIv_standard_curve[1]:.2f}',
    f'R2 = {r2:.3f}'])
    plt.savefig(f"bayes0_stim_SEv_ITIv_{serial_num}.pdf", bbox_inches = 'tight')
    plt.show()
    
    #PlayerのSEとITIの散布図
    plt.xlabel('SE')
    plt.ylabel('ITI')
    player_SE_tmp = player_SE.copy()
    del player_SE_tmp[-1]
    player_ITI_tmp = player_ITI.copy()
    del player_ITI_tmp[0]
    player_standard_curve = np.polyfit(player_SE_tmp, player_ITI_tmp, 1)
    y_pred = np.poly1d(np.polyfit(player_SE_tmp, player_ITI_tmp, 1))(player_SE_tmp)
    plt.scatter(player_SE_tmp, player_ITI_tmp)
    plt.plot(player_SE_tmp, y_pred)
    r2 = r2_score_manual(player_ITI_tmp, y_pred)
    plt.legend([f'ITI = {player_standard_curve[0]:.2f}SE + {player_standard_curve[1]:.2f}',
    f'R2 = {r2:.3f}'])
    plt.savefig(f"bayes0_player_SE_ITI_{serial_num}.pdf", bbox_inches = 'tight')
    plt.show()
    
    #PlayerのSEとITIvの散布図
    plt.xlabel('SE')
    plt.ylabel('ITIv')
    player_ITIv_standard_curve = np.polyfit(player_SE_tmp, player_ITIv, 1)
    y_pred = np.poly1d(np.polyfit(player_SE_tmp, player_ITIv, 1))(player_SE_tmp)
    plt.scatter(player_SE_tmp, player_ITIv)
    plt.plot(player_SE_tmp, y_pred)
    r2 = r2_score_manual(player_ITIv, y_pred)
    plt.legend([f'ITIv = {player_ITIv_standard_curve[0]:.2f}SE + {player_ITIv_standard_curve[1]:.2f}',
    f'R2 = {r2:.3f}'])
    plt.savefig(f"bayes0_player_SE_ITIv_{serial_num}.pdf", bbox_inches = 'tight')
    plt.show()
    
    #PlayerのSEvとITIの散布図
    plt.xlabel('SEv')
    plt.ylabel('ITI')
    player_SEv_tmp = player_SEv.copy()
    del player_SEv_tmp[-1]
    player_ITI_tmp = player_ITI.copy()
    del player_ITI_tmp[:2]
    player_standard_curve = np.polyfit(player_SEv_tmp, player_ITI_tmp, 1)
    y_pred = np.poly1d(np.polyfit(player_SEv_tmp, player_ITI_tmp, 1))(player_SEv_tmp)
    plt.scatter(player_SEv_tmp, player_ITI_tmp)
    plt.plot(player_SEv_tmp, y_pred)
    r2 = r2_score_manual(player_ITI_tmp, y_pred)
    plt.legend([f'ITI = {player_standard_curve[0]:.2f}SEv + {player_standard_curve[1]:.2f}',
    f'R2 = {r2:.3f}'])
    plt.savefig(f"bayes0_player_SEv_ITI_{serial_num}.pdf", bbox_inches = 'tight')
    plt.show()
    
    #PlayerのSEvとITIvの散布図
    plt.xlabel('SEv')
    plt.ylabel('ITIv')
    player_ITIv_tmp = player_ITIv.copy()
    del player_ITIv_tmp[0]
    player_ITIv_standard_curve = np.polyfit(player_SEv_tmp, player_ITIv_tmp, 1)
    y_pred = np.poly1d(np.polyfit(player_SEv_tmp, player_ITIv_tmp, 1))(player_SEv_tmp)
    plt.scatter(player_SEv_tmp, player_ITIv_tmp)
    plt.plot(player_SEv_tmp, y_pred)
    r2 = r2_score_manual(player_ITIv_tmp, y_pred)
    plt.legend([f'ITIv = {player_ITIv_standard_curve[0]:.2f}SEv + {player_ITIv_standard_curve[1]:.2f}',
    f'R2 = {r2:.3f}'])
    plt.savefig(f"bayes0_player_SEv_ITIv_{serial_num}.pdf", bbox_inches = 'tight')
    plt.show()

# イベントループを開始
while True:
    # タイマーが2秒以上経過したら音を再生してタイマーをリセット
    if timer.getTime() >= span:
        stage1_num += 1
        sound_02a.play()
        timer.reset()

    # キー入力をチェック
    keys = event.getKeys()
    if 'space' in keys:
        # スペースキーが押されたらCの音を再生
        sound_03a.play()
    
    if 'escape' in keys:
        # エスケープキーが押されたらプログラムを終了
        win.close()
        core.quit()

    # stage1_num回鳴らしたらブレーク
    if stage1_num >= stage1:
        random_second = np.random.normal(span, scale)
        break

# イベントループを開始
while True:
    # タイマーがrandom秒以上経過したら音を再生してタイマーをリセット
    if timer.getTime() >= random_second and flag == 1:
        sound_02a.play()
        stim_tap.append(clock.getTime())
        hypo.append(b0.get_hypothesis())
        
        #ターンをかえす
        flag = 0
        turn += 1
        
        #stage2+1の回数を迎えたら終了
        if turn >= (stage2 + buffer*2):
            analysis()
            break
        
    # キー入力をチェック
    if flag == 0:
        keys = event.getKeys()
        if 'space' in keys:
            # スペースキーが押されたら現在の時間を記録
            player_tap.append(clock.getTime())
            
            # スペースキーが押されたら音を再生
            sound_03a.play()

            #SEの計算
            stim_SE.append(stim_tap[turn] - (player_tap[turn] + player_tap[turn + 1])/2)
            
            #タイマーの作成
            random_second = ((span / 2) - b0.inference(stim_SE[turn]))
            
            #時間をリセット
            timer.reset()
            flag = 1
            
        if 'escape' in keys:
            analysis()
            
            # エスケープキーが押されたらプログラムを終了
            break

# ウィンドウを閉じる
win.close()
core.quit()