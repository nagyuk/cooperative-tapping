"""
Visualization tools for cooperative tapping analysis.
Provides functions to create various plots for data analysis.
"""
import matplotlib.pyplot as plt
import numpy as np
import os
from .metrics import calculate_regression

def plot_time_series(stim_data, player_data, title, ylabel, output_path, 
                    figsize=(10, 6), colors=('b', 'r')):
    """Plot time series data for stimulus and player.
    
    Args:
        stim_data: Stimulus data series
        player_data: Player data series
        title: Plot title
        ylabel: Y-axis label
        output_path: Path to save the plot
        figsize: Figure size (width, height)
        colors: Colors for stimulus and player lines
    """
    plt.figure(figsize=figsize)
    plt.title(title)
    plt.xlabel("Tap Number", fontsize=16)
    plt.ylabel(ylabel, fontsize=16)
    plt.grid(True)
    plt.tick_params(labelsize=12)
    
    x_stim = range(len(stim_data))
    x_player = range(len(player_data))
    
    plt.plot(x_stim, stim_data, color=colors[0], label='Stimulus')
    plt.plot(x_player, player_data, color=colors[1], label='Player')
    
    plt.legend(loc='upper left', fontsize=12)
    
    # Create directory if it doesn't exist
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    plt.savefig(output_path, bbox_inches='tight', dpi=300)
    plt.close()

def plot_histogram(stim_data, player_data, title, xlabel, output_path,
                  figsize=(10, 6), bin_range=(0, 2.0), colors=('b', 'r')):
    """Plot histograms for stimulus and player data.
    
    Args:
        stim_data: Stimulus data
        player_data: Player data
        title: Plot title
        xlabel: X-axis label
        output_path: Path to save the plot
        figsize: Figure size (width, height)
        bin_range: Range for histogram bins
        colors: Colors for stimulus and player histograms
    """
    plt.figure(figsize=figsize)
    plt.title(title)
    plt.xlabel(xlabel, fontsize=16)
    plt.ylabel("Frequency", fontsize=16)
    plt.tick_params(labelsize=12)
    
    plt.hist(stim_data, alpha=0.5, range=bin_range, color=colors[0], label='Stimulus')
    plt.hist(player_data, alpha=0.5, range=bin_range, color=colors[1], label='Player')
    
    plt.legend(loc='upper left', fontsize=12)
    
    # Create directory if it doesn't exist
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    plt.savefig(output_path, bbox_inches='tight', dpi=300)
    plt.close()

def plot_scatter_with_regression(x, y, title, xlabel, ylabel, output_path, figsize=(10, 6)):
    """Plot scatter with regression line.
    
    Args:
        x: X values
        y: Y values
        title: Plot title
        xlabel: X-axis label
        ylabel: Y-axis label
        output_path: Path to save the plot
        figsize: Figure size (width, height)
    """
    slope, intercept, r2 = calculate_regression(x, y)
    
    plt.figure(figsize=figsize)
    plt.title(title)
    plt.xlabel(xlabel, fontsize=16)
    plt.ylabel(ylabel, fontsize=16)
    
    # Scatter plot
    plt.scatter(x, y, alpha=0.7)
    
    # Add regression line if regression was successful
    if not np.isnan(slope):
        x_line = np.array([min(x), max(x)])
        y_line = slope * x_line + intercept
        plt.plot(x_line, y_line, 'r-', linewidth=2)
        
        # Add equation and R² to legend
        equation = f"{ylabel} = {slope:.2f} · {xlabel} + {intercept:.2f}"
        r2_text = f"R² = {r2:.3f}"
        plt.legend([equation, r2_text], loc='best', fontsize=12)
    
    # Create directory if it doesn't exist
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    plt.savefig(output_path, bbox_inches='tight', dpi=300)
    plt.close()

