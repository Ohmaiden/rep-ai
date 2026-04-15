# Changelog — Rep AI

All notable changes to this project are documented here.
Keep this file updated with every future change. Add new entries at the top.

---

## [Unreleased] — 2026-04-15

### Added
- Improved onboarding flow: 6 clean informational screens replacing the fitness-level/goal-setter flow
  - Screen 1: Welcome to Rep AI
  - Screen 2: How it works (phone placement, distance, side view)
  - Screen 3: What you can do (quick/custom workouts, streaks, goals, badges, history)
  - Screen 4: Push-ups supported (standard, wide, diamond, pike; more coming)
  - Screen 5: Tips for best results (pace, lighting, framing, ding feedback)
  - Screen 6: You're ready! — "Get Started" button navigates to home
  - All screens: swipeable, dot indicators, Skip button, portrait + landscape aware
- Select button in workout history AppBar — tap to enter multi-select mode without long-pressing
- Delete Selected bottom bar in history: full-width red button showing count, disabled until at least one workout is selected
- Auto-refresh history screen after a workout ends — WorkoutState listener added to history_screen.dart so history, calendar, and monthly totals update without pull-to-refresh

### Changed
- History AppBar in select mode now shows only a close (✕) button; delete action moved to bottom bar
- History AppBar when not in select mode shows "Select" text button alongside the clear-all icon

### Previously added (since v2.0.0)
- Exercise guide screen accessible from home screen header
- FAQ screen in settings
- Portrait-only lock enforced on iPhone, iPad, and Android (UIRequiresFullScreen set for iOS)
- Confetti animation on workout summary screen
- Audio fixes: fresh AudioPlayer per sound to prevent pool exhaustion on fast reps
- Goal breakdowns: weekly goals split into daily targets
- Tappable numbers on home screen to edit daily/weekly targets inline
- Badges with unlock descriptions and earned dates
- Goals toggle in Settings to fully disable goal tracking

---

## [2.0.0] — 2026-03-22 — Public Release

### Release
- versionCode bumped to 3, versionName set to 2.0.0
- Release AAB built (102.3 MB) and uploaded to Google Play Console

---

## [Unreleased] - 2026-03-22 (patch 7)

### Changed
- Goals toggle now fully disables goal tracking (not just display)
- Weekly goal reset day is now user-configurable (Settings → "Week starts on"); defaults to Monday
- "Resets Monday" label dynamically reflects the chosen start day

### Fixed
- goals_visible key renamed to goals_enabled for semantic accuracy
- Comprehensive pixel overflow prevention sweep applied app-wide
  - All bottom sheets capped at 85% screen height with SafeArea + SingleChildScrollView + keyboard inset padding
  - Daily/weekly goal text rows wrapped in Flexible with ellipsis to prevent row overflow
  - Session card exercise name capped at 1 line with ellipsis

---

## [Unreleased] - 2026-03-22 (patch 6)

### Changed
- Goals visibility toggle moved from home screen eye icon to Settings screen
- Daily goal carry-over removed — today's target is always base daily target (weekly ÷ days/week), no deficit added from missed days
- Streak now resets to 0 on app load if last workout was before yesterday (stale streak fix)

### Fixed
- Goal reset bug: editing weekly goal no longer overwrites a custom daily target; custom daily is only recalculated if none was explicitly set
- Consolidated duplicate daily target fields (`_dailyTarget` / `_adjustedDailyTarget`) into one source of truth
- Onboarding tap-to-type dialogs (weekly reps, days/week) replaced with bottom sheet — no more pixel overflow when keyboard opens in landscape

---

## [Unreleased] - 2026-03-22 (patch 5)

### Added
- Goals visibility toggle (eye icon) — show/hide goal progress on home screen, persisted
- New onboarding slide: "Follow the ding" — tip on rep counting pace and feedback

### Fixed
- Custom daily/weekly goal values no longer reset on app restart
- Replay onboarding dialog title now bold

---

## [Unreleased] - 2026-03-22 (patch 4)

### Fixed
- SFX now fires synchronously with rep counter increment in both portrait and landscape

---

## [Unreleased] - 2026-03-22 (patch 2)

### Added
- Tap-to-edit goal targets directly on home screen progress rows (Option A)
- "✎ tap to edit" hint under daily and weekly progress displays

