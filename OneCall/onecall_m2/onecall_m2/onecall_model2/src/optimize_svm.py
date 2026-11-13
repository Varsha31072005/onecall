"""
OneCall Model 2: Linear SVM + TF-IDF Controlled Optimization Pipeline
====================================================================
Implements controlled hyperparameter sweeps and feature representation experiments
for Model 2 (Medical Specialty Prediction).

Guiding Principles:
1. Strict Leakage Control: Vectorizers and SVM are fitted strictly on X_train.
2. Validation Tuning: Hyperparameters and representations are selected based on Validation Macro F1.
3. One-Time Test Evaluation: The test set is evaluated ONCE on the selected best model.
4. Pure Sparse Representations: Scipy sparse matrices are preserved throughout; never converted to dense.
"""

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
import scipy.sparse as sp

from sklearn.pipeline import Pipeline
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.preprocessing import LabelEncoder
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
    TextPreprocessor,
    CalibratedLinearSVC,
    WordCharHybridFeatureExtractor,
    get_tfidf_pipeline,
    get_char_tfidf_pipeline,
    get_hybrid_tfidf_pipeline
)

# Alias into __main__ for joblib pickling reproducibility
import __main__
__main__.CalibratedLinearSVC = CalibratedLinearSVC
__main__.WordCharHybridFeatureExtractor = WordCharHybridFeatureExtractor

warnings.filterwarnings("ignore")


# -------------------------------------------------------------
# 1. PATH RESOLUTION & DATA LOADING (STRICT ZERO LEAKAGE)
# -------------------------------------------------------------
def get_paths():
    base_dir = _parent_dir
    models_dir = os.path.join(base_dir, "models")
    results_dir = os.path.join(base_dir, "results")
    cm_dir = os.path.join(results_dir, "confusion_matrices")
    os.makedirs(models_dir, exist_ok=True)
    os.makedirs(results_dir, exist_ok=True)
    os.makedirs(cm_dir, exist_ok=True)
    return base_dir, models_dir, results_dir, cm_dir


def load_dataset_splits(models_dir):
    """
    Loads train_data.csv, validation_data.csv, and test_data.csv.
    Enforces strict zero-leakage assertions before any experiment runs.
    """
    train_path = os.path.join(models_dir, "train_data.csv")
    val_path = os.path.join(models_dir, "validation_data.csv")
    test_path = os.path.join(models_dir, "test_data.csv")
    
    for p in [train_path, val_path, test_path]:
        if not os.path.exists(p):
            raise FileNotFoundError(
                f"Split file '{p}' not found. Please run 'python src/data_audit.py' first."
            )
            
    train_df = pd.read_csv(train_path)
    val_df = pd.read_csv(val_path)
    test_df = pd.read_csv(test_path)
    
    # Zero-leakage verification
    train_texts = set(train_df['transcription'].dropna())
    val_texts = set(val_df['transcription'].dropna())
    test_texts = set(test_df['transcription'].dropna())
    
    if len(train_texts & test_texts) != 0 or len(train_texts & val_texts) != 0 or len(val_texts & test_texts) != 0:
        raise ValueError("CRITICAL: Data leakage detected across splits. Halting immediately.")
        
    all_classes = sorted(list(set(train_df['medical_specialty']).union(set(val_df['medical_specialty'])).union(set(test_df['medical_specialty']))))
    return train_df, val_df, test_df, all_classes


# -------------------------------------------------------------
# 2. EXPERIMENT EVALUATION & LOGGING UTILITY
# -------------------------------------------------------------
def log_validation_experiment(
    exp_id,
    rep_name,
    pipeline,
    X_train,
    y_train,
    X_val,
    y_val,
    config_dict,
    results_dir
):
    """
    Fits the pipeline ONLY on training data.
    Evaluates strictly on the validation set for parameter selection.
    Records metrics to results/svm_optimization_results.csv.
    """
    # 1. Fit ONLY on training data
    pipeline.fit(X_train, y_train)
    
    # 2. Predict on validation data
    val_pred = pipeline.predict(X_val)
    
    val_acc = accuracy_score(y_val, val_pred)
    val_macro_p = precision_score(y_val, val_pred, average="macro", zero_division=0)
    val_macro_r = recall_score(y_val, val_pred, average="macro", zero_division=0)
    val_macro_f1 = f1_score(y_val, val_pred, average="macro", zero_division=0)
    val_weighted_f1 = f1_score(y_val, val_pred, average="weighted", zero_division=0)
    
    row = {
        "experiment_id": exp_id,
        "representation": rep_name,
        "analyzer": config_dict.get("analyzer", "word"),
        "ngram_range": str(config_dict.get("ngram_range", (1, 2))),
        "min_df": config_dict.get("min_df", 2),
        "max_df": config_dict.get("max_df", 0.95),
        "max_features": config_dict.get("max_features", 10000),
        "sublinear_tf": config_dict.get("sublinear_tf", True),
        "stop_words": str(config_dict.get("stop_words", None)),
        "C": config_dict.get("C", 1.0),
        "class_weight": str(config_dict.get("class_weight", "balanced")),
        "validation_accuracy": round(val_acc, 4),
        "validation_macro_precision": round(val_macro_p, 4),
        "validation_macro_recall": round(val_macro_r, 4),
        "validation_macro_f1": round(val_macro_f1, 4),
        "validation_weighted_f1": round(val_weighted_f1, 4)
    }
    
    print(f"  [{exp_id}] {rep_name} (C={config_dict.get('C')}, cw={config_dict.get('class_weight')}) -> Val Macro F1: {val_macro_f1:.4f} | Val Acc: {val_acc:.4f}")
    
    # Append/Update svm_optimization_results.csv
    csv_path = os.path.join(results_dir, "svm_optimization_results.csv")
    if os.path.exists(csv_path):
        results_df = pd.read_csv(csv_path)
        results_df = results_df[results_df["experiment_id"] != exp_id]
        results_df = pd.concat([results_df, pd.DataFrame([row])], ignore_index=True)
    else:
        results_df = pd.DataFrame([row])
    results_df.to_csv(csv_path, index=False)
    
    return pipeline, row


