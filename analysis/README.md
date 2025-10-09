# データ分析スクリプト

このディレクトリには、Human-Humanデータからモデルパラメータを推定するためのスクリプトが含まれています。

## 使用方法

### パラメータ推定

```matlab
% Human-Humanデータからパラメータを推定
params = estimate_parameters_from_human_data('data/raw/human_human/');

% 結果:
%   params.SPAN_mean           - 推奨SPAN値
%   params.SCALE_mean          - 推奨SCALE値
%   params.BAYES_N_HYPOTHESIS  - 推奨仮説数
%   params.BIB_L_MEMORY        - 推奨メモリ長
```

## ファイル

- `estimate_parameters_from_human_data.m` - パラメータ推定スクリプト
- `estimated_parameters.mat` - 推定結果（スクリプト実行後に生成）

## 詳細

詳しい実験計画については `docs/parameter_validation_plan.md` を参照してください。