### Changed
- Removed dedicated goal card from home screen
- Form badge full text visible in landscape (no truncation)
- Landscape rep detection debounce reduced for faster form feedback and SFX

### Fixed
- Comprehensive pixel overflow sweep across all screens

---

## [Unreleased] - 2026-03-22 (patch 3)

### Fixed
- Daily/weekly goal edit bottom sheet overflow in landscape mode

---

## [Unreleased] - 2026-03-22

### Added
- 5-screen onboarding flow replacing the original 3 static screens:
  - Fitness level picker (Beginner / Intermediate / Advanced) with preset weekly rep goals (50 / 150 / 300)
  - Phone placement illustration with portrait and landscape orientation support (OrientationBuilder)
  - Camera permission primer screen before system permission dialog
  - Goal setter with weekly reps + days per week pickers, live "= X reps/day" calculation
  - Tappable number fields throughout — tap any number in +/- pickers to type a custom value
  - Hint text below all pickers: "Tap the number to type a custom value"
- Help icon on home screen to replay onboarding at any time
- Confetti animation on workout summary screen (plays once on load, no new packages)
- Upside-down / wrong-orientation phone detection during workout:
  - Angle-based logic: 90° (camera left) → "Flip your phone 180°, camera should be on your right"; 180° (portrait upside down) → "Flip your phone, camera should be at the top"; 270° = correct; 0° = correct
  - Spinning + pulsing phone icon on the overlay
  - 10-frame debounce to avoid false positives
- Daily rep target on home screen with carry-over logic:
  - Today's adjusted target = base daily target + deficit from missed reps
  - Carry-over note shown when deficit > 0
  - Week total progress displayed alongside daily target
- Monthly rep tracking card on home screen (total reps for current month, replaces monthly goal)
- Bottom navigation bar: Home / Workout / History / Settings tabs
  - Hidden on workout screen, onboarding, rest timer
  - IndexedStack preserves state per tab
  - Settings screen with theme toggle extracted
- Scrollable calendar in History screen with Month / Week toggle:
  - Month view: horizontal scroll through all months with data, current month highlighted
  - Week view: horizontal scroll through 7-day week blocks with mini bar chart per day
  - Tap a week card → bottom sheet showing Mon–Sun individual daily rep counts and week total
- Multi-select delete in workout history:
  - Long press to enter select mode
  - Tap to select/deselect (blue border on selected)
  - Trash icon in AppBar, confirmation dialog before deleting
  - Back to exit select mode
- Landscape push-up detection accuracy improvements:
  - Landmark coordinates rotated to match screen orientation before analysis
  - Rep counter switches from shoulder Y (portrait) to shoulder X (landscape side-view)
  - Visibility threshold lowered to 0.5 in landscape
- Preset weekly goals by fitness level during onboarding
- System theme default (matches phone system theme on first install)
- Welcome screen hint: "Theme matches your system. Tap ⚙ Settings to change it anytime."

### Improved
- Smooth screen transitions: fade (250ms) for all routes, slide-up (300ms) for workout
- Camera loading fades in smoothly (no black flash), pulsing spinner while initialising
- All screens overflow-safe (LayoutBuilder + SingleChildScrollView, SafeArea)
- Onboarding landscape: all 5 pages use 2-column split layout (icon left / content right), centred vertically
- Goal setter supports up to 5-digit numbers (99999) on one line with FittedBox
- Workout screen landscape: overlay panel docks to right side, timer pinned bottom-left
- "End Workout" button: single line in landscape with FittedBox, proper width
- Form badge (Good Form / Fix Form) constrained to panel width, no overflow
- Lock screen recovery: camera reinitialises silently on unlock; if locked 10+ min, auto-navigates to summary
- Week detail bottom sheet: scrollable in landscape, capped at 85% screen height, SafeArea
- History screen: SafeArea + bottom padding so nothing cut off behind Android nav
- Launcher icon dumbbell scaled down 20% across all mipmap densities
- All fitness_center icon sizes reduced 20% app-wide

### Fixed
- Pre-existing deprecation warnings in history_screen.dart and home_screen.dart (withOpacity → withValues)
- use_build_context_synchronously lint issues resolved
- Fitness level card text wrapping in landscape
- Camera placement illustration overflow in landscape (ClipRect + proportional sizing)

