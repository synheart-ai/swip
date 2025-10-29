# Colab-ready ONNX inference for ExtraTrees model

import onnxruntime as ort
import numpy as np
import json
from pathlib import Path

# --- Config ---
MODEL_DIR = Path("/content/swip/models")
MODEL_FILENAME = "extratrees_wrist_all_v1_0.onnx"
META_FILENAME = "extratrees_wrist_all_v1_0.meta.json"

LABEL_ORDER = ["Calm", "Stressed", "Amused"]

# --- Helpers ---
def load_sidecar(meta_path: Path):
    """Load sidecar metadata JSON"""
    if not meta_path.exists():
        raise FileNotFoundError(f"Sidecar metadata not found: {meta_path}")
    with open(meta_path, "r") as f:
        return json.load(f)

def softmax(logits):
    e = np.exp(logits - np.max(logits, axis=-1, keepdims=True))
    return e / np.sum(e, axis=-1, keepdims=True)

def infer_onnx(model_path: Path, meta_path: Path, sample: dict):
    """Run ONNX inference with ExtraTrees model"""
    if not model_path.exists():
        raise FileNotFoundError(f"ONNX model not found: {model_path}")
    
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
    input_name = sess.get_inputs()[0].name
    outputs = sess.run(None, {input_name: x_arr})
    
    # ExtraTrees ONNX outputs: [label, probabilities]
    # probabilities is shape (1, 3) for 3 classes
    if len(outputs) >= 2:
        probs = np.array(outputs[1], dtype=np.float32)
    else:
        # Fallback: use first output and apply softmax
        probs = softmax(np.array(outputs[0], dtype=np.float32))
    
    class_idx = int(np.argmax(probs, axis=1)[0])
    pred_label = LABEL_ORDER[class_idx]
    
    return pred_label, probs, outputs

# --- Main ---
model_path = MODEL_DIR / MODEL_FILENAME
meta_path = MODEL_DIR / META_FILENAME

# Load feature names
meta = load_sidecar(meta_path)
feature_names = meta.get("schema", {}).get("input_names")
print("Feature names:", feature_names)
print("Expected features: SDNN, RMSSD, pNN50, Mean_RR, HR_mean\n")

# Example sample with all 5 features
sample = {
    "SDNN": 50.0,      # ms
    "RMSSD": 30.0,     # ms
    "pNN50": 15.0,     # %
    "Mean_RR": 850.0,  # ms
    "HR_mean": 70.6    # bpm
}

print("Input sample:", sample)

# Run inference
pred_label, probs, raw_outs = infer_onnx(model_path, meta_path, sample)

print("\n" + "="*50)
print("PREDICTION RESULTS")
print("="*50)
print(f"Predicted State: {pred_label}")
print(f"\nClass Probabilities:")
for label, prob in zip(LABEL_ORDER, probs[0]):
    print(f"  {label:10s}: {prob:.4f} ({prob*100:.1f}%)")
print("\nRaw output shapes:", [np.array(o).shape for o in raw_outs])