#!/usr/bin/env python3
"""
train_classifier.py
--------------------
Trains a TensorFlow Lite push-up form classifier from collected landmark data.

Input : JSON files in tools/data_pull/
Output: assets/models/pushup_classifier.tflite  (drop-in for the Flutter app)
        assets/models/pushup_labels.txt          (label index → class name)

Labels used: good_form | bad_form | not_exercise
"""

import json, os, glob
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix
import tensorflow as tf

# ── Paths ────────────────────────────────────────────────────────────────────
ROOT       = os.path.join(os.path.dirname(__file__), "..")
DATA_DIR   = os.path.join(os.path.dirname(__file__), "data_pull")
OUT_DIR    = os.path.join(ROOT, "assets", "models")
MODEL_PATH = os.path.join(OUT_DIR, "pushup_classifier.tflite")
LABEL_PATH = os.path.join(OUT_DIR, "pushup_labels.txt")

# ── Landmark config ──────────────────────────────────────────────────────────
# 15 landmarks saved by the app (ML Kit subset, uppercase)
LANDMARK_NAMES = [
    "NOSE",
    "LEFT_EAR", "RIGHT_EAR",
    "LEFT_SHOULDER", "RIGHT_SHOULDER",
    "LEFT_ELBOW", "RIGHT_ELBOW",
    "LEFT_WRIST", "RIGHT_WRIST",
    "LEFT_HIP", "RIGHT_HIP",
    "LEFT_KNEE", "RIGHT_KNEE",
    "LEFT_ANKLE", "RIGHT_ANKLE",
]
N_LANDMARKS = len(LANDMARK_NAMES)   # 15
N_FEATURES  = N_LANDMARKS * 2       # x, y only (visibility used as weight, not feature)

VALID_LABELS = {"good_form", "bad_form", "not_exercise"}

# ── Feature extraction ───────────────────────────────────────────────────────
def extract_features(landmarks: dict) -> np.ndarray | None:
    """
    Returns a 30-float feature vector normalised to the body.
    Coordinates are centred on the mid-hip and scaled by torso length
    so position/distance from camera don't affect the prediction.
    """
    coords = []
    visibilities = []
    for name in LANDMARK_NAMES:
        lm = landmarks.get(name)
        if lm is None:
            return None  # skip frames with missing landmarks
        coords.append([lm["x"], lm["y"]])
        visibilities.append(lm.get("visibility", 1.0))

    coords = np.array(coords, dtype=np.float32)  # (15, 2)

    # Only use the frame if the key body landmarks are visible
    shoulder_vis = (visibilities[3] + visibilities[4]) / 2  # LEFT/RIGHT_SHOULDER
    hip_vis      = (visibilities[9] + visibilities[10]) / 2  # LEFT/RIGHT_HIP
    if shoulder_vis < 0.3 or hip_vis < 0.3:
        return None

    # Normalise: centre on mid-hip, scale by shoulder-to-hip distance
    mid_hip      = (coords[9] + coords[10]) / 2            # indices of L/R hip
    mid_shoulder = (coords[3] + coords[4]) / 2             # indices of L/R shoulder
    torso_size   = np.linalg.norm(mid_shoulder - mid_hip)

    if torso_size < 1e-4:
        return None  # degenerate / person out of frame

    coords = (coords - mid_hip) / torso_size
    return coords.flatten()  # 30 values

# ── Load data ────────────────────────────────────────────────────────────────
def load_data():
    files = glob.glob(os.path.join(DATA_DIR, "*.json"))
    X, y = [], []
    skipped_label = skipped_pose = 0

    for path in files:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        for frame in data.get("frames", []):
            label = frame.get("label", "")
            if label not in VALID_LABELS:
                skipped_label += 1
                continue
            feat = extract_features(frame.get("landmarks", {}))
            if feat is None:
                skipped_pose += 1
                continue
            X.append(feat)
            y.append(label)

    print(f"Loaded  : {len(X)} frames")
    print(f"Skipped : {skipped_label} (wrong label)  {skipped_pose} (bad pose)")
    return np.array(X, dtype=np.float32), np.array(y)

print("=" * 55)
print("  Push-up Form Classifier — Training")
print("=" * 55)

X, y_str = load_data()

# Encode labels alphabetically: bad_form=0, good_form=1, not_exercise=2
classes   = sorted(VALID_LABELS)
label_map = {c: i for i, c in enumerate(classes)}
y         = np.array([label_map[l] for l in y_str], dtype=np.int32)

print(f"\nClass distribution:")
for name in classes:
    count = int((y_str == name).sum())
    bar   = "█" * (count // 30)
    print(f"  [{label_map[name]}] {name:<15} {count:>5}  {bar}")

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)
print(f"\nTrain: {len(X_train)}   Test: {len(X_test)}")

# ── Model ────────────────────────────────────────────────────────────────────
model = tf.keras.Sequential([
    tf.keras.layers.Input(shape=(N_FEATURES,)),
    tf.keras.layers.Dense(64, activation="relu"),
    tf.keras.layers.Dropout(0.3),
    tf.keras.layers.Dense(32, activation="relu"),
    tf.keras.layers.Dropout(0.2),
    tf.keras.layers.Dense(len(classes), activation="softmax"),
], name="pushup_classifier")

model.compile(
    optimizer="adam",
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"],
)
model.summary()

# ── Train ─────────────────────────────────────────────────────────────────────
print("\nTraining…")
history = model.fit(
    X_train, y_train,
    epochs=60,
    batch_size=32,
    validation_split=0.15,
    callbacks=[
        tf.keras.callbacks.EarlyStopping(
            monitor="val_accuracy", patience=10, restore_best_weights=True
        ),
    ],
    verbose=1,
)

# ── Evaluate ──────────────────────────────────────────────────────────────────
loss, acc = model.evaluate(X_test, y_test, verbose=0)
print(f"\n{'='*55}")
print(f"  Test accuracy : {acc:.1%}   loss: {loss:.4f}")
print(f"{'='*55}")

y_pred = model.predict(X_test, verbose=0).argmax(axis=1)
print("\nClassification report:")
print(classification_report(y_test, y_pred, target_names=classes))
print("Confusion matrix (rows=actual, cols=predicted):")
print("  Labels:", classes)
print(confusion_matrix(y_test, y_pred))

# ── Export TFLite ─────────────────────────────────────────────────────────────
os.makedirs(OUT_DIR, exist_ok=True)
converter    = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_bytes = converter.convert()

with open(MODEL_PATH, "wb") as f:
    f.write(tflite_bytes)

with open(LABEL_PATH, "w") as f:
    f.write("\n".join(classes))

print(f"\nSaved model  : {MODEL_PATH}  ({len(tflite_bytes)/1024:.1f} KB)")
print(f"Saved labels : {LABEL_PATH}")
print(f"  " + "  ".join(f"{i}={c}" for i, c in enumerate(classes)))
print("\nDone. Drop the .tflite file into the Flutter app's assets/models/ folder.")
