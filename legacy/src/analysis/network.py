"""
Recurrence network analysis tools for cooperative tapping task.
Provides functions to build recurrence networks from time series data and analyze their properties.
"""
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import networkx as nx
import os
from scipy import stats
import sys # コマンドライン引数処理のために追加
from sklearn.linear_model import LinearRegression

def create_recurrence_network(time_series, epsilon=None, recurrence_rate=0.05, 
                              delay=1, embedding_dim=1):
    """Create a recurrence network from a time series.
    
    Args:
        time_series: Time series data
        epsilon: Threshold for recurrence (if None, calculated from recurrence_rate)
        recurrence_rate: Target recurrence rate if epsilon is None
        delay: Delay parameter for time delay embedding
        embedding_dim: Embedding dimension for state space reconstruction
        
    Returns:
        adjacency_matrix: Adjacency matrix of the recurrence network
    """
    # Time delay embedding
    if embedding_dim > 1:
        vectors = []
        for i in range(len(time_series) - (embedding_dim-1)*delay):
            vector = [time_series[i + j*delay] for j in range(embedding_dim)]
            vectors.append(vector)
        states = np.array(vectors)
    else:
        states = np.array(time_series).reshape(-1, 1)
    
    # Calculate distances
    N = len(states)
    distances = np.zeros((N, N))
    
    for i in range(N):
        for j in range(i+1, N):
            dist = np.linalg.norm(states[i] - states[j])
            distances[i, j] = distances[j, i] = dist
    
    # If epsilon is not provided, calculate from recurrence rate
    if epsilon is None:
        # Flatten the upper triangular part of the distance matrix
        flat_distances = distances[np.triu_indices(N, k=1)]
        # Sort distances
        sorted_distances = np.sort(flat_distances)
        # Calculate the threshold for the desired recurrence rate
        idx = int(recurrence_rate * len(sorted_distances))
        epsilon = sorted_distances[idx]
    
    # Create adjacency matrix
    adjacency_matrix = np.zeros((N, N))
    adjacency_matrix[distances <= epsilon] = 1
    np.fill_diagonal(adjacency_matrix, 0)  # Remove self-loops
    
    return adjacency_matrix, epsilon

def calculate_network_metrics(adjacency_matrix):
    """Calculate various network metrics from an adjacency matrix.
    
    Args:
        adjacency_matrix: Adjacency matrix of the network
        
    Returns:
        dict: Dictionary of network metrics
    """
    # Create NetworkX graph
    G = nx.from_numpy_array(adjacency_matrix)
    
    # Basic metrics
    n_nodes = G.number_of_nodes()
    n_edges = G.number_of_edges()
    density = nx.density(G)
    
    # Node-level metrics
    if nx.is_connected(G):
        avg_path_length = nx.average_shortest_path_length(G)
    else:
        # For disconnected graphs, compute the average over all connected components
        components = list(nx.connected_components(G))
        if len(components) > 1:
            # Calculate for the largest component
            largest_cc = max(components, key=len)
            largest_subgraph = G.subgraph(largest_cc)
            avg_path_length = nx.average_shortest_path_length(largest_subgraph)
        else:
            avg_path_length = np.nan
    
    # Clustering coefficient
    clustering_coef = nx.average_clustering(G)
    
    # Assortativity
    try:
        assortativity = nx.degree_assortativity_coefficient(G)
    except:
        assortativity = np.nan
    
    # Centrality measures
    degree_centrality = np.mean(list(nx.degree_centrality(G).values()))
    closeness_centrality = np.mean(list(nx.closeness_centrality(G).values()))
    
    # Degree distribution
    degrees = [d for _, d in G.degree()]
    avg_degree = np.mean(degrees)
    std_degree = np.std(degrees)
    max_degree = max(degrees) if degrees else 0
    
    return {
        'n_nodes': n_nodes,
        'n_edges': n_edges,
        'density': density,
        'avg_path_length': avg_path_length,
        'clustering_coefficient': clustering_coef,
        'assortativity': assortativity,
        'avg_degree': avg_degree,
        'std_degree': std_degree,
        'max_degree': max_degree,
        'degree_centrality': degree_centrality,
        'closeness_centrality': closeness_centrality
    }

