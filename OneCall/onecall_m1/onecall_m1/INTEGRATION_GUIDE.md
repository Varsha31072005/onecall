# OneCall Model 1: Clinical Triage Model & App Integration Guide

This guide details the fixes applied to [MOdel_1.ipynb](file:///c:/Users/venun/OneDrive/Desktop/onecall_m1/MOdel_1.ipynb) and provides complete instructions on how to integrate the triage model into your application.

---

## 1. Summary of Notebook Fixes in `MOdel_1.ipynb`

| # | Component | Original Problem | Resolution Applied |
|---|---|---|---|
| 1 | **Cell 1 & 2** | `AttributeError: _ARRAY_API not found` and `ImportError` caused by unconstrained NumPy 2.x upgrade breaking compiled C-extensions. | Pinned `numpy<2.0.0` and `huggingface_hub<0.26.0`. Cleared crash outputs. |
| 2 | **Cell 7** | Corrupted character `\ufffd` in regular expression (`age_match`). | Fixed regex to match standard hyphens and en/em dashes: `[-–—]`. |
| 3 | **Cell 13 & 14** | Hardcoded `/content` paths broke execution outside Google Colab (raising `FileNotFoundError` on local systems). | Replaced with dynamic path resolution: `Path("/content") if Path("/content").exists() else Path("./content")`. |
| 4 | **Cell 16 & 17** | **Data Leakage**: Median age and duration imputation was computed across the entire dataset before splitting. | Separated imputation: medians are strictly computed on `train_df` only and transformed onto `val_df` and `test_df`. |
| 5 | **Cell 23 & 24** | Cell 24 was a 100% duplicate of Cell 23 (running the entire ensemble validation search twice). | Removed duplicate Cell 24. |
| 6 | **Cell 25, 26, 28, 30** | Hardcoded paths for confusion matrices, feature importances, and leakage datasets. | Standardized using dynamic `OUT_DIR` and `BASE_DIR`. |
| 7 | **Cell 31** | Missing serialization of TF-IDF SVM, tokenizer/vocab, and ensemble configuration. | Added serialization of `tfidf_svm_model.joblib`, `ensemble_config.json`, and tokenizer/vocab. |
| 8 | **Cell 33** | Empty trailing cell. | Removed. |

---

## 2. Directory Architecture

```
onecall_m1/
│
├── MOdel_1.ipynb              # Fixed, crash-resilient training & evaluation notebook
├── MOdel_1.ipynb.backup       # Original backup copy
│
├── triage_inference.py        # Production-grade inference engine (class OneCallTriageEngine)
├── app.py                     # FastAPI web service + Interactive UI dashboard
│
├── content/                   # Processed datasets and exported model outputs
│   ├── onecall_syntech_clean.csv
│   ├── onecall_medical_symptom_triage_clean.csv
│   ├── onecall_model1_combined.csv
│   ├── onecall_model1_combined_no_severity.csv
│   └── onecall_model1_outputs/  # Serialized model artifacts (after running notebook)
│       ├── best_xgboost_model.joblib
│       ├── preprocessor.joblib
│       ├── tfidf_svm_model.joblib
│       ├── ensemble_config.json
│       ├── best_xlmr_weights.pt
│       └── final_metrics.csv
```

---

## 3. How to Integrate the Model into Your App

### Option A: Direct Python Module Integration (`triage_inference.py`)

If your app is built in Python (Django, Flask, FastAPI, Streamlit, Celery worker, etc.), you can import and call the inference engine directly without running a separate server:

```python
from triage_inference import OneCallTriageEngine

# Initialize the engine (automatically detects saved models or uses clinical safety baseline)
engine = OneCallTriageEngine()

# Patient case payload
patient_case = {
    "patient_query": "Severe squeezing chest pain radiating to left shoulder and neck for 30 minutes",
    "symptoms": "chest pain, radiating pain, diaphoresis",
    "duration": "30 minutes",
    "age": 62,
    "gender": "male",
    "comorbidities": "hypertension, CAD"
}

# Run prediction
result = engine.predict(patient_case)

print("Triage Urgency:", result["urgency"])         # 'HIGH', 'MEDIUM', or 'LOW'
print("Confidence:", result["confidence"])           # e.g. 0.9412
print("Probabilities:", result["probabilities"])     # {'low': 0.01, 'medium': 0.05, 'high': 0.94}
print("Advisory:", result["clinical_advisory"])
print("Red Flags:", result["detected_red_flags"])
```

---

### Option B: Microservice REST API Integration (`app.py`)

Run the triage service as a standalone REST API that any client (web, mobile, or backend) can access.

#### 1. Start the Server:
```bash
python app.py
```
* **Interactive UI:** [http://localhost:8000](http://localhost:8000)
* **Interactive Swagger Documentation:** [http://localhost:8000/docs](http://localhost:8000/docs)
* **Health Check:** `GET http://localhost:8000/api/health`

#### 2. Calling the API from Frontend / JavaScript:
```javascript
async function getTriagePrediction(patientData) {
  const response = await fetch("http://localhost:8000/api/triage", {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      patient_query: patientData.query,
      symptoms: patientData.symptoms,
      duration: patientData.duration,
      age: patientData.age,
      gender: patientData.gender,
      comorbidities: patientData.comorbidities
    })
  });
  
  const data = await response.json();
  console.log("Urgency:", data.urgency); // "HIGH" | "MEDIUM" | "LOW"
  return data;
}
```

#### 3. Calling the API from Mobile (Flutter / Dart):
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> evaluateTriage(Map<String, dynamic> patientCase) async {
  final url = Uri.parse('http://YOUR_SERVER_IP:8000/api/triage');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(patientCase),
  );
  
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to evaluate triage');
  }
}
```

#### 4. Calling via cURL:
```bash
curl -X POST "http://localhost:8000/api/triage" \
  -H "Content-Type: application/json" \
  -d '{
    "patient_query": "Severe sudden onset headache with neck stiffness and nausea",
    "duration": "2 hours",
    "age": 45,
    "gender": "female"
  }'
```

---

## 4. Response Schema

```json
{
  "urgency": "HIGH",
  "urgency_level": "high",
  "confidence": 0.892,
  "probabilities": {
    "low": 0.021,
    "medium": 0.087,
    "high": 0.892
  },
  "active_model": "Ensemble (TF-IDF/Text + XGBoost)",
  "clinical_advisory": "Immediate medical attention / emergency evaluation required. Do not delay care.",
  "detected_red_flags": [
    "Severe chest pain / pressure"
  ],
  "processed_input_summary": {
    "age_used": 62.0,
    "duration_days": 0.0208,
    "symptom_count": 3,
    "combined_text": "Symptoms: chest pain | Duration: 30 minutes | Patient query: Severe chest pain..."
  },
  "clinical_notice": "EXPERIMENTAL ML MODEL. NOT CLINICALLY VALIDATED. For demonstration & decision support only."
}
```
