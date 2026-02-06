class Debate {
  final String id;
  final String topic;
  final String status;
  final String? createdAt;
  final List<DebateTurn> turns;

  Debate({
    required this.id,
    required this.topic,
    required this.status,
    required this.turns,
    this.createdAt,
  });

  factory Debate.fromJson(Map<String, dynamic> json) {
    return Debate(
      id: json['id'],
      topic: json['topic'],
      status: json['status'],
      createdAt: json['createdAt'],
      turns:
          (json['turns'] as List<dynamic>?)
              ?.map((e) => DebateTurn.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class DebateTurn {
  final String id;
  final String speaker;
  final String content;
  final Map<String, dynamic>? analysis;
  final String? modelName;
  final DateTime timestamp;

  DebateTurn({
    required this.id,
    required this.speaker,
    required this.content,
    required this.timestamp,
    this.analysis,
    this.modelName = 'llama3.2',
  });

  factory DebateTurn.fromJson(Map<String, dynamic> json) {
    return DebateTurn(
      id: json['id'],
      speaker: json['speaker'],
      content: json['content'],
      analysis: json['analysis'] != null
          ? json['analysis'] as Map<String, dynamic>
          : null,
      modelName: json['modelName'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
