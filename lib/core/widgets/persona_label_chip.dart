import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:itiproject/core/services/persona_label_service.dart';

/// Interactive pastel label chip matching the Pinterest/iOS reference design
class PersonaLabelChip extends StatelessWidget {
  final String label;
  final int index;
  final VoidCallback? onTap;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const PersonaLabelChip({
    super.key,
    required this.label,
    required this.index,
    this.onTap,
    this.fontSize = 13.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = PersonaLabelService.getLabelBackgroundColor(index, label);
    const textColor = PersonaLabelService.labelTextColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: padding,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontal scrollable row or wrap of pastel persona labels
class PersonaLabelsRow extends StatelessWidget {
  final List<String> labels;
  final void Function(String label)? onLabelTap;
  final bool scrollable;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final EdgeInsetsGeometry chipPadding;

  const PersonaLabelsRow({
    super.key,
    required this.labels,
    this.onLabelTap,
    this.scrollable = true,
    this.padding = EdgeInsets.zero,
    this.fontSize = 13.5,
    this.chipPadding = const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
  });

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();

    if (scrollable) {
      return SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: padding,
          itemCount: labels.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final label = labels[index];
            return PersonaLabelChip(
              label: label,
              index: index,
              fontSize: fontSize,
              padding: chipPadding,
              onTap: onLabelTap != null ? () => onLabelTap!(label) : null,
            );
          },
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (int i = 0; i < labels.length; i++)
            PersonaLabelChip(
              label: labels[i],
              index: i,
              fontSize: fontSize,
              padding: chipPadding,
              onTap: onLabelTap != null ? () => onLabelTap!(labels[i]) : null,
            ),
        ],
      ),
    );
  }
}
