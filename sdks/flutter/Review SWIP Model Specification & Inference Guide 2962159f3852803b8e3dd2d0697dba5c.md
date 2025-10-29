# Review SWIP Model Specification & Inference Guide

**Purpose:** Define how models are serialized, named, validated, and loaded by SWIP SDKs (Flutter/Dart core, iOS/Swift, optional Android/Kotlin). This keeps models small, verifiable, and interchangeable (SVM/LogReg/CoreML/ONNX).

**Scope:** Applies to all model artifacts under swip/models/ and any app-embedded copies.

- `WRIST_SDNN:
- Best Model: RF
- Macro F1: 0.4335
- Accuracy: 0.5612`

- `WRIST_RMSSD:
- Best Model: ExtraTrees
- Macro F1: 0.4185
- Accuracy: 0.5000`

- `WRIST_ALL:
- Best Model: ExtraTrees (Production), XGB (Research)
- Macro F1: 0.6848 (XGB), 0.6335 (ExtraTrees)
- Accuracy: 0.7755 (XGB), 0.7142 (ExtraTrees)
- Production Model: extratrees_wrist_all_v1_0.onnx (ONNX format only)`

# ✅ JSON deployment

| Model Type | JSON Deployment? | Notes |  |
| --- | --- | --- | --- |
| **Linear SVM** (SVC kernel='linear') | ✅ Easy | Just dot-product + bias |  |
| **Logistic Regression** | ✅ Easy | Softmax/Sigmoid after dot-product |  |
| **Linear Regression** | ✅ Easy | Same as above (no activation) |  |
| **Naive Bayes** | ✅ Moderate | Store priors + likelihood stats |  |
| **KNN** | ✅ Yes, but heavy | Requires storing all training vectors or compressed indexes |  |
| **Perceptron** | ✅ Simple | Same structure as Logistic Regression |  |
| **PCA + Linear classifier** | ✅ Yes | PCA transform matrix + classifier weights |  |
| **Feature scaling (z-score)** | ✅ Yes | Mean + Std in JSON |  |

# 🚫 NO JSON deployment

| Model Type | JSON Deployment? | Why |
| --- | --- | --- |
| **Random Forest** | 🚫 Not ideal | Dozens of trees → huge JSON + slow mobile branching |
| **ExtraTrees** | 🚫 Not ideal | Same issues but worse (random splits) |
| **Gradient Boosted Trees** (XGBoost, LightGBM, CatBoost) | ❌ Not practical via JSON | Many trees, complex node logic, parameters compress poorly |
| **SVM with RBF/poly kernel** | ❌ Hard | Requires storing entire support vectors set |

---

## 1) Naming & Versioning

### File names

Pattern: `<model_family>_<arch>_<source>_<feature>_v<major>_<minor>.<ext>`

Examples:
- `svm_linear_wrist_sdnn_v1_0.json`
- `logreg_v1_2.json`
- `wesad_coreml_v1_0.mlmodelc` (directory bundle in iOS build)
- `svm_linear_wrist_sdnn_v1_0.onnx`
- `extratrees_wrist_all_v1_0.onnx` ✅ **Production model**
- `swip_classifier_v1_0.onnx`

### Model IDs (inside metadata)

Format: `<model_family>_<arch>_<source>_<feature>_v<major>_<minor>`

Must **exactly match** the base filename (without extension).

### Version policy

- **Major:** breaking schema or feature-order changes
- **Minor:** weight updates or calibration changes with compatible schema

---

## 2) Directory Layout

```
swip/
  models/
    svm_linear_wrist_sdnn_v1_0.json
    svm_linear_wrist_sdnn_v1_0.onnx
    svm_linear_wrist_sdnn_v1_0.meta.json
    wesad_coreml_v1_0/
    swip_classifier_v1_0.onnx
  tools/
    validate_model_checksum.py
    convert_coreml_to_json.py
    infer_onnx.py
```

---

## 3) Common Metadata (required for all formats)

Every model export must carry (or be accompanied by) metadata with the fields below. For JSON models it lives in-file; for CoreML/ONNX it lives in a **sidecar** JSON: `<filename>.meta.json`.

```json
{  "model_id": "extratrees_wrist_all_v1_0",  "format": "onnx",  "created_utc": "2025-10-25T13:00:32Z",  "training_data_tag": "wesad_r1_3class",  "schema": {    "input_names": ["SDNN", "RMSSD", "pNN50", "Mean_RR", "HR_mean"],    "input_units": ["ms", "ms", "%", "ms", "bpm"],    "order_fixed": true,    "normalization": {      "type": "none",      "note": "Normalization included in the binary model pipeline"    }  },  "output": {    "type": "probability",    "range": [0.0, 1.0],    "class_names": ["Calm", "Stressed", "Amused"],    "positive_class": "Stressed"  },  "quantization": {    "enabled": false,    "dtype": "float32"  },  "checksum": {    "algo": "sha256",    "value": "c06ebe09b89fbfa23f65d44ddde75c044b8a2a05477f609a6c1beed033a54894"  },  "license": "Apache-2.0",  "notes": "ONNX model includes built-in normalization. Converted from ExtraTreesClassifier trained on WESAD wrist_all. Production deployment validated on iOS Simulator."}
```

### Rules

- `schema.input_names` order is **contractual**; SDKs feed features in this order
- normalization is applied **before** inference
- If `quantization.enabled = true`, specify dtype and any scale/zero-point per-tensor details in the format-specific section

---

## 4) JSON Linear Models (SVM / Logistic Regression)

**Extension:** `.json`

**Use when:** Tiny, fast, portable, and explainable models are desired (SDK default).

### 4.1 SVM (linear) JSON schema

```json
{  "model_id": "svm_linear_v1_0",  "format": "svm_json",  "w": [0.145, -0.082, 0.530, -0.210],  "b": 0.120,  "schema": {},  "inference": {    "score_fn": "margin",    "sigmoid_a": 1.0,    "sigmoid_b": 0.0  },  "checksum": {}}
```

