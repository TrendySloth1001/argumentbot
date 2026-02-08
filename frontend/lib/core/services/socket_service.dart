import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import '../config/api_config.dart';
import '../../features/auth/data/services/auth_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  IO.Socket? _debateSocket;
  IO.Socket? _matchmakingSocket;
  final AuthService _authService = AuthService();

  // Streams
  final _matchFoundController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _queueStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _newTurnController = StreamController<Map<String, dynamic>>.broadcast();
  final _scoreUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _opponentTypingController = StreamController<String>.broadcast();

  Stream<Map<String, dynamic>> get onMatchFound => _matchFoundController.stream;
  Stream<Map<String, dynamic>> get onQueueStatus =>
      _queueStatusController.stream;
  Stream<Map<String, dynamic>> get onNewTurn => _newTurnController.stream;
  Stream<Map<String, dynamic>> get onScoreUpdate =>
      _scoreUpdateController.stream;
  Stream<String> get onOpponentTyping => _opponentTypingController.stream;

  SocketService._internal();

  void init() {
    // Lazy init or manual init
  }

  IO.Socket? _sttSocket;
  final _sttResultController = StreamController<String>.broadcast();
  Stream<String> get onSttResult => _sttResultController.stream;

  void connect() async {
    final token = await _authService.getToken();
    if (token == null) return;

    // Matchmaking Socket
    _matchmakingSocket = IO.io(
      '${ApiConfig.baseUrl}/matchmaking',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .setExtraHeaders({
            'Authorization': 'Bearer $token',
          }) // If we add auth guard
          .build(),
    );

    _matchmakingSocket!.onConnect((_) {
      print('Connected to Matchmaking Namespace');
    });

    _matchmakingSocket!.on('match_found', (data) {
      print('Match found: $data');
      _matchFoundController.add(Map<String, dynamic>.from(data));
    });

    _matchmakingSocket!.on('queue_joined', (data) {
      _queueStatusController.add({'status': 'joined', ...data});
    });

    // Debate Socket
    _debateSocket = IO.io(
      '${ApiConfig.baseUrl}/debate',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    _debateSocket!.onConnect((_) {
      print('Connected to Debate Namespace');
    });

    _debateSocket!.on('new_turn', (data) {
      _newTurnController.add(Map<String, dynamic>.from(data));
    });

    _debateSocket!.on('score_update', (data) {
      _scoreUpdateController.add(Map<String, dynamic>.from(data));
    });

    _debateSocket!.on('opponent_typing', (data) {
      _opponentTypingController.add('typing');
    });

    _debateSocket!.on('opponent_stopped_typing', (data) {
      _opponentTypingController.add('stopped');
    });

    // STT Socket
    _sttSocket = IO.io(
      '${ApiConfig.baseUrl}/stt',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    _sttSocket!.onConnect((_) {
      print('Connected to STT Namespace');
    });

    _sttSocket!.on('transcription', (data) {
      // print('STT Transcription: $data');
      if (data is String) {
        _sttResultController.add(data);
      }
    });

    _sttSocket!.onConnectError((data) => print('STT Connection Error: $data'));
  }

  // ... (existing methods)

  // Matchmaking Methods
  void joinQueue(String userId, String username) {
    _matchmakingSocket?.emit('join_queue', {
      'userId': userId,
      'username': username,
    });
  }

  void leaveQueue() {
    _matchmakingSocket?.emit('leave_queue');
  }

  // Debate Methods
  void joinDebateRoom(String debateId, String userId) {
    _debateSocket?.emit('join_room', {'debateId': debateId, 'userId': userId});
  }

  void leaveDebateRoom(String debateId) {
    _debateSocket?.emit('leave_room', {'debateId': debateId});
  }

  void submitTurn(
    String debateId,
    String userId,
    String content,
    String speaker,
  ) {
    _debateSocket?.emit('submit_turn', {
      'debateId': debateId,
      'userId': userId,
      'content': content,
      'speaker': speaker, // 'MODEL_A' (Pro/User1) or 'MODEL_B' (Con/User2)
    });
  }

  void sendTyping(String debateId, String userId, bool isTyping) {
    if (isTyping) {
      _debateSocket?.emit('typing_started', {
        'debateId': debateId,
        'userId': userId,
      });
    } else {
      _debateSocket?.emit('typing_stopped', {
        'debateId': debateId,
        'userId': userId,
      });
    }
  }

  void sendAudioChunk(List<int> data) {
    if (_sttSocket != null && _sttSocket!.connected) {
      _sttSocket!.emit('audio_chunk', data);
    }
  }

  void disconnect() {
    _matchmakingSocket?.disconnect();
    _debateSocket?.disconnect();
    _sttSocket?.disconnect();
  }
}
