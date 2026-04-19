# Changelog — Rep AI

All notable changes to this project are documented here.
Keep this file updated with every future change. Add new entries at the top.

---

## [2.6.0] — 2026-04-19 (Splash dark mode + cat pose + elbow flare — build 107)

### Fixed
- **Splash screen always light:** Launch screen was hardcoded to light colours regardless of device/system dark mode setting
  - Android: added `values-night/colors.xml` with dark splash background (`#0F172A`); corrected `drawable-v21/launch_background.xml` to use `@color/splash_background` and restored the launch icon
  - iOS: created `SplashBackground.colorset` with explicit light (`#F8FAFC`) and dark (`#0F172A`) variants; updated `LaunchScreen.storyboard` to reference the named color asset instead of `systemBackgroundColor`
- **Cat pose on knees counted as a rep:** `_hipCoActive` flag was set to `false` on a single frame of poor hip landmark visibility, silently disabling the hip co-movement check for the rest of the rep. The check now retains its accumulated values across brief tracking gaps — cat/stretch still rejected, knee push-ups still pass
- **Badly flared elbows counted as reps:** Elbow-spread threshold was `2.5× shoulderWidth` — too permissive for genuinely flared elbows (shoulders splayed out to the sides). Lowered to `2.0×`; wide-grip push-ups sit at ~1.4–1.8× and are unaffected

---

## [2.6.0] — 2026-04-19 (Onboarding auth + music-friendly audio — build 105)

### Added
- Onboarding now has 10 pages: new account page (page 9) between Goals and "You're all set"
  - Offers Google sign-in, Apple sign-in (iOS only), and email sign-in / create account toggle
  - "Skip for now" link at the bottom for users who don't want an account
  - Shows a confirmation card if the user is already signed in
- Audio settings accessible from the Workout hub: speaker icon in the header opens a bottom sheet with a mute toggle and a music-tip hint card
- Mute preference now persists to SharedPreferences — survives app restart

### Changed
- `WorkoutAudioService` elevated from a local workout-screen object to a root `ChangeNotifier` provider; mute state is now shared across workout hub, workout screen, and workout summary
- Workout-complete (triumph) SFX on the summary screen respects the mute toggle set during the workout — if muted during the session, no sound on summary
- Audio session configured for music-friendly mixing:
  - iOS: `AVAudioSessionCategory.ambient` + `mixWithOthers` — rep SFX plays over Spotify/Apple Music without interrupting or ducking it
  - Android: `gainTransientMayDuck` — briefly lowers other audio while SFX plays, then restores automatically

---

## [2.6.0] — 2026-04-19 (Push-up detection reliability — build 103)

### Fixed
- **Tracking stops mid-set (main bug):** A single `not_exercise` frame during a rep was calling `_goIdle()`, wiping all position tracking and resetting the state machine. During fast reps the geometric classifier can flicker to `not_exercise` for 1–2 frames (nose/shoulder relationship momentarily misread). Now requires **4 consecutive `not_exercise` frames** before going idle
- **Head position kills tracking:** `noseAboveShoulders > 0.20` threshold was returning `not_exercise` when the nose was only 20% above shoulders in the frame — easily triggered by looking at the camera or tilting the head during a push-up. Raised to `> 0.35`
- **Close camera kills tracking:** `shoulderY < 0.30` flagged the person as standing if shoulders appeared in the top 30% of the frame. With the phone on the floor, shoulders can sit at 0.22–0.28 mid-rep. Lowered to `< 0.18`
- **Knee push-ups silently rejected:** Hip co-movement check required hips to travel at least 40% of shoulder travel. Knee push-ups pivot at the knees so hips travel roughly 15–25% as much as the shoulders. Threshold lowered from 0.40 → 0.20 (still rejects lying cat/cow stretches where hips barely move)
- **Wide-grip flagged as bad form:** `elbowSpread > 1.8× shoulderWidth` was marking wide-grip push-ups as "Arms too wide". Threshold raised to 2.5× — only extreme/unintentional flaring is flagged now

---