---

## [1.0.0] — 2026-03-18 — Public Release

### Added
- AI push-up detection with on-device TFLite classifier
- Good form only rep counting
- Quick workout and custom workout modes
- Rest timer with adjustable duration
- Workout history, streaks, goals, badges, personal records
- Audio and haptic feedback
- Light/dark theme support
- Onboarding and help guide
- Full privacy: all processing on-device

### Technical Stack
- Flutter 3.41.4 / Dart
- Google ML Kit Pose Detection (on-device, 33 landmarks)
- Custom TFLite classifier (~6500 labeled training frames)
- SQLite (sqflite + sqflite_common_ffi)
- Provider state management
- fl_chart for charts
- audioplayers for sound effects
- Target: Android 8+ (API 21+)

---

## Development History

### Phase 7 — Store Preparation (2026-03-16 to 2026-03-18)
- App renamed from "Rep Counter" to "Rep AI" everywhere
- App icon: diagonal dumbbell (45 deg), white on blue #2563EB, 2 plates per side ascending
- Splash screen with app branding
- Privacy policy created (privacy_policy.html) and hosted
- Google Play Developer account created
- Store listing written: description, short description, tags, category
- Feature graphic created (1024x500)
- App icon exported as 512x512 PNG for Play Store
- App bundle built: build\app\outputs\bundle\release\app-release.aab
- CHANGELOG.md created documenting full development history

### Phase 6 — Features and Polish (2026-03-16 to 2026-03-18)
- Custom workout mode: configurable sets, reps per set, rest time
- Rest timer screen with circular countdown, -10s/+10s adjustment buttons, skip button
- Auto-transition to rest timer when set target reached
- Auto-end workout after final set with full-screen summary
- Rep counter clamped to target in custom mode (never exceeds set target)
- Post-workout summary changed from bottom sheet overlay to full-screen page
- Per-set and per-rep breakdown in summary
- Workout history with swipe-to-delete and clear all
- Individual workout deletion from history
- Daily streak tracking with fire emoji and calendar view
- Calendar shows workout days highlighted, tap for day details
- Personal records: best streak, most reps, best form score
- New record badge on summary screen when records are broken
- Goals system: daily/weekly/monthly targets with progress bar
- Goal breakdown: weekly goals split into daily targets, monthly into weekly
- Badges and achievements system (First Workout, Week Warrior, 100 Club, Perfect Form, Consistent, Goal Crusher)
- Rep statistics: today/this week/this month/this year/all time
- Tappable stat cards showing detailed breakdowns
- Audio feedback: good_rep.mp3, bad_rep.mp3, set_complete.mp3
- Audio files trimmed in Audacity to remove leading silence
- Fresh AudioPlayer per sound to prevent pool exhaustion on fast reps
- Workout complete sound plays on summary screen appearance
- Haptic feedback on good and bad reps
- Light mode, dark mode, system-follow theme with settings toggle
- Onboarding: 3-screen first-time guide, saved to SharedPreferences
- Help button (?) on home screen to revisit guide anytime
- Settings screen accessible from home screen
- Camera permission handling with friendly message and open-settings button
- No-pose hint after 10 seconds without detection
- 0-rep workouts don't save to history
- App handles backgrounding and resuming (camera restarts)
- Wakelock during workouts
- Status bar contrast fixed for light and dark backgrounds
- SafeArea and MediaQuery padding for Android navigation bar on all screens

### Phase 5 — Rep Counting Overhaul (2026-03-15 to 2026-03-16)
- Removed angle-based elbow threshold rep counting
- Replaced with shoulder midpoint Y-position tracking (works from any camera angle)
- Fixed critical baseline drift bug: _topValue was chasing signal downward every frame, preventing rep detection after first set
- Fix: lock _topValue after 8 settling frames, then hold it fixed
- Fixed _finishRep setting _topValue to bottom position: changed to _topValue = null and re-establish on next UP
- Added _bottomValue tracking in DOWN state for proper rise detection
- Made thresholds dynamic: scale with torso length (15% drop for DOWN, 10% rise for UP)
- Removed deviceAngle axis swapping — ML Kit landmarks are always in image space, always use Y axis
- Only good form reps increment the visible counter; bad form tracked silently in background
- Added null guards on all _topValue! and _bottomValue! operators to prevent red error screens

