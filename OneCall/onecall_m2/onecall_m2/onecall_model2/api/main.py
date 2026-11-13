from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, constr
import os
import sys

# Add parent directory to path so we can import src
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from src.predict import SpecialtyPredictor

app = FastAPI(
    title="OneCall Model 2: Medical Specialty Prediction API",
    description="An academic research prototype for AI-assisted specialty prediction.",
    version="1.0.0"
)

# Load model on startup
try:
    predictor = SpecialtyPredictor()
except Exception as e:
    print(f"Warning: Model not loaded on startup (run training and evaluation first). Error: {e}")
    predictor = None


class PredictionRequest(BaseModel):
    transcription: str

@app.post("/predict-specialty")
async def predict_specialty(request: PredictionRequest):
    if predictor is None:
        raise HTTPException(status_code=503, detail="Model is not loaded.")
        
    if not request.transcription or not request.transcription.strip():
        raise HTTPException(status_code=400, detail="Transcription cannot be empty.")
        
    try:
        result = predictor.predict(request.transcription)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    return {"status": "ok", "model_loaded": predictor is not None}