## [2.6.0] — 2026-04-18 (Shelf landscape/side-view paths — build 100)

### Changed
- Side-view classifier shelved: `_geometricClassify` now always routes to `_classifyFrontView`; `_classifySideView` is kept in-code but not called — the app is portrait-only so the camera is always head-on
- Landscape detection branches in `pushup_analyzer` annotated as shelved; `_isLandscape` is always false in portrait mode so none of those paths are reached

---

## [2.6.0] — 2026-04-18 (Form detection tuning — build 99)

### Fixed
- "Hips too low" false positives: front-view hip sag threshold relaxed from 0.12 → 0.20 of frame height; a floor-level portrait camera produces up to ~15% perspective offset even with a perfectly flat plank
- Side-view hip sag thresholds relaxed (ankle reference: 0.06 → 0.09; shoulder-only fallback: 0.10 → 0.14) to stop penalising users with natural lumbar curve or a slightly elevated camera angle
- Front-view head-dropping threshold relaxed from 0.15 → 0.20; the nose naturally dips below shoulder level at the bottom of a full-depth rep
- Rep quality vote ratio changed from simple majority (bad ≥ good) to a clear-majority rule: a rep now only fails when bad-form frames exceed 60% of all exercise frames in portrait (55% in landscape) — isolated false-positive frames no longer flip an otherwise good rep

---

## [2.6.0] — 2026-04-18 (What's New + Feedback — build 98)

### Added
- What's New popup: appears automatically on first launch after an update; shows version-grouped changelog with bullet points; never shown twice for the same version (SharedPreferences tracks last-seen version)
- What's New button: new `new_releases` icon next to the help button on the home screen opens the changelog on demand at any time
- Feedback: "Send Feedback" entry under a new Support section in Settings; chooser sheet offers "Feature Request" or "Report an Issue"; each opens a text-input screen and submits anonymously to Firestore (`feedback` collection: type + message + server timestamp only — no user ID, device info, or personal data)
- Changelog history in What's New covers versions 2.1.0–2.3.0

---

## [2.5.0] — 2026-04-17 (Squircle splash icon + dialog polish — build 95)

### Changed
- Splash screen icon: launch image is now squircle-shaped (iOS App Store superellipse, n=5) with the blue gradient + white dumbbell, matching the marketing icon — transparent corners reveal the adaptive background
- Edit Name dialog title is now bold (`FontWeight.w700`), matching the Sign Out dialog and other headings
- Splash screen background: `systemBackgroundColor` follows iOS system dark/light mode; note — the app's in-app theme preference cannot be read before launch completes (iOS limitation), so the splash follows the device's system setting

### Added
- `tool/generate_launch_icons.dart`: Dart script to regenerate squircle launch images at 1x/2x/3x from scratch (no external dependencies)

---

## [2.5.0] — 2026-04-18 (Account polish + splash screen — build 94)

### Added
- Edit display name: pencil icon next to the name in the account profile screen opens a dialog to update it — works for any sign-in method (email, Google, Apple)
- Forgot password: "Forgot password?" link in the email sign-in form; if an email address is already typed it sends a Firebase password-reset email immediately, otherwise it prompts the user to enter one
- `AuthService.updateDisplayName()` and `AuthService.sendPasswordReset()` methods

### Changed
- Splash screen: replaced empty placeholder images with the real app icon (80 pt, scaled); added "Rep AI" label below the icon; background now uses `systemBackgroundColor` — white in light mode, system dark in dark mode — matching the app's current theme setting

---

## [2.5.0] — 2026-04-18 (Apple Sign-In investigation — builds 91–93)

