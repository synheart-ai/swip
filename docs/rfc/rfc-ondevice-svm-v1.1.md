# RFC: On-Device Linear SVM Inference in Flutter (v1.1)

**Date:** October 21, 2025  
**Author:** Israel Goytom  
**Status:** Draft  
**Version:** 1.1  
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
Wearable SDK → FeatureExtractor → InferenceController → SvmPredictor → UI
```

### Components

| Component | Description | Language |
|------------|--------------|----------|
| `FeatureExtractor` | Converts HR & RR time series to HRV features (SDNN, RMSSD, etc.). | Dart |
| `InferenceController` | Normalizes features, triggers prediction, and emits state updates. | Dart |
| `SvmPredictor` | Performs normalized linear SVM prediction with preloaded weights. | Dart |
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
\text{score}_k = \mathbf{w}_k \cdot \left(\frac{\mathbf{x} - \mu}{\sigma}\right) + b_k
$$
Prediction = `argmax(score_k)`  
Optional softmax applied for normalized probabilities.

### Normalization Handling
Normalization is applied **inside** `SvmPredictor.predictRaw()` before computing the dot product.  
- Input features from `FeatureExtractor` are *raw* physiological values.  
- The predictor applies z-score normalization using the scaler (mean, std) stored in `model_linear_ovr.json`.  

This ensures consistent preprocessing across devices and versions.

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
3. **InferenceController** collects feature vectors, sends them to `SvmPredictor` for normalization + inference.  
4. **SvmPredictor** computes class scores and returns probabilities and label.  
5. **UI** subscribes to the emotion stream and updates visuals in real-time (new prediction every ~10s).

### Note on Temporal Resolution
The chosen **60s sliding window** with **10s hop** means that predictions update every **10 seconds**.  
Although inference itself is instantaneous (<10 ms), the physiological signal requires sufficient data to compute HRV metrics reliably.

---

## 8. Example Inference Output
```json
{
  "t": "2025-10-21T10:45:00Z",
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
| Update interval | Every 10 s |
| Battery impact | < 2% per hour (avg.) |

---

## 10. Floating Point Precision
All math operations use Dart’s `double` (IEEE 754 64-bit floating point).  
Empirical testing on Android (ARM64) and iOS (A15 chip) shows negligible variance (<1e−9) in dot product results.  
For audit consistency:
- Store model weights and scalers as float64 JSON numbers.  
- Apply normalization in the same order as during training.  

---

## 11. Security & Privacy
- All inference runs **locally**; no cloud upload of biosignals.  
- The model file (`model_linear_ovr.json`) is signed and versioned.  
- Users can opt-in for anonymized research uploads.  

---

## 12. Future Extensions
- Replace SVM with small neural net (TinyML or TensorFlow Lite).  
- Integrate with **Synheart Dashboard** for aggregated insights.  
- Multi-modal inputs (motion, GSR, cognitive performance).  
- Model compression + quantization for ultra-low power wearables.  

---

## 13. References
- WESAD Dataset (Wearable Stress and Affect Detection): <https://ubicomp.eti.uni-siegen.de/home/datasets/wesad/>  
- Chang & Lin (2011): LIBSVM: A Library for Support Vector Machines.  
- Synheart AI — SWIP SDK RFC 1.0  

---

## 14. Appendix: Example JSON
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
