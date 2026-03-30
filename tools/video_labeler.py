"""
Push-up Video Labeler
=====================
Load a video of yourself doing push-ups, mark which segments have which labels,
then export — it runs MediaPipe pose detection on those segments and saves a
JSON file in the exact same format the Flutter app produces.

Install dependencies:
    pip install mediapipe opencv-python pillow

Usage:
    python tools/video_labeler.py

Workflow:
    1. Click "Open Video File" and load your video
    2. Scrub to where a segment starts, press [S] to mark start
    3. Pick the label on the right that matches that segment
    4. Scrub to where the segment ends, press [E] to mark end
    5. Repeat for each segment (skip setup/intro entirely)
    6. Click "Export Training Data" — it processes and saves JSON
"""

import tkinter as tk
from tkinter import ttk, filedialog, messagebox
import cv2
import mediapipe as mp
import json
import os
import threading
from datetime import datetime
from PIL import Image, ImageTk


LABELS = [
    ('pushup_up_good',        'UP — Good Form',      '#16A34A'),
    ('pushup_down_good',      'DOWN — Good Form',    '#16A34A'),
    ('transition',            'Moving (transition)', '#2563EB'),
    ('pushup_bad_hips',       'Bad — Hips Sagging',  '#DC2626'),
    ('pushup_bad_depth',      'Bad — Not Deep Enough','#DC2626'),
    ('pushup_bad_head',       'Bad — Head Position', '#DC2626'),
    ('pushup_bad_speed',      'Bad — Too Fast',      '#EA580C'),
    ('pushup_bad_extension',  'Bad — Arm Extension', '#EA580C'),
    ('not_exercise',          'Not Exercising',      '#6B7280'),
]


