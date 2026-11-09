# OneCall Model 2: AI-Assisted Medical Specialty Prediction
## Comprehensive Project Overview & Review Guide

---

## 1. Executive Summary & Problem Statement

### 1.1 The Clinical Challenge
In modern telemedicine applications like **OneCall**, patients submit unstructured free-text complaints, descriptions of symptoms, or medical histories. Correctly triaging and directing patients to the proper medical specialist (e.g., Cardiology, Orthopedics, Neurology, Gastroenterology) is critical:
- **Misrouting Delays Care:** Sending a patient with cardiac ischemia to an orthopedic specialist creates critical care delays.
- **Provider Burnout & Overhead:** Clinicians waste substantial administrative hours manually reading and re-routing misdirected referrals.

### 1.2 The OneCall Model 2 Solution
**OneCall Model 2** is an NLP-driven specialty prediction service. It ingests raw clinical transcription text and accurately classifies it into the appropriate specialty while providing **calibrated posterior probabilities**, **margin flags**, and **confidence tiers** to ensure clinical safety.

---

## 2. System Architecture & Information Flow

```
+-------------------------------------------------------------+
|              OneCall Telemedicine Mobile / Web App          |
+-------------------------------------------------------------+
                              |
                     POST /predict-specialty
                   { "transcription": "..." }
                              v
+-------------------------------------------------------------+
|               FastAPI Microservice (api/main.py)            |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
|            Inference Engine (src/predict.py)                |
|  - Text Preprocessing (lowercase, whitespace normalization) |
|  - Word TF-IDF Vectorizer (1-2 n-grams, sublinear TF)       |
|  - Calibrated Linear SVM Classifier (Platt Softmax Scaling) |
+-------------------------------------------------------------+
                              |
       +----------------------+----------------------+
       |                                             |
       v                                             v
[High Confidence / Clear Margin]          [Low Confidence / Tight Margin]
Auto-route directly to specialist         Flag for Human Nurse Review
```

---

## 3. Data Engineering & Integrity Protocols

The foundation of Model 2 is built on the **MTSamples** clinical transcription dataset. Strict clinical data-engineering standards were applied:

### 3.1 Duplicate & Conflict Segregation (`src/data_audit.py`)
- **Same-Specialty Duplicates:** Redundant identical transcription records with the same label were deduplicated to retain exactly one unique instance.
- **Cross-Specialty Conflicts:** Identical transcription texts tagged under conflicting specialties (e.g. both *Surgery* and *Obstetrics/Gynecology*) were isolated and excluded from the single-label training set to eliminate label ambiguity.

### 3.2 Leakage-Free Stratified Splitting (`src/preprocessing.py`)
- **Train Split:** 154 samples (74%)
- **Validation Split:** 25 samples (12%) — used strictly for hyperparameter sweeps
- **Held-Out Test Split:** 29 samples (14%) — evaluated once to freeze benchmarks
- **Verification Guarantee:** Hard programmatic assertions verify $Train \cap Test = \emptyset$ and $Train \cap Val = \emptyset$ (zero shared clinical texts).

### 3.3 Data Augmentation & Stability Auditing (`src/analyze_augmentation_stability.py`)
- Explored synthetic text augmentation to bolster rare minority classes (expanding training data from 154 to 279 samples).
- Conducted cosine-similarity distance checks and repeated 5-fold cross-validation (25 folds) to ensure synthetic samples did not leak or memorize held-out test data.

---

## 4. Model Exploration & Empirical Benchmarks

Four candidate models across classical ML and modern deep learning were trained and evaluated on the exact same held-out test partition:

| Model Candidate | Feature Representation | Test Accuracy | Macro Precision | Macro Recall | **Macro F1** *(Primary Metric)* | Weighted F1 | Latency | Deployment Suitability |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **Model B: Linear SVM** *(Selected)* | **Word TF-IDF (1–2 n-grams) + Platt Scaling** | **79.31%** | **0.6061** | **0.6818** | **0.6288** | **0.7529** | **< 5 ms** | **Production Winner** |
| **Model A: Logistic Regression** | Word TF-IDF (1–2 n-grams, 10k features) | 75.86% | 0.5397 | 0.6667 | 0.5794 | 0.6839 | < 5 ms | Baseline Alternative |
| **Model C: XGBoost** | TF-IDF + TruncatedSVD (128 dims) | 51.72% | 0.2508 | 0.3333 | 0.2662 | 0.4389 | ~25 ms | Sub-optimal on sparse text |
| **Model D: Bio_ClinicalBERT** | Contextual Transformer Embeddings | 72.41% | 0.5303 | 0.5833 | 0.5303 | 0.6782 | ~150 ms | High compute & GPU required |

### Why Model B (Linear SVM) Was Selected
1. **Highest Macro F1 (0.6288):** High-dimensional sparse TF-IDF (10,000 features) provides clean linear separation between clinical domains, especially in imbalanced datasets.
2. **Platt Softmax Calibration:** Unlike standard SVMs that only output uncalibrated distance margins, our `CalibratedLinearSVC` wrapper applies sigmoid/softmax Platt scaling to deliver reliable posterior probabilities.
3. **Ultra-Low Latency & CPU Deployment:** Predicts in under 5 ms on standard CPU servers without needing expensive GPU instances.

---

## 5. Application Integration & API Documentation

The production model is packaged as a high-performance **FastAPI** microservice located at `api/main.py`.

