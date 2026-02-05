import 'package:dio/dio.dart';
import '../models/stream_preview.dart';
import '../models/category_preview.dart';
import '../config/twitch_constants.dart';

/// Service for fetching Twitch browse data (streams, categories, search)
///
/// Uses Twitch GraphQL API for all queries. Ported from app/specific/Screens.js
class TwitchBrowseService {
  final Dio _dio;

  TwitchBrowseService({Dio? dio}) : _dio = dio ?? Dio();

  Map<String, String> get _headers => {
    'Client-ID': twitchGqlClientId,
    'Content-Type': 'application/json',
  };
  
  /// Fetch featured/recommended streams
  /// 
  /// Ported from Screens.js featuredQuery
  Future<List<StreamPreview>> getFeaturedStreams({int limit = 10}) async {
    // GraphQL query for featured streams
    final query = '''
    {
      featuredStreams(first: $limit, acceptedMature: true) {
        stream {
          type
          game { displayName, id }
          isMature
          title
          id
          previewImageURL
          viewersCount
          createdAt
          broadcaster {
            roles { isPartner }
            id
            login
            displayName
            language
            profileImageURL(width: 300)
          }
        }
      }
    }
    ''';
    
    try {
      final response = await _dio.post(
        twitchGqlEndpoint,
        data: {'query': query},
        options: Options(headers: _headers),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        // Check for errors
        if (data['errors'] != null) {
          print('[TwitchBrowseService] GraphQL errors: ${data['errors']}');
          // Try fallback to top streams
          return _getTopStreamsHelix(limit: limit);
        }
        
        final featuredStreams = data['data']?['featuredStreams'] as List?;
        if (featuredStreams == null || featuredStreams.isEmpty) {
          print('[TwitchBrowseService] No featured streams, falling back to top streams');
          return _getTopStreamsHelix(limit: limit);
        }
        
        return featuredStreams
            .map((item) => StreamPreview.fromGraphQL(item))
            .toList();
      } else {
        throw Exception('Failed to fetch featured streams: ${response.statusCode}');
      }
    } catch (e) {
      print('[TwitchBrowseService] Featured streams error: $e');
      // Fallback to Helix API for top streams
      return _getTopStreamsHelix(limit: limit);
    }
  }
  
  /// Fallback: Fetch top streams using Helix API
  Future<List<StreamPreview>> _getTopStreamsHelix({int limit = 10}) async {
    print('[TwitchBrowseService] Using Helix fallback for top streams');
    
    // Use GraphQL streams query as it doesn't require OAuth
    final query = '''
    {
      streams(first: $limit, options: {sort: VIEWER_COUNT}) {
        edges {
          node {
            type
            game { displayName, id }
            isMature
            title
            id
            previewImageURL
            viewersCount
            createdAt
            broadcaster {
              roles { isPartner }
              id
              login
              displayName
              language
              profileImageURL(width: 300)
            }
          }
        }
      }
    }
    ''';
    
    try {
      final response = await _dio.post(
        twitchGqlEndpoint,
        data: {'query': query},
        options: Options(headers: _headers),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        final edges = data['data']?['streams']?['edges'] as List?;
        
        if (edges == null || edges.isEmpty) {
          print('[TwitchBrowseService] No streams found');
          return [];
        }
        
        return edges
            .map((edge) => StreamPreview.fromGraphQL(edge['node']))
            .toList();
      } else {
        throw Exception('Failed to fetch top streams: ${response.statusCode}');
      }
    } catch (e) {
      print('[TwitchBrowseService] Top streams error: $e');
      return [];
    }
  }
  
  /// Fetch top games/categories
  /// 
  /// Ported from Screens.js gamesQuery
  Future<List<CategoryPreview>> getTopGames({int limit = 12}) async {
    final query = '''
    {
      games(first: $limit) {
        edges {
          node {
            id
            displayName
            boxArtURL
            viewersCount
            channelsCount
          }
        }
      }
    }
    ''';
    
    try {
      final response = await _dio.post(
        twitchGqlEndpoint,
        data: {'query': query},
        options: Options(headers: _headers),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        // Check for errors
        if (data['errors'] != null) {
          print('[TwitchBrowseService] GraphQL errors: ${data['errors']}');
          return [];
        }
        
        final edges = data['data']?['games']?['edges'] as List?;
        if (edges == null) {
          print('[TwitchBrowseService] No games data');
          return [];
        }
        
        return edges
            .map((edge) => CategoryPreview.fromGraphQL(edge))
            .toList();
      } else {
        throw Exception('Failed to fetch games: ${response.statusCode}');
      }
    } catch (e) {
      print('[TwitchBrowseService] Games error: $e');
      return [];
    }
  }
  
  /// Search for channels (placeholder - TODO: implement in Phase 2)
  Future<List<StreamPreview>> searchChannels(String query, {int limit = 20}) async {
    // TODO: Implement search in Phase 2
    print('[TwitchBrowseService] Search not implemented yet: $query');
    return [];
  }
  
  /// Search for games (placeholder - TODO: implement in Phase 2)
  Future<List<CategoryPreview>> searchGames(String query, {int limit = 20}) async {
    // TODO: Implement search in Phase 2
    print('[TwitchBrowseService] Game search not implemented yet: $query');
    return [];
  }
}
