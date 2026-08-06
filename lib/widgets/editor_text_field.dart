import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_settings.dart';
import '../services/editor_service.dart';

class EditorTextField extends StatefulWidget {
  final String initialText;
  final ValueChanged<String> onChanged;
  final String searchQuery;
  final bool isCaseSensitive;
  final bool isRegexSearch;
  final double fontSize;
  final bool isCurrentMatch;

  const EditorTextField({
    super.key,
    required this.initialText,
    required this.onChanged,
    this.searchQuery = '',
    this.isCaseSensitive = false,
    this.isRegexSearch = false,
    this.fontSize = 16.0,
    this.isCurrentMatch = false,
  });

  @override
  State<EditorTextField> createState() => _EditorTextFieldState();
}

class _EditorTextFieldState extends State<EditorTextField> {
  late HighlightEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = HighlightEditingController(text: widget.initialText);
    _controller.searchQuery = widget.searchQuery;
    _controller.isCaseSensitive = widget.isCaseSensitive;
    _controller.isRegexSearch = widget.isRegexSearch;
    _controller.isCurrentMatch = widget.isCurrentMatch;
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {
      _controller.updateSearch(
        widget.searchQuery,
        widget.isCaseSensitive,
        widget.isRegexSearch,
        widget.isCurrentMatch,
        _focusNode.hasFocus,
      );
    });
  }

  void _transformSelection(String Function(String) transformer) {
    final text = _controller.text;
    final selection = _controller.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final selectedText = text.substring(selection.start, selection.end);
      final transformedText = transformer(selectedText);
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        transformedText,
      );

      final newSelection = selection.baseOffset <= selection.extentOffset
          ? TextSelection(
              baseOffset: selection.start,
              extentOffset: selection.start + transformedText.length,
            )
          : TextSelection(
              baseOffset: selection.start + transformedText.length,
              extentOffset: selection.start,
            );

      _controller.value = TextEditingValue(
        text: newText,
        selection: newSelection,
      );
      widget.onChanged(newText);
    }
  }

  @override
  void didUpdateWidget(covariant EditorTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialText != _controller.text) {
      _controller.text = widget.initialText;
    }
    if (widget.searchQuery != oldWidget.searchQuery ||
        widget.isCaseSensitive != oldWidget.isCaseSensitive ||
        widget.isRegexSearch != oldWidget.isRegexSearch ||
        widget.isCurrentMatch != oldWidget.isCurrentMatch) {
      _controller.updateSearch(
        widget.searchQuery,
        widget.isCaseSensitive,
        widget.isRegexSearch,
        widget.isCurrentMatch,
        _focusNode.hasFocus,
      );
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      minLines: 1,
      maxLines: 8,
      style: TextStyle(fontSize: widget.fontSize),
      enableInteractiveSelection: true,
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        filled: _focusNode.hasFocus,
        fillColor: Theme.of(context).colorScheme.primary.withAlpha(26),
      ),
      contextMenuBuilder:
          (BuildContext context, EditableTextState editableTextState) {
            final settings = context.read<AppSettings>();
            final trans = settings.trans;

            final List<ContextMenuButtonItem> buttonItems =
                editableTextState.contextMenuButtonItems;

            // Override Flutter's built-in context menu labels with localized versions
            for (int i = 0; i < buttonItems.length; i++) {
              final item = buttonItems[i];
              String? label;
              switch (item.type) {
                case ContextMenuButtonType.cut:
                  label = trans['cut'];
                  break;
                case ContextMenuButtonType.copy:
                  label = trans['copy'];
                  break;
                case ContextMenuButtonType.paste:
                  label = trans['paste'];
                  break;
                case ContextMenuButtonType.selectAll:
                  label = trans['select_all'];
                  break;
                case ContextMenuButtonType.delete:
                  label = trans['delete'];
                  break;
                default:
                  break;
              }
              if (label != null) {
                buttonItems[i] = ContextMenuButtonItem(
                  label: label,
                  onPressed: item.onPressed,
                  type: item.type,
                );
              }
            }

            if (_controller.selection.isValid &&
                !_controller.selection.isCollapsed) {
              buttonItems.add(
                ContextMenuButtonItem(
                  label: trans["ctx_menu_upper"] ?? "AA",
                  onPressed: () {
                    _transformSelection(
                      (s) => s.replaceAll('i', 'İ').toUpperCase(),
                    );
                    editableTextState.hideToolbar();
                  },
                ),
              );

              buttonItems.add(
                ContextMenuButtonItem(
                  label: trans["ctx_menu_lower"] ?? "aa",
                  onPressed: () {
                    _transformSelection(
                      (s) => s
                          .replaceAll('I', 'ı')
                          .replaceAll('İ', 'i')
                          .toLowerCase(),
                    );
                    editableTextState.hideToolbar();
                  },
                ),
              );

              buttonItems.add(
                ContextMenuButtonItem(
                  label: trans["ctx_menu_capitalize"] ?? "Aa",
                  onPressed: () {
                    _transformSelection((s) {
                      return s
                          .split(' ')
                          .map((str) {
                            if (str.isEmpty) return str;
                            String first = str
                                .substring(0, 1)
                                .replaceAll('i', 'İ')
                                .toUpperCase();
                            String rest = "";
                            if (str.length > 1) {
                              rest = str
                                  .substring(1)
                                  .replaceAll('I', 'ı')
                                  .replaceAll('İ', 'i')
                                  .toLowerCase();
                            }
                            return "$first$rest";
                          })
                          .join(' ');
                    });
                    editableTextState.hideToolbar();
                  },
                ),
              );
            }

            return AdaptiveTextSelectionToolbar.buttonItems(
              anchors: editableTextState.contextMenuAnchors,
              buttonItems: buttonItems,
            );
          },
      onChanged: widget.onChanged,
    );
  }
}

