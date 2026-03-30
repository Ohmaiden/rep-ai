"""
relabel.py
==========
Bulk-relabels all frames in a JSON file to a single label.
Use this when you know an entire recording was good form or bad form.

Usage:
    python tools/relabel.py tools/pushup_1.json good_form
    python tools/relabel.py tools/pushup_2.json bad_form
    python tools/relabel.py tools/pushup_3.json not_exercise

Valid labels: good_form, bad_form, not_exercise
"""

import json, sys, os
from collections import defaultdict

VALID = {'good_form', 'bad_form', 'not_exercise'}

def relabel(path: str, new_label: str):
    if new_label not in VALID:
        print(f'Invalid label "{new_label}". Choose from: {", ".join(VALID)}')
        return

    with open(path) as f:
        data = json.load(f)

    old_counts = data.get('label_counts', {})
    total = len(data['frames'])

    # Drop setup/unlabeled frames, relabel the rest
    kept = [f for f in data['frames'] if f['label'] != 'unlabeled']
    dropped = total - len(kept)

    for frame in kept:
        frame['label'] = new_label

    data['frames'] = kept
    data['label_counts'] = {new_label: len(kept)}
    data['total_frames'] = len(kept)

    with open(path, 'w') as f:
        json.dump(data, f, indent=2)

    print(f'\n{os.path.basename(path)}')
    print(f'  Before: {dict(old_counts)}')
    print(f'  Dropped {dropped} unlabeled setup frames')
    print(f'  After:  {len(kept)} frames → "{new_label}"')

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    relabel(sys.argv[1], sys.argv[2])
