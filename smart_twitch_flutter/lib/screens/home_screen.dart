import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stream_preview.dart';
import '../models/category_preview.dart';
import '../services/twitch_browse_service.dart';
import '../services/preview_player_manager.dart';
import '../state/auth_provider.dart';
import '../utils/ui_config.dart';
import '../widgets/collapsible_sidebar.dart';
import '../widgets/stream_preview_card.dart';
import '../widgets/category_card.dart';
import 'player_screen.dart';
import 'login_screen.dart';

/// Main home screen with featured streams and categories
/// 
/// Layout similar to Twitch homepage:
/// - Search bar at top
/// - Collapsible sidebar on left
/// - Featured live streams row
/// - Categories row
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TwitchBrowseService _browseService = TwitchBrowseService();
  final PreviewPlayerManager _previewManager = PreviewPlayerManager();
  final TextEditingController _searchController = TextEditingController();
  
  List<StreamPreview> _featuredStreams = [];
  List<CategoryPreview> _categories = [];
  bool _isLoadingStreams = true;
  bool _isLoadingCategories = true;
  String? _streamsError;
  String? _categoriesError;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    // Dispose preview player when leaving home screen
    _previewManager.disposePlayer();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    await Future.wait([
      _loadFeaturedStreams(),
      _loadCategories(),
    ]);
  }
  
  Future<void> _loadFeaturedStreams() async {
    setState(() {
      _isLoadingStreams = true;
      _streamsError = null;
    });
    
    try {
      final streams = await _browseService.getFeaturedStreams(
        limit: UIConfig.homeScreenStreamCount,
      );
      
      if (mounted) {
        setState(() {
          _featuredStreams = streams;
          _isLoadingStreams = false;
        });
        
        // Pre-initialize ALL video controllers for instant previews
        // This runs in background - streams appear first, then become "ready"
        _previewManager.preloadAllStreams(streams);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _streamsError = 'Failed to load streams';
          _isLoadingStreams = false;
        });
      }
    }
  }
  
  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _categoriesError = null;
    });
    
    try {
      final categories = await _browseService.getTopGames(
        limit: UIConfig.homeScreenCategoryCount,
      );
      
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _categoriesError = 'Failed to load categories';
          _isLoadingCategories = false;
        });
      }
    }
  }
  
  void _onStreamTap(StreamPreview stream) async {
    // Dispose preview controllers before navigating to free RAM
    _previewManager.disposePlayer();
    
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(channelLogin: stream.login),
      ),
    );
    
    // When returning from player, reload the previews
    if (mounted && _featuredStreams.isNotEmpty) {
      _previewManager.preloadAllStreams(_featuredStreams);
    }
  }
  
  void _onCategoryTap(CategoryPreview category) {
    // TODO: Navigate to category browse screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Browse ${category.displayName} - Coming soon!'),
        duration: const Duration(seconds: 2),
        backgroundColor: UIConfig.twitchPurple,
      ),
    );
  }
  
  void _onSearchSubmit(String query) {
    if (query.trim().isEmpty) return;
    
    // TODO: Implement search in Phase 2
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Search "$query" - Coming soon!'),
        duration: const Duration(seconds: 2),
        backgroundColor: UIConfig.twitchPurple,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UIConfig.twitchDarkBg,
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              // Top bar with search
              _buildTopBar(),
              
              // Scrollable content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  color: UIConfig.twitchPurple,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(
                      left: UIConfig.sidebarCollapsedWidth + 16,
                      right: 16,
                      top: 16,
                      bottom: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Featured streams section
                        _buildSectionHeader(
                          'Live Channels',
                          icon: Icons.play_circle_filled,
                          onSeeAll: () {
                            // TODO: Navigate to browse all streams
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildFeaturedStreams(),
                        
                        const SizedBox(height: 32),
                        
                        // Categories section
                        _buildSectionHeader(
                          'Categories',
                          icon: Icons.category,
                          onSeeAll: () {
                            // TODO: Navigate to browse all categories
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildCategories(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Collapsible sidebar (overlays content)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Consumer(
              builder: (context, ref, child) {
                final authState = ref.watch(authProvider);
                return CollapsibleSidebar(
                  isLoggedIn: authState.isAuthenticated,
                  username: authState.userLogin,
                  onLoginPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                  onLogoutPressed: () {
                    ref.read(authProvider.notifier).logout();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Signed out successfully'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  onHomePressed: () {
                    // Already on home
                  },
                  onBrowsePressed: () {
                    // TODO: Navigate to browse screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Browse - Coming soon!'),
                        duration: Duration(seconds: 2),
                        backgroundColor: UIConfig.twitchPurple,
                      ),
                    );
                  },
                  onSettingsPressed: () {
                    // TODO: Navigate to settings screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Settings - Coming soon!'),
                        duration: Duration(seconds: 2),
                        backgroundColor: UIConfig.twitchPurple,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTopBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: UIConfig.twitchSurface,
      child: Row(
        children: [
          // Space for sidebar
          const SizedBox(width: UIConfig.sidebarCollapsedWidth),
          
          // Logo / Title
          const Row(
            children: [
              Icon(Icons.live_tv, color: UIConfig.twitchPurple, size: 28),
              SizedBox(width: 8),
              Text(
                'SmartTwitch',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(width: 32),
          
          // Search bar
          Expanded(
            child: Container(
              height: 36,
              constraints: const BoxConstraints(maxWidth: 400),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: UIConfig.twitchDarkBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.white54),
                    onPressed: () => _onSearchSubmit(_searchController.text),
                  ),
                ),
                onSubmitted: _onSearchSubmit,
              ),
            ),
          ),
          
          const Spacer(),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, {
    required IconData icon,
    VoidCallback? onSeeAll,
  }) {
    return Row(
      children: [
        Icon(icon, color: UIConfig.twitchPurple, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: const Text(
              'See all',
              style: TextStyle(color: UIConfig.twitchPurple),
            ),
          ),
      ],
    );
  }
  
  Widget _buildFeaturedStreams() {
    if (_isLoadingStreams) {
      return SizedBox(
        height: UIConfig.streamCardHeight + 80,
        child: const Center(
          child: CircularProgressIndicator(color: UIConfig.twitchPurple),
        ),
      );
    }
    
    if (_streamsError != null) {
      return SizedBox(
        height: UIConfig.streamCardHeight + 80,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white38, size: 48),
              const SizedBox(height: 12),
              Text(
                _streamsError!,
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadFeaturedStreams,
                style: ElevatedButton.styleFrom(
                  backgroundColor: UIConfig.twitchPurple,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_featuredStreams.isEmpty) {
      return SizedBox(
        height: UIConfig.streamCardHeight + 80,
        child: const Center(
          child: Text(
            'No live streams found',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }
    
    return SizedBox(
      height: UIConfig.streamCardHeight + 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _featuredStreams.length,
        itemBuilder: (context, index) {
          final stream = _featuredStreams[index];
          return Padding(
            padding: EdgeInsets.only(
              right: index < _featuredStreams.length - 1 ? 16 : 0,
            ),
            child: SizedBox(
              width: UIConfig.streamCardHeight * UIConfig.streamCardAspectRatio,
              child: StreamPreviewCard(
                stream: stream,
                onTap: () => _onStreamTap(stream),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildCategories() {
    if (_isLoadingCategories) {
      return SizedBox(
        height: UIConfig.categoryCardHeight + 60,
        child: const Center(
          child: CircularProgressIndicator(color: UIConfig.twitchPurple),
        ),
      );
    }
    
    if (_categoriesError != null) {
      return SizedBox(
        height: UIConfig.categoryCardHeight + 60,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white38, size: 48),
              const SizedBox(height: 12),
              Text(
                _categoriesError!,
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadCategories,
                style: ElevatedButton.styleFrom(
                  backgroundColor: UIConfig.twitchPurple,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_categories.isEmpty) {
      return SizedBox(
        height: UIConfig.categoryCardHeight + 60,
        child: const Center(
          child: Text(
            'No categories found',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }
    
    return SizedBox(
      height: UIConfig.categoryCardHeight + 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return Padding(
            padding: EdgeInsets.only(
              right: index < _categories.length - 1 ? 12 : 0,
            ),
            child: SizedBox(
              width: (UIConfig.categoryCardHeight - 50) * UIConfig.categoryCardAspectRatio,
              child: CategoryCard(
                category: category,
                onTap: () => _onCategoryTap(category),
              ),
            ),
          );
        },
      ),
    );
  }
}
