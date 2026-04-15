# Rep AI — Full Project Summary

## What Is Rep AI?
Rep AI is an AI-powered fitness app built with Flutter that uses your phone camera + on-device machine learning to count push-up reps and detect form quality. Only good form reps count — bad form attempts are tracked silently. No wearables, no equipment, just prop your phone up and work out.

## Who Built It
Omar (Ohms Labs), solo indie developer. Built the entire app using Claude Code as primary dev environment, with GPT as a strategic advisor.

## Current Status (April 2026)
- **iOS:** Live on the Apple App Store at £0.99 (one-time payment). Actively being promoted.
- **Android:** Closed testing on Google Play with 12+ testers. Awaiting 14-day testing period before production launch.
- **Focus:** Tweaking and polishing the app for promotion. Subscription model planned when more exercises are added.

---

## Tech Stack
- **Framework:** Flutter/Dart (cross-platform mobile)
- **Pose Detection:** Google ML Kit Pose Detection (on-device, 33 body landmarks)
- **Form Classification:** Custom TFLite model trained on ~6,500 labeled frames (92.7% accuracy, 97% good_form recall)
- **Database:** SQLite (sqflite + sqflite_common_ffi for desktop)
- **State Management:** Provider
- **Charts:** fl_chart
- **Audio:** audioplayers (MP3 files for rep feedback sounds)
- **Build/Distribution:** Google Play Console, Codemagic (iOS), GitHub (private repo)
- **Test Device:** Samsung Galaxy A53 (Android 16)

## Project Location
- **Code:** E:\dev\rep_counter
- **GitHub:** Private repo at github.com/Ohmaiden/rep-ai.git
- **Package name (Android):** com.repcounter.rep_counter
- **Package name (iOS):** com.ohmslabs.repai

---

## How Rep Counting Works
1. Google ML Kit detects 33 body landmarks from the camera feed
2. Shoulder midpoint Y-position is tracked (rises and falls during push-ups)
3. Signal is smoothed with EMA filter to reduce noise
4. State machine: IDLE → UP (in push-up position) → DOWN (shoulders drop below threshold) → UP (rep counted)
5. Thresholds are dynamic — scale with torso length so they work at any distance from camera
6. TFLite classifier runs on each frame: outputs good_form / bad_form / not_exercise
7. Per-rep form quality = majority vote across all frames in that rep
8. Only good form reps increment the visible counter; bad reps tracked in background

### Key Technical Decisions
- **Shoulder Y-position, not elbow angle** — angles vary too much across body types and camera angles
- **Dynamic thresholds** — 15% of torso length for DOWN detection, 10% for UP detection
- **Baseline lock after 8 frames** — prevents baseline drift bug where _topValue chased the signal
- **Always use Y axis** — ML Kit landmarks are in image space regardless of device rotation
- **Fresh AudioPlayer per sound** — prevents pool exhaustion on fast consecutive reps

---

## App Features (What's Built)

### Core
- AI push-up rep counting with form classification
- Works from any camera angle (front, side, diagonal)
- Works in landscape and portrait mode
- Front camera by default

### Workout Modes
- **Quick Workout** — free session, no targets, start and stop whenever
- **Custom Workout** — set number of sets, reps per set, rest time between sets
- Rest timer with circular countdown, ±10s adjustment buttons, skip button
- Auto-transition to rest timer when set target reached
- Auto-end workout after final set
- Rep counter capped at target in custom mode

### Tracking & Stats
- Workout history stored in SQLite with per-rep and per-set breakdown
- Progress charts (reps over time, form score over time)
- Daily/weekly/monthly/yearly rep statistics
- Tappable stat cards showing detailed breakdowns
- Swipe to delete individual sessions from history

### Motivation & Goals
- Daily streak tracking with fire emoji
- Visual calendar showing workout days (tap for details)
- Personal records: best streak, most reps, best form score
- Goals system: daily/weekly targets set during onboarding, editable anytime in Settings
- Daily goal seeded from fitness level (Beginner 20, Intermediate 50, Advanced 100 push-ups per day)
- Weekly goal computed automatically as daily goal x number of active training days
- Active training days configurable per day of the week (e.g. Tue/Thu/Sat/Sun only) — default all 7
- Weekly goal reset day configurable in Settings (default Monday)
- Badges and achievements (First Workout, Week Warrior, Century Club, Perfect Form, Consistent, Goal Crusher)
- Locked badges show how to earn them when tapped

### Audio & Haptic Feedback
- good_rep.mp3 — satisfying ding on each good rep
- bad_rep.mp3 — buzz on bad form attempt
- set_complete.mp3 — chime when workout summary appears
- Audio files trimmed in Audacity to remove leading silence
- Haptic vibration on good and bad reps

