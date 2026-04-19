/// Workout Screen
/// ===============
/// Premium, minimal workout view. Camera feed with floating rep counter.
/// Supports both free mode and custom sets mode.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/workout_models.dart';
import '../services/pose_service.dart';
import '../services/workout_state.dart';
import '../services/database_service.dart';
import '../services/audio_service.dart';
import 'rest_timer_screen.dart';
import 'workout_summary_screen.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _cameraController;
  PoseDetectionService? _poseService;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String? _errorMessage;
  bool _permissionDenied = false;
  bool _navigatingToRest = false;
  bool _finishing = false;
  bool _isRecovering = false;
  DateTime? _pausedAt;

  // Per-rep bad-form screenshot capture.
  // Frames are held in memory during the session; saved to disk at the end.
  final GlobalKey _cameraPreviewKey = GlobalKey();
  final List<_RepCapture> _pendingCaptures = [];
  Uint8List? _currentRepImage;           // best frame captured so far in current rep
  double _currentRepBestBadScore = 0.0;  // highest bad-form score seen in current rep
  int _lastRepHistoryLen = 0;            // used to detect when a new rep finishes
  bool _capturingFrame = false;

  // Audio & haptic — resolved from provider in initState
  late WorkoutAudioService _audio;
  int _lastAttemptCount = 0;

  // No-pose hint
  DateTime? _lastPoseTime;
  bool _showPoseHint = false;
  Timer? _poseHintTimer;

  // Rep flash animation
  late AnimationController _flashController;
  late Animation<double> _flashAnim;
  int _lastRepCount = 0;

  // Camera fade-in animation
  late AnimationController _cameraFadeController;

  // Loading pulse animation
  late AnimationController _loadingPulseController;
  late Animation<double> _loadingPulseAnim;

  // Upside-down overlay animations
  late AnimationController _upsideDownSpinController;
  late AnimationController _upsideDownPulseController;
  late Animation<double> _upsideDownPulseAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Rep flash
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flashAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );

    // Camera fade-in (loading → preview)
    _cameraFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Loading pulse (pulsing indicator while camera inits)
    _loadingPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _loadingPulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _loadingPulseController, curve: Curves.easeInOut),
    );

    // Upside-down spin (continuous 360° rotation)
    _upsideDownSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Upside-down pulse (scale 1.0 ↔ 1.1)
    _upsideDownPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _upsideDownPulseAnim = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _upsideDownPulseController, curve: Curves.easeInOut),
    );

    _audio = context.read<WorkoutAudioService>();
    // Set audio service immediately so rep sounds aren't missed during init.
    context.read<WorkoutState>().setAudioService(_audio);
    _audio.init();
    _initializeCamera();
    _startPoseHintTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    context.read<WorkoutState>().setIsTablet(isTablet);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _poseService?.close();
    _poseHintTimer?.cancel();
    _flashController.dispose();
    _cameraFadeController.dispose();
    _loadingPulseController.dispose();
    _upsideDownSpinController.dispose();
    _upsideDownPulseController.dispose();
    // _audio is a root provider — do not dispose here.
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedAt ??= DateTime.now();
      try {
        _cameraController?.stopImageStream();
      } catch (_) {}
      _cameraController?.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      final paused = _pausedAt;
      _pausedAt = null;
      if (paused != null &&
          DateTime.now().difference(paused) >
              const Duration(minutes: 10)) {
        // Been away more than 10 minutes — treat as completed
        _endWorkout();
        return;
      }
      _recoverCamera();
    }
  }

  Future<void> _recoverCamera() async {
    if (!mounted) return;
    setState(() => _isRecovering = true);
    try {
      await _initializeCamera();
    } catch (_) {
      // Retry once
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        await _initializeCamera();
      } catch (_) {
        // Give up silently — user still sees the loading screen
      }
    }
    if (mounted) setState(() => _isRecovering = false);
  }

  void _startPoseHintTimer() {
    _lastPoseTime = DateTime.now();
    _poseHintTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      final noPose = _lastPoseTime != null &&
          DateTime.now().difference(_lastPoseTime!) >
              const Duration(seconds: 10);
      if (noPose != _showPoseHint) {
        setState(() => _showPoseHint = noPose);
      }
    });
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _permissionDenied = true;
        _errorMessage = null;
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No cameras found');
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        // nv21 is Android-only; iOS requires bgra8888
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
      _poseService = PoseDetectionService();
      await _cameraController!.startImageStream(_processFrame);

      if (mounted) {
        await context.read<WorkoutState>().initML();
      }

      setState(() {
        _isInitialized = true;
        _permissionDenied = false;
      });

      // Fade in the camera preview smoothly
      _cameraFadeController.forward();
    } catch (e) {
      setState(() => _errorMessage = 'Camera error: $e');
    }
  }

  void _processFrame(CameraImage image) async {
    if (_isProcessing || _poseService == null || _cameraController == null) {
      return;
    }
    _isProcessing = true;

    try {
      final camera = _cameraController!.description;
      final workoutState = context.read<WorkoutState>();
      final landmarks = await _poseService!.processFrame(
        image,
        camera,
        camera.sensorOrientation,
        deviceAngle: workoutState.deviceAngle,
      );

      if (!mounted) return;
      if (landmarks != null) {
        _lastPoseTime = DateTime.now();
        if (_showPoseHint) setState(() => _showPoseHint = false);
        workoutState.processLandmarks(landmarks);
      }
    } catch (_) {}

    _isProcessing = false;
  }

  /// Check if set is complete and auto-transition
  void _checkSetComplete(WorkoutState state) {
    if (!state.isCustom || _navigatingToRest) return;
    if (!state.isSetComplete) return;

    _navigatingToRest = true;

    if (state.currentSet >= state.totalSets) {
      // Last set — auto-end workout
      _audio.playSetComplete();
      HapticFeedback.heavyImpact();
      state.finishCurrentSet();
      _endWorkout();
      return;
    }

    // Not last set — go to rest timer
    _cameraController?.stopImageStream();
    _audio.playSetComplete();
    HapticFeedback.heavyImpact();
    state.finishCurrentSet();

    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RestTimerScreen(
          seconds: state.restSeconds,
          nextSet: state.currentSet,
          totalSets: state.totalSets,
        ),
      ),
    ).then((result) async {
      _navigatingToRest = false;
      if (!mounted) return;
      if (_cameraController != null) {
        try {
          await _cameraController!.startImageStream(_processFrame);
        } catch (_) {
          await _initializeCamera();
        }
      }
    });
  }

  Future<void> _endWorkout() async {
    setState(() => _finishing = true);

    // Fully stop and release camera
    try {
      await _cameraController?.stopImageStream();
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 50));
    _cameraController?.dispose();
    _cameraController = null;
    _poseService?.close();
    _poseService = null;
    if (!mounted) return;

    final workoutState = context.read<WorkoutState>();
    final repHistory = List<RepResult>.from(workoutState.repHistory);
    final setGood = List<int>.from(workoutState.setGoodReps);
    final setBad = List<int>.from(workoutState.setBadReps);
    final isCustom = workoutState.isCustom;
    final session = workoutState.endSession();

    if (session != null && session.totalReps > 0) {
      final db = context.read<DatabaseService>();
      final oldRecords = await db.getPersonalRecords();
      final oldMostReps = oldRecords['mostReps'] as int? ?? 0;
      final oldBestForm = oldRecords['bestFormScore'] as double? ?? 0;

      await db.saveSession(session);
      await db.updateStreak();
      if (!mounted) return;

      final isNewRepRecord = session.goodFormReps > oldMostReps;
      final isNewFormRecord =
          session.formScore > oldBestForm && session.totalReps >= 3;

      // Convert in-memory captures to BadFormCapture — no disk write needed
      final captures = _pendingCaptures
          .map((c) => BadFormCapture(
                imageBytes: c.image,
                issues: c.issues,
                repNumber: c.repNumber,
              ))
          .toList();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutSummaryScreen(
            session: session,
            repHistory: repHistory,
            setGoodReps: isCustom ? setGood : null,
            setBadReps: isCustom ? setBad : null,
            newRepRecord: isNewRepRecord,
            newFormRecord: isNewFormRecord,
            badFormCaptures: captures,
          ),
        ),
      );
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: _finishing
          ? _buildFinishing()
          : _isRecovering
              ? _buildRecovering()
              : _permissionDenied
                  ? _buildPermissionDenied()
                  : _errorMessage != null
                      ? _buildError()
                      : !_isInitialized
                          ? _buildLoading()
                          : _buildWorkoutView(),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_off_rounded,
                  color: Color(0xFF2563EB), size: 36),
            ),
            const SizedBox(height: 24),
            const Text('Camera Access Required',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const Text(
              'Rep AI needs camera access to detect your pose and count reps. '
              'Your video is processed on-device and never leaves your phone.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.white54, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 8),
            const Text(
              'Go to: Settings → Privacy & Security → Camera → Rep AI',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await openAppSettings();
                  // Re-check permission when user returns
                  await Future.delayed(const Duration(milliseconds: 500));
                  if (mounted) {
                    final status = await Permission.camera.status;
                    if (status.isGranted) {
                      setState(() => _permissionDenied = false);
                      _initializeCamera();
                    }
                  }
                },
                icon: const Icon(Icons.settings_rounded),
                label: const Text('Open App Settings',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  // Try requesting again — in case status changed
                  final status = await Permission.camera.request();
                  if (status.isGranted && mounted) {
                    setState(() => _permissionDenied = false);
                    _initializeCamera();
                  } else if (mounted) {
                    await openAppSettings();
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back',
                  style: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishing() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          SizedBox(height: 16),
          Text('Saving workout...',
              style: TextStyle(color: Colors.white54, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildRecovering() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          SizedBox(height: 16),
          Text('Resuming workout...',
              style: TextStyle(color: Colors.white54, fontSize: 15)),
        ],
      ),
    );
  }

  /// Animated loading state — dark screen with pulsing progress indicator.
  Widget _buildLoading() {
    return AnimatedBuilder(
      animation: _loadingPulseAnim,
      builder: (context, child) {
        return Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: _loadingPulseAnim.value,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Opacity(
                  opacity: _loadingPulseAnim.value,
                  child: const Text('Starting camera...',
                      style: TextStyle(color: Colors.white38, fontSize: 15)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(_errorMessage!,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back')),
          ],
        ),
      ),
    );
  }

  /// Captures the camera preview as a PNG and stores it as the best frame
  /// seen so far during the current rep. Called whenever bad-form confidence
  /// peaks — only the final value (_currentRepImage) is kept when the rep ends.
  Future<void> _maybeCaptureRepFrame() async {
    if (_capturingFrame || !_isInitialized || _finishing || !mounted) return;
    _capturingFrame = true;
    try {
      final boundary = _cameraPreviewKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 0.6);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      image.dispose();
      if (byteData != null && mounted) {
        _currentRepImage = byteData.buffer.asUint8List();
      }
    } catch (_) {
      // Capture failed silently — rep still counted normally
    } finally {
      _capturingFrame = false;
    }
  }

  Widget _buildWorkoutView() {
    // App is portrait-locked, so deviceAngle is always 0.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkoutState>().setDeviceAngle(0);
    });

    return Consumer<WorkoutState>(
      builder: (context, state, child) {
        // Good rep: repCount went up — trigger flash animation + haptic
        if (state.repCount > _lastRepCount) {
          _flashController.forward(from: 0);
          HapticFeedback.mediumImpact();
          _lastRepCount = state.repCount;
          _lastAttemptCount = state.attemptCount;
        }
        // Bad rep: attemptCount went up but repCount didn't — haptic only
        else if (state.attemptCount > _lastAttemptCount) {
          HapticFeedback.heavyImpact();
          Future.delayed(const Duration(milliseconds: 80), () {
            HapticFeedback.heavyImpact();
          });
          _lastAttemptCount = state.attemptCount;
        }

        // Check if set is complete (after build)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkSetComplete(state);
        });

        // When a rep finishes, check if it was bad and stash its best frame.
        final repLen = state.repHistory.length;
        if (repLen > _lastRepHistoryLen) {
          _lastRepHistoryLen = repLen;
          final newRep = state.repHistory.last;
          if (!newRep.goodForm && _currentRepImage != null) {
            _pendingCaptures.add(_RepCapture(
              image: _currentRepImage!,
              issues: List.from(newRep.issues),
              repNumber: newRep.repNumber,
            ));
          }
          // Reset for the next rep regardless of form
          _currentRepBestBadScore = 0.0;
          _currentRepImage = null;
        }

        // Capture the frame whenever bad-form confidence peaks within the current rep
        final badScore = state.currentForm?.badScore ?? 0.0;
        if (state.currentForm != null &&
            state.currentForm!.isBadForm &&
            badScore > _currentRepBestBadScore + 0.05) {
          _currentRepBestBadScore = badScore;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _maybeCaptureRepFrame();
          });
        }

        return Stack(
          children: [
            // Camera preview fades in from black
            // Wrapped in RepaintBoundary so we can capture the worst form frame
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _cameraFadeController,
                builder: (context, child) => Opacity(
                  opacity: CurvedAnimation(
                    parent: _cameraFadeController,
                    curve: Curves.easeIn,
                  ).value,
                  child: child,
                ),
                child: RepaintBoundary(
                  key: _cameraPreviewKey,
                  child: _buildCameraPreview(),
                ),
              ),
            ),

            // Gradient overlay (portrait-only since the app is portrait-locked)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                      stops: const [0.0, 0.2, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
            ),
                  // ── PORTRAIT LAYOUT ──
                  // Top-left: exercise label + set info
                  Positioned(
                    top: 0,
                    left: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.exercise.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                            ),
                            if (state.isCustom)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Set ${state.currentSet} of ${state.totalSets}',
                                  style: TextStyle(
                                    color: Colors.white
                                        .withValues(alpha: 0.7),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Top-right: mute toggle + form badge
                  Positioned(
                    top: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding:
                            const EdgeInsets.only(right: 16, top: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => _audio.toggleMute(),
                              child: Consumer<WorkoutAudioService>(
                                builder: (_, audio, __) => Icon(
                                  audio.isMuted
                                      ? Icons.volume_off_rounded
                                      : Icons.volume_up_rounded,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _buildFormBadge(state.currentForm,
                                liveIssue: state.currentLiveFormIssue),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Rep counter
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Center(
                          child: Column(
                            children: [
                              _buildRepCounter(
                                state.isCustom
                                    ? state.currentSetGoodReps
                                        .clamp(0, state.targetReps)
                                    : state.repCount,
                              ),
                              if (state.isCustom)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '/ ${state.targetReps}',
                                    style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.5),
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bad rep flash
                  if (_isBadRepRecent(
                      state.lastRepValid, state.lastRepTime))
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: EdgeInsets.only(
                              top: state.isCustom ? 200 : 170),
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                    sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626)
                                        .withValues(alpha: 0.7),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _badRepMessage(state.lastRepFeedback),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Bottom bar
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildTimer(state.elapsed),
                            _buildEndButton(),
                          ],
                        ),
                      ),
                    ),
                  ),

                // No-pose hint
                if (_showPoseHint)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter:
                                ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 14),
                              decoration: BoxDecoration(
                                color:
                                    Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Text(
                                'Make sure your full body is visible',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Upside-down overlay
                if (state.isUpsideDown)
                  Positioned.fill(
                    child: _buildUpsideDownOverlay(
                      state.flipMessageTitle,
                      state.flipMessageSubtitle,
                    ),
                  ),

          ],
        );
      },
    );
  }

  Widget _buildUpsideDownOverlay(String title, String subtitle) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge(
                  [_upsideDownSpinController, _upsideDownPulseController]),
              builder: (context, child) {
                return Transform.scale(
                  scale: _upsideDownPulseAnim.value,
                  child: RotationTransition(
                    turns: _upsideDownSpinController,
                    child: const Icon(
                      Icons.phone_android,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isBadRepRecent(bool? lastRepValid, DateTime? lastRepTime) {
    if (lastRepValid != false || lastRepTime == null) return false;
    return DateTime.now().difference(lastRepTime) <
        const Duration(seconds: 3);
  }

  Widget _buildRepCounter(int count) {
    return AnimatedBuilder(
      animation: _flashAnim,
      builder: (context, child) {
        final flashValue = _flashAnim.value;
        final displayColor = flashValue > 0
            ? Color.lerp(
                const Color(0xFF00E676), Colors.white, flashValue)!
            : Colors.white;

        return Text(
          '$count',
          style: TextStyle(
            fontSize: 88,
            fontWeight: FontWeight.w900,
            color: displayColor,
            height: 1,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCameraPreview() {
    final previewSize = _cameraController!.value.previewSize;
    if (previewSize == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final screenAspect = screenWidth / screenHeight;
        final cameraAspect = previewSize.height / previewSize.width;

        double scaleX, scaleY;
        if (screenAspect > cameraAspect) {
          scaleX = screenWidth;
          scaleY = screenWidth / cameraAspect;
        } else {
          scaleY = screenHeight;
          scaleX = screenHeight * cameraAspect;
        }

        return ClipRect(
          child: OverflowBox(
            maxWidth: scaleX,
            maxHeight: scaleY,
            child: CameraPreview(_cameraController!),
          ),
        );
      },
    );
  }

  /// Returns a user-facing message for the bad-rep flash banner.
  String _badRepMessage(List<String> feedback) {
    final issue = feedback.isNotEmpty ? feedback.first : '';
    if (issue.isEmpty || issue == 'Work on form' || issue == 'Bad form') {
      return 'Fix your form — not counted';
    }
    return '$issue — not counted';
  }

  Widget _buildFormBadge(dynamic currentForm,
      {double? maxWidth, String? liveIssue}) {
    if (currentForm == null || currentForm.isNotExercise) {
      return const SizedBox.shrink();
    }
    final isGood = currentForm.isGoodForm as bool;
    final color = isGood ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    String label;
    if (isGood) {
      label = 'Good Form';
    } else if (liveIssue != null && liveIssue.isNotEmpty) {
      label = liveIssue;
    } else {
      label = 'Fix Form';
    }

    Widget badge = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isGood
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  softWrap: false,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Ensure badge is at least 120px wide so full text is always visible
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: 0,
        maxWidth: maxWidth != null ? maxWidth.clamp(120.0, double.infinity) : double.infinity,
      ),
      child: badge,
    );
  }

  Widget _buildTimer(Duration elapsed) {
    final mins = elapsed.inMinutes.toString().padLeft(2, '0');
    final secs = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Text(
      '$mins:$secs',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildEndButton() {
    return GestureDetector(
      onTap: _endWorkout,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'End Workout',
                maxLines: 1,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Private data class ────────────────────────────────────────────────────────

/// Holds an in-memory capture for a single bad-form rep while the workout is
/// running. Saved to disk in [_WorkoutScreenState._saveCapturesToDisk] when
/// the workout ends and then discarded from memory.
class _RepCapture {
  final Uint8List image;
  final List<String> issues;
  final int repNumber;

  _RepCapture({
    required this.image,
    required this.issues,
    required this.repNumber,
  });
}
