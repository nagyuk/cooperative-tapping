import numpy as np
from scipy.stats import norm


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


# 使い方：クラスを生成して、inference に観測値を渡して、予測値を受け取るだけ。
# scale の値をいじると、曖昧性が高くなる。
if __name__ == '__main__':
    b = ContBayes(-2, 2, 20, 0, 0.3)
    for t in range(100):
        print(b.inference(np.random.randn()))