# -------------------------------------------------------------
# 3. EXPERIMENT GROUPS IMPLEMENTATION
# -------------------------------------------------------------

def run_experiment_0_baseline(X_train, y_train, X_val, y_val, results_dir):
    """
    EXPERIMENT 0 — CURRENT BASELINE:
    Word TF-IDF (1-2 ngrams, 10k features, sublinear_tf=True, min_df=2, max_df=0.95)
    + CalibratedLinearSVC(C=1.0, class_weight='balanced')
    """
    print("\n" + "=" * 65)
    print("RUNNING EXPERIMENT 0 — CURRENT BASELINE")
    print("=" * 65)
    
    cfg = {
        "analyzer": "word",
        "ngram_range": (1, 2),
        "min_df": 2,
        "max_df": 0.95,
        "max_features": 10000,
        "sublinear_tf": True,
        "stop_words": None,
        "C": 1.0,
        "class_weight": "balanced"
    }
    
    pipe = get_tfidf_pipeline(
        CalibratedLinearSVC(C=cfg["C"], class_weight=cfg["class_weight"], random_state=42),
        ngram_range=cfg["ngram_range"],
        max_features=cfg["max_features"],
        sublinear_tf=cfg["sublinear_tf"],
        min_df=cfg["min_df"],
        max_df=cfg["max_df"]
    )
    
    return log_validation_experiment(
        "EXP_0_BASELINE", "Word TF-IDF Baseline", pipe, X_train, y_train, X_val, y_val, cfg, results_dir
    )


def run_group_a_c_tuning(X_train, y_train, X_val, y_val, results_dir):
    """
    EXPERIMENT GROUP A — SVM C PARAMETER TUNING:
    Tests C in [0.01, 0.05, 0.1, 0.5, 1.0, 2.0, 5.0, 10.0] with class_weight='balanced'.
    """
    print("\n" + "=" * 65)
    print("RUNNING EXPERIMENT GROUP A — SVM C PARAMETER TUNING")
    print("=" * 65)
    
    c_values = [0.01, 0.05, 0.1, 0.5, 1.0, 2.0, 5.0, 10.0]
    best_pipe, best_row, best_f1 = None, None, -1.0
    
    for c in c_values:
        cfg = {
            "analyzer": "word",
            "ngram_range": (1, 2),
            "min_df": 2,
            "max_df": 0.95,
            "max_features": 10000,
            "sublinear_tf": True,
            "stop_words": None,
            "C": c,
            "class_weight": "balanced"
        }
        pipe = get_tfidf_pipeline(
            CalibratedLinearSVC(C=c, class_weight="balanced", random_state=42),
            ngram_range=(1, 2),
            max_features=10000,
            sublinear_tf=True,
            min_df=2,
            max_df=0.95
        )
        fitted_pipe, row = log_validation_experiment(
            f"EXP_A_C_{c}", f"Word TF-IDF (C={c})", pipe, X_train, y_train, X_val, y_val, cfg, results_dir
        )
        if row["validation_macro_f1"] > best_f1:
            best_f1 = row["validation_macro_f1"]
            best_pipe, best_row = fitted_pipe, row
            
    print(f"Group A Best: C={best_row['C']} with Validation Macro F1 = {best_f1:.4f}")
    return best_pipe, best_row


def run_group_b_class_weight(X_train, y_train, X_val, y_val, results_dir, best_c=1.0):
    """
    EXPERIMENT GROUP B — CLASS WEIGHT COMPARISON:
    Compares class_weight='balanced' vs. class_weight=None at the chosen C.
    """
    print("\n" + "=" * 65)
    print("RUNNING EXPERIMENT GROUP B — CLASS WEIGHT TUNING")
    print("=" * 65)
    
    weights = ["balanced", None]
    best_pipe, best_row, best_f1 = None, None, -1.0
    
    for cw in weights:
        cfg = {
            "analyzer": "word",
            "ngram_range": (1, 2),
            "min_df": 2,
            "max_df": 0.95,
            "max_features": 10000,
            "sublinear_tf": True,
            "stop_words": None,
            "C": best_c,
            "class_weight": cw
        }
        pipe = get_tfidf_pipeline(
            CalibratedLinearSVC(C=best_c, class_weight=cw, random_state=42),
            ngram_range=(1, 2),
            max_features=10000,
            sublinear_tf=True,
            min_df=2,
            max_df=0.95
        )
        cw_label = "balanced" if cw == "balanced" else "none"
        fitted_pipe, row = log_validation_experiment(
            f"EXP_B_CW_{cw_label}", f"Word TF-IDF (cw={cw})", pipe, X_train, y_train, X_val, y_val, cfg, results_dir
        )
        if row["validation_macro_f1"] > best_f1:
            best_f1 = row["validation_macro_f1"]
            best_pipe, best_row = fitted_pipe, row
            
    return best_pipe, best_row


