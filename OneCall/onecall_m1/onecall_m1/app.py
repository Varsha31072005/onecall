"""
OneCall Triage Web Service & API Application
Provides REST endpoints and an interactive web UI for clinical urgency triage.
"""

import os
import json
from pathlib import Path
from typing import Dict, Any, List, Optional
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import uvicorn

from triage_inference import OneCallTriageEngine

app = FastAPI(
    title="OneCall Model 1: Clinical Triage API",
    description="Multi-modal Machine Learning Triage Classification Engine (Low, Medium, High Urgency)",
    version="1.0.0"
)

# Enable CORS for external app integration (Flutter, React, iOS, Android, etc.)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Inference Engine
engine = OneCallTriageEngine()


class TriageRequest(BaseModel):
    patient_query: str = Field(..., description="Chief complaint or raw patient description")
    symptoms: Optional[str] = Field("", description="Comma-separated symptom list")
    duration: Optional[str] = Field("", description="Duration of symptoms, e.g. '2 hours', '3 days'")
    age: Optional[float] = Field(None, description="Patient age in years")
    gender: Optional[str] = Field("", description="Patient gender, e.g. 'male', 'female'")
    comorbidities: Optional[str] = Field("", description="Known medical history / conditions")
    description: Optional[str] = Field("", description="Additional context or notes")


class BatchTriageRequest(BaseModel):
    cases: List[TriageRequest]


@app.get("/api/health")
def health_check():
    """Returns engine health status and active models."""
    return {
        "status": "healthy",
        "service": "OneCall Model 1 Triage",
        "xgboost_loaded": engine.xgb_model is not None,
        "svm_loaded": engine.svm_pipeline is not None,
        "model_dir": str(engine.model_dir.resolve())
    }


@app.post("/api/triage")
def predict_triage(request: TriageRequest):
    """
    Classifies a patient case into Low, Medium, or High clinical urgency.
    """
    try:
        result = engine.predict(request.dict())
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/triage/batch")
def predict_batch_triage(request: BatchTriageRequest):
    """
    Classifies multiple patient cases in batch.
    """
    try:
        results = [engine.predict(c.dict()) for c in request.cases]
        return {"total_cases": len(results), "results": results}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/", response_class=HTMLResponse)
