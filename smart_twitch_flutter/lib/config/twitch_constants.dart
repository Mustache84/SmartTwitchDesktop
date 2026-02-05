/// Twitch API Configuration Constants
///
/// This file contains all Twitch API-related constants used throughout the app.
/// Centralizing these values ensures consistency and makes updates easier.
///
/// DO NOT duplicate these constants elsewhere - import this file instead.

/// OAuth Client ID for SmartTwitchDesktop
///
/// Registered OAuth application client ID. Works for:
/// - OAuth authentication flows (Device Code Grant)
/// - Twitch Helix API requests (official API)
///
/// Does NOT work with GraphQL API - use [twitchGqlClientId] instead.
/// Register/manage at: https://dev.twitch.tv/console/apps
const String twitchClientId = 'vrhsf9gxj2y4jntunres6mzber1fg1';

/// Client ID for Twitch GraphQL API (gql.twitch.tv)
///
/// Twitch's unofficial GraphQL API only accepts "blessed" client IDs
/// embedded in official Twitch clients. Custom OAuth client IDs return
/// HTTP 400 "Client-ID header is invalid" on GraphQL endpoints.
///
/// Used for: PlaybackAccessToken, featured streams, top games, search
const String twitchGqlClientId = 'kd1unb4b3q4t58fwlpcbzcbnm76a8fp';

/// GraphQL endpoint for token fetching and browse queries
///
/// Note: This is an unofficial API endpoint. Use for:
/// - PlaybackAccessToken queries (stream tokens)
/// - Featured streams
/// - Top games/categories
const String twitchGqlEndpoint = 'https://gql.twitch.tv/gql';

/// Helix API endpoint for official Twitch API calls
///
/// Official Twitch API. Use for:
/// - User information
/// - Followed channels
/// - Subscription status
/// - Other authenticated operations
const String twitchHelixEndpoint = 'https://api.twitch.tv/helix';

/// OAuth scopes required for app functionality
///
/// These scopes are requested during the Device Code Grant flow.
/// - chat:read - Read chat messages (IRC)
/// - chat:edit - Send chat messages (IRC)
/// - user:read:follows - Get user's followed channels
/// - user:read:subscriptions - Check subscription status for DVR eligibility
const List<String> twitchOAuthScopes = [
  'chat:read',
  'chat:edit',
  'user:read:follows',
  'user:read:subscriptions',
];