def run_group_c_word_tfidf(X_train, y_train, X_val, y_val, results_dir, best_c=1.0, best_cw="balanced"):
    """
    EXPERIMENT GROUP C — WORD TF-IDF OPTIMIZATION:
    Controlled sweeps of n-gram ranges, min_df, max_df, sublinear_tf, and max_features.
    """
    print("\n" + "=" * 65)
    print("RUNNING EXPERIMENT GROUP C — WORD TF-IDF OPTIMIZATION")
    print("=" * 65)
    
    configurations = [
        # 1. N-Gram Range variations
        {"id": "EXP_C_NGRAM_1_1", "ngram_range": (1, 1), "min_df": 2, "max_df": 0.95, "sublinear_tf": True, "max_features": 10000},
        {"id": "EXP_C_NGRAM_1_2", "ngram_range": (1, 2), "min_df": 2, "max_df": 0.95, "sublinear_tf": True, "max_features": 10000},
        {"id": "EXP_C_NGRAM_1_3", "ngram_range": (1, 3), "min_df": 2, "max_df": 0.95, "sublinear_tf": True, "max_features": 10000},
        
        # 2. Min-DF variations
        {"id": "EXP_C_MINDF_1", "ngram_range": (1, 2), "min_df": 1, "max_df": 0.95, "sublinear_tf": True, "max_features": 10000},
        {"id": "EXP_C_MINDF_3", "ngram_range": (1, 2), "min_df": 3, "max_df": 0.95, "sublinear_tf": True, "max_features": 10000},
        {"id": "EXP_C_MINDF_5", "ngram_range": (1, 2), "min_df": 5, "max_df": 0.95, "sublinear_tf": True, "max_features": 10000},
        
        # 3. Max-DF variations
        {"id": "EXP_C_MAXDF_090", "ngram_range": (1, 2), "min_df": 2, "max_df": 0.90, "sublinear_tf": True, "max_features": 10000},
        {"id": "EXP_C_MAXDF_100", "ngram_range": (1, 2), "min_df": 2, "max_df": 1.00, "sublinear_tf": True, "max_features": 10000},
        
        # 4. Sublinear TF variations
        {"id": "EXP_C_SUBLIN_FALSE", "ngram_range": (1, 2), "min_df": 2, "max_df": 0.95, "sublinear_tf": False, "max_features": 10000},
        
        # 5. Vocabulary limit variations
        {"id": "EXP_C_VOCAB_20K", "ngram_range": (1, 2), "min_df": 2, "max_df": 0.95, "sublinear_tf": True, "max_features": 20000},
        {"id": "EXP_C_VOCAB_50K", "ngram_range": (1, 2), "min_df": 2, "max_df": 0.95, "sublinear_tf": True, "max_features": 50000},
        {"id": "EXP_C_VOCAB_100K", "ngram_range": (1, 2), "min_df": 2, "max_df": 0.95, "sublinear_tf": True, "max_features": 100000}
    ]
    
    best_pipe, best_row, best_f1 = None, None, -1.0
    
    for c_item in configurations:
        cfg = {
            "analyzer": "word",
            "ngram_range": c_item["ngram_range"],
            "min_df": c_item["min_df"],
            "max_df": c_item["max_df"],
            "max_features": c_item["max_features"],
            "sublinear_tf": c_item["sublinear_tf"],
            "stop_words": None,
            "C": best_c,
            "class_weight": best_cw
        }
        pipe = get_tfidf_pipeline(
            CalibratedLinearSVC(C=best_c, class_weight=best_cw, random_state=42),
            ngram_range=c_item["ngram_range"],
            max_features=c_item["max_features"],
            sublinear_tf=c_item["sublinear_tf"],
            min_df=c_item["min_df"],
            max_df=c_item["max_df"]
        )
        fitted_pipe, row = log_validation_experiment(
            c_item["id"], f"Word TF-IDF ({c_item['id']})", pipe, X_train, y_train, X_val, y_val, cfg, results_dir
        )
        if row["validation_macro_f1"] > best_f1:
            best_f1 = row["validation_macro_f1"]
            best_pipe, best_row = fitted_pipe, row
            
    print(f"Group C Best: {best_row['experiment_id']} (Validation Macro F1 = {best_f1:.4f})")
    return best_pipe, best_row


