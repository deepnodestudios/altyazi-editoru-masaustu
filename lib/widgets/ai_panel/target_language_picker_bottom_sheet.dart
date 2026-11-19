import 'package:flutter/material.dart';

Future<String?> showAiPanelTargetLanguagePickerBottomSheet({
  required BuildContext context,
  required Map<String, String> trans,
  required ColorScheme colorScheme,
  required List<Map<String, String>> options,
  required String currentCode,
  double? maxSheetWidth,
  bool? alignToLeft,
  Rect? anchorRect,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _TargetLanguagePickerDialog(
      trans: trans,
      colorScheme: colorScheme,
      options: options,
      currentCode: currentCode,
    ),
  );
}

class _TargetLanguagePickerDialog extends StatefulWidget {
  final Map<String, String> trans;
  final ColorScheme colorScheme;
  final List<Map<String, String>> options;
  final String currentCode;

  const _TargetLanguagePickerDialog({
    required this.trans,
    required this.colorScheme,
    required this.options,
    required this.currentCode,
  });

  @override
  State<_TargetLanguagePickerDialog> createState() =>
      _TargetLanguagePickerDialogState();
}

class _TargetLanguagePickerDialogState
    extends State<_TargetLanguagePickerDialog> {
  late final TextEditingController _controller;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.options
        : widget.options.where((o) {
            final code = (o['code'] ?? '').toLowerCase();
            final label = (o['label'] ?? '').toLowerCase();
            return code.contains(q) || label.contains(q);
          }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: widget.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: false,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: widget.trans['search_language_hint'] ?? 'Dil ara...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onChanged: (v) {
                setState(() {
                  _query = v;
                });
              },
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: widget.colorScheme.outlineVariant
                        .withValues(alpha: 0.35),
                  ),
                  itemBuilder: (ctx, i) {
                    final item = filtered[i];
                    final code = item['code'] ?? '';
                    final label = item['label'] ?? '';
                    final selected = code == widget.currentCode;

                    return ListTile(
                      dense: true,
                      title: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(code),
                      trailing: selected
                          ? Icon(Icons.check, color: widget.colorScheme.primary)
                          : null,
                      onTap: () => Navigator.pop(ctx, code),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
