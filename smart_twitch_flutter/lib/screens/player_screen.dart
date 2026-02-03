import 'package:flutter/material.dart';
import '../services/twitch_api_service.dart';
import '../utils/hls_url_builder.dart';
import '../widgets/video_widget.dart';

class PlayerScreen extends StatefulWidget {
  final String channelLogin;
  
  const PlayerScreen({super.key, required this.channelLogin});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final TwitchApiService _apiService = TwitchApiService();
  String? _hlsUrl;
  String? _error;
  bool _loading = true;
  
  @override
  void initState() {
    super.initState();
    _loadStream();
  }
  
  Future<void> _loadStream() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final token = await _apiService.getPlaybackToken(widget.channelLogin);
      
      final hlsUrl = HlsUrlBuilder.buildStreamUrl(
        channel: widget.channelLogin,
        token: token.token,
        signature: token.signature,
      );
      
      setState(() {
        _hlsUrl = hlsUrl;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Text('Watching: ${widget.channelLogin}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStream,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.purple),
            SizedBox(height: 16),
            Text('Loading stream...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStream,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (_hlsUrl != null) {
      return Center(
        child: TwitchVideoWidget(hlsUrl: _hlsUrl!),
      );
    }
    
    return const Center(
      child: Text('No stream available', style: TextStyle(color: Colors.white)),
    );
  }
}