def run_group_d_stop_words(X_train, y_train, X_val, y_val, results_dir, best_c=1.0, best_cw="balanced"):
    """
    EXPERIMENT GROUP D — STOP WORDS COMPARISON:
    Evaluates stop_words=None vs. stop_words='english' without assumptions.
    """
    print("\n" + "=" * 65)
    print("RUNNING EXPERIMENT GROUP D — STOP WORDS COMPARISON")
    print("=" * 65)
    
    stop_options = [None, "english"]
    best_pipe, best_row, best_f1 = None, None, -1.0
    
    for sw in stop_options:
        sw_name = "none" if sw is None else "english"
        cfg = {
            "analyzer": "word",
            "ngram_range": (1, 2),
            "min_df": 2,
            "max_df": 0.95,
            "max_features": 10000,
            "sublinear_tf": True,
            "stop_words": sw,
            "C": best_c,
            "class_weight": best_cw
        }
        pipe = Pipeline([
            ('preprocessor', TextPreprocessor()),
            ('tfidf', TfidfVectorizer(
                analyzer='word',
                ngram_range=(1, 2),
                min_df=2,
                max_df=0.95,
                max_features=10000,
                sublinear_tf=True,
                stop_words=sw
            )),
            ('clf', CalibratedLinearSVC(C=best_c, class_weight=best_cw, random_state=42))
        ])
        fitted_pipe, row = log_validation_experiment(
            f"EXP_D_STOPWORDS_{sw_name.upper()}", f"Word TF-IDF (stopwords={sw_name})", pipe, X_train, y_train, X_val, y_val, cfg, results_dir
        )
        if row["validation_macro_f1"] > best_f1:
            best_f1 = row["validation_macro_f1"]
            best_pipe, best_row = fitted_pipe, row
            
    return best_pipe, best_row


def run_group_e_char_tfidf(X_train, y_train, X_val, y_val, results_dir, best_c=1.0, best_cw="balanced"):
    """
    EXPERIMENT GROUP E — CHARACTER-LEVEL TF-IDF:
    Evaluates character n-gram representations (3,5), (3,6), (4,6).
    Subword representations provide robustness against medical typos and compound morphological terms.
    """
    print("\n" + "=" * 65)
    print("RUNNING EXPERIMENT GROUP E — CHARACTER-LEVEL TF-IDF")
    print("=" * 65)
    
    char_ranges = [(3, 5), (3, 6), (4, 6)]
    best_pipe, best_row, best_f1 = None, None, -1.0
    
    for r in char_ranges:
        cfg = {
            "analyzer": "char",
            "ngram_range": r,
            "min_df": 2,
            "max_df": 0.95,
            "max_features": 30000,
            "sublinear_tf": True,
            "stop_words": None,
            "C": best_c,
            "class_weight": best_cw
        }
        pipe = get_char_tfidf_pipeline(
            CalibratedLinearSVC(C=best_c, class_weight=best_cw, random_state=42),
            ngram_range=r,
            min_df=2,
            max_df=0.95,
            max_features=30000,
            sublinear_tf=True
        )
        exp_id = f"EXP_E_CHAR_{r[0]}_{r[1]}"
        fitted_pipe, row = log_validation_experiment(
            exp_id, f"Char TF-IDF (ngrams={r})", pipe, X_train, y_train, X_val, y_val, cfg, results_dir
        )
        if row["validation_macro_f1"] > best_f1:
            best_f1 = row["validation_macro_f1"]
            best_pipe, best_row = fitted_pipe, row
            
    print(f"Group E Best: {best_row['experiment_id']} (Validation Macro F1 = {best_f1:.4f})")
    return best_pipe, best_row


def run_group_f_hybrid_tfidf(X_train, y_train, X_val, y_val, results_dir, best_c=1.0, best_cw="balanced"):
    """
    EXPERIMENT GROUP F — HYBRID WORD + CHARACTER TF-IDF:
    Combines Word (1,2) with Char (3,5) using scipy.sparse.hstack.
    Maintains 100% sparse CSR representation for high performance and zero dense memory waste.
    """
    print("\n" + "=" * 65)
    print("RUNNING EXPERIMENT GROUP F — HYBRID WORD + CHARACTER TF-IDF")
    print("=" * 65)
    
    cfg = {
        "analyzer": "word+char",
        "ngram_range": "(1,2)_word+(3,5)_char",
        "min_df": 2,
        "max_df": 0.95,
        "max_features": 40000, # 10k word + 30k char
        "sublinear_tf": True,
        "stop_words": None,
        "C": best_c,
        "class_weight": best_cw
    }
    
    extractor = WordCharHybridFeatureExtractor(
        word_ngram_range=(1, 2),
        word_min_df=2,
        word_max_df=0.95,
        word_max_features=10000,
        word_sublinear_tf=True,
        char_ngram_range=(3, 5),
        char_min_df=2,
        char_max_df=0.95,
        char_max_features=30000,
        char_sublinear_tf=True
    )
    
    pipe = get_hybrid_tfidf_pipeline(
        CalibratedLinearSVC(C=best_c, class_weight=best_cw, random_state=42),
        hybrid_extractor=extractor
    )
    
    return log_validation_experiment(
        "EXP_F_HYBRID_WORD_CHAR", "Hybrid Word+Char TF-IDF", pipe, X_train, y_train, X_val, y_val, cfg, results_dir
    )