### Changed
- Build 91: CHANGELOG update only, no app changes (build number bump after key rotation)
- Build 92: Apple Sign-In nonce strategy changed — pass raw nonce to `getAppleIDCredential` instead of pre-hashed value (Apple's native SDK hashes it internally)
- Build 93: Apple Sign-In rewritten to use Firebase's `signInWithProvider(AppleAuthProvider())` — removes manual credential + nonce path entirely; Firebase handles the native Apple flow and token exchange internally
- `sign_in_with_apple` package no longer used in `auth_service.dart` (retained in UI layer for `isAvailable()` check only)
- Removed `crypto` package dependency from auth service

### Investigating
- `[firebase_auth/invalid-credential] Invalid Auth response from apple.com` persists across all nonce strategies and Firebase private key rotation; root cause not yet identified

---

## [2.5.0] — 2026-04-17 (Auth debug — build 90)

### Changed
- Apple Sign-In error handler temporarily shows raw Firebase error for debugging

---

## [2.5.0] — 2026-04-17 (Auth fixes — build 89)

### Fixed
- Google Sign-In crash: added explicit `clientId` to `GoogleSignIn` constructor; added `openURL` forwarding in `AppDelegate.swift`
- Apple Sign-In: added null guard on `identityToken`; Apple-specific error messages instead of generic email/password copy
- Sign Out dialog title is now bold to match other headings
- `firebase_options.dart`: replaced placeholder values with real Firebase project credentials
- `Info.plist`: added `REVERSED_CLIENT_ID` URL scheme for Google Sign-In redirect
- Apple Sign-In nonce: proper SHA-256 nonce generation and verification flow
- Added `crypto` package for nonce hashing

---

## [2.5.0] — 2026-04-17 (Build fixes — build 86)

### Fixed
- iOS CocoaPods build failure: bumped iOS deployment target to 15.5 (required by `google_mlkit_pose_detection` 0.14.x)
- Upgraded `google_mlkit_pose_detection` to 0.14.1 to resolve `MLKitVision`/`MLKitXenoCommon` beta version conflict
- Replaced placeholder Firebase config files with real credentials (Android `google-services.json`, iOS `GoogleService-Info.plist`)
- Added `Runner.entitlements` with Sign In with Apple capability and wired into all Xcode build configs
- Removed orphaned `_buildMonthlyRepCard` method and unused `dart:typed_data` import (flutter analyze warnings)

---

## [2.5.0] — 2026-04-17 (Cloud Sync + Account + Home screen polish — build 79)

### Added
- Optional user accounts (Email, Google, Apple Sign In) — entirely optional; offline mode works fully without an account
- Cloud sync via Firestore: workout history, streak, goals, badges, and settings follow the user across devices on sign-in
- Account screen accessible from home screen header avatar and Settings → Account
- "Sync Now" button in the account profile screen to manually push/pull data
- Settings screen gains an Account row at the top linking to the account screen

### Changed
- Home screen header: replaced "Rep AI" title with a time-of-day greeting ("Good morning / afternoon / evening") and today's date; account avatar button in top-right (shows initial when signed in)
- Removed redundant Exercise Guide icon from home screen header (accessible via Workout tab)
- Stats section redesigned as a 2×2 grid: Sessions, This Month, Today's Reps, Avg Form — replaces 3-card row and removes the separate monthly rep card
- "Overview" section header added above the stats grid for clearer navigation hierarchy
- "Badges" section header upgraded to headlineMedium to match other section headers
- Session cards now display good-form rep count (more accurate than total attempts); date format cleaned up to "Apr 17 · 2:30 PM"

### Technical
- New: `lib/firebase_options.dart` (placeholder — replace with `flutterfire configure` output)
- New: `lib/services/auth_service.dart` — Firebase Auth wrapper (ChangeNotifier)
- New: `lib/services/cloud_sync_service.dart` — Firestore push/pull (batch writes, merge on sign-in)
- New: `lib/screens/account_screen.dart` — sign-in / profile UI with 3 states
- `AuthService` + `CloudSyncService` wired into provider tree in `main.dart`
- Android: `google-services.json` placeholder + `com.google.gms.google-services` plugin
- iOS: `GoogleService-Info.plist` placeholder

### Firebase setup required before cloud sync activates
1. Create a Firebase project at https://console.firebase.google.com
2. Add Android app (`com.repcounter.rep_counter`) and iOS app to the project
3. Replace `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`
4. Run `flutterfire configure` to regenerate `lib/firebase_options.dart`
5. Enable Email/Password, Google, and Apple Sign In in Firebase Console → Authentication
6. Firestore rules: allow users read/write only to `/users/{their_uid}/**`

---

## [2.4.0] — 2026-04-17 (Stage 3 final tweaks — build 77)

### Changed
- "Push Ups" title in the workout bottom sheet is now bold (fontWeight w800), matching other headings in the app
- Exercise Guide chip row auto-scrolls to keep the selected variation visible when swiping — Pike, Decline and any off-screen chip are automatically centered in the row
- Quick Workout now skips the pre-workout form guide and starts the session immediately; users can still view the guide via the Form Guide button before starting
- Custom Workout (Start Workout button) now skips the pre-workout form guide and goes straight into the workout; same rationale — guide is available separately

### Technical
- `_chipKeys` list of `GlobalKey`s added to `ExerciseGuideScreen`; `Scrollable.ensureVisible` called on `onPageChanged` and `_selectVariation`
- `WorkoutHubScreen` imports `WorkoutState` provider; quick workout path calls `startSession` then navigates to `/workout`
- `WorkoutSetupScreen` navigates to `/workout` directly instead of `/guide`

---

## [2.4.0] — 2026-04-16 (Push Ups exercise hub + wide-elbow fix — build 75)

### Changed
- Wide grip push-up bottom elbow now draws back behind the shoulder (same direction as all other variations) instead of forward; the joint now visually moves toward the ground as it should
- Workout tab redesigned: replaced direct Quick/Custom buttons with an exercise category list — "Push Ups" card is the first entry
- Tapping "Push Ups" opens a bottom sheet with three options: Form Guide (opens animated exercise guide), Quick Workout, and Custom Workout; designed to extend with more exercises later

### Technical
- `WorkoutHubScreen` split into `_ExerciseCard` and `_ExerciseOptionsSheet` helper widgets
- `ExerciseGuideScreen` imported into `WorkoutHubScreen` for direct push navigation

---

## [2.4.0] — 2026-04-16 (Workout hub, guide polish, wide-elbow fix — build 71)

### Changed
- Wide grip bottom elbow fixed: was pointing upward (y=0.66, above shoulder y=0.70); now sits directly above the hand with a vertical forearm and horizontal upper arm (y=0.73, below shoulder), correctly pointing toward the ground
- Exercise Guide now responds to horizontal swipes anywhere on the screen, not only on the animation card (translucent screen-level GestureDetector)
- Quick Workout and Custom Workout buttons moved from the Home screen to the Workout tab, which now shows a dedicated hub screen
- Pre-workout animation guide (shown before every session) redesigned to match the Exercise Guide: PageView outside vertical scroll, animated dot indicators, swipe-anywhere, AnimatedSwitcher for the key-points card

### Technical
- New `WorkoutHubScreen` added; wired into `MainShell` `IndexedStack` as tab 1
- `_stackIndex` in `MainShell` is now a direct 1-to-1 mapping (simplified from the previous offset-based approach)
- Camera permission request moved from `HomeScreen._launchWorkout` to `WorkoutHubScreen`
- `HomeScreen._launchWorkout` and `_buildWorkoutButtons` removed

---

## [2.4.0] — 2026-04-16 (Exercise Guide swipe fix — build 70)

### Fixed
- Swiping the animation in the Exercise Guide now reliably changes the variation: moved the PageView outside the outer vertical ListView so horizontal swipes are never ambiguous and always handled by the PageView
- Added animated page-indicator dots below the animation so it is visually clear the card is swipeable

---

## [2.4.0] — 2026-04-16 (Pike elbow direction fix — build 69)

### Changed
- Pike push-up bottom elbow now points downward toward the ground (draws back and down from the shoulder, matching the decline push-up style) instead of upward

---

## [2.4.0] — 2026-04-16 (Wide push-up animation rework — build 68)

### Changed
- Wide push-up animation overhauled: hand moved from x=0.83 to x=0.80 so the arm length is proportional (the old value made the arm look longer than standard, not wider)
- Bottom elbow now flares forward/outward to correctly show the wide-grip elbow flare, instead of drawing back behind the shoulder like a standard push-up
- Shoulder drops slightly lower at the bottom to reflect the greater range of motion a wide stance allows
- 'Arms wide' callout anchor updated to match new hand position

---

## [2.4.0] — 2026-04-16 (UI and animation fixes — build 67)

### Changed
- Question mark button on the home screen now re-opens the startup / onboarding guide (swipeable walkthrough), not the exercise guide
- Exercise guide gets its own dedicated button (dumbbell icon) next to the question mark in the home screen header
- Pike push-up bottom elbow fixed: was incorrectly at the same height as the shoulder making the bend look inverted; now clearly points upward above both the shoulder and hand, creating a correct acute-angle bend

---

## [2.4.0] — 2026-04-16 (Stretch rejection — build 66)

### Changed
- Cat-pose / lying back-stretch no longer counts as a rep: the analyzer now compares hip travel to shoulder travel each rep attempt; if the hips barely moved relative to the shoulders (ratio below 40%) the rep is discarded without affecting good/bad-form indicators

### Technical
- `PushUpAnalyzer` now tracks a smoothed hip-Y signal (α = 0.4) alongside the existing shoulder signal
- `_hipTopValue` / `_hipBottomValue` record the hip range-of-motion during each attempt
- `_hipCoActive` flag gates the check — only applied when hip landmarks were visible for the full attempt, avoiding false rejections when the camera angle obscures the hips
- Stretch rejection runs in `_finishRep()` before the debouncer; discarded attempts call `_goIdle()` cleanly without incrementing any counter

---

## [2.4.0] — 2026-04-16 (Animation fixes and swipe guide — build 65)

### Changed
- Wide grip bottom elbow fixed: was bending the wrong way (obtuse angle); now correctly draws back behind the shoulder for a clear acute angle
- Pike push-up flipped to face RIGHT, consistent with all other variations
- Pike bottom elbow fixed: elbows now correctly rise up and forward as you lower (acute angle)
- Phone indicator repositioned to sit on the ground line for every variation (bottom of phone touches the floor)
- Swipe navigation added to the Exercise Guide: swipe the animation left/right to browse variations; tapping a chip still works and animates the page smoothly
- Key points card fades when switching variation
- Bullet points: removed all em dashes from text; "1–2 metres" rewritten to "1 to 2 metres"

---

## [2.4.0] — 2026-04-16 (Bad-form gallery — build 64)

### Changed
- Bad-form screenshots are now kept in memory only — no disk writes at all
- Tapping a thumbnail opens a swipeable full-screen gallery (PageView) starting at the tapped photo
- Swipe left/right to browse all bad-form captures in one go
- Animated page indicator dots shown when there are multiple captures
- Issues overlay updates as you swipe to match the current photo
- Removed delete button (photos are discarded automatically when you leave the summary)
- Privacy note updated: "Captured in memory only. Nothing is saved or uploaded."

### Technical
- `BadFormCapture.filePath` replaced by `BadFormCapture.imageBytes: Uint8List`
- `WorkoutScreen._saveCapturesToDisk()` removed; `_pendingCaptures` mapped directly to `BadFormCapture` in `_endWorkout`
- `path_provider` import removed from `workout_screen.dart`
- `WorkoutSummaryScreen._captures` is now a getter (no mutable copy needed)
- `_BadFormViewer` replaced by `_BadFormGallery` with `PageController` + `InteractiveViewer` per page

---

## [2.4.0] — 2026-04-16 (Stage 3 animation polish — build 63)

### Changed
- **Phone indicator** moved to be in front of the figure's head (right edge for all horizontal variations; left/floor edge for pike) instead of the far-left background
- **Arms straight at top position**: elbow is now collinear with shoulder and hand for all six variations — no more obtuse angle at the top
- **Body alignment fixed**: hip and knee now lie on the shoulder-to-ankle plank line for all non-pike variations in both top and bottom poses — no more raised-butt appearance
- **Pike push-up** redesigned with a wider, more realistic inverted-V (~40° between torso and legs vs the previous near-acute shape); hands and feet stance is wider; hip is at a realistic training height
- **Head-forward movement** added to pike and decline: head moves toward the floor as the figure lowers, matching the real movement pattern
- **Decline head** fixed — was previously drawn at the same position as the elbow; now correctly positioned forward of the shoulder
- **Bullet points** rewritten across all six variations: plain language, no jargon, shoulder protraction cue included, no filler points
- Callout anchor positions updated to match corrected figure geometry

---

## [2.3.0] — 2026-04-16 (Stage 2 revised — build 62)

### Changed
- Per-rep bad-form screenshots replace the single "worst moment" capture
  - One screenshot is captured per bad-form rep (at the frame of peak bad-form confidence within that rep, not during setup)
  - Screenshots are saved to the app's documents directory at the end of the session
  - Workout Summary shows a horizontal thumbnail strip — "Bad Form Captures (N)"
  - Tap any thumbnail → full-screen viewer with pinch-to-zoom and issue overlay
  - Delete button in the full-screen viewer removes the photo from the device with a confirmation dialog
  - If file save fails, the session still completes and the issues list is shown without thumbnails

### Technical
- `BadFormCapture` model added to `workout_models.dart` (`filePath`, `issues`, `repNumber`)
- `WorkoutScreen`: per-rep capture state (`_pendingCaptures`, `_currentRepImage`,
  `_currentRepBestBadScore`, `_lastRepHistoryLen`); frames saved via
  `_saveCapturesToDisk()` using `path_provider` into `rep_ai_bad_form/`
- `WorkoutSummaryScreen`: `worstFormImage` replaced by `List<BadFormCapture> badFormCaptures`;
  mutable `_captures` state updated live on delete; new `_BadFormViewer` widget
- `_RepCapture` private struct holds in-memory data between frame capture and session end

---

## [2.4.0] — 2026-04-16

### Added
- Pre-workout form guide shown before every session
  - Animated side-view stick-figure demonstrating the push-up movement
  - Smooth 4-phase loop: extend at top → lower → hold at bottom → rise
  - Appears when the user taps the Workout tab or starts a custom workout
  - "Let's Go" button starts the workout once the user is ready
- Six animated variation guides with per-variation form callout labels:
  Standard, Wide Grip, Diamond, Knee, Pike, Decline
  - Each animation shows the full range of motion for that variation
  - Two labelled callout annotations on the canvas (e.g. "Flat back", "Shoulder-width")
    pointing directly to the relevant body parts; labels fade gently during motion
    and return to full opacity when the figure holds at the top position
  - Subtle camera placement indicator (phone outline at chest height, left edge)
    showing where to position the phone relative to the exercise
  - Swipeable chip selector to browse all six variations
  - Key form-point list below each animation
- Exercise Guide screen updated with the same animated widget replacing static text
- Home screen `?` (help) icon now opens the Exercise Guide directly

### Technical
- New `PushUpAnimationWidget` (`lib/widgets/pushup_animation.dart`) — `CustomPainter`
  with 6 sets of top/bottom pose keyframes; lerps on a smooth 4-phase cycle.
  Added `_CalloutDef`, `_calloutsFor()`, `_drawCallout()`, and `_drawPhoneIndicator()`
  for on-canvas annotations. Callout opacity driven by animation phase.
- New `PreWorkoutGuideScreen` (`lib/screens/pre_workout_guide_screen.dart`)
- Workout tab routes to `/guide` before `/workout`; custom setup also routes through guide
- Home screen `?` icon navigates to `ExerciseGuideScreen` (onboarding replay removed from header)

---

## [2.3.0] — 2026-04-16

### Added
- Worst form screenshot on workout summary screen
  - Camera preview is captured at the moment of highest bad-form confidence during the session
  - Displayed as a photo card on the summary screen after the workout ends
  - Labelled "Worst form moment" with a red overlay badge
  - Only shown if the session had bad form reps
- Natural-language issues list under the screenshot (e.g. "Hips too low on 3 reps")
- Privacy note on the card: "Captured on this device only. Nothing is saved or uploaded."
- "Form Review" section replaces Stage 1's plain issues list, incorporating both the screenshot and the issues summary in one card

### Technical
- Camera preview wrapped in `RepaintBoundary`; `toImage()` captures at 0.5× pixel ratio (thumbnail quality, minimal memory)
- Image stored as `Uint8List` in widget state only — never written to disk, cleared when session ends
- Capture triggers only when bad-form confidence exceeds previous peak by 5+ points, preventing redundant captures

---

## [2.2.0] — 2026-04-16

### Added
- Specific form feedback: the app now identifies *why* a rep had bad form, not just that it did
  - Named issues detected: "Hips too low", "Arms too wide", "Head dropping", "Head too high", "Not going low enough", "Going too deep"
  - Geometric classifier updated to collect a named issues list instead of a pass/fail boolean
  - `MLFormClassifier.diagnoseIssues()` added so Android's TFLite path also gets specific issue labels via geometric analysis
  - `PushUpAnalyzer` accumulates per-frame issue votes and stores the dominant issue(s) in each `RepResult`
- Live form issue hint: form badge in workout screen now shows the specific issue in real time (e.g. "Hips too low" instead of "Fix Form")
- Bad-rep flash now shows the specific reason (e.g. "Arms too wide — not counted")
- Form Issues summary card on workout summary screen — aggregates issues by frequency (e.g. "Hips too low — 3 reps")
- Per-rep breakdown on summary screen now shows the specific issue per bad rep

### Fixed
- Bad-rep flash was never showing due to a `< Duration.zero` comparison bug — fixed to 3-second display window

---

## [Unreleased] — 2026-04-15 (patch 2)

### Fixed
- Build number bumped to +50 (was +49, same as last App Store upload — caused duplicate CFBundleVersion rejection on Codemagic)
- Pre-push git hook installed at .git/hooks/pre-push — automatically increments build number in pubspec.yaml and commits before every push, so Codemagic always receives a higher build number

---

## [Unreleased] — 2026-04-15

### Added
- Onboarding expanded to 9 pages with three new goal and personalisation screens:
  - Fitness level picker (Beginner 20/day, Intermediate 50/day, Advanced 100/day) — pre-fills daily goal, persisted as `fitness_level`
  - Active training days — 7-day chip toggles, all on by default, minimum 1 day always required, persisted as `active_workout_days`
  - Daily goal page — stepper for push-ups per day with computed weekly total shown automatically (daily x active days); weekly total is no longer a separate input
  - Final page explicitly tells users the question mark button returns them to this guide at any time
- Workout history auto-refreshes every time the History tab is opened (GlobalKey + refresh() on tab focus via IndexedStack), on top of the existing WorkoutState end-session listener
- Active training days section in Settings — same 7-chip toggle so users can update their training schedule after onboarding
- Select button in workout history AppBar — tap to enter multi-select mode without long-pressing
- Delete Selected bottom bar in history — full-width red button showing count, disabled until at least one workout is selected

### Changed
- Weekly goal on home screen now derived live as `daily_goal x active_days_count` — changing days or daily goal in Settings updates the home screen immediately when the tab is focused
- Editing the weekly goal on the home screen now writes back a new daily target (weekly / active_days) instead of a separate weekly override, keeping one source of truth
- "Week starts on" setting relabelled to "Weekly goal resets on"
- History screen dates are now human-readable: "Today at 3:05 PM", "Yesterday at 9:10 AM", "Monday 14 Apr at 6:20 PM"
- History empty state updated to plain friendly message
- Workout summary "Done" button relabelled "Back to Home"
- Settings: each setting now has a one-line plain-English subtitle
- All em dashes and sentence-break dashes replaced with full stops across all user-visible text
- Onboarding copy rewritten throughout — short titles, plain English, no jargon, no filler, sentence case only
- Removed inline workout labels ("Camera is tracking your form", "Push-ups counted") — onboarding covers this
- Removed motivational lines from workout summary screen

### Fixed
- History AppBar in select mode now shows only a close button; delete action moved to bottom bar
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
