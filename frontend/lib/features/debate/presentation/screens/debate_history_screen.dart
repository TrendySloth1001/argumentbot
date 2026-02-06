import 'package:flutter/material.dart';
import '../../data/models/debate.dart';
import '../../data/services/debate_service.dart';
import 'debate_screen.dart';
import 'package:intl/intl.dart';
import '../widgets/power_bar.dart';

class DebateHistoryScreen extends StatefulWidget {
  const DebateHistoryScreen({super.key});

  @override
  State<DebateHistoryScreen> createState() => _DebateHistoryScreenState();
}

class _DebateHistoryScreenState extends State<DebateHistoryScreen> {
  final _debateService = DebateService();
  late Future<List<Debate>> _debatesFuture;

  static const Color neonGreen = Color(0xFF00FF88);

  @override
  void initState() {
    super.initState();
    _debatesFuture = _debateService.getDebates();
  }

  void _refresh() {
    setState(() => _debatesFuture = _debateService.getDebates());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'All Debates',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<Debate>>(
        future: _debatesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: neonGreen,
                strokeWidth: 2,
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Colors.grey[600], size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load debates',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.grey[700],
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No debates yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final debates = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            color: neonGreen,
            child: ListView.separated(
              itemCount: debates.length,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              separatorBuilder: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _buildDivider(),
              ),
              itemBuilder: (context, index) => _buildDebateItem(debates[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDebateItem(Debate debate) {
    final dateStr = DateFormat('MMM d, y • h:mm a').format(
      DateTime.parse(
        debate.createdAt ?? DateTime.now().toIso8601String(),
      ).toLocal(),
    );
    final isFinished = debate.status == 'FINISHED';

    // Calculate scores
    double scoreA = 50, scoreB = 50;
    for (var turn in debate.turns) {
      if (turn.analysis != null) {
        final p = (turn.analysis!['persuasiveness'] ?? 50) as num;
        if (turn.speaker == 'MODEL_A') {
          scoreA += p.toDouble();
        } else {
          scoreB += p.toDouble();
        }
      }
    }

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
        color: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFinished ? Colors.grey[600] : neonGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    debate.topic,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[700], size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                dateStr,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: MiniPowerBar(scoreA: scoreA, scoreB: scoreB),
            ),
            if (debate.turns.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text(
                  '"${debate.turns.first.content.split('\n').first}"',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