def run_group_g_representation_comparison(X_train, y_train, X_val, y_val, results_dir, best_c=1.0, best_cw="balanced"):
    """
    EXPERIMENT GROUP G — FEATURE REPRESENTATION COMPARISON:
    Standardized direct comparison of 4 feature representation paradigms:
      Experiment 0: Current word TF-IDF + Linear SVM
      Experiment 1: Optimized word TF-IDF + Linear SVM
      Experiment 2: Character TF-IDF + Linear SVM
      Experiment 3: Word + Character TF-IDF + Linear SVM
    """
    print("\n" + "=" * 65)
    print("RUNNING EXPERIMENT GROUP G — FEATURE REPRESENTATION COMPARISON")
    print("=" * 65)
    
    reps = [
        ("EXP_G_0_WORD_BASE", "Baseline Word TF-IDF (1,2)", get_tfidf_pipeline(
            CalibratedLinearSVC(C=1.0, class_weight="balanced", random_state=42),
            ngram_range=(1, 2), max_features=10000, sublinear_tf=True, min_df=2, max_df=0.95
        ), {"analyzer": "word", "ngram_range": (1, 2), "max_features": 10000, "C": 1.0, "class_weight": "balanced"}),
        
        ("EXP_G_1_WORD_OPT", "Optimized Word TF-IDF (1,2 20k)", get_tfidf_pipeline(
            CalibratedLinearSVC(C=best_c, class_weight=best_cw, random_state=42),
            ngram_range=(1, 2), max_features=20000, sublinear_tf=True, min_df=2, max_df=0.95
        ), {"analyzer": "word", "ngram_range": (1, 2), "max_features": 20000, "C": best_c, "class_weight": best_cw}),
        
        ("EXP_G_2_CHAR_TFIDF", "Character TF-IDF (3,5)", get_char_tfidf_pipeline(
            CalibratedLinearSVC(C=best_c, class_weight=best_cw, random_state=42),
            ngram_range=(3, 5), max_features=30000, sublinear_tf=True, min_df=2, max_df=0.95
        ), {"analyzer": "char", "ngram_range": (3, 5), "max_features": 30000, "C": best_c, "class_weight": best_cw}),
        
        ("EXP_G_3_HYBRID_TFIDF", "Hybrid Word+Char TF-IDF", get_hybrid_tfidf_pipeline(
            CalibratedLinearSVC(C=best_c, class_weight=best_cw, random_state=42),
            hybrid_extractor=WordCharHybridFeatureExtractor()
        ), {"analyzer": "word+char", "ngram_range": "(1,2)+(3,5)", "max_features": 40000, "C": best_c, "class_weight": best_cw})
    ]
    
    for exp_id, rep_title, pipe, cfg in reps:
        log_validation_experiment(exp_id, rep_title, pipe, X_train, y_train, X_val, y_val, cfg, results_dir)


