# Model 2: Scientific Evaluation and Comparison

Primary selection metric: **Macro F1** (reflects balanced recognition across common and rare specialties).

| Model                        | Representation                              |   Accuracy |   Macro Precision |   Macro Recall |   Macro F1 |   Weighted Precision |   Weighted Recall |   Weighted F1 |
|:-----------------------------|:--------------------------------------------|-----------:|------------------:|---------------:|-----------:|---------------------:|------------------:|--------------:|
| Model B: Linear SVM          | TF-IDF (Calibrated Platt Scaling)           |     0.7931 |            0.6061 |         0.6818 |     0.6288 |               0.7356 |            0.7931 |        0.7529 |
| Model A: Logistic Regression | TF-IDF (ngram 1-2, sublinear, 10k features) |     0.7586 |            0.5397 |         0.6667 |     0.5794 |               0.6494 |            0.7586 |        0.6839 |
| Model C: XGBoost             | TF-IDF + TruncatedSVD (128 dims)            |     0.5172 |            0.2508 |         0.3333 |     0.2662 |               0.4115 |            0.5172 |        0.4389 |
