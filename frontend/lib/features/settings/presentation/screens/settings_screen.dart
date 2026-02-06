import 'package:flutter/material.dart';
import '../../../../core/data/settings_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _scoringMode = 'AI';
  bool _isLoading = true;

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
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 20),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
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
