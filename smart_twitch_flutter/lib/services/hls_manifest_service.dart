import 'package:dio/dio.dart';
import 'settings_service.dart';

/// Service for parsing HLS manifests to extract available quality options.
/// 
/// Twitch provides a master playlist with multiple quality variants.
/// This service fetches and parses that playlist to get:
/// - Available resolutions (1080p60, 720p60, etc.)
/// - Bandwidth for each quality
/// - Codec information
class HlsManifestService {
  final Dio _dio;

  HlsManifestService({Dio? dio}) : _dio = dio ?? Dio();

  /// Fetch and parse quality options from an HLS master playlist URL
  Future<List<QualityOption>> getQualityOptions(String masterPlaylistUrl) async {
    try {
      final response = await _dio.get<String>(
        masterPlaylistUrl,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.data == null) {
        print('[HlsManifestService] Empty response from manifest');
        return _defaultQualities();
      }

      return _parseManifest(response.data!);
    } catch (e) {
      print('[HlsManifestService] Error fetching manifest: $e');
      return _defaultQualities();
    }
  }

  /// Parse HLS master playlist content
  List<QualityOption> _parseManifest(String content) {
    final lines = content.split('\n');
    final qualities = <QualityOption>[];
    
    // Always add Auto as first option
    qualities.add(const QualityOption(
      id: 'auto',
      label: 'Auto',
    ));

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      // Look for #EXT-X-STREAM-INF lines
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        final attributes = _parseAttributes(line.substring('#EXT-X-STREAM-INF:'.length));
        
        // Get the stream URL (next line)
        String? streamUrl;
        if (i + 1 < lines.length) {
          streamUrl = lines[i + 1].trim();
        }

        // Extract quality info
        final bandwidth = int.tryParse(attributes['BANDWIDTH'] ?? '');
        final resolution = attributes['RESOLUTION'];
        final frameRateStr = attributes['FRAME-RATE'];
        final codecs = attributes['CODECS'];
        final name = attributes['NAME'] ?? attributes['VIDEO'];

        int? width, height, frameRate;
        if (resolution != null && resolution.contains('x')) {
          final parts = resolution.split('x');
          width = int.tryParse(parts[0]);
          height = int.tryParse(parts[1]);
        }
        if (frameRateStr != null) {
          frameRate = double.tryParse(frameRateStr)?.round();
        }

        // Generate ID and label
        final id = _generateId(name, height, frameRate, streamUrl);
        final label = _generateLabel(name, height, frameRate);

        if (id.isNotEmpty) {
          qualities.add(QualityOption(
            id: id,
            label: label,
            width: width,
            height: height,
            frameRate: frameRate,
            bandwidth: bandwidth,
            codecs: codecs,
          ));
        }
      }
    }

    // Sort by bandwidth (highest first, after Auto)
    if (qualities.length > 1) {
      final auto = qualities.removeAt(0);
      qualities.sort((a, b) => (b.bandwidth ?? 0).compareTo(a.bandwidth ?? 0));
      qualities.insert(0, auto);
    }

    print('[HlsManifestService] Parsed ${qualities.length} quality options');
    return qualities.isEmpty ? _defaultQualities() : qualities;
  }

  /// Parse HLS attribute string into key-value pairs
  Map<String, String> _parseAttributes(String attributeString) {
    final attributes = <String, String>{};
    final regex = RegExp(r'([A-Z-]+)=(?:"([^"]+)"|([^,]+))');
    
    for (final match in regex.allMatches(attributeString)) {
      final key = match.group(1)!;
      final value = match.group(2) ?? match.group(3) ?? '';
      attributes[key] = value;
    }
    
    return attributes;
  }

  /// Generate a unique ID for the quality option
  String _generateId(String? name, int? height, int? frameRate, String? url) {
    // Twitch uses specific names like "chunked" for source, "720p60", etc.
    if (name != null && name.isNotEmpty) {
      final lower = name.toLowerCase();
      if (lower == 'chunked' || lower.contains('source')) {
        return 'source';
      }
      // Use the name directly if it looks like a quality identifier
      if (RegExp(r'^\d+p\d*$').hasMatch(lower)) {
        return lower;
      }
    }
    
    // Generate from resolution and framerate
    if (height != null) {
      final fps = (frameRate != null && frameRate >= 50) ? '$frameRate' : '';
      return '${height}p$fps';
    }
    
    // Extract from URL as fallback
    if (url != null) {
      final match = RegExp(r'(\d+p\d*)').firstMatch(url);
      if (match != null) return match.group(1)!;
    }
    
    return '';
  }

  /// Generate a human-readable label for the quality option
  String _generateLabel(String? name, int? height, int? frameRate) {
    if (name != null) {
      final lower = name.toLowerCase();
      if (lower == 'chunked' || lower.contains('source')) {
        return 'Source';
      }
    }
    
    if (height != null) {
      final fps = (frameRate != null && frameRate >= 50) ? ' ($frameRate fps)' : '';
      return '${height}p$fps';
    }
    
    return name ?? 'Unknown';
  }

  /// Default quality options when manifest parsing fails
  List<QualityOption> _defaultQualities() {
    return const [
      QualityOption(id: 'auto', label: 'Auto'),
      QualityOption(id: 'source', label: 'Source', height: 1080, frameRate: 60),
      QualityOption(id: '1080p60', label: '1080p (60 fps)', height: 1080, frameRate: 60),
      QualityOption(id: '1080p', label: '1080p', height: 1080),
      QualityOption(id: '720p60', label: '720p (60 fps)', height: 720, frameRate: 60),
      QualityOption(id: '720p', label: '720p', height: 720),
      QualityOption(id: '480p', label: '480p', height: 480),
      QualityOption(id: '360p', label: '360p', height: 360),
      QualityOption(id: '160p', label: '160p', height: 160),
    ];
  }
}
