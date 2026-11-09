import os
import re
import pandas as pd
import numpy as np
import scipy.sparse as sp
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.decomposition import TruncatedSVD
from sklearn.pipeline import Pipeline
from sklearn.base import BaseEstimator, TransformerMixin, ClassifierMixin
from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import train_test_split


def clean_text(text):
    """
    Standard clinical text cleaning:
    - Converts to lowercase
    - Normalizes excessive whitespace and newlines
    - Preserves medically meaningful terminology (no aggressive stemming/lemmatization)
    """
    if not isinstance(text, str):
        return ""
    text = text.lower()
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def normalize_specialty_label(label):
    """
    Normalizes obvious formatting issues in specialty labels:
    - Leading and trailing whitespace
    - Accidental duplicate spaces within names
    - Case normalization while preserving original medical taxonomy
    Does NOT merge medically different specialties.
    """
    if not isinstance(label, str):
        return ""
    cleaned = re.sub(r'\s+', ' ', label.strip())
    return cleaned


def get_dataset_stats(df, target_col='medical_specialty'):
    """
    Computes dataset statistics for documentation and verification:
    - total samples
    - number of classes
    - class distribution
    - minimum class size
    - maximum class size
    - median class size
    """
    if target_col not in df.columns:
        raise ValueError(f"Target column '{target_col}' not found in dataframe.")
        
    counts = df[target_col].value_counts()
    pcts = df[target_col].value_counts(normalize=True) * 100
    
    stats = {
        "total_samples": len(df),
        "num_classes": int(df[target_col].nunique()),
        "min_class_size": int(counts.min()) if len(counts) > 0 else 0,
        "min_class_name": counts.idxmin() if len(counts) > 0 else "",
        "max_class_size": int(counts.max()) if len(counts) > 0 else 0,
        "max_class_name": counts.idxmax() if len(counts) > 0 else "",
        "median_class_size": float(counts.median()) if len(counts) > 0 else 0.0,
        "classes_under_10": int((counts < 10).sum()),
        "classes_under_20": int((counts < 20).sum()),
        "classes_under_50": int((counts < 50).sum()),
        "class_distribution": pd.DataFrame({
            "Specialty": counts.index,
            "Count": counts.values,
            "Percentage": pcts.values.round(2)
        })
    }
    return stats