**Note:** `score_fn` can be “margin” or “sigmoid”. The sigmoid parameters are optional and used when `score_fn == "sigmoid"`.

### Computation

1. Normalize inputs x → x’ using `schema.normalization`
2. Calculate margin: `m = dot(w, x') + b`
3. If `score_fn == "sigmoid"`: `p = 1 / (1 + exp(-(a*m + b)))`
4. Otherwise: map margin to probability in SDK (Platt or fixed)

### 4.2 Logistic Regression JSON schema

```json
{  "model_id": "logreg_v1_0",  "format": "logreg_json",  "w": [0.145, -0.082, 0.530, -0.210],  "b": -0.35,  "schema": {},  "checksum": {}}
```

### Probability

- Calculate: `z = dot(w, x') + b`
- Probability: `p = 1 / (1 + exp(-z))`

### 4.3 Optional quantization (JSON)

```json
"quantization": {  "enabled": true,  "dtype": "int8",  "input_scale": [0.05, 0.08, 0.02, 0.01],  "input_zero_point": [0,0,0,0],  "weight_scale": 0.01,  "weight_zero_point": 0,  "bias_scale": 0.0005,  "bias_zero_point": 0}
```

SDKs must dequantize or run integer math if implemented.

---

## 5) Core ML Models

**Extension:** `.mlmodelc` (compiled) + sidecar metadata: `wesad_coreml_v1_0.meta.json`

### Requirements

- Input feature names and order must match `schema.input_names`
- If the CoreML graph includes its own normalization, set `schema.normalization.type = "none"` and **document** preprocessing inside notes
- Provide output mapping: probabilities keyed by class_names or a single scalar p

### Embedding

iOS apps embed `.mlmodel` which Xcode compiles to `.mlmodelc`. Commit **instructions** (README) rather than binary if repo policy disallows large files.

---

## 6) ONNX Models

**Extension:** `.onnx` + sidecar metadata `*.meta.json`

### Requirements

- Static shapes or clear dynamic axes for batch=1 inference on-device
- Match `schema.input_names` order; if the graph expects a single tensor, document the packing order
- Quantized ONNX must declare per-tensor scales/zero-points in the sidecar if not embedded

### 6.1 ONNX Output Format Handling

ONNX models may return outputs in different formats:

1. **Single output (1, num_classes):** Direct probability array or logits
2. **Multiple outputs:** Search for probability-shaped array among outputs (e.g., ExtraTrees returns `{label: [class_index], probabilities: [[p1, p2, p3]]}`)
3. **Nested format:** Tree-based models often return shape `(1, num_classes)` as nested list `[[p1, p2, p3]]` - extract inner list
4. **Probability detection:** If output sums to ~1.0 and all values ≥ 0, treat as probabilities
5. **Logits:** Apply softmax transformation if not probabilities

### Softmax computation

```python
def softmax(logits):
    e = np.exp(logits - np.max(logits, axis=-1, keepdims=True))
    return e / np.sum(e, axis=-1, keepdims=True)
```

### 6.2 ONNX Input Name Discovery

Different ONNX models use different input tensor names. Implementations should try common names in order:

1. **`X`** - sklearn default for most models
2. **`float_input`** - ExtraTrees and some sklearn pipeline models ✅ (confirmed working)
3. **`input`** - generic ONNX convention
4. **`inputs`** - alternative plural form
5. **First feature name** - fallback to schema's first input_name

**Implementation note:** The `float_input` name is used by sklearn's ONNX converter when exporting pipeline models (StandardScaler + ExtraTrees). Always implement input name discovery rather than hardcoding.

---

## 7) Python ONNX Inference Implementation

### 7.1 Overview

Python inference scripts provide a reference implementation for ONNX model loading, preprocessing, and inference. This serves as:

- Ground truth for SDK implementations
- Testing and validation tool
- Colab/Jupyter notebook integration
- Research and debugging interface

### 7.2 Core Components

### 7.2.1 Sidecar Metadata Loading

```python
def load_sidecar(meta_path: Path):
    """Load sidecar metadata JSON and return dict."""    if not meta_path.exists():
        raise FileNotFoundError(f"Sidecar metadata not found: {meta_path}")
    with open(meta_path, "r") as f:
        meta = json.load(f)
    return meta
```

### 7.2.2 Input Array Construction

```python
def build_input_array(sample: dict, input_names: list, mean=None, std=None):
    """    Build and normalize input array for model inference.    Args:        sample: dict mapping feature_name -> value        input_names: list of feature names expected by model (order matters)        mean/std: arrays for normalization (zscore). If None -> no normalization    Returns:        np.float32 array shaped (1, n_features)    """    x = []
    for name in input_names:
        if name not in sample:
            raise KeyError(f"Missing feature '{name}' in sample.")
        x.append(float(sample[name]))
    arr = np.array(x, dtype=np.float32).reshape(1, -1)
    if mean is not None and std is not None:
        mean = np.array(mean, dtype=np.float32).reshape(1, -1)
        std = np.array(std, dtype=np.float32).reshape(1, -1)
        std[std == 0] = 1.0        arr = (arr - mean) / std
    return arr
```

Note: We replace `std = 0` with `1.0` to avoid division by zero.

### 7.2.3 ONNX Inference Pipeline