# -------------------------------------------------------------
# 4. FINAL SELECTION & ONE-TIME TEST EVALUATION (PARTS 10, 13-18)
# -------------------------------------------------------------
def finalize_and_evaluate_best(models_dir, results_dir, cm_dir):
    """
    1. Reads results/svm_optimization_results.csv.
    2. Identifies the winning configuration based on Validation Macro F1.
    3. Re-fits the winning pipeline on X_train (or X_train + X_val).
    4. Evaluates ONCE on the untouched test set (X_test).
    5. Saves:
       - results/final_model_results.csv
       - results/confused_specialty_pairs.csv (Error Analysis)
       - results/rare_class_performance.csv (Rare Class Analysis)
       - models/best_svm_pipeline.pkl, models/best_svm_model.pkl, etc.
    """
    csv_path = os.path.join(results_dir, "svm_optimization_results.csv")
    if not os.path.exists(csv_path):
        raise FileNotFoundError(
            "Optimization results not found. Please run experiments first via 'python src/optimize_svm.py --step all'."
        )
        
    results_df = pd.read_csv(csv_path)
    
    # Primary selection metric: Validation Macro F1 (with secondary metrics)
    results_df.sort_values(
        by=["validation_macro_f1", "validation_macro_recall", "validation_weighted_f1", "validation_accuracy"],
        ascending=[False, False, False, False],
        inplace=True
    )
    
    best_exp = results_df.iloc[0]
    best_id = best_exp["experiment_id"]
    best_rep = best_exp["representation"]
    best_c = float(best_exp["C"])
    
    # Safely parse class_weight (handles NaN, 'None', 'nan', '')
    raw_cw = best_exp.get("class_weight", None)
    if pd.isna(raw_cw) or str(raw_cw).strip().lower() in ["none", "nan", ""]:
        best_cw = None
    else:
        best_cw = str(raw_cw).strip()
        
    best_val_f1 = float(best_exp["validation_macro_f1"])
    
    print("\n" + "=" * 65)
    print("WINNING CONFIGURATION SELECTED ON VALIDATION SET")
    print("=" * 65)
    print(f"Selected Experiment ID: {best_id}")
    print(f"Representation:         {best_rep}")
    print(f"C parameter:            {best_c}")
    print(f"Class Weight:           {best_cw}")
    print(f"Validation Macro F1:    {best_val_f1:.4f}")
    print(f"Validation Accuracy:    {best_exp['validation_accuracy']:.4f}")
    print("=" * 65)
    
    # Load dataset splits
    train_df, val_df, test_df, all_classes = load_dataset_splits(models_dir)
    X_train, y_train = train_df['transcription'], train_df['medical_specialty']
    X_test, y_test = test_df['transcription'], test_df['medical_specialty']
    
    # Rebuild the winning pipeline
    analyzer = str(best_exp["analyzer"]).lower()
    
    if "char" in analyzer and "word" in analyzer:
        # Hybrid
        extractor = WordCharHybridFeatureExtractor(
            word_ngram_range=(1, 2),
            word_max_features=10000,
            char_ngram_range=(3, 5),
            char_max_features=30000
        )
        best_pipeline = get_hybrid_tfidf_pipeline(
            CalibratedLinearSVC(C=best_c, class_weight=best_cw, random_state=42),
            hybrid_extractor=extractor
        )
    elif "char" in analyzer:
        # Char only
        ng_range = eval(str(best_exp["ngram_range"])) if isinstance(best_exp["ngram_range"], str) else (3, 5)
        best_pipeline = get_char_tfidf_pipeline(
            CalibratedLinearSVC(C=best_c, class_weight=best_cw, random_state=42),
            ngram_range=ng_range,
            max_features=int(best_exp["max_features"])
        )
    else:
        # Word only
        ng_range = eval(str(best_exp["ngram_range"])) if isinstance(best_exp["ngram_range"], str) else (1, 2)
        
        # Safely parse stop_words (handles NaN, 'None', 'nan', 'english')
        raw_sw = best_exp.get("stop_words", None)
        if pd.isna(raw_sw) or str(raw_sw).strip().lower() in ["none", "nan", ""]:
            sw = None
        elif str(raw_sw).strip().lower() == "english":
            sw = "english"
        else:
            sw = str(raw_sw).strip()
            
        best_pipeline = Pipeline([
            ('preprocessor', TextPreprocessor()),
            ('tfidf', TfidfVectorizer(
                analyzer='word',
                ngram_range=ng_range,
                min_df=int(best_exp["min_df"]),
                max_df=float(best_exp["max_df"]),
                max_features=int(best_exp["max_features"]),
                sublinear_tf=bool(best_exp["sublinear_tf"]),
                stop_words=sw
            )),
            ('clf', CalibratedLinearSVC(C=best_c, class_weight=best_cw, random_state=42))
        ])
        
    # Fit strictly on training data
    print("\nFitting selected winning pipeline strictly on training data...")
    best_pipeline.fit(X_train, y_train)
    
    # One-Time Final Test Evaluation
    print("Evaluating ONCE on untouched test set...")
    test_pred = best_pipeline.predict(X_test)
    
    test_acc = accuracy_score(y_test, test_pred)
    test_macro_p = precision_score(y_test, test_pred, average="macro", zero_division=0)
    test_macro_r = recall_score(y_test, test_pred, average="macro", zero_division=0)
    test_macro_f1 = f1_score(y_test, test_pred, average="macro", zero_division=0)
    test_weighted_p = precision_score(y_test, test_pred, average="weighted", zero_division=0)
    test_weighted_r = recall_score(y_test, test_pred, average="weighted", zero_division=0)
    test_weighted_f1 = f1_score(y_test, test_pred, average="weighted", zero_division=0)
    
    print("\n" + "=" * 65)
    print("FINAL TEST SET PERFORMANCE (SELECTED MODEL)")
    print("=" * 65)
    print(f"Accuracy:           {test_acc:.4f}")
    print(f"Macro Precision:    {test_macro_p:.4f}")
    print(f"Macro Recall:       {test_macro_r:.4f}")
    print(f"Macro F1 (Primary): {test_macro_f1:.4f}")
    print(f"Weighted Precision: {test_weighted_p:.4f}")
    print(f"Weighted Recall:    {test_weighted_r:.4f}")
    print(f"Weighted F1:        {test_weighted_f1:.4f}")
    print("=" * 65)
    
    # Save results/final_model_results.csv (Part 17)
    final_test_row = {
        "model": "Optimized Linear SVM",
        "representation": best_rep,
        "accuracy": round(test_acc, 4),
        "macro_precision": round(test_macro_p, 4),
        "macro_recall": round(test_macro_r, 4),
        "macro_f1": round(test_macro_f1, 4),
        "weighted_precision": round(test_weighted_p, 4),
        "weighted_recall": round(test_weighted_r, 4),
        "weighted_f1": round(test_weighted_f1, 4)
    }
    final_csv_path = os.path.join(results_dir, "final_model_results.csv")
    pd.DataFrame([final_test_row]).to_csv(final_csv_path, index=False)
    print(f"Saved final test metrics to: {final_csv_path}")
    
    # -------------------------------------------------------------
    # ERROR ANALYSIS & CONFUSION PAIRS (PART 13)
    # -------------------------------------------------------------
    # 1. Per-class report sorted by F1 ascending (weakest classes first)
    rep_dict = classification_report(y_test, test_pred, labels=all_classes, output_dict=True, zero_division=0)
    class_report_rows = []
    for cls in all_classes:
        metrics = rep_dict.get(cls, {"precision": 0.0, "recall": 0.0, "f1-score": 0.0, "support": 0})
        class_report_rows.append({
            "specialty": cls,
            "precision": round(metrics["precision"], 4),
            "recall": round(metrics["recall"], 4),
            "f1_score": round(metrics["f1-score"], 4),
            "test_support": int(metrics["support"])
        })
    class_report_df = pd.DataFrame(class_report_rows)
    class_report_df.sort_values(by="f1_score", ascending=True, inplace=True)
    report_path = os.path.join(results_dir, "optimized_svm_classification_report.csv")
    class_report_df.to_csv(report_path, index=False)
    print(f"Saved per-class report (weakest classes first) to: {report_path}")
    
    # 2. Confusion Matrix Heatmap
    cm = confusion_matrix(y_test, test_pred, labels=all_classes)
    plt.figure(figsize=(14, 11))
    sns.heatmap(cm, annot=False, cmap="Blues", xticklabels=all_classes, yticklabels=all_classes)
    plt.title(f"Optimized Linear SVM Confusion Matrix (Macro F1: {test_macro_f1:.4f})")
    plt.xlabel("Predicted Specialty")
    plt.ylabel("True Specialty")
    plt.xticks(rotation=90, fontsize=8)
    plt.yticks(rotation=0, fontsize=8)
    plt.tight_layout()
    cm_plot_path = os.path.join(cm_dir, "optimized_svm_cm.png")
    plt.savefig(cm_plot_path, dpi=300)
    plt.close()
    print(f"Saved confusion matrix heatmap to: {cm_plot_path}")
    
    # 3. Frequently confused specialty pairs
    confused_pairs = []
    for i, true_cls in enumerate(all_classes):
        for j, pred_cls in enumerate(all_classes):
            if i != j and cm[i, j] > 0:
                confused_pairs.append({
                    "True Specialty": true_cls,
                    "Predicted Specialty": pred_cls,
                    "Number of errors": int(cm[i, j])
                })
    confused_df = pd.DataFrame(confused_pairs)
    if not confused_df.empty:
        confused_df.sort_values(by="Number of errors", ascending=False, inplace=True)
    else:
        confused_df = pd.DataFrame(columns=["True Specialty", "Predicted Specialty", "Number of errors"])
    confused_csv_path = os.path.join(results_dir, "confused_specialty_pairs.csv")
    confused_df.to_csv(confused_csv_path, index=False)
    print(f"Saved confused specialty pairs to: {confused_csv_path}")
    
    # -------------------------------------------------------------
    # RARE CLASS PERFORMANCE ANALYSIS (PART 14)
    # -------------------------------------------------------------
    train_counts = train_df['medical_specialty'].value_counts().to_dict()
    val_counts = val_df['medical_specialty'].value_counts().to_dict()
    test_counts = test_df['medical_specialty'].value_counts().to_dict()
    
    rare_analysis_rows = []
    for cls in all_classes:
        m = rep_dict.get(cls, {"precision": 0.0, "recall": 0.0, "f1-score": 0.0})
        rare_analysis_rows.append({
            "specialty": cls,
            "training_support": int(train_counts.get(cls, 0)),
            "validation_support": int(val_counts.get(cls, 0)),
            "test_support": int(test_counts.get(cls, 0)),
            "precision": round(m["precision"], 4),
            "recall": round(m["recall"], 4),
            "f1": round(m["f1-score"], 4)
        })
    rare_df = pd.DataFrame(rare_analysis_rows)
    # Sort by training support ascending
    rare_df.sort_values(by="training_support", ascending=True, inplace=True)
    rare_csv_path = os.path.join(results_dir, "rare_class_performance.csv")
    rare_df.to_csv(rare_csv_path, index=False)
    print(f"Saved rare class analysis to: {rare_csv_path}")
    
    # -------------------------------------------------------------
    # SAVE PIPELINE & ARTIFACTS (PART 18)
    # -------------------------------------------------------------
    # 1. Complete end-to-end pipeline
    pipeline_save_path = os.path.join(models_dir, "best_svm_pipeline.pkl")
    joblib.dump(best_pipeline, pipeline_save_path)
    
    # Also update production model
    prod_model_path = os.path.join(models_dir, "onecall_specialty_model.pkl")
    joblib.dump(best_pipeline, prod_model_path)
    
    # 2. Individual components (classifier and vectorizers)
    clf_obj = best_pipeline.named_steps['clf']
    joblib.dump(clf_obj, os.path.join(models_dir, "best_svm_model.pkl"))
    
    if "hybrid" in best_pipeline.named_steps:
        hybrid_step = best_pipeline.named_steps['hybrid']
        joblib.dump(hybrid_step.word_vectorizer, os.path.join(models_dir, "word_tfidf.pkl"))
        joblib.dump(hybrid_step.char_vectorizer, os.path.join(models_dir, "char_tfidf.pkl"))
    elif "tfidf" in best_pipeline.named_steps:
        joblib.dump(best_pipeline.named_steps['tfidf'], os.path.join(models_dir, "best_tfidf_vectorizer.pkl"))
        
    # 3. Label encoder
    le = LabelEncoder()
    le.fit(all_classes)
    joblib.dump(le, os.path.join(models_dir, "label_encoder.pkl"))
    
    # 4. Configuration JSON
    best_config = {
        "experiment_id": best_id,
        "representation": best_rep,
        "analyzer": analyzer,
        "parameters": best_exp.to_dict(),
        "validation_metrics": {
            "macro_f1": best_val_f1,
            "accuracy": float(best_exp["validation_accuracy"])
        },
        "test_metrics": final_test_row
    }
    with open(os.path.join(models_dir, "best_model_config.json"), "w") as f:
        json.dump(best_config, f, indent=2)
        
    print(f"\nSaved all artifacts to '{models_dir}':")
    print(f"  - best_svm_pipeline.pkl (and onecall_specialty_model.pkl)")
    print(f"  - best_svm_model.pkl")
    print(f"  - best_tfidf_vectorizer.pkl (or word_tfidf.pkl / char_tfidf.pkl)")
    print(f"  - label_encoder.pkl")
    print(f"  - best_model_config.json")
    print("\nModel 2 optimization complete.")