### UI/UX
- Clean modern design — dark workout screen, light/dark theme for everything else
- Light mode, dark mode, system-follow theme with settings toggle
- Onboarding guide (9 screens) for first-time users, shown once — covers fitness level, active training days, daily goal, and app navigation
- Question mark button (?) on home screen to revisit guide anytime
- Final onboarding page tells users they can return via the question mark at any time
- All onboarding copy written in plain English — no jargon, minimal words, accessible to any age or experience level
- Settings screen accessible from home screen
- Camera permission handling with friendly message
- No-pose hint after 10 seconds without detection
- 0-rep workouts don't save to history
- Confetti animation on workout completion
- Human-readable dates in workout history ("Today", "Yesterday", "Monday 14 Apr")
- Friendly empty state when no workouts recorded yet

### Privacy
- All AI processing on-device — no video recorded, no data uploaded
- No accounts, no login, no analytics, no ads
- Privacy policy hosted on GitHub Pages

---

## Known Issues / Bugs

### Active Bugs
- **Null check error** — red screen "Null check operator used on a null value" when app goes to background during workout. Caused by _bottomValue or _topValue being null in pushup_analyzer.dart. Fix: add null guards on all ! operators.
- **Rest timer overflow** — pixel overflow in landscape mode on the rest timer screen (portrait mostly fixed with OrientationBuilder)
- **Goal dialog text** — "Weekly" and "Monthly" buttons truncate or wrap to two lines in the Set Your Goal dialog. Buttons need to be wider.
- **Audio lag in landscape** — good form ding has slight delay in landscape vs portrait
- **Landscape direction detection** — in landscape, facing one way works, facing the other doesn't (partially fixed by always using Y axis)

### Known Limitations
- Only push-ups — no other exercises yet
- Trained on one person's data (~6,500 frames) — may be less accurate for very different body types
- Bizarre/unusual push-up forms might still be counted
- Front-facing camera is less reliable than side view
- No video recording or playback

---

## Store Listings

### Google Play
- **App name:** Rep AI
- **Package:** com.repcounter.rep_counter
- **Short description:** AI rep counter that only counts clean reps. Fix your form and progress.
- **Category:** Health & Fitness
- **Tags:** Workout, Activity tracker, Health & fitness, Sports coaching, Self-help
- **Price:** £2.99 (set for production, free during closed testing)
- **Contact email:** info.ohmslabs@gmail.com
- **Business name:** Ohms Labs
- **Privacy policy:** https://github.com/OhmsLabs/rep-ai-privacy
- **Tester link:** https://play.google.com/apps/testing/com.repcounter.rep_counter

### App Store (iOS)
- **App name:** Rep AI
- **Bundle ID:** com.ohmslabs.repai
- **Description:** Rep AI is an AI-powered push-up counter that only counts reps with good form. Using your phone's camera and on-device AI, Rep AI tracks your movement in real time. Features: automatic rep counting with form detection, good vs bad form tracking, workout history with weekly/monthly stats, daily/weekly rep goals, streak tracking, portrait and landscape support. All processing happens on device. No video recorded. No data uploaded.
- **Price:** £0.99 (one-time payment)
- **Status:** Live on the App Store
- **iPhone and iPad** — portrait-only on both; `UIRequiresFullScreen=true` opts out of iPad multitasking (required for portrait-only iPad apps); `TARGETED_DEVICE_FAMILY=1,2` targets both
- **Built via Codemagic** (cloud Mac builds)

---

## Accounts & Credentials

### Google Play Developer
- **Email:** info.ohmslabs@gmail.com
- **Status:** Verified, approved
- **Cost:** £25 one-time (paid)

### Apple Developer
- **Email:** omar.ac27@icloud.com (Apple ID)
- **Status:** Enrolled, $99/year paid
- **Cost:** $99/year (~£79)

### Codemagic
- **Email:** info.ohmslabs@gmail.com
- **GitHub connected:** github.com/Ohmaiden/rep-ai.git
- **Workflow:** iOS build with automatic App Store Connect publishing

### Keystore (Android signing — CRITICAL)
- **File:** android/app/upload-keystore.jks
- **Password:** RepAI2026!
- **Alias:** upload
- **Key password:** RepAI2026!
- **WARNING:** If this file is lost, you can NEVER update the app on Google Play

---

## Development History

### Phase 0 — Python Prototype
- MediaPipe + OpenCV push-up detection on Windows laptop
- iPhone streamed via Iriun Webcam
- Discovered ML Kit reports angles ~25° higher than visual reality
- Calibrated thresholds: down=125°, up=145°
- Learned hard-coded angle thresholds don't generalize

