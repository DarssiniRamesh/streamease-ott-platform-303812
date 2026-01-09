import 'package:flutter/material.dart';

class RailSkeleton extends StatelessWidget {
  const RailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final Color base = Theme.of(context).colorScheme.primary.withAlpha(18);
    final Color highlight = Theme.of(context).colorScheme.primary.withAlpha(30);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Container(
              height: 18,
              width: 180,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (BuildContext context, int index) {
                return Container(
                  width: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[base, highlight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
