# RFC: WESAD SVM → Flutter On‑Device Emotion Model

**Author:** Synheart AI Research Team
**Date:** 2025‑10‑20
**Status:** Implementation‑Ready Specification

---

## 1. Purpose

Define the structure and implementation flow for training, validating, and deploying a Support Vector Machine (SVM)‑based **emotion recognition model** on mobile devices. The model is trained on the **WESAD dataset** and deployed within the **Synheart Flutter SDK** for real‑time HRV‑based emotion inference.

This document is optimized for execution by an **AI agent or automation pipeline**, ensuring each stage can be programmatically completed.

---

## 2. Objectives

### Core

1. Train emotion classifier using HRV data from WESAD.
2. Evaluate both **RBF** and **Linear** SVM variants.
3. Export model weights and scaler parameters to a JSON file.
4. Integrate JSON into Flutter SDK for on‑device inference.

### Constraints

* Must run fully offline on mobile.
* Latency < 20 ms per prediction.
* Model footprint ≤ 1 MB.

---

## 3. Implementation Phases

### Phase 1 – Dataset Processing

**Input:** Raw WESAD dataset (ECG files).
**Task:**

1. Extract RR intervals (NN‑only).
2. Segment into 60–120 s overlapping windows.
3. Label windows with “Calm” (baseline) or “Stress” (stress task).
   **Output:** Processed RR sequences with class labels.

---

### Phase 2 – Feature Extraction

**Input:** RR intervals per window.
**Task:**

1. Compute 7 HRV features: `[sdnn, rmssd, pnn50, hr_mean, lf, hf, lf_hf]`.
2. Normalize features per subject.
   **Output:** Feature matrix (N × 7) and corresponding labels.

---

### Phase 3 – Model Training

**Input:** Feature matrix + labels.
**Procedure:**

1. Split 80/20 for training/testing.
2. Train two models:

   * **RBF‑SVM** (C = 4.0, γ = scale)
   * **Linear‑SVM** (C = 1.0)
3. Compute metrics: Accuracy, Balanced Accuracy, F1.
4. Select model with trade‑off between accuracy and model size.
   **Output:** Trained model object(s) and StandardScaler.

---

### Phase 4 – Model Export

**Task:** Convert trained model into portable JSON schema.

**Fields (required):** `type`, `feature_order`, `scaler_mean`, `scaler_scale`, `classes`, and weights/support vectors depending on model type.

**Outputs:**

* `svm_linear_v1_0.json` (production candidate)
* `svm_rbf_v1_0.json` (research candidate)

**Versioning Convention:**

* File names use semantic-style versions: `modelname_vMAJOR_MINOR.json` (e.g., `svm_linear_v1_2.json`).
* Increment **MINOR** for hyperparam tweaks or feature-order changes; **MAJOR** for label set changes or breaking schema updates.
* Maintain a `MANIFEST.json` alongside exports mapping `version → checksum → metrics`.

**Integrity & Provenance:**

* Include `model_hash` (SHA-256 of canonicalized JSON without the `model_hash` field) and `export_time_utc`.
* Optional `training_commit` (git SHA) and `data_manifest_id` for traceability.

**JSON Schema (abridged example):**

```json
{
  "type": "linear_svm",
  "version": "1.0",
  "feature_order": ["sdnn", "rmssd", "pnn50", "hr_mean", "lf", "hf", "lf_hf"],
  "scaler_mean": [0.08, 0.05, 0.12, 72.1, 1.1, 0.9, 1.2],
  "scaler_scale": [0.02, 0.02, 0.10, 8.0, 0.4, 0.3, 0.5],
  "classes": [0, 1],
  "coef": [[0.3, -0.5, 0.1, -0.02, 0.4, -0.1, 0.2]],
  "intercept": [-0.1],
  "model_hash": "<sha256-hex>",
  "export_time_utc": "2025-10-20T19:00:00Z",
  "training_commit": "<git-sha>",
  "data_manifest_id": "wesad_rr_v3"
}
```

**Acceptance Criteria:**

* JSON validates against schema and passes hash verification.
* Predictions identical (±1e-6) between Python and Dart on a 1k-sample parity set.

### Pha

**Target:** Flutter SDK.
**Task:**

1. Embed exported JSON under `assets/`.
2. Load model at runtime via model loader class.
3. Ingest RR intervals from wearable APIs.
4. Predict emotion state in real time.
   **Interfaces:**

* `EmotionModel.predictFromRR(rrList)` → returns class label.
  **Output:** Emotion classification event for UI and analytics layers.

---

## 4. AI Agent Implementation Plan

| Step | Action                            | Automation Hint                                            |
| ---- | --------------------------------- | ---------------------------------------------------------- |
| 1    | Download WESAD dataset            | Public academic source or internal cache                   |
| 2    | Parse ECG → RR intervals          | Use Pan–Tompkins or neurokit2 API                          |
| 3    | Apply HRV feature pipeline        | Run on all subjects concurrently                           |
| 4    | Train SVM models                  | Scikit‑learn with auto‑hyperparameter tuning (grid search) |
| 5    | Export JSON models                | Serialize scaler + weights                                 |
| 6    | Validate predictions              | Cross‑verify Python vs Dart output                         |
| 7    | Register JSON into Flutter assets | Update `pubspec.yaml` automatically                        |
| 8    | Generate SDK documentation        | Auto‑summarize API reference and class usage               |

---

## 5. Evaluation

| Metric            | Target                         | Description                |
| ----------------- | ------------------------------ | -------------------------- |
| Accuracy          | ≥ 80 % (RBF) / ≥ 70 % (Linear) | Test‑set accuracy          |
| Balanced Accuracy | ≥ 0.75                         | Per‑class balance          |
| Latency           | ≤ 10 ms (Linear)               | Mobile runtime performance |
| Model Size        | ≤ 1 MB                         | JSON file footprint        |

---

## 6. Deployment

**Deliverables:**

* `svm_linear.json` (production)
* `svm_rbf.json` (research)
* `emotion_model.dart` loader

**Pipeline Output Folder:**

```
exports/
  ├── svm_linear.json
  ├── svm_rbf.json
  └── metrics.json
```

**Flutter Asset Configuration:**

```yaml
flutter:
  assets:
    - assets/svm_linear.json
```

---

## 7. Privacy & Compliance

* No raw ECG or RR data transmitted externally.
* Model weights are open and reproducible.
* Local predictions only; no telemetry unless user‑approved.

---

## 8. Future Extensions

1. **Adaptive Baselines:** On‑device calibration for personalized inference.
2. **Federated Updates:** Aggregate performance metrics without sharing data.
3. **Model Distillation:** Compress RBF‑SVM to a lightweight neural approximation.
4. **Multimodal Fusion:** Combine HRV with contextual sensors for emotion clustering.

---

## 9. References

* Li, J. & Washington, P. (2023). *A Comparison of Personalized and Generalized Approaches to Emotion Recognition Using Consumer Wearable Devices.* JMIR Formative Research, 7, e44752.
* Schmidt, P. et al. (2018). *Introducing WESAD, a Multimodal Dataset for Wearable Stress and Affect Detection.* ICMI 2018.

---

**End of RFC**
