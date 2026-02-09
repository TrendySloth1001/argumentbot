import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import '../config/api_config.dart';
import '../../features/auth/data/services/auth_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  IO.Socket? _debateSocket;
  IO.Socket? _matchmakingSocket;
  IO.Socket? _sttSocket;
  final AuthService _authService = AuthService();

  // Connection state tracking
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Streams
  final _matchFoundController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _queueStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _newTurnController = StreamController<Map<String, dynamic>>.broadcast();
  final _scoreUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _opponentTypingController = StreamController<String>.broadcast();
  final _sttResultController = StreamController<String>.broadcast();
  final _connectionStatusController = StreamController<String>.broadcast();

  Stream<Map<String, dynamic>> get onMatchFound => _matchFoundController.stream;
  Stream<Map<String, dynamic>> get onQueueStatus =>
      _queueStatusController.stream;
  Stream<Map<String, dynamic>> get onNewTurn => _newTurnController.stream;
  Stream<Map<String, dynamic>> get onScoreUpdate =>
      _scoreUpdateController.stream;
  Stream<String> get onOpponentTyping => _opponentTypingController.stream;
  Stream<String> get onSttResult => _sttResultController.stream;
  Stream<String> get onConnectionStatus => _connectionStatusController.stream;

  SocketService._internal();

  void init() {
    // Lazy init or manual init
  }

  Future<void> connect() async {
    if (_isConnected) {
      print('SocketService: Already connected, skipping...');
      return;
    }

    final token = await _authService.getToken();
    if (token == null) {
      print('SocketService: No token, cannot connect');
      return;
    }

    print('SocketService: Connecting to sockets...');

    // Matchmaking Socket - with reconnection
    _matchmakingSocket = IO.io(
      '${ApiConfig.baseUrl}/matchmaking',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    _matchmakingSocket!.onConnect((_) {
      print('SocketService: Connected to Matchmaking');
      _connectionStatusController.add('matchmaking_connected');
    });

    _matchmakingSocket!.onDisconnect((_) {
      print('SocketService: Matchmaking disconnected');
      _connectionStatusController.add('matchmaking_disconnected');
    });

    _matchmakingSocket!.onReconnect((_) {
      print('SocketService: Matchmaking reconnected');
      _connectionStatusController.add('matchmaking_reconnected');
    });

    _matchmakingSocket!.on('match_found', (data) {
      print('SocketService: Match found: $data');
      _matchFoundController.add(Map<String, dynamic>.from(data));
    });

    _matchmakingSocket!.on('queue_joined', (data) {
      _queueStatusController.add({'status': 'joined', ...data});
    });

    // Debate Socket - with reconnection
    _debateSocket = IO.io(
      '${ApiConfig.baseUrl}/debate',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    _debateSocket!.onConnect((_) {
      print('SocketService: Connected to Debate');
      _connectionStatusController.add('debate_connected');
    });

    _debateSocket!.onDisconnect((_) {
      print('SocketService: Debate disconnected');
      _connectionStatusController.add('debate_disconnected');
    });

    _debateSocket!.onReconnect((_) {
      print('SocketService: Debate reconnected');
      _connectionStatusController.add('debate_reconnected');
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

    // STT Socket - with reconnection
    _sttSocket = IO.io(
      '${ApiConfig.baseUrl}/stt',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    _sttSocket!.onConnect((_) {
      print('SocketService: Connected to STT');
      _connectionStatusController.add('stt_connected');
    });

    _sttSocket!.onDisconnect((_) {
      print('SocketService: STT disconnected');
      _connectionStatusController.add('stt_disconnected');
    });

    _sttSocket!.onReconnect((_) {
      print('SocketService: STT reconnected');
      _connectionStatusController.add('stt_reconnected');
    });

    _sttSocket!.on('transcription', (data) {
      print('SocketService: STT transcription received: $data');
      if (data is String) {
        _sttResultController.add(data);
      } else if (data is Map) {
        // Handle JSON object directly
        _sttResultController.add(data.toString());
      }
    });

    _sttSocket!.onConnectError((data) {
      print('SocketService: STT Connection Error: $data');
      _connectionStatusController.add('stt_error');
    });

    _isConnected = true;
    print('SocketService: All sockets initialized');
  }

  // Ensure connection before operations
  Future<void> ensureConnected() async {
    if (!_isConnected) {
      await connect();
    }
  }

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
      'speaker': speaker,
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

  // STT Methods
  void sendAudioChunk(List<int> data) {
    if (_sttSocket != null && _sttSocket!.connected) {
      _sttSocket!.emit('audio_chunk', data);
    } else {
      print('SocketService: STT socket not connected, cannot send audio');
    }
  }

  bool get isSttConnected => _sttSocket?.connected ?? false;

  void disconnect() {
    print('SocketService: Disconnecting all sockets...');
    _matchmakingSocket?.disconnect();
    _debateSocket?.disconnect();
    _sttSocket?.disconnect();
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _matchFoundController.close();
    _queueStatusController.close();
    _newTurnController.close();
    _scoreUpdateController.close();
    _opponentTypingController.close();
    _sttResultController.close();
    _connectionStatusController.close();
  }
}
