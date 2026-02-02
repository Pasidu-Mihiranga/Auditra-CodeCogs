import 'package:hive_flutter/hive_flutter.dart';
import 'api_service.dart';

/// Service for managing offline database using Hive
/// Only enabled for field officers
class OfflineDBService {
  static const String _valuationsBoxName = 'valuations';
  static const String _projectsCacheBoxName = 'projects_cache';
  static const String _attendanceBoxName = 'attendance';
  static const String _syncQueueBoxName = 'sync_queue';
  static const String _photosCacheBoxName = 'photos_cache';
  
  static bool _isInitialized = false;
  
  /// Check if database is initialized (public getter)
  static bool get isInitialized => _isInitialized;

  /// Initialize Hive database (only for field officers)
  static Future<void> initOfflineDB() async {
    if (_isInitialized) {
      return;
    }

    // Check if user is field officer
    if (!await isOfflineModeEnabled()) {
      print('Offline mode not enabled for this user');
      return;
    }

    try {
      // Initialize Hive Flutter
      await Hive.initFlutter();
      
      // Open boxes
      await Hive.openBox(_valuationsBoxName);
      await Hive.openBox(_projectsCacheBoxName);
      await Hive.openBox(_attendanceBoxName);
      await Hive.openBox(_syncQueueBoxName);
      await Hive.openBox(_photosCacheBoxName);
      
      _isInitialized = true;
      print('✅ Offline database initialized');
    } catch (e) {
      print('❌ Error initializing offline database: $e');
      rethrow;
    }
  }

  /// Check if offline mode is enabled (only for field officers)
  static Future<bool> isOfflineModeEnabled() async {
    try {
      final role = await ApiService.getUserRole();
      return role == 'field_officer';
    } catch (e) {
      print('Error checking user role: $e');
      return false;
    }
  }

  /// Get valuations box
  static Box get valuationsBox {
    if (!_isInitialized) {
      throw Exception('Offline database not initialized. Call initOfflineDB() first.');
    }
    return Hive.box(_valuationsBoxName);
  }

  /// Get projects cache box
  static Box get projectsCacheBox {
    if (!_isInitialized) {
      throw Exception('Offline database not initialized. Call initOfflineDB() first.');
    }
    return Hive.box(_projectsCacheBoxName);
  }

  /// Get attendance box
  static Box get attendanceBox {
    if (!_isInitialized) {
      throw Exception('Offline database not initialized. Call initOfflineDB() first.');
    }
    return Hive.box(_attendanceBoxName);
  }

  /// Get sync queue box
  static Box get syncQueueBox {
    if (!_isInitialized) {
      throw Exception('Offline database not initialized. Call initOfflineDB() first.');
    }
    return Hive.box(_syncQueueBoxName);
  }

  /// Get photos cache box
  static Box get photosCacheBox {
    if (!_isInitialized) {
      throw Exception('Offline database not initialized. Call initOfflineDB() first.');
    }
    return Hive.box(_photosCacheBoxName);
  }

  /// Clear all offline data (use with caution)
  static Future<void> clearAllData() async {
    if (!_isInitialized) return;
    
    await valuationsBox.clear();
    await projectsCacheBox.clear();
    await attendanceBox.clear();
    await syncQueueBox.clear();
    await photosCacheBox.clear();
  }

  /// Get database statistics
  static Map<String, int> getStats() {
    if (!_isInitialized) {
      return {};
    }
    
    return {
      'valuations': valuationsBox.length,
      'projects': projectsCacheBox.length,
      'attendance': attendanceBox.length,
      'sync_queue': syncQueueBox.length,
      'photos': photosCacheBox.length,
    };
  }
}