def create_all_visualizations(data_dict, model_type, experiment_id, output_dir):
    """Create all standard visualizations for experiment data.
    
    Args:
        data_dict: Dictionary containing all data series
        model_type: Type of model used (sea, bayes, bib)
        experiment_id: Experiment ID (timestamp)
        output_dir: Directory to save plots
    """
    import datetime
    
    # 日付からディレクトリ名を生成（年月日）
    if len(experiment_id) >= 8:  # YYYYMMDDHHMMの形式を想定
        date_prefix = experiment_id[:8]
    else:
        # フォールバック: 現在の日付を使用
        date_prefix = datetime.datetime.now().strftime('%Y%m%d')
    
    # 被験者IDを取得（データに含まれていない場合は'anonymous'を使用）
    subject_id = data_dict.get('subject_id', 'anonymous')
    
    # 出力ディレクトリの構造化されたパス
    viz_dir = os.path.join(
        output_dir,
        f"{date_prefix}_{subject_id}",
        f"{model_type}_{experiment_id}"
    )
    
    # ベースパスを定義（base_pathが後で使用される）
    base_path = os.path.join(
        output_dir,
        f"{date_prefix}_{subject_id}",
        f"{model_type}_{experiment_id}"
    )
    
    # ディレクトリが存在しない場合は作成
    os.makedirs(viz_dir, exist_ok=True)
    
    print(f"Saving visualizations to: {viz_dir}")
    
    # 時系列プロット
    if 'stim_iti' in data_dict and 'player_iti' in data_dict:
        plot_time_series(
            data_dict['stim_iti'], 
            data_dict['player_iti'],
            "Inter Tap-onset Intervals Over Time",
            "ITI (seconds)",
            os.path.join(viz_dir, "ITI.pdf")
        )
    
    if 'stim_itiv' in data_dict and 'player_itiv' in data_dict:
        plot_time_series(
            data_dict['stim_itiv'], 
            data_dict['player_itiv'],
            "ITI Variations Over Time",
            "ITIv (seconds)",
            os.path.join(viz_dir, "ITIv.pdf")
        )
    
    if 'stim_se' in data_dict and 'player_se' in data_dict:
        plot_time_series(
            data_dict['stim_se'], 
            data_dict['player_se'],
            "Synchronization Errors Over Time",
            "SE (seconds)",
            os.path.join(viz_dir, "SE.pdf")
        )
    
    if 'stim_sev' in data_dict and 'player_sev' in data_dict:
        plot_time_series(
            data_dict['stim_sev'], 
            data_dict['player_sev'],
            "SE Variations Over Time",
            "SEv (seconds)",
            os.path.join(viz_dir, "SEv.pdf")
        )
    
    # ヒストグラム
    if 'stim_iti' in data_dict and 'player_iti' in data_dict:
        plot_histogram(
            data_dict['stim_iti'], 
            data_dict['player_iti'],
            "Distribution of Inter Tap-onset Intervals",
            "ITI (seconds)",
            os.path.join(viz_dir, "ITI_hist.pdf")
        )
    
    # 散布図（回帰分析付き）
    if 'stim_se' in data_dict and 'stim_iti' in data_dict:
        # データの配列長を合わせる
        se = data_dict['stim_se'][:-1] if len(data_dict['stim_se']) > len(data_dict['stim_iti']) else data_dict['stim_se']
        iti = data_dict['stim_iti'][1:] if len(data_dict['stim_iti']) > len(data_dict['stim_se']) else data_dict['stim_iti']
        
        if len(se) == len(iti) and len(se) > 1:
            plot_scatter_with_regression(
                se, iti,
                "Relationship Between SE and ITI (Stimulus)",
                "SE (seconds)",
                "ITI (seconds)",
                os.path.join(viz_dir, "stim_SE_ITI.pdf")
            )
    
    if 'stim_se' in data_dict and 'stim_itiv' in data_dict:
        se = data_dict['stim_se'][:-1] if len(data_dict['stim_se']) > len(data_dict['stim_itiv']) else data_dict['stim_se']
        itiv = data_dict['stim_itiv'] if len(data_dict['stim_itiv']) <= len(se) else data_dict['stim_itiv'][:len(se)]
        
        if len(se) == len(itiv) and len(se) > 1:
            plot_scatter_with_regression(
                se, itiv,
                "Relationship Between SE and ITIv (Stimulus)",
                "SE (seconds)",
                "ITIv (seconds)",
                os.path.join(viz_dir, "stim_SE_ITIv.pdf")
            )
    
    # Import recurrence network visualization functions
    from .network import (
        create_recurrence_network, plot_recurrence_network, 
        plot_recurrence_matrix, plot_degree_distribution,
        analyze_sliding_window, plot_sliding_window_metrics,
        calculate_network_metrics, fit_degree_distribution,
        interpret_network_results
    )
    
    # Create recurrence network visualizations
    time_series_data = {
        'stim_se': data_dict.get('stim_se', []),
        'stim_iti': data_dict.get('stim_iti', []),
        'player_se': data_dict.get('player_se', []),
        'player_iti': data_dict.get('player_iti', [])
    }
    
    # For each time series, create recurrence network analysis visualizations
    for ts_name, ts_data in time_series_data.items():
        if len(ts_data) >= 20:  # Minimum length for meaningful analysis
            print(f"Creating recurrence network visualizations for {ts_name}...")
            
            # Create recurrence network
            adjacency_matrix, epsilon = create_recurrence_network(
                ts_data, 
                recurrence_rate=0.05,
                embedding_dim=2  # Use 2D embedding for better capturing dynamics
            )
            
            # Calculate network metrics
            metrics = calculate_network_metrics(adjacency_matrix)
            
            # Add degree distribution fit information
            fit_results = fit_degree_distribution(adjacency_matrix)
            metrics.update(fit_results)
            
            # Get model-specific interpretation
            interpretation = interpret_network_results(metrics, model_type)
            
            # Determine criticality level
            critical_score = 0
            if fit_results['best_fit'] == 'power_law' and fit_results['power_law_r2'] > 0.7:
                critical_score += 2
            elif fit_results['best_fit'] == 'power_law' and fit_results['power_law_r2'] > 0.5:
                critical_score += 1
            if metrics['clustering_coefficient'] > 0.5 and metrics['avg_path_length'] < 3:
                critical_score += 2
            elif metrics['clustering_coefficient'] > 0.3:
                critical_score += 1
                
            criticality_level = "低" if critical_score < 2 else "中" if critical_score < 4 else "高"
            
            # Define criticality explanation based on model
            if model_type.lower() == 'sea':
                criticality_explanation = "（SEAモデルでは通常低い臨界性が予想されます）"
                if critical_score >= 3:
                    criticality_explanation = "（SEAモデルにしては予想外に高い臨界性です！）"
            elif model_type.lower() == 'bayes':
                criticality_explanation = "（ベイズモデルでは中程度の臨界性が予想されます）"
            elif model_type.lower() == 'bib':
                criticality_explanation = "（BIBモデルでは高い臨界性が予想されます）"
                if critical_score < 3:
                    criticality_explanation = "（BIBモデルにしては予想外に低い臨界性です）"
            else:
                criticality_explanation = ""
            
            # Print comprehensive summary of network metrics
            print(f"\n============ リカレンスネットワーク分析結果 - {ts_name} ============")
            print(f"■ 基本統計:")
            print(f"  ノード数: {metrics['n_nodes']}, エッジ数: {metrics['n_edges']}")
            print(f"  ネットワーク密度: {metrics['density']:.3f}")
            
            print(f"\n■ ネットワーク特性:")
            print(f"  平均次数: {metrics['avg_degree']:.2f}, 最大次数: {metrics['max_degree']}")
            print(f"  クラスタリング係数: {metrics['clustering_coefficient']:.3f}")
            print(f"  平均経路長: {metrics['avg_path_length']:.3f}")
            print(f"  次数相関（アソータティビティ）: {metrics['assortativity']:.3f}")
            
            print(f"\n■ 次数分布分析:")
            if fit_results['best_fit'] == 'power_law':
                print(f"  分布タイプ: べき則 (α={fit_results['power_law_alpha']:.2f}, R²={fit_results['power_law_r2']:.3f})")
                if 2 < fit_results['power_law_alpha'] < 3:
                    print(f"  臨界指標: α値が2～3の範囲内 (α={fit_results['power_law_alpha']:.2f}) → 臨界状態の強い証拠")
                else:
                    print(f"  臨界指標: α値が2～3の範囲外 (α={fit_results['power_law_alpha']:.2f}) → 臨界状態の弱い証拠")
            elif fit_results['best_fit'] == 'exponential':
                print(f"  分布タイプ: 指数分布 (λ={fit_results['exponential_lambda']:.2f}, R²={fit_results['exponential_r2']:.3f})")
                print(f"  臨界指標: 指数分布はランダムまたは規則的な性質を示唆 → 臨界状態の証拠なし")
            else:
                print(f"  分布タイプ: 特定できず")
            
            print(f"\n■ 臨界性評価:")
            print(f"  臨界性レベル: {criticality_level} {criticality_explanation}")
            if metrics['clustering_coefficient'] > 0.5 and metrics['avg_path_length'] < 3:
                print(f"  スモールワールド性: 高 (C={metrics['clustering_coefficient']:.2f}, L={metrics['avg_path_length']:.2f})")
            else:
                print(f"  スモールワールド性: 低～中")
            
            print(f"\n■ {model_type.upper()}モデルの観点からの解釈:")
            print(f"{interpretation}")
            
            # Save interpretation to file
            interpretation_file = os.path.join(viz_dir, f"{ts_name}_interpretation.txt")
            with open(interpretation_file, 'w', encoding='utf-8') as f:
                f.write(f"リカレンスネットワーク分析結果 - {ts_name}\n")
                f.write(f"=======================================\n\n")
                f.write(f"基本統計:\n")
                f.write(f"  ノード数: {metrics['n_nodes']}, エッジ数: {metrics['n_edges']}\n")
                f.write(f"  ネットワーク密度: {metrics['density']:.3f}\n\n")
                f.write(f"ネットワーク特性:\n")
                f.write(f"  平均次数: {metrics['avg_degree']:.2f}, 最大次数: {metrics['max_degree']}\n")
                f.write(f"  クラスタリング係数: {metrics['clustering_coefficient']:.3f}\n")
                f.write(f"  平均経路長: {metrics['avg_path_length']:.3f}\n")
                f.write(f"  次数相関（アソータティビティ）: {metrics['assortativity']:.3f}\n\n")
                f.write(f"次数分布分析:\n")
                if fit_results['best_fit'] == 'power_law':
                    f.write(f"  分布タイプ: べき則 (α={fit_results['power_law_alpha']:.2f}, R²={fit_results['power_law_r2']:.3f})\n")
                elif fit_results['best_fit'] == 'exponential':
                    f.write(f"  分布タイプ: 指数分布 (λ={fit_results['exponential_lambda']:.2f}, R²={fit_results['exponential_r2']:.3f})\n")
                else:
                    f.write(f"  分布タイプ: 特定できず\n")
                f.write(f"\n臨界性評価:\n")
                f.write(f"  臨界性レベル: {criticality_level} {criticality_explanation}\n\n")
                f.write(f"解釈:\n{interpretation}\n")
            
            print(f"  詳細な解釈結果を保存しました: {interpretation_file}\n")
            
            # Plot recurrence network
            plot_recurrence_network(
                adjacency_matrix, 
                title=f"リカレンスネットワーク - {ts_name.replace('_', ' ').title()}",
                output_path=os.path.join(viz_dir, f"{ts_name}_recurrence_network.pdf")
            )
            
            # Plot recurrence matrix
            plot_recurrence_matrix(
                adjacency_matrix,
                title=f"リカレンス行列 - {ts_name.replace('_', ' ').title()}",
                output_path=os.path.join(viz_dir, f"{ts_name}_recurrence_matrix.pdf")
            )
            
            # Plot degree distribution
            plot_degree_distribution(
                adjacency_matrix,
                title=f"次数分布 - {ts_name.replace('_', ' ').title()}",
                output_path=os.path.join(viz_dir, f"{ts_name}_degree_distribution.pdf"),
                fit=True
            )
            
            # Perform sliding window analysis for longer time series
            if len(ts_data) >= 50:
                print(f"時間窓分析の実行中 - {ts_name}...")
                window_results = analyze_sliding_window(
                    ts_data,
                    window_size=30,
                    step=5,
                    recurrence_rate=0.05,
                    embedding_dim=2
                )
                
                # Plot sliding window metrics
                if not window_results.empty:
                    plot_sliding_window_metrics(
                        window_results,
                        title=f"ネットワーク指標の時間変化 - {ts_name.replace('_', ' ').title()}",
                        output_path=os.path.join(viz_dir, f"{ts_name}_sliding_window.pdf"),
                        metrics_to_plot=[
                            'clustering_coefficient', 
                            'avg_path_length',
                            'assortativity',
                            'power_law_r2',
                            'exponential_r2'
                        ]
                    )