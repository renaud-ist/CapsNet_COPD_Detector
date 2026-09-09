import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
from sklearn.metrics import confusion_matrix

# Define confusion matrix data for each model
models = {
    'CapsNet': {'TP': 176, 'TN': 278, 'FP': 22, 'FN': 24, 'cmap': 'Blues'},
    'Standard CNN': {'TP': 153, 'TN': 255, 'FP': 45, 'FN': 47, 'cmap': 'Greens'},
    'ResNet50': {'TP': 156, 'TN': 262, 'FP': 38, 'FN': 44, 'cmap': 'Reds'},
    'SVM': {'TP': 141, 'TN': 240, 'FP': 60, 'FN': 59, 'cmap': 'Purples'},
    'Random Forest': {'TP': 136, 'TN': 238, 'FP': 62, 'FN': 64, 'cmap': 'Oranges'}
}

# Labels for confusion matrix
labels = ['Negative', 'Positive']

# Plot individual confusion matrices
for model_name, metrics in models.items():
    # Construct confusion matrix from TP, TN, FP, FN
    cm = np.array([[metrics['TN'], metrics['FP']],
                   [metrics['FN'], metrics['TP']]])
    
    # Create a new figure for each model
    plt.figure(figsize=(6, 5))
    
    # Plot heatmap with model-specific colormap
    sns.heatmap(cm, annot=True, fmt='d', cmap=metrics['cmap'],
                xticklabels=labels, yticklabels=labels, cbar=True,
                annot_kws={'size': 12, 'color': 'black'})
    
    # Customize plot
    plt.title(f'Confusion Matrix: {model_name}', fontsize=14, pad=15)
    plt.xlabel('Predicted Label', fontsize=12)
    plt.ylabel('True Label', fontsize=12)
    
    # Adjust layout
    plt.tight_layout()
    
    # Save the plot as a high-resolution PNG
    plt.savefig(f'confusion_matrix_{model_name.lower().replace(" ", "_")}.png', dpi=300, bbox_inches='tight')
    
    # Close the figure to free memory
    plt.close()