class HighlightEditingController extends TextEditingController {
  String searchQuery = "";
  bool isCaseSensitive = false;
  bool isRegexSearch = false;
  bool isCurrentMatch = false;
  bool hasFocus = false;

  HighlightEditingController({super.text});

  void updateSearch(
    String query,
    bool caseSensitive,
    bool regex,
    bool current,
    bool focused,
  ) {
    searchQuery = query;
    isCaseSensitive = caseSensitive;
    isRegexSearch = regex;
    isCurrentMatch = current;
    hasFocus = focused;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (searchQuery.isEmpty || hasFocus) {
      return TextSpan(style: style, text: text);
    }

    final List<TextSpan> children = [];
    final String content = text;

    if (isRegexSearch) {
      try {
        final regex = RegExp(
          searchQuery,
          caseSensitive: isCaseSensitive,
          multiLine: true,
        );
        final matches = regex.allMatches(content);

        int currentIndex = 0;
        for (final match in matches) {
          if (match.start > currentIndex) {
            children.add(
              TextSpan(
                text: content.substring(currentIndex, match.start),
                style: style,
              ),
            );
          }
          children.add(
            TextSpan(
              text: content.substring(match.start, match.end),
              style: style?.copyWith(
                backgroundColor: isCurrentMatch
                    ? Colors.orange.withAlpha(153)
                    : Colors.yellow.withAlpha(128),
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
          currentIndex = match.end;
        }
        if (currentIndex < content.length) {
          children.add(
            TextSpan(text: content.substring(currentIndex), style: style),
          );
        }
        return TextSpan(style: style, children: children);
      } catch (_) {
        return TextSpan(style: style, text: text);
      }
    }

    final ranges = EditorService.findPlainTextMatchRanges(
      content,
      searchQuery,
      isCaseSensitive,
    );
    if (ranges.isEmpty) {
      return TextSpan(style: style, text: text);
    }

    int currentIndex = 0;
    for (final range in ranges) {
      if (range.start > currentIndex) {
        children.add(
          TextSpan(
            text: content.substring(currentIndex, range.start),
            style: style,
          ),
        );
      }

      children.add(
        TextSpan(
          text: content.substring(range.start, range.end),
          style: style?.copyWith(
            backgroundColor: isCurrentMatch
                ? Colors.orange.withAlpha(153)
                : Colors.yellow.withAlpha(128),
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      currentIndex = range.end;
    }

    if (currentIndex < content.length) {
      children.add(
        TextSpan(text: content.substring(currentIndex), style: style),
      );
    }

    return TextSpan(style: style, children: children);
  }
}
