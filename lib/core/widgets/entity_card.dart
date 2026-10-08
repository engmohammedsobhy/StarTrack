import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:itiproject/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:itiproject/features/favorites/presentation/widgets/save_to_collection_sheet.dart';
import 'package:itiproject/features/home/data/models/entity_model.dart';
import 'package:itiproject/features/home/presentation/providers/user_interests_provider.dart';

class EntityCard extends ConsumerWidget {
  final KnowledgeEntity entity;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const EntityCard({
    super.key,
    required this.entity,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  void _showPinterestLongPressMenu(BuildContext context, WidgetRef ref, String? displayImage) {
    HapticFeedback.mediumImpact();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'PinterestContextMenu',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Consumer(
          builder: (ctx, refWatcher, _) {
            final favorites = refWatcher.watch(favoritesProvider);
            final isFav = favorites.any((e) => e.id == entity.id);

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Floating Preview Card
                        Material(
                          color: Colors.transparent,
                          child: Container(
                            width: 280,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (displayImage != null && displayImage.trim().isNotEmpty)
                                  AspectRatio(
                                    aspectRatio: entity.displayAspectRatio,
                                    child: CachedNetworkImage(
                                      imageUrl: displayImage,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.topCenter,
                                      httpHeaders: const {'User-Agent': 'StarTrackAI-Engine/2.3 (contact@startrack.ai)'},
                                      placeholder: (context, url) => Container(
                                        color: const Color(0xFF1E1E1E),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Color(0xFF2C3E50), Color(0xFF1A1A2E)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: const Center(child: Icon(Icons.person_outline, color: Colors.white70, size: 40)),
                                      ),
                                    ),
                                  )
                                else
                                  AspectRatio(
                                    aspectRatio: entity.displayAspectRatio,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Color(0xFF2C3E50), Color(0xFF1A1A2E)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: const Center(child: Icon(Icons.person_outline, color: Colors.white70, size: 40)),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entity.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (entity.description != null && entity.description!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          entity.description!,
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 13,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // 4 Quick Action Buttons
                        Material(
                          color: Colors.transparent,
                          child: Container(
                            width: 280,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2B2B2B).withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 1. Save to Collection
                                _PinterestActionButton(
                                  icon: isFav ? Icons.bookmark : Icons.bookmark_outline,
                                  iconColor: isFav ? Colors.redAccent : Colors.white,
                                  label: 'Save to Collection',
                                  onTap: () {
                                    Navigator.of(dialogContext).pop();
                                    showSaveToCollectionSheet(context, entity);
                                  },
                                ),
                                const Divider(height: 1, color: Colors.white12),
                                // 2. Ask AI about [Name]
                                _PinterestActionButton(
                                  icon: Icons.auto_awesome,
                                  iconColor: Colors.amberAccent,
                                  label: 'Ask AI about ${entity.title}',
                                  onTap: () {
                                    Navigator.of(dialogContext).pop();
                                    context.push('/person_chat', extra: entity);
                                  },
                                ),
                                const Divider(height: 1, color: Colors.white12),
                                // 3. Share
                                _PinterestActionButton(
                                  icon: Icons.share_rounded,
                                  iconColor: Colors.lightBlueAccent,
                                  label: 'Share',
                                  onTap: () {
                                    Navigator.of(dialogContext).pop();
                                    final imageUrl = displayImage ?? '';
                                    try {
                                      // ignore: deprecated_member_use
                                      Share.share('Check out ${entity.title} on Persona!\n$imageUrl');
                                    } catch (_) {}
                                  },
                                ),
                                const Divider(height: 1, color: Colors.white12),
                                // 4. View Profile
                                _PinterestActionButton(
                                  icon: Icons.remove_red_eye_rounded,
                                  iconColor: Colors.greenAccent,
                                  label: 'View Profile',
                                  onTap: () {
                                    ref.read(userInterestsProvider.notifier).recordViewedPersona(entity);
                                    Navigator.of(dialogContext).pop();
                                    context.push('/person/${Uri.encodeComponent(entity.title)}', extra: entity);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? displayImage = entity.thumbnailUrl;
    final double aspectRatio = entity.displayAspectRatio;

    return GestureDetector(
      onTap: () {
        ref.read(userInterestsProvider.notifier).recordViewedPersona(entity);
        context.push('/person/${Uri.encodeComponent(entity.title)}', extra: entity);
      },
      onLongPress: () => _showPinterestLongPressMenu(context, ref, displayImage),
      child: Hero(
        tag: 'entity_${entity.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              children: [
                Positioned.fill(
                  child: (displayImage != null && displayImage.trim().isNotEmpty)
                      ? Container(
                          color: Colors.white,
                          child: CachedNetworkImage(
                            key: ValueKey<String>(displayImage),
                            imageUrl: displayImage,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            httpHeaders: const {'User-Agent': 'StarTrackAI-Engine/2.3 (contact@startrack.ai)'},
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) => Container(
                              color: const Color(0xFF1E1E1E),
                              width: double.infinity,
                              height: double.infinity,
                            ),
                            errorWidget: (context, url, error) => Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF2C3E50), Color(0xFF1A1A2E)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              width: double.infinity,
                              height: double.infinity,
                              child: Center(
                                child: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: Colors.white12,
                                  child: Text(
                                    entity.title.isNotEmpty ? entity.title[0].toUpperCase() : '?',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white70),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF2C3E50), Color(0xFF1A1A2E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          width: double.infinity,
                          height: double.infinity,
                          child: Center(
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white12,
                              child: Text(
                                entity.title.isNotEmpty ? entity.title[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white70),
                              ),
                            ),
                          ),
                        ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.5, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entity.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (entity.description != null && entity.description!.isNotEmpty)
                        Text(
                          entity.description!,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 11,
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
        ),
      ),
    );
  }
}

class _PinterestActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _PinterestActionButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
