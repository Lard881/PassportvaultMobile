import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Reusable skeleton loading widgets with shimmer effect
/// Replaces CircularProgressIndicator for better UX
class SkeletonLoader {
  /// Base shimmer wrapper with app theme colors
  static Widget shimmer({required Widget child}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: child,
    );
  }

  /// Single line skeleton (for text)
  static Widget line({
    double width = double.infinity,
    double height = 16.0,
    BorderRadius? borderRadius,
  }) {
    return shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius ?? BorderRadius.circular(4),
        ),
      ),
    );
  }

  /// Circular skeleton (for avatars, icons)
  static Widget circle({
    double size = 40.0,
  }) {
    return shimmer(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  /// Rectangle skeleton (for cards, images)
  static Widget rectangle({
    double width = double.infinity,
    double height = 100.0,
    BorderRadius? borderRadius,
  }) {
    return shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Card skeleton with icon, title, and subtitle
  static Widget card({
    bool showIcon = true,
    int subtitleLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            if (showIcon) ...[
              circle(size: 48),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  line(width: double.infinity, height: 16),
                  const SizedBox(height: 8),
                  ...List.generate(
                    subtitleLines,
                    (index) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: line(width: 150, height: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            line(width: 24, height: 24),
          ],
        ),
      ),
    );
  }

  /// List of card skeletons
  static Widget cardList({
    int itemCount = 5,
    bool showIcon = true,
    int subtitleLines = 1,
  }) {
    return ListView.builder(
      itemCount: itemCount,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (context, index) => card(
        showIcon: showIcon,
        subtitleLines: subtitleLines,
      ),
    );
  }

  /// Grid item skeleton (for dashboard cards)
  static Widget gridItem() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          circle(size: 40),
          const SizedBox(height: 12),
          line(width: 80, height: 20),
          const SizedBox(height: 8),
          line(width: 60, height: 14),
        ],
      ),
    );
  }

  /// Dashboard skeleton with stats cards
  static Widget dashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          line(width: 200, height: 24),
          const SizedBox(height: 8),
          line(width: 150, height: 16),
          const SizedBox(height: 24),
          
          // Stats grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: List.generate(4, (index) => gridItem()),
          ),
          
          const SizedBox(height: 24),
          
          // Section title
          line(width: 150, height: 20),
          const SizedBox(height: 16),
          
          // List items
          ...List.generate(3, (index) => card(subtitleLines: 2)),
        ],
      ),
    );
  }

  /// Document list skeleton
  static Widget documentList({int itemCount = 5}) {
    return cardList(
      itemCount: itemCount,
      showIcon: true,
      subtitleLines: 2,
    );
  }

  /// Profile list skeleton
  static Widget profileList({int itemCount = 5}) {
    return cardList(
      itemCount: itemCount,
      showIcon: true,
      subtitleLines: 1,
    );
  }

  /// Notification list skeleton
  static Widget notificationList({int itemCount = 5}) {
    return ListView.builder(
      itemCount: itemCount,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  circle(size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        line(width: double.infinity, height: 14),
                        const SizedBox(height: 6),
                        line(width: 100, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              line(width: double.infinity, height: 12),
              const SizedBox(height: 4),
              line(width: 200, height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Calendar skeleton with month view
  static Widget calendar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Month header
          rectangle(width: double.infinity, height: 50),
          const SizedBox(height: 16),
          
          // Calendar grid
          rectangle(width: double.infinity, height: 300),
          const SizedBox(height: 24),
          
          // Events list
          line(width: 150, height: 20),
          const SizedBox(height: 16),
          
          ...List.generate(3, (index) => card(subtitleLines: 1)),
        ],
      ),
    );
  }

  /// Alert list skeleton
  static Widget alertList({int itemCount = 5}) {
    return ListView.builder(
      itemCount: itemCount,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              circle(size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    line(width: double.infinity, height: 16),
                    const SizedBox(height: 8),
                    line(width: 120, height: 12),
                    const SizedBox(height: 4),
                    line(width: 100, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Generic loading screen with centered shimmer
  static Widget loadingScreen({String? message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          circle(size: 60),
          if (message != null) ...[
            const SizedBox(height: 16),
            line(width: 200, height: 16),
          ],
        ],
      ),
    );
  }
}