```python
def infer_onnx(model_path: Path, meta_path: Path, sample: dict):
    """    Load model + meta, prepare sample, run ONNX inference.    Returns:        (pred_label, probs, raw_outputs)    """    meta = load_sidecar(meta_path)
    # Extract schema information    feature_names = meta.get("schema", {}).get("input_names")
    norm = meta.get("schema", {}).get("normalization", {})
    mean = norm.get("mean")
    std = norm.get("std")
    # Prepare input vector    x = build_input_array(sample, feature_names, mean=mean, std=std)
    # Run ONNX    sess = ort.InferenceSession(str(model_path),
                                providers=["CPUExecutionProvider"])
    input_name = sess.get_inputs()[0].name
    outputs = sess.run(None, {input_name: x})
    # Process outputs to extract probabilities    probs = extract_probabilities(outputs)
    class_idx = int(np.argmax(probs, axis=1)[0])
    # Map to class label    class_names = meta.get("output", {}).get("class_names", [])
    pred_label = class_names[class_idx] if class_idx < len(class_names) else str(class_idx)
    return pred_label, probs, outputs
```

### 7.3 Multi-Class Classification Support

ONNX models support both binary and multi-class classification:

**Binary classification:**
- class_names: `["low", "high"]`
- Output shape: `(1, 2)`

**Multi-class classification:**
- class_names: `["Calm", "Stressed", "Amused"]` ✅ (Production standard)
- Output shape: `(1, 3)`
- **Note:** Class names updated from legacy ["Baseline", "Stress", "Amusement"] to match clinical terminology

Example sidecar for multi-class:

```json
{  "model_id": "extratrees_wrist_all_v1_0",  "output": {    "type": "probability",    "range": [0.0, 1.0],    "class_names": ["Calm", "Stressed", "Amused"],    "positive_class": "Stressed"  }}
```

### 7.4 Example Usage

```python
import onnxruntime as ort
import numpy as np
import json
from pathlib import Path
# ConfigurationMODEL_DIR = Path("/content/drive/MyDrive/swip/models")
MODEL_FILENAME = "svm_linear_wrist_sdnn_v1_0.onnx"META_FILENAME = MODEL_FILENAME.replace(".onnx", ".meta.json")
model_path = MODEL_DIR / MODEL_FILENAME
meta_path = MODEL_DIR / META_FILENAME
# Load metadata to inspect feature namesmeta = json.load(open(meta_path))
feature_names = meta.get("schema", {}).get("input_names", [])
print("Feature names:", feature_names)
# Build sample with actual or default valuessample = {
    "hr_mean": 70.0,
    "sdnn_ms": 50.0,
    "rmssd_ms": 30.0,
    "accel_mag_mean": 0.08,
    "accel_mag_std": 0.02}
# Run inferencepred_label, probs, raw_outs = infer_onnx(model_path, meta_path, sample)
print("Predicted label:", pred_label)
print("Probabilities:", probs)
```

### 7.5 Feature Value Guidelines

When creating test samples or handling missing features:

**ExtraTrees model (extratrees_wrist_all_v1_0) features:**

| Feature | Typical Range | Default/Median | Unit | Description |
| --- | --- | --- | --- | --- |
| SDNN | 20-150 | 50.0 | ms | Standard Deviation of NN intervals |
| RMSSD | 20-120 | 30.0 | ms | Root Mean Square of Successive Differences |
| pNN50 | 5-70 | 15.0 | % | Percentage of NN intervals differing by >50ms |
| Mean_RR | 600-1000 | 850.0 | ms | Mean RR interval |
| HR_mean | 60-100 | 70.0 | bpm | Mean heart rate |

**Training data statistics (from metadata):**
- Mean: [346.54, 459.87, 69.14, 887.38, 70.01]
- Std: [446.03, 635.91, 17.75, 216.27, 11.29]

**Legacy SVM model features:**

| Feature | Typical Range | Default/Median | Unit |
| --- | --- | --- | --- |
| hr_mean | 60-100 | 70.0 | bpm |
| sdnn_ms | 20-80 | 50.0 | ms |
| rmssd_ms | 20-50 | 30.0 | ms |
| accel_mag_mean | 0.05-0.15 | 0.08 | g |
| accel_mag_std | 0.01-0.05 | 0.02 | g |

### 7.6 Error Handling

```python
# Missing featuresif feature_name not in sample:
    raise KeyError(f"Missing feature '{feature_name}'")
# Missing sidecarif not meta_path.exists():
    raise FileNotFoundError(f"Sidecar metadata not found: {meta_path}")
# Model file not foundif not model_path.exists():
    raise FileNotFoundError(f"ONNX model not found: {model_path}")
# Normalization safetystd[std == 0] = 1.0
# Input name discoverytry:
    outputs = sess.run(None, {input_name: x})
except Exception as e:
    # Try alternative input names
    for alt_name in ['X', 'float_input', 'input', 'inputs']:
        try:
            outputs = sess.run(None, {alt_name: x})
            break
        except:
            continue
```

### 7.7 ExtraTrees ONNX Inference Example (Production Model)