def audit_and_clean_dataset(df, min_char_len=20, verbose=True):
    """
    Performs rigorous duplicate and conflicting label segregation:
    1. Preserves only non-leaking features: transcription (input) and medical_specialty (target).
    2. Drops records with missing transcription or medical_specialty.
    3. Cleans transcription text (whitespace normalization, lowercase).
    4. Filters out extremely short transcriptions (< min_char_len chars).
    5. Normalizes specialty label whitespace.
    6. Groups by exact cleaned transcription:
       - Category A: Duplicates with SAME specialty label -> Retains exactly 1 unique record.
       - Category B: Duplicates with DIFFERENT specialty labels -> Segregated to conflicting dataset (excluded from single-label master).
       - Single-occurrence records: Retained in clean master dataset.
       
    Returns:
        clean_df: Single-label master dataset with unique transcriptions.
        conflicting_df: All records having ambiguous/multi-specialty labels for audit.
        same_spec_dup_df: Records that were duplicates with identical labels.
        audit_summary: Dictionary of comprehensive counts.
    """
    initial_count = len(df)
    
    # Strictly isolate non-leaking features
    cols_to_keep = [c for c in ['transcription', 'medical_specialty'] if c in df.columns]
    working_df = df[cols_to_keep].copy()
    
    # 1. Missing value removal
    missing_trans = working_df['transcription'].isnull().sum() if 'transcription' in working_df.columns else 0
    missing_spec = working_df['medical_specialty'].isnull().sum() if 'medical_specialty' in working_df.columns else 0
    working_df = working_df.dropna(subset=['transcription', 'medical_specialty'])
    after_dropna = len(working_df)
    
    # 2. Text cleaning & normalization
    working_df['transcription'] = working_df['transcription'].apply(clean_text)
    working_df['medical_specialty'] = working_df['medical_specialty'].apply(normalize_specialty_label)
    
    # 3. Length filter
    short_records = working_df[working_df['transcription'].str.len() < min_char_len]
    working_df = working_df[working_df['transcription'].str.len() >= min_char_len]
    after_length_filter = len(working_df)
    
    # 4. Group by exact cleaned transcription text
    grouped = working_df.groupby('transcription')['medical_specialty'].agg(
        occurrences='count',
        unique_specialties='nunique',
        specialty_labels=lambda s: list(s.unique()),
        label_counts=lambda s: {str(k): int(v) for k, v in s.value_counts().items()}
    ).reset_index()
    
    # Category A: Exact duplicate transcription with SAME specialty label (occurrences > 1, unique_specialties == 1)
    same_spec_dup_groups = grouped[(grouped['occurrences'] > 1) & (grouped['unique_specialties'] == 1)]
    same_spec_dup_texts = set(same_spec_dup_groups['transcription'])
    
    # Category B: Duplicate transcription with DIFFERENT specialty labels (unique_specialties > 1)
    conflicting_groups = grouped[grouped['unique_specialties'] > 1]
    conflicting_texts = set(conflicting_groups['transcription'])
    
    # Single-occurrence texts (occurrences == 1)
    single_texts = set(grouped[grouped['occurrences'] == 1]['transcription'])
    
    # Build clean master dataset:
    # Retain all single occurrence records + exactly ONE record for each same-specialty duplicate group
    clean_records_mask = working_df['transcription'].isin(single_texts) | working_df['transcription'].isin(same_spec_dup_texts)
    clean_df = working_df[clean_records_mask].drop_duplicates(subset=['transcription'], keep='first').copy()
    
    # Build conflicting dataset for full audit & inspection
    conflicting_df = working_df[working_df['transcription'].isin(conflicting_texts)].copy()
    
    # Build same specialty duplicate dataset
    same_spec_dup_df = working_df[working_df['transcription'].isin(same_spec_dup_texts)].copy()
    
    # Counts
    retained_count = len(clean_df)
    removed_same_duplicates = len(same_spec_dup_df) - len(same_spec_dup_texts)
    excluded_conflicting_rows = len(conflicting_df)
    
    audit_summary = {
        "initial_raw_rows": initial_count,
        "missing_transcriptions": int(missing_trans),
        "missing_specialties": int(missing_spec),
        "short_transcriptions": len(short_records),
        "valid_non_empty_rows": after_length_filter,
        "unique_transcriptions": len(grouped),
        "duplicate_groups_total": int((grouped['occurrences'] > 1).sum()),
        "same_specialty_duplicate_groups": len(same_spec_dup_groups),
        "conflicting_specialty_groups": len(conflicting_groups),
        "retained_clean_records": retained_count,
        "removed_exact_same_duplicates": removed_same_duplicates,
        "excluded_conflicting_rows": excluded_conflicting_rows,
        "clean_specialties_count": int(clean_df['medical_specialty'].nunique())
    }
    
    if verbose:
        print("=" * 65)
        print("DATASET AUDIT & DUPLICATE SEGREGATION SUMMARY")
        print("=" * 65)
        print(f"Total raw rows:                     {initial_count}")
        print(f"Missing transcriptions:             {missing_trans}")
        print(f"Missing specialty labels:           {missing_spec}")
        print(f"Short transcriptions (< {min_char_len} chars): {len(short_records)}")
        print(f"Valid cleaned rows:                 {after_length_filter}")
        print(f"Unique transcription texts:         {len(grouped)}")
        print(f"Same-specialty duplicate groups:    {len(same_spec_dup_groups)}")
        print(f"Conflicting-specialty groups:       {len(conflicting_groups)} (rows: {excluded_conflicting_rows})")
        print("-" * 65)
        print(f"RETAINED in Clean Master Dataset:   {retained_count}")
        print(f"REMOVED as exact same duplicates:   {removed_same_duplicates}")
        print(f"EXCLUDED due to label conflicts:    {excluded_conflicting_rows}")
        print(f"Clean Unique Specialties:           {audit_summary['clean_specialties_count']}")
        print("=" * 65)
        
    return clean_df, conflicting_df, same_spec_dup_df, grouped, audit_summary


