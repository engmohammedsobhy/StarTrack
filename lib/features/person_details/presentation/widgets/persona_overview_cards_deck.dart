import 'package:flutter/material.dart';
import 'package:itiproject/features/home/data/models/entity_model.dart';
import '../../data/models/rag_response_model.dart';

class PersonaOverviewCardsDeck extends StatefulWidget {
  final List<OverviewCardModel> cards;
  final KnowledgeEntity entity;

  const PersonaOverviewCardsDeck({
    super.key,
    required this.cards,
    required this.entity,
  });

  @override
  State<PersonaOverviewCardsDeck> createState() =>
      _PersonaOverviewCardsDeckState();
}

class _PersonaOverviewCardsDeckState extends State<PersonaOverviewCardsDeck> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // 1.0 viewport fraction to fill the full normal stretch of the app
    _pageController = PageController(viewportFraction: 1.0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < widget.cards.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalCards = widget.cards.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Text(
                  'Overview',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(width: 10),
                // Simple Counter Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252525),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_currentPage + 1}/$totalCards',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            // Navigation Controls
            Row(
              children: [
                InkWell(
                  onTap: _currentPage > 0 ? _previousPage : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 22,
                      color: _currentPage > 0 ? Colors.white : Colors.white24,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: _currentPage < totalCards - 1 ? _nextPage : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: _currentPage < totalCards - 1
                          ? Colors.white
                          : Colors.white24,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Simple Pinterest-style Swipeable Card
        SizedBox(
          height: 195,
          child: PageView.builder(
            controller: _pageController,
            itemCount: totalCards,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final card = widget.cards[index];

              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Only
                    Text(
                      card.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),

                    // Content Under
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          card.content,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 14.5,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // Animated Page Indicator Dots
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(totalCards, (index) {
              final isCurrent = index == _currentPage;
              return GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 4,
                  width: isCurrent ? 18 : 5,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
