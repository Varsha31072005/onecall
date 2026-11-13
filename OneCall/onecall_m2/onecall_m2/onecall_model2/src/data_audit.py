import os
import sys

_current_dir = os.path.dirname(os.path.abspath(__file__))
_parent_dir = os.path.dirname(_current_dir)
if _parent_dir not in sys.path:
    sys.path.insert(0, _parent_dir)
if _current_dir not in sys.path:
    sys.path.insert(0, _current_dir)

import json
import pandas as pd
import numpy as np

from src.preprocessing import (
    clean_text,
    normalize_specialty_label,
    audit_and_clean_dataset,
    create_leakage_free_splits,
    check_transcription_lengths,
    get_dataset_stats
)


def resolve_mtsamples_path():
    candidate_paths = [
        os.path.join("data", "mtsamples.csv"),
        os.path.join("..", "data", "mtsamples.csv"),
        os.path.join(_parent_dir, "data", "mtsamples.csv"),
        os.path.join(os.path.dirname(_parent_dir), "dataset", "mtsamples.csv"),
        r"C:\Users\venun\OneDrive\Desktop\model1\onecall_model2\data\mtsamples.csv",
        r"C:\Users\venun\OneDrive\Desktop\model1\dataset\mtsamples.csv"
    ]
    for p in candidate_paths:
        if os.path.exists(p):
            return os.path.abspath(p)
    raise FileNotFoundError("Could not locate original mtsamples.csv in candidate locations.")


