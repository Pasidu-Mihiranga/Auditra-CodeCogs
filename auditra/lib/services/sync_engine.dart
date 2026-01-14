import 'dart:async';
import 'api_service.dart';
import 'network_service.dart';
import 'offline_storage_service.dart';
import 'offline_db_service.dart';

/// Service for automatically syncing offline data when connectivity returns
class SyncEngine {
  static bool _isInitialized = false;
  static bool _isSyncing = false;
  static StreamSubscription<bool>? _networkSubscription;
  static Timer? _periodicSyncTimer;
  static final List<Function(Map<String, dynamic>)> _listeners = [];
  static bool _wasOffline = false;

  /// Initialize sync engine
  static Future<void> init() async {
    if (_isInitialized) {
      print('🔄 Sync engine already initialized');
      return;
    }

    // Check if offline mode is enabled
    if (!await OfflineDBService.isOfflineModeEnabled()) {
      print('🔄 Sync engine not needed (offline mode disabled)');
      return;
    }

    // Initialize network service
    await NetworkService.init();

    // Track previous network state to detect transitions from offline to online
    _wasOffline = !NetworkService.isOnline;
    
    // Listen to network status changes
    _networkSubscription = NetworkService.networkStatusStream.listen((isOnline) {
      if (isOnline) {
        if (_wasOffline) {
          // Transitioning from offline to online - sync immediately
          print('📶 Network restored (was offline) - triggering sync');
          Future.delayed(const Duration(seconds: 1), () {
            syncAll();
          });
        }
        // Don't sync if already online - items should go directly to server
        _wasOffline = false;
      } else {
        print('📴 Network lost');
        _wasOffline = true;
      }
    });

    // Initial sync check: only if we were offline and now online, or if there are unsynced items
    if (NetworkService.isOnline) {
      // Check if there are unsynced items that need syncing
      final unsyncedValuations = OfflineStorageService.getUnsyncedValuations();
      if (unsyncedValuations.isNotEmpty) {
        print('📶 Online with ${unsyncedValuations.length} unsynced items - syncing now');
        Future.delayed(const Duration(seconds: 2), () {
          syncAll(silent: true);
        });
      }
    }

    _isInitialized = true;
    print('✅ Sync engine initialized');
  }

  /// Add listener for sync events
  static void addListener(Function(Map<String, dynamic>) listener) {
    _listeners.add(listener);
  }