# -------------------------------------------------------------
# 5. INFERENCE FUNCTION (PART 19 & 20)
# -------------------------------------------------------------
def predict_specialty(transcription, model_path=None):
    """
    Standardized inference function for OneCall Model 2.
    Applies the exact same preprocessing and feature representation as the selected model.
    Returns predicted_specialty, decision margins, and calibrated probability estimates.
    """
    base_dir, models_dir, _, _ = get_paths()
    if model_path is None:
        model_path = os.path.join(models_dir, "onecall_specialty_model.pkl")
        if not os.path.exists(model_path):
            model_path = os.path.join(models_dir, "best_svm_pipeline.pkl")
            
    if not os.path.exists(model_path):
        raise FileNotFoundError(f"Trained model not found at {model_path}.")
        
    pipeline = joblib.load(model_path)
    
    is_single = isinstance(transcription, str)
    texts = [transcription] if is_single else list(transcription)
    
    preds = pipeline.predict(texts)
    
    # Decision scores & calibrated probabilities
    clf = pipeline.named_steps.get('clf', None)
    results = []
    
    if hasattr(pipeline, "predict_proba"):
        probas = pipeline.predict_proba(texts)
        classes = pipeline.classes_ if hasattr(pipeline, "classes_") else clf.classes_
        
        for i, pred in enumerate(preds):
            p = probas[i]
            sorted_idx = np.argsort(p)[::-1]
            top_class = classes[sorted_idx[0]]
            top_prob = float(p[sorted_idx[0]])
            second_class = classes[sorted_idx[1]] if len(sorted_idx) > 1 else top_class
            second_prob = float(p[sorted_idx[1]]) if len(sorted_idx) > 1 else top_prob
            margin = top_prob - second_prob
            
            top_dict = {classes[idx]: round(float(p[idx]), 4) for idx in sorted_idx[:5]}
            
            results.append({
                "predicted_specialty": pred,
                "confidence": round(top_prob, 4),
                "second_specialty": second_class,
                "second_probability": round(second_prob, 4),
                "probability_margin": round(margin, 4),
                "top_probabilities": top_dict,
                "note": "Calibrated softmax estimates over SVM decision margins."
            })
    else:
        for pred in preds:
            results.append({"predicted_specialty": pred})
            
    return results[0] if is_single else results