class VideoLabeler:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title('Push-up Video Labeler')
        self.root.configure(bg='#1a1a2e')
        self.root.minsize(960, 600)

        self.cap = None
        self.total_frames = 0
        self.fps = 30.0
        self.current_frame = 0
        self.is_playing = False
        self.photo = None

        self.segments: list[tuple[int, int, str]] = []
        self.mark_start_frame: int | None = None
        self.selected_label = tk.StringVar(value=LABELS[0][0])

        self._build_ui()
        self._bind_keys()

    # ------------------------------------------------------------------ UI --

    def _build_ui(self):
        # ---- Left: video panel ----
        left = tk.Frame(self.root, bg='#1a1a2e')
        left.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=10, pady=10)

        self.canvas = tk.Canvas(left, bg='#000000', width=640, height=360,
                                highlightthickness=0)
        self.canvas.pack()

        self.scrubber_var = tk.DoubleVar()
        self.scrubber = ttk.Scale(left, from_=0, to=100, orient=tk.HORIZONTAL,
                                  variable=self.scrubber_var,
                                  command=self._on_scrub)
        self.scrubber.pack(fill=tk.X, pady=(6, 0))

        self.frame_label = tk.Label(left, text='No video loaded',
                                    bg='#1a1a2e', fg='#9CA3AF',
                                    font=('Courier', 10))
        self.frame_label.pack(pady=(2, 6))

        # Playback buttons
        ctrl = tk.Frame(left, bg='#1a1a2e')
        ctrl.pack(pady=2)
        bs = dict(bg='#374151', fg='white', relief='flat',
                  padx=10, pady=5, font=('Arial', 11))
        tk.Button(ctrl, text='⏮', command=self._go_start, **bs).pack(side=tk.LEFT, padx=2)
        tk.Button(ctrl, text='◀◀', command=lambda: self._step(-30), **bs).pack(side=tk.LEFT, padx=2)
        tk.Button(ctrl, text='◀',  command=lambda: self._step(-1),  **bs).pack(side=tk.LEFT, padx=2)
        self.play_btn = tk.Button(ctrl, text='▶', command=self._toggle_play, **bs)
        self.play_btn.pack(side=tk.LEFT, padx=2)
        tk.Button(ctrl, text='▶',  command=lambda: self._step(1),   **bs).pack(side=tk.LEFT, padx=2)
        tk.Button(ctrl, text='▶▶', command=lambda: self._step(30),  **bs).pack(side=tk.LEFT, padx=2)
        tk.Button(ctrl, text='⏭', command=self._go_end, **bs).pack(side=tk.LEFT, padx=2)

        tk.Button(left, text='Open Video File', command=self._open_video,
                  bg='#2563EB', fg='white', relief='flat',
                  padx=14, pady=8, font=('Arial', 11, 'bold')).pack(pady=10)

        # ---- Right: labels + segments ----
        right = tk.Frame(self.root, bg='#111827', width=300)
        right.pack(side=tk.RIGHT, fill=tk.Y, padx=(0, 10), pady=10)
        right.pack_propagate(False)

        tk.Label(right, text='SELECT LABEL', bg='#111827', fg='#6B7280',
                 font=('Arial', 8, 'bold')).pack(pady=(14, 4))

        for lid, ltext, _ in LABELS:
            tk.Radiobutton(right, text=ltext, variable=self.selected_label,
                           value=lid, bg='#111827', fg='white',
                           selectcolor='#374151', activebackground='#111827',
                           activeforeground='white',
                           font=('Arial', 10)).pack(anchor=tk.W, padx=14, pady=1)

        # Mark start/end buttons
        mf = tk.Frame(right, bg='#111827')
        mf.pack(fill=tk.X, padx=10, pady=10)

        self.mark_start_btn = tk.Button(
            mf, text='[S]  Mark Segment Start', command=self._mark_start,
            bg='#D97706', fg='white', relief='flat', pady=7,
            font=('Arial', 10, 'bold'))
        self.mark_start_btn.pack(fill=tk.X, pady=2)

        self.mark_end_btn = tk.Button(
            mf, text='[E]  Mark Segment End', command=self._mark_end,
            bg='#374151', fg='#6B7280', relief='flat', pady=7,
            font=('Arial', 10, 'bold'), state=tk.DISABLED)
        self.mark_end_btn.pack(fill=tk.X, pady=2)

        # Segments list
        tk.Label(right, text='SEGMENTS', bg='#111827', fg='#6B7280',
                 font=('Arial', 8, 'bold')).pack(pady=(6, 4))

        sf = tk.Frame(right, bg='#111827')
        sf.pack(fill=tk.BOTH, expand=True, padx=10)

        self.seg_listbox = tk.Listbox(sf, bg='#1F2937', fg='white',
                                      relief='flat', selectbackground='#374151',
                                      font=('Courier', 9), height=8)
        self.seg_listbox.pack(fill=tk.BOTH, expand=True)

        tk.Button(sf, text='Delete Selected Segment', command=self._delete_segment,
                  bg='#7F1D1D', fg='white', relief='flat', pady=4).pack(fill=tk.X, pady=(4, 0))

        tk.Button(right, text='⚡  Export Training Data',
                  command=self._export,
                  bg='#16A34A', fg='white', relief='flat',
                  padx=12, pady=10,
                  font=('Arial', 11, 'bold')).pack(fill=tk.X, padx=10, pady=8)

        self.status_label = tk.Label(right, text='Open a video to start.',
                                     bg='#111827', fg='#6B7280',
                                     font=('Arial', 9), wraplength=260,
                                     justify=tk.LEFT)
        self.status_label.pack(padx=10, pady=(0, 10))

    def _bind_keys(self):
        self.root.bind('<space>',        lambda e: self._toggle_play())
        self.root.bind('<Left>',         lambda e: self._step(-1))
        self.root.bind('<Right>',        lambda e: self._step(1))
        self.root.bind('<Shift-Left>',   lambda e: self._step(-30))
        self.root.bind('<Shift-Right>',  lambda e: self._step(30))
        self.root.bind('s',              lambda e: self._mark_start())
        self.root.bind('e',              lambda e: self._mark_end())

    # -------------------------------------------------------- Video loading --

    def _open_video(self):
        path = filedialog.askopenfilename(
            title='Open Video',
            filetypes=[('Video files', '*.mp4 *.mov *.avi *.mkv'), ('All files', '*.*')]
        )
        if not path:
            return

        if self.cap:
            self.cap.release()

        self.cap = cv2.VideoCapture(path)
        self.total_frames = int(self.cap.get(cv2.CAP_PROP_FRAME_COUNT))
        self.fps = self.cap.get(cv2.CAP_PROP_FPS) or 30.0
        self.current_frame = 0
        self.segments.clear()
        self.mark_start_frame = None
        self._update_seg_list()
        self.scrubber.configure(to=max(1, self.total_frames - 1))
        self._show_frame(0)

        duration = self.total_frames / self.fps
        self.status_label.config(
            text=f'{os.path.basename(path)}\n'
                 f'{self.total_frames} frames  '
                 f'{int(duration//60)}:{int(duration%60):02d}  '
                 f'{self.fps:.1f}fps\n\n'
                 f'Scrub to where a good segment starts,\n'
                 f'press [S], pick a label, scrub to end,\npress [E].'
        )

    # -------------------------------------------------------- Frame display --

    def _show_frame(self, frame_num: int):
        if self.cap is None:
            return

        frame_num = max(0, min(frame_num, self.total_frames - 1))
        self.current_frame = frame_num

        self.cap.set(cv2.CAP_PROP_POS_FRAMES, frame_num)
        ret, frame = self.cap.read()
        if not ret:
            return

        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        h, w = frame_rgb.shape[:2]
        scale = min(640 / w, 360 / h)
        new_w, new_h = int(w * scale), int(h * scale)
        frame_rgb = cv2.resize(frame_rgb, (new_w, new_h))

        # Overlay: mark-start indicator
        if self.mark_start_frame is not None:
            cv2.putText(frame_rgb,
                        f'START @ {self._fmt_frame(self.mark_start_frame)}',
                        (8, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (255, 165, 0), 2)

        img = Image.fromarray(frame_rgb)
        self.photo = ImageTk.PhotoImage(img)
        self.canvas.configure(width=new_w, height=new_h)
        self.canvas.create_image(0, 0, anchor=tk.NW, image=self.photo)

        self.scrubber_var.set(frame_num)
        self.frame_label.config(
            text=f'Frame {frame_num} / {self.total_frames}   {self._fmt_frame(frame_num)}'
        )

    def _fmt_frame(self, n: int) -> str:
        secs = n / self.fps
        return f'{int(secs // 60)}:{int(secs % 60):02d}.{int((secs % 1) * 10)}'

    def _on_scrub(self, val):
        if self.cap:
            self._show_frame(int(float(val)))

    def _step(self, n: int):
        self._show_frame(self.current_frame + n)

    def _go_start(self):
        self._show_frame(0)

    def _go_end(self):
        self._show_frame(self.total_frames - 1)

    def _toggle_play(self):
        if self.cap is None:
            return
        self.is_playing = not self.is_playing
        self.play_btn.config(text='⏸' if self.is_playing else '▶')
        if self.is_playing:
            self._play_loop()

    def _play_loop(self):
        if not self.is_playing or self.cap is None:
            return
        if self.current_frame >= self.total_frames - 1:
            self.is_playing = False
            self.play_btn.config(text='▶')
            return
        self._show_frame(self.current_frame + 1)
        delay = max(1, int(1000 / self.fps))
        self.root.after(delay, self._play_loop)

    # ----------------------------------------------------------- Segmenting --

    def _mark_start(self):
        if self.cap is None:
            return
        self.mark_start_frame = self.current_frame
        self.mark_end_btn.config(state=tk.NORMAL, bg='#16A34A', fg='white')
        self.status_label.config(
            text=f'Start marked: {self._fmt_frame(self.mark_start_frame)}\n\n'
                 f'Pick a label on the right, scrub to\nwhere this segment ends, press [E].'
        )

    def _mark_end(self):
        if self.mark_start_frame is None:
            return
        end = self.current_frame
        if end <= self.mark_start_frame:
            messagebox.showwarning('Invalid', 'End must be after start.')
            return

        label = self.selected_label.get()
        self.segments.append((self.mark_start_frame, end, label))
        self._update_seg_list()

        frames = end - self.mark_start_frame
        self.mark_start_frame = None
        self.mark_end_btn.config(state=tk.DISABLED, bg='#374151', fg='#6B7280')
        self.status_label.config(
            text=f'Segment added: {frames} frames ({frames/self.fps:.1f}s)\n\n'
                 f'{len(self.segments)} segment(s) total.\n'
                 f'Keep marking or click Export.'
        )

    def _update_seg_list(self):
        self.seg_listbox.delete(0, tk.END)
        for i, (start, end, label) in enumerate(self.segments):
            dur = (end - start) / self.fps
            short = label.replace('pushup_', '').replace('_', ' ')
            self.seg_listbox.insert(
                tk.END,
                f'{i+1}. {short:<18} {dur:4.1f}s'
            )

    def _delete_segment(self):
        sel = self.seg_listbox.curselection()
        if sel:
            self.segments.pop(sel[0])
            self._update_seg_list()

    # -------------------------------------------------------------- Export --

    def _export(self):
        if not self.segments:
            messagebox.showwarning('Nothing to export', 'Mark some segments first.')
            return

        out_dir = filedialog.askdirectory(title='Save training data to folder')
        if not out_dir:
            return

        self.status_label.config(text='Processing with MediaPipe...\nThis may take a minute.')
        self.root.update()
        threading.Thread(target=self._run_export, args=(out_dir,), daemon=True).start()

    def _run_export(self, out_dir: str):
        mp_pose = mp.solutions.pose
        pose = mp_pose.Pose(
            static_image_mode=False,
            model_complexity=1,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5,
        )
        landmark_names = [lm.name for lm in mp_pose.PoseLandmark]

        all_frames = []
        total_to_process = sum(end - start for start, end, _ in self.segments)
        processed = 0

        for seg_start, seg_end, label in self.segments:
            self.cap.set(cv2.CAP_PROP_POS_FRAMES, seg_start)

            for frame_num in range(seg_start, seg_end):
                ret, frame = self.cap.read()
                if not ret:
                    break

                rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                result = pose.process(rgb)

                if result.pose_landmarks:
                    landmarks = {}
                    for i, lm in enumerate(result.pose_landmarks.landmark):
                        landmarks[landmark_names[i]] = {
                            'x': round(lm.x, 6),
                            'y': round(lm.y, 6),
                            'visibility': round(lm.visibility, 4),
                        }
                    all_frames.append({
                        'timestamp_ms': int((frame_num / self.fps) * 1000),
                        'label': label,
                        'exercise': 'pushup',
                        'landmarks': landmarks,
                    })

                processed += 1
                if processed % 30 == 0:
                    pct = int(processed / total_to_process * 100)
                    self.root.after(0, lambda p=pct: self.status_label.config(
                        text=f'Processing... {p}%'))

        pose.close()

        if not all_frames:
            self.root.after(0, lambda: messagebox.showerror(
                'Export failed', 'MediaPipe detected no poses in any segment.\n'
                                 'Check that the person is clearly visible.'))
            return

        # Build label counts
        label_counts: dict[str, int] = {}
        for f in all_frames:
            label_counts[f['label']] = label_counts.get(f['label'], 0) + 1

        # Save JSON — same format as Flutter app's DataCollectionService
        timestamp = datetime.now().strftime('%Y-%m-%dT%H-%M-%S')
        filename = f'pushup_{timestamp}.json'
        out_path = os.path.join(out_dir, filename)

        data = {
            'exercise': 'pushup',
            'recorded_at': datetime.now().isoformat(),
            'total_frames': len(all_frames),
            'label_counts': label_counts,
            'frames': all_frames,
        }
        with open(out_path, 'w') as f:
            json.dump(data, f, indent=2)

        summary = '\n'.join(f'  {k}: {v}' for k, v in label_counts.items())
        self.root.after(0, lambda: [
            self.status_label.config(
                text=f'Done! {len(all_frames)} frames saved.\n{filename}'),
            messagebox.showinfo(
                'Export complete',
                f'Saved {len(all_frames)} frames:\n{summary}\n\nFile:\n{out_path}'
            )
        ])


if __name__ == '__main__':
    root = tk.Tk()
    app = VideoLabeler(root)
    root.mainloop()