  /// Remove listener
  static void removeListener(Function(Map<String, dynamic>) listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners
  static void _notifyListeners(String event, Map<String, dynamic> data) {
    for (var listener in _listeners) {
      try {
        listener({'event': event, ...data});
      } catch (e) {
        print('Error in sync listener: $e');
      }
    }
  }

  /// Sync all pending items
  static Future<void> syncAll({bool silent = false}) async {
    if (_isSyncing) {
      if (!silent) print('⏳ Sync already in progress');
      return;
    }

    if (!NetworkService.isOnline) {
      if (!silent) print('📴 Offline - skipping sync');
      return;
    }

    // Check if there are any unsynced items before starting sync
    final unsyncedValuations = OfflineStorageService.getUnsyncedValuations();
    final unsyncedAttendance = OfflineStorageService.getUnsyncedAttendance();
    final unsyncedPhotos = OfflineStorageService.getUnsyncedPhotos();
    final hasUnsyncedItems = unsyncedValuations.isNotEmpty || 
                            unsyncedAttendance.isNotEmpty || 
                            unsyncedPhotos.isNotEmpty;
    
    if (!hasUnsyncedItems) {
      if (!silent) print('✅ No unsynced items - skipping sync');
      return;
    }

    _isSyncing = true;
    _notifyListeners('syncStart', {});

    try {
      int syncedCount = 0;
      int failedCount = 0;

      // Sync valuations
      final valuationResult = await _syncValuations(silent: silent);
      syncedCount += valuationResult['synced'] as int;
      failedCount += valuationResult['failed'] as int;

      // Sync attendance
      final attendanceResult = await _syncAttendance(silent: silent);
      syncedCount += attendanceResult['synced'] as int;
      failedCount += attendanceResult['failed'] as int;

      // Sync photos
      final photosResult = await _syncPhotos(silent: silent);
      syncedCount += photosResult['synced'] as int;
      failedCount += photosResult['failed'] as int;

      if (!silent || syncedCount > 0 || failedCount > 0) {
        print('✅ Sync complete: $syncedCount synced, $failedCount failed');
      }

      _notifyListeners('syncComplete', {
        'synced': syncedCount,
        'failed': failedCount,
      });
    } catch (e) {
      print('❌ Sync error: $e');
      _notifyListeners('syncError', {'error': e.toString()});
    } finally {
      _isSyncing = false;
    }
  }

  /// Silent sync for periodic checks
  static Future<void> syncAllSilent() {
    return syncAll(silent: true);
  }

  /// Sync a single valuation
  static Future<Map<String, dynamic>> syncValuation(String localId) async {
    final valuation = OfflineStorageService.getValuationByLocalId(localId);
    
    if (valuation == null) {
      return {'success': false, 'message': 'Valuation not found'};
    }

    if (valuation['syncStatus'] == 1) {
      return {'success': true, 'message': 'Already synced'};
    }

    try {
      // Prepare data for API (remove offline metadata)
      final apiData = Map<String, dynamic>.from(valuation);
      apiData.remove('localId');
      apiData.remove('syncStatus');
      apiData.remove('serverId');
      apiData.remove('createdAt');
      apiData.remove('updatedAt');
      apiData.remove('syncedAt');
      
      // Debug: Log the data being synced
      print('🔄 Syncing valuation $localId with data: ${apiData.keys.toList()}');

      // Use syncValuationToServer directly to avoid creating duplicate offline entries
      final result = await ApiService.syncValuationToServer(apiData);
      
      // Debug: Log the result
      print('🔄 Sync result for $localId: success=${result['success']}, message=${result['message']}');

      if (result['success'] == true) {
        // Check if data exists and has an id
        final data = result['data'];
        if (data != null && data is Map<String, dynamic> && data['id'] != null) {
          final serverId = data['id'] as int;
          await OfflineStorageService.markValuationSynced(localId, serverId);
          print('✅ Valuation synced: $localId -> $serverId');
          return {'success': true, 'serverId': serverId};
        } else {
          print('❌ Sync response missing data or id: $result');
          return {'success': false, 'message': 'Server response missing valuation ID'};
        }
      } else {
        final errorMessage = result['message'] ?? 'Unknown error';
        print('❌ Failed to sync valuation: $errorMessage');
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      print('❌ Error syncing valuation: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Sync all unsynced valuations
  static Future<Map<String, dynamic>> _syncValuations({bool silent = false}) async {
    final unsynced = OfflineStorageService.getUnsyncedValuations();
    
    if (!silent && unsynced.isNotEmpty) {
      print('📤 Syncing ${unsynced.length} valuations...');
    }

    int synced = 0;
    int failed = 0;

    for (var valuation in unsynced) {
      final localId = valuation['localId'] as String;
      final result = await syncValuation(localId);
      
      if (result['success']) {
        synced++;
        _notifyListeners('valuationSynced', {'localId': localId, 'serverId': result['serverId']});
      } else {
        failed++;
      }
    }

    // Clean up successfully synced valuations after sync
    if (synced > 0) {
      await OfflineStorageService.cleanupSyncedValuations();
    }

    if (!silent && synced > 0) {
      _notifyListeners('syncSuccess', {
        'message': '$synced valuation${synced > 1 ? 's' : ''} successfully synced and submitted',
        'synced': synced,
        'failed': failed,
      });
    }

    return {'synced': synced, 'failed': failed};
  }

  /// Sync all unsynced attendance records
  static Future<Map<String, dynamic>> _syncAttendance({bool silent = false}) async {
    final unsynced = OfflineStorageService.getUnsyncedAttendance();
    
    if (!silent && unsynced.isNotEmpty) {
      print('📤 Syncing ${unsynced.length} attendance records...');
    }

    int synced = 0;
    int failed = 0;

    // TODO: Implement attendance sync when API is available
    // For now, just mark as synced if we have the API endpoint
    
    return {'synced': synced, 'failed': failed};
  }

  /// Sync all unsynced photos
  static Future<Map<String, dynamic>> _syncPhotos({bool silent = false}) async {
    final unsynced = OfflineStorageService.getUnsyncedPhotos();
    
    if (!silent && unsynced.isNotEmpty) {
      print('📤 Syncing ${unsynced.length} photos...');
    }

    int synced = 0;
    int failed = 0;

    // TODO: Implement photo sync when API is available
    // Need to upload photo file and link to valuation
    
    return {'synced': synced, 'failed': failed};
  }

  /// Get sync status
  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final stats = OfflineStorageService.getStats();
      return {
        'pendingValuations': stats['unsynced_valuations'] ?? 0,
        'pendingAttendance': stats['unsynced_attendance'] ?? 0,
        'pendingPhotos': stats['unsynced_photos'] ?? 0,
        'isOnline': NetworkService.isOnline,
        'isSyncing': _isSyncing,
        'isInitialized': _isInitialized,
      };
    } catch (e) {
      // Return default status if database not initialized
      return {
        'pendingValuations': 0,
        'pendingAttendance': 0,
        'pendingPhotos': 0,
        'isOnline': NetworkService.isOnline,
        'isSyncing': false,
        'isInitialized': false,
      };
    }
  }

  /// Dispose resources
  static void dispose() {
    _networkSubscription?.cancel();
    _periodicSyncTimer?.cancel();
    _listeners.clear();
    _isInitialized = false;
  }

}

