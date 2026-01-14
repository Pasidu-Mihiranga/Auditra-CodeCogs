import 'package:geolocator/geolocator.dart';

/// Default location fallback (for when GPS is unavailable)
class DefaultLocation {
  // Default coordinates (adjust to your location)
  static const double defaultLatitude = 6.6828;
  static const double defaultLongitude = 80.3992;
  static const double defaultAccuracy = 1000.0;
}

/// Service for getting location offline (GPS works without internet)
class OfflineLocationService {
  /// Get current location
  /// Returns default location if GPS is unavailable
  static Future<Map<String, dynamic>> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️ Location services disabled. Using default location.');
        return _getDefaultLocation();
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('⚠️ Location permissions denied. Using default location.');
          return _getDefaultLocation();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('⚠️ Location permissions permanently denied. Using default location.');
        return _getDefaultLocation();
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'heading': position.heading,
        'speed': position.speed,
          'timestamp': position.timestamp.millisecondsSinceEpoch,
        'isDefault': false,
      };
    } catch (e) {
      print('⚠️ Error getting location: $e. Using default location.');
      return _getDefaultLocation();
    }
  }

  /// Get last known location
  static Future<Map<String, dynamic>?> getLastKnownLocation() async {
    try {
      Position? position = await Geolocator.getLastKnownPosition();
      
      if (position != null) {
        return {
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
    } catch (e) {
      print('Error getting last known location: $e');
    }
    
    return null;
  }

  /// Get default location
  static Map<String, dynamic> _getDefaultLocation() {
    return {
      'latitude': DefaultLocation.defaultLatitude,
      'longitude': DefaultLocation.defaultLongitude,
      'accuracy': DefaultLocation.defaultAccuracy,
      'altitude': null,
      'heading': null,
      'speed': null,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isDefault': true,
    };
  }

  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Request location permissions
  static Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }
}

