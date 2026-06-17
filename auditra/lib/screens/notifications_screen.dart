import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'project_standups_screen.dart';
import 'field_officer/screens/valuation_history_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String? _error;
  String _activeFilter = 'all'; // 'all', 'unread', or a category name
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _load();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await ApiService.getNotifications();
    if (!mounted) return;
    if (result['success'] == true) {
      final raw = result['data'];
      final list = raw is List ? raw : (raw['results'] ?? []);
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(list as List);
        _loading = false;
      });
      _fadeCtrl.forward(from: 0);
    } else {
      setState(() { _error = result['message'] ?? 'Failed to load'; _loading = false; });
    }
  }

  Future<void> _markRead(int id) async {
    await ApiService.markNotificationRead(id);
    _load();
  }

  Future<void> _markAllRead() async {
    await ApiService.markAllNotificationsRead();
    _load();
  }

  // ─── Filtered list ─────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_activeFilter == 'all') return _notifications;
    if (_activeFilter == 'unread') {
      return _notifications.where((n) => n['is_read'] != true).toList();
    }
    // Filter by category
    return _notifications.where((n) {
      return (n['category']?.toString().toLowerCase() ?? '') == _activeFilter.toLowerCase();
    }).toList();
  }

  // ─── Category helpers ──────────────────────────────────────────────

  Color _categoryColor(String? category) {
    switch ((category ?? '').toLowerCase()) {
      case 'chat':
        return const Color(0xFF2563EB);
      case 'document':
        return const Color(0xFF7C3AED);
      case 'project':
        return const Color(0xFF0EA5A4);
      case 'payment':
        return const Color(0xFF059669);
      case 'leave':
      case 'attendance':
        return const Color(0xFFD97706);
      case 'valuation':
        return const Color(0xFF0284C7);
      default:
        return AppColors.accent;
    }
  }

  IconData _categoryIcon(String? category) {
    switch ((category ?? '').toLowerCase()) {
      case 'chat':
        return Icons.chat_bubble_rounded;
      case 'document':
        return Icons.description_rounded;
      case 'project':
        return Icons.work_rounded;
      case 'payment':
        return Icons.payments_rounded;
      case 'leave':
      case 'attendance':
        return Icons.event_note_rounded;
      case 'valuation':
        return Icons.assessment_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  // ─── Time helpers ──────────────────────────────────────────────────

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _timeAgo(dynamic value) {
    final dt = _parseDate(value);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _dateGroup(dynamic value) {
    final dt = _parseDate(value);
    if (dt == null) return 'Earlier';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notifDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(notifDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'This Week';
    return 'Earlier';
  }

  Map<String, List<Map<String, dynamic>>> _grouped(List<Map<String, dynamic>> items) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final n in items) {
      final label = _dateGroup(n['created_at']);
      groups.putIfAbsent(label, () => []).add(n);
    }
    return groups;
  }

  List<String> _getUniqueCategories() {
    final cats = <String>{};
    for (final n in _notifications) {
      final cat = n['category']?.toString().toLowerCase() ?? '';
      if (cat.isNotEmpty) cats.add(cat);
    }
    return cats.toList();
  }

  int _getCategoryCount(String cat) {
    return _notifications.where((n) =>
      (n['category']?.toString().toLowerCase() ?? '') == cat.toLowerCase()
    ).length;
  }

  // ─── Navigation handler ─────────────────────────────────────────

  void _handleNotificationTap(Map<String, dynamic> n) {
    // Mark as read
    final isRead = n['is_read'] == true;
    if (!isRead && n['id'] != null) {
      _markRead(n['id'] as int);
    }

    final category = (n['category'] ?? '').toString().toLowerCase();
    final title = n['title']?.toString() ?? '';
    final projectId = n['project_id'] ?? n['related_object_id'];

    switch (category) {
      case 'chat':
        if (projectId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProjectStandupsScreen(
                projectId: projectId is int ? projectId : int.tryParse(projectId.toString()) ?? 0,
                projectTitle: _extractProjectName(title),
              ),
            ),
          );
        }
        break;

      case 'valuation':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ValuationHistoryScreen()),
        );
        break;

      case 'attendance':
      case 'leave':
        // Navigate back to dashboard attendance tab
        Navigator.pop(context);
        break;

      case 'project':
        if (projectId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProjectStandupsScreen(
                projectId: projectId is int ? projectId : int.tryParse(projectId.toString()) ?? 0,
                projectTitle: _extractProjectName(title),
              ),
            ),
          );
        }
        break;

      default:
        // Show detail bottom sheet for unknown categories
        _showNotificationDetail(n);
        break;
    }
  }

  String _extractProjectName(String title) {
    // Try to extract project name from notification title
    // e.g., "Valuation created — Full Company Audit" → "Full Company Audit"
    if (title.contains('—')) {
      return title.split('—').last.trim();
    }
    if (title.contains('-')) {
      return title.split('-').last.trim();
    }
    return title;
  }

  void _showNotificationDetail(Map<String, dynamic> n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catColor = _categoryColor(n['category']?.toString());
    final catIcon = _categoryIcon(n['category']?.toString());

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: catColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(catIcon, color: catColor, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                n['title']?.toString() ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                n['message']?.toString() ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _timeAgo(n['created_at']),
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredNotifications;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : _error != null
                      ? _buildErrorState(isDark)
                      : _notifications.isEmpty
                          ? _buildEmptyState(isDark)
                          : filtered.isEmpty
                              ? _buildNoResultsState(isDark)
                              : _buildNotificationsList(isDark, filtered),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    final unreadCount = _notifications.where((n) => n['is_read'] != true).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 12, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                isDark: isDark,
                onTap: () => Navigator.pop(context),
              ),
              const Spacer(),
              Column(
                children: [
                  Text('Notifications', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    letterSpacing: -0.3,
                  )),
                  if (!_loading && _notifications.isNotEmpty)
                    Text('$unreadCount unread', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent,
                    )),
                ],
              ),
              const Spacer(),
              _buildIconButton(
                icon: Icons.more_horiz_rounded,
                isDark: isDark,
                onTap: () => _showActionsSheet(context, isDark),
              ),
            ],
          ),
          if (!_loading && _notifications.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildFilterChip('All', _notifications.length, 'all', isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('Unread', unreadCount, 'unread', isDark),
                  const SizedBox(width: 8),
                  ..._getUniqueCategories().map((cat) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildCategoryFilterChip(cat, isDark),
                  )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required bool isDark, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 16, color: isDark ? Colors.white : const Color(0xFF111827)),
      ),
    );
  }

  Widget _buildFilterChip(String label, int count, String filterKey, bool isDark) {
    final selected = _activeFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : (isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: selected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
            )),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withAlpha(40) : AppColors.accent.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(count.toString(), style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800,
                color: selected ? Colors.white : AppColors.accent,
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilterChip(String category, bool isDark) {
    final color = _categoryColor(category);
    final icon = _categoryIcon(category);
    final prettyName = category[0].toUpperCase() + category.substring(1);
    final selected = _activeFilter == category;
    final count = _getCategoryCount(category);

    return GestureDetector(
      onTap: () => setState(() => _activeFilter = selected ? 'all' : category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : color.withAlpha(15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : color.withAlpha(40)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: selected ? Colors.white : color),
            const SizedBox(width: 5),
            Text(prettyName, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: selected ? Colors.white : color,
            )),
            const SizedBox(width: 4),
            Text('$count', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800,
              color: selected ? Colors.white.withAlpha(200) : color.withAlpha(150),
            )),
          ],
        ),
      ),
    );
  }

  // ─── States ────────────────────────────────────────────────────────

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: AppColors.accent.withAlpha(15), shape: BoxShape.circle),
              child: Icon(Icons.notifications_off_outlined, size: 60, color: AppColors.accent),
            ),
            const SizedBox(height: 32),
            Text('No Notifications', style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF111827),
            )),
            const SizedBox(height: 10),
            Text("You're all caught up!\nWe'll notify you when something new happens.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280), height: 1.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off_rounded, size: 48, color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF)),
          const SizedBox(height: 16),
          Text('No notifications match this filter', style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
          )),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _activeFilter = 'all'),
            child: Text('Show all', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Notifications List ────────────────────────────────────────────

  Widget _buildNotificationsList(bool isDark, List<Map<String, dynamic>> items) {
    final groups = _grouped(items);
    final groupOrder = ['Today', 'Yesterday', 'This Week', 'Earlier'];
    final orderedLabels = groupOrder.where((g) => groups.containsKey(g)).toList();

    return FadeTransition(
      opacity: _fadeCtrl,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.accent,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
          itemCount: orderedLabels.length,
          itemBuilder: (context, groupIndex) {
            final groupLabel = orderedLabels[groupIndex];
            final groupItems = groups[groupLabel]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date group header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 3, height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(groupLabel, style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                        letterSpacing: 0.5,
                      )),
                      const Spacer(),
                      Text('${groupItems.length}', style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
                      )),
                    ],
                  ),
                ),
                // Notifications card container
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      children: groupItems.asMap().entries.map((entry) {
                        final i = entry.key;
                        final n = entry.value;
                        return Dismissible(
                          key: ValueKey('notif_${n['id'] ?? i}'),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => _deleteNotification(n),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            color: AppColors.error.withAlpha(20),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildNotificationTile(n, isDark),
                              if (i < groupItems.length - 1)
                                Divider(height: 1, thickness: 1, indent: 72, endIndent: 16,
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _deleteNotification(Map<String, dynamic> n) async {
    final id = n['id'];
    // Remove from local list immediately for snappy UX
    setState(() {
      _notifications.removeWhere((item) => item['id'] == id);
    });

    // Try to delete on the server
    if (id != null) {
      final deleted = await ApiService.deleteNotification(id as int);
      if (!deleted) {
        // If server doesn't support DELETE, at least mark as read
        await ApiService.markNotificationRead(id);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notification removed'),
          backgroundColor: AppColors.accent,
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () => _load(), // Reload from server to undo
          ),
        ),
      );
    }
  }

  Widget _buildNotificationTile(Map<String, dynamic> n, bool isDark) {
    final isRead = n['is_read'] == true;
    final category = n['category']?.toString() ?? '';
    final catColor = _categoryColor(category);
    final catIcon = _categoryIcon(category);
    final title = n['title']?.toString() ?? '';
    final message = n['message']?.toString() ?? '';
    final timeStr = _timeAgo(n['created_at']);

    return Material(
      color: isRead
          ? Colors.transparent
          : (isDark ? AppColors.accent.withAlpha(8) : AppColors.accent.withAlpha(6)),
      child: InkWell(
        onTap: () => _handleNotificationTap(n),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [catColor.withAlpha(30), catColor.withAlpha(15)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(catIcon, color: catColor, size: 20),
              ),
              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14, fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF111827), height: 1.3,
                            )),
                        ),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(timeStr, style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
                          )),
                        ),
                        if (!isRead) ...[
                          const SizedBox(width: 8),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: AppColors.accent.withAlpha(80), blurRadius: 6, offset: const Offset(0, 1)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(message, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w400,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280), height: 1.4,
                      )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Actions Sheet ─────────────────────────────────────────────────

  void _showActionsSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28), topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              )),
              const SizedBox(height: 24),
              _buildSheetAction(
                icon: Icons.done_all_rounded, label: 'Mark all as read',
                color: AppColors.accent, isDark: isDark,
                onTap: () { Navigator.pop(context); _markAllRead(); },
              ),
              const SizedBox(height: 10),
              _buildSheetAction(
                icon: Icons.refresh_rounded, label: 'Refresh notifications',
                color: const Color(0xFF059669), isDark: isDark,
                onTap: () { Navigator.pop(context); _load(); },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Text('Cancel', style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                  )),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetAction({
    required IconData icon, required String label,
    required Color color, required bool isDark, required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 14),
              Text(label, style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF111827),
              )),
            ],
          ),
        ),
      ),
    );
  }
}
