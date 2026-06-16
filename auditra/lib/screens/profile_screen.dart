import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../services/sync_engine.dart';
import '../services/network_service.dart';
import '../theme/app_colors.dart';
import '../widgets/user_avatar.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';
import 'field_officer/screens/valuation_history_screen.dart';


class ProfileScreen extends StatefulWidget {
  final bool showAppBar;
  final VoidCallback? onNavigateToProjects;
  const ProfileScreen({super.key, this.showAppBar = true, this.onNavigateToProjects});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  bool _saving = false;
  bool _uploading = false;
  String? _avatarUrl;

  // Sync state monitoring
  bool _isOnline = true;
  bool _isSyncing = false;
  int _pendingCount = 0;
  bool _isFieldOfficer = false;
  StreamSubscription? _networkSubscription;
  Function(Map<String, dynamic>)? _syncListener;

  @override
  void initState() {
    super.initState();
    _load();
    _initSyncStatus();
  }


  Future<void> _load() async {
    try {
      setState(() { _loading = true; _error = null; });
      final result = await ApiService.getUserProfile();
      if (!mounted) return;
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;

        // Safely extract profile Map
        Map<String, dynamic> profile = {};
        if (data['profile'] is Map) {
          profile = Map<String, dynamic>.from(data['profile'] as Map);
        }

        setState(() {
          _profile = data;
          _firstNameCtrl.text = (data['first_name'] ?? '').toString();
          _lastNameCtrl.text = (data['last_name'] ?? '').toString();
          _phoneCtrl.text = (profile['phone'] ?? '').toString();
          _bioCtrl.text = (profile['bio'] ?? '').toString();
          _avatarUrl = profile['profile_image_url']?.toString();
          _loading = false;
        });

        // Feature #16: hydrate ThemeService with the server preference.
        final serverTheme = profile['theme_preference'];
        if (serverTheme is String) {
          // ignore: use_build_context_synchronously
          Provider.of<ThemeService>(context, listen: false)
              .applyServerPreference(serverTheme);
        }
      } else {
        setState(() { _error = result['message']; _loading = false; });
      }
    } catch (e, stack) {
      debugPrint('Error in ProfileScreen._load(): $e\n$stack');
      if (mounted) {
        setState(() {
          _error = 'Failed to load profile details: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _initSyncStatus() async {
    try {
      final role = await ApiService.getUserRole();
      if (mounted) {
        setState(() {
          _isFieldOfficer = role == 'field_officer';
        });
      }
      if (!NetworkService.isInitialized) {
        await NetworkService.init();
      }
      await _loadSyncStatus();
      _setupSyncListeners();
    } catch (e) {
      debugPrint('Error initializing sync status in profile: $e');
    }
  }

  Future<void> _loadSyncStatus() async {
    try {
      final status = await SyncEngine.getStatus();
      if (mounted) {
        setState(() {
          _isOnline = status['isOnline'] as bool? ?? true;
          _isSyncing = status['isSyncing'] as bool? ?? false;
          _pendingCount = (status['pendingValuations'] as int? ?? 0) +
              (status['pendingAttendance'] as int? ?? 0) +
              (status['pendingPhotos'] as int? ?? 0) +
              (status['pendingSubmitActions'] as int? ?? 0);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOnline = NetworkService.isOnline;
          _isSyncing = false;
          _pendingCount = 0;
        });
      }
    }
  }

  void _setupSyncListeners() {
    _networkSubscription = NetworkService.networkStatusStream.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _loadSyncStatus();
        });
      }
    });

    _syncListener = (event) {
      if (!mounted) return;
      final eventType = event['event'] as String?;
      if (eventType == 'syncStart') {
        setState(() {
          _isSyncing = true;
        });
      } else if (eventType == 'syncComplete' || eventType == 'syncError') {
        setState(() {
          _isSyncing = false;
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _loadSyncStatus();
        });
      } else if (eventType == 'valuationSynced' || eventType == 'syncSuccess') {
        if (eventType == 'syncSuccess') {
          setState(() {
            _isSyncing = false;
          });
        }
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _loadSyncStatus();
        });
      }
    };
    SyncEngine.addListener(_syncListener!);
  }

  @override
  void dispose() {
    _networkSubscription?.cancel();
    if (_syncListener != null) {
      SyncEngine.removeListener(_syncListener!);
    }
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; });
    final result = await ApiService.updateUserProfile({
      'first_name': _firstNameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'bio': _bioCtrl.text.trim(),
    });
    if (!mounted) return;
    setState(() { _saving = false; });
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated'), backgroundColor: AppColors.success),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Update failed'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _pickAvatar() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar upload is not supported on web'), backgroundColor: AppColors.warning),
      );
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() { _uploading = true; });
    final res = await ApiService.uploadUserAvatar(File(picked.path));
    if (!mounted) return;
    setState(() { _uploading = false; });
    if (res['success'] == true) {
      final url = (res['data'] as Map?)?['profile_image_url'] as String?;
      setState(() { _avatarUrl = url; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated'), backgroundColor: AppColors.success),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Upload failed'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    // When used standalone (not inside dashboard), wrap with Scaffold
    if (widget.showAppBar) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(title: const Text('My Profile')),
        body: _buildBody(isDark, bgColor),
      );
    }

    // When embedded in IndexedStack (no Scaffold to avoid nesting issue)
    return Container(
      color: bgColor,
      child: _buildBody(isDark, bgColor),
    );
  }

  Widget _buildBody(bool isDark, Color bgColor) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Custom Header
          Center(
            child: Text(
              'Profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Avatar & Hello title
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : Colors.white,
                          width: 3.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: UserAvatar(
                        imageUrl: _avatarUrl,
                        firstName: _firstNameCtrl.text,
                        lastName: _lastNameCtrl.text,
                        username: _profile?['username'],
                        radius: 48,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Material(
                        color: isDark ? const Color(0xFF334155) : Colors.black,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _uploading ? null : _pickAvatar,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: _uploading
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Hello-${_firstNameCtrl.text.isNotEmpty ? _firstNameCtrl.text : (_profile?['username'] ?? 'User')}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _profile?['email'] ?? _profile?['username'] ?? 'no-email@auditra.com',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Offline sync status banner
          if (_isFieldOfficer) _buildSyncStatusBanner(isDark),

          // Dual Grid Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: widget.onNavigateToProjects,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentLight,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'NEW',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.accent,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.north_east_rounded,
                                    size: 14,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Active Projects',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Assigned valuation projects',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ValuationHistoryScreen(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Statistics',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.analytics_outlined,
                                    size: 14,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Valuation History',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Track submitted reports',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section List Options
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  children: [
                    _buildListItem(
                      context: context,
                      icon: Icons.person_outline_rounded,
                      title: 'Personal Information',
                      subtitle: 'Manage your account details',
                      isDark: isDark,
                      onTap: () => _showEditProfileDialog(context),
                    ),
                    _divider(isDark),
                    _buildListItem(
                      context: context,
                      icon: Icons.palette_outlined,
                      title: 'Theme Preference',
                      subtitle: 'Toggle dark, light or default mode',
                      isDark: isDark,
                      onTap: () => _showThemeBottomSheet(context),
                    ),
                    _divider(isDark),
                    _buildListItem(
                      context: context,
                      icon: Icons.lock_outline_rounded,
                      title: 'Security Settings',
                      subtitle: 'Change password & secure accounts',
                      isDark: isDark,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Modern Logout Button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.error.withOpacity(0.15) : AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.error.withOpacity(isDark ? 0.3 : 0.2),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: () => _confirmLogout(context),
                borderRadius: BorderRadius.circular(24),
                highlightColor: AppColors.error.withOpacity(0.1),
                splashColor: AppColors.error.withOpacity(0.2),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, color: isDark ? const Color(0xFFFCA5A5) : AppColors.error, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Log Out',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFFCA5A5) : AppColors.error,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSyncStatusBanner(bool isDark) {
    // Styles for online vs offline vs pending sync
    final Color bannerBg;
    final Color bannerBorder;
    final Color iconBg;
    final Color iconColor;
    final IconData iconData;
    final String titleText;
    final String subtitleText;
    final VoidCallback? onTapAction;

    if (!_isOnline) {
      bannerBg = isDark ? const Color(0xFF2C1F15) : const Color(0xFFFFF7ED);
      bannerBorder = isDark ? const Color(0xFF78350F) : const Color(0xFFFFEDD5);
      iconBg = isDark ? const Color(0xFF78350F) : const Color(0xFFFFE0B2);
      iconColor = Colors.orange[800]!;
      iconData = Icons.cloud_off_rounded;
      titleText = 'Offline Mode';
      subtitleText = _pendingCount > 0 
          ? '$_pendingCount report${_pendingCount > 1 ? "s" : ""} queued. Connect to sync.' 
          : 'Changes will sync when online.';
      onTapAction = () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device is offline. Connect to the internet to sync data.'),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 3),
          ),
        );
      };
    } else if (_pendingCount > 0) {
      bannerBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F9FF);
      bannerBorder = isDark ? const Color(0xFF334155) : const Color(0xFFBAE6FD);
      iconBg = isDark ? const Color(0xFF334155) : const Color(0xFFE0F2FE);
      iconColor = AppColors.accent;
      iconData = Icons.sync_rounded;
      titleText = _isSyncing ? 'Syncing Reports...' : 'Sync Pending';
      subtitleText = _isSyncing 
          ? 'Uploading report data to server...' 
          : '$_pendingCount report${_pendingCount > 1 ? "s" : ""} waiting to upload. Tap to sync.';
      onTapAction = () async {
        if (_isSyncing) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Synchronization is already in progress...'),
              backgroundColor: AppColors.accent,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Starting synchronization...'),
              backgroundColor: AppColors.accent,
              duration: Duration(seconds: 2),
            ),
          );
          await SyncEngine.syncAll();
        }
      };
    } else {
      bannerBg = isDark ? const Color(0xFF14241C) : const Color(0xFFF0FDF4);
      bannerBorder = isDark ? const Color(0xFF166534) : const Color(0xFFDCFCE7);
      iconBg = isDark ? const Color(0xFF166534) : const Color(0xFFD1FAE5);
      iconColor = const Color(0xFF16A34A);
      iconData = Icons.cloud_done_rounded;
      titleText = 'All Reports Synced';
      subtitleText = 'All local reports synced & secure';
      onTapAction = () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database is fully synchronized'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      };
    }

    return GestureDetector(
      onTap: onTapAction,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bannerBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: bannerBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: _isSyncing && _isOnline && _pendingCount > 0
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: iconColor,
                      ),
                    )
                  : Icon(
                      iconData,
                      color: iconColor,
                      size: 20,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            if (_isOnline && _pendingCount > 0 && !_isSyncing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'SYNC',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor ?? AppColors.accent,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white : const Color(0xFF111827),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 64,
      endIndent: 20,
      color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Edit Personal Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _modalField('First Name', _firstNameCtrl, isDark),
                    _modalField('Last Name', _lastNameCtrl, isDark),
                    _modalField('Phone', _phoneCtrl, isDark),
                    _modalField('Bio', _bioCtrl, isDark, maxLines: 3),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                setModalState(() => _saving = true);
                                await _save();
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _modalField(String label, TextEditingController ctrl, bool isDark, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827), fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppColors.accent,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeBottomSheet(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Choose Theme Mode',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildThemeOption(
                    title: 'System Default',
                    subtitle: 'Follow device color scheme',
                    icon: Icons.monitor_rounded,
                    selected: themeService.preference == 'system',
                    onTap: () {
                      themeService.setMode('system');
                      Navigator.pop(context);
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildThemeOption(
                    title: 'Light Mode',
                    subtitle: 'Classic bright layout',
                    icon: Icons.light_mode_rounded,
                    selected: themeService.preference == 'light',
                    onTap: () {
                      themeService.setMode('light');
                      Navigator.pop(context);
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildThemeOption(
                    title: 'Dark Mode',
                    subtitle: 'Comfortable low-light layout',
                    icon: Icons.dark_mode_rounded,
                    selected: themeService.preference == 'dark',
                    onTap: () {
                      themeService.setMode('dark');
                      Navigator.pop(context);
                    },
                    isDark: isDark,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withOpacity(0.08)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.accent
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.accent : (isDark ? Colors.white70 : Colors.black54),
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.accent,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning/Logout Icon Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Text(
                  'Confirm Logout',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                // Description
                Text(
                  'Are you sure you want to log out of your account?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 28),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFD1D5DB),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext); // Close dialog
                          await ApiService.logout();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
