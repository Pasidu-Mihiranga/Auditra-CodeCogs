import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'network_service.dart';

/// Tunable GPS capture settings for valuation reports.
class LocationCaptureConfig {
  /// Maximum horizontal accuracy (metres) accepted before saving coordinates.
  static const double maxAcceptableAccuracyMeters = 20.0;

  /// How long to wait for a satellite-grade fix before giving up.
  static const Duration maxWait = Duration(seconds: 25);

  /// iOS purpose key — must match Info.plist entry.
  static const String iosPrecisePurposeKey = 'ValuationLocation';
}

/// Provides accurate GPS coordinates without requiring internet.
///
/// Waits for a fix with accuracy ≤ [LocationCaptureConfig.maxAcceptableAccuracyMeters]
/// instead of accepting the first fast network/cell position. Never returns fake
/// hardcoded coordinates on failure.
class OfflineLocationService {
  /// Reads GPS and returns an accurate fix, or a failure map (no fake lat/lng).
  ///
  /// Success map: `success: true`, `latitude`, `longitude`, `accuracy`, `isDefault: false`.
  /// Failure map: `success: false`, `reason`, null coordinates.
  static Future<Map<String, dynamic>> getCurrentLocation() async {
    final stopwatch = Stopwatch()..start();

    var result = await _captureAccurateLocation(stopwatch);
    if (result['success'] == true) {
      return result;
    }

    // One automatic retry before giving up (same workflow, no user action).
    if (kDebugMode) {
      debugPrint('[GPS] First capture failed (${result['reason']}), retrying...');
    }
    await Future.delayed(const Duration(seconds: 2));
    result = await _captureAccurateLocation(stopwatch);
    return result;
  }

  /// Same accuracy rules as [getCurrentLocation] — used for photo metadata.
  static Future<Map<String, dynamic>> getPhotoLocation() {
    return getCurrentLocation();
  }