### 5.1 Starting the Server
```powershell
cd c:\Users\venun\OneDrive\Desktop\model1\onecall_model2
uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload
```

### 5.2 API Endpoints

#### Health Check
- **Route:** `GET /health`
- **Output:**
  ```json
  {
    "status": "ok",
    "model_loaded": true
  }
  ```

#### Specialty Prediction
- **Route:** `POST /predict-specialty`
- **Headers:** `Content-Type: application/json`
- **Request Body:**
  ```json
  {
    "transcription": "Patient is a 62-year-old male presenting with acute retrosternal chest pressure radiating to the left shoulder and neck, accompanied by diaphoresis and shortness of breath upon minimal exertion."
  }
  ```
- **Response Body:**
  ```json
  {
    "predicted_specialty": "Cardiovascular / Pulmonary",
    "confidence": 0.8414,
    "second_specialty": "General Medicine",
    "second_probability": 0.0804,
    "probability_margin": 0.7610,
    "confidence_level": "High",
    "margin_flag": "Clear Margin (>= 0.10)",
    "top_probabilities": {
      "Cardiovascular / Pulmonary": 0.8414,
      "General Medicine": 0.0804,
      "Emergency Room Reports": 0.0412,
      "Surgery": 0.0210,
      "Radiology": 0.0160
    },
    "message": "AI-assisted specialty prediction. Experimental research prototype, not a medical diagnosis."
  }
  ```

### 5.3 Frontend / App Decision Logic
```javascript
// Example client-side routing decision
if (response.confidence_level === "High" && response.probability_margin >= 0.10) {
    // Confident match -> Auto-recommend specialist to patient
    displayRecommendedDoctor(response.predicted_specialty);
} else {
    // Low confidence or tight margin -> Request human review or offer choices
    displayTopOptions([response.predicted_specialty, response.second_specialty]);
    flagForTriageNurse();
}
```

---

## 6. Slide-by-Slide Outline for PPT Presentation

| Slide # | Slide Title | Key Content & Bullet Points |
| :---: | :--- | :--- |
| **1** | **Title Slide** | **OneCall Model 2: AI-Assisted Medical Specialty Prediction**<br>Subtitle: Intelligent Clinical Routing for Telemedicine<br>Presenter names & date |
| **2** | **Clinical Need & Motivation** | - Patients provide unstructured free-text symptom notes.<br>- Misrouting causes care delays and physician administrative burden.<br>- Goal: Real-time, calibrated automated specialty routing. |
| **3** | **Data Engineering & Quality Control** | - MTSamples clinical transcriptions.<br>- Deduplication of identical records.<br>- Segregation of cross-specialty conflicting notes.<br>- 100% disjoint train/val/test splits (Zero Leakage). |
| **4** | **Candidate Model Architecture** | - **Model A:** Logistic Regression (traditional linear baseline)<br>- **Model B:** Linear SVM + TF-IDF (margin classifier with Platt scaling)<br>- **Model C:** XGBoost + SVD (dense gradient boosting)<br>- **Model D:** Bio_ClinicalBERT (domain transformer) |
| **5** | **Benchmark Results & Selection** | - Include the Comparison Table.<br>- **Winner: Model B (Linear SVM)**<br>- **Accuracy: 79.31% \| Macro F1: 0.6288 \| Weighted F1: 0.7529**<br>- Outperformed deep learning baselines on small-sample generalization. |
| **6** | **Clinical Safety & Probability Calibration** | - Why raw SVM outputs are insufficient (lack probabilities).<br>- Softmax Platt scaling converts distance to true posterior probability.<br>- Margin flags (< 0.10) identify borderline ambiguous clinical cases. |
| **7** | **System Integration & Live Demo** | - FastAPI REST backend (`/predict-specialty`).<br>- Ultra-fast inference (< 5 ms latency).<br>- Seamless integration with OneCall mobile & web applications. |
| **8** | **Summary & Future Roadmap** | - Ready-to-deploy frozen artifact (`onecall_specialty_model.pkl`).<br>- Containerization (Docker) & horizontal scaling.<br>- Expansion to multi-label co-occurring specialties. |

---

## 7. Directory & Artifact Structure

```
onecall_model2/
│-- api/
│   └── main.py                   # FastAPI service backend
│-- data/
│   └── mtsamples.csv             # Primary clean clinical corpus
│-- models/
│   ├── onecall_specialty_model.pkl # Frozen deployed production model
│   ├── model_metadata.json       # Production deployment metadata
│   ├── train_data.csv            # Frozen training partition
│   ├── validation_data.csv       # Frozen validation partition
│   └── test_data.csv             # Frozen test partition
│-- results/
│   ├── model_comparison.csv      # Formal benchmark metrics table
│   ├── model_selection.md        # Scientific justification for Model B
│   └── confusion_matrices/       # Per-model confusion matrix plots
│-- src/
│   ├── preprocessing.py          # Core NLP, cleaners, and estimators
│   ├── train.py                  # Model training runner
│   ├── evaluate.py               # Evaluation & model freezing runner
│   └── predict.py                # Standalone inference engine
│-- PROJECT_OVERVIEW_AND_REVIEW_GUIDE.md  # This comprehensive guide
│-- README.md                     # Repository usage guide
└── requirements.txt              # Python dependencies
```

---

## 8. Clinical & Regulatory Disclaimer
*OneCall Model 2 is an AI-assisted routing tool designed for clinical workflow efficiency and decision support. It is not an automated medical diagnostic tool and must not be used as a standalone substitute for professional medical judgment.*
