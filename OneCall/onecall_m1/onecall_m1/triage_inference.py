"""
OneCall Model 1: Production Triage Inference Engine
Handles patient query ingestion, feature engineering, model inference,
and ensemble aggregation for clinical urgency triage (Low, Medium, High).
"""

import os
import re
import json
import logging
from pathlib import Path
from typing import Dict, Any, Optional, Union
import numpy as np
import pandas as pd
import joblib

logger = logging.getLogger("onecall_triage")
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")


class OneCallTriageEngine:
    """
    Inference Engine for OneCall Model 1 Triage.
    Loads saved models (XGBoost, Deep Text Model / XLM-R, TF-IDF SVM)
    and applies validation-tuned ensemble weighting.
    """

    DEFAULT_ID2LABEL = {0: "low", 1: "medium", 2: "high"}
    DEFAULT_LABEL2ID = {"low": 0, "medium": 1, "high": 2}

    def __init__(self, model_dir: Optional[Union[str, Path]] = None):
        if model_dir:
            self.model_dir = Path(model_dir)
        else:
            # Check local directory first, then Colab /content
            local_dir = Path("./content/onecall_model1_outputs")
            colab_dir = Path("/content/onecall_model1_outputs")
            if local_dir.exists():
                self.model_dir = local_dir
            elif colab_dir.exists():
                self.model_dir = colab_dir
            else:
                self.model_dir = local_dir

        self.xgb_model = None
        self.preprocessor = None
        self.svm_pipeline = None
        self.config = {}
        self.id2label = self.DEFAULT_ID2LABEL
        self.weights = {"text_model": 0.5, "xgboost": 0.5}
        self.imputation = {"train_median_age": 40.0, "train_median_duration": 3.0}

        self.load_artifacts()

    def load_artifacts(self):
        """Loads serialized models, preprocessors, and metadata."""
        cfg_path = self.model_dir / "ensemble_config.json"
        if cfg_path.exists():
            try:
                with open(cfg_path, "r", encoding="utf-8") as f:
                    self.config = json.load(f)
                self.weights = self.config.get("weights", self.weights)
                self.imputation = self.config.get("imputation", self.imputation)
                labels = self.config.get("labels", {})
                if "id2label" in labels:
                    self.id2label = {int(k): v for k, v in labels["id2label"].items()}
                logger.info(f"Loaded ensemble config from {cfg_path}")
            except Exception as e:
                logger.warning(f"Failed to read {cfg_path}: {e}")

        # Load XGBoost & Preprocessor
        xgb_path = self.model_dir / "best_xgboost_model.joblib"
        prep_path = self.model_dir / "preprocessor.joblib"
        if xgb_path.exists() and prep_path.exists():
            try:
                self.xgb_model = joblib.load(xgb_path)
                self.preprocessor = joblib.load(prep_path)
                logger.info("Loaded XGBoost model and structured preprocessor.")
            except Exception as e:
                logger.error(f"Error loading XGBoost: {e}")

        # Load TF-IDF SVM if saved
        svm_path = self.model_dir / "tfidf_svm_model.joblib"
        if svm_path.exists():
            try:
                self.svm_pipeline = joblib.load(svm_path)
                logger.info("Loaded TF-IDF SVM model pipeline.")
            except Exception as e:
                logger.warning(f"Could not load TF-IDF SVM: {e}")

    @staticmethod
    def _clean_str(val: Any) -> str:
        if val is None or pd.isna(val):
            return ""
        s = str(val).strip()
        return "" if s.lower() in ["none", "nan", "null"] else s

    @classmethod
    def build_combined_text(
        cls,
        patient_query: str = "",
        symptoms: str = "",
        duration: str = "",
        age: Any = "",
        gender: str = "",
        comorbidities: str = "",
        description: str = ""
    ) -> str:
        """Constructs standardized multimodal clinical text input."""
        sym = cls._clean_str(symptoms)
        dur = cls._clean_str(duration)
        desc = cls._clean_str(description)
        comorb = cls._clean_str(comorbidities)
        query = cls._clean_str(patient_query)

        parts = []
        if sym:
            parts.append(f"Symptoms: {sym}")
        if dur:
            parts.append(f"Duration: {dur}")
        if desc:
            parts.append(f"Description: {desc}")
        if comorb:
            parts.append(f"Comorbidities: {comorb}")
        if query:
            parts.append(f"Patient query: {query}")

        return " | ".join(parts) if parts else (query or "No symptom information provided.")

    @staticmethod
    def parse_duration_to_days(val: Any) -> float:
        """Converts natural language duration (e.g. '2 hours', '3 weeks') to float days."""
        if val is None or pd.isna(val):
            return np.nan
        s = str(val).lower().strip()
        if not s or s in ["none", "nan", "null"]:
            return np.nan

        match = re.search(r"(\d+(?:\.\d+)?)", s)
        num = float(match.group(1)) if match else 1.0

        if "minute" in s or "min" in s:
            return num / (24.0 * 60.0)
        elif "hour" in s or "hr" in s:
            return num / 24.0
        elif "day" in s:
            return num
        elif "week" in s:
            return num * 7.0
        elif "month" in s:
            return num * 30.0
        elif "year" in s:
            return num * 365.0
        return num

    @staticmethod
    def extract_duration_unit(val: Any) -> str:
        """Categorizes duration unit for structured categorical feature."""
        if val is None or pd.isna(val):
            return "missing"
        s = str(val).lower().strip()
        if "minute" in s or "min" in s:
            return "minutes"
        elif "hour" in s or "hr" in s:
            return "hours"
        elif "day" in s:
            return "days"
        elif "week" in s:
            return "weeks"
        elif "month" in s:
            return "months"
        elif "year" in s:
            return "years"
        return "other"

    @staticmethod
    def clean_gender(val: Any) -> str:
        if val is None or pd.isna(val):
            return "unknown"
        s = str(val).lower().strip()
        if s in ["m", "male", "man"]:
            return "male"
        elif s in ["f", "female", "woman"]:
            return "female"
        return "unknown"

    @staticmethod
    def count_items(val: Any) -> int:
        if val is None or pd.isna(val):
            return 0
        s = str(val).strip()
        if not s or s.lower() in ["none", "nan", "null"]:
            return 0
        for d in [";", "\n", "•"]:
            s = s.replace(d, ",")
        items = [x.strip() for x in s.split(",") if x.strip()]
        return len(items) if items else 1

    def prepare_features(self, patient_data: Dict[str, Any]) -> pd.DataFrame:
        """Transforms a single patient input dictionary into the exact model feature matrix."""
        query = self._clean_str(patient_data.get("patient_query", ""))
        symptoms = self._clean_str(patient_data.get("symptoms", ""))
        duration = self._clean_str(patient_data.get("duration", ""))
        description = self._clean_str(patient_data.get("description", ""))
        comorbidities = self._clean_str(patient_data.get("comorbidities", ""))
        age_raw = patient_data.get("age", None)
        gender_raw = patient_data.get("gender", "")

        combined_text = self.build_combined_text(
            patient_query=query,
            symptoms=symptoms,
            duration=duration,
            age=age_raw,
            gender=gender_raw,
            comorbidities=comorbidities,
            description=description
        )

        duration_days = self.parse_duration_to_days(duration)
        duration_unit = self.extract_duration_unit(duration)
        duration_is_missing = 1 if pd.isna(duration_days) else 0

        age_numeric = pd.to_numeric(age_raw, errors="coerce")
        age_is_missing = 1 if pd.isna(age_numeric) else 0

        median_age = self.imputation.get("train_median_age", 40.0)
        median_dur = self.imputation.get("train_median_duration", 3.0)

        age_imputed = median_age if pd.isna(age_numeric) else float(age_numeric)
        duration_days_imputed = median_dur if pd.isna(duration_days) else float(duration_days)

        gender_clean = self.clean_gender(gender_raw)
        symptom_count = self.count_items(symptoms if symptoms else query)
        comorbidity_count = self.count_items(comorbidities)
        has_comorbidity = 1 if comorbidity_count > 0 else 0
        text_length = len(combined_text.split())

        df_row = pd.DataFrame([{
            "combined_text": combined_text,
            "age_imputed": age_imputed,
            "age_is_missing": age_is_missing,
            "duration_days_imputed": duration_days_imputed,
            "duration_is_missing": duration_is_missing,
            "symptom_count": symptom_count,
            "comorbidity_count": comorbidity_count,
            "has_comorbidity": has_comorbidity,
            "text_length": text_length,
            "gender_clean": gender_clean,
            "duration_unit": duration_unit
        }])

        return df_row

    def predict(self, patient_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Executes end-to-end triage prediction.
        
        Args:
            patient_data: dict containing keys such as:
              - 'patient_query': str
              - 'symptoms': str (optional)
              - 'duration': str (optional)
              - 'age': int or float (optional)
              - 'gender': str (optional)
              - 'comorbidities': str (optional)
              - 'description': str (optional)
              
        Returns:
            Dictionary with urgency classification ('low', 'medium', 'high'),
            confidence score, probabilities breakdown, and safety advisories.
        """
        features_df = self.prepare_features(patient_data)
        combined_text = features_df["combined_text"].iloc[0]

        prob_xgb = None
        prob_svm = None

        # 1. XGBoost inference
        if self.xgb_model is not None and self.preprocessor is not None:
            try:
                X_struct = self.preprocessor.transform(features_df)
                prob_xgb = self.xgb_model.predict_proba(X_struct)[0]
            except Exception as e:
                logger.warning(f"XGBoost inference failed: {e}")

        # 2. TF-IDF SVM inference
        if self.svm_pipeline is not None:
            try:
                vectorizer = self.svm_pipeline["vectorizer"]
                classifier = self.svm_pipeline["classifier"]
                X_tfidf = vectorizer.transform([combined_text])
                prob_svm = classifier.predict_proba(X_tfidf)[0]
            except Exception as e:
                logger.warning(f"SVM inference failed: {e}")

        # 3. Determine Final Probabilities
        if prob_xgb is not None and prob_svm is not None:
            w_text = self.weights.get("text_model", 0.5)
            w_xgb = self.weights.get("xgboost", 0.5)
            total_w = w_text + w_xgb
            final_probs = ((w_text * prob_svm) + (w_xgb * prob_xgb)) / total_w
            active_model = "Ensemble (TF-IDF/Text + XGBoost)"
        elif prob_xgb is not None:
            final_probs = prob_xgb
            active_model = "XGBoost (Structured)"
        elif prob_svm is not None:
            final_probs = prob_svm
            active_model = "TF-IDF + LinearSVC"
        else:
            # Fallback Rule-Based Clinical Heuristic if models not yet trained on disk
            final_probs = self._heuristic_fallback(features_df.iloc[0], combined_text)
            active_model = "Clinical Heuristic Fallback (Pre-Training Baseline)"

        pred_idx = int(np.argmax(final_probs))
        urgency = self.id2label.get(pred_idx, "medium")
        confidence = float(final_probs[pred_idx])

        # Clinical Safety Check: Immediate red flags boost to High urgency
        red_flags = self._check_red_flags(combined_text)
        if red_flags and urgency != "high":
            urgency = "high"
            active_model += " [Safety Override: Red Flag Detected]"

        advisory_map = {
            "high": "Immediate medical attention / emergency evaluation required. Do not delay care.",
            "medium": "Prompt medical evaluation recommended. Contact outpatient clinic or urgent care.",
            "low": "Routine care or self-monitoring appropriate. Seek care if symptoms worsen."
        }

        return {
            "urgency": urgency.upper(),
            "urgency_level": urgency.lower(),
            "confidence": round(confidence, 4),
            "probabilities": {
                "low": round(float(final_probs[0]), 4),
                "medium": round(float(final_probs[1]), 4),
                "high": round(float(final_probs[2]), 4)
            },
            "active_model": active_model,
            "clinical_advisory": advisory_map.get(urgency.lower(), "Consult a healthcare professional."),
            "detected_red_flags": red_flags,
            "processed_input_summary": {
                "age_used": float(features_df["age_imputed"].iloc[0]),
                "duration_days": float(features_df["duration_days_imputed"].iloc[0]),
                "symptom_count": int(features_df["symptom_count"].iloc[0]),
                "combined_text": combined_text[:200] + ("..." if len(combined_text) > 200 else "")
            },
            "clinical_notice": "EXPERIMENTAL ML MODEL. NOT CLINICALLY VALIDATED. For demonstration & decision support only."
        }

    @staticmethod
    def _check_red_flags(text: str) -> list:
        """Identifies clinical emergency keywords requiring immediate care."""
        flags = []
        lowered = text.lower()
        patterns = {
            "Severe chest pain / pressure": r"\b(chest pain|pressure in chest|radiating to (?:left )?arm|crushing chest)\b",
            "Acute shortness of breath": r"\b(can't breathe|unable to breathe|severe shortness of breath|gasping|cyanosis|blue lips)\b",
            "Signs of stroke": r"\b(facial droop|slurred speech|sudden numbness|one side weakness|loss of vision)\b",
            "Severe trauma or uncontrolled bleeding": r"\b(uncontrolled bleeding|coughing blood|vomiting blood|massive hemorrhage)\b",
            "Altered mental status": r"\b(unresponsive|unconscious|fainting|blacked out|seizure)\b"
        }
        for name, pat in patterns.items():
            if re.search(pat, lowered):
                flags.append(name)
        return flags

    @staticmethod
    def _heuristic_fallback(row: pd.Series, text: str) -> np.ndarray:
        """Sensible baseline when serialized joblib models have not yet been generated."""
        lowered = text.lower()
        if any(w in lowered for w in ["chest pain", "breathless", "bleeding", "emergency", "severe", "crushing", "paralysis"]):
            return np.array([0.05, 0.15, 0.80])
        elif any(w in lowered for w in ["fever", "infection", "pain", "swelling", "vomiting", "diarrhea", "migraine"]):
            return np.array([0.15, 0.65, 0.20])
        else:
            return np.array([0.70, 0.25, 0.05])


if __name__ == "__main__":
    engine = OneCallTriageEngine()
    test_case = {
        "patient_query": "I have sudden severe chest pain that is radiating to my left jaw and sweating",
        "duration": "45 minutes",
        "age": 58,
        "gender": "male",
        "comorbidities": "hypertension, type 2 diabetes"
    }
    result = engine.predict(test_case)
    print("\n--- SAMPLE TRIAGE PREDICTION ---")
    print(json.dumps(result, indent=2))
