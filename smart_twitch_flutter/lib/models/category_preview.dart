/// Model representing a category/game preview for the home/browse screens
class CategoryPreview {
  final String id;
  final String displayName;
  final String boxArtUrl;
  final int viewersCount;
  final int? channelsCount;

  const CategoryPreview({
    required this.id,
    required this.displayName,
    required this.boxArtUrl,
    required this.viewersCount,
    this.channelsCount,
  });

  /// Create from Twitch GraphQL games response
  factory CategoryPreview.fromGraphQL(Map<String, dynamic> json) {
    final node = json['node'] ?? json;
    
    // Parse box art URL - replace dimensions placeholder
    String boxArt = node['boxArtURL'] ?? '';
    boxArt = boxArt
        .replaceAll('{width}', '188')
        .replaceAll('{height}', '250');
    
    // Handle case where dimensions are in URL format like /188x250/
    if (!boxArt.contains('188') && boxArt.contains('-{width}x{height}')) {
      boxArt = boxArt.replaceAll('-{width}x{height}', '-188x250');
    }
    
    return CategoryPreview(
      id: node['id']?.toString() ?? '',
      displayName: node['displayName'] ?? '',
      boxArtUrl: boxArt,
      viewersCount: node['viewersCount'] ?? 0,
      channelsCount: node['channelsCount'],
    );
  }

  /// Format viewer count for display (e.g., "1.2K viewers")
  String get formattedViewers {
    if (viewersCount >= 1000000) {
      return '${(viewersCount / 1000000).toStringAsFixed(1)}M viewers';
    } else if (viewersCount >= 1000) {
      return '${(viewersCount / 1000).toStringAsFixed(1)}K viewers';
    }
    return '$viewersCount viewers';
  }

  /// Format channel count for display
  String? get formattedChannels {
    if (channelsCount == null) return null;
    if (channelsCount! >= 1000) {
      return '${(channelsCount! / 1000).toStringAsFixed(1)}K';
    }
    return channelsCount.toString();
  }

  @override
  String toString() => 'CategoryPreview($displayName)';
}
