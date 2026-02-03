/// Model representing a stream preview for the home/browse screens
class StreamPreview {
  final String id;
  final String login;
  final String displayName;
  final String title;
  final String? gameName;
  final String? gameId;
  final int viewersCount;
  final String previewImageUrl;
  final String profileImageUrl;
  final bool isPartner;
  final bool isMature;
  final String language;
  final DateTime? startedAt;

  const StreamPreview({
    required this.id,
    required this.login,
    required this.displayName,
    required this.title,
    this.gameName,
    this.gameId,
    required this.viewersCount,
    required this.previewImageUrl,
    required this.profileImageUrl,
    this.isPartner = false,
    this.isMature = false,
    this.language = 'en',
    this.startedAt,
  });

  /// Create from Twitch GraphQL featured/live stream response
  factory StreamPreview.fromGraphQL(Map<String, dynamic> json) {
    final stream = json['stream'] ?? json;
    final broadcaster = stream['broadcaster'] ?? {};
    final game = stream['game'];
    final roles = broadcaster['roles'] ?? {};
    
    // Parse preview image URL - replace dimensions placeholder
    String previewUrl = stream['previewImageURL'] ?? '';
    previewUrl = previewUrl
        .replaceAll('{width}', '440')
        .replaceAll('{height}', '248');
    
    // Parse created at
    DateTime? startedAt;
    if (stream['createdAt'] != null) {
      try {
        startedAt = DateTime.parse(stream['createdAt']);
      } catch (_) {}
    }
    
    return StreamPreview(
      id: stream['id']?.toString() ?? '',
      login: broadcaster['login'] ?? '',
      displayName: broadcaster['displayName'] ?? broadcaster['login'] ?? '',
      title: stream['title'] ?? '',
      gameName: game?['displayName'],
      gameId: game?['id']?.toString(),
      viewersCount: stream['viewersCount'] ?? 0,
      previewImageUrl: previewUrl,
      profileImageUrl: broadcaster['profileImageURL'] ?? '',
      isPartner: roles['isPartner'] == true,
      isMature: stream['isMature'] == true,
      language: broadcaster['language'] ?? 'en',
      startedAt: startedAt,
    );
  }

  /// Format viewer count for display (e.g., "1.2K", "45.3K")
  String get formattedViewers {
    if (viewersCount >= 1000000) {
      return '${(viewersCount / 1000000).toStringAsFixed(1)}M';
    } else if (viewersCount >= 1000) {
      return '${(viewersCount / 1000).toStringAsFixed(1)}K';
    }
    return viewersCount.toString();
  }

  /// Get uptime string (e.g., "2h 30m")
  String? get uptime {
    if (startedAt == null) return null;
    final duration = DateTime.now().difference(startedAt!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  String toString() => 'StreamPreview($login: $title)';
}