def fit_degree_distribution(adjacency_matrix):
    """Fit the degree distribution to power-law and exponential distributions.
    
    Args:
        adjacency_matrix: Adjacency matrix of the network
        
    Returns:
        dict: Fit parameters and goodness of fit
    """
    G = nx.from_numpy_array(adjacency_matrix)
    degrees = [d for _, d in G.degree()]
    
    if not degrees or max(degrees) == min(degrees):
        return {
            'power_law_alpha': np.nan,
            'power_law_r2': np.nan,
            'exponential_lambda': np.nan,
            'exponential_r2': np.nan,
            'best_fit': 'none'
        }
    
    # Create degree histogram
    degree_counts = np.bincount(degrees)
    degree_values = np.arange(len(degree_counts))
    
    # Remove zeros
    non_zero_indices = np.where(degree_counts > 0)[0]
    degree_values = degree_values[non_zero_indices]
    degree_counts = degree_counts[non_zero_indices]
    
    if len(degree_values) <= 2:
        return {
            'power_law_alpha': np.nan,
            'power_law_r2': np.nan,
            'exponential_lambda': np.nan,
            'exponential_r2': np.nan,
            'best_fit': 'none'
        }
    
    # Normalize to get probability
    degree_prob = degree_counts / np.sum(degree_counts)
    
    # Log transform for power law fit
    log_degrees = np.log10(degree_values[degree_values > 0])
    log_probs = np.log10(degree_prob[degree_values > 0])
    
    # Power law fit
    if len(log_degrees) > 1:
        power_law_model = LinearRegression()
        power_law_model.fit(log_degrees.reshape(-1, 1), log_probs)
        power_law_alpha = -power_law_model.coef_[0]
        power_law_pred = power_law_model.predict(log_degrees.reshape(-1, 1))
        power_law_r2 = stats.pearsonr(log_probs, power_law_pred)[0] ** 2
    else:
        power_law_alpha = np.nan
        power_law_r2 = np.nan
    
    # Exponential fit
    try:
        exponential_model = LinearRegression()
        exponential_model.fit(degree_values.reshape(-1, 1), np.log(degree_prob))
        exponential_lambda = -exponential_model.coef_[0]
        exponential_pred = exponential_model.predict(degree_values.reshape(-1, 1))
        exponential_r2 = stats.pearsonr(np.log(degree_prob), exponential_pred)[0] ** 2
    except:
        exponential_lambda = np.nan
        exponential_r2 = np.nan
    
    # Determine best fit
    if not np.isnan(power_law_r2) and not np.isnan(exponential_r2):
        best_fit = 'power_law' if power_law_r2 > exponential_r2 else 'exponential'
    elif not np.isnan(power_law_r2):
        best_fit = 'power_law'
    elif not np.isnan(exponential_r2):
        best_fit = 'exponential'
    else:
        best_fit = 'none'
    
    return {
        'power_law_alpha': power_law_alpha,
        'power_law_r2': power_law_r2,
        'exponential_lambda': exponential_lambda,
        'exponential_r2': exponential_r2,
        'best_fit': best_fit
    }

def analyze_sliding_window(time_series, window_size=20, step=5, epsilon=None, 
                           recurrence_rate=0.05, embedding_dim=1):
    """Analyze network metrics in sliding windows.
    
    Args:
        time_series: Time series data
        window_size: Size of sliding window
        step: Step size for sliding window
        epsilon: Threshold for recurrence (if None, calculated from recurrence_rate)
        recurrence_rate: Target recurrence rate if epsilon is None
        embedding_dim: Embedding dimension for state space reconstruction
        
    Returns:
        DataFrame: DataFrame with network metrics for each window
    """
    results = []
    
    for i in range(0, len(time_series) - window_size + 1, step):
        window = time_series[i:i+window_size]
        
        # Create recurrence network for this window
        adj_matrix, window_epsilon = create_recurrence_network(
            window, epsilon, recurrence_rate, embedding_dim=embedding_dim
        )
        
        # Calculate network metrics
        metrics = calculate_network_metrics(adj_matrix)
        
        # Fit degree distribution
        fit_results = fit_degree_distribution(adj_matrix)
        
        # Combine results
        metrics.update(fit_results)
        metrics['window_start'] = i
        metrics['window_end'] = i + window_size
        metrics['window_center'] = i + window_size // 2
        metrics['epsilon'] = window_epsilon
        
        results.append(metrics)
    
    # Create DataFrame
    if results:
        return pd.DataFrame(results)
    else:
        return pd.DataFrame()