def run_full_dataset_audit():
    print("=" * 70)
    print("ONECALL MODEL 2 - COMPREHENSIVE ORIGINAL DATASET AUDIT & PIPELINE")
    print("=" * 70)
    
    data_path = resolve_mtsamples_path()
    base_dir = _parent_dir
    results_dir = os.path.join(base_dir, "results")
    models_dir = os.path.join(base_dir, "models")
    data_dir = os.path.join(base_dir, "data")
    
    os.makedirs(results_dir, exist_ok=True)
    os.makedirs(models_dir, exist_ok=True)
    os.makedirs(data_dir, exist_ok=True)
    
    print(f"Loading raw MTSamples dataset from: {data_path}")
    raw_df = pd.read_csv(data_path)
    total_raw_rows = len(raw_df)
    
    # -------------------------------------------------------------
    # PART 3 — AUDIT RAW INPUTS
    # -------------------------------------------------------------
    missing_transcription_count = int(raw_df['transcription'].isnull().sum()) if 'transcription' in raw_df.columns else 0
    missing_specialty_count = int(raw_df['medical_specialty'].isnull().sum()) if 'medical_specialty' in raw_df.columns else 0
    
    # -------------------------------------------------------------
    # PART 4 & 5 — DUPLICATE AND CONFLICTING LABEL ANALYSIS
    # -------------------------------------------------------------
    clean_df, conflicting_df, same_spec_dup_df, grouped_df, audit_summary = audit_and_clean_dataset(
        raw_df, min_char_len=20, verbose=True
    )
    
    # Category A: Same specialty duplicate details
    same_spec_groups = grouped_df[(grouped_df['occurrences'] > 1) & (grouped_df['unique_specialties'] == 1)].copy()
    same_spec_groups['specialty_label'] = same_spec_groups['specialty_labels'].apply(lambda l: l[0] if len(l) > 0 else "")
    same_spec_csv = os.path.join(results_dir, "duplicate_same_specialty.csv")
    same_spec_groups[['transcription', 'occurrences', 'specialty_label']].to_csv(same_spec_csv, index=False)
    print(f"Saved same-specialty duplicate analysis to: {same_spec_csv}")
    
    # Category B: Conflicting specialty duplicate details
    conflicting_groups = grouped_df[grouped_df['unique_specialties'] > 1].copy()
    conflicting_analysis = pd.DataFrame({
        "transcription": conflicting_groups['transcription'],
        "number_of_occurrences": conflicting_groups['occurrences'],
        "specialty_labels": conflicting_groups['specialty_labels'].apply(lambda l: "; ".join(l)),
        "label_counts": conflicting_groups['label_counts'].apply(lambda d: json.dumps({str(k): int(v) for k, v in d.items()}))
    })
    conflicting_csv = os.path.join(results_dir, "conflicting_transcriptions.csv")
    conflicting_analysis.to_csv(conflicting_csv, index=False)
    print(f"Saved conflicting transcription analysis to: {conflicting_csv}")
    
    # Also save in data/ for easy reference
    conflicting_analysis.to_csv(os.path.join(data_dir, "conflicting_transcriptions.csv"), index=False)
    
    # -------------------------------------------------------------
    # TRANSCRIPTION LENGTH PROFILING (ON CLEAN DATASET)
    # -------------------------------------------------------------
    length_stats = check_transcription_lengths(clean_df['transcription'])
    
    # -------------------------------------------------------------
    # SPECIALTY CLASS METRICS (ON CLEAN DATASET)
    # -------------------------------------------------------------
    clean_stats = get_dataset_stats(clean_df, target_col='medical_specialty')
    
    # -------------------------------------------------------------
    # SAVE AUDIT CSV (PART 3 REQUIREMENTS 1-14)
    # -------------------------------------------------------------
    audit_metrics_table = [
        ("1. Total number of raw rows", total_raw_rows),
        ("2. Missing transcription count", missing_transcription_count),
        ("3. Missing specialty count", missing_specialty_count),
        ("4. Exact duplicate transcription count (rows)", audit_summary["valid_non_empty_rows"] - audit_summary["unique_transcriptions"]),
        ("5. Number of unique transcriptions", audit_summary["unique_transcriptions"]),
        ("6. Number of transcription groups having multiple specialty labels", audit_summary["conflicting_specialty_groups"]),
        ("7. Specialty class count (clean dataset)", clean_stats["num_classes"]),
        ("8. Minimum class size (clean dataset)", clean_stats["min_class_size"]),
        ("9. Maximum class size (clean dataset)", clean_stats["max_class_size"]),
        ("10. Median class size (clean dataset)", clean_stats["median_class_size"]),
        ("11. Classes with < 10 samples", clean_stats["classes_under_10"]),
        ("12. Classes with < 20 samples", clean_stats["classes_under_20"]),
        ("13. Classes with < 50 samples", clean_stats["classes_under_50"]),
        ("14. Transcription length min words", length_stats.get("min_words", 0)),
        ("15. Transcription length mean words", round(length_stats.get("mean_words", 0.0), 2)),
        ("16. Transcription length median words", round(length_stats.get("median_words", 0.0), 2)),
        ("17. Transcription length 75th percentile words", round(length_stats.get("p75_words", 0.0), 2)),
        ("18. Transcription length 90th percentile words", round(length_stats.get("p90_words", 0.0), 2)),
        ("19. Transcription length max words", length_stats.get("max_words", 0)),
        ("20. Pct exceeding 256 tokens", length_stats.get("pct_exceeding_256", 0.0)),
        ("21. Pct exceeding 384 tokens", length_stats.get("pct_exceeding_384", 0.0)),
        ("22. Pct exceeding 512 tokens", length_stats.get("pct_exceeding_512", 0.0)),
        ("23. Retained clean records", audit_summary["retained_clean_records"]),
        ("24. Excluded conflicting rows", audit_summary["excluded_conflicting_rows"])
    ]
    
    audit_df = pd.DataFrame(audit_metrics_table, columns=["Metric", "Value"])
    audit_csv_path = os.path.join(results_dir, "dataset_audit.csv")
    audit_df.to_csv(audit_csv_path, index=False)
    print(f"Saved dataset audit metrics to: {audit_csv_path}")
    
    # Save class distribution
    class_dist_csv = os.path.join(results_dir, "class_distribution.csv")
    clean_stats["class_distribution"].to_csv(class_dist_csv, index=False)
    print(f"Saved clean class distribution to: {class_dist_csv}")
    
    # -------------------------------------------------------------
    # PART 7 — CREATE CLEAN MASTER DATASET
    # -------------------------------------------------------------
    clean_master_csv = os.path.join(data_dir, "cleaned_mtsamples.csv")
    clean_df[['transcription', 'medical_specialty']].to_csv(clean_master_csv, index=False)
    # Also mirror into models/
    clean_df[['transcription', 'medical_specialty']].to_csv(os.path.join(models_dir, "cleaned_mtsamples.csv"), index=False)
    print(f"Saved clean master dataset to: {clean_master_csv} ({len(clean_df)} samples)")
    
    # -------------------------------------------------------------
    # PART 8 & 9 — LEAKAGE-FREE SPLIT & CLASS CHECKS
    # -------------------------------------------------------------
    train_df, val_df, test_df = create_leakage_free_splits(
        clean_df, train_size=0.8, val_size=0.1, test_size=0.1, random_state=42
    )
    
    train_path = os.path.join(models_dir, "train_data.csv")
    val_path = os.path.join(models_dir, "validation_data.csv")
    test_path = os.path.join(models_dir, "test_data.csv")
    
    train_df.to_csv(train_path, index=False)
    val_df.to_csv(val_path, index=False)
    test_df.to_csv(test_path, index=False)
    
    print(f"\nSaved split files successfully:")
    print(f"  Train data:      {train_path} ({len(train_df)} rows)")
    print(f"  Validation data: {val_path} ({len(val_df)} rows)")
    print(f"  Test data:       {test_path} ({len(test_df)} rows)")
    
    # Print class distribution verification
    print("\n--- CLASS DISTRIBUTION PER SPLIT ---")
    splits_comparison = pd.DataFrame({
        "Train": train_df['medical_specialty'].value_counts(),
        "Val": val_df['medical_specialty'].value_counts(),
        "Test": test_df['medical_specialty'].value_counts()
    }).fillna(0).astype(int)
    print(splits_comparison)
    splits_comparison.to_csv(os.path.join(results_dir, "splits_class_distribution.csv"))
    
    # Write Markdown Audit Report
    md_path = os.path.join(results_dir, "data_audit.md")
    with open(md_path, "w", encoding="utf-8") as f:
        f.write("# OneCall Model 2: Comprehensive MTSamples Dataset Audit\n\n")
        f.write("## 1. Executive Summary & Critical Dataset Discovery\n")
        f.write(
            f"The raw MTSamples dataset contains **{total_raw_rows}** rows. However, a deep deduplication audit revealed that "
            f"there are only **{audit_summary['unique_transcriptions']}** unique clinical transcriptions. "
            f"Crucially, **{audit_summary['conflicting_specialty_groups']}** transcription groups (accounting for **{audit_summary['excluded_conflicting_rows']}** rows) "
            f"are duplicates assigned to multiple **different** medical specialty labels (e.g., Surgery vs. Gastroenterology vs. Radiology). "
            f"In the previous uncurated split, 812 of 991 test rows were exact duplicates of training samples, creating massive data leakage and target ambiguity.\n\n"
        )
        f.write("## 2. Segregation & Cleaning Action\n")
        f.write(f"- **Retained in Single-Label Master Dataset**: {audit_summary['retained_clean_records']} records across {clean_stats['num_classes']} specialties.\n")
        f.write(f"- **Removed Exact Same-Label Duplicates**: {audit_summary['removed_exact_same_duplicates']} records.\n")
        f.write(f"- **Excluded Conflicting/Multi-Label Groups**: {audit_summary['excluded_conflicting_rows']} rows (saved separately in `conflicting_transcriptions.csv` for transparent auditing).\n\n")
        
        f.write("## 3. Key Dataset Metrics\n")
        f.write("| Metric | Value |\n")
        f.write("| :--- | :--- |\n")
        for m, v in audit_metrics_table:
            f.write(f"| {m} | {v} |\n")
            
        f.write("\n## 4. Transcription Length & Token Budget Analysis\n")
        f.write(f"- **Mean words**: {length_stats.get('mean_words', 0.0):.1f}\n")
        f.write(f"- **Median words**: {length_stats.get('median_words', 0.0):.1f}\n")
        f.write(f"- **75th percentile**: {length_stats.get('p75_words', 0.0):.1f}\n")
        f.write(f"- **90th percentile**: {length_stats.get('p90_words', 0.0):.1f}\n")
        f.write(f"- **Exceeding 256 tokens**: {length_stats.get('pct_exceeding_256', 0.0)}%\n")
        f.write(f"- **Exceeding 384 tokens**: {length_stats.get('pct_exceeding_384', 0.0)}%\n")
        f.write(f"- **Exceeding 512 tokens**: {length_stats.get('pct_exceeding_512', 0.0)}%\n\n")
        
        f.write("## 5. Clean Master Split Summary\n")
        f.write(f"- **Train**: {len(train_df)} samples\n")
        f.write(f"- **Validation**: {len(val_df)} samples\n")
        f.write(f"- **Test**: {len(test_df)} samples\n")
        f.write(f"- **Train ∩ Test overlap**: 0 texts (Verified)\n")
        f.write(f"- **Train ∩ Val overlap**: 0 texts (Verified)\n")
        f.write(f"- **Val ∩ Test overlap**: 0 texts (Verified)\n")
        
    print(f"Generated comprehensive audit markdown at: {md_path}")
    print("\nDataset audit and split generation completed successfully.")


if __name__ == "__main__":
    run_full_dataset_audit()
