import 'package:flutter/material.dart';

/// Banner widget that shows connectivity status
class OfflineBanner extends StatelessWidget {
  final bool isOnline;
  final bool showOnlineMessage;

  const OfflineBanner({
    super.key,
    required this.isOnline,
    this.showOnlineMessage = false,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show anything if online (unless we want to show "back online" message)
    if (isOnline && !showOnlineMessage) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: isOnline && showOnlineMessage ? 0 : 40,
      child: Material(
        color: isOnline ? const Color(0xFF198754) : const Color(0xFFdc3545),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOnline
                      ? 'Back online!'
                      : 'No internet - Viewing cached data',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Connectivity status indicator (small icon)
class ConnectivityIndicator extends StatelessWidget {
  final bool isOnline;
  final String? connectionType;

  const ConnectivityIndicator({
    super.key,
    required this.isOnline,
    this.connectionType,
  });

  @override
  Widget build(BuildContext context) {
    if (isOnline) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFdc3545).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFdc3545).withValues(alpha: 0.3),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 14, color: Color(0xFFdc3545)),
          SizedBox(width: 4),
          Text(
            'Offline',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFFdc3545),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