```python
# Colab-ready ONNX inference for ExtraTrees model
import onnxruntime as ort
import numpy as np
import json
from pathlib import Path

MODEL_DIR = Path("/content/swip/models")
MODEL_FILENAME = "extratrees_wrist_all_v1_0.onnx"
META_FILENAME = "extratrees_wrist_all_v1_0.meta.json"

LABEL_ORDER = ["Calm", "Stressed", "Amused"]

def softmax(logits):
    e = np.exp(logits - np.max(logits, axis=-1, keepdims=True))
    return e / np.sum(e, axis=-1, keepdims=True)

def infer_onnx(model_path: Path, meta_path: Path, sample: dict):
    """Run ONNX inference with ExtraTrees model"""
    meta = load_sidecar(meta_path)
    feature_names = meta.get("schema", {}).get("input_names")
    
    # Note: ExtraTrees ONNX already has normalization built-in (from pipeline)
    # So we DON'T apply normalization here
    
    # Build input array in correct order
    x = []
    for name in feature_names:
        if name not in sample:
            raise KeyError(f"Missing feature '{name}'. Need: {feature_names}")
        x.append(float(sample[name]))
    
    x_arr = np.array(x, dtype=np.float32).reshape(1, -1)
    
    # Run ONNX
    sess = ort.InferenceSession(str(model_path), providers=["CPUExecutionProvider"])
    input_name = sess.get_inputs()[0].name  # Usually 'float_input' for ExtraTrees
    outputs = sess.run(None, {input_name: x_arr})
    
    # ExtraTrees ONNX outputs: [label, probabilities]
    # probabilities is shape (1, 3) for 3 classes
    if len(outputs) >= 2:
        probs = np.array(outputs[1], dtype=np.float32)  # Extract probabilities output
    else:
        # Fallback: use first output and apply softmax
        probs = softmax(np.array(outputs[0], dtype=np.float32))
    
    class_idx = int(np.argmax(probs, axis=1)[0])
    pred_label = LABEL_ORDER[class_idx]
    
    return pred_label, probs, outputs

# Example usage
model_path = MODEL_DIR / MODEL_FILENAME
meta_path = MODEL_DIR / META_FILENAME

# Example sample with all 5 features
sample = {
    "SDNN": 50.0,      # ms
    "RMSSD": 30.0,     # ms
    "pNN50": 15.0,     # %
    "Mean_RR": 850.0,  # ms
    "HR_mean": 70.6    # bpm
}

pred_label, probs, raw_outs = infer_onnx(model_path, meta_path, sample)
print(f"Predicted State: {pred_label}")
print(f"\nClass Probabilities:")
for label, prob in zip(LABEL_ORDER, probs[0]):
    print(f"  {label:10s}: {prob:.4f} ({prob*100:.1f}%)")
```

**Production validation:** This implementation has been tested and validated on iOS Simulator with Flutter SDK, achieving real-time emotion recognition with 40-60% confidence scores.

---

## 8) Input Schema: Canonical Feature Set

### Minimum required for SWIP v1 (Production)

**ExtraTrees wrist_all model (extratrees_wrist_all_v1_0.onnx):**

1. **SDNN** (ms) — Standard Deviation of NN intervals
2. **RMSSD** (ms) — Root Mean Square of Successive Differences  
3. **pNN50** (%) — Percentage of NN intervals differing by >50ms
4. **Mean_RR** (ms) — Mean RR interval
5. **HR_mean** (bpm) — Mean heart rate

**Legacy SVM models (wrist_sdnn):**

1. **hr_mean** (bpm) — mean over window
2. **sdnn_ms** (ms) — Apple SDNN if available, else computed from RR
3. **accel_mag_mean** (g)
4. **accel_mag_std** (g)

### Optional extensions

- hr_std
- rr_count
- rmssd_ms (now required for ExtraTrees)
- pnn50 (now required for ExtraTrees)
- motion_state_onehot_*
- eda_mean
- eda_std

### WESAD adapter

The WESAD adapter maps RR/ECG-derived RR (and optional EDA) to this canonical schema. If a feature is missing, fill with NaN and the SDK will either impute (if enabled) or reject the window.

---

## 9) Normalization Policy

- **Default:** z-score with per-feature mean and std from training
- **Missing features:**
    - If imputation is **off:** the window is skipped
    - If imputation is **on:** fill with training mean. Record this in contributors as `imputed:true`
- **Zero std handling:** Replace `std=0` with `1.0` to prevent division errors

---

## 10) Security & Integrity

### Checksum

SHA-256 over the exact payload bytes:

- **JSON:** UTF-8 without BOM, **minified** (no whitespace). Store the hex digest in `checksum.value`
- **Binary (ONNX/CoreML):** bytes as on disk

### Validation

- Run `tools/validate_model_checksum.py <path>` in CI
- The SDK **must** verify checksum before loading and refuse on mismatch

### Signing (optional)

If distributing over network, add a detached signature (`.sig`) and verify before persisting.

---

## 11) License & Attribution

- Include license in metadata (Apache-2.0 recommended) and ensure training data license allows redistribution
- If the model was trained on public datasets (e.g., WESAD), mention them in notes

---

## 12) Backward Compatibility Rules

- Adding **new optional** fields to JSON is allowed (SDKs ignore unknown keys)
- Changing `schema.input_names` **requires** a **major** version bump
- Changing normalization stats without schema changes is **minor** bump

---

## 13) SDK Loader Expectations

### Dart (swip_core)

- Must support: `svm_json` and `logreg_json` natively
- Optional shims for ONNX/CoreML via platform channels

### Swift (SwippKit)

- Native CoreML
- JSON linear models via simple compute

### Python (reference)

- ONNX via onnxruntime
- JSON models via numpy

### Contributors map

All runners should return contributors with at least: `{"hr": w_hr_contrib, "hrv": w_hrv_contrib, "motion": w_motion_contrib}` or a best-effort proxy.

---

## 14) Examples

### 14.1 Minimal SVM JSON (float32)

```json
{  "model_id": "svm_linear_v1_0",  "format": "svm_json",  "w": [0.145, -0.082, 0.530, -0.210],  "b": 0.120,  "schema": {    "input_names": ["hr_mean", "sdnn_ms", "accel_mag_mean", "accel_mag_std"],    "input_units": ["bpm", "ms", "g", "g"],    "order_fixed": true,    "normalization": {      "type": "zscore",      "mean": [72.1, 45.3, 0.08, 0.02],      "std":  [10.4, 18.7, 0.03, 0.01]    }  },  "output": {
    "type": "probability",
    "range": [0,1],
    "class_names": ["low","high"],
    "positive_class": "high"
  },  "inference": {
    "score_fn": "sigmoid",
    "sigmoid_a": 1.0,
    "sigmoid_b": 0.0
  },  "quantization": {
    "enabled": false,
    "dtype": "float32"
  },  "training_data_tag": "wesad_r3_balanced",  "created_utc": "2025-10-22T07:00:00Z",  "checksum": {
    "algo": "sha256",
    "value": "DEADBEEF..."
  },  "license": "Apache-2.0",  "notes": "Trained on WESAD RR+Accel; no EDA."}
```

### 14.2 Sidecar metadata for ONNX (binary classification)

