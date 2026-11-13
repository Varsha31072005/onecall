import os
import sys

_current_dir = os.path.dirname(os.path.abspath(__file__))
_parent_dir = os.path.dirname(_current_dir)
if _parent_dir not in sys.path:
    sys.path.insert(0, _parent_dir)
if _current_dir not in sys.path:
    sys.path.insert(0, _current_dir)

import argparse
import json
import warnings
import numpy as np
import pandas as pd
import joblib
import matplotlib.pyplot as plt
import seaborn as sns

from sklearn.linear_model import LogisticRegression
from sklearn.svm import LinearSVC
from sklearn.calibration import CalibratedClassifierCV
from sklearn.metrics import (
    accuracy_score,
    precision_score,
    recall_score,
    f1_score,
    classification_report,
    confusion_matrix
)

from src.preprocessing import (
    clean_text,
    audit_and_clean_dataset,
    create_leakage_free_splits,
    get_tfidf_pipeline,
    get_tfidf_svd_pipeline,
    check_transcription_lengths,
    head_tail_truncate,
    ClinicalDocumentChunker,
    XGBoostSpecialtyClassifier,
    CalibratedLinearSVC
)

warnings.filterwarnings("ignore")


# -------------------------------------------------------------
# PATH RESOLUTION & DATA QUALITY VERIFICATION (PART 8, 9, 19)
# -------------------------------------------------------------
def resolve_data_paths():
    base_dir = _parent_dir
    models_dir = os.path.join(base_dir, "models")
    results_dir = os.path.join(base_dir, "results")
    data_dir = os.path.join(base_dir, "data")
    
    os.makedirs(models_dir, exist_ok=True)
    os.makedirs(results_dir, exist_ok=True)
    os.makedirs(os.path.join(results_dir, "confusion_matrices"), exist_ok=True)
    return base_dir, models_dir, results_dir, data_dir


def load_verified_splits(models_dir, data_dir):
    """
    Loads train_data.csv, validation_data.csv, and test_data.csv.
    If splits do not exist, builds them from original mtsamples.csv via audit_and_clean_dataset.
    Executes strict Part 19 data quality verification before proceeding.
    """
    train_path = os.path.join(models_dir, "train_data.csv")
    val_path = os.path.join(models_dir, "validation_data.csv")
    test_path = os.path.join(models_dir, "test_data.csv")
    
    if not (os.path.exists(train_path) and os.path.exists(val_path) and os.path.exists(test_path)):
        print("[INFO] Splits not found. Rebuilding clean master dataset from mtsamples.csv...")
        raw_path = os.path.join(data_dir, "mtsamples.csv")
        if not os.path.exists(raw_path):
            raw_path = os.path.join(os.path.dirname(_parent_dir), "dataset", "mtsamples.csv")
        raw_df = pd.read_csv(raw_path)
        clean_df, _, _, _, _ = audit_and_clean_dataset(raw_df, min_char_len=20)
        train_df, val_df, test_df = create_leakage_free_splits(clean_df, random_state=42)
        train_df.to_csv(train_path, index=False)
        val_df.to_csv(val_path, index=False)
        test_df.to_csv(test_path, index=False)
    else:
        train_df = pd.read_csv(train_path)
        val_df = pd.read_csv(val_path)
        test_df = pd.read_csv(test_path)
        
    # PART 19 — STRICT DATA QUALITY VERIFICATION
    train_texts = set(train_df['transcription'].dropna())
    val_texts = set(val_df['transcription'].dropna())
    test_texts = set(test_df['transcription'].dropna())
    
    dup_train_test = len(train_texts.intersection(test_texts))
    dup_train_val = len(train_texts.intersection(val_texts))
    dup_val_test = len(val_texts.intersection(test_texts))
    
    total_clean = len(train_df) + len(val_df) + len(test_df)
    unique_specs = sorted(list(set(train_df['medical_specialty']).union(set(val_df['medical_specialty'])).union(set(test_df['medical_specialty']))))
    
    print("\n" + "=" * 65)
    print("DATA QUALITY VERIFICATION REPORT (PRE-TRAINING)")
    print("=" * 65)
    print(f"Total clean samples:              {total_clean}")
    print(f"Number of specialties:            {len(unique_specs)}")
    print(f"Train samples:                    {len(train_df)}")
    print(f"Validation samples:               {len(val_df)}")
    print(f"Test samples:                     {len(test_df)}")
    print("-" * 65)
    print(f"Duplicate train/test texts:       {dup_train_test}")
    print(f"Duplicate train/validation texts: {dup_train_val}")
    print(f"Duplicate validation/test texts:  {dup_val_test}")
    print("=" * 65)
    
    if dup_train_test != 0 or dup_train_val != 0 or dup_val_test != 0:
        raise ValueError(
            f"CRITICAL ERROR: Data leakage detected across splits!\n"
            f"train/test duplicates: {dup_train_test}, train/val: {dup_train_val}, val/test: {dup_val_test}.\n"
            f"Stopping training immediately."
        )
        
    return train_df, val_df, test_df, unique_specs


