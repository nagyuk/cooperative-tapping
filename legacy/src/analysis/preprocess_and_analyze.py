import os
import glob
import pandas as pd
import subprocess # network.pyをサブプロセスとして呼び出す場合に必要

# --- 設定項目 ---
DATA_PRE_DIR = "/Users/sasailab/cooperative-tapping/data/pre"
NETWORK_SCRIPT_PATH = "/Users/sasailab/cooperative-tapping/src/analysis/network.py"

# network.py から分析関数をインポートする場合の試み
ANALYSIS_FUNCTION = None
try:
    # network.py が同じディレクトリにあり、直接インポート可能な場合
    # import network
    # ANALYSIS_FUNCTION = network.run_analysis # 例: network.py に run_analysis(dataframe) があると仮定

    # network.py がパッケージの一部として同じディレクトリにある場合
    from . import network # network.py が同じ analysis ディレクトリ内にある場合
    ANALYSIS_FUNCTION = network.run_analysis # 例: network.py に run_analysis(dataframe) があると仮定
    print("network.pyから分析関数をインポートしました。")
except ImportError:
    print(f"警告: 'network'モジュールのインポートに失敗しました。network.pyはサブプロセスとして呼び出されるか、分析ステップがスキップされます。")
except AttributeError:
    print(f"警告: 'network'モジュールはインポートできましたが、指定された分析関数が見つかりません。")
    ANALYSIS_FUNCTION = None # 関数が見つからなかった場合


# --- ヘルパー関数 ---
def extract_participant_id_from_filename(filename_basename):
    """
    ファイル名（拡張子なし）から参加者IDを抽出するプレースホルダー関数。
    実際のファイル命名規則に基づいて、この関数をカスタマイズする必要があります。

    例:
    - "bayes0_tap_participantA.csv" -> "participantA"
    - "data_subject123_modify.csv" -> "subject123"

    Args:
        filename_basename (str): CSVファイルのベース名（例: "bayes0_tap_ark2"）。

    Returns:
        str: 抽出された参加者ID。
    """
    # --- !!! お客様によるカスタマイズが必須です !!! ---
    # 以下は非常に単純な例です。実際の命名規則に合わせて調整してください。
    parts = filename_basename.split('_')
    if len(parts) > 2 and parts[1] == "tap": # 例: "bayes0_tap_ark2" -> "ark2"
        return parts[2]
    elif len(parts) > 1: # 例: "modify_user1" -> "user1"
        return parts[-1]
    print(f"警告: '{filename_basename}' から参加者IDを抽出できませんでした。デフォルトIDを使用します。 extract_participant_id_from_filename を確認してください。")
    return f"unknown_pid_{filename_basename}"