### Phase 1 — Flutter Setup
- Flutter SDK, Android SDK, VS Code, Samsung A53 test device
- Fixed CardTheme → CardThemeData for Flutter 3.41+
- Fixed sqflite for Windows desktop with FFI

### Phase 2 — Core Architecture (16 files)
- ML Kit integration, pose service, workout state, database service
- Home screen, workout screen, history screen
- Skeleton overlay (later removed for performance)

### Phase 3 — Camera & Detection Fixes
- Switched to front camera
- Fixed camera preview aspect ratio
- Removed skeleton overlay for performance boost
- Simplified workout screen to camera + rep counter + timer

### Phase 4 — AI Model Training
- Built data collection screen for labeled pose data
- Collected ~6,500 frames (good_form, bad_form, not_exercise)
- Trained TFLite classifier: 92.7% accuracy
- Replaced angle-based detection with ML model

### Phase 5 — Rep Counting Overhaul
- Replaced elbow angle detection with shoulder Y-position tracking
- Fixed critical baseline drift bug (3+ iterations)
- Made thresholds dynamic (scale with torso length)
- Changed to always use Y axis (ML Kit image space)

### Phase 6 — Features & Polish
- Custom workouts, rest timer, goals, streaks, badges, personal records
- Audio feedback (trimmed MP3s, fresh AudioPlayer per sound)
- Haptic feedback, theme switching, onboarding guide
- Rep stats (daily/weekly/monthly/yearly), tappable stat cards

### Phase 7 — Store Submission
- Google Play: signed release bundle, store listing, closed testing with 12 testers
- App Store: Codemagic iOS build, submitted for review
- Privacy policy on GitHub Pages

---

## Roadmap

### Immediate (Promotion phase — April 2026)
- Promote iOS App Store listing (live at £0.99)
- Complete Android 14-day testing period and go live on Google Play
- Fix remaining bugs (null check error in pushup_analyzer, rest timer landscape overflow)
- Monitor App Store reviews and fix critical issues fast

### Post-Launch (First month)
- Go live on Google Play
- Add squats (reuse same ML pipeline, train new model)

### Medium-term (Months 2-6)
- More exercises: pull-ups, dips, sit-ups
- Push-up variations: wide, diamond, pike, pseudo planche
- Workout plans and programs
- Subscription pricing model
- Advanced form coaching

### Long-term (6+ months)
- Video comparison (user vs ideal form)
- Voice coaching
- Social features / leaderboards
- Wearable integration
- Calorie estimation (requires body profile)

### NOT Building Yet
- User accounts / login
- Social features
- Video recording / playback
- Gender/height/weight profiles
- Advanced gamification beyond current badges

---

## Key Files

### Core Detection
- `lib/services/pushup_analyzer.dart` — Rep counting state machine
- `lib/services/pose_service.dart` — ML Kit wrapper
- `lib/services/ml_form_classifier.dart` — TFLite model wrapper
- `lib/utils/geometry.dart` — SmoothedValue, HysteresisTracker, RepDebouncer
- `assets/models/pushup_classifier.tflite` — Trained form classifier

### Screens
- `lib/screens/home_screen.dart` — Main menu, stats, streaks, goals
- `lib/screens/workout_screen.dart` — Live camera + rep counter
- `lib/screens/workout_summary_screen.dart` — Post-workout breakdown
- `lib/screens/history_screen.dart` — Workout history + charts
- `lib/screens/rest_timer_screen.dart` — Between-sets countdown
- `lib/screens/workout_setup_screen.dart` — Custom workout config

### Services
- `lib/services/workout_state.dart` — ChangeNotifier for live sessions
- `lib/services/database_service.dart` — SQLite storage
- `lib/services/audio_service.dart` — Sound effects playback

### Config
- `pubspec.yaml` — Dependencies, version (currently 2.1.0+50). Build number auto-incremented by pre-push git hook — never touch this manually
- `android/app/build.gradle.kts` — Android build config
- `android/key.properties` — Keystore config (DO NOT commit to public repo)

---

## Run Commands

```bash
# Development
cd E:\dev\rep_counter
flutter run -d RZCW311V2SE  # Run on Samsung A53

# Release build (Android)
flutter clean
flutter pub get
flutter build appbundle --release  # Creates .aab for Play Store

# iOS builds done via Codemagic (push to GitHub, Codemagic builds automatically)
git add .
git commit -m "description"
git push origin main
```

---

## Contact
- **Business email:** info.ohmslabs@gmail.com
- **Personal email:** omar.acx27@gmail.com
- **Apple ID:** omar.ac27@icloud.com