# -------------------------------------------------------------
# EVALUATION & METRIC LOGGING UTILITIES (PART 17 & 18)
# -------------------------------------------------------------
def evaluate_and_record_metrics(name, rep_name, y_true, y_pred, all_classes, results_dir):
    """
    Computes and saves all Part 17 metrics:
    - Accuracy, Macro/Weighted Precision, Recall, F1
    - Confusion Matrix (PNG)
    - Per-class classification report (CSV)
    - Appends/updates results/model_comparison.csv
    """
    acc = accuracy_score(y_true, y_pred)
    macro_p = precision_score(y_true, y_pred, average='macro', zero_division=0)
    macro_r = recall_score(y_true, y_pred, average='macro', zero_division=0)
    macro_f1 = f1_score(y_true, y_pred, average='macro', zero_division=0)
    weighted_p = precision_score(y_true, y_pred, average='weighted', zero_division=0)
    weighted_r = recall_score(y_true, y_pred, average='weighted', zero_division=0)
    weighted_f1 = f1_score(y_true, y_pred, average='weighted', zero_division=0)
    
    print(f"\n--- {name} Results on Shared Test Set ---")
    print(f"Accuracy:           {acc:.4f}")
    print(f"Macro Precision:    {macro_p:.4f}")
    print(f"Macro Recall:       {macro_r:.4f}")
    print(f"Macro F1 (Primary): {macro_f1:.4f}")
    print(f"Weighted F1:        {weighted_f1:.4f}")
    
    # 1. Per-class report
    report_dict = classification_report(y_true, y_pred, labels=all_classes, output_dict=True, zero_division=0)
    report_df = pd.DataFrame(report_dict).transpose().reset_index()
    report_df.rename(columns={'index': 'class_or_metric'}, inplace=True)
    clean_name = name.replace(":", "").replace(" ", "_")
    report_path = os.path.join(results_dir, f"{clean_name}_classification_report.csv")
    report_df.to_csv(report_path, index=False)
    
    # 2. Confusion matrix
    cm = confusion_matrix(y_true, y_pred, labels=all_classes)
    plt.figure(figsize=(14, 11))
    sns.heatmap(cm, annot=False, cmap='Blues', xticklabels=all_classes, yticklabels=all_classes)
    plt.title(f"Confusion Matrix: {name} (Macro F1: {macro_f1:.4f})")
    plt.xlabel("Predicted Specialty")
    plt.ylabel("True Specialty")
    plt.xticks(rotation=90, fontsize=8)
    plt.yticks(rotation=0, fontsize=8)
    plt.tight_layout()
    cm_path = os.path.join(results_dir, "confusion_matrices", f"{clean_name}_cm.png")
    plt.savefig(cm_path, dpi=300)
    plt.close()
    
    # 3. Model comparison table
    record = {
        "Model": name,
        "Representation": rep_name,
        "Accuracy": round(acc, 4),
        "Macro Precision": round(macro_p, 4),
        "Macro Recall": round(macro_r, 4),
        "Macro F1": round(macro_f1, 4),
        "Weighted Precision": round(weighted_p, 4),
        "Weighted Recall": round(weighted_r, 4),
        "Weighted F1": round(weighted_f1, 4)
    }
    
    comp_csv = os.path.join(results_dir, "model_comparison.csv")
    if os.path.exists(comp_csv):
        comp_df = pd.read_csv(comp_csv)
        comp_df = comp_df[comp_df['Model'] != name]
        comp_df = pd.concat([comp_df, pd.DataFrame([record])], ignore_index=True)
    else:
        comp_df = pd.DataFrame([record])
    comp_df.to_csv(comp_csv, index=False)
    
    # Markdown comparison table
    comp_md = os.path.join(results_dir, "model_comparison.md")
    with open(comp_md, "w") as f:
        f.write("# Model Comparison Table (Macro F1 Primary)\n\n")
        f.write(comp_df.to_markdown(index=False))
        f.write("\n")
        
    return record


