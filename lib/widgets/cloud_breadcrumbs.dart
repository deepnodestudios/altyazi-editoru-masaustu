import 'package:flutter/material.dart';

class CloudBreadcrumbs extends StatelessWidget {
  final List<String> labels;
  final ValueChanged<int>? onBreadcrumbTap;
  final String rootLabel;

  const CloudBreadcrumbs({
    super.key,
    required this.labels,
    this.onBreadcrumbTap,
    required this.rootLabel,
  });

  @override
  Widget build(BuildContext context) {
    // This is a placeholder implementation.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (index) {
          return GestureDetector(
            onTap: onBreadcrumbTap != null ? () => onBreadcrumbTap!(index) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                labels[index],
                style: const TextStyle(
                  decoration: TextDecoration.underline,
                  color: Colors.blue,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