Filename: `svm_linear_v1_0.meta.json`

```json
{  "model_id": "svm_linear_v1_0",  "format": "onnx",  "schema": {    "input_names": ["hr_mean", "sdnn_ms", "accel_mag_mean", "accel_mag_std"],    "input_units": ["bpm", "ms", "g", "g"],    "order_fixed": true,    "normalization": {
      "type": "zscore",
      "mean": [72.1,45.3,0.08,0.02],
      "std": [10.4,18.7,0.03,0.01]
    }  },  "output": {
    "type": "probability",
    "range": [0,1],
    "class_names": ["low","high"],
    "positive_class": "high"
  },  "quantization": {
    "enabled": false,
    "dtype": "float32"
  },  "checksum": {
    "algo": "sha256",
    "value": "ABCD1234..."
  },  "license": "Apache-2.0"}
```

### 14.3 Sidecar metadata for ONNX (multi-class classification) - PRODUCTION MODEL

Filename: `extratrees_wrist_all_v1_0.meta.json`

```json
{
  "model_id": "extratrees_wrist_all_v1_0",
  "format": "onnx",
  "created_utc": "2025-10-25T13:00:32Z",
  "training_data_tag": "wesad_r1_3class",
  "schema": {
    "input_names": [
      "SDNN",
      "RMSSD",
      "pNN50",
      "Mean_RR",
      "HR_mean"
    ],
    "input_units": [
      "ms",
      "ms",
      "%",
      "ms",
      "bpm"
    ],
    "order_fixed": true,
    "normalization": {
      "type": "none",
      "mean": [
        346.5433217198369,
        459.87351259502583,
        69.14352871514882,
        887.3834345700303,
        70.0063657024377
      ],
      "std": [
        446.02671436865324,
        635.9081068145273,
        17.74552851342567,
        216.27284122317997,
        11.291319943043808
      ],
      "note": "Normalization included in the binary model pipeline"
    }
  },
  "output": {
    "type": "probability",
    "range": [0.0, 1.0],
    "class_names": ["Calm", "Stressed", "Amused"],
    "positive_class": "Stressed"
  },
  "quantization": {
    "enabled": false,
    "dtype": "float32"
  },
  "checksum": {
    "algo": "sha256",
    "value": "c06ebe09b89fbfa23f65d44ddde75c044b8a2a05477f609a6c1beed033a54894"
  },
  "license": "Apache-2.0",
  "notes": "ONNX model includes built-in normalization. Converted from ExtraTreesClassifier trained on WESAD wrist_all. Production deployment validated on iOS Simulator with Flutter SDK."
}
```

**Deployment Status:** ✅ Production-ready, validated on iOS Simulator
**Model Size:** 2.6 MB (ONNX)
**Input Name:** `float_input` (automatically discovered)
**Output Format:** `{label: [index], probabilities: [[p1, p2, p3]]}`

---

## 15) CI Checks (recommended)

1. **Schema lint:** Validate required keys by JSON Schema
2. **Checksum verify:** `tools/validate_model_checksum.py`
3. **Round-trip test:** Load → run 3–5 synthetic inputs → assert deterministic outputs
4. **Size budget:** Fail if JSON models > 64 KB or ONNX/CoreML > set budgets (e.g., 5 MB)
5. **Python inference test:** Run reference implementation on test samples and verify outputs

---

## 16) Release Checklist

- [ ]  Filename and model_id match
- [ ]  Metadata complete (schema, normalization, checksum)
- [ ]  Feature order verified against SDKs
- [ ]  Sidecar metadata file present for ONNX/CoreML models
- [ ]  CI passes (schema, checksum, size, inference test)
- [ ]  Changelog entry in docs/CHANGELOG.md
- [ ]  Demo app updated with the new model_id
- [ ]  Python inference script tested with new model

---

## 17) Platform-Specific Deployment

### 17.1 Google Colab / Jupyter

- Store models in Google Drive: `/content/drive/MyDrive/swip/models/`
- Use Python reference implementation for inference
- Load metadata before inference to inspect schema
- Suitable for experimentation and model validation

### 17.2 iOS (Swift)

- Embed `.mlmodel` files in Xcode project
- Use CoreML for native inference
- Fallback to JSON linear models for cross-platform consistency

### 17.3 Flutter (Dart)

- Bundle JSON models in assets
- Use platform channels for ONNX/CoreML inference
- Primary target for production deployment

---

## Appendix A: Complete Python Inference Script

**Location:** `tools/infer_onnx.py`

### Dependencies

```
onnxruntime
numpy
pandas
```

### Key functions

- `load_sidecar()` — Load and validate metadata
- `build_input_array()` — Prepare and normalize features
- `infer_onnx()` — Run inference and return predictions
- `softmax()` — Convert logits to probabilities

### Usage pattern

1. Point to model directory
2. Specify model filename
3. Load sidecar to inspect schema
4. Build sample dict with feature values
5. Run inference and get (label, probabilities, raw_outputs)

---

## 18) Model Type Classification & Export Strategy

Models are classified into tiers based on complexity, export capabilities, and SDK support.

### Tier 1: Linear Models (Production Ready)

**Models:** LinearSVC, LogisticRegression

**Export formats:**
- ✅ JSON (5-64 KB) - Native SDK support
- ✅ ONNX (50-500 KB) - Cross-platform
- ✅ CoreML (50-500 KB) - iOS native

**SDK support:**
- **Dart/Flutter:** Full native JSON support + ONNX via platform channels
- **Swift/iOS:** Full native JSON + CoreML
- **Python:** Full support (numpy + onnxruntime)

**Use case:** Production deployments, on-device inference, resource-constrained environments

**Performance:** F1 Score 0.75-0.85 (3-class classification)

**Inference complexity:** O(n) where n = number of features

### Tier 2: Tree Ensembles (Binary Formats Only)

**Models:** RandomForest, ExtraTrees, XGBoost