# -------------------------------------------------------------
# PART 10 — MODEL A: LOGISTIC REGRESSION + TF-IDF (BASELINE)
# -------------------------------------------------------------
def train_model_a_logistic_regression(train_df, val_df, test_df, all_classes, models_dir, results_dir):
    print("\n" + "=" * 65)
    print("TRAINING MODEL A: Logistic Regression + TF-IDF (Baseline)")
    print("=" * 65)
    
    X_train, y_train = train_df['transcription'], train_df['medical_specialty']
    X_val, y_val = val_df['transcription'], val_df['medical_specialty']
    X_test, y_test = test_df['transcription'], test_df['medical_specialty']
    
    c_values = [0.1, 0.5, 1.0, 2.0, 5.0]
    best_pipe = None
    best_val_f1 = -1.0
    best_c = 1.0
    
    for C in c_values:
        clf = LogisticRegression(
            C=C,
            class_weight='balanced',
            max_iter=2000,
            random_state=42
        )
        pipe = get_tfidf_pipeline(clf, ngram_range=(1, 2), max_features=10000, sublinear_tf=True)
        pipe.fit(X_train, y_train)
        
        val_preds = pipe.predict(X_val)
        val_f1 = f1_score(y_val, val_preds, average='macro', zero_division=0)
        print(f"  LR Tuning: C={C}, class_weight='balanced' -> Validation Macro F1 = {val_f1:.4f}")
        
        if val_f1 > best_val_f1:
            best_val_f1 = val_f1
            best_pipe = pipe
            best_c = C
            
    print(f"Best LR Configuration: C={best_c} (Validation Macro F1 = {best_val_f1:.4f})")
    
    # Evaluate winning model on unseen test set
    y_test_pred = best_pipe.predict(X_test)
    rep_name = "TF-IDF (ngram 1-2, sublinear, 10k features)"
    record = evaluate_and_record_metrics(
        "Model A: Logistic Regression", rep_name, y_test, y_test_pred, all_classes, results_dir
    )
    
    save_path = os.path.join(models_dir, "Logistic_Regression.pkl")
    joblib.dump(best_pipe, save_path)
    print(f"Saved Model A pipeline to: {save_path}")
    return best_pipe, record