### Phase 4 — AI Model Training (2026-03-13 to 2026-03-14)
- Built data collection screen for recording labeled pose landmark data
- Labels simplified to: good_form, bad_form, not_exercise (instead of granular per-frame labels)
- Collected training data: 1,432 good_form + 1,796 bad_form + 2,255 not_exercise = 6,168 frames
- Additional 507 good_form frames collected to balance dataset
- Trained TFLite classifier on landmark data (66 input features = 33 landmarks x x,y)
- Model accuracy: 92.7% test accuracy, 97% good_form recall
- Integrated trained model (pushup_classifier.tflite) into Flutter app via MLFormClassifier service
- Replaced all hard-coded angle-based form checks with ML model classification
- Form quality determined by frame voting: majority good_form frames = good rep, majority bad_form = bad rep

### Phase 3 — Camera and Detection Fixes (2026-03-11 to 2026-03-13)
- Switched from back camera to front camera for solo use
- Fixed camera preview squishing in landscape mode using LayoutBuilder
- Added front camera mirroring for skeleton overlay (before skeleton was removed)
- Removed skeleton overlay entirely for major performance improvement
- Removed all real-time form text from workout screen — moved to post-workout summary
- Simplified workout screen to: camera feed + big rep counter + timer + end button
- Added landscape and portrait rotation support
- Resolution increased to ResolutionPreset.high, later to ResolutionPreset.veryHigh (1080p)

### Phase 2 — Core App Architecture (2026-03-09 to 2026-03-11)
16 initial Dart files created:
- main.dart: App entry point, theme, routes, orientation support
- workout_models.dart: WorkoutSession, RepResult, PoseMetrics, ExercisePhase
- pose_service.dart: Google ML Kit Pose Detection wrapper, returns normalized landmarks
- pushup_analyzer.dart: Push-up state machine with angle-based detection (later replaced)
- workout_state.dart: ChangeNotifier managing live workout sessions
- database_service.dart: SQLite storage with desktop FFI compatibility
- geometry.dart: calcAngle, SmoothedValue, HysteresisTracker, RepDebouncer
- home_screen.dart: Exercise selection, stats, recent workouts
- workout_screen.dart: Live camera with rep counter
- history_screen.dart: Workout history with charts
- pose_overlay.dart: Skeleton drawing (later removed for performance)
- rep_counter_display.dart: Animated rep counter widget
- form_feedback_display.dart: Real-time form warnings
- session_summary_sheet.dart: Post-workout summary

### Phase 1 — Flutter App Setup (2026-03-08 to 2026-03-09)
- Set up Flutter development environment on Windows 11 with VS Code
- Flutter SDK installed at C:\flutter via VS Code extension
- Android Studio installed for Android SDK (API 36)
- Project created: flutter create rep_counter --org com.repcounter
- Samsung Galaxy A53 (SM-A536B, Android 16) acquired as test device
- USB debugging configured, device ID: RZCW311V2SE
- Fixed CardTheme to CardThemeData for Flutter 3.41+ compatibility
- Fixed sqflite for Windows desktop: added sqflite_common_ffi with FFI initialization
- Fixed folder typo: utlis to utils

### Phase 0 — Python Prototype (2026-03-06 to 2026-03-08)
- Built initial push-up detection using Python + MediaPipe + OpenCV on Windows laptop
- iPhone streamed video via Iriun Webcam to laptop
- MediaPipe Tasks API with pose_landmarker_lite.task model
- Custom state machine for rep counting (UP to DOWN to UP = 1 rep)
- Implemented signal smoothing (EMA filter), hysteresis tracking, and rep debouncing
- Form checks: elbow depth, hip sag, hip pike, head position, tempo
- Debug overlay showing real-time metric values
- Discovered MediaPipe lite model reports elbow angles ~25 deg higher than visual reality (e.g. 113 deg when arms visually at 90 deg)
- Calibrated thresholds to real measurements: down=125 deg, up=145 deg
- Identified that hard-coded angle thresholds don't work across different bodies, clothing, and camera angles
