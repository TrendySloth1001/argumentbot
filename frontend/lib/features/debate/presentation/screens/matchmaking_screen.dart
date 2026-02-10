import 'package:flutter/material.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../features/auth/data/models/user_model.dart';
import '../../../../features/auth/data/services/auth_service.dart';
import 'debate_room_screen.dart'; // Will create next
import 'dart:async';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen>
    with SingleTickerProviderStateMixin {
  final SocketService _socketService = SocketService();
  final AuthService _authService = AuthService();

  bool _isSearching = false;
  String _statusText = "Ready to Debate?";
  Timer? _dotsTimer;
  Timer? _timeoutTimer;
  User? _user;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Store subscriptions for cleanup
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _socketService.connect();

    // Listen for match
    _subscriptions.add(
      _socketService.onMatchFound.listen((data) {
        if (!mounted) return;

        setState(() {
          _isSearching = false;
          _statusText = "Match Found!";
        });
        _pulseController.stop();

        // Navigate to Room
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DebateRoomScreen(
              debateId: data['debateId'],
              role: data['role'], // PRO or CON
              opponentName: data['opponent'],
              topic: data['topic'],
              currentUserId: _user!.id,
            ),
          ),
        );
      }),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadUser() async {
    final user = await _authService.checkAuth();
    setState(() => _user = user);
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _dotsTimer?.cancel();
    _timeoutTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    if (_user == null) return;

    setState(() {
      _isSearching = !_isSearching;
    });

    if (_isSearching) {
      _socketService.joinQueue(
        _user!.id,
        _user!.username, // Handle username
      );
      _startDotsAnimation();
      _startTimeoutTimer();
      _pulseController.repeat(reverse: true);
    } else {
      _socketService.leaveQueue();
      _dotsTimer?.cancel();
      _timeoutTimer?.cancel();
      _pulseController.stop();
      _pulseController.reset();
      setState(() => _statusText = "Ready to Debate?");
    }
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (!mounted || !_isSearching) return;
      _showTimeoutDialog();
    });
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          "Matchmaking Timeout",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "It's taking longer than expected to find an opponent. Do you want to keep searching?",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _toggleSearch(); // This will cancel the search
            },
            child: const Text("CANCEL", style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startTimeoutTimer(); // Restart the timeout timer
            },
            child: const Text(
              "KEEP SEARCHING",
              style: TextStyle(color: Color(0xFF448AFF)),
            ),
          ),
        ],
      ),
    );
  }

  void _startDotsAnimation() {
    int dots = 0;
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        dots = (dots + 1) % 4;
        _statusText = "Searching for opponent${'.' * dots}";
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Neon Green Theme
    final primaryColor = const Color(0xFF00FF88);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          "Multiplayer Arena",
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsating Circle
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isSearching
                      ? primaryColor.withOpacity(0.1)
                      : Colors.grey[900],
                  border: Border.all(
                    color: _isSearching ? primaryColor : Colors.grey[800]!,
                    width: 2,
                  ),
                  boxShadow: _isSearching
                      ? [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Icon(
                    Icons.flash_on, // Valid Icon
                    size: 80,
                    color: _isSearching ? primaryColor : Colors.grey[600],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 48),

            Text(
              _statusText,
              style: TextStyle(
                color: _isSearching ? primaryColor : Colors.grey[400],
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier',
              ),
            ),

            const SizedBox(height: 16),

            if (_isSearching)
              const Text(
                "Finding a worthy opponent...",
                style: TextStyle(color: Colors.grey),
              ),

            const SizedBox(height: 64),

            // Search Button
            GestureDetector(
              onTap: _toggleSearch,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: _isSearching
                      ? Colors.red.withOpacity(0.2)
                      : primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _isSearching ? Colors.red : primaryColor,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isSearching ? Colors.red : primaryColor)
                          .withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Text(
                  _isSearching ? "CANCEL SEARCH" : "FIND MATCH",
                  style: TextStyle(
                    color: _isSearching ? Colors.red : primaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
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