# -------------------------------------------------------------
# 6. CLI DISPATCHER
# -------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="OneCall Model 2 Linear SVM Optimization Runner")
    parser.add_argument(
        "--step",
        type=str,
        default="baseline",
        choices=["0", "baseline", "A", "C_tuning", "B", "class_weight", "C", "word_tfidf", "D", "stop_words", "E", "char_tfidf", "F", "hybrid", "G", "compare", "all"],
        help="Experiment group to execute"
    )
    parser.add_argument(
        "--finalize",
        action="store_true",
        help="Selects best configuration using validation Macro F1, evaluates ONCE on test set, and saves models."
    )
    args = parser.parse_args()
    
    base_dir, models_dir, results_dir, cm_dir = get_paths()
    train_df, val_df, test_df, all_classes = load_dataset_splits(models_dir)
    
    X_train, y_train = train_df['transcription'], train_df['medical_specialty']
    X_val, y_val = val_df['transcription'], val_df['medical_specialty']
    
    step = args.step.upper()
    
    if args.finalize:
        finalize_and_evaluate_best(models_dir, results_dir, cm_dir)
        return
        
    if step in ["0", "BASELINE", "ALL"]:
        run_experiment_0_baseline(X_train, y_train, X_val, y_val, results_dir)
        
    if step in ["A", "C_TUNING", "ALL"]:
        run_group_a_c_tuning(X_train, y_train, X_val, y_val, results_dir)
        
    if step in ["B", "CLASS_WEIGHT", "ALL"]:
        run_group_b_class_weight(X_train, y_train, X_val, y_val, results_dir, best_c=1.0)
        
    if step in ["C", "WORD_TFIDF", "ALL"]:
        run_group_c_word_tfidf(X_train, y_train, X_val, y_val, results_dir, best_c=1.0, best_cw="balanced")
        
    if step in ["D", "STOP_WORDS", "ALL"]:
        run_group_d_stop_words(X_train, y_train, X_val, y_val, results_dir, best_c=1.0, best_cw="balanced")
        
    if step in ["E", "CHAR_TFIDF", "ALL"]:
        run_group_e_char_tfidf(X_train, y_train, X_val, y_val, results_dir, best_c=1.0, best_cw="balanced")
        
    if step in ["F", "HYBRID", "ALL"]:
        run_group_f_hybrid_tfidf(X_train, y_train, X_val, y_val, results_dir, best_c=1.0, best_cw="balanced")
        
    if step in ["G", "COMPARE", "ALL"]:
        run_group_g_representation_comparison(X_train, y_train, X_val, y_val, results_dir, best_c=1.0, best_cw="balanced")
        
    print("\n" + "=" * 65)
    print("EXPERIMENT EXECUTION COMPLETE")
    print(f"Validation metrics logged to: {os.path.join(results_dir, 'svm_optimization_results.csv')}")
    print("Next step: Run 'python src/optimize_svm.py --finalize' to evaluate the best model on test set.")
    print("=" * 65)


if __name__ == "__main__":
    main()
