import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/data/settings_manager.dart';
import '../../../../core/data/voice_settings.dart';
import '../../../../core/services/tts_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/config/api_config.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'how_it_works_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _scoringMode = 'AI';
  bool _isLoading = true;

  // Server status states
  Map<String, String> _serverStatus = {
    'backend': 'unknown',
    'tts': 'unknown',
    'minio': 'unknown',
  };
  bool _isCheckingStatus = false;

  // Voice settings state
  final TtsService _ttsService = TtsService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<VoiceModel> _availableVoices = [];
  String _proponentVoice = 'en_US-amy-medium';
  String _opponentVoice = 'en_US-ryan-high';
  String? _previewingVoice;
  String? _errorMessage;

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
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final mode = await SettingsManager.getScoringMode();
    final proVoice = await VoiceSettings.getProponentVoice();
    final oppVoice = await VoiceSettings.getOpponentVoice();
    setState(() {
      _scoringMode = mode;
      _proponentVoice = proVoice;
      _opponentVoice = oppVoice;
      _isLoading = false;
    });
  }

  Future<void> _loadVoices() async {
    try {
      setState(() => _errorMessage = null);
      final voicesData = await _ttsService.getVoices();
      setState(() {
        _availableVoices = voicesData
            .map((v) => VoiceModel.fromJson(v))
            .toList();
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _previewVoice(String voiceId) async {
    if (_previewingVoice == voiceId) {
      await _audioPlayer.stop();
      setState(() => _previewingVoice = null);
      return;
    }

    setState(() => _previewingVoice = voiceId);

    try {
      final Uint8List audioBytes = await _ttsService.synthesize(
        "Hello! This is a preview of my voice. How do I sound?",
        voice: voiceId,
      );

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/preview_$voiceId.wav');
      await tempFile.writeAsBytes(audioBytes);

      await _audioPlayer.setFilePath(tempFile.path);

      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) setState(() => _previewingVoice = null);
          tempFile.delete().catchError((_) => tempFile);
        }
      });

      await _audioPlayer.play();
    } catch (e) {
      setState(() => _previewingVoice = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Preview failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  Widget _buildServerStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dns, color: neonGreen, size: 22),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Server Status',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Check all service health',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _isCheckingStatus ? null : _checkAllServerStatus,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _isCheckingStatus ? Colors.grey[700] : neonGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isCheckingStatus
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Check',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildServerStatusRow('Backend API', 'backend', Icons.api),
          const SizedBox(height: 8),
          _buildServerStatusRow('TTS Service', 'tts', Icons.record_voice_over),
          const SizedBox(height: 8),
          _buildServerStatusRow('MinIO Storage', 'minio', Icons.storage),
        ],
      ),
    );
  }

  Widget _buildServerStatusRow(String name, String key, IconData icon) {
    final status = _serverStatus[key] ?? 'unknown';
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'online':
        statusColor = neonGreen;
        statusIcon = Icons.check_circle;
        break;
      case 'offline':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'error':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400], size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          Icon(statusIcon, color: statusColor, size: 18),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.record_voice_over, color: neonGreen, size: 22),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TTS Voices',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Different voices for each debater',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Refresh button
              GestureDetector(
                onTap: _loadVoices,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.refresh, size: 16, color: Colors.grey[400]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Voice count indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: neonGreen.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: neonGreen.withAlpha(50)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 14, color: neonGreen),
                const SizedBox(width: 6),
                Text(
                  '${_availableVoices.length} voices available',
                  style: TextStyle(
                    color: neonGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Proponent Voice Section
          _buildVoiceSelectorExpanded(
            label: 'PROPONENT VOICE',
            subtitle: 'Argues FOR the topic',
            color: neonPurple,
            selectedVoice: _proponentVoice,
            onChanged: _updateProponentVoice,
          ),
          const SizedBox(height: 16),

          // Opponent Voice Section
          _buildVoiceSelectorExpanded(
            label: 'OPPONENT VOICE',
            subtitle: 'Argues AGAINST the topic',
            color: neonBlue,
            selectedVoice: _opponentVoice,
            onChanged: _updateOpponentVoice,
          ),

          const SizedBox(height: 16),

          // Storage info footer
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.save, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Preferences saved locally on device',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          if (_errorMessage != null || _availableVoices.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage != null
                            ? 'Error: ${_errorMessage!.replaceAll("Exception:", "").trim()}'
                            : 'Loading voices...',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVoiceSelectorExpanded({
    required String label,
    required String subtitle,
    required Color color,
    required String selectedVoice,
    required Function(String?) onChanged,
  }) {
    // Find current voice details
    final currentVoice = _availableVoices.firstWhere(
      (v) => v.id == selectedVoice,
      orElse: () => _availableVoices.isNotEmpty
          ? _availableVoices.first
          : VoiceModel(
              id: '',
              name: 'Loading...',
              gender: '',
              accent: '',
              quality: '',
              description: '',
            ),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Preview button
              GestureDetector(
                onTap: () => _previewVoice(currentVoice.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _previewingVoice == currentVoice.id
                        ? neonGreen.withAlpha(30)
                        : Colors.grey[800],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _previewingVoice == currentVoice.id
                          ? neonGreen
                          : Colors.grey[700]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_previewingVoice == currentVoice.id)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: neonGreen,
                          ),
                        )
                      else
                        Icon(
                          Icons.play_arrow,
                          size: 14,
                          color: Colors.grey[400],
                        ),
                      const SizedBox(width: 4),
                      Text(
                        'Preview',
                        style: TextStyle(
                          color: _previewingVoice == currentVoice.id
                              ? neonGreen
                              : Colors.grey[400],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Voice dropdown with full details
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _availableVoices.any((v) => v.id == selectedVoice)
                  ? selectedVoice
                  : (_availableVoices.isNotEmpty
                        ? _availableVoices.first.id
                        : null),
              isExpanded: true,
              dropdownColor: Colors.grey[850],
              underline: const SizedBox(),
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[400]),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: _availableVoices.map((voice) {
                return DropdownMenuItem<String>(
                  value: voice.id,
                  child: Row(
                    children: [
                      // Gender icon
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: voice.gender == 'female'
                              ? Colors.pinkAccent.withAlpha(30)
                              : Colors.lightBlueAccent.withAlpha(30),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          voice.gender == 'female' ? Icons.female : Icons.male,
                          size: 14,
                          color: voice.gender == 'female'
                              ? Colors.pinkAccent
                              : Colors.lightBlueAccent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Name and accent
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              voice.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              voice.accent,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Quality badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getQualityColor(voice.quality).withAlpha(30),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          voice.quality.toUpperCase(),
                          style: TextStyle(
                            color: _getQualityColor(voice.quality),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),

          // Current voice description
          if (currentVoice.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              currentVoice.description,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getQualityColor(String quality) {
    switch (quality.toLowerCase()) {
      case 'high':
        return neonGreen;
      case 'medium':
        return Colors.amber;
      case 'low':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: neonGreen))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildDivider(),
                    const SizedBox(height: 24),

                    // Server Status
                    _buildSectionTitle('System'),
                    const SizedBox(height: 12),
                    _buildServerStatusCard(),

                    const SizedBox(height: 24),
                    _buildDivider(),
                    const SizedBox(height: 24),

                    // Voice Settings
                    _buildSectionTitle('Voice Settings'),
                    const SizedBox(height: 12),
                    _buildVoiceSettingsCard(),

                    const SizedBox(height: 24),
                    _buildDivider(),
                    const SizedBox(height: 24),

                    // Debate Analysis
                    _buildSectionTitle('Debate Analysis'),
                    const SizedBox(height: 12),
                    _buildRadioOption(
                      title: 'AI Judge',
                      subtitle: 'Slower (5s), deeper analysis',
                      value: 'AI',
                    ),
                    _buildRadioOption(
                      title: 'Algorithmic Judge',
                      subtitle: 'Instant heuristic scoring',
                      value: 'ALGO',
                    ),

                    const SizedBox(height: 24),
                    _buildDivider(),
                    const SizedBox(height: 24),

                    // About
                    _buildSectionTitle('About'),
                    const SizedBox(height: 12),
                    _buildListTile(
                      icon: Icons.science_outlined,
                      title: 'How It Works',
                      subtitle: 'RAG, scoring, math formulas',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HowItWorksScreen(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    _buildDivider(),
                    const SizedBox(height: 24),

                    // Legal
                    _buildSectionTitle('Legal'),
                    const SizedBox(height: 12),
                    _buildListTile(
                      icon: Icons.description_outlined,
                      title: 'Terms & Privacy Policy',
                      subtitle: 'Accepted',
                      onTap: _showPolicyPage,
                    ),

                    const SizedBox(height: 24),
                    _buildDivider(),
                    const SizedBox(height: 24),

                    // Open Source
                    _buildSectionTitle('Open Source'),
                    const SizedBox(height: 12),
                    _buildGitHubCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: Colors.grey[500],
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildRadioOption({
    required String title,
    required String subtitle,
    required String value,
  }) {
    final isSelected = value == _scoringMode;
    return GestureDetector(
      onTap: () => _updateScoringMode(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: neonGreen) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? neonGreen : Colors.grey[600]!,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: neonGreen,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: neonGreen, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white)),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildGitHubCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: neonGreen.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.code, color: neonGreen, size: 22),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TrendySloth1001/argumentbot',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'AI Debate Simulator',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              "So you've been using this app for free, huh?\n\n"
              "Look, I'm not saying you OWE me anything... but if you're a dev "
              "and you haven't starred the repo yet, that's kinda sus.\n\n"
              "Just saying... the star button doesn't bite. Fork it if you're brave enough.",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _openGitHub,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: neonGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star_border, color: Colors.black, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Star It',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _openGitHub,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.fork_right,
                          color: Colors.grey[400],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Fork It',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
