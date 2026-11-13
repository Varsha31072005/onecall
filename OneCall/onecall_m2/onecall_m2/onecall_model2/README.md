# OneCall Model 2

AI-Based Medical Specialty Prediction

This repository contains the Model 2 prototype for the OneCall telemedicine application. The model predicts the most appropriate medical specialty based on a patient's free-text medical description.

## Structure
- `data/`: Contains the `mtsamples.csv` dataset.
- `src/`: Core Python modules:
  - `preprocessing.py`: Text cleaning, dataset audit stats, TF-IDF + SVD pipelines, and long-document truncation.
  - `train.py`: Sequential training runner for Models A, B, C, and D.
  - `evaluate.py`: Cross-model evaluation on a shared test set, confusion matrices, and dynamic model selection.
  - `predict.py`: Inference engine supporting both classical pipelines and Transformers with confidence margins.
  - `experiments.py`: Controlled hyperparameter exploration on transcription text.
  - `data_audit.py`: Dataset integrity and class distribution audit.
  - `error_analysis.py`: Post-evaluation error inspection.
- `api/`: FastAPI backend to serve the model.
- `models/`: Saved model artifacts, persistent test/train splits, and deployment metadata.
- `results/`: Experimental outputs (model comparison table, confusion matrices, classification reports).

## Candidate Models
- **Model A**: Logistic Regression + TF-IDF (Traditional Baseline)
- **Model B**: Linear SVM + TF-IDF (Calibrated Platt scaling)
- **Model C**: XGBoost + TF-IDF + TruncatedSVD (128 dense semantic components)
- **Model D**: Bio_ClinicalBERT Transformer (Contextual embeddings + class-weighted loss)

## Setup
```bash
pip install -r requirements.txt
```

## Sequential Execution Workflow
```bash
# 1. Train candidate models (or specify --model A/B/C/D)
python src/train.py --model all

# 2. Evaluate all candidate models on the shared test set
python src/evaluate.py

# 3. Test standalone inference
python src/predict.py
```


## Running the API
```bash
uvicorn api.main:app --reload
```

## API Usage
POST `/predict-specialty`
```json
{
    "transcription": "I have chest pain and shortness of breath."
}
```

## Disclaimer
This AI prediction is for research and informational purposes only and is not a medical diagnosis or a substitute for professional medical assessment.
