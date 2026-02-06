import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_twitch_flutter/widgets/debug/integrity_status_indicator.dart';
import '../core/core.dart';

/// Collapsible sidebar that slides over content
/// 
/// Expands on mouse enter, collapses on mouse leave.
/// Animation is kept snappy per UIUX requirements.
class CollapsibleSidebar extends ConsumerStatefulWidget {
  final bool isLoggedIn;
  final String? username;
  final String? avatarUrl;
  final VoidCallback? onLoginPressed;
  final VoidCallback? onLogoutPressed;
  final VoidCallback? onHomePressed;
  final VoidCallback? onBrowsePressed;
  final VoidCallback? onSettingsPressed;
  
  const CollapsibleSidebar({
    super.key,
    this.isLoggedIn = false,
    this.username,
    this.avatarUrl,
    this.onLoginPressed,
    this.onLogoutPressed,
    this.onHomePressed,
    this.onBrowsePressed,
    this.onSettingsPressed,
  });

  @override
  ConsumerState<CollapsibleSidebar> createState() => _CollapsibleSidebarState();
}

class _CollapsibleSidebarState extends ConsumerState<CollapsibleSidebar> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _widthAnimation;
  bool _isExpanded = false;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppDurations.sidebarAnimation,
      vsync: this,
    );
    _widthAnimation = Tween<double>(
      begin: AppDimens.sidebarCollapsedWidth,
      end: AppDimens.sidebarExpandedWidth,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppCurves.sidebar,
    ));
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _expand() {
    if (!_isExpanded) {
      _isExpanded = true;
      _controller.forward();
    }
  }
  
  void _collapse() {
    if (_isExpanded) {
      _isExpanded = false;
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _expand(),
      onExit: (_) => _collapse(),
      child: AnimatedBuilder(
        animation: _widthAnimation,
        builder: (context, child) {
          return Container(
            width: _widthAnimation.value,
            height: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                
                // User profile / Login button
                _buildProfileSection(),
                
                const SizedBox(height: 16),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 8),
                
                // Navigation items
                _buildNavItem(
                  icon: Icons.home,
                  label: 'Home',
                  onTap: widget.onHomePressed,
                ),
                _buildNavItem(
                  icon: Icons.explore,
                  label: 'Browse',
                  onTap: widget.onBrowsePressed,
                ),
                
                const Spacer(),
                
                // Integrity status indicator (debug only)
                const IntegrityStatusIndicator(
                  debugModeOnly: true,
                  size: 10,
                ),
                
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 8),
                
                // Settings at bottom
                _buildNavItem(
                  icon: Icons.settings,
                  label: 'Settings',
                  onTap: widget.onSettingsPressed,
                ),
                
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildProfileSection() {
    final isExpanded = _widthAnimation.value > AppDimens.sidebarCollapsedWidth + 20;
    
    if (widget.isLoggedIn && widget.username != null) {
      // Logged in user
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary,
                  backgroundImage: widget.avatarUrl != null 
                      ? NetworkImage(widget.avatarUrl!) 
                      : null,
                  child: widget.avatarUrl == null 
                      ? const Icon(Icons.person, color: Colors.white, size: 20)
                      : null,
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.username!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            // Logout button (only when expanded)
            if (isExpanded) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: widget.onLogoutPressed,
                  icon: const Icon(Icons.logout, size: 16, color: Colors.white54),
                  label: const Text(
                    'Sign out',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    } else {
      // Not logged in - show login button
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: InkWell(
          onTap: widget.onLoginPressed ?? () {
            // Show "Coming soon" toast
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login coming soon!'),
                duration: Duration(seconds: 2),
                backgroundColor: AppColors.primary,
              ),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.login, color: Colors.white, size: 20),
                if (isExpanded) ...[
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
  }
  
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final isExpanded = _widthAnimation.value > AppDimens.sidebarCollapsedWidth + 20;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 22),
              if (isExpanded) ...[
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