# --- データ標準化関数 ---
def standardize_data_for_analysis(df, file_type, participant_id):
    """
    異なる形式のDataFrameをnetwork.pyが期待する共通形式に標準化します。
    提供されたCSV形式（インデックス列、Player_tap, Stim_tap）を前提とします。

    Args:
        df (pd.DataFrame): 処理対象のDataFrame。
        file_type (str): ファイルの種類 ("bayes0", "bayes1", "modify", "unknown")。

    Returns:
        pd.DataFrame: 標準化されたDataFrame。
    """
    print(f"ファイルタイプ '{file_type}', 参加者ID '{participant_id}' のデータを標準化中...")
    standardized_df = df.copy()

    # network.py が期待するカラム名と理想的なデータ型を定義
    TARGET_COLUMNS_SCHEMA = {
        "trial_index": "Int64",      # 元のCSVのインデックス (Nullable Integer)
        "participant_id": "str",
        "model_type": "str",         # bayes0, bayes1, modify
        "player_tap_time": "float64",
        "stim_tap_time": "float64",
    }

    # 元のDataFrameのインデックスを列として追加
    standardized_df['trial_index'] = df.index

    # 参加者IDとモデルタイプを列として追加
    standardized_df['participant_id'] = participant_id
    standardized_df['model_type'] = file_type

    # カラム名を標準的な名前に変更
    # "すべてこの形式です" とのことなので、入力カラム名は Player_tap, Stim_tap で固定と仮定
    rename_map = {
        "Player_tap": "player_tap_time",
        "Stim_tap": "stim_tap_time"
    }
    standardized_df.rename(columns=rename_map, inplace=True)

    # 最終的なカラムリスト
    final_columns_ordered = list(TARGET_COLUMNS_SCHEMA.keys())
    output_df = pd.DataFrame(columns=final_columns_ordered) # 型情報を持つ空のDFを作成

    for target_col, target_type in TARGET_COLUMNS_SCHEMA.items():
        if target_col in standardized_df.columns:
            output_df[target_col] = standardized_df[target_col]
            # --- お客様によるカスタマイズが必要 ---
            # データ型変換 (必要に応じてより堅牢なエラー処理を追加してください)
            try:
                if output_df[target_col].notna().any(): # 全てNaNのカラムは変換を試みない
                    if "datetime" in target_type and not pd.api.types.is_datetime64_any_dtype(output_df[target_col]):
                        output_df[target_col] = pd.to_datetime(output_df[target_col], errors='coerce')
                    elif "float" in target_type and not pd.api.types.is_float_dtype(output_df[target_col]):
                        output_df[target_col] = pd.to_numeric(output_df[target_col], errors='coerce')
                    elif "int" in target_type and not pd.api.types.is_integer_dtype(output_df[target_col]):
                        output_df[target_col] = pd.to_numeric(output_df[target_col], errors='coerce').astype('Int64') # Nullable Integer
                    elif "str" in target_type and not pd.api.types.is_string_dtype(output_df[target_col]):
                        output_df[target_col] = output_df[target_col].astype(str)
            except Exception as e:
                print(f"警告: カラム '{target_col}' の型変換に失敗しました ({file_type}): {e}")
        else:
            print(f"情報: ターゲットカラム '{target_col}' が標準化プロセスで生成される前の '{file_type}' のデータに存在しませんでした。NaN/NaTで初期化します。")
            if "datetime" in target_type:
                output_df[target_col] = pd.NaT
            else:
                output_df[target_col] = pd.NA

    # TARGET_COLUMNS_SCHEMA に定義されたカラムのみを選択し、順序を保証する
    return output_df[final_columns_ordered]


# --- ファイルタイプ別パース関数 ---
def parse_csv_file(filepath, file_type_hint, participant_id):
    """
    指定されたCSVファイルを読み込み、基本的な前処理と標準化を行います。
    提供されたCSV形式（インデックス列、Player_tap, Stim_tap）を前提とします。
    """
    filename = os.path.basename(filepath)
    print(f"ファイル '{filename}' (タイプ: {file_type_hint}, 参加者ID: {participant_id}) を処理中...")
    try:
        # 提供されたCSVの最初の列はインデックスなので、index_col=0 を指定
        df = pd.read_csv(filepath, index_col=0)

        # ここで、必要であればファイルタイプに特有の追加クリーニングや変換を行う
        # if file_type_hint == "specific_type_needing_special_handling":
        #     df = some_special_cleaning(df)

        return standardize_data_for_analysis(df, file_type_hint, participant_id)
    except pd.errors.EmptyDataError:
        print(f"エラー: ファイル {filepath} は空です。")
        return None
    except Exception as e:
        print(f"エラー: ファイル {filepath} の処理中にエラーが発生しました: {e}")
        return None