def plot_recurrence_network(adjacency_matrix, node_size=30, edge_width=0.5, 
                            node_color='skyblue', edge_color='gray', alpha=0.7,
                            title='Recurrence Network', figsize=(10, 8),
                            output_path=None):
    """Plot the recurrence network.
    
    Args:
        adjacency_matrix: Adjacency matrix of the network
        node_size: Size of nodes in the plot
        edge_width: Width of edges in the plot
        node_color: Color of nodes
        edge_color: Color of edges
        alpha: Transparency of nodes and edges
        title: Plot title
        figsize: Figure size (width, height)
        output_path: Path to save the plot (if None, plot is not saved)
    """
    # 明示的にfigとaxを作成
    fig, ax = plt.subplots(figsize=figsize)
    
    # Create network
    G = nx.from_numpy_array(adjacency_matrix)
    
    # Calculate node positions
    pos = nx.spring_layout(G, seed=42)
    
    # Calculate node colors based on degree
    node_degrees = dict(G.degree())
    degrees = list(node_degrees.values())
    
    # Scale node sizes by degree (optional)
    node_sizes = [max(10, node_size * (1 + d / max(degrees))) if max(degrees) > 0 else node_size 
                  for d in degrees]
    
    # Draw network
    nx.draw_networkx_nodes(G, pos, node_size=node_sizes, node_color=degrees, 
                          cmap=plt.cm.viridis, alpha=alpha, ax=ax)
    nx.draw_networkx_edges(G, pos, width=edge_width, edge_color=edge_color, alpha=alpha*0.5, ax=ax)
    
    # Add colorbar with explicit axes reference
    sm = plt.cm.ScalarMappable(cmap=plt.cm.viridis, norm=plt.Normalize(min(degrees), max(degrees)))
    sm.set_array([])
    cbar = fig.colorbar(sm, ax=ax, shrink=0.8, label='Node Degree')
    
    # Add title and adjust layout
    ax.set_title(title)
    ax.axis('off')
    
    # Create directory if it doesn't exist
    if output_path:
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        plt.savefig(output_path, bbox_inches='tight', dpi=300)
    
    plt.close()

def plot_recurrence_matrix(adjacency_matrix, title='Recurrence Matrix', 
                           figsize=(10, 8), output_path=None):
    """Plot the recurrence matrix as a heatmap.
    
    Args:
        adjacency_matrix: Adjacency matrix of the network
        title: Plot title
        figsize: Figure size (width, height)
        output_path: Path to save the plot (if None, plot is not saved)
    """
    fig, ax = plt.subplots(figsize=figsize)
    
    im = ax.imshow(adjacency_matrix, cmap='binary', interpolation='none', aspect='equal')
    
    ax.set_title(title)
    ax.set_xlabel('Time Index')
    ax.set_ylabel('Time Index')
    cbar = fig.colorbar(im, ax=ax, label='Recurrence')
    
    # Create directory if it doesn't exist
    if output_path:
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        plt.savefig(output_path, bbox_inches='tight', dpi=300)
    
    plt.close()