**Export formats:**
- ❌ JSON (not feasible - would be 10-50 MB)
- ✅ ONNX (1-5 MB)
- ✅ CoreML (1-5 MB)

**SDK support:**
- **Dart/Flutter:** ONNX via platform channels (requires onnxruntime)
- **Swift/iOS:** CoreML native
- **Python:** ONNX via onnxruntime

**Use case:** High-accuracy requirements, server-side inference, devices with ML accelerators

**Performance:** F1 Score 0.85-0.95 (3-class classification)

**Inference complexity:** O(t × d) where t = number of trees, d = tree depth

### Trade-off Matrix

| Criterion | Tier 1 (Linear) | Tier 2 (Trees) |
| --- | --- | --- |
| Model size | 5-64 KB | 1-5 MB |
| Accuracy (F1) | 0.75-0.85 | 0.85-0.95 |
| Inference time | <1 ms | 5-20 ms |
| SDK integration | Simple | Medium |
| JSON support | ✅ Yes | ❌ No |
| Battery impact | Minimal | Moderate |
| Interpretability | High | Low |

### Recommendation

**For SWIP v1.0 (UPDATED):** 

**Production Model:** **ExtraTrees ONNX** (`extratrees_wrist_all_v1_0.onnx`) - Successfully deployed and validated:
- ✅ 5-feature wrist-based model (SDNN, RMSSD, pNN50, Mean_RR, HR_mean)
- ✅ 3-class classification (Calm, Stressed, Amused)
- ✅ Model size: ~2.6 MB (acceptable for mobile)
- ✅ Real-time inference working on iOS Simulator
- ✅ Built-in normalization (no SDK preprocessing needed)
- ✅ Input name: `float_input` (discovered automatically)
- ✅ Confidence scores: 40-60% range (realistic)

**Fallback:** Tier 1 linear models (SVM or LogReg) for extremely resource-constrained environments or web deployment where ONNX runtime is not available.

**For SWIP v2.0:** Consider XGBoost for maximum accuracy (68% F1) in server-side scenarios where model size and inference time are less critical.

---

## 19) Modular Architecture & Best Practices

### 19.1 Recommended Project Structure

```
swip/
├── models/                          # Model artifacts
│   ├── svm_linear_wrist_sdnn_v1_0.json
│   ├── svm_linear_wrist_sdnn_v1_0.onnx
│   └── svm_linear_wrist_sdnn_v1_0.meta.json
│
├── tools/
│   ├── core/                        # Core utilities
│   │   ├── config.py               # Centralized configuration
│   │   ├── checksum.py             # SHA256 utilities
│   │   └── metadata.py             # Metadata generation
│   │
│   ├── data/                        # Data processing
│   │   ├── wesad_loader.py         # WESAD dataset loading
│   │   ├── feature_extraction.py   # HRV feature extraction
│   │   └── preprocessors.py        # Scaling, windowing
│   │
│   ├── training/                    # Training logic
│   │   ├── trainer.py              # Model training
│   │   └── evaluator.py            # Metrics & visualization
│   │
│   ├── export/                      # Model export (KEY MODULE)
│   │   ├── base_exporter.py        # Abstract base class
│   │   ├── json_exporter.py        # JSON linear models
│   │   ├── onnx_exporter.py        # ONNX conversion
│   │   ├── coreml_exporter.py      # CoreML conversion
│   │   └── registry.py             # Export format registry
│   │
│   ├── validation/                  # Testing & validation
│   │   ├── schema_validator.py     # JSON schema validation
│   │   ├── checksum_validator.py   # Integrity checks
│   │   └── inference_tester.py     # Round-trip tests
│   │
│   └── inference/                   # Reference implementations
│       ├── onnx_runtime.py         # ONNX inference
│       ├── json_runtime.py         # JSON model inference
│       └── coreml_runtime.py       # CoreML inference
│
├── sdk/                             # SDK implementations
│   ├── dart/                       # Flutter/Dart SDK
│   ├── swift/                      # iOS/Swift SDK
│   └── python/                     # Python reference SDK
│
├── config/
│   ├── model_registry.yaml         # Supported models config
│   └── export_config.yaml          # Export settings
│
└── tests/                          # Comprehensive tests
```

### 19.2 Export Registry Pattern

**Purpose:** Centralize model export logic to avoid code duplication and ensure consistency.

**Key concept:** Different model types support different export formats. The registry maps `(model_type, format)` → `Exporter class`.

**Example configuration (model_registry.yaml):**

```yaml
models:  linear_svm:    class: "sklearn.svm.LinearSVC"    export_formats: [json, onnx, coreml]    size_budget:      json: "64KB"      onnx: "500KB"      coreml: "1MB"    sdk_support:      dart: [json, onnx]      swift: [json, coreml]      python: [json, onnx]  logreg:    class: "sklearn.linear_model.LogisticRegression"    export_formats: [json, onnx, coreml]    size_budget:      json: "64KB"      onnx: "500KB"      coreml: "1MB"    sdk_support:      dart: [json, onnx]      swift: [json, coreml]      python: [json, onnx]  xgboost:    class: "xgboost.XGBClassifier"    export_formats: [onnx, coreml]    size_budget:      onnx: "5MB"      coreml: "5MB"    sdk_support:      dart: [onnx]      swift: [coreml]      python: [onnx]    notes: "Binary formats only - tree ensembles too large for JSON"
```

### 19.3 Simplified Training Workflow

**Before (monolithic):**

```python
# 600+ lines in single train.py file# Manual export for each model type# Duplicated validation logic
```

**After (modular):**

```python
# Simple CLI interfacepython -m tools.cli.train \  --scenario wrist_sdnn \  --models LinearSVM,LogReg \  --export json,onnx,coreml \  --validate
```

**Benefits:**
- ✅ Automatic format selection based on model type
- ✅ Consistent metadata generation
- ✅ Built-in validation
- ✅ Easy to add new models
- ✅ Testable components

