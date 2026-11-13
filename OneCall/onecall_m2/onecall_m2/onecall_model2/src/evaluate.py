import os
import sys

_current_dir = os.path.dirname(os.path.abspath(__file__))
_parent_dir = os.path.dirname(_current_dir)
if _parent_dir not in sys.path:
    sys.path.insert(0, _parent_dir)
if _current_dir not in sys.path:
    sys.path.insert(0, _current_dir)

import json
import warnings
import numpy as np
import pandas as pd
import joblib
import matplotlib.pyplot as plt
import seaborn as sns

from sklearn.metrics import (
    accuracy_score,
    precision_score,
    recall_score,
    f1_score,
    classification_report,
    confusion_matrix
)

from src.preprocessing import head_tail_truncate, XGBoostSpecialtyClassifier, CalibratedLinearSVC

# Alias into __main__ so joblib can unpickle XGBoost and CalibratedLinearSVC cleanly
import __main__
__main__.XGBoostSpecialtyClassifier = XGBoostSpecialtyClassifier
__main__.CalibratedLinearSVC = CalibratedLinearSVC

warnings.filterwarnings("ignore")


def load_test_and_val_data(models_dir):
    test_path = os.path.join(models_dir, "test_data.csv")
    val_path = os.path.join(models_dir, "validation_data.csv")
    
    if not os.path.exists(test_path):
        raise FileNotFoundError(
            f"Test data not found at {test_path}. Please execute 'python src/data_audit.py' first to build the clean split."
        )
    test_df = pd.read_csv(test_path)
    val_df = pd.read_csv(val_path) if os.path.exists(val_path) else None
    return test_df, val_df


def evaluate_classical_pipeline(model_path, X_test, y_test, all_classes):
    """
    Evaluates a scikit-learn pipeline (Model A: LR, Model B: SVM, Model C: XGBoost).
    """
    pipeline = joblib.load(model_path)
    y_pred = pipeline.predict(X_test)
    
    probas = None
    if hasattr(pipeline, "predict_proba"):
        try:
            probas = pipeline.predict_proba(X_test)
        except Exception:
            probas = None
            
    return y_pred, probas, pipeline


def evaluate_transformer(transformer_dir, X_test, y_test, all_classes):
    """
    Evaluates fine-tuned Transformer (Model D: Bio_ClinicalBERT) on the test set.
    """
    import torch
    from transformers import AutoTokenizer, AutoModelForSequenceClassification
    
    label_path = os.path.join(transformer_dir, "label_mapping.json")
    if not os.path.exists(label_path):
        raise FileNotFoundError(f"Label mapping not found at {label_path}")
        
    with open(label_path, "r") as f:
        mapping = json.load(f)
    id2label = {int(k): v for k, v in mapping["id2label"].items()}
    label2id = mapping["label2id"]
    max_length = mapping.get("max_length", 512)
    
    tokenizer = AutoTokenizer.from_pretrained(transformer_dir)
    model = AutoModelForSequenceClassification.from_pretrained(transformer_dir)
    model.eval()
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model.to(device)
    
    # Apply head-tail truncation to preserve Chief Complaint and Assessment
    X_test_proc = [head_tail_truncate(t, max_words=380) for t in X_test]
    
    all_preds = []
    all_probas = []
    batch_size = 16
    
    with torch.no_grad():
        for i in range(0, len(X_test_proc), batch_size):
            batch_texts = X_test_proc[i:i + batch_size]
            encoded = tokenizer(
                batch_texts,
                padding=True,
                truncation=True,
                max_length=max_length,
                return_tensors="pt"
            ).to(device)
            outputs = model(**encoded)
            logits = outputs.logits
            probs = torch.softmax(logits, dim=1).cpu().numpy()
            preds = np.argmax(probs, axis=1)
            
            all_preds.extend([id2label[p] for p in preds])
            all_probas.extend(probs)
            
    return np.array(all_preds), np.array(all_probas), model