def plot_degree_distribution(adjacency_matrix, fit=True, title='Degree Distribution',
                            figsize=(10, 6), output_path=None):
    """Plot the degree distribution of the network.
    
    Args:
        adjacency_matrix: Adjacency matrix of the network
        fit: Whether to plot power-law and exponential fits
        title: Plot title
        figsize: Figure size (width, height)
        output_path: Path to save the plot (if None, plot is not saved)
    """
    fig, ax = plt.subplots(figsize=figsize)
    
    # Create network
    G = nx.from_numpy_array(adjacency_matrix)
    degrees = [d for _, d in G.degree()]
    
    if not degrees:
        ax.set_title("No degrees to plot")
        if output_path:
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            plt.savefig(output_path, bbox_inches='tight', dpi=300)
        plt.close()
        return
    
    # Create degree histogram
    degree_counts = np.bincount(degrees)
    degree_values = np.arange(len(degree_counts))
    
    # Remove zeros
    non_zero_indices = np.where(degree_counts > 0)[0]
    degree_values = degree_values[non_zero_indices]
    degree_counts = degree_counts[non_zero_indices]
    
    # Normalize to get probability
    degree_prob = degree_counts / np.sum(degree_counts)
    
    # Plot degree distribution
    ax.loglog(degree_values, degree_prob, 'o-', label='Observed')
    
    # Add fits if requested
    if fit and len(degree_values) > 1:
        fit_results = fit_degree_distribution(adjacency_matrix)
        
        # Create smooth x values for plotting fit lines
        x_smooth = np.logspace(np.log10(min(degree_values)), 
                               np.log10(max(degree_values)), 100)
        
        # Power law fit
        if not np.isnan(fit_results['power_law_alpha']):
            alpha = fit_results['power_law_alpha']
            power_law = x_smooth ** (-alpha)
            # Normalize
            power_law = power_law / np.sum(power_law)
            ax.loglog(x_smooth, power_law, 'r-', 
                      label=f'Power law (α={alpha:.2f}, R²={fit_results["power_law_r2"]:.2f})')
        
        # Exponential fit
        if not np.isnan(fit_results['exponential_lambda']):
            lambda_val = fit_results['exponential_lambda']
            exponential = np.exp(-lambda_val * x_smooth)
            # Normalize
            exponential = exponential / np.sum(exponential)
            ax.loglog(x_smooth, exponential, 'g-', 
                      label=f'Exponential (λ={lambda_val:.2f}, R²={fit_results["exponential_r2"]:.2f})')
        
        # Add best fit indication
        if fit_results['best_fit'] != 'none':
            best_fit = fit_results['best_fit'].replace('_', ' ').title()
            ax.set_title(f"{title} - Best fit: {best_fit}")
        else:
            ax.set_title(title)
    else:
        ax.set_title(title)
    
    ax.set_xlabel('Degree (k)')
    ax.set_ylabel('Probability P(k)')
    ax.grid(True, alpha=0.3)
    ax.legend()
    
    # Create directory if it doesn't exist
    if output_path:
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        plt.savefig(output_path, bbox_inches='tight', dpi=300)
    
    plt.close()

def plot_sliding_window_metrics(window_results, metrics_to_plot=None, 
                               title='Network Metrics Over Time', figsize=(12, 8),
                               output_path=None):
    """Plot network metrics from sliding window analysis.
    
    Args:
        window_results: DataFrame from analyze_sliding_window
        metrics_to_plot: List of metrics to plot (if None, plot common metrics)
        title: Plot title
        figsize: Figure size (width, height)
        output_path: Path to save the plot (if None, plot is not saved)
    """
    if window_results.empty:
        print("No window results to plot")
        return
    
    # Default metrics to plot if not specified
    if metrics_to_plot is None:
        metrics_to_plot = [
            'clustering_coefficient', 
            'avg_path_length',
            'assortativity',
            'power_law_r2',
            'exponential_r2'
        ]
    
    # Filter to include only metrics that exist in the data
    metrics_to_plot = [m for m in metrics_to_plot if m in window_results.columns]
    
    if not metrics_to_plot:
        print("No valid metrics to plot")
        return
    
    # Create figure and axes
    fig, axes = plt.subplots(len(metrics_to_plot), 1, figsize=figsize, sharex=True)
    
    # If only one metric, axes will not be an array, so convert to array for consistency
    if len(metrics_to_plot) == 1:
        axes = [axes]
    
    # Get x values (window centers)
    x = window_results['window_center']
    
    # Create subplot for each metric
    for i, metric in enumerate(metrics_to_plot):
        ax = axes[i]
        ax.plot(x, window_results[metric], 'o-', label=metric)
        ax.set_ylabel(metric.replace('_', ' ').title())
        ax.grid(True, alpha=0.3)
        ax.legend()
        
        # Only add x-label for the last subplot
        if i == len(metrics_to_plot) - 1:
            ax.set_xlabel('Window Center (Time Index)')
    
    fig.suptitle(title)
    plt.tight_layout(rect=[0, 0.03, 1, 0.97])
    
    # Create directory if it doesn't exist
    if output_path:
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        plt.savefig(output_path, bbox_inches='tight', dpi=300)
    
    plt.close()

