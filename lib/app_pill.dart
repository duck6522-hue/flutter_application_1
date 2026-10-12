import 'package:flutter/material.dart';

/// ChoiceChipの代わりに使う、文字が欠けない選択ピル
class AppPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dotColor;
  const AppPill({super.key, required this.label, required this.selected, required this.onTap, this.dotColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final fg = selected ? cs.onPrimary : cs.onSurface;
    return Material(
      color: selected ? cs.primary : (isDark ? cs.surfaceContainerHigh : Colors.white),
      shape: StadiumBorder(side: BorderSide(color: selected ? Colors.transparent : cs.outlineVariant)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (dotColor != null) ...[
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle, border: selected ? Border.all(color: cs.onPrimary, width: 1.5) : null),
              ),
              const SizedBox(width: 7),
            ],
            Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}
