"""
inspect_data.py
===============
Shows a summary of all training JSON files in a folder.
Tells you how many frames per label you have before training.

Usage:
    python tools/inspect_data.py tools/
    python tools/inspect_data.py C:/path/to/json/folder
"""

import json
import os
import sys
from collections import defaultdict

def inspect(folder: str):
    files = [f for f in os.listdir(folder) if f.endswith('.json')]
    if not files:
        print(f'No JSON files found in {folder}')
        return

    total_frames = 0
    label_counts: dict[str, int] = defaultdict(int)
    file_summaries = []

    for fname in sorted(files):
        path = os.path.join(folder, fname)
        try:
            with open(path) as f:
                data = json.load(f)
            n = data.get('total_frames', 0)
            counts = data.get('label_counts', {})
            total_frames += n
            for label, count in counts.items():
                label_counts[label] += count
            file_summaries.append((fname, n, counts))
        except Exception as e:
            print(f'  Could not read {fname}: {e}')

    # Print per-file summary
    print(f'\n{"─"*55}')
    print(f'  FILES FOUND: {len(files)}')
    print(f'{"─"*55}')
    for fname, n, counts in file_summaries:
        print(f'\n  {fname}')
        print(f'  {n} frames total')
        for label, count in sorted(counts.items()):
            bar = '█' * min(30, count // 10)
            print(f'    {label:<30} {count:>5}  {bar}')

    # Print totals
    print(f'\n{"─"*55}')
    print(f'  TOTAL ACROSS ALL FILES: {total_frames} frames')
    print(f'{"─"*55}')
    for label, count in sorted(label_counts.items(), key=lambda x: -x[1]):
        bar = '█' * min(40, count // 20)
        status = '✓' if count >= 200 else '⚠ need more' if count >= 50 else '✗ too few'
        print(f'  {label:<30} {count:>5}  {status}')

    print(f'\n  Recommendation:')
    print(f'  • 200+ frames per label = good to train')
    print(f'  • 500+ frames per label = solid model')
    print(f'  • Labels with ✗ need more data before training\n')


if __name__ == '__main__':
    folder = sys.argv[1] if len(sys.argv) > 1 else '.'
    inspect(folder)
