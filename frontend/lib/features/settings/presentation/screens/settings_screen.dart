import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';
import '../../../../core/data/settings_manager.dart';
import '../../../../core/data/voice_settings.dart';
import '../../../../core/services/tts_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../core/config/api_config.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'how_it_works_screen.dart';
import '../widgets/voice_selection_modal.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _scoringMode = 'AI';
  bool _isLoading = true;

  // Server status states
  final Map<String, String> _serverStatus = {
    'backend': 'unknown',
    'tts': 'unknown',
    'stt': 'unknown',
    'minio': 'unknown',
  };
  bool _isCheckingStatus = false;

  // Voice settings state
  final TtsService _ttsService = TtsService();

  List<VoiceModel> _availableVoices = [];
  String _proponentVoice = 'en_US-amy-medium';
  String _opponentVoice = 'en_US-ryan-high';

  String? _errorMessage;
  bool _isAudioCacheEnabled = true;
  bool _isKaraokeEnabled = true;
  String _cacheSize = '0 KB';

  // Theme colors
  static const Color neonGreen = Color(0xFF00FF88);
  static const Color neonPurple = Color(0xFF8E2DE2);
  static const Color neonBlue = Color(0xFF00B4DB);

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadVoices();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final mode = await SettingsManager.getScoringMode();
    final proVoice = await VoiceSettings.getProponentVoice();
    final oppVoice = await VoiceSettings.getOpponentVoice();
    final cacheEnabled = await VoiceSettings.getAudioCacheEnabled();

    final karaokeEnabled = await VoiceSettings.getKaraokeEnabled();

    await _updateCacheSize();

    setState(() {
      _scoringMode = mode;
      _proponentVoice = proVoice;
      _opponentVoice = oppVoice;
      _isAudioCacheEnabled = cacheEnabled;
      _isKaraokeEnabled = karaokeEnabled;
      _isLoading = false;
    });
  }

  Future<void> _updateCacheSize() async {
    final bytes = await _ttsService.getCacheSize();
    setState(() {
      if (bytes < 1024) {
        _cacheSize = '$bytes B';
      } else if (bytes < 1024 * 1024) {
        _cacheSize = '${(bytes / 1024).toStringAsFixed(1)} KB';
      } else {
        _cacheSize = '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    });
  }

  Future<void> _toggleAudioCache(bool value) async {
    await VoiceSettings.setAudioCacheEnabled(value);
    setState(() => _isAudioCacheEnabled = value);
    if (!value) {
      // Optional: Clear cache when disabling? No, let user decide.
    }
  }

  Future<void> _toggleKaraoke(bool value) async {
    await VoiceSettings.setKaraokeEnabled(value);
    setState(() => _isKaraokeEnabled = value);
  }

  Future<void> _clearAudioCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Clear Audio Cache?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will delete all downloaded voice files. They will be re-downloaded as needed.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: neonGreen)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _ttsService.clearAudioCache();
      await _updateCacheSize();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Audio cache cleared')));
      }
    }
  }

  Future<void> _loadVoices() async {
    try {
      setState(() => _errorMessage = null);
      final voicesData = await _ttsService.getVoices();
      print('SettingsScreen: Loaded ${voicesData.length} voices'); // DEBUG LOG
      setState(() {
        _availableVoices = voicesData
            .map((v) => VoiceModel.fromJson(v))
            .toList();
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _updateProponentVoice(String? voiceId) async {
    if (voiceId == null) return;
    await VoiceSettings.setProponentVoice(voiceId);
    setState(() => _proponentVoice = voiceId);
  }

  Future<void> _updateOpponentVoice(String? voiceId) async {
    if (voiceId == null) return;
    await VoiceSettings.setOpponentVoice(voiceId);
    setState(() => _opponentVoice = voiceId);
  }

  Future<void> _updateScoringMode(String? newMode) async {
    if (newMode == null) return;
    await SettingsManager.setScoringMode(newMode);
    setState(() => _scoringMode = newMode);
  }

  Future<void> _checkAllServerStatus() async {
    setState(() => _isCheckingStatus = true);

    // Check Backend
    try {
      final backendResponse = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/'))
          .timeout(const Duration(seconds: 5));
      setState(
        () => _serverStatus['backend'] = backendResponse.statusCode == 200
            ? 'online'
            : 'error',
      );
    } catch (e) {
      setState(() => _serverStatus['backend'] = 'offline');
    }

    // Check TTS Service
    try {
      final ttsResponse = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/tts/health'))
          .timeout(const Duration(seconds: 5));
      if (ttsResponse.statusCode == 200) {
        final data = jsonDecode(ttsResponse.body);
        setState(
          () => _serverStatus['tts'] = data['status'] == 'healthy'
              ? 'online'
              : 'error',
        );
      } else {
        setState(() => _serverStatus['tts'] = 'error');
      }
    } catch (e) {
      setState(() => _serverStatus['tts'] = 'offline');
    }

    // Check STT Service
    try {
      final sttResponse = await http
          .get(Uri.parse(ApiConfig.sttHealthUrl))
          .timeout(const Duration(seconds: 5));
      if (sttResponse.statusCode == 200) {
        final data = jsonDecode(sttResponse.body);
        setState(
          () => _serverStatus['stt'] = data['status'] == 'healthy'
              ? 'online'
              : 'error',
        );
      } else {
        setState(() => _serverStatus['stt'] = 'error');
      }
    } catch (e) {
      setState(() => _serverStatus['stt'] = 'offline');
    }

    // Check MinIO (via backend proxy or direct)
    try {
      // MinIO console runs on port 9001, we check if responsive
      final minioUrl = ApiConfig.baseUrl
          .replaceAll(':3000', ':9001')
          .replaceAll(':3001', ':9001');
      final minioResponse = await http
          .get(Uri.parse(minioUrl))
          .timeout(const Duration(seconds: 5));
      setState(
        () => _serverStatus['minio'] = minioResponse.statusCode < 500
            ? 'online'
            : 'error',
      );
    } catch (e) {
      setState(() => _serverStatus['minio'] = 'offline');
    }

    setState(() => _isCheckingStatus = false);
  }

  Future<void> _openGitHub() async {
    final uri = Uri.parse('https://github.com/TrendySloth1001/argumentbot');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open GitHub')));
      }
    }
  }

  void _showPolicyPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PolicyPage()),
    );
  }

  Widget _buildServerStatusList() {
    return Column(
      children: [
        Container(height: 1, color: Colors.grey[900]),
        _buildServerStatusRow('Backend API', 'backend'),
        _buildDivider(),
        _buildDivider(),
        _buildServerStatusRow('TTS Service', 'tts'),
        _buildDivider(),
        _buildServerStatusRow('STT Service', 'stt'),
        _buildDivider(),
        _buildServerStatusRow('MinIO Storage', 'minio'),
        Container(height: 1, color: Colors.grey[900]),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Check all services status',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
              GestureDetector(
                onTap: _isCheckingStatus ? null : _checkAllServerStatus,
                child: Text(
                  _isCheckingStatus ? 'Checking...' : 'Check Now',
                  style: TextStyle(
                    color: _isCheckingStatus ? Colors.grey : neonGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServerStatusRow(String name, String key) {
    final status = _serverStatus[key] ?? 'unknown';
    Color statusColor;
    String statusText;

    switch (status) {
      case 'online':
        statusColor = neonGreen;
        statusText = 'ONLINE';
        break;
      case 'offline':
        statusColor = Colors.red;
        statusText = 'OFFLINE';
        break;
      case 'error':
        statusColor = Colors.orange;
        statusText = 'ERROR';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'UNKNOWN';
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        name,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceSettingsList() {
    return Column(
      children: [
        Container(height: 1, color: Colors.grey[900]),
        // Proponent
        _buildVoiceSettingTile(
          label: 'Proponent Voice',
          subtitle: 'Argues FOR the topic',
          color: neonPurple,
          voiceId: _proponentVoice,
          onChanged: _updateProponentVoice,
        ),
        _buildDivider(),
        // Opponent
        _buildVoiceSettingTile(
          label: 'Opponent Voice',
          subtitle: 'Argues AGAINST the topic',
          color: neonBlue,
          voiceId: _opponentVoice,
          onChanged: _updateOpponentVoice,
        ),
        Container(height: 1, color: Colors.grey[900]),

        const SizedBox(height: 24),
        _buildSectionHeader('PREFERENCES'),
        Container(height: 1, color: Colors.grey[900]),

        // Audio Cache
        SwitchListTile(
          activeColor: neonGreen,
          activeTrackColor: neonGreen.withAlpha(50),
          inactiveThumbColor: Colors.grey[400],
          inactiveTrackColor: Colors.grey[800],
          tileColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text(
            'Cache Audio',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          subtitle: Text(
            'Save voices to device ($_cacheSize)',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          value: _isAudioCacheEnabled,
          onChanged: _toggleAudioCache,
        ),

        if (_isAudioCacheEnabled && _cacheSize != '0 B')
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: _clearAudioCache,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: Colors.redAccent,
                  ),
                  label: const Text(
                    'Clear Cache',
                    style: TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),

        _buildDivider(),

        // Karaoke Toggle
        SwitchListTile(
          activeColor: neonGreen,
          activeTrackColor: neonGreen.withAlpha(50),
          inactiveThumbColor: Colors.grey[400],
          inactiveTrackColor: Colors.grey[800],
          tileColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text(
            'Karaoke Mode',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          subtitle: Text(
            'Highlight text as it is spoken',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          value: _isKaraokeEnabled,
          onChanged: _toggleKaraoke,
        ),
        Container(height: 1, color: Colors.grey[900]),

        if (_errorMessage != null || _availableVoices.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _errorMessage ?? 'Loading voices...',
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.grey[800]!,
            Colors.grey[800]!,
            Colors.transparent,
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
      ),
    );
  }

  Widget _buildVoiceSettingTile({
    required String label,
    required String subtitle,
    required Color color,
    required String voiceId,
    required Function(String?) onChanged,
  }) {
    final currentVoice = _availableVoices.firstWhere(
      (v) => v.id == voiceId,
      orElse: () => _availableVoices.isNotEmpty
          ? _availableVoices.first
          : const VoiceModel(
              id: '',
              name: 'Loading...',
              gender: '',
              accent: '',
              quality: '',
              description: '',
            ),
    );

    return InkWell(
      onTap: () {
        _showVoiceSelectionSheet(label, color, voiceId, onChanged);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: Colors.transparent),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.3), width: 1),
              ),
              child: Icon(Icons.record_voice_over, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        currentVoice.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          currentVoice.accent,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[700], size: 20),
          ],
        ),
      ),
    );
  }

  void _showVoiceSelectionSheet(
    String title,
    Color color,
    String currentVoiceId,
    Function(String?) onChanged,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent, // Transparent to show modal's rounded corners
      isScrollControlled: true,
      builder: (context) {
        return VoiceSelectionModal(
          voices: _availableVoices,
          selectedVoiceId: currentVoiceId,
          onVoiceSelected: (voice) {
            onChanged(voice.id);
          },
          // onPreviewVoice handled internally by modal now
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: neonGreen));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _loadSettings,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            _buildSectionHeader('SERVER STATUS'),
            _buildServerStatusList(),

            const SizedBox(height: 24),
            _buildSectionHeader('VOICE SETTINGS'),
            _buildVoiceSettingsList(),

            const SizedBox(height: 24),
            _buildSectionHeader('DEBATE ANALYSIS'),
            Container(height: 1, color: Colors.grey[900]),
            RadioListTile<String>(
              title: const Text(
                'AI Judge',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              subtitle: const Text(
                'Slower (5s), deeper analysis',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              value: 'AI',
              groupValue: _scoringMode,
              onChanged: (value) => _updateScoringMode(value),
              activeColor: neonGreen,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              tileColor: Colors.transparent,
            ),
            _buildDivider(),
            RadioListTile<String>(
              title: const Text(
                'Algorithmic Judge',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              subtitle: const Text(
                'Instant heuristic scoring',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              value: 'ALGO',
              groupValue: _scoringMode,
              onChanged: (value) => _updateScoringMode(value),
              activeColor: neonGreen,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              tileColor: Colors.transparent,
            ),
            Container(height: 1, color: Colors.grey[900]),

            const SizedBox(height: 24),
            _buildSectionHeader('ABOUT'),
            _buildListTile(
              icon: Icons.info_outline,
              title: 'How it Works',
              subtitle: 'Learn about the debate scoring and logic',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HowItWorksScreen(),
                  ),
                );
              },
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: _showPolicyPage,
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.code,
              title: 'Source Code',
              subtitle: 'View on GitHub',
              onTap: _openGitHub,
            ),

            const SizedBox(height: 48),
            Center(
              child: Text(
                'Version 1.0.0',
                style: TextStyle(color: Colors.grey[800], fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: neonGreen,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.transparent, // Make entire area tappable
        child: Row(
          children: [
            Icon(icon, color: neonGreen, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[700]),
          ],
        ),
      ),
    );
  }
}

// Full-page Policy Screen
class PolicyPage extends StatelessWidget {
  const PolicyPage({super.key});

  static const Color neonGreen = Color(0xFF00FF88);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Terms & Privacy',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: FutureBuilder<http.Response>(
        future: http.get(Uri.parse('${ApiConfig.baseUrl}/policy')),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: neonGreen),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load policy',
                style: TextStyle(color: Colors.red[400]),
              ),
            );
          }
          final data = jsonDecode(snapshot.data!.body);
          return Markdown(
            data: data['content'],
            padding: const EdgeInsets.all(16),
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
              h1: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              h2: const TextStyle(
                color: neonGreen,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              h3: const TextStyle(color: Colors.white, fontSize: 16),
              listBullet: const TextStyle(color: Colors.white70),
              strong: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              horizontalRuleDecoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[700]!)),
              ),
            ),
          );
        },
      ),
    );
  }
}
