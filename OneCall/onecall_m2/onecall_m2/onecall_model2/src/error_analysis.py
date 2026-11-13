import pandas as pd
import os
import joblib
from sklearn.metrics import classification_report, confusion_matrix
import numpy as np

def run_error_analysis(models_dir, results_dir):
    print("Running error analysis...")
    test_data_path = os.path.join(models_dir, "test_data.csv")
    if not os.path.exists(test_data_path):
        print("Test data not found.")
        return
        
    test_data = pd.read_csv(test_data_path)
    X_test = test_data['transcription']
    y_test = test_data['medical_specialty']
    
    # Analyze the best model (e.g., Logistic Regression or SVM, let's assume Linear SVM is strong, but we can look at all or just LR)
    model_name = "Linear_SVM"
    model_path = os.path.join(models_dir, f"{model_name}.pkl")
    
    if not os.path.exists(model_path):
        print(f"{model_name} not found.")
        return
        
    pipeline = joblib.load(model_path)
    y_pred = pipeline.predict(X_test)
    
    classes = pipeline.classes_
    report_dict = classification_report(y_test, y_pred, zero_division=0, output_dict=True)
    
    cm = confusion_matrix(y_test, y_pred)
    
    # 1. Easiest to predict (highest F1, support > 5)
    # 2. Difficult to predict (lowest F1, support > 5)
    class_metrics = []
    for cls in classes:
        if cls in report_dict:
            class_metrics.append({
                'Class': cls,
                'F1': report_dict[cls]['f1-score'],
                'Recall': report_dict[cls]['recall'],
                'Precision': report_dict[cls]['precision'],
                'Support': report_dict[cls]['support']
            })
            
    df_metrics = pd.DataFrame(class_metrics)
    # Filter out classes with very low support in test set to avoid noise
    valid_classes = df_metrics[df_metrics['Support'] > 2]
    
    easiest = valid_classes.sort_values(by='F1', ascending=False).head(5)
    difficult = valid_classes.sort_values(by='F1', ascending=True).head(5)
    
    # 3. Commonly confused
    confusions = []
    for i, true_cls in enumerate(classes):
        for j, pred_cls in enumerate(classes):
            if i != j and cm[i, j] > 0:
                confusions.append({
                    'True Class': true_cls,
                    'Predicted Class': pred_cls,
                    'Count': cm[i, j]
                })
                
    df_confusions = pd.DataFrame(confusions).sort_values(by='Count', ascending=False).head(10)
    
    # 4. Rare specialties performance
    rare_classes = df_metrics[df_metrics['Support'] <= 5]
    
    md_path = os.path.join(results_dir, "error_analysis.md")
    with open(md_path, "w") as f:
        f.write("# Error Analysis Report\n\n")
        f.write(f"Based on `{model_name}` predictions on the test set.\n\n")
        
        f.write("## 1. Easiest Specialties to Predict (Support > 2)\n")
        f.write(easiest.to_markdown(index=False))
        f.write("\n\n")
        
        f.write("## 2. Difficult Specialties to Predict (Support > 2)\n")
        f.write(difficult.to_markdown(index=False))
        f.write("\n\n")
        
        f.write("## 3. Most Commonly Confused Specialties\n")
        f.write(df_confusions.to_markdown(index=False))
        f.write("\n\n")
        
        f.write("## 4. Rare Specialties Performance (Support <= 5 in Test Set)\n")
        f.write(rare_classes.to_markdown(index=False))
        f.write("\n\n")
        
        f.write("## 5. Misclassification Example\n")
        # Find one example
        misclassified = test_data[y_test != y_pred]
        if not misclassified.empty:
            sample = misclassified.iloc[0]
            true_label = sample['medical_specialty']
            pred_label = y_pred[misclassified.index[0]]
            text = sample['transcription'][:500] + "..." if len(sample['transcription']) > 500 else sample['transcription']
            
            f.write(f"**True Label:** {true_label}\n\n")
            f.write(f"**Predicted Label:** {pred_label}\n\n")
            f.write(f"**Text:**\n> {text}\n")
            
    print("Error analysis saved to results/error_analysis.md")

if __name__ == "__main__":
    models_dir = "models"
    results_dir = "results"
    run_error_analysis(models_dir, results_dir)
