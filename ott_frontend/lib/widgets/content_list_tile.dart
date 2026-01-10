import 'package:flutter/material.dart';
import 'package:ott_frontend/widgets/pressable_scale.dart';

class ContentListTile extends StatelessWidget {
  const ContentListTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.heroTag,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String heroTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(16);

    return PressableScale(
      borderRadius: radius,
      pressedScale: 0.99,
      onTap: onTap,
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: Hero(
            tag: heroTag,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Theme.of(context).colorScheme.primary.withAlpha(24),
                    Theme.of(context).colorScheme.secondary.withAlpha(16),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const SizedBox(
                width: 46,
                height: 46,
                child: Icon(Icons.movie),
              ),
            ),
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