def create_leakage_free_splits(clean_df, train_size=0.8, val_size=0.1, test_size=0.1, random_state=42):
    """
    Creates a strict, leakage-free 80/10/10 train/validation/test split.
    - Uses stratified splitting for all classes with adequate sample size (>= 3).
    - Classes with 2 samples: allocates 1 to train, 1 to test.
    - Classes with 1 sample: allocated to train (cannot be split into val/test), logging a clear warning.
    - Strictly verifies train ∩ test == empty, train ∩ val == empty, val ∩ test == empty.
    """
    assert abs((train_size + val_size + test_size) - 1.0) < 1e-5, "Splits must sum to 1.0"
    
    # Shuffle dataset reproducibly
    df_shuffled = clean_df.sample(frac=1.0, random_state=random_state).reset_index(drop=True)
    
    class_counts = df_shuffled['medical_specialty'].value_counts()
    
    train_indices = []
    val_indices = []
    test_indices = []
    
    stratified_classes = []
    two_sample_classes = []
    single_sample_classes = []
    
    for cls_name, count in class_counts.items():
        cls_idx = df_shuffled.index[df_shuffled['medical_specialty'] == cls_name].tolist()
        
        if count >= 3:
            stratified_classes.append(cls_name)
            # 80% train, 10% val, 10% test
            n_test = max(1, int(round(count * test_size)))
            n_val = max(1, int(round(count * val_size)))
            n_train = count - n_test - n_val
            if n_train < 1:
                n_train = 1
                n_val = max(1, (count - 1) // 2)
                n_test = count - n_train - n_val
                
            test_indices.extend(cls_idx[:n_test])
            val_indices.extend(cls_idx[n_test:n_test + n_val])
            train_indices.extend(cls_idx[n_test + n_val:])
            
        elif count == 2:
            two_sample_classes.append(cls_name)
            # Allocate 1 to train, 1 to test (ensures both training and unseen evaluation)
            train_indices.append(cls_idx[0])
            test_indices.append(cls_idx[1])
            
        else: # count == 1
            single_sample_classes.append(cls_name)
            # Allocate sole sample to train
            train_indices.append(cls_idx[0])
            
    train_df = df_shuffled.iloc[train_indices].reset_index(drop=True)
    val_df = df_shuffled.iloc[val_indices].reset_index(drop=True)
    test_df = df_shuffled.iloc[test_indices].reset_index(drop=True)
    
    # -------------------------------------------------------------
    # AUTOMATIC VERIFICATION CHECK (STRICT ZERO LEAKAGE)
    # -------------------------------------------------------------
    train_texts = set(train_df['transcription'])
    val_texts = set(val_df['transcription'])
    test_texts = set(test_df['transcription'])
    
    train_test_overlap = len(train_texts.intersection(test_texts))
    train_val_overlap = len(train_texts.intersection(val_texts))
    val_test_overlap = len(val_texts.intersection(test_texts))
    
    if train_test_overlap != 0 or train_val_overlap != 0 or val_test_overlap != 0:
        raise ValueError(
            f"LEAKAGE DETECTED! Overlapping transcriptions found:\n"
            f"  train ∩ test: {train_test_overlap}\n"
            f"  train ∩ val:  {train_val_overlap}\n"
            f"  val ∩ test:   {val_test_overlap}\n"
            f"Splits must be 100% disjoint."
        )
        
    print("\n" + "=" * 65)
    print("DATA QUALITY & SPLIT VERIFICATION REPORT")
    print("=" * 65)
    print(f"Total clean samples:              {len(clean_df)}")
    print(f"Number of specialties:            {clean_df['medical_specialty'].nunique()}")
    print(f"Train samples:                    {len(train_df)} ({len(train_df)/len(clean_df)*100:.1f}%)")
    print(f"Validation samples:               {len(val_df)} ({len(val_df)/len(clean_df)*100:.1f}%)")
    print(f"Test samples:                     {len(test_df)} ({len(test_df)/len(clean_df)*100:.1f}%)")
    print("-" * 65)
    print(f"Duplicate train/test texts:       {train_test_overlap} (Expected: 0)")
    print(f"Duplicate train/validation texts: {train_val_overlap} (Expected: 0)")
    print(f"Duplicate validation/test texts:  {val_test_overlap} (Expected: 0)")
    print("=" * 65)
    
    if single_sample_classes:
        print(f"\n[NOTE - RARE CLASSES] {len(single_sample_classes)} classes have exactly 1 sample and were allocated to Train:")
        print(f"  {', '.join(single_sample_classes)}")
    if two_sample_classes:
        print(f"[NOTE - RARE CLASSES] {len(two_sample_classes)} classes have exactly 2 samples (allocated: 1 Train, 1 Test):")
        print(f"  {', '.join(two_sample_classes)}")
        
    return train_df, val_df, test_df


def preprocess_dataset(df, min_char_len=20, verbose=True):
    """
    Backwards-compatible wrapper returning the clean master dataset.
    """
    clean_df, _, _, _, _ = audit_and_clean_dataset(df, min_char_len=min_char_len, verbose=verbose)
    return clean_df


class TextPreprocessor(BaseEstimator, TransformerMixin):
    """
    Sklearn-compatible transformer for text preprocessing.
    """
    def fit(self, X, y=None):
        return self
    
    def transform(self, X, y=None):
        if isinstance(X, pd.Series):
            return X.apply(clean_text)
        elif isinstance(X, (list, np.ndarray)):
            return [clean_text(text) for text in X]
        else:
            return X


def get_tfidf_pipeline(classifier, ngram_range=(1, 2), max_features=10000, sublinear_tf=True, min_df=2, max_df=0.95):
    """
    Returns a pipeline with TextPreprocessor, TF-IDF Vectorizer, and the specified classifier.
    Suitable for linear models (Model A: Logistic Regression, Model B: Linear SVM).
    """
    pipeline = Pipeline([
        ('preprocessor', TextPreprocessor()),
        ('tfidf', TfidfVectorizer(
            ngram_range=ngram_range,
            max_features=max_features,
            sublinear_tf=sublinear_tf,
            min_df=min_df,
            max_df=max_df
        )),
        ('clf', classifier)
    ])
    return pipeline


def get_char_tfidf_pipeline(classifier, ngram_range=(3, 5), min_df=2, max_df=0.95, max_features=30000, sublinear_tf=True):
    """
    Returns a pipeline with TextPreprocessor, Character-level TF-IDF Vectorizer, and Classifier.
    Useful for subword pattern matching and robustness against typos in clinical text.
    """
    pipeline = Pipeline([
        ('preprocessor', TextPreprocessor()),
        ('tfidf', TfidfVectorizer(
            analyzer='char',
            ngram_range=ngram_range,
            max_features=max_features,
            sublinear_tf=sublinear_tf,
            min_df=min_df,
            max_df=max_df
        )),
        ('clf', classifier)
    ])
    return pipeline


class WordCharHybridFeatureExtractor(BaseEstimator, TransformerMixin):
    """
    Combines Word-level TF-IDF and Character-level TF-IDF via scipy.sparse.hstack.
    Maintains pure sparse CSR format without converting to dense arrays, ensuring minimal memory footprint.
    """
    def __init__(
        self,
        word_ngram_range=(1, 2),
        word_min_df=2,
        word_max_df=0.95,
        word_max_features=10000,
        word_sublinear_tf=True,
        word_stop_words=None,
        char_ngram_range=(3, 5),
        char_min_df=2,
        char_max_df=0.95,
        char_max_features=30000,
        char_sublinear_tf=True
    ):
        self.word_ngram_range = word_ngram_range
        self.word_min_df = word_min_df
        self.word_max_df = word_max_df
        self.word_max_features = word_max_features
        self.word_sublinear_tf = word_sublinear_tf
        self.word_stop_words = word_stop_words
        self.char_ngram_range = char_ngram_range
        self.char_min_df = char_min_df
        self.char_max_df = char_max_df
        self.char_max_features = char_max_features
        self.char_sublinear_tf = char_sublinear_tf
        
        self.word_vectorizer = None
        self.char_vectorizer = None

    def fit(self, X, y=None):
        self.word_vectorizer = TfidfVectorizer(
            analyzer='word',
            ngram_range=self.word_ngram_range,
            min_df=self.word_min_df,
            max_df=self.word_max_df,
            max_features=self.word_max_features,
            sublinear_tf=self.word_sublinear_tf,
            stop_words=self.word_stop_words
        )
        self.char_vectorizer = TfidfVectorizer(
            analyzer='char',
            ngram_range=self.char_ngram_range,
            min_df=self.char_min_df,
            max_df=self.char_max_df,
            max_features=self.char_max_features,
            sublinear_tf=self.char_sublinear_tf
        )
        self.word_vectorizer.fit(X)
        self.char_vectorizer.fit(X)
        return self

    def transform(self, X):
        X_word = self.word_vectorizer.transform(X)
        X_char = self.char_vectorizer.transform(X)
        return sp.hstack([X_word, X_char], format='csr')


def get_hybrid_tfidf_pipeline(classifier, hybrid_extractor=None):
    """
    Returns a pipeline with TextPreprocessor, WordCharHybridFeatureExtractor, and Classifier.
    """
    extractor = hybrid_extractor if hybrid_extractor is not None else WordCharHybridFeatureExtractor()
    pipeline = Pipeline([
        ('preprocessor', TextPreprocessor()),
        ('hybrid', extractor),
        ('clf', classifier)
    ])
    return pipeline


def get_tfidf_svd_pipeline(classifier, n_components=128, ngram_range=(1, 2), max_features=10000, random_state=42):
    """
    Returns a pipeline with TF-IDF Vectorizer + TruncatedSVD dimensionality reduction + Classifier.
    Tree-based models (Model C: XGBoost/LightGBM) benefit from dense semantic representations.
    """
    pipeline = Pipeline([
        ('preprocessor', TextPreprocessor()),
        ('tfidf', TfidfVectorizer(
            ngram_range=ngram_range,
            max_features=max_features,
            sublinear_tf=True,
            min_df=2,
            max_df=0.95
        )),
        ('svd', TruncatedSVD(n_components=n_components, random_state=random_state)),
        ('clf', classifier)
    ])
    return pipeline


class XGBoostSpecialtyClassifier(BaseEstimator, ClassifierMixin):
    """
    Wrapper for XGBoost multiclass classification with string labels.
    Seamlessly manages label encoding and exposes classes_ and predict_proba.
    Defined in preprocessing module so it can be unpickled cleanly across any script.
    """
    def __init__(self, n_estimators=100, max_depth=5, learning_rate=0.1, subsample=0.8, random_state=42):
        self.n_estimators = n_estimators
        self.max_depth = max_depth
        self.learning_rate = learning_rate
        self.subsample = subsample
        self.random_state = random_state
        self.model = None
        self.classes_ = None
        self.label_encoder_ = None
        
    def fit(self, X, y):
        import xgboost as xgb
        self.label_encoder_ = LabelEncoder()
        y_encoded = self.label_encoder_.fit_transform(y)
        self.classes_ = self.label_encoder_.classes_
        
        self.model = xgb.XGBClassifier(
            n_estimators=self.n_estimators,
            max_depth=self.max_depth,
            learning_rate=self.learning_rate,
            subsample=self.subsample,
            objective='multi:softprob',
            eval_metric='mlogloss',
            random_state=self.random_state,
            n_jobs=-1
        )
        self.model.fit(X, y_encoded)
        return self
        
    def predict(self, X):
        preds_encoded = self.model.predict(X)
        return self.label_encoder_.inverse_transform(preds_encoded)
        
    def predict_proba(self, X):
        return self.model.predict_proba(X)


class CalibratedLinearSVC(BaseEstimator, ClassifierMixin):
    """
    Linear Support Vector Classifier wrapper for medical specialty classification.
    Directly trains LinearSVC without requiring multi-fold cross validation splits
    (which crash on rare single-sample classes in imbalanced clinical datasets).
    Exposes decision_function, classes_, predict, and predict_proba via softmax margin calibration.
    """
    def __init__(self, C=1.0, class_weight='balanced', random_state=42, max_iter=2000):
        self.C = C
        self.class_weight = class_weight
        self.random_state = random_state
        self.max_iter = max_iter
        self.clf = None
        self.classes_ = None

    def fit(self, X, y):
        from sklearn.svm import LinearSVC
        self.clf = LinearSVC(
            C=self.C,
            class_weight=self.class_weight,
            random_state=self.random_state,
            dual='auto',
            max_iter=self.max_iter
        )
        self.clf.fit(X, y)
        self.classes_ = self.clf.classes_
        return self

    def predict(self, X):
        return self.clf.predict(X)

    def decision_function(self, X):
        return self.clf.decision_function(X)

    def predict_proba(self, X):
        df = self.clf.decision_function(X)
        if df.ndim == 1:
            p1 = 1.0 / (1.0 + np.exp(-np.clip(df, -50, 50)))
            return np.column_stack([1.0 - p1, p1])
        exp_df = np.exp(df - np.max(df, axis=1, keepdims=True))
        return exp_df / np.sum(exp_df, axis=1, keepdims=True)


def check_transcription_lengths(texts, max_token_limits=[256, 384, 512]):
    """
    Analyzes document word and token length distributions:
    Reports min, mean, median, 75th, 90th, 95th percentiles, max,
    and exact percentages exceeding 256, 384, and 512 tokens.
    """
    text_list = list(texts) if hasattr(texts, "tolist") or not isinstance(texts, list) else texts
    n_docs = len(text_list)
    if n_docs == 0:
        return {}

    word_counts = [len(str(t).split()) for t in text_list]
    approx_tokens = [int(w * 1.3) for w in word_counts]
    
    summary = {
        "total_documents": n_docs,
        "min_words": int(np.min(word_counts)),
        "mean_words": float(np.mean(word_counts)),
        "median_words": float(np.median(word_counts)),
        "p75_words": float(np.percentile(word_counts, 75)),
        "p90_words": float(np.percentile(word_counts, 90)),
        "p95_words": float(np.percentile(word_counts, 95)),
        "max_words": int(np.max(word_counts)),
        "approx_mean_tokens": float(np.mean(approx_tokens)),
        "approx_max_tokens": int(np.max(approx_tokens))
    }
    
    for limit in max_token_limits:
        exceeding = sum(1 for t in approx_tokens if t > limit)
        pct = (exceeding / n_docs) * 100.0 if n_docs > 0 else 0.0
        summary[f"docs_exceeding_{limit}"] = exceeding
        summary[f"pct_exceeding_{limit}"] = round(pct, 2)
        
    return summary


def head_tail_truncate(text, max_words=380, head_ratio=0.5):
    """
    Clinical long-document preservation strategy:
    Preserves Chief Complaint/History at start (head) and Impression/Plan at end (tail)
    within BERT's token budget, avoiding loss of critical diagnostic information.
    """
    if not isinstance(text, str):
        return ""
    words = text.split()
    if len(words) <= max_words:
        return text
    
    head_len = int(max_words * head_ratio)
    tail_len = max_words - head_len
    
    head_text = " ".join(words[:head_len])
    tail_text = " ".join(words[-tail_len:])
    return head_text + " " + tail_text


class ClinicalDocumentChunker:
    """
    Code support for transformer long-document chunking experiment (Part 14):
    Splits long transcriptions into overlapping chunks (e.g. 256 tokens with stride 128),
    enabling chunk-level representation aggregation (e.g. mean pooling, max pooling, or attention).
    """
    def __init__(self, chunk_size=256, chunk_stride=128):
        self.chunk_size = chunk_size
        self.chunk_stride = chunk_stride
        
    def chunk_tokens(self, input_ids, attention_mask=None):
        """
        Takes input_ids tensor or list and yields overlapping windowed chunks.
        """
        chunks = []
        seq_len = len(input_ids)
        for i in range(0, seq_len, self.chunk_stride):
            chunk = input_ids[i:i + self.chunk_size]
            chunks.append(chunk)
            if i + self.chunk_size >= seq_len:
                break
        return chunks
        
    def chunk_text(self, text):
        """
        Splits text by whitespace into overlapping word chunks.
        """
        words = text.split()
        if len(words) <= self.chunk_size:
            return [text]
        chunks = []
        for i in range(0, len(words), self.chunk_stride):
            chunk = " ".join(words[i:i + self.chunk_size])
            chunks.append(chunk)
            if i + self.chunk_size >= len(words):
                break
        return chunks
