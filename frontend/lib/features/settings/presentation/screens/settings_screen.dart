import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/data/settings_manager.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _scoringMode = 'AI';
  bool _isLoading = true;
  bool _policyAccepted = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final mode = await SettingsManager.getScoringMode();
    setState(() {
      _scoringMode = mode;
      _isLoading = false;
    });
  }

  Future<void> _updateScoringMode(String? newMode) async {
    if (newMode == null) return;
    await SettingsManager.setScoringMode(newMode);
    setState(() {
      _scoringMode = newMode;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('Debate Analysis'),
                _buildRadioOption(
                  title: 'AI Judge',
                  subtitle:
                      'Slower (5s), but deeper analysis and better insights.',
                  value: 'AI',
                  groupValue: _scoringMode,
                  onChanged: _updateScoringMode,
                ),
                _buildRadioOption(
                  title: 'Algorithmic Judge',
                  subtitle: 'Instant results using heuristic scoring.',
                  value: 'ALGO',
                  groupValue: _scoringMode,
                  onChanged: _updateScoringMode,
                ),

                const SizedBox(height: 24),
                _buildSectionHeader('Legal'),
                _buildListTile(
                  icon: Icons.description_outlined,
                  title: 'Terms & Privacy Policy',
                  subtitle: _policyAccepted ? 'Accepted' : 'Not accepted',
                  onTap: _showPolicyPage,
                ),

                const SizedBox(height: 24),
                _buildSectionHeader('Open Source'),
                _buildGitHubCard(),
              ],
            ),
    );
  }

  Widget _buildGitHubCard() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.code, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TrendySloth1001/argumentbot',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              "So you've been using this app for free, huh?\n\n"
              "Look, I'm not saying you OWE me anything... but if you're a dev "
              "and you haven't starred the repo yet, that's kinda sus.\n\n"
              "Just saying... the star button doesn't bite. Fork it if you're brave enough. "
              "Or don't. See if I care.",
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
                child: ElevatedButton.icon(
                  onPressed: _openGitHub,
                  icon: const Icon(Icons.star_border, size: 18),
                  label: const Text('Star It'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E2DE2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openGitHub,
                  icon: const Icon(Icons.fork_right, size: 18),
                  label: const Text('Fork It'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[500],
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
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _buildRadioOption({
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: isSelected ? Border.all(color: const Color(0xFF8E2DE2)) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        activeColor: const Color(0xFF8E2DE2),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
      ),
    );
  }
}

// Full-page Policy Screen
class PolicyPage extends StatelessWidget {
  const PolicyPage({super.key});

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
      ),
      body: FutureBuilder<http.Response>(
        future: http.get(Uri.parse('${ApiConfig.baseUrl}/policy')),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
                color: Colors.blueAccent,
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
