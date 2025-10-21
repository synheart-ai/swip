# RFC: On-Device Linear SVM Inference in Flutter

**Date:** October 20, 2025  
**Author:** Israel Goytom  
**Status:** Draft  
**Version:** 1.0  
**Component:** Synheart SDK — `lib/ml`  

---

## 1. Summary
This RFC defines the architecture and implementation plan for running a **Linear SVM classifier** directly on-device within a Flutter application.  
The model receives **physiological features (HR, HRV, etc.)** from the wearable SDK and outputs an emotional state (e.g., *Calm*, *Amused*, *Stressed*).  

The goal is to enable **offline, real-time inference** without depending on cloud APIs, ensuring:
- Privacy-preserving processing of biosignals  
- Real-time performance  
- Cross-platform consistency (Android/iOS)  

---

## 2. Motivation
Synheart’s mission is to measure the **wellness impact of digital experiences** through heart-based data (SWIP — Synheart Wellness Impact Protocol).  
To maintain **trust and transparency**, we need models that:
- Run locally without sending data to servers  
- Can be verified and audited (open weights)  
- Operate efficiently on wearable and mobile CPUs  

The Linear SVM trained on WESAD-like data provides a small, explainable, and efficient baseline for emotion classification.

---

## 3. Goals
✅ **Functional Goals**
- Deploy a small, pre-trained **Linear SVM (one-vs-rest)** model in Flutter.  
- Load model weights and scaling parameters from local assets.  
- Continuously stream features from the **wearable SDK** (heart rate, RR intervals).  
- Perform **real-time inference** (~1s latency).  
- Return predicted emotion + confidence to UI layer.  

🚫 **Non-Goals**
- Cloud-based inference or federated learning.  
- On-device retraining or adaptation.  
- Large models (e.g., deep learning, >5 MB weights).

---

## 4. Architecture
```
Wearable SDK → FeatureExtractor → SvmPredictor → InferenceController → UI
```

### Components

| Component | Description | Language |
|------------|--------------|----------|
| `FeatureExtractor` | Converts HR & RR time series to HRV features (SDNN, RMSSD, etc.). | Dart |
| `SvmPredictor` | Performs normalized linear SVM prediction with preloaded weights. | Dart |
| `InferenceController` | Coordinates the feature pipeline and prediction stream. | Dart |
| `model_linear_ovr.json` | Stores weights, biases, and scaler for SVM model. | JSON asset |

---

## 5. Model Specification
**Model Type:** Linear SVM (One-vs-Rest, 3 classes)  
**Classes:** Amused, Calm, Stressed  
**Input Features (example):**
1. Mean HR  
2. HR Std  
3. HR Min  
4. HR Max  
5. SDNN  
6. RMSSD  

**Equation:**
$$
\text{score}_k = \mathbf{w}_k \cdot \mathbf{x} + b_k
$$
Prediction = `argmax(score_k)`  
Optional softmax applied for normalized probabilities.

---

## 6. File Structure
```
lib/
 ├─ ml/
 │   ├─ svm_predictor.dart
 │   └─ feature_prep.dart
 ├─ services/
 │   ├─ wearable_service.dart
 │   └─ inference_controller.dart
assets/
 └─ data/
     └─ model_linear_ovr.json
```

---

## 7. Data Flow
1. **Wearable SDK** streams heart rate and RR data every second.  
2. **FeatureExtractor** buffers data (60s window, 10s hop) and computes HRV metrics.  
3. **SvmPredictor** loads model parameters from `model_linear_ovr.json`.  
4. **InferenceController** normalizes features, runs inference, and publishes a state stream.  
5. **UI** subscribes to the emotion stream and updates visuals in real-time.

---

## 8. Example Inference Output
```json
{
  "t": "2025-10-20T10:45:00Z",
  "label": "Calm",
  "probs": [0.05, 0.85, 0.10]
}
```

---

## 9. Performance Targets
| Metric | Target |
|--------|--------|
| Model size | < 50 KB |
| Inference time | < 10 ms |
| Memory footprint | < 5 MB |
| Battery impact | < 2% per hour (avg.) |

---

## 10. Security & Privacy
- All inference runs **locally**; no cloud upload of biosignals.  
- The model file (`model_linear_ovr.json`) is signed and versioned.  
- Users can opt-in for anonymized research uploads.  

---

## 11. Future Extensions
- Replace SVM with small neural net (TinyML or TensorFlow Lite).  
- Integrate with **Synheart Dashboard** for aggregated insights.  
- Multi-modal inputs (motion, GSR, cognitive performance).  
- Model compression + quantization for ultra-low power wearables.  

---

## 12. References
- WESAD Dataset (Wearable Stress and Affect Detection): <https://ubicomp.eti.uni-siegen.de/home/datasets/wesad/>  
- Chang & Lin (2011): LIBSVM: A Library for Support Vector Machines.  
- Li & Washington (2023): A Comparison of Personalized and Generalized Approaches to
Emotion Recognition Using Consumer Wearable Devices: Machine
Learning Study 
- Synheart AI — SWIP SDK RFC 1.0  

---

## 13. Appendix: Example JSON
```json
{
  "type": "linear_ovr",
  "classes": ["Amused", "Calm", "Stressed"],
  "scaler": {
    "mean": [0.5, 1.2, 0.3, 0.4, 50.2, 35.6],
    "std":  [0.1, 0.2, 0.05, 0.1, 10.0, 8.0]
  },
  "weights": [
    [0.12, -0.33, 0.08, -0.19, 0.5, 0.3],
    [-0.21, 0.55, -0.07, 0.1, -0.4, -0.3],
    [0.02, -0.12, 0.1, 0.05, 0.2, 0.1]
  ],
  "bias": [-0.2, 0.3, 0.1]
}
```