# -------------------------------------------------------------
# PART 11 — MODEL B: LINEAR SVM + TF-IDF
# -------------------------------------------------------------
def train_model_b_linear_svm(train_df, val_df, test_df, all_classes, models_dir, results_dir):
    print("\n" + "=" * 65)
    print("TRAINING MODEL B: Linear SVM + TF-IDF")
    print("=" * 65)
    
    X_train, y_train = train_df['transcription'], train_df['medical_specialty']
    X_val, y_val = val_df['transcription'], val_df['medical_specialty']
    X_test, y_test = test_df['transcription'], test_df['medical_specialty']
    
    c_values = [0.1, 0.5, 1.0, 2.0, 5.0]
    class_weights = ['balanced', None]
    
    best_pipe = None
    best_val_f1 = -1.0
    best_params = {}
    
    for cw in class_weights:
        for C in c_values:
            svm_clf = CalibratedLinearSVC(
                C=C,
                class_weight=cw,
                random_state=42,
                max_iter=2000
            )
            pipe = get_tfidf_pipeline(svm_clf, ngram_range=(1, 2), max_features=10000, sublinear_tf=True)
            pipe.fit(X_train, y_train)
            
            val_preds = pipe.predict(X_val)
            val_f1 = f1_score(y_val, val_preds, average='macro', zero_division=0)
            print(f"  Linear SVM Tuning: C={C}, class_weight={cw} -> Validation Macro F1 = {val_f1:.4f}")
            
            if val_f1 > best_val_f1:
                best_val_f1 = val_f1
                best_pipe = pipe
                best_params = {"C": C, "class_weight": cw}
                
    print(f"Best SVM Configuration: {best_params} (Validation Macro F1 = {best_val_f1:.4f})")
    
    # Evaluate winning model on unseen test set
    y_test_pred = best_pipe.predict(X_test)
    rep_name = "TF-IDF (Calibrated Platt Scaling)"
    record = evaluate_and_record_metrics(
        "Model B: Linear SVM", rep_name, y_test, y_test_pred, all_classes, results_dir
    )
    
    save_path = os.path.join(models_dir, "Linear_SVM.pkl")
    joblib.dump(best_pipe, save_path)
    print(f"Saved Model B pipeline to: {save_path}")
    return best_pipe, record


# -------------------------------------------------------------
# PART 12 — MODEL C: XGBOOST + TF-IDF + TRUNCATED SVD
# -------------------------------------------------------------
def train_model_c_xgboost(train_df, val_df, test_df, all_classes, models_dir, results_dir, svd_components=128):
    print("\n" + "=" * 65)
    print(f"TRAINING MODEL C: XGBoost + TF-IDF + TruncatedSVD ({svd_components} dims)")
    print("=" * 65)
    
    X_train, y_train = train_df['transcription'], train_df['medical_specialty']
    X_test, y_test = test_df['transcription'], test_df['medical_specialty']
    
    # Ensure SVD components do not exceed number of training samples
    actual_svd_components = min(svd_components, len(X_train) - 1)
    
    xgb_clf = XGBoostSpecialtyClassifier(
        n_estimators=100,
        max_depth=5,
        learning_rate=0.1,
        subsample=0.8,
        random_state=42
    )
    
    pipe = get_tfidf_svd_pipeline(
        xgb_clf,
        n_components=actual_svd_components,
        max_features=10000,
        ngram_range=(1, 2),
        random_state=42
    )
    
    pipe.fit(X_train, y_train)
    
    y_test_pred = pipe.predict(X_test)
    rep_name = f"TF-IDF + TruncatedSVD ({actual_svd_components} dims)"
    record = evaluate_and_record_metrics(
        "Model C: XGBoost", rep_name, y_test, y_test_pred, all_classes, results_dir
    )
    
    save_path = os.path.join(models_dir, "XGBoost.pkl")
    joblib.dump(pipe, save_path)
    print(f"Saved Model C pipeline to: {save_path}")
    return pipe, record


