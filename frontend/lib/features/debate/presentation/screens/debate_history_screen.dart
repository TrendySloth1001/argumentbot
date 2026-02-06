import 'package:flutter/material.dart';
import '../../data/models/debate.dart';
import '../../data/services/debate_service.dart';
import 'debate_screen.dart';
import 'package:intl/intl.dart';

class DebateHistoryScreen extends StatefulWidget {
  const DebateHistoryScreen({super.key});

  @override
  State<DebateHistoryScreen> createState() => _DebateHistoryScreenState();
}

class _DebateHistoryScreenState extends State<DebateHistoryScreen> {
  final _debateService = DebateService();
  late Future<List<Debate>> _debatesFuture;

  @override
  void initState() {
    super.initState();
    _debatesFuture = _debateService.getDebates();
  }

  void _refresh() {
    setState(() {
      _debatesFuture = _debateService.getDebates();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Debate History',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Debate>>(
        future: _debatesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No debates found',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          final debates = snapshot.data!;
          return ListView.builder(
            itemCount: debates.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final debate = debates[index];
              return _buildDebateCard(debate);
            },
          );
        },
      ),
    );
  }

  Widget _buildDebateCard(Debate debate) {
    final dateStr = DateFormat('MMM d, y, h:mm a').format(
      DateTime.parse(
        debate.createdAt ?? DateTime.now().toIso8601String(),
      ).toLocal(),
    );
    final isFinished = debate.status == 'FINISHED';

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DebateScreen(debateId: debate.id),
          ),
        );
        _refresh();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    debate.topic,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isFinished
                        ? Colors.green.withOpacity(0.2)
                        : Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isFinished ? 'FINISHED' : 'ACTIVE',
                    style: TextStyle(
                      color: isFinished
                          ? Colors.greenAccent
                          : Colors.blueAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              dateStr,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            if (debate.turns.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Last turn: "${debate.turns.first.content.split('\n').first}..."',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
