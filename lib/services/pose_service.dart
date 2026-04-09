/// Pose Detection Service
/// =======================
/// Wraps Google ML Kit Pose Detection for use in the app.
/// Converts ML Kit landmarks into the same format our PushUpAnalyzer expects.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseDetectionService {
  late final PoseDetector _poseDetector;
  bool _isBusy = false;

  PoseDetectionService() {
    // Create the pose detector with base (fast) model
    // Base model: faster, good enough for rep counting
    // Accurate model: slower but more precise (use if base isn't good enough)
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,  // Optimized for video
        model: PoseDetectionModel.base,
      ),
    );
  }

  /// Process a camera frame and return landmarks.
  ///
  /// Returns a Map of {landmark_name: {x, y, visibility}} using NORMALIZED
  /// coordinates (0.0 to 1.0), matching what PushUpAnalyzer expects.
  ///
  /// [deviceAngle] is the current device rotation in degrees:
  ///   0   = portrait (default)
  ///   270 = landscape, camera on right (counter-clockwise from portrait)
  ///   90  = landscape, camera on left
  ///
  /// Returns null if no pose detected or if already processing.
  Future<Map<String, Map<String, double>>?> processFrame(
    CameraImage image,
    CameraDescription camera,
    int sensorOrientation, {
    double deviceAngle = 0,
  }) async {
    // Skip if still processing the last frame
    if (_isBusy) return null;
    _isBusy = true;

    try {
      // Convert CameraImage to InputImage for ML Kit
      final inputImage = _convertCameraImage(image, camera, sensorOrientation);
      if (inputImage == null) {
        _isBusy = false;
        return null;
      }

      // Run pose detection
      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isEmpty) {
        _isBusy = false;
        return null;
      }

      // Take the first detected pose
      final pose = poses.first;

      // iOS bgra8888 tends to produce lower likelihood scores than Android NV21.
      // Lower the threshold on iOS to avoid filtering out valid detections.
      final minLikelihood = Platform.isIOS ? 0.3 : (deviceAngle == 90 || deviceAngle == 270) ? 0.5 : 0.6;

      // Reject the frame if the key push-up joints aren't clearly visible.
      if (!_keyJointsVisible(pose, minLikelihood: minLikelihood)) {
        _isBusy = false;
        return null;
      }

      // Convert ML Kit landmarks to our format
      final landmarks = _convertLandmarks(
        pose,
        image.width,
        image.height,
        deviceAngle: deviceAngle,
        sensorOrientation: sensorOrientation,
      );

      _isBusy = false;
      return landmarks;
    } catch (e) {
      _isBusy = false;
      return null;
    }
  }

  /// Returns true only if the joints needed for push-up analysis are all
  /// clearly visible. Rejects background people and partially-visible poses.
  bool _keyJointsVisible(Pose pose, {required double minLikelihood}) {
    const required = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ];
    for (final type in required) {
      final lm = pose.landmarks[type];
      if (lm == null || lm.likelihood < minLikelihood) return false;
    }
    return true;
  }

  /// Convert ML Kit Pose to our landmark format.
  /// Returns normalized coordinates (0-1).
  ///
  /// Applies coordinate rotation for landscape modes so that the Y axis
  /// always represents the "vertical" body axis that changes during a push-up:
  ///   deviceAngle == 270 (landscape, camera right): newX = y, newY = 1 - x
  ///   deviceAngle == 0  (portrait): no transform
  Map<String, Map<String, double>> _convertLandmarks(
    Pose pose,
    int imageWidth,
    int imageHeight, {
    double deviceAngle = 0,
    int sensorOrientation = 0,
  }) {
    final landmarks = <String, Map<String, double>>{};

    // Map ML Kit PoseLandmarkType to our naming convention
    final nameMap = {
      PoseLandmarkType.nose: 'NOSE',
      PoseLandmarkType.leftEar: 'LEFT_EAR',
      PoseLandmarkType.rightEar: 'RIGHT_EAR',
      PoseLandmarkType.leftShoulder: 'LEFT_SHOULDER',
      PoseLandmarkType.rightShoulder: 'RIGHT_SHOULDER',
      PoseLandmarkType.leftElbow: 'LEFT_ELBOW',
      PoseLandmarkType.rightElbow: 'RIGHT_ELBOW',
      PoseLandmarkType.leftWrist: 'LEFT_WRIST',
      PoseLandmarkType.rightWrist: 'RIGHT_WRIST',
      PoseLandmarkType.leftHip: 'LEFT_HIP',
      PoseLandmarkType.rightHip: 'RIGHT_HIP',
      PoseLandmarkType.leftKnee: 'LEFT_KNEE',
      PoseLandmarkType.rightKnee: 'RIGHT_KNEE',
      PoseLandmarkType.leftAnkle: 'LEFT_ANKLE',
      PoseLandmarkType.rightAnkle: 'RIGHT_ANKLE',
    };

    for (final entry in nameMap.entries) {
      final lm = pose.landmarks[entry.key];
      if (lm != null) {
        // Normalize to 0-1 range first
        double nx = lm.x / imageWidth;
        double ny = lm.y / imageHeight;

        // Rotate coordinates to compensate for camera image orientation.
        // ML Kit returns coordinates in the raw image space, so we need to
        // transform them into upright world/portrait space.
        //
        // On iOS: the sensor always delivers landscape frames (sensorOrientation=90)
        // regardless of device orientation. We compute the effectiveRotation:
        //   effectiveRotation = (sensorOrientation - deviceAngle + 360) % 360
        //
        // On Android: sensorOrientation is already baked into the coordinate
        // space by the camera pipeline, so we only need to handle deviceAngle.
        if (!Platform.isIOS) {
          // Android only: transform based on device orientation.
          // On iOS, ML Kit handles orientation internally so no transform needed.
          if (deviceAngle == 270) {
            final rotX = ny;
            final rotY = 1.0 - nx;
            nx = rotX;
            ny = rotY;
          } else if (deviceAngle == 90) {
            final rotX = 1.0 - ny;
            final rotY = nx;
            nx = rotX;
            ny = rotY;
          }
        }

        landmarks[entry.value] = {
          'x': nx,
          'y': ny,
          'visibility': lm.likelihood,  // ML Kit calls it "likelihood"
        };
      }
    }

    return landmarks;
  }

  /// Get raw ML Kit landmarks for drawing on screen (pixel coordinates).
  /// This is separate from the normalized coords used for analysis.
  Future<List<PoseLandmark>?> getRawLandmarks(
    CameraImage image,
    CameraDescription camera,
    int sensorOrientation,
  ) async {
    // This would share the same detection result - for now, the overlay
    // painter handles the coordinate conversion separately
    return null;
  }

  /// Convert CameraImage to ML Kit's InputImage format.
  /// Handles both Android (NV21) and iOS (BGRA8888) formats.
  InputImage? _convertCameraImage(
    CameraImage image,
    CameraDescription camera,
    int sensorOrientation,
  ) {
    if (image.planes.isEmpty) return null;

    // Get the image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // Pass sensorOrientation to ML Kit on all platforms so it can correctly
    // process the image. On iOS, the sensor delivers landscape frames
    // (sensorOrientation=90) even in portrait — ML Kit needs to know this
    // to detect the pose correctly.
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation)
        ?? InputImageRotation.rotation0deg;

    // On iOS with bgra8888, all data is in a single plane.
    // On Android with NV21/YUV420, we may need to concatenate planes.
    final Uint8List bytes;
    if (image.planes.length == 1) {
      bytes = image.planes.first.bytes;
    } else {
      // Concatenate all planes (Android YUV420)
      final allBytes = image.planes.map((p) => p.bytes).toList();
      final totalLength = allBytes.fold<int>(0, (sum, b) => sum + b.length);
      final merged = Uint8List(totalLength);
      int offset = 0;
      for (final plane in allBytes) {
        merged.setRange(offset, offset + plane.length, plane);
        offset += plane.length;
      }
      bytes = merged;
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: ui.Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  void close() {
    _poseDetector.close();
  }
}