def interpret_network_results(metrics, model_type):
    """Provide interpretation of network metrics based on model type.
    
    Args:
        metrics: Dictionary of network metrics
        model_type: Type of model ('sea', 'bayes', or 'bib')
        
    Returns:
        str: Interpretation of results
    """
    interpretations = []
    
    # Extract key metrics
    clustering = metrics.get('clustering_coefficient', np.nan)
    path_length = metrics.get('avg_path_length', np.nan)
    assortativity = metrics.get('assortativity', np.nan)
    power_law_r2 = metrics.get('power_law_r2', np.nan)
    exponential_r2 = metrics.get('exponential_r2', np.nan)
    best_fit = metrics.get('best_fit', 'none')
    power_law_alpha = metrics.get('power_law_alpha', np.nan)
    density = metrics.get('density', np.nan)
    avg_degree = metrics.get('avg_degree', np.nan)
    
    # Small-world criteria: high clustering and short path length
    if not np.isnan(clustering) and not np.isnan(path_length):
        small_world_ratio = clustering / (path_length / np.log(metrics.get('n_nodes', 10)))
        has_small_world = clustering > 0.5 and path_length < 3 and small_world_ratio > 1.5
    else:
        has_small_world = False
    
    # Critical behavior criteria: power-law distribution with alpha between 2 and 3
    has_critical_behavior = best_fit == 'power_law' and power_law_r2 > 0.7
    if has_critical_behavior and not np.isnan(power_law_alpha):
        has_critical_behavior = has_critical_behavior and (2.0 < power_law_alpha < 3.0)
    
    # General network structure interpretation
    if has_small_world:
        interpretations.append(f"• ネットワークは顕著なスモールワールド性を示しています（クラスタリング係数={clustering:.2f}、平均経路長={path_length:.2f}）。これは協調タッピングにおける局所的に構造化された（クラスター化された）リズムパターンと、異なるリズムパターン間の効率的な遷移を示唆しています。")
    elif not np.isnan(clustering) and not np.isnan(path_length):
        if clustering > 0.5:
            interpretations.append(f"• 高いクラスタリング係数（{clustering:.2f}）は、時系列に局所的な構造があることを示唆しています。すなわち、リズムパターンが一定期間持続する傾向があります。")
        if path_length > 3:
            interpretations.append(f"• 長い平均経路長（{path_length:.2f}）は、時系列に複雑な長期的構造があることを示唆しています。異なるリズムパターン間の遷移が段階的に行われています。")
    
    # Degree distribution interpretation
    if has_critical_behavior:
        interpretations.append(f"• 次数分布はべき則に従い（α={power_law_alpha:.2f}、R²={power_law_r2:.2f}）、臨界的な状態を示唆しています。これは「やわらかい予期」が実現する非定常状態への適応能力の証拠であり、人間のタイミング制御と類似した特性です。")
    elif best_fit == 'power_law' and 0.5 < power_law_r2 <= 0.7:
        interpretations.append(f"• 次数分布は弱いながらもべき則傾向（α={power_law_alpha:.2f}、R²={power_law_r2:.2f}）を示し、部分的に臨界状態に近い特性があります。")
    elif best_fit == 'exponential' and exponential_r2 > 0.7:
        interpretations.append(f"• 次数分布は指数分布に従い（R²={exponential_r2:.2f}）、より規則的で予測可能なリズムパターンを示唆しています。これは機械的な特性を反映しています。")
    
    # Density & connectivity interpretation
    if not np.isnan(density) and not np.isnan(avg_degree):
        if density < 0.1:
            interpretations.append(f"• ネットワークの低い密度（{density:.3f}）とスパース性は、少数の特徴的なリズムパターンが存在することを示唆しています。")
        elif density > 0.3:
            interpretations.append(f"• ネットワークの高い密度（{density:.3f}）は、リズムパターンの多様性と豊かな遷移関係を示唆しています。")
        
        if avg_degree > 5:
            interpretations.append(f"• 高い平均次数（{avg_degree:.2f}）は、各時点が複数の異なる時点と類似していることを示し、リズムパターンの複雑な繰り返し構造を示唆しています。")
    
    # Assortativity interpretation
    if not np.isnan(assortativity):
        if assortativity > 0.2:
            interpretations.append(f"• 正の次数相関（アソータティビティ={assortativity:.2f}）は、同様のタイミング特性を持つ時点が結合する傾向を示しています。これは、類似したリズムパターンが連続して現れやすいことを意味します。")
        elif assortativity < -0.2:
            interpretations.append(f"• 負の次数相関（アソータティビティ={assortativity:.2f}）は、異なるタイミング特性を持つ時点が結合する傾向を示しています。これは、異なるリズムパターン間での動的な遷移を意味します。")
    
    # Model-specific interpretations
    if model_type.lower() == 'sea':
        # SEA model interpretations
        if best_fit == 'exponential' and exponential_r2 > 0.7:
            interpretations.append("• SEAモデルの予測通り、ネットワーク構造は指数分布に従う傾向があります。これは規則的でランダム性の少ないタッピングパターンを示唆しています。単純な平均化メカニズムは、比較的安定したタイミング制御を生成します。")
        elif clustering < 0.3:
            interpretations.append(f"• SEAモデルで見られる低いクラスタリング係数（{clustering:.2f}）は、単純な平均化による予測の特性を反映しています。これは、ランダムネットワークに近い構造であり、リズムパターンの局所的な構造化が弱いことを示しています。")
        elif has_critical_behavior:
            interpretations.append("• 興味深いことに、SEAモデルでありながらべき則分布と臨界的な特性が見られます。これは、単純な平均化メカニズムでも、特定の条件下では複雑な創発的振る舞いを示す可能性があることを示唆しています。")
            
    elif model_type.lower() == 'bayes':
        # Bayesian model interpretations
        if 0.3 < clustering < 0.6 and 0.5 < power_law_r2 < 0.8:
            interpretations.append(f"• ベイズモデルは中程度のクラスタリング（{clustering:.2f}）と弱いながらもべき則傾向（R²={power_law_r2:.2f}）を示しています。これは、確率的推論に基づく適応的なタイミング制御が、限定的な柔軟性を持つことを示唆しています。")
        elif best_fit == 'exponential' and has_small_world:
            interpretations.append("• ベイズモデルは、指数分布に従いながらもスモールワールド性を示しています。これは、ベイズ推論が確率的に安定した予測を生成しつつも、効率的なリズムパターンの遷移を可能にしていることを示唆しています。")
        
    elif model_type.lower() == 'bib':
        # BIB model interpretations
        if has_critical_behavior and clustering > 0.4:
            interpretations.append(f"• BIBモデルの「やわらかい予期」特性が明確に確認されました。べき則分布（α={power_law_alpha:.2f}、R²={power_law_r2:.2f}）と高いクラスタリング（{clustering:.2f}）は、臨界的な状態の証拠であり、非定常状態への優れた適応能力を示唆しています。これは人間のタイミング制御に最も近い特性です。")
        elif has_small_world:
            interpretations.append(f"• BIBモデルはスモールワールド性（クラスタリング={clustering:.2f}、経路長={path_length:.2f}）を示しており、局所的な構造と効率的な情報伝達の両方を備えています。これは「やわらかい予期」の特徴的な性質であり、柔軟なリズム適応を可能にします。")
        elif best_fit == 'exponential' and exponential_r2 > 0.7:
            interpretations.append("• 予想に反して、BIBモデルは指数分布を示しています。これは、逆ベイズ更新のパラメータ設定や、データ長の不足によるものかもしれません。逆ベイズ更新の効果が十分に発揮されていない可能性があります。")
    
    # If no specific interpretations, add general comment
    if not interpretations:
        interpretations.append("• 十分なデータがないか、明確なパターンが見られません。より長い時系列データでの分析をお勧めします。")
    
    return "\n".join(interpretations)