  /// Returns the most recent OS-cached reading. Preview only — do not use for save.
  static Future<Map<String, dynamic>?> getLastKnownLocation() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) return null;

      final age = DateTime.now().difference(position.timestamp);
      if (age.inMinutes > 2) return null;
      if (position.accuracy > LocationCaptureConfig.maxAcceptableAccuracyMeters) {
        return null;
      }

      return _positionToResult(position);
    } catch (e) {
      if (kDebugMode) debugPrint('[GPS] getLastKnownLocation error: $e');
    }
    return null;
  }

  static Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  static Future<LocationPermission> requestPermission() {
    return Geolocator.requestPermission();
  }

  // ---------------------------------------------------------------------------
  // Internal capture pipeline
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> _captureAccurateLocation(Stopwatch stopwatch) async {
    try {
      final prep = await _ensureLocationReady();
      if (prep['success'] != true) {
        final failure = _failureResult(
          prep['reason'] as String,
          elapsedMs: stopwatch.elapsedMilliseconds,
          permission: prep['permission'] as String?,
        );
        _logDiagnostic(failure, permission: prep['permission'] as String?);
        return failure;
      }

      final position = await _waitForAccuratePosition();
      if (position == null) {
        final failure = _failureResult(
          'accurate_fix_timeout',
          elapsedMs: stopwatch.elapsedMilliseconds,
          permission: prep['permission'] as String?,
        );
        _logDiagnostic(failure, permission: prep['permission'] as String?);
        return failure;
      }

      final result = _positionToResult(position);
      _logDiagnostic(result, permission: prep['permission'] as String?);
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('[GPS] capture error: $e');
      final failure = _failureResult(
        'error',
        elapsedMs: stopwatch.elapsedMilliseconds,
        message: e.toString(),
      );
      _logDiagnostic(failure);
      return failure;
    }
  }

  static Future<Map<String, dynamic>> _ensureLocationReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return {'success': false, 'reason': 'service_disabled'};
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return {
        'success': false,
        'reason': 'permission_denied',
        'permission': permission.name,
      };
    }

    if (permission == LocationPermission.deniedForever) {
      return {
        'success': false,
        'reason': 'permission_denied_forever',
        'permission': permission.name,
      };
    }

    await _requestPreciseLocationIfNeeded();

    final reducedPrecision = await _hasReducedPrecision(permission);
    if (reducedPrecision) {
      return {
        'success': false,
        'reason': 'reduced_precision',
        'permission': permission.name,
      };
    }

    return {'success': true, 'permission': permission.name};
  }

  /// Returns true when the OS only grants approximate (not precise) location.
  static Future<bool> _hasReducedPrecision(LocationPermission permission) async {
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return false;
    }

    try {
      final accuracyStatus = await Geolocator.getLocationAccuracy();
      return accuracyStatus == LocationAccuracyStatus.reduced;
    } catch (e) {
      if (kDebugMode) debugPrint('[GPS] Location accuracy check: $e');
      return false;
    }
  }

  static Future<void> _requestPreciseLocationIfNeeded() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    try {
      final accuracyStatus = await Geolocator.getLocationAccuracy();
      if (accuracyStatus == LocationAccuracyStatus.reduced) {
        await Geolocator.requestTemporaryFullAccuracy(
          purposeKey: LocationCaptureConfig.iosPrecisePurposeKey,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[GPS] iOS precise location request: $e');
    }
  }

  /// Listens to position updates until accuracy threshold is met or [maxWait] elapses.
  static Future<Position?> _waitForAccuratePosition() async {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
    );

    Position? best;
    StreamSubscription<Position>? subscription;
    final completer = Completer<Position?>();

    late final Timer timer;
    timer = Timer(LocationCaptureConfig.maxWait, () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    subscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) {
        if (best == null || position.accuracy < best!.accuracy) {
          best = position;
        }

        if (position.accuracy <= LocationCaptureConfig.maxAcceptableAccuracyMeters) {
          if (!completer.isCompleted) {
            completer.complete(position);
          }
        }
      },
      onError: (_) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    final accurate = await completer.future;
    await subscription.cancel();
    timer.cancel();

    if (accurate != null &&
        accurate.accuracy <= LocationCaptureConfig.maxAcceptableAccuracyMeters) {
      return accurate;
    }

    if (best != null &&
        best!.accuracy <= LocationCaptureConfig.maxAcceptableAccuracyMeters) {
      return best;
    }

    return null;
  }

  static Map<String, dynamic> _positionToResult(Position position) {
    return {
      'success': true,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'altitude': position.altitude,
      'heading': position.heading,
      'speed': position.speed,
      'timestamp': position.timestamp.millisecondsSinceEpoch,
      'isDefault': false,
    };
  }

  static Map<String, dynamic> _failureResult(
    String reason, {
    int? elapsedMs,
    String? permission,
    String? message,
  }) {
    return {
      'success': false,
      'reason': reason,
      'latitude': null,
      'longitude': null,
      'accuracy': null,
      'altitude': null,
      'heading': null,
      'speed': null,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isDefault': false,
      if (elapsedMs != null) 'elapsedMs': elapsedMs,
      if (permission != null) 'permission': permission,
      if (message != null) 'message': message,
    };
  }

  static void _logDiagnostic(
    Map<String, dynamic> result, {
    String? permission,
  }) {
    if (!kDebugMode) return;

    final isOnline = NetworkService.isInitialized ? NetworkService.isOnline : null;
    debugPrint(
      '[GPS] success=${result['success']} '
      'reason=${result['reason']} '
      'lat=${result['latitude']} lng=${result['longitude']} '
      'accuracy=${result['accuracy']}m '
      'isDefault=${result['isDefault']} '
      'permission=$permission '
      'isOnline=$isOnline '
      'elapsedMs=${result['elapsedMs']}',
    );
  }
}
