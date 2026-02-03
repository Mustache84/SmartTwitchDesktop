import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/multi_stream_state.dart';
import '../services/twitch_api_service.dart';
import '../utils/hls_url_builder.dart';
import '../widgets/multi_stream_grid.dart';

/// Main screen for multi-stream viewing
class MultiStreamScreen extends ConsumerStatefulWidget {
  const MultiStreamScreen({super.key});

  @override
  ConsumerState<MultiStreamScreen> createState() => _MultiStreamScreenState();
}

class _MultiStreamScreenState extends ConsumerState<MultiStreamScreen> {
  final TextEditingController _channelController = TextEditingController();
  final TwitchApiService _apiService = TwitchApiService();
  bool _isAddingStream = false;
  String? _error;
  
  @override
  void dispose() {
    _channelController.dispose();
    super.dispose();
  }
  
  Future<void> _addStream() async {
    final channel = _channelController.text.trim();
    if (channel.isEmpty) return;
    
    final notifier = ref.read(multiStreamProvider.notifier);
    if (notifier.isFull) {
      setState(() => _error = 'All 4 slots are full');
      return;
    }
    
    setState(() {
      _isAddingStream = true;
      _error = null;
    });
    
    try {
      final token = await _apiService.getPlaybackToken(channel);
      final hlsUrl = HlsUrlBuilder.buildStreamUrl(
        channel: channel,
        token: token.token,
        signature: token.signature,
      );
      
      notifier.addStream(channel, hlsUrl);
      _channelController.clear();
      
    } on TwitchApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isAddingStream = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = ref.watch(multiStreamProvider);
    final activeCount = slots.where((s) => s.isActive).length;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Control bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[900],
            child: Row(
              children: [
                // Back button
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                
                const SizedBox(width: 16),
                
                // Title
                Text(
                  'Multi-Stream ($activeCount/4)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    const SizedBox(width: 24),
                    
                    // Add stream input
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _channelController,
                              enabled: !_isAddingStream,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Enter channel name...',
                                hintStyle: TextStyle(color: Colors.grey[500]),
                                filled: true,
                                fillColor: Colors.grey[800],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onSubmitted: (_) => _addStream(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isAddingStream ? null : _addStream,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                            ),
                            child: _isAddingStream
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Add Stream'),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Rotate button
                    IconButton(
                      icon: const Icon(Icons.rotate_right, color: Colors.white),
                      tooltip: 'Rotate positions (R)',
                      onPressed: activeCount >= 2
                          ? () => ref.read(multiStreamProvider.notifier).rotatePositions()
                          : null,
                    ),
                    
                    // Clear all button
                    IconButton(
                      icon: const Icon(Icons.clear_all, color: Colors.white),
                      tooltip: 'Clear all streams',
                      onPressed: activeCount > 0
                          ? () => ref.read(multiStreamProvider.notifier).clearAll()
                          : null,
                    ),
                  ],
                ),
              ),
              
              // Error message
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: Colors.red[900],
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: () => setState(() => _error = null),
                      ),
                    ],
                  ),
                ),
              
              // Stream grid
              const Expanded(
                child: MultiStreamGrid(),
              ),
              
              // Bottom bar with rotate button
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Colors.grey[850],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _KeyHint(label: 'Click stream', description: 'Switch audio'),
                    const SizedBox(width: 24),
                    TextButton.icon(
                      onPressed: activeCount >= 2
                          ? () => ref.read(multiStreamProvider.notifier).rotatePositions()
                          : null,
                      icon: const Icon(Icons.rotate_right, size: 18),
                      label: const Text('Rotate'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}

class _KeyHint extends StatelessWidget {
  final String label;
  final String description;
  
  const _KeyHint({required this.label, required this.description});
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[700],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          description,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