def index_ui():
    """
    Interactive web UI dashboard for testing and integrating OneCall Model 1.
    """
    html_content = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>OneCall Model 1 - Clinical Urgency Triage</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #090d16;
      --card-bg: rgba(18, 24, 38, 0.85);
      --card-border: rgba(255, 255, 255, 0.08);
      --text-main: #f1f5f9;
      --text-muted: #94a3b8;
      --accent: #38bdf8;
      --accent-glow: rgba(56, 189, 248, 0.15);
      --urgent-high: #ef4444;
      --urgent-high-glow: rgba(239, 68, 68, 0.2);
      --urgent-med: #f59e0b;
      --urgent-med-glow: rgba(245, 158, 11, 0.2);
      --urgent-low: #10b981;
      --urgent-low-glow: rgba(16, 185, 129, 0.2);
      --radius: 14px;
    }

    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Plus Jakarta Sans', sans-serif;
      background-color: var(--bg);
      color: var(--text-main);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      background-image: 
        radial-gradient(circle at 10% 20%, rgba(56, 189, 248, 0.08) 0%, transparent 40%),
        radial-gradient(circle at 90% 80%, rgba(139, 92, 246, 0.08) 0%, transparent 40%);
    }

    header {
      padding: 1.5rem 2rem;
      border-bottom: 1px solid var(--card-border);
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: rgba(9, 13, 22, 0.8);
      backdrop-filter: blur(12px);
      position: sticky;
      top: 0;
      z-index: 50;
    }

    .brand {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .logo-badge {
      background: linear-gradient(135deg, #0284c7, #38bdf8);
      width: 38px;
      height: 38px;
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 800;
      color: #fff;
      font-size: 1.1rem;
      box-shadow: 0 4px 14px rgba(56, 189, 248, 0.3);
    }

    .brand h1 {
      font-size: 1.25rem;
      font-weight: 700;
      letter-spacing: -0.02em;
    }

    .brand span {
      color: var(--accent);
    }

    .header-links a {
      color: var(--text-muted);
      text-decoration: none;
      font-size: 0.9rem;
      font-weight: 600;
      padding: 6px 14px;
      border-radius: 8px;
      border: 1px solid var(--card-border);
      transition: all 0.2s ease;
    }

    .header-links a:hover {
      color: var(--text-main);
      border-color: var(--accent);
      background: var(--accent-glow);
    }

    main {
      flex: 1;
      max-width: 1200px;
      width: 100%;
      margin: 0 auto;
      padding: 2rem 1.5rem;
      display: grid;
      grid-template-columns: 1.1fr 0.9fr;
      gap: 2rem;
    }

    @media (max-width: 900px) {
      main { grid-template-columns: 1fr; }
    }

    .card {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: var(--radius);
      padding: 1.75rem;
      backdrop-filter: blur(16px);
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
    }

    .card-title {
      font-size: 1.15rem;
      font-weight: 700;
      margin-bottom: 0.5rem;
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .card-subtitle {
      font-size: 0.85rem;
      color: var(--text-muted);
      margin-bottom: 1.5rem;
    }

    .presets-row {
      display: flex;
      gap: 8px;
      margin-bottom: 1.5rem;
      flex-wrap: wrap;
    }

    .preset-btn {
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid var(--card-border);
      color: var(--text-muted);
      padding: 6px 12px;
      border-radius: 20px;
      font-size: 0.75rem;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s;
    }

    .preset-btn:hover {
      border-color: var(--accent);
      color: var(--text-main);
      background: var(--accent-glow);
    }

    .form-group {
      margin-bottom: 1.25rem;
    }

    label {
      display: block;
      font-size: 0.85rem;
      font-weight: 600;
      color: var(--text-muted);
      margin-bottom: 0.4rem;
    }

    input, textarea, select {
      width: 100%;
      background: rgba(11, 15, 25, 0.7);
      border: 1px solid var(--card-border);
      color: var(--text-main);
      padding: 0.75rem 1rem;
      border-radius: 10px;
      font-family: inherit;
      font-size: 0.9rem;
      outline: none;
      transition: all 0.2s;
    }

    input:focus, textarea:focus, select:focus {
      border-color: var(--accent);
      box-shadow: 0 0 0 3px var(--accent-glow);
    }

    textarea {
      resize: vertical;
      min-height: 85px;
    }

    .grid-2 {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 1rem;
    }

    .btn-submit {
      width: 100%;
      background: linear-gradient(135deg, #0284c7, #38bdf8);
      color: #fff;
      border: none;
      padding: 0.9rem;
      border-radius: 10px;
      font-size: 1rem;
      font-weight: 700;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      transition: all 0.25s ease;
      box-shadow: 0 4px 16px rgba(56, 189, 248, 0.3);
      margin-top: 0.5rem;
    }

    .btn-submit:hover {
      transform: translateY(-1px);
      box-shadow: 0 6px 20px rgba(56, 189, 248, 0.45);
    }

    .btn-submit:active {
      transform: translateY(0);
    }

    /* Result Panel */
    .result-placeholder {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100%;
      min-height: 380px;
      text-align: center;
      color: var(--text-muted);
    }

    .triage-badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      font-size: 1.75rem;
      font-weight: 800;
      padding: 0.6rem 1.6rem;
      border-radius: 12px;
      margin-bottom: 1.25rem;
      letter-spacing: 0.03em;
    }

    .badge-high {
      background: var(--urgent-high-glow);
      color: var(--urgent-high);
      border: 1px solid var(--urgent-high);
    }

    .badge-medium {
      background: var(--urgent-med-glow);
      color: var(--urgent-med);
      border: 1px solid var(--urgent-med);
    }

    .badge-low {
      background: var(--urgent-low-glow);
      color: var(--urgent-low);
      border: 1px solid var(--urgent-low);
    }

    .advisory-box {
      background: rgba(255, 255, 255, 0.03);
      border-left: 4px solid var(--accent);
      padding: 1rem 1.25rem;
      border-radius: 8px;
      margin-bottom: 1.5rem;
      font-size: 0.9rem;
      line-height: 1.5;
    }

    .prob-bar-container {
      margin-bottom: 1rem;
    }

    .prob-bar-header {
      display: flex;
      justify-content: space-between;
      font-size: 0.8rem;
      font-weight: 600;
      margin-bottom: 0.3rem;
    }

    .prob-track {
      background: rgba(255, 255, 255, 0.06);
      height: 8px;
      border-radius: 4px;
      overflow: hidden;
    }

    .prob-fill {
      height: 100%;
      border-radius: 4px;
      transition: width 0.6s cubic-bezier(0.16, 1, 0.3, 1);
    }

    .fill-high { background: var(--urgent-high); }
    .fill-med { background: var(--urgent-med); }
    .fill-low { background: var(--urgent-low); }

    .red-flag-tag {
      background: rgba(239, 68, 68, 0.15);
      border: 1px solid var(--urgent-high);
      color: #fca5a5;
      padding: 4px 10px;
      border-radius: 6px;
      font-size: 0.8rem;
      display: inline-block;
      margin: 4px 4px 0 0;
    }

    .json-preview {
      background: #050811;
      border: 1px solid var(--card-border);
      border-radius: 8px;
      padding: 1rem;
      font-family: 'JetBrains Mono', monospace;
      font-size: 0.75rem;
      color: #38bdf8;
      max-height: 220px;
      overflow-y: auto;
      margin-top: 1.5rem;
      white-space: pre-wrap;
    }

    footer {
      text-align: center;
      padding: 1.5rem;
      font-size: 0.8rem;
      color: var(--text-muted);
      border-top: 1px solid var(--card-border);
      margin-top: auto;
    }
  </style>
</head>
<body>

  <header>
    <div class="brand">
      <div class="logo-badge">1C</div>
      <div>
        <h1>OneCall <span>Model 1</span></h1>
      </div>
    </div>
    <div class="header-links">
      <a href="/docs" target="_blank">Interactive API Docs (Swagger)</a>
    </div>
  </header>

  <main>
    <!-- Left Input Card -->
    <div class="card">
      <div class="card-title">Patient Triage Inquiry</div>
      <div class="card-subtitle">Input patient symptoms or select a clinical preset to classify urgency.</div>

      <div class="presets-row">
        <span style="font-size: 0.75rem; color: var(--text-muted); align-self: center;">Presets:</span>
        <button type="button" class="preset-btn" onclick="applyPreset('cardiac')">🚨 Acute Chest Pain</button>
        <button type="button" class="preset-btn" onclick="applyPreset('pediatric_fever')">⚠️ High Fever (Child)</button>
        <button type="button" class="preset-btn" onclick="applyPreset('mild_cold')">✅ Mild Seasonal Cough</button>
      </div>

      <form id="triageForm">
        <div class="form-group">
          <label for="patient_query">Patient Query / Chief Complaint *</label>
          <textarea id="patient_query" required placeholder="Describe what the patient is experiencing..."></textarea>
        </div>

        <div class="grid-2">
          <div class="form-group">
            <label for="symptoms">Symptoms</label>
            <input type="text" id="symptoms" placeholder="e.g. chest pain, shortness of breath">
          </div>
          <div class="form-group">
            <label for="duration">Duration</label>
            <input type="text" id="duration" placeholder="e.g. 45 minutes, 3 days">
          </div>
        </div>

        <div class="grid-2">
          <div class="form-group">
            <label for="age">Age (Years)</label>
            <input type="number" id="age" min="0" max="120" placeholder="e.g. 52">
          </div>
          <div class="form-group">
            <label for="gender">Gender</label>
            <select id="gender">
              <option value="">Select / Unknown</option>
              <option value="male">Male</option>
              <option value="female">Female</option>
            </select>
          </div>
        </div>

        <div class="form-group">
          <label for="comorbidities">Medical History / Comorbidities</label>
          <input type="text" id="comorbidities" placeholder="e.g. hypertension, diabetes, asthma">
        </div>

        <button type="submit" class="btn-submit" id="submitBtn">
          <span>Evaluate Clinical Triage</span>
        </button>
      </form>
    </div>

    <!-- Right Result Card -->
    <div class="card" id="resultCard">
      <div class="card-title">Triage Classification Result</div>
      <div class="card-subtitle">Real-time model inference and clinical risk stratification.</div>

      <div id="resultContent" class="result-placeholder">
        <svg width="48" height="48" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24" style="margin-bottom: 12px; opacity: 0.5;">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <p>Submit a patient inquiry to view clinical urgency classification, confidence scores, and safety flags.</p>
      </div>
    </div>
  </main>

  <footer>
    OneCall Model 1 Clinical Triage • Decision Support Tool • Not a substitute for professional medical diagnosis.
  </footer>

  <script>
    const presets = {
      cardiac: {
        query: "I have sudden crushing chest pressure that is radiating to my left arm, along with nausea and cold sweat.",
        symptoms: "crushing chest pain, left arm radiation, nausea, sweating",
        duration: "45 minutes",
        age: 61,
        gender: "male",
        comorbidities: "hypertension, high cholesterol"
      },
      pediatric_fever: {
        query: "My 4-year-old child has had a high fever of 103F for 2 days and is becoming unusually lethargic and refusing fluids.",
        symptoms: "high fever, lethargy, poor intake",
        duration: "2 days",
        age: 4,
        gender: "female",
        comorbidities: "none"
      },
      mild_cold: {
        query: "I have a slight tickle in my throat and a runny nose since yesterday, no breathing difficulties or fever.",
        symptoms: "mild sore throat, runny nose",
        duration: "24 hours",
        age: 28,
        gender: "female",
        comorbidities: ""
      }
    };

    function applyPreset(name) {
      const p = presets[name];
      if (!p) return;
      document.getElementById('patient_query').value = p.query;
      document.getElementById('symptoms').value = p.symptoms;
      document.getElementById('duration').value = p.duration;
      document.getElementById('age').value = p.age;
      document.getElementById('gender').value = p.gender;
      document.getElementById('comorbidities').value = p.comorbidities;
    }

    document.getElementById('triageForm').addEventListener('submit', async (e) => {
      e.preventDefault();
      const submitBtn = document.getElementById('submitBtn');
      submitBtn.innerHTML = '<span>Analyzing Case...</span>';
      submitBtn.disabled = true;

      const payload = {
        patient_query: document.getElementById('patient_query').value.trim(),
        symptoms: document.getElementById('symptoms').value.trim(),
        duration: document.getElementById('duration').value.trim(),
        age: document.getElementById('age').value ? parseFloat(document.getElementById('age').value) : null,
        gender: document.getElementById('gender').value,
        comorbidities: document.getElementById('comorbidities').value.trim()
      };

      try {
        const res = await fetch('/api/triage', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        const data = await res.json();
        renderResult(data);
      } catch (err) {
        alert('Error connecting to Triage API: ' + err.message);
      } finally {
        submitBtn.innerHTML = '<span>Evaluate Clinical Triage</span>';
        submitBtn.disabled = false;
      }
    });

    function renderResult(data) {
      const urgency = data.urgency.toLowerCase();
      const badgeClass = urgency === 'high' ? 'badge-high' : (urgency === 'medium' ? 'badge-medium' : 'badge-low');
      const badgeIcon = urgency === 'high' ? '🚨' : (urgency === 'medium' ? '⚠️' : '✅');

      let redFlagsHtml = '';
      if (data.detected_red_flags && data.detected_red_flags.length > 0) {
        redFlagsHtml = `
          <div style="margin-bottom: 1.25rem;">
            <div style="font-size: 0.8rem; font-weight: 700; color: #ef4444; margin-bottom: 4px;">Detected Emergency Red Flags:</div>
            ${data.detected_red_flags.map(f => `<span class="red-flag-tag">⚠️ ${f}</span>`).join('')}
          </div>
        `;
      }

      const pLow = (data.probabilities.low * 100).toFixed(1);
      const pMed = (data.probabilities.medium * 100).toFixed(1);
      const pHigh = (data.probabilities.high * 100).toFixed(1);

      const html = `
        <div style="text-align: center;">
          <div class="triage-badge ${badgeClass}">
            ${badgeIcon} ${data.urgency} URGENCY
          </div>
        </div>

        <div class="advisory-box" style="border-left-color: ${urgency === 'high' ? '#ef4444' : (urgency === 'medium' ? '#f59e0b' : '#10b981')}">
          <strong>Clinical Advisory:</strong><br>
          ${data.clinical_advisory}
        </div>

        ${redFlagsHtml}

        <div style="margin-bottom: 1.5rem;">
          <div style="font-size: 0.85rem; font-weight: 700; margin-bottom: 0.75rem;">Model Confidence & Probabilities</div>
          
          <div class="prob-bar-container">
            <div class="prob-bar-header">
              <span>High Urgency</span>
              <span style="color: var(--urgent-high);">${pHigh}%</span>
            </div>
            <div class="prob-track">
              <div class="prob-fill fill-high" style="width: ${pHigh}%;"></div>
            </div>
          </div>

          <div class="prob-bar-container">
            <div class="prob-bar-header">
              <span>Medium Urgency</span>
              <span style="color: var(--urgent-med);">${pMed}%</span>
            </div>
            <div class="prob-track">
              <div class="prob-fill fill-med" style="width: ${pMed}%;"></div>
            </div>
          </div>

          <div class="prob-bar-container">
            <div class="prob-bar-header">
              <span>Low Urgency</span>
              <span style="color: var(--urgent-low);">${pLow}%</span>
            </div>
            <div class="prob-track">
              <div class="prob-fill fill-low" style="width: ${pLow}%;"></div>
            </div>
          </div>
        </div>

        <div style="font-size: 0.75rem; color: var(--text-muted); margin-bottom: 0.5rem;">
          <strong>Active Engine:</strong> ${data.active_model}
        </div>

        <div style="font-size: 0.75rem; color: var(--text-muted); margin-top: 1rem;">
          <strong>App Integration JSON Response:</strong>
        </div>
        <div class="json-preview">${JSON.stringify(data, null, 2)}</div>
      `;

      document.getElementById('resultContent').innerHTML = html;
      document.getElementById('resultContent').className = '';
    }
  </script>
</body>
</html>
"""
    return html_content


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    print(f"\n[OneCall Triage API Server] Launching on http://localhost:{port}")
    print(f"[Interactive UI] Open http://localhost:{port} in your browser")
    print(f"[API Documentation] http://localhost:{port}/docs\n")
    uvicorn.run("app:app", host="0.0.0.0", port=port, reload=False)
