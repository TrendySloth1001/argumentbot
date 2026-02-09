class Debate {
  final String id;
  final String topic;
  final String status;
  final String? createdAt;
  final String mode;
  final String userRole;
  final String difficulty;
  final String? winner;
  final List<DebateTurn> turns;

  Debate({
    required this.id,
    required this.topic,
    required this.status,
    required this.turns,
    this.createdAt,
    this.mode = 'AI_VS_AI',
    this.userRole = 'SPECTATOR',
    this.difficulty = 'INTERMEDIATE',
    this.winner,
  });

  factory Debate.fromJson(Map<String, dynamic> json) {
    return Debate(
      id: json['id'],
      topic: json['topic'],
      status: json['status'],
      createdAt: json['createdAt'],
      mode: json['mode'] ?? 'AI_VS_AI',
      userRole: json['userRole'] ?? 'SPECTATOR',
      difficulty: json['difficulty'] ?? 'INTERMEDIATE',
      winner: json['winner'],
      turns:
          (json['turns'] as List<dynamic>?)
              ?.map((e) => DebateTurn.fromJson(e))
              .toList() ??
          [],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic': topic,
      'status': status,
      'createdAt': createdAt,
      'mode': mode,
      'userRole': userRole,
      'turns': turns.map((t) => t.toJson()).toList(),
    };
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'speaker': speaker,
      'content': content,
      'analysis': analysis,
      'modelName': modelName,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
