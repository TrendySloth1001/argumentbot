import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/data/voice_settings.dart';
import '../../../../core/services/tts_service.dart';
import 'voice_card.dart';

class VoiceSelectionModal extends StatefulWidget {
  final List<VoiceModel> voices;
  final String selectedVoiceId;
  final Function(VoiceModel) onVoiceSelected;

  const VoiceSelectionModal({
    super.key,
    required this.voices,
    required this.selectedVoiceId,
    required this.onVoiceSelected,
  });

  @override
  State<VoiceSelectionModal> createState() => _VoiceSelectionModalState();
}

class _VoiceSelectionModalState extends State<VoiceSelectionModal> {
  String _searchQuery = '';
  String _selectedEngine = 'All'; // All, Coqui, Piper
  String _selectedGender = 'All'; // All, Male, Female
  String? _playingVoiceId; // ID of voice currently playing preview

  final AudioPlayer _audioPlayer = AudioPlayer();
  final TtsService _ttsService = TtsService();

  @override
  void initState() {
    super.initState();
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        if (state.processingState == ProcessingState.completed) {
          setState(() {
            _playingVoiceId = null;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPreview(VoiceModel voice) async {
    // If clicking the same voice that is playing, stop it
    if (_playingVoiceId == voice.id) {
      await _audioPlayer.stop();
      setState(() => _playingVoiceId = null);
      return;
    }

    setState(() {
      _playingVoiceId = voice.id; // Optimistic UI update
    });

    try {
      await _audioPlayer.stop(); // Stop previous

      final text = "This is a preview of the ${voice.name} voice.";
      final url = _ttsService.getStreamUrl(text, voice: voice.id);

      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
    } catch (e) {
      print("Preview error: $e");
      if (mounted) {
        setState(() => _playingVoiceId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play preview'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        // No loading state needed for now
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Filter voices
    final filteredVoices = widget.voices.where((voice) {
      final matchesSearch =
          voice.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          voice.accent.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesEngine =
          _selectedEngine == 'All' ||
          (_selectedEngine == 'Coqui' && voice.engine == 'coqui') ||
          (_selectedEngine == 'Piper' && voice.engine == 'piper');

      final matchesGender =
          _selectedGender == 'All' ||
          voice.gender.toLowerCase() == _selectedGender.toLowerCase();

      return matchesSearch && matchesEngine && matchesGender;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF141414), // Dark background
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Voice',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search voices...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Filters (Tabs)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildFilterChip(
                  'All',
                  _selectedEngine == 'All',
                  () => setState(() => _selectedEngine = 'All'),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Pro (Coqui)',
                  _selectedEngine == 'Coqui',
                  () => setState(() => _selectedEngine = 'Coqui'),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Fast (Piper)',
                  _selectedEngine == 'Piper',
                  () => setState(() => _selectedEngine = 'Piper'),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.grey[800],
                ), // Divider
                const SizedBox(width: 16),
                _buildFilterChip('Male', _selectedGender == 'Male', () {
                  setState(
                    () => _selectedGender = _selectedGender == 'Male'
                        ? 'All'
                        : 'Male',
                  );
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Female', _selectedGender == 'Female', () {
                  setState(
                    () => _selectedGender = _selectedGender == 'Female'
                        ? 'All'
                        : 'Female',
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: filteredVoices.length,
              itemBuilder: (context, index) {
                final voice = filteredVoices[index];
                final isSelected = voice.id == widget.selectedVoiceId;
                final isPlaying = _playingVoiceId == voice.id;

                return VoiceCard(
                  voice: voice,
                  isSelected: isSelected,
                  isPlaying: isPlaying,
                  onTap: () {
                    widget.onVoiceSelected(voice);
                    Navigator.pop(context);
                  },
                  onPreview: () => _playPreview(voice),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.white : Colors.white10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.grey[400],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