def run_evaluation(models_dir=None, results_dir=None):
    base_dir = _parent_dir
    if models_dir is None:
        models_dir = os.path.join(base_dir, "models")
    if results_dir is None:
        results_dir = os.path.join(base_dir, "results")

    print("=" * 65)
    print("ONECALL MODEL 2 - COMPREHENSIVE EXPERIMENTAL EVALUATION")
    print("=" * 65)
    
    cm_dir = os.path.join(results_dir, "confusion_matrices")
    os.makedirs(results_dir, exist_ok=True)
    os.makedirs(cm_dir, exist_ok=True)
    
    # 1. Load test data
    test_df, val_df = load_test_and_val_data(models_dir)
    X_test = test_df['transcription']
    y_test = test_df['medical_specialty']
    print(f"Loaded clean test set with {len(X_test)} samples across {y_test.nunique()} unique specialties.")
    
    # All classes from test set + any known classes
    all_classes = sorted(list(y_test.unique()))
    
    model_configs = [
        {
            "name": "Model A: Logistic Regression",
            "key": "Logistic_Regression",
            "type": "sklearn",
            "path": os.path.join(models_dir, "Logistic_Regression.pkl"),
            "representation": "TF-IDF (ngram 1-2, sublinear, 10k features)"
        },
        {
            "name": "Model B: Linear SVM",
            "key": "Linear_SVM",
            "type": "sklearn",
            "path": os.path.join(models_dir, "Linear_SVM.pkl"),
            "representation": "TF-IDF (Calibrated Platt Scaling)"
        },
        {
            "name": "Model C: XGBoost",
            "key": "XGBoost",
            "type": "sklearn",
            "path": os.path.join(models_dir, "XGBoost.pkl"),
            "representation": "TF-IDF + TruncatedSVD (128 dims)"
        },
        {
            "name": "Model D: Bio_ClinicalBERT",
            "key": "Transformer",
            "type": "transformer",
            "path": os.path.join(models_dir, "transformer"),
            "representation": "Contextual Embeddings (Bio_ClinicalBERT)"
        }
    ]
    
    comparison_records = []
    evaluated_models = {}
    
    for cfg in model_configs:
        name = cfg["name"]
        key = cfg["key"]
        path = cfg["path"]
        rep = cfg["representation"]
        
        # Check if model exists (directory for transformer, file for sklearn)
        if cfg["type"] == "transformer":
            label_file = os.path.join(path, "label_mapping.json")
            if not os.path.exists(label_file):
                print(f"[INFO] Skipping {name}: artifact not found at {path} (has not been trained yet).")
                continue
        else:
            if not os.path.exists(path):
                print(f"[INFO] Skipping {name}: artifact not found at {path} (has not been trained yet).")
                continue
                
        print(f"\nEvaluating {name} on shared clean test set...")
        try:
            if cfg["type"] == "sklearn":
                y_pred, probas, model_obj = evaluate_classical_pipeline(path, X_test, y_test, all_classes)
            else:
                y_pred, probas, model_obj = evaluate_transformer(path, X_test, y_test, all_classes)
        except Exception as e:
            print(f"[ERROR] Failed to evaluate {name}: {e}")
            continue
            
        acc = accuracy_score(y_test, y_pred)
        macro_p = precision_score(y_test, y_pred, average="macro", zero_division=0)
        macro_r = recall_score(y_test, y_pred, average="macro", zero_division=0)
        macro_f1 = f1_score(y_test, y_pred, average="macro", zero_division=0)
        weighted_p = precision_score(y_test, y_pred, average="weighted", zero_division=0)
        weighted_r = recall_score(y_test, y_pred, average="weighted", zero_division=0)
        weighted_f1 = f1_score(y_test, y_pred, average="weighted", zero_division=0)
        
        # Save confusion matrix
        cm = confusion_matrix(y_test, y_pred, labels=all_classes)
        plt.figure(figsize=(14, 11))
        sns.heatmap(cm, annot=False, cmap="Blues", xticklabels=all_classes, yticklabels=all_classes)
        plt.title(f"Confusion Matrix: {name} (Macro F1: {macro_f1:.4f})")
        plt.xlabel("Predicted Specialty")
        plt.ylabel("True Specialty")
        plt.xticks(rotation=90, fontsize=8)
        plt.yticks(rotation=0, fontsize=8)
        plt.tight_layout()
        cm_path = os.path.join(cm_dir, f"{key}_cm.png")
        plt.savefig(cm_path, dpi=300)
        plt.close()
        print(f"  Saved confusion matrix: {cm_path}")
        
        # Save per-class classification report
        rep_dict = classification_report(y_test, y_pred, labels=all_classes, output_dict=True, zero_division=0)
        rep_df = pd.DataFrame(rep_dict).transpose().reset_index()
        rep_df.rename(columns={"index": "class_or_metric"}, inplace=True)
        rep_path = os.path.join(results_dir, f"{key}_classification_report.csv")
        rep_df.to_csv(rep_path, index=False)
        print(f"  Saved per-class classification report: {rep_path}")
        
        comparison_records.append({
            "Model": name,
            "Representation": rep,
            "Accuracy": round(acc, 4),
            "Macro Precision": round(macro_p, 4),
            "Macro Recall": round(macro_r, 4),
            "Macro F1": round(macro_f1, 4),
            "Weighted Precision": round(weighted_p, 4),
            "Weighted Recall": round(weighted_r, 4),
            "Weighted F1": round(weighted_f1, 4)
        })
        evaluated_models[name] = {"model": model_obj, "type": cfg["type"], "macro_f1": macro_f1}
        
    if not comparison_records:
        print("\n[NOTE] No trained models were found to evaluate. Train models first via 'python src/train.py --model A'.")
        return
        
    comp_df = pd.DataFrame(comparison_records)
    comp_df.sort_values(by="Macro F1", ascending=False, inplace=True)
    
    print("\n" + "=" * 65)
    print("FINAL MODEL COMPARISON (FROM ACTUAL EXPERIMENTAL EXECUTION)")
    print("=" * 65)
    print(comp_df.to_string(index=False))
    
    comp_csv = os.path.join(results_dir, "model_comparison.csv")
    comp_df.to_csv(comp_csv, index=False)
    
    comp_md = os.path.join(results_dir, "model_comparison.md")
    with open(comp_md, "w") as f:
        f.write("# Model 2: Scientific Evaluation and Comparison\n\n")
        f.write("Primary selection metric: **Macro F1** (reflects balanced recognition across common and rare specialties).\n\n")
        f.write(comp_df.to_markdown(index=False))
        f.write("\n")
        
    print(f"\nSaved comparison tables to:")
    print(f"  - {comp_csv}")
    print(f"  - {comp_md}")
    
    # -------------------------------------------------------------
    # MODEL SELECTION DECISION
    # -------------------------------------------------------------
    best_row = comp_df.iloc[0]
    best_name = best_row["Model"]
    best_f1 = best_row["Macro F1"]
    
    print("\n" + "=" * 65)
    print(f"MODEL SELECTION DECISION: {best_name}")
    print("=" * 65)
    print(f"Primary Selection Metric: Macro F1 = {best_f1:.4f}")
    print(f"Accuracy:                {best_row['Accuracy']:.4f}")
    print(f"Macro Recall:            {best_row['Macro Recall']:.4f}")
    print(f"Weighted F1:             {best_row['Weighted F1']:.4f}")
    
    # Deploy winning model
    deployed_path = os.path.join(models_dir, "onecall_specialty_model.pkl")
    best_info = evaluated_models[best_name]
    
    metadata = {
        "model_name": best_name,
        "representation": best_row["Representation"],
        "primary_metric": "Macro F1",
        "macro_f1": float(best_f1),
        "accuracy": float(best_row["Accuracy"]),
        "macro_precision": float(best_row["Macro Precision"]),
        "macro_recall": float(best_row["Macro Recall"]),
        "weighted_f1": float(best_row["Weighted F1"]),
        "num_classes": len(all_classes),
        "model_type": best_info["type"]
    }
    
    if best_info["type"] == "sklearn":
        joblib.dump(best_info["model"], deployed_path)
        print(f"Deployed winning model pipeline to: {deployed_path}")
        
    with open(os.path.join(models_dir, "model_metadata.json"), "w") as f:
        json.dump(metadata, f, indent=2)
        
    with open(os.path.join(results_dir, "model_selection.md"), "w") as f:
        f.write("# Model Selection and Scientific Evaluation\n\n")
        f.write(f"## Selected Model: {best_name}\n\n")
        f.write("### Selection Justification\n")
        f.write(
            f"1. **Macro F1 Primary Metric:** Evaluated on the clean, duplicate-free shared test set. "
            f"{best_name} achieved the highest Macro F1 score of **{best_f1:.4f}**.\n"
            f"2. **Representation:** Utilized {best_row['Representation']}.\n"
            f"3. **Overall Metrics:** Accuracy = {best_row['Accuracy']:.4f}, Macro Recall = {best_row['Macro Recall']:.4f}, Weighted F1 = {best_row['Weighted F1']:.4f}.\n"
        )
        
    print(f"Generated model selection documentation: {os.path.join(results_dir, 'model_selection.md')}")
    print("\nEvaluation step completed successfully.")


if __name__ == "__main__":
    run_evaluation()
