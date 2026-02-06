import 'package:flutter/material.dart';
import '../../data/services/debate_service.dart';
import 'debate_screen.dart';

class DebateSetupScreen extends StatefulWidget {
  const DebateSetupScreen({super.key});

  @override
  State<DebateSetupScreen> createState() => _DebateSetupScreenState();
}

class _DebateSetupScreenState extends State<DebateSetupScreen> {
  final _topicController = TextEditingController();
  final _debateService = DebateService();
  bool _isLoading = false;

  static const Color neonGreen = Color(0xFF00FF88);

  final List<String> _suggestedTopics = [
    'Is AI dangerous?',
    'Universal Basic Income',
    'Remote work vs Office',
    'Space exploration cost',
    'Veganism is the future',
  ];

  void _startDebate() async {
    if (_topicController.text.isEmpty) return;
    _performStart(_topicController.text);
  }

  void _performStart(String topic) async {
    setState(() => _isLoading = true);

    try {
      final debate = await _debateService.startDebate(topic);
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
                  style: const TextStyle(color: Colors.white, fontSize: 15),
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

              const SizedBox(height: 20),

              // Suggestions - takes remaining space
              Expanded(
                child: Column(
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
                              border: Border.all(color: Colors.grey[800]!),
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
              ),

              // Start button - always at bottom
              _isLoading
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
            ],
          ),
        ),
      ),
    );
  }
}
