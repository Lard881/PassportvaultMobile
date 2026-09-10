import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'confirm_dialog.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final int unreadCount;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onLogoTap;

  const AppHeader({
    super.key,
    this.unreadCount = 0,
    this.onNotificationTap,
    this.onLogoTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60.0);

  void _showUserMenu(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.user;
    final userName = user?['full_name'] ?? user?['name'] ?? 'User Account';
    final userEmail = user?['email'] ?? 'user@example.com';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // User Profile Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF0D6EFD),
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF212529),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userEmail,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey[400] : const Color(0xFF6C757D),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE9ECEF),
                ),
                // Settings Action
                ListTile(
                  leading: const Icon(
                    Icons.settings_outlined,
                    color: Color(0xFF0D6EFD),
                  ),
                  title: Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF212529),
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    Navigator.pushNamed(context, '/settings');
                  },
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE9ECEF),
                ),
                // Logout Action
                ListTile(
                  leading: const Icon(
                    Icons.logout,
                    color: Color(0xFFDC3545),
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDC3545),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    showDialog(
                      context: context,
                      builder: (dialogContext) => ConfirmDialog(
                        title: 'Logout',
                        message: 'Are you sure you want to log out of PassportVault?',
                        confirmText: 'Logout',
                        cancelText: 'Cancel',
                        type: 'danger',
                        onConfirm: () async {
                          await authProvider.logout();
                          if (context.mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                          }
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final userName = user?['full_name'] ?? user?['name'] ?? 'User';

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleSpacing: 16,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE9ECEF),
          height: 1.0,
        ),
      ),
      title: InkWell(
        onTap: onLogoTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/images/logo.svg',
                width: 28,
                height: 28,
              ),
              const SizedBox(width: 8),
              Text(
                'PassportVault',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF212529),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Notification Bell Icon with Badge
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, size: 24),
              color: isDark ? Colors.white70 : const Color(0xFF212529),
              tooltip: 'Notifications',
              onPressed: onNotificationTap,
            ),
            if (unreadCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC3545),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        width: 1.5,
                      ),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
        // User Profile Avatar Button
        Padding(
          padding: const EdgeInsets.only(right: 12, left: 4),
          child: InkWell(
            onTap: () => _showUserMenu(context, authProvider),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0D6EFD),
                border: Border.all(
                  color: isDark ? const Color(0xFF333333) : const Color(0xFFE9ECEF),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
