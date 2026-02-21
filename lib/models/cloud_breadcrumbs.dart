import 'package:flutter/material.dart';

class CloudBreadcrumbs extends StatelessWidget {
  final List<String> labels;
  final ValueChanged<int>? onBreadcrumbTap;
  final String rootLabel;

  const CloudBreadcrumbs({
    super.key,
    required this.labels,
    required this.onBreadcrumbTap,
    this.rootLabel = 'Root',
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            TextButton(
              onPressed: (onBreadcrumbTap == null || i == labels.length - 1)
                  ? null
                  : () => onBreadcrumbTap!(i),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
              ),
              child: Text(
                labels[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (i != labels.length - 1)
              const Icon(Icons.chevron_right, size: 18),
          ],
          if (labels.isEmpty)
            Text(
              rootLabel,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }
}