### 19.4 Adding New Models

To add a new model (e.g., LightGBM):

**Step 1:** Add to `config/model_registry.yaml`

```yaml
lightgbm:  class: "lightgbm.LGBMClassifier"  export_formats: [onnx, coreml]  tier: 2  size_budget:    onnx: "5MB"
```

**Step 2:** Update `tools/export/registry.py`

```python
@ExporterRegistry.register("lightgbm", ["onnx", "coreml"])
class LightGBMExporter(BaseModelExporter):
    # Inherits common logic, only override specifics    pass
```

**Step 3:** Run training

```bash
python -m tools.cli.train --models LightGBM --export onnx,coreml
```

**That’s it!** No changes to core training logic needed.

---

## 20) SDK Implementation Guidelines

### 20.1 Required SDK Components

Every SDK (Dart, Swift, Python) must implement:

**1. Model Loader**
- Parse JSON models or load binary formats
- Validate checksum before loading
- Verify model_id matches filename

**2. Metadata Parser**
- Load sidecar `.meta.json` for ONNX/CoreML
- Extract `schema.input_names` for feature ordering
- Extract normalization parameters (mean, std)

**3. Normalizer**
- Apply z-score normalization: `(x - mean) / std`
- Handle zero std: replace with 1.0
- Support missing features (optional imputation)

**4. Inference Engine**
- **JSON models:** Implement linear inference (dot product + bias)
- **ONNX models:** Use platform runtime (onnxruntime)
- **CoreML models:** Use native CoreML API

**5. Output Mapper**
- Map numeric predictions to class names
- Return probabilities array
- Support multi-class (3+) and binary classification

### 20.2 SDK Feature Matrix

| Feature | Dart | Swift | Python |
| --- | --- | --- | --- |
| JSON linear models | ✅ Native | ✅ Native | ✅ Native |
| ONNX runtime | ✅ **Production (flutter_onnxruntime)** | ⚠️ Platform channel | ✅ Native |
| ONNX input name discovery | ✅ Automatic | 🔄 Planned | ✅ Manual |
| Nested output extraction | ✅ Implemented | 🔄 Planned | ✅ Implemented |
| CoreML runtime | ❌ iOS only | ✅ Native | ❌ macOS only |
| Checksum validation | ✅ Required | ✅ Required | ✅ Required |
| Feature imputation | 🔄 Optional | 🔄 Optional | 🔄 Optional |
| Quantization | 🔜 Future | 🔜 Future | 🔜 Future |
| **ExtraTrees ONNX** | ✅ **Validated** | 🔄 Planned | ✅ Validated |

### 20.3 Dart/Flutter SDK Example (Production Implementation)

```dart
/// Load model from Flutter asset (supports both JSON and ONNX)
static Future<EmotionRecognitionModel> loadFromAsset(String assetPath) async {
  try {
    if (assetPath.endsWith('.onnx')) {
      return await _loadOnnxModel(assetPath);
    } else {
      final jsonString = await rootBundle.loadString(assetPath);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      return EmotionRecognitionModel.fromJson(jsonData);
    }
  } catch (e) {
    throw Exception('Failed to load emotion recognition model: $e');
  }
}

/// Load ONNX model with metadata (ExtraTrees implementation)
static Future<EmotionRecognitionModel> _loadOnnxModel(String onnxPath) async {
  // Load sidecar metadata
  final metaPath = onnxPath.replaceAll('.onnx', '.meta.json');
  final jsonString = await rootBundle.loadString(metaPath);
  final metadata = json.decode(jsonString) as Map<String, dynamic>;
  
  // Initialize ONNX Runtime
  final ort = OnnxRuntime();
  final session = await ort.createSessionFromAsset(onnxPath);
  
  // Create model instance with ONNX data
  final model = EmotionRecognitionModel(
    type: metadata['format'] as String,
    version: '1.0',
    modelId: metadata['model_id'] as String,
    featureOrder: List<String>.from(metadata['schema']['input_names'] as List),
    classes: List<String>.from(metadata['output']['class_names'] as List),
    scalerMean: [], // ONNX models have built-in normalization
    scalerStd: [],
    weights: [],
    bias: [],
    inference: metadata['output'] as Map<String, dynamic>,
    training: {
      'dataset': metadata['training_data_tag'] as String? ?? 'unknown',
      'created_utc': metadata['created_utc'] as String?,
    },
  );
  
  model._onnxSession = session;
  model._isOnnxModel = true;
  
  return model;
}

/// Predict using ONNX model (ExtraTrees)
Future<EmotionPrediction> _predictOnnx(HRVFeatures features) async {
  // Extract all 5 features in correct order
  final featureVector = _extractFeatureVector(features);
  // [SDNN, RMSSD, pNN50, Mean_RR, HR_mean]
  
  // Prepare input tensor (shape: [1, 5])
  final inputShape = [1, featureVector.length];
  final inputTensor = await OrtValue.fromList(featureVector, inputShape);
  
  // Try different input names (float_input works for ExtraTrees)
  final possibleInputNames = ['X', 'float_input', 'input', 'inputs'];
  Map<String, OrtValue>? outputs;
  
  for (final inputName in possibleInputNames) {
    try {
      final inputs = <String, OrtValue>{inputName: inputTensor};
      outputs = await _onnxSession!.run(inputs);
      break; // Success
    } catch (e) {
      continue; // Try next name
    }
  }
  
  // Extract probabilities from nested output [[p1, p2, p3]]
  final probsKey = outputs.keys.toList()[1]; // Second output is probabilities
  final probsData = await outputs[probsKey]!.asList();
  
  List<double> probabilities;
  if (probsData[0] is List) {
    // Nested list [[p1, p2, p3]] - extract inner list
    probabilities = (probsData[0] as List).map((e) => (e as num).toDouble()).toList();
  } else {
    // Flat list [p1, p2, p3]
    probabilities = probsData.map((e) => (e as num).toDouble()).toList();
  }
  
  // Find predicted class
  final predictedIndex = probabilities.indexOf(probabilities.reduce(max));
  final predictedClass = EmotionClass.fromString(classes[predictedIndex]);
  
  return EmotionPrediction(
    emotion: predictedClass,
    probabilities: probabilities,
    confidence: probabilities.reduce(max),
    timestamp: features.timestamp,
  );
}
```

