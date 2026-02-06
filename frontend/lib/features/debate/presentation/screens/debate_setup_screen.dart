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

  final List<String> _suggestedTopics = [
    'Is AI dangerous?',
    'Universal Basic Income',
    'Remote work vs Office',
    'Space exploration cost',
    'Vegan diet benefits',
  ];

  void _startDebate() async {
    if (_topicController.text.isEmpty) return;
    _performStart(_topicController.text);
  }

  void _performStart(String topic) async {
    setState(() {
      _isLoading = true;
    });

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
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('New Debate', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a Topic,',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
            const Text(
              'Ignite the Argument.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 32,
                fontWeight: FontWeight.w300,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _topicController,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Enter a controversial topic...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: _topicController.clear,
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Suggestions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _suggestedTopics.map((topic) {
                return ActionChip(
                  label: Text(topic),
                  labelStyle: const TextStyle(color: Colors.white),
                  backgroundColor: Colors.grey[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.grey[800]!),
                  ),
                  onPressed: () {
                    _topicController.text = topic;
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 50),
            Center(
              child: _isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF8E2DE2),
                      ),
                    )
                  : GestureDetector(
                      onTap: _startDebate,
                      child: Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4A00E0).withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Start Debate',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
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