# -------------------------------------------------------------
# PART 13-16 — MODEL D: TRANSFORMER (BIO_CLINICALBERT)
# -------------------------------------------------------------
def train_model_d_transformer(
    train_df,
    val_df,
    test_df,
    all_classes,
    models_dir,
    results_dir,
    epochs=3,
    lr=2e-5,
    batch_size=16,
    max_length=512,
    loss_type="weighted"
):
    """
    Trains Model D: Bio_ClinicalBERT.
    - Long-document profiling (256, 384, 512).
    - Preserves head-tail clinical sections.
    - Support for Standard CrossEntropy vs Class-Weighted CrossEntropy (strictly from train).
    - Hyperparameter exploration support: lr, epochs, early stopping on validation Macro F1.
    """
    print("\n" + "=" * 65)
    print("TRAINING MODEL D: Transformer (Bio_ClinicalBERT)")
    print("=" * 65)
    
    try:
        import torch
        import torch.nn as nn
        from transformers import (
            AutoTokenizer,
            AutoModelForSequenceClassification,
            Trainer,
            TrainingArguments,
            EarlyStoppingCallback
        )
        from datasets import Dataset
        from sklearn.utils.class_weight import compute_class_weight
    except ImportError:
        print("[ERROR] Required transformer packages missing. Install: pip install torch transformers datasets accelerate")
        return None, None
        
    X_train, y_train = train_df['transcription'].tolist(), train_df['medical_specialty'].tolist()
    X_val, y_val = val_df['transcription'].tolist(), val_df['medical_specialty'].tolist()
    X_test, y_test = test_df['transcription'].tolist(), test_df['medical_specialty'].tolist()
    
    # 1. Document length profiling
    print("\n[LONG-DOCUMENT PROFILING]")
    len_stats = check_transcription_lengths(X_train)
    print(f"  Mean words: {len_stats.get('mean_words', 0):.1f}, Median words: {len_stats.get('median_words', 0):.1f}")
    print(f"  Docs exceeding 256 tokens: {len_stats.get('pct_exceeding_256', 0)}%")
    print(f"  Docs exceeding 384 tokens: {len_stats.get('pct_exceeding_384', 0)}%")
    print(f"  Docs exceeding 512 tokens: {len_stats.get('pct_exceeding_512', 0)}%")
    
    # 2. Preprocess with head-tail truncation (380 words ~ 490 tokens, preserves Chief Complaint & Plan)
    X_train_proc = [head_tail_truncate(t, max_words=380) for t in X_train]
    X_val_proc = [head_tail_truncate(t, max_words=380) for t in X_val]
    X_test_proc = [head_tail_truncate(t, max_words=380) for t in X_test]
    
    class_to_id = {c: i for i, c in enumerate(all_classes)}
    id_to_class = {i: c for i, c in enumerate(all_classes)}
    
    y_train_ids = [class_to_id[c] for c in y_train]
    y_val_ids = [class_to_id[c] for c in y_val]
    y_test_ids = [class_to_id[c] for c in y_test]
    
    model_name = "emilyalsentzer/Bio_ClinicalBERT"
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Loading pretrained tokenizer & model: {model_name} on {device}...")
    
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    model = AutoModelForSequenceClassification.from_pretrained(
        model_name,
        num_labels=len(all_classes),
        id2label=id_to_class,
        label2id=class_to_id
    ).to(device)
    
    train_dataset = Dataset.from_dict({"text": X_train_proc, "label": y_train_ids})
    val_dataset = Dataset.from_dict({"text": X_val_proc, "label": y_val_ids})
    test_dataset = Dataset.from_dict({"text": X_test_proc, "label": y_test_ids})
    
    def tokenize_fn(batch):
        return tokenizer(batch["text"], padding="max_length", truncation=True, max_length=max_length)
        
    train_tok = train_dataset.map(tokenize_fn, batched=True)
    val_tok = val_dataset.map(tokenize_fn, batched=True)
    test_tok = test_dataset.map(tokenize_fn, batched=True)
    
    # Class weights strictly from training set (Part 15)
    train_classes_present = np.unique(y_train_ids)
    full_weights = np.ones(len(all_classes), dtype=np.float32)
    computed_weights = compute_class_weight('balanced', classes=train_classes_present, y=y_train_ids)
    for c_id, w in zip(train_classes_present, computed_weights):
        full_weights[c_id] = w
    class_weights_tensor = torch.tensor(full_weights, dtype=torch.float).to(device)
    
    class ConfigurableLossTrainer(Trainer):
        def compute_loss(self, model, inputs, return_outputs=False, num_items_in_batch=None):
            labels = inputs.pop("labels")
            outputs = model(**inputs)
            logits = outputs.get("logits")
            if loss_type == "weighted":
                loss_fct = nn.CrossEntropyLoss(weight=class_weights_tensor)
            else:
                loss_fct = nn.CrossEntropyLoss()
            loss = loss_fct(logits.view(-1, self.model.config.num_labels), labels.view(-1))
            return (loss, outputs) if return_outputs else loss
            
    def compute_metrics(eval_pred):
        logits, labels = eval_pred
        preds = np.argmax(logits, axis=1)
        return {
            "accuracy": accuracy_score(labels, preds),
            "macro_f1": f1_score(labels, preds, average="macro", zero_division=0)
        }
        
    training_args = TrainingArguments(
        output_dir=os.path.join(models_dir, "transformer_checkpoints"),
        learning_rate=lr,
        per_device_train_batch_size=batch_size,
        per_device_eval_batch_size=batch_size,
        num_train_epochs=epochs,
        weight_decay=0.01,
        eval_strategy="epoch",
        save_strategy="epoch",
        load_best_model_at_end=True,
        metric_for_best_model="macro_f1",
        greater_is_better=True,
        logging_steps=10,
        fp16=torch.cuda.is_available()
    )
    
    trainer = ConfigurableLossTrainer(
        model=model,
        args=training_args,
        train_dataset=train_tok,
        eval_dataset=val_tok,
        compute_metrics=compute_metrics,
        callbacks=[EarlyStoppingCallback(early_stopping_patience=2)]
    )
    
    print(f"Executing Transformer training ({epochs} epochs, lr={lr}, loss={loss_type})...")
    trainer.train()
    
    # Save model and artifacts
    transformer_dir = os.path.join(models_dir, "transformer")
    os.makedirs(transformer_dir, exist_ok=True)
    trainer.save_model(transformer_dir)
    tokenizer.save_pretrained(transformer_dir)
    
    with open(os.path.join(transformer_dir, "label_mapping.json"), "w") as f:
        json.dump({"id2label": id_to_class, "label2id": class_to_id, "max_length": max_length}, f, indent=2)
        
    # Evaluate on test set
    preds_output = trainer.predict(test_tok)
    y_test_pred_ids = np.argmax(preds_output.predictions, axis=1)
    y_test_pred = [id_to_class[p] for p in y_test_pred_ids]
    
    rep_name = f"Contextual Embeddings (Bio_ClinicalBERT, {loss_type} loss)"
    record = evaluate_and_record_metrics(
        "Model D: Bio_ClinicalBERT", rep_name, y_test, y_test_pred, all_classes, results_dir
    )
    return model, record


