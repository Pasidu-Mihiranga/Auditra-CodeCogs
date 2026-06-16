import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import '../services/api_service.dart';
import '../theme/app_colors.dart';

/// Feature #1 — Per-project standup chat (work-to-do / work-done templates + @mention).
class ProjectStandupsScreen extends StatefulWidget {
  final int projectId;
  final String? projectTitle;
  const ProjectStandupsScreen({super.key, required this.projectId, this.projectTitle});

  @override
  State<ProjectStandupsScreen> createState() => _ProjectStandupsScreenState();
}

class _ProjectStandupsScreenState extends State<ProjectStandupsScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  bool _sending = false;
  String _kind = 'free';
  String? _currentUsername;

  // Mention autocomplete state
  String? _mentionQuery;

  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _wsClosed = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUsername();
    _loadAll();
    _connectWebSocket();
  }

  Future<void> _loadCurrentUsername() async {
    final username = await ApiService.getUsername();
    if (!mounted) return;
    setState(() => _currentUsername = username);
  }

  @override
  void dispose() {
    _wsClosed = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    try {
      _channel?.sink.close(ws_status.normalClosure);
    } catch (_) {}
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final msgRes = await ApiService.getStandupMessages(widget.projectId);
    final memRes = await ApiService.getStandupMembers(widget.projectId);
    if (!mounted) return;
    setState(() {
      if (msgRes['success'] == true && msgRes['data'] is List) {
        _messages = List<Map<String, dynamic>>.from(msgRes['data']);
      }
      if (memRes['success'] == true && memRes['data'] is List) {
        _members = List<Map<String, dynamic>>.from(memRes['data']);
      }
      _loading = false;
    });
    _scrollToBottom();
  }

  Future<void> _connectWebSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return;
    // baseUrl is http://10.0.2.2:8000/api → ws host = 10.0.2.2:8000
    final base = ApiService.baseUrl.replaceFirst(RegExp(r'^http'), 'ws').replaceFirst('/api', '');
    final url = Uri.parse('$base/ws/standups/${widget.projectId}/?token=$token');
    try {
      _channel = WebSocketChannel.connect(url);
      _channel!.stream.listen(
        (event) {
          try {
            final data = jsonDecode(event) as Map<String, dynamic>;
            if (data['type'] == 'standup_message' && data['message'] != null) {
              final msg = Map<String, dynamic>.from(data['message']);
              if (!mounted) return;
              setState(() {
                if (!_messages.any((m) => m['id'] == msg['id'])) {
                  _messages.add(msg);
                }
              });
              _scrollToBottom();
            }
          } catch (_) {}
        },
        onDone: () {
          if (!_wsClosed) {
            _reconnectTimer?.cancel();
            _reconnectTimer = Timer(const Duration(seconds: 3), _connectWebSocket);
          }
        },
        onError: (_) {
          if (!_wsClosed) {
            _reconnectTimer?.cancel();
            _reconnectTimer = Timer(const Duration(seconds: 3), _connectWebSocket);
          }
        },
      );
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        try { _channel?.sink.add(jsonEncode({'action': 'ping'})); } catch (_) {}
      });
    } catch (_) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 3), _connectWebSocket);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final res = await ApiService.postStandupMessage(widget.projectId, text, kind: _kind);
    if (!mounted) return;
    if (res['success'] == true && res['data'] is Map) {
      final msg = Map<String, dynamic>.from(res['data']);
      setState(() {
        if (!_messages.any((m) => m['id'] == msg['id'])) {
          _messages.add(msg);
        }
        _controller.clear();
        _kind = 'free';
        _sending = false;
        _mentionQuery = null;
      });
      _scrollToBottom();
    } else {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Failed to send')),
      );
    }
  }

  void _onTextChanged(String value) {
    final match = RegExp(r'@(\w*)$').firstMatch(value);
    setState(() => _mentionQuery = match?.group(1));
  }

  void _insertMention(Map<String, dynamic> member) {
    final name = (member['username'] ?? '').toString();
    final newValue = _controller.text.replaceFirst(RegExp(r'@\w*$'), '@$name ');
    _controller.text = newValue;
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: newValue.length));
    setState(() => _mentionQuery = null);
  }

  List<Map<String, dynamic>> get _filteredMembers {
    if (_mentionQuery == null) return [];
    final q = _mentionQuery!.toLowerCase();
    return _members.where((m) {
      final u = (m['username'] ?? '').toString().toLowerCase();
      final n = ('${m['first_name'] ?? ''} ${m['last_name'] ?? ''}').toLowerCase();
      return q.isEmpty || u.contains(q) || n.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF0B1220) : const Color(0xFFF4F7FB), // Very soft blue-grey background
      body: Stack(
        children: [
          // Chat messages area
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : _messages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.chat_bubble_outline_rounded, size: 60, color: AppColors.accent.withOpacity(0.3)),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No messages yet.\\nStart the standup!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 20, 16, 140),
                              itemCount: _messages.length,
                              itemBuilder: (ctx, i) => _buildMessage(_messages[i]),
                            ),
                ),
                if (_filteredMembers.isNotEmpty && _mentionQuery != null)
                  _buildMentionList(),
              ],
            ),
          ),
          // Floating template buttons & input bar at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.35, 1.0],
                  colors: [
                    (isDark ? const Color(0xFF0B1220) : const Color(0xFFF4F7FB)).withOpacity(0.0),
                    (isDark ? const Color(0xFF0B1220) : const Color(0xFFF4F7FB)).withOpacity(0.8),
                    isDark ? const Color(0xFF0B1220) : const Color(0xFFF4F7FB),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),
                    _buildTemplateBar(),
                    _buildInputBar(),
                  ],
                ),
              ),
            ),
          ),
          // Dynamic island header
          _buildDynamicIsland(context),
        ],
      ),
    );
}

  Widget _buildDynamicIsland(BuildContext context) {
    return AnimatedBuilder(
      animation: _scrollController,
      builder: (context, child) {
        double offset = 0;
        if (_scrollController.hasClients) {
          offset = _scrollController.offset.clamp(0.0, 100.0);
        }
        final factor = offset / 100.0;
        final marginH = 16.0 + (16.0 * factor); // Scales from 16 to 32
        final topPadding = MediaQuery.of(context).padding.top;
        final outerTopMargin = topPadding + 12.0; // Always floating below status bar

        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: EdgeInsets.only(
              top: outerTopMargin,
              left: marginH,
              right: marginH,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40), // Always a pill shape
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                child: Container(
                  height: kToolbarHeight + 8.0 - (8.0 * factor), // Shrinks slightly when scrolling
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00A3FF).withOpacity(0.55), 
                        const Color(0xFF0082FF).withOpacity(0.35),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2 + (0.1 * factor)),
                      width: 1.2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -30,
                        right: -20,
                        child: CircleAvatar(
                          radius: 80,
                          backgroundColor: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      Positioned(
                        bottom: -20,
                        left: 30,
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.25),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.of(context).pop(),
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(10.0),
                                  child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.projectTitle ?? 'Daily Standup',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Daily Standup',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.95),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final author = (msg['author_name'] ?? '').toString();
    final authorUsername = (msg['author_username'] ?? '').toString();
    final role = (msg['author_role'] ?? '').toString();
    final body = (msg['body'] ?? '').toString();
    final kind = (msg['kind'] ?? 'free').toString();
    final createdAt = (msg['created_at'] ?? '').toString();
    final isMine = _currentUsername != null && authorUsername == _currentUsername;
    final seenBy = ((msg['seen_by'] is List) ? List<Map<String, dynamic>>.from(msg['seen_by']) : <Map<String, dynamic>>[]);
    final seenByOthers = seenBy.where((u) => (u['username'] ?? '').toString() != authorUsername).toList();
    final kindLabel = {
      'work_to_do': 'Work To Do',
      'work_done': 'Work Done',
    }[kind];
    final kindColor = {
      'work_to_do': Colors.orange,
      'work_done': Colors.green,
    }[kind];

    final bubbleColor = isMine
        ? AppColors.accent.withOpacity(0.15) // Soft Light Blue Bubble
        : (isDark ? const Color(0xFF1E293B) : Colors.white);

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(isMine ? 20 : 6),
      bottomRight: Radius.circular(isMine ? 6 : 20),
    );

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: isMine ? Alignment.bottomRight : Alignment.bottomLeft,
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.accent.withOpacity(0.15),
              child: Text(
                author.isNotEmpty ? author[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
              ),
            ),
            const SizedBox(width: 8),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: isMine ? AppColors.accent.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                borderRadius: borderRadius,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // Provide tactile feedback on tap, future interactive expansions can go here.
                  },
                  borderRadius: borderRadius,
                  splashColor: AppColors.accent.withOpacity(0.2),
                  highlightColor: AppColors.accent.withOpacity(0.1),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: borderRadius,
                    ),
                    child: IntrinsicWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                          mainAxisSize: MainAxisSize.min, // Fix full width expansion
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                isMine ? 'You' : author,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accent,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8), // Add some spacing before time
                            Text(
                              _formatTime(createdAt),
                              style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500], fontSize: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        if (!isMine) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  role,
                                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (kindLabel != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isMine ? kindColor!.withOpacity(0.15) : kindColor!.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              kindLabel,
                              style: TextStyle(
                                color: kindColor, 
                                fontSize: 10, 
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        _buildMessageBody(body, isMine, isDark),
                        if (isMine) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.done_all_rounded, size: 14, color: AppColors.accent),
                                const SizedBox(width: 4),
                                Text(
                                  seenByOthers.isNotEmpty
                                      ? 'Seen'
                                      : 'Sent',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        ],
      ),
    ),
    );
  }

  String _formatTime(String isoTime) {
    if (isoTime.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      final hh = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final mm = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hh:$mm $ampm';
    } catch (_) {
      return '';
    }
  }

  String _formatRole(String role) {
    if (role.isEmpty) return '';
    return role
        .split('_')
        .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  Widget _buildMessageBody(String body, bool isMine, bool isDark) {
    final words = body.split(RegExp(r'\s+'));
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 15,
          height: 1.4,
          color: isDark ? Colors.white : Colors.black87,
        ),
        children: words.map((word) {
          final isMention = word.startsWith('@');
          return TextSpan(
            text: '$word ',
            style: isMention
                ? TextStyle(
                    color: isMine ? AppColors.accent : AppColors.accent, 
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                  )
                : null,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMentionList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _filteredMembers.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : Colors.grey.shade100),
        itemBuilder: (ctx, i) {
          final m = _filteredMembers[i];
          final username = (m['username'] ?? '').toString();
          final role = _formatRole((m['role'] ?? '').toString());
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.accent.withOpacity(0.15),
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              '@$username',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isDark ? Colors.grey[100] : Colors.black87,
              ),
            ),
            subtitle: Text(
              role,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey.shade600),
            ),
            onTap: () => _insertMention(m),
          );
        },
      ),
    );
  }

  Widget _buildTemplateBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget floatingKindButton({
      required String label,
      required IconData icon,
      required String value,
      required Color color,
    }) {
      final selected = _kind == value;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => setState(() => _kind = selected ? 'free' : value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? color
                  : (isDark ? Colors.white.withOpacity(0.08) : Colors.white),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: selected ? color : (isDark ? Colors.white.withOpacity(0.15) : Colors.grey.shade300),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: selected ? color.withOpacity(0.3) : Colors.black.withOpacity(0.08),
                  blurRadius: selected ? 8 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: selected ? Colors.white : color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : (isDark ? Colors.grey[300] : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          floatingKindButton(
            label: 'Work To Do',
            icon: Icons.assignment_late_rounded,
            value: 'work_to_do',
            color: Colors.orange.shade600,
          ),
          const SizedBox(width: 12),
          floatingKindButton(
            label: 'Work Done',
            icon: Icons.task_alt_rounded,
            value: 'work_done',
            color: Colors.green.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom > 0 ? 16 : 24),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : AppColors.accent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 5),
            )
          ],
        ),
        padding: const EdgeInsets.only(left: 20, right: 6, top: 6, bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Text field
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: _onTextChanged,
                maxLines: 4,
                minLines: 1,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 15),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Right send button
            Padding(
              padding: const EdgeInsets.only(bottom: 2, right: 2),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _sending ? null : _send,
                  borderRadius: BorderRadius.circular(30),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _controller.text.trim().isEmpty 
                          ? (isDark ? const Color(0xFF334155) : Colors.grey.shade200) 
                          : AppColors.accent,
                      boxShadow: _controller.text.trim().isEmpty ? null : [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Center(
                      child: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : Icon(
                              Icons.send_rounded,
                              color: _controller.text.trim().isEmpty 
                                  ? (isDark ? Colors.grey[500] : Colors.grey[400]) 
                                  : Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