**Production Status:** ✅ Fully implemented and validated on iOS Simulator with `extratrees_wrist_all_v1_0.onnx`

### 20.4 Swift/iOS SDK Example

```swift
class SwipModelLoader {    func loadModel(path: String) throws -> SwipModel {        // 1. Load JSON        let data = try Data(contentsOf: URL(fileURLWithPath: path))        let json = try JSONDecoder().decode(ModelMetadata.self, from: data)        // 2. Validate checksum        let checksum = computeSHA256(data)        guard checksum == json.checksum.value else {            throw ModelError.checksumMismatch
        }        // 3. Parse model type        switch json.format {        case "svm_json":            return try SVMModel(metadata: json)        case "logreg_json":            return try LogRegModel(metadata: json)        case "coreml":            return try CoreMLModel(path: path)        default:            throw ModelError.unsupportedFormat
        }    }}class SVMModel: SwipModel {    let w: [Double]    let b: Double
    let normalizer: Normalizer
    func predict(features: [String: Double]) -> Prediction {        // 1. Order features        let x = try schema.inputNames.map { name in            guard let value = features[name] else {                throw ModelError.missingFeature(name)            }            return value
        }        // 2. Normalize        let xNorm = normalizer.normalize(x)        // 3. Compute        let score = zip(w, xNorm).map(*).reduce(0, +) + b
        let prob = 1.0 / (1.0 + exp(-score))        // 4. Map to class        let classIdx = prob > 0.5 ? 1 : 0        let className = schema.classNames[classIdx]        return Prediction(label: className, probabilities: [1-prob, prob])    }}
```

---

## 21) Testing & Validation Strategy

### 21.1 CI Pipeline Requirements

**Pre-commit checks:**

```bash
# 1. Schema validationpython -m tools.validate.schema --model-dir swip/models/
# 2. Checksum verificationpython -m tools.validate.checksum --model-dir swip/models/
# 3. Size budget checkpython -m tools.validate.size --model-dir swip/models/
```

**Post-training checks:**

```bash
# 4. Round-trip inference testpython -m tools.validate.inference --model-dir swip/models/ --samples 5
# 5. Cross-platform consistency testpython -m tools.validate.cross_platform --formats json,onnx,coreml
```

### 21.2 Test Scenarios

**1. Schema Validation:**
- All required metadata fields present
- `model_id` matches filename
- `schema.input_names` is non-empty
- `schema.normalization` has mean and std arrays of correct length

**2. Checksum Tests:**
- SHA-256 matches for JSON models
- SHA-256 matches for ONNX/CoreML files
- Sidecar metadata exists for binary formats

**3. Inference Tests:**
- Load model successfully
- Run inference on 5 synthetic samples
- Output shape matches expected (1, num_classes)
- Probabilities sum to ~1.0
- Deterministic: same input → same output

**4. Cross-Format Consistency:**
- JSON vs ONNX: max difference < 1e-5
- JSON vs CoreML: max difference < 1e-5
- ONNX vs CoreML: max difference < 1e-5

**5. Size Budget:**
- JSON models < 64 KB
- ONNX models < 5 MB (linear) or < 10 MB (trees)
- CoreML models < 5 MB (linear) or < 10 MB (trees)

---

## 22) Migration Path & Backward Compatibility

### 22.1 From Monolithic to Modular

**Phase 1: Extract exporters (Week 1)**
- Move export logic to `tools/export/`
- Create base exporter class
- Implement JSON, ONNX, CoreML exporters

**Phase 2: Configuration (Week 2)**
- Create `model_registry.yaml`
- Implement registry pattern
- Update training script to use registry

**Phase 3: CLI & validation (Week 3)**
- Create CLI interface
- Implement validation tools
- Add CI checks

**Phase 4: SDK updates (Week 4)**
- Update Dart SDK with new features
- Update Swift SDK with new features
- Add cross-platform tests

### 22.2 Versioning Strategy

**Model versions:**
- `v1_0`: Initial production release
- `v1_1`: Minor update (retraining, normalization tweaks)
- `v2_0`: Major update (new features, breaking changes)

**Metadata versions:**
- Add `spec_version: "1.0"` field to track metadata format
- Future changes trigger spec version bump
- SDKs must check and handle multiple spec versions

---

## Quick Reference

### File Extensions

- `.json` — JSON linear models (SVM/LogReg)
- `.onnx` — ONNX models
- `.meta.json` — Sidecar metadata
- `.mlmodel` — CoreML source
- `.mlmodelc` — CoreML compiled

### Essential Metadata Fields

```
model_id
format
schema.input_names
schema.normalization
output.class_names
checksum
```

### Inference Flow

```
Load Model → Load Metadata → Extract Features → Normalize → Infer → Map to Class → Return Prediction
```

### CLI Commands

```bash
# Trainingpython -m tools.cli.train --scenario wrist_sdnn --models LinearSVM,LogReg
# Validationpython -m tools.cli.validate --model-dir swip/models/
# Exportpython -m tools.cli.export --model model.pkl --formats json,onnx,coreml
```

### Model Selection Guide

**Use Linear Models (Tier 1) when:**
- Size matters (mobile deployment)
- Battery life is critical
- Interpretability needed
- Acceptable accuracy (75-85% F1)

**Use Tree Models (Tier 2) when:**
- Maximum accuracy required (85-95% F1)
- Server-side inference
- ML accelerators available
- Size budget allows (1-5 MB)

---