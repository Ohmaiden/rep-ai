"""
pull_and_inspect.py
-------------------
Pulls all training data JSON files from the phone and prints a label summary.
"""

import subprocess, json, os, sys
from collections import defaultdict

ADB = r"C:\Users\omara\AppData\Local\Android\Sdk\platform-tools\adb.exe"
DEVICE = "RZCW311V2SE"
PACKAGE = "com.ohmslabs.repai"
REMOTE_DIR = "app_flutter/training_data"
LOCAL_DIR = os.path.join(os.path.dirname(__file__), "data_pull")
os.makedirs(LOCAL_DIR, exist_ok=True)

def adb(cmd):
    result = subprocess.run(
        [ADB, "-s", DEVICE, "shell", f"run-as {PACKAGE} {cmd}"],
        capture_output=True, text=True
    )
    return result.stdout.strip()

# List files
files = [f.strip() for f in adb(f"ls {REMOTE_DIR}").splitlines() if f.strip().endswith(".json")]
print(f"Found {len(files)} file(s) on device\n")

label_totals = defaultdict(int)
total_frames = 0
errors = []

for fname in files:
    local_path = os.path.join(LOCAL_DIR, fname)
    # Pull file content
    content = adb(f"cat {REMOTE_DIR}/{fname}")
    if not content or content.startswith("cat:"):
        errors.append(fname)
        continue
    with open(local_path, "w", encoding="utf-8") as f:
        f.write(content)
    try:
        data = json.loads(content)
        frames = data.get("frames", [])
        file_labels = defaultdict(int)
        for frame in frames:
            label = frame.get("label", "unlabeled")
            file_labels[label] += 1
            label_totals[label] += 1
        total_frames += len(frames)
        label_str = ", ".join(f"{k}: {v}" for k, v in sorted(file_labels.items()))
        print(f"  {fname}")
        print(f"    {len(frames)} frames  —  {label_str}")
    except json.JSONDecodeError as e:
        errors.append(f"{fname} (parse error: {e})")

print()
print("─" * 52)
print(f"  TOTAL FILES  : {len(files)}")
print(f"  TOTAL FRAMES : {total_frames}")
print("─" * 52)
for label, count in sorted(label_totals.items()):
    bar = "█" * min(30, count // 10)
    status = "✓" if count >= 200 else "✗ need more"
    print(f"  {label:<20} {count:>5}  {bar}  {status}")
print("─" * 52)

if errors:
    print(f"\nFailed to read: {errors}")

needed = {"good_form": 300, "bad_form": 300, "not_exercise": 200}
print("\nReadiness for training:")
for label, target in needed.items():
    have = label_totals.get(label, 0)
    pct = min(100, int(have / target * 100))
    bar = "█" * (pct // 5) + "░" * (20 - pct // 5)
    print(f"  {label:<15} [{bar}] {have}/{target}")
