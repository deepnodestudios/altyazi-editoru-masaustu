import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:altyazi_editoru/models/subtitle_block.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import 'package:altyazi_editoru/app_settings.dart';
import '../controllers/translation_controller.dart';

class LiveSubtitleViewer extends StatefulWidget {
  final List<SubtitleBlock> source;
  final List<SubtitleBlock> target;
  final bool followEnabled;
  final bool isFullScreen;

  const LiveSubtitleViewer({
    super.key,
    required this.source,
    required this.target,
    this.followEnabled = true,
    this.isFullScreen = false,
  });

  @override
  State<LiveSubtitleViewer> createState() => _LiveSubtitleViewerState();
}

class _LiveSubtitleViewerState extends State<LiveSubtitleViewer>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollResumeTimer;
  bool _autoScrollPausedByUser = false;

  late final AnimationController _skeletonController;
  late final Animation<double> _skeletonOpacity;

  @override
  void initState() {
    super.initState();
    _skeletonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _skeletonOpacity = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _skeletonController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFollow());
  }

  @override
  void didUpdateWidget(LiveSubtitleViewer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If auto-follow is externally disabled (e.g., translation paused/stopped),
    // stop any pending resume timer and hide the paused UI.
    if (!widget.followEnabled && oldWidget.followEnabled) {
      _autoScrollResumeTimer?.cancel();
      if (_autoScrollPausedByUser) {
        setState(() {
          _autoScrollPausedByUser = false;
        });
      }
      return;
    }

    final newLen = widget.target.length;
    final oldLen = oldWidget.target.length;
    final lastTextChanged = newLen > 0 &&
        oldLen > 0 &&
        newLen == oldLen &&
        widget.target.last.text != oldWidget.target.last.text;

    // Yeni satır geldiğinde veya son satır güncellendiğinde takip et
    if (widget.followEnabled &&
        !_autoScrollPausedByUser &&
        (newLen != oldLen || lastTextChanged)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFollow());
    }
  }

  int _visibleItemCount() {
    // Yalnızca çevrilmiş satırları göster, kaynak listenin tamamını değil
    return widget.target.length;
  }

  void _scrollToFollow() {
    if (!widget.followEnabled) return;
    if (_autoScrollPausedByUser) return;
    if (!_scrollController.hasClients) return;

    final lastTranslatedIndex = widget.target.isEmpty ? -1 : widget.target.length - 1;
    if (lastTranslatedIndex < 0) return;

    // Scroll proportionally to the last translated index instead of jumping
    // to the end, keeping translation context in view.
    if (!_scrollController.position.hasContentDimensions) return;
    final total = _visibleItemCount();
    if (total <= 1) return;
    final fraction = lastTranslatedIndex / (total - 1);
    final target = (_scrollController.position.maxScrollExtent * fraction)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _onUserInteraction() {
    if (!widget.followEnabled) return;
    if (!_autoScrollPausedByUser) {
      setState(() {
        _autoScrollPausedByUser = true;
      });
    }
    _autoScrollResumeTimer?.cancel();
    // Otomatik devam etme kaldırıldı, kullanıcı butona basana kadar duraklatılır.
  }

  void _resumeFollowNow() {
    _autoScrollResumeTimer?.cancel();
    if (!widget.followEnabled) return;
    if (!_autoScrollPausedByUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFollow());
      return;
    }
    setState(() {
      _autoScrollPausedByUser = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFollow());
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // Only treat user-driven interactions as a pause trigger.
    if (notification is UserScrollNotification) {
      if (notification.direction != ScrollDirection.idle) {
        _onUserInteraction();
      }
    } else if (notification is ScrollStartNotification && notification.dragDetails != null) {
      _onUserInteraction();
    } else if (notification is ScrollUpdateNotification && notification.dragDetails != null) {
      _onUserInteraction();
    }
    return false;
  }

  @override
  void dispose() {
    _autoScrollResumeTimer?.cancel();
    _scrollController.dispose();
    _skeletonController.dispose();
    super.dispose();
  }

  Widget _buildSkeletonWaiting(AppSettings settings) {
    final colorScheme = Theme.of(context).colorScheme;
    final fill = colorScheme.surfaceContainerLow.withValues(alpha: 0.65);

    return FadeTransition(
      opacity: _skeletonOpacity,
      child: Container(
        color: fill,
        child: const SizedBox.expand(),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: Text(context.read<AppSettings>().trans['live_view'] ?? 'Canlı Önizleme'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
          body: Consumer<TranslationController>(
            builder: (context, controller, _) {
              return LiveSubtitleViewer(
                source: controller.sourceBlocks,
                target: controller.translatedBlocks,
                followEnabled: controller.status == TranslationStatus.running,
                isFullScreen: true,
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final trans = settings.trans;
    final colorScheme = Theme.of(context).colorScheme;
    final fontSize = settings.liveViewFontSize;

    // Responsive: use ~48% of viewport height, clamped to a sensible range.
    final viewerHeight = widget.isFullScreen
        ? double.infinity
        : (MediaQuery.of(context).size.height * 0.48).clamp(300.0, 600.0);

    return Container(
      height: viewerHeight,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor)),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.isFullScreen ? 8.0 : 10.0,
              widget.isFullScreen ? 8.0 : 8.0,
              widget.isFullScreen ? 8.0 : 10.0,
              widget.isFullScreen ? 8.0 : 8.0,
            ),
            child: SizedBox(
              height: 24,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Row(
                      children: [
                        Expanded(
                          child: Center(
                            child: Text(
                              trans['live_view_source'] ?? 'Source',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              trans['live_view_translation'] ?? 'Translation',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 20),
                          onPressed: settings.decreaseLiveViewFontSize,
                          tooltip: trans['decrease_font_size'] ?? 'Küçült',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add, size: 20),
                          onPressed: settings.increaseLiveViewFontSize,
                          tooltip: trans['increase_font_size'] ?? 'Büyüt',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        if (!widget.isFullScreen) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.fullscreen, size: 20),
                            onPressed: () => _openFullScreen(context),
                            tooltip: trans['fullscreen'] ?? 'Tam Ekran',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          Expanded(
            child: Stack(
              children: [
                if (widget.source.isNotEmpty && widget.target.isEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _buildSkeletonWaiting(settings),
                    ),
                  ),
                Listener(
                  onPointerDown: (_) => _onUserInteraction(),
                  onPointerMove: (_) => _onUserInteraction(),
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      _onUserInteraction();
                    }
                  },
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _handleScrollNotification,
                    child: Scrollbar(
                      controller: _scrollController,
                      interactive: true,
                      thumbVisibility: true,
                      thickness: 8,
                      radius: const Radius.circular(6),
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        itemCount: _visibleItemCount(),
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
                        itemBuilder: (context, index) {
                          // index şimdi yalnızca çevrilmiş satırları işaret ediyor
                          final target = widget.target[index];
                          final source = index < widget.source.length
                              ? widget.source[index]
                              : null;

                          if (source == null) {
                            return const SizedBox.shrink();
                          }

                          final int lastTranslatedIndex =
                              widget.target.isEmpty ? -1 : widget.target.length - 1;
                          final bool isFollowRow = index == lastTranslatedIndex;

                          return Container(
                              decoration: isFollowRow
                                  ? BoxDecoration(
                                      color: colorScheme.primaryContainer.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3), width: 1),
                                    )
                                  : null,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Metadata Header (Index & Timecode)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            "${source.index}",
                                            style: TextStyle(
                                                color: colorScheme.primary,
                                                fontSize: (fontSize - 2).clamp(8.0, 40.0),
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          source.timecode,
                                          style: TextStyle(
                                              color: colorScheme.onSurfaceVariant,
                                              fontSize: (fontSize - 2).clamp(8.0, 40.0),
                                              fontFamily: 'Courier',
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Content Row
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                          child: Container(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        decoration: const BoxDecoration(
                                            border: Border(right: BorderSide(color: Colors.transparent))), // Border kaldırıldı veya temaya uygun yapılabilir
                                        child: SelectableText(source.text,
                                            style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7), fontSize: fontSize)),
                                      )),
                                      Expanded(
                                          child: Padding(
                                        padding: const EdgeInsets.only(left: 8.0),
                                        child: SelectableText(
                                          target.text,
                                          style: TextStyle(
                                            color: target.text.isNotEmpty
                                                ? colorScheme.onSurface
                                                : colorScheme.onSurface.withValues(alpha: 0.3),
                                            fontSize: fontSize,
                                            fontWeight: target.text.isNotEmpty ? FontWeight.w500 : FontWeight.normal,
                                          ),
                                        ),
                                      )),
                                    ],
                                  ),
                                ],
                              ),
                            );
                        },
                      ),
                    ),
                  ),
                ),
                if (_autoScrollPausedByUser)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: colorScheme.inverseSurface.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                trans['live_view_follow_paused'] ??
                                    'Auto-follow paused',
                                style: TextStyle(
                                  color: colorScheme.onInverseSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _resumeFollowNow,                          icon: const Icon(Icons.arrow_downward),
                          label: Text(
                            trans['live_view_scroll_down'] ??
                                'Aşağı Git',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
