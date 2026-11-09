import os
import sys

_current_dir = os.path.dirname(os.path.abspath(__file__))
_parent_dir = os.path.dirname(_current_dir)
if _parent_dir not in sys.path:
    sys.path.insert(0, _parent_dir)
if _current_dir not in sys.path:
    sys.path.insert(0, _current_dir)

import json
import numpy as np
import joblib

from src.preprocessing import (
    CalibratedLinearSVC,
    WordCharHybridFeatureExtractor,
    XGBoostSpecialtyClassifier,
    TextPreprocessor
)

import __main__
__main__.CalibratedLinearSVC = CalibratedLinearSVC
__main__.WordCharHybridFeatureExtractor = WordCharHybridFeatureExtractor
__main__.XGBoostSpecialtyClassifier = XGBoostSpecialtyClassifier
__main__.TextPreprocessor = TextPreprocessor

class SpecialtyPredictor:

    """
    Inference engine for OneCall Model 2 (Medical Specialty Prediction).
    Supports either the trained classical sklearn pipeline or fine-tuned Transformer model.
    """
    def __init__(self, model_path=None):
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        models_dir = os.path.join(base_dir, "models")
        meta_path = os.path.join(models_dir, "model_metadata.json")
        
        self.model_type = "sklearn_pipeline"
        self.pipeline = None
        self.transformer_model = None
        self.tokenizer = None
        self.id2label = None
        self.classes = []
        
        # Check deployment metadata if available
        if os.path.exists(meta_path):
            try:
                with open(meta_path, "r") as f:
                    meta = json.load(f)
                self.model_type = meta.get("model_type", "sklearn_pipeline")
            except Exception:
                pass
                
        # 1. If Transformer is deployed
        transformer_dir = os.path.join(models_dir, "transformer")
        if self.model_type == "transformer" and os.path.exists(transformer_dir):
            import torch
            from transformers import AutoTokenizer, AutoModelForSequenceClassification
            from src.preprocessing import head_tail_truncate
            
            self.tokenizer = AutoTokenizer.from_pretrained(transformer_dir)
            self.transformer_model = AutoModelForSequenceClassification.from_pretrained(transformer_dir)
            self.transformer_model.eval()
            self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
            self.transformer_model.to(self.device)
            
            label_map_path = os.path.join(transformer_dir, "label_mapping.json")
            with open(label_map_path, "r") as f:
                mapping = json.load(f)
            self.id2label = {int(k): v for k, v in mapping["id2label"].items()}
            self.classes = [self.id2label[i] for i in range(len(self.id2label))]
        else:
            # 2. Classical Pipeline (Logistic Regression, Linear SVM, or XGBoost)
            resolved_path = model_path
            if not resolved_path or not os.path.exists(resolved_path):
                resolved_path = os.path.join(models_dir, "best_svm_pipeline.pkl")
            if not os.path.exists(resolved_path):
                resolved_path = os.path.join(models_dir, "onecall_specialty_model.pkl")
            if not os.path.exists(resolved_path):
                # Fallback to any saved candidate
                candidates = ["best_svm_pipeline.pkl", "Linear_SVM.pkl", "Logistic_Regression.pkl", "XGBoost.pkl"]
                for cand in candidates:
                    p = os.path.join(models_dir, cand)
                    if os.path.exists(p):
                        resolved_path = p
                        break
                        
            if not resolved_path or not os.path.exists(resolved_path):
                raise FileNotFoundError(
                    f"No trained model artifact found. Please run 'python src/train.py' and 'python src/evaluate.py' first."
                )
                
            self.pipeline = joblib.load(resolved_path)
            self.classes = list(self.pipeline.classes_)
            
    def predict(self, transcription: str):
        if not transcription or not isinstance(transcription, str) or not transcription.strip():
            raise ValueError("Transcription cannot be empty.")
            
        text = transcription.strip()
        
        # Obtain probability distribution across all classes
        if self.model_type == "transformer" and self.transformer_model is not None:
            import torch
            from src.preprocessing import head_tail_truncate
            processed_text = head_tail_truncate(text, max_words=380)
            encoded = self.tokenizer(
                [processed_text],
                padding=True,
                truncation=True,
                max_length=512,
                return_tensors="pt"
            ).to(self.device)
            with torch.no_grad():
                logits = self.transformer_model(**encoded).logits
                probas = torch.softmax(logits, dim=1).cpu().numpy()[0]
        else:
            # Sklearn pipeline
            if hasattr(self.pipeline, "predict_proba"):
                probas = self.pipeline.predict_proba([text])[0]
            elif hasattr(self.pipeline, "decision_function"):
                # Calibrated approximation from decision function
                dec = self.pipeline.decision_function([text])[0]
                exp_d = np.exp(dec - np.max(dec))
                probas = exp_d / np.sum(exp_d)
            else:
                pred = self.pipeline.predict([text])[0]
                return {
                    "predicted_specialty": str(pred),
                    "confidence": 1.0,
                    "second_specialty": None,
                    "second_probability": 0.0,
                    "probability_margin": 1.0,
                    "confidence_level": "Undetermined",
                    "margin_flag": None,
                    "message": "AI-assisted specialty prediction. Experimental research prototype, not a medical diagnosis."
                }
                
        # Pair classes with probabilities and sort descending
        prob_pairs = sorted(zip(self.classes, probas), key=lambda x: x[1], reverse=True)
        top1_spec, top1_prob = prob_pairs[0]
        top2_spec, top2_prob = prob_pairs[1] if len(prob_pairs) > 1 else (None, 0.0)
        
        margin = float(top1_prob - top2_prob)
        
        # Experimental heuristic thresholds (OneCall decision support research)
        if top1_prob >= 0.70:
            confidence_level = "High"
        elif top1_prob >= 0.40:
            confidence_level = "Moderate"
        else:
            confidence_level = "Low"
            
        margin_flag = "Tight Margin (< 0.10)" if margin < 0.10 else "Normal Margin"
        
        return {
            "predicted_specialty": str(top1_spec),
            "confidence": round(float(top1_prob), 4),
            "second_specialty": str(top2_spec) if top2_spec else None,
            "second_probability": round(float(top2_prob), 4),
            "probability_margin": round(margin, 4),
            "confidence_level": confidence_level,
            "margin_flag": margin_flag,
            "top_probabilities": {str(k): round(float(v), 4) for k, v in prob_pairs[:5]},
            "message": "AI-assisted specialty prediction. Experimental research prototype, not a medical diagnosis."
        }

_cached_predictor = None

def predict_specialty(transcription: str, model_path: str = None):
    """
    Standard inference function returning structured prediction metadata.
    """
    global _cached_predictor
    if _cached_predictor is None or model_path is not None:
        _cached_predictor = SpecialtyPredictor(model_path)
    return _cached_predictor.predict(transcription)

if __name__ == "__main__":
    test_note = "Patient presents with persistent crushing chest pain, dyspnea on exertion, and diaphoresis."
    print("Testing inference with sample clinical note:")
    print(f"Input: {test_note}\n")
    try:
        res = predict_specialty(test_note)
        print(json.dumps(res, indent=2))
    except Exception as e:
        print(f"Predictor ready. Note: Model execution will occur after training. Details: {e}")