def run_analysis_from_file(filepath, output_dir_base="data/analysis_results"):
    """
    指定されたCSVファイルからデータを読み込み、リカレンスネットワーク分析を実行し、
    結果の解釈を標準出力に表示し、画像を保存します。

    Args:
        filepath (str): 入力CSVファイルのパス。
                        期待されるカラム: 'player_tap_time', 'stim_tap_time', 'model_type', 'participant_id'
        output_dir_base (str): 分析結果の画像などを保存するベースディレクトリ。
    """
    try:
        df = pd.read_csv(filepath)
        print(f"network.py: ファイル '{filepath}' を読み込みました。データ件数: {len(df)}")
    except FileNotFoundError:
        print(f"network.py: エラー: ファイルが見つかりません: {filepath}", file=sys.stderr)
        return
    except Exception as e:
        print(f"network.py: エラー: ファイル読み込み中にエラーが発生しました: {e}", file=sys.stderr)
        return

    # --- 分析対象の時系列データを選択 ---
    # ここでは 'player_tap_time' を例として使用します。
    # 必要に応じて 'stim_tap_time' や他のカラムを選択・処理するように変更してください。
    if 'player_tap_time' not in df.columns:
        print(f"network.py: エラー: 必須カラム 'player_tap_time' がファイルに存在しません。", file=sys.stderr)
        return
    
    time_series_data = df['player_tap_time'].dropna().values
    if len(time_series_data) < 20: # 分析に十分なデータ長か確認
        print(f"network.py: 警告: 'player_tap_time' のデータ長 ({len(time_series_data)}) が短すぎるため、分析をスキップします。", file=sys.stderr)
        return

    model_type = df['model_type'].iloc[0] if 'model_type' in df.columns else "unknown"
    participant_id = df['participant_id'].iloc[0] if 'participant_id' in df.columns else "unknown"
    
    # 出力ディレクトリの作成 (preprocess_and_analyze.py の一時ファイル名から取得)
    base_filename = os.path.basename(filepath)
    if base_filename.startswith("temp_standardized_"):
        original_filename = base_filename.replace("temp_standardized_", "").removesuffix('.csv')
    else:
        original_filename = base_filename.removesuffix('.csv')

    # visualization.py と同様のディレクトリ構造を試みる
    import datetime
    date_prefix = datetime.datetime.now().strftime('%Y%m%d') # 現在の日付を使用
    
    viz_dir = os.path.join(
        output_dir_base,
        f"{date_prefix}_{participant_id}",
        f"{model_type}_{original_filename}",
        "network_analysis_player_tap_time" # 分析対象の時系列名をサブディレクトリに
    )
    os.makedirs(viz_dir, exist_ok=True)
    print(f"network.py: 分析結果の保存先: {viz_dir}")

    # リカレンスネットワークの構築と分析
    adj_matrix, epsilon = create_recurrence_network(time_series_data, recurrence_rate=0.05, embedding_dim=2)
    metrics = calculate_network_metrics(adj_matrix)
    fit_results = fit_degree_distribution(adj_matrix)
    metrics.update(fit_results)
    interpretation = interpret_network_results(metrics, model_type)

    print("\n--- リカレンスネットワーク分析結果 (player_tap_time) ---")
    for key, value in metrics.items():
        print(f"  {key}: {value}")
    print("\n--- 解釈 ---")
    print(interpretation)

    # 可視化の実行と保存 (必要に応じて呼び出しを追加)
    plot_recurrence_network(adj_matrix, title=f"Recurrence Network (Player Tap Time)\n{original_filename}", output_path=os.path.join(viz_dir, "recurrence_network_player.pdf"))
    plot_recurrence_matrix(adj_matrix, title=f"Recurrence Matrix (Player Tap Time)\n{original_filename}", output_path=os.path.join(viz_dir, "recurrence_matrix_player.pdf"))
    plot_degree_distribution(adj_matrix, title=f"Degree Distribution (Player Tap Time)\n{original_filename}", output_path=os.path.join(viz_dir, "degree_distribution_player.pdf"))
    
    # スライディングウィンドウ分析などもここに追加可能

if __name__ == "__main__":
    if len(sys.argv) > 1:
        input_filepath = sys.argv[1]
        # output_dir_base はオプションで変更可能にするか、固定値とする
        run_analysis_from_file(input_filepath)
    else:
        print("使用法: python network.py <入力ファイルパス>", file=sys.stderr)
