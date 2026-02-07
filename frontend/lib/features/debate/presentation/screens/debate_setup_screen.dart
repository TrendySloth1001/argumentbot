import 'package:flutter/material.dart';
import '../../data/services/debate_service.dart';
import 'debate_screen.dart';

class DebateSetupScreen extends StatefulWidget {
  final String? initialTopic;

  const DebateSetupScreen({super.key, this.initialTopic});

  @override
  State<DebateSetupScreen> createState() => _DebateSetupScreenState();
}

class _DebateSetupScreenState extends State<DebateSetupScreen> {
  late TextEditingController _topicController;
  final _debateService = DebateService();
  bool _isLoading = false;
  String _selectedMode = 'AI_VS_AI';
  String _selectedRole = 'SPECTATOR';

  static const Color neonGreen = Color(0xFF00FF88);

  final List<String> _suggestedTopics = [
    'Is AI dangerous?',
    'Universal Basic Income',
    'Remote work vs Office',
    'Space exploration cost',
    'Veganism is the future',
  ];

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(text: widget.initialTopic);
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  void _startDebate() async {
    if (_topicController.text.isEmpty) return;
    _performStart(_topicController.text);
  }

  void _performStart(String topic) async {
    setState(() => _isLoading = true);

    try {
      final role = _selectedMode == 'AI_VS_AI' ? 'SPECTATOR' : _selectedRole;

      final debate = await _debateService.startDebate(
        topic,
        mode: _selectedMode,
        userRole: role,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DebateScreen(debateId: debate.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Title
                      const Text(
                        'New',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const Text(
                        'Debate',
                        style: TextStyle(
                          color: neonGreen,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),
                      Text(
                        'Pick a topic and let AI minds clash',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),

                      const SizedBox(height: 24),

                      // Input field
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[800]!),
                        ),
                        child: TextField(
                          controller: _topicController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter a topic...',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            border: InputBorder.none,
                            suffixIcon: IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Colors.grey[600],
                                size: 18,
                              ),
                              onPressed: _topicController.clear,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Mode Selection
                      Row(
                        children: [
                          Expanded(
                            child: _buildModeButton(
                              'Spectate',
                              Icons.visibility,
                              'AI_VS_AI',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModeButton(
                              'Battle',
                              Icons.sports_mma,
                              'USER_VS_AI',
                            ),
                          ),
                        ],
                      ),

                      if (_selectedMode == 'USER_VS_AI') ...[
                        const SizedBox(height: 24),
                        const Text(
                          'CHOOSE YOUR SIDE',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildRoleButton('Pro', 'PRO')),
                            const SizedBox(width: 12),
                            Expanded(child: _buildRoleButton('Con', 'CON')),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Suggestions
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SUGGESTIONS',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _suggestedTopics.map((topic) {
                              return GestureDetector(
                                onTap: () => _topicController.text = topic,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[900],
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.grey[800]!,
                                    ),
                                  ),
                                  child: Text(
                                    topic,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24), // Bottom padding for scroll
                    ],
                  ),
                ),
              ),
            ),

            // Start button - pinned
            Padding(
              padding: const EdgeInsets.all(24),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: neonGreen),
                    )
                  : GestureDetector(
                      onTap: _startDebate,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: neonGreen,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: neonGreen.withAlpha(77),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bolt, color: Colors.black, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Start Debate',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, IconData icon, String value) {
    final isSelected = _selectedMode == value;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedMode = value;
        // Reset role if switching to AI_VS_AI
        if (value == 'AI_VS_AI') {
          _selectedRole = 'SPECTATOR';
        } else if (_selectedRole == 'SPECTATOR') {
          _selectedRole = 'PRO';
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? neonGreen.withOpacity(0.2) : Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? neonGreen : Colors.grey[800]!),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? neonGreen : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleButton(String label, String value) {
    final isSelected = _selectedRole == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? neonGreen.withOpacity(0.2) : Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? neonGreen : Colors.grey[800]!),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