def main():
    csv_files = glob.glob(os.path.join(DATA_PRE_DIR, "*.csv"))

    if not csv_files:
        print(f"{DATA_PRE_DIR} にCSVファイルが見つかりませんでした。")
        return

    all_analysis_results = [] # network.pyからの結果を格納する場合

    for filepath in csv_files:
        base_filename = os.path.basename(filepath)
        filename_lower = base_filename.lower()
        filename_no_ext = base_filename.removesuffix('.csv')

        standardized_df = None
        file_type = "unknown"

        # ファイル名から参加者IDを抽出 (!!! 要カスタマイズ !!!)
        participant_id = extract_participant_id_from_filename(filename_no_ext)

        # ファイル名からファイルタイプを判定
        # "byayes1" は "bayes1" のタイプミスと仮定
        if "bayes0" in filename_lower:
            file_type = "bayes0" # ベイズモデル
        elif "bayes1" in filename_lower or "byayes1" in filename_lower:
            file_type = "bayes1" # BIBモデル
        elif "modify" in filename_lower:
            file_type = "modify" # SE平均モデル
        else:
            print(f"警告: ファイル {base_filename} は既知のファイルタイプパターンに一致しません。タイプを 'unknown' とします。")
            # file_type は "unknown" のまま

        standardized_df = parse_csv_file(filepath, file_type, participant_id)

        if standardized_df is not None and not standardized_df.empty:
            print(f"ファイル {base_filename} の処理と標準化が完了しました。")

            # --- network.py を使った分析 ---
            if ANALYSIS_FUNCTION:
                try:
                    print(f"インポートされた関数を使用して {os.path.basename(filepath)} のデータを分析中...")
                    # ANALYSIS_FUNCTION がDataFrameを受け取り、何らかの結果を返すと仮定
                    result = ANALYSIS_FUNCTION(standardized_df)
                    if result is not None:
                        all_analysis_results.append({
                            "file": base_filename,
                            "result": result
                        })
                    print(f"{base_filename} の分析が完了しました。")
                except Exception as e:
                    print(f"エラー: インポートされた関数による {base_filename} の分析中にエラー: {e}")
            elif os.path.exists(NETWORK_SCRIPT_PATH):
                # network.py をサブプロセスとして呼び出す場合
                # この例では、標準化されたDataFrameを一時的なCSVファイルとして保存し、
                # それを network.py に渡します。
                temp_csv_path = os.path.join(DATA_PRE_DIR, f"temp_standardized_{base_filename}")
                try:
                    standardized_df.to_csv(temp_csv_path, index=False)
                    print(f"サブプロセスとして {NETWORK_SCRIPT_PATH} を実行し、{base_filename} のデータを分析中...")
                    
                    # --- お客様によるカスタマイズが必要 ---
                    # network.py の呼び出し方を調整してください。
                    # 例: network.py がCSVファイルパスを引数に取り、結果を標準出力する場合
                    process = subprocess.run(
                        ["python", NETWORK_SCRIPT_PATH, temp_csv_path],
                        capture_output=True, text=True, check=False, encoding='utf-8'
                    )
                    print(f"--- {base_filename} の分析結果 (標準出力) ---")
                    print(process.stdout)
                    if process.stderr:
                        print(f"--- {base_filename} の分析エラー (標準エラー出力) ---")
                        print(process.stderr)
                    
                    # network.py が結果ファイルを出力する場合、その処理をここに追加
                    # all_analysis_results.append(...)

                except subprocess.CalledProcessError as e:
                    print(f"エラー: {NETWORK_SCRIPT_PATH} の実行に失敗 ({base_filename} via {temp_csv_path}): {e}")
                    print(f"Stdout: {e.stdout}")
                    print(f"Stderr: {e.stderr}")
                except Exception as e:
                    print(f"エラー: サブプロセス実行中に予期せぬエラー ({base_filename}): {e}")
                finally:
                    if os.path.exists(temp_csv_path):
                        os.remove(temp_csv_path) # 一時ファイルを削除
            else:
                print(f"警告: {base_filename} の分析をスキップします。network.pyの関数またはスクリプトパスが設定されていません。")
        else:
            print(f"ファイル {base_filename} の処理に失敗したか、データが空です。分析をスキップします。")

    if all_analysis_results:
        print("\n--- 全ファイルの集計分析結果 ---")
        for item in all_analysis_results:
            print(f"ファイル: {item['file']}, 結果: {item['result']}")
        # ここで all_analysis_results をさらに処理・保存できます。

if __name__ == "__main__":
    main()