import 'package:flutter/material.dart';

Future<String?> showAiPanelTargetLanguagePickerBottomSheet({
  required BuildContext context,
  required Map<String, String> trans,
  required ColorScheme colorScheme,
  required List<Map<String, String>> options,
  required String currentCode,
  double? maxSheetWidth,
  bool alignToLeft = false,
  Rect? anchorRect,
}) {
  if (anchorRect != null) {
    return showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (ctx, _, __) {
        var query = '';
        final controller = TextEditingController();

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final q = query.trim().toLowerCase();
            final filtered = q.isEmpty
                ? options
                : options.where((o) {
                    final code = (o['code'] ?? '').toLowerCase();
                    final label = (o['label'] ?? '').toLowerCase();
                    return code.contains(q) || label.contains(q);
                  }).toList();

            final media = MediaQuery.of(ctx);
            final screenSize = media.size;
            final left = anchorRect.left.clamp(8.0, screenSize.width - 8.0);
            final width = anchorRect.width.clamp(
              220.0,
              screenSize.width - left - 8.0,
            );
            final top = (anchorRect.bottom + 6.0).clamp(8.0, screenSize.height - 8.0);
            final maxHeight = (screenSize.height - top - 8.0).clamp(180.0, 460.0);

            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(ctx),
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned(
                  left: left,
                  top: top,
                  width: width,
                  child: Material(
                    color: colorScheme.surface,
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 12,
                        right: 12,
                        top: 12,
                        bottom: 12 + media.viewInsets.bottom,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxHeight),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: controller,
                              autofocus: false,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search),
                                hintText:
                                    trans['search_language_hint'] ?? 'Dil ara...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                isDense: true,
                              ),
                              onChanged: (v) {
                                setSheetState(() {
                                  query = v;
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: colorScheme.outlineVariant
                                      .withValues(alpha: 0.35),
                                ),
                                itemBuilder: (ctx, i) {
                                  final item = filtered[i];
                                  final code = item['code'] ?? '';
                                  final label = item['label'] ?? '';
                                  final selected = code == currentCode;

                                  return InkWell(
                                    onTap: () => Navigator.pop(ctx, code),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 64,
                                            child: Text(
                                              code,
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w500,
                                                color: colorScheme.primary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 22,
                                                color: colorScheme.onSurface,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (selected)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 8,
                                              ),
                                              child: Icon(
                                                Icons.check,
                                                color: colorScheme.primary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  final shouldUseDesktopLeftSheet = alignToLeft && maxSheetWidth != null;

  if (shouldUseDesktopLeftSheet) {
    return showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: colorScheme.scrim.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, _, __) {
        var query = '';
        final controller = TextEditingController();

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final q = query.trim().toLowerCase();
            final filtered = q.isEmpty
                ? options
                : options.where((o) {
                    final code = (o['code'] ?? '').toLowerCase();
                    final label = (o['label'] ?? '').toLowerCase();
                    return code.contains(q) || label.contains(q);
                  }).toList();

            return SafeArea(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Material(
                  color: colorScheme.surface,
                  elevation: 8,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    width: maxSheetWidth,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 12,
                        bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: controller,
                            autofocus: false,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText:
                                  trans['search_language_hint'] ?? 'Dil ara...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              isDense: true,
                            ),
                            onChanged: (v) {
                              setSheetState(() {
                                query = v;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: 0.35),
                              ),
                              itemBuilder: (ctx, i) {
                                final item = filtered[i];
                                final code = item['code'] ?? '';
                                final label = item['label'] ?? '';
                                final selected = code == currentCode;

                                return InkWell(
                                  onTap: () => Navigator.pop(ctx, code),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 64,
                                          child: Text(
                                            code,
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w500,
                                              color: colorScheme.primary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 22,
                                              color: colorScheme.onSurface,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (selected)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            child: Icon(
                                              Icons.check,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
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

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: colorScheme.surface,
    builder: (ctx) {
      var query = '';
      final controller = TextEditingController();
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          final q = query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? options
              : options.where((o) {
                  final code = (o['code'] ?? '').toLowerCase();
                  final label = (o['label'] ?? '').toLowerCase();
                  return code.contains(q) || label.contains(q);
                }).toList();

          final content = Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: false,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: trans['search_language_hint'] ?? 'Dil ara...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    setSheetState(() {
                      query = v;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: colorScheme.outlineVariant
                          .withValues(alpha: 0.35),
                    ),
                    itemBuilder: (ctx, i) {
                      final item = filtered[i];
                      final code = item['code'] ?? '';
                      final label = item['label'] ?? '';
                      final selected = code == currentCode;

                      return InkWell(
                        onTap: () => Navigator.pop(ctx, code),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 64,
                                child: Text(
                                  code,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 22,
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (selected)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.check,
                                    color: colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );

          return SafeArea(
            child: Align(
              alignment: alignToLeft ? Alignment.bottomLeft : Alignment.bottomCenter,
              child: SizedBox(
                width: maxSheetWidth,
                child: content,
              ),
            ),
          );
        },
      );
    },
  );
}
