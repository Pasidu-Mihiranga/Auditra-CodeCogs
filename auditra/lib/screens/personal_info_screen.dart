import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _roleInfo;
  bool _isLoading = true;
  String? _username;

  @override
  void initState() {
    super.initState();
    _loadPersonalInfo();
  }

  Future<void> _loadPersonalInfo() async {
    setState(() => _isLoading = true);

    final username = await ApiService.getUsername();
    final profileResult = await ApiService.getProfile();
    final roleResult = await ApiService.getMyRole();

    if (mounted) {
      setState(() {
        _username = username;
        if (profileResult['success']) {
          _profile = profileResult['data'];
        }
        if (roleResult['success']) {
          _roleInfo = roleResult['data'];
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 120.0,
              floating: false,
              pinned: true,
              backgroundColor: const Color(0xFF0D47A1),
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'Personal Information',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                centerTitle: true,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20,
                        top: -20,
                        child: Icon(
                          Icons.person_pin_rounded,
                          color: Colors.white.withOpacity(0.1),
                          size: 150,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ];
        },
        body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPersonalInfo,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile Header Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.blue[100],
                              child: Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.blue[700],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _profile?['first_name'] != null && _profile?['last_name'] != null
                                  ? '${_profile!['first_name']} ${_profile!['last_name']}'
                                  : _username ?? 'User',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_roleInfo?['role_display'] != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: Text(
                                  _roleInfo!['role_display'],
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Personal Information Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                                const SizedBox(width: 12),
                                const Text(
                                  'Personal Information',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildInfoRow('Username', _username ?? 'N/A', Icons.person),
                            const Divider(height: 24),
                            _buildInfoRow('Email', _profile?['email'] ?? 'N/A', Icons.email),
                            if (_profile?['first_name'] != null) ...[
                              const Divider(height: 24),
                              _buildInfoRow('First Name', _profile!['first_name'], Icons.badge),
                            ],
                            if (_profile?['last_name'] != null) ...[
                              const Divider(height: 24),
                              _buildInfoRow('Last Name', _profile!['last_name'], Icons.badge),
                            ],
                            if (_profile?['date_joined'] != null) ...[
                              const Divider(height: 24),
                              _buildInfoRow(
                                'Date Joined',
                                _formatDate(_profile!['date_joined']),
                                Icons.calendar_today,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Role Information Card
                    if (_roleInfo != null)
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.work_outline, color: Colors.blue[700], size: 24),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Role Information',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _buildInfoRow('Role', _roleInfo!['role_display'] ?? 'N/A', Icons.badge),
                              if (_roleInfo?['salary'] != null) ...[
                                const Divider(height: 24),
                                _buildInfoRow(
                                  'Salary',
                                  'Rs ${_formatNumber(_roleInfo!['salary'])}',
                                  Icons.attach_money,
                                ),
                              ],
                              if (_roleInfo?['assigned_by_username'] != null) ...[
                                const Divider(height: 24),
                                _buildInfoRow(
                                  'Assigned By',
                                  _roleInfo!['assigned_by_username'],
                                  Icons.person_add,
                                ),
                              ],
                              if (_roleInfo?['assigned_at'] != null) ...[
                                const Divider(height: 24),
                                _buildInfoRow(
                                  'Assigned At',
                                  _formatDate(_roleInfo!['assigned_at']),
                                  Icons.access_time,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatNumber(dynamic number) {
    if (number == null) return '0';
    try {
      final num = number is int ? number : double.parse(number.toString());
      return num.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    } catch (e) {
      return number.toString();
    }
  }
}