# -------------------------------------------------------------
# MAIN CLI PIPELINE (MANUAL EXECUTION SUPPORT)
# -------------------------------------------------------------
def run_pipeline(selected_model='all', epochs=3, lr=2e-5, loss_type="weighted"):
    base_dir, models_dir, results_dir, data_dir = resolve_data_paths()
    
    train_df, val_df, test_df, all_classes = load_verified_splits(models_dir, data_dir)
    
    target = selected_model.upper()
    
    if target in ['ALL', 'A']:
        train_model_a_logistic_regression(train_df, val_df, test_df, all_classes, models_dir, results_dir)
        
    if target in ['ALL', 'B']:
        train_model_b_linear_svm(train_df, val_df, test_df, all_classes, models_dir, results_dir)
        
    if target in ['ALL', 'C']:
        train_model_c_xgboost(train_df, val_df, test_df, all_classes, models_dir, results_dir)
        
    if target in ['ALL', 'D']:
        train_model_d_transformer(
            train_df, val_df, test_df, all_classes, models_dir, results_dir,
            epochs=epochs, lr=lr, loss_type=loss_type
        )
        
    print("\n" + "=" * 65)
    print("PIPELINE EXECUTION COMPLETE")
    print(f"Results recorded to: {os.path.join(results_dir, 'model_comparison.csv')}")
    print("=" * 65)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OneCall Model 2 Modular Training Pipeline")
    parser.add_argument(
        "--model",
        type=str,
        default="A",
        choices=["all", "A", "B", "C", "D", "a", "b", "c", "d"],
        help="Model to train: A (Logistic Regression), B (Linear SVM), C (XGBoost), D (Bio_ClinicalBERT), or all"
    )
    parser.add_argument("--epochs", type=int, default=3, help="Epochs for Model D (default: 3)")
    parser.add_argument("--lr", type=float, default=2e-5, help="Learning rate for Model D (default: 2e-5)")
    parser.add_argument("--loss", type=str, default="weighted", choices=["weighted", "standard"], help="Loss type for Model D")
    args = parser.parse_args()
    
    run_pipeline(selected_model=args.model, epochs=args.epochs, lr=args.lr, loss_type=args.loss)
