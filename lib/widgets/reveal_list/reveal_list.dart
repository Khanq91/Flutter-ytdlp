/// RevealList
/// Origin: reimplemented — dựng lại "Animated List" của react-bits cho
/// mobile: entrance scale+fade khi item lọt viewport, chọn bằng tap thay vì
/// arrow keys, edge fade theo vị trí scroll.
/// Deps: flutter only
/// Flutter: 3.44.5
/// Entry file. Copy the whole folder into another project and import this file.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Scrollable list whose items pop in (scale 0.7→1, fade 0→1) the first time
/// they become ≥[visibleFraction] visible, with gradient fades hugging the
/// top/bottom edges while there is more content that way. Tap selects an
/// item; the current selection is handed back to [itemBuilder] for styling.
///
/// Each item reveals exactly once per list lifetime — scrolling away and
/// back does not replay it.
class RevealList extends StatefulWidget {
  const RevealList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.onItemSelected,
    this.initialSelectedIndex = -1,
    this.controller,
    this.itemKeyBuilder,
    this.onReorderItem,
    this.padding = const EdgeInsets.all(16),
    this.itemSpacing = 12,
    this.physics,
    this.shrinkWrap = false,
    this.showEdgeFades = true,
    this.edgeFadeColor,
    this.edgeFadeHeight = 90,
    this.entranceDuration = const Duration(milliseconds: 260),
    this.entranceStagger = const Duration(milliseconds: 80),
    this.visibleFraction = 0.5,
  });

  factory RevealList.children({
    Key? key,
    required List<Widget> children,
    ValueChanged<int>? onItemSelected,
    int initialSelectedIndex = -1,
    ScrollController? controller,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    double itemSpacing = 0,
    ScrollPhysics? physics,
    bool shrinkWrap = false,
    bool showEdgeFades = true,
    Color? edgeFadeColor,
    double edgeFadeHeight = 90,
    Duration entranceDuration = const Duration(milliseconds: 260),
    Duration entranceStagger = const Duration(milliseconds: 80),
    double visibleFraction = 0.5,
  }) => RevealList(
    key: key,
    itemCount: children.length,
    itemBuilder: (_, index, __) => children[index],
    onItemSelected: onItemSelected,
    initialSelectedIndex: initialSelectedIndex,
    controller: controller,
    padding: padding,
    itemSpacing: itemSpacing,
    physics: physics,
    shrinkWrap: shrinkWrap,
    showEdgeFades: showEdgeFades,
    edgeFadeColor: edgeFadeColor,
    edgeFadeHeight: edgeFadeHeight,
    entranceDuration: entranceDuration,
    entranceStagger: entranceStagger,
    visibleFraction: visibleFraction,
  );

  final int itemCount;

  /// Builds one item; `selected` reflects the current tap selection.
  final Widget Function(BuildContext context, int index, bool selected)
      itemBuilder;

  /// Fired when the user taps an item (after the selection updates).
  final ValueChanged<int>? onItemSelected;

  /// -1 = nothing selected initially.
  final int initialSelectedIndex;

  /// Optional external scroll controller; an internal one is created (and
  /// disposed) when null.
  final ScrollController? controller;

  /// Stable keys are useful when the list can be reordered or its items can
  /// change while the list remains mounted.
  final Key Function(int index)? itemKeyBuilder;

  /// Enables a reorderable vertical list while retaining the reveal effect.
  final void Function(int oldIndex, int newIndex)? onReorderItem;

  final EdgeInsetsGeometry padding;

  /// Vertical gap between items.
  final double itemSpacing;

  final ScrollPhysics? physics;
  final bool shrinkWrap;

  /// Show the top/bottom scroll-hint gradients.
  final bool showEdgeFades;

  /// Color the edge gradients fade from — match the backdrop behind the
  /// list. Defaults to `Theme.of(context).scaffoldBackgroundColor`.
  final Color? edgeFadeColor;

  final double edgeFadeHeight;

  /// Length of one item's entrance animation.
  final Duration entranceDuration;

  /// Extra delay per item for the batch visible on first layout.
  final Duration entranceStagger;

  /// How much of an item must be inside the viewport to trigger its
  /// entrance (0..1).
  final double visibleFraction;

  @override
  State<RevealList> createState() => _RevealListState();
}

class _RevealListState extends State<RevealList> {
  ScrollController? _internalController;
  ScrollController get _controller =>
      widget.controller ?? (_internalController ??= ScrollController());

  final Set<_RevealItemState> _items = <_RevealItemState>{};
  final Set<Key> _revealed = <Key>{};
  final ValueNotifier<double> _topFade = ValueNotifier<double>(0);
  final ValueNotifier<double> _bottomFade = ValueNotifier<double>(0);
  late int _selected = widget.initialSelectedIndex;
  bool _sweepScheduled = false;
  bool _initialSweepDone = false;

  @override
  void dispose() {
    _internalController?.dispose();
    _topFade.dispose();
    _bottomFade.dispose();
    super.dispose();
  }

  void _register(_RevealItemState item) {
    _items.add(item);
    _scheduleSweep();
  }

  void _unregister(_RevealItemState item) => _items.remove(item);

  Key _keyForIndex(int index) =>
      widget.itemKeyBuilder?.call(index) ?? ValueKey<int>(index);

  bool _wasRevealed(Key itemKey) => _revealed.contains(itemKey);

  void _scheduleSweep() {
    if (_sweepScheduled) {
      return;
    }
    _sweepScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sweepScheduled = false;
      if (mounted) {
        _sweep();
      }
    });
  }

  /// Reveal every registered item that is sufficiently inside the viewport.
  void _sweep() {
    if (!_controller.hasClients) {
      return;
    }
    final ScrollPosition position = _controller.position;
    _updateFades(position);
    final double vpTop = position.pixels;
    final double vpBottom = vpTop + position.viewportDimension;
    final List<_RevealItemState> due = <_RevealItemState>[];
    for (final _RevealItemState item in _items) {
      if (item._revealed) {
        continue;
      }
      final RenderObject? ro = item.context.findRenderObject();
      if (ro is! RenderBox || !ro.attached || !ro.hasSize) {
        continue;
      }
      final RenderAbstractViewport? viewport =
          RenderAbstractViewport.maybeOf(ro);
      if (viewport == null) {
        continue;
      }
      final double itemTop = viewport.getOffsetToReveal(ro, 0).offset;
      final double itemBottom = itemTop + ro.size.height;
      final double overlap = itemBottom.clamp(vpTop, vpBottom).toDouble() -
          itemTop.clamp(vpTop, vpBottom).toDouble();
      if (ro.size.height <= 0 ||
          overlap / ro.size.height >= widget.visibleFraction) {
        due.add(item);
      }
    }
    // Stagger only the batch visible on first layout; later scroll-triggered
    // reveals play immediately (they already arrive one by one).
    due.sort((a, b) => a.widget.index.compareTo(b.widget.index));
    for (int i = 0; i < due.length; i++) {
      _revealed.add(due[i].widget.identityKey);
      due[i].reveal(
        delay: _initialSweepDone
            ? Duration.zero
            : widget.entranceStagger * i,
      );
    }
    _initialSweepDone = true;
  }

  void _updateFades(ScrollPosition position) {
    if (!widget.showEdgeFades) {
      return;
    }
    final double fromTop = position.pixels - position.minScrollExtent;
    final double fromBottom = position.maxScrollExtent - position.pixels;
    _topFade.value = (fromTop / 50).clamp(0.0, 1.0).toDouble();
    _bottomFade.value = (fromBottom / 50).clamp(0.0, 1.0).toDouble();
  }

  void _select(int index) {
    setState(() => _selected = index);
    widget.onItemSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    Widget buildItem(BuildContext context, int index) {
      final itemKey = _keyForIndex(index);
      final child = widget.itemBuilder(context, index, index == _selected);
      final revealItem = _RevealItem(
        key: widget.onReorderItem == null ? itemKey : null,
        index: index,
        identityKey: itemKey,
        list: this,
        duration: widget.entranceDuration,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Selection is a visual state update. Let the item itself expose
          // its semantic actions without this parent tap merging them.
          excludeFromSemantics: true,
          onTap: () => _select(index),
          child: child,
        ),
      );
      if (widget.onReorderItem == null) {
        return revealItem;
      }
      // Use long-press to reorder on every platform. The default desktop drag
      // handle overlays trailing controls such as the queue remove button.
      return ReorderableDelayedDragStartListener(
        key: itemKey,
        index: index,
        child: revealItem,
      );
    }

    final Widget scrollable =
        widget.onReorderItem == null
            ? ListView.separated(
              controller: _controller,
              padding: widget.padding,
              physics: widget.physics,
              shrinkWrap: widget.shrinkWrap,
              itemCount: widget.itemCount,
              separatorBuilder: (_, _) => SizedBox(height: widget.itemSpacing),
              itemBuilder: buildItem,
            )
            : ReorderableListView.builder(
              buildDefaultDragHandles: false,
              scrollController: _controller,
              padding: widget.padding.resolve(Directionality.of(context)),
              physics: widget.physics,
              shrinkWrap: widget.shrinkWrap,
              itemCount: widget.itemCount,
              onReorderItem: widget.onReorderItem!,
              itemBuilder: buildItem,
            );

    final Widget list = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _sweep();
        return false;
      },
      child: scrollable,
    );
    if (!widget.showEdgeFades) {
      return list;
    }
    final Color fade =
        widget.edgeFadeColor ?? Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      children: <Widget>[
        Positioned.fill(child: list),
        _EdgeFade(
          top: true,
          color: fade,
          height: widget.edgeFadeHeight,
          opacity: _topFade,
        ),
        _EdgeFade(
          top: false,
          color: fade,
          height: widget.edgeFadeHeight,
          opacity: _bottomFade,
        ),
      ],
    );
  }
}

/// Sliver form of [RevealList] for a section inside a `CustomScrollView`.
/// Entrance timing matches [RevealList]; edge fades belong to the scroll view
/// itself and are therefore not drawn by this sliver.
class RevealListSliver extends StatefulWidget {
  const RevealListSliver({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.onItemSelected,
    this.initialSelectedIndex = -1,
    this.itemKeyBuilder,
    this.entranceDuration = const Duration(milliseconds: 260),
    this.entranceStagger = const Duration(milliseconds: 80),
    this.visibleFraction = 0.5,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index, bool selected)
      itemBuilder;
  final ValueChanged<int>? onItemSelected;
  final int initialSelectedIndex;
  final Key Function(int index)? itemKeyBuilder;
  final Duration entranceDuration;
  final Duration entranceStagger;
  final double visibleFraction;

  @override
  State<RevealListSliver> createState() => _RevealListSliverState();
}

class _RevealListSliverState extends State<RevealListSliver> {
  final Set<_SliverRevealItemState> _items = <_SliverRevealItemState>{};
  final Set<Key> _revealed = <Key>{};
  ScrollPosition? _position;
  late int _selected = widget.initialSelectedIndex;
  bool _sweepScheduled = false;
  bool _initialSweepDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (identical(nextPosition, _position)) return;
    _position?.removeListener(_scheduleSweep);
    _position = nextPosition;
    _position?.addListener(_scheduleSweep);
    _scheduleSweep();
  }

  @override
  void dispose() {
    _position?.removeListener(_scheduleSweep);
    super.dispose();
  }

  Key _keyForIndex(int index) =>
      widget.itemKeyBuilder?.call(index) ?? ValueKey<int>(index);

  bool _wasRevealed(Key key) => _revealed.contains(key);

  void _register(_SliverRevealItemState item) {
    _items.add(item);
    _scheduleSweep();
  }

  void _unregister(_SliverRevealItemState item) => _items.remove(item);

  void _scheduleSweep() {
    if (_sweepScheduled) return;
    _sweepScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sweepScheduled = false;
      if (mounted) _sweep();
    });
  }

  void _sweep() {
    final position = _position;
    if (position == null || !position.hasViewportDimension) return;
    final vpTop = position.pixels;
    final vpBottom = vpTop + position.viewportDimension;
    final due = <_SliverRevealItemState>[];
    for (final item in _items) {
      if (item._revealed) continue;
      final ro = item.context.findRenderObject();
      if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
      final viewport = RenderAbstractViewport.maybeOf(ro);
      if (viewport == null) continue;
      final itemTop = viewport.getOffsetToReveal(ro, 0).offset;
      final itemBottom = itemTop + ro.size.height;
      final overlap = itemBottom.clamp(vpTop, vpBottom).toDouble() -
          itemTop.clamp(vpTop, vpBottom).toDouble();
      if (ro.size.height <= 0 ||
          overlap / ro.size.height >= widget.visibleFraction) {
        due.add(item);
      }
    }
    due.sort((a, b) => a.widget.index.compareTo(b.widget.index));
    for (var i = 0; i < due.length; i++) {
      _revealed.add(due[i].widget.identityKey);
      due[i].reveal(
        delay: _initialSweepDone
            ? Duration.zero
            : widget.entranceStagger * i,
      );
    }
    _initialSweepDone = true;
  }

  void _select(int index) {
    setState(() => _selected = index);
    widget.onItemSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) => SliverList(
    delegate: SliverChildBuilderDelegate(
      (context, index) {
        final itemKey = _keyForIndex(index);
        final child = widget.itemBuilder(context, index, index == _selected);
        return _SliverRevealItem(
          key: itemKey,
          index: index,
          identityKey: itemKey,
          list: this,
          duration: widget.entranceDuration,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Preserve semantic actions provided by the item subtree.
            excludeFromSemantics: true,
            onTap: () => _select(index),
            child: child,
          ),
        );
      },
      childCount: widget.itemCount,
      findChildIndexCallback: (key) {
        if (widget.itemKeyBuilder == null) return null;
        for (var i = 0; i < widget.itemCount; i++) {
          if (_keyForIndex(i) == key) return i;
        }
        return null;
      },
    ),
  );
}

class _SliverRevealItem extends StatefulWidget {
  const _SliverRevealItem({
    super.key,
    required this.index,
    required this.identityKey,
    required this.list,
    required this.duration,
    required this.child,
  });

  final int index;
  final Key identityKey;
  final _RevealListSliverState list;
  final Duration duration;
  final Widget child;

  @override
  State<_SliverRevealItem> createState() => _SliverRevealItemState();
}

class _SliverRevealItemState extends State<_SliverRevealItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.list._wasRevealed(widget.identityKey) ? 1 : 0,
  );
  late CurvedAnimation _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  late bool _revealed = widget.list._wasRevealed(widget.identityKey);

  @override
  void initState() {
    super.initState();
    widget.list._register(this);
  }

  void reveal({Duration delay = Duration.zero}) {
    if (_revealed) return;
    _revealed = true;
    if (delay > Duration.zero) {
      final total = delay + widget.duration;
      _controller.duration = total;
      _curve.dispose();
      setState(() {
        _curve = CurvedAnimation(
          parent: _controller,
          curve: Interval(
            delay.inMicroseconds / total.inMicroseconds,
            1,
            curve: Curves.easeOutBack,
          ),
        );
      });
    }
    _controller.forward();
  }

  @override
  void dispose() {
    widget.list._unregister(this);
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.7, end: 1).animate(_curve),
      child: widget.child,
    ),
  );
}

class _EdgeFade extends StatelessWidget {
  const _EdgeFade({
    required this.top,
    required this.color,
    required this.height,
    required this.opacity,
  });

  final bool top;
  final Color color;
  final double height;
  final ValueListenable<double> opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: ValueListenableBuilder<double>(
          valueListenable: opacity,
          builder: (context, value, child) =>
              Opacity(opacity: value, child: child),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                end: top ? Alignment.bottomCenter : Alignment.topCenter,
                colors: <Color>[color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RevealItem extends StatefulWidget {
  const _RevealItem({
    super.key,
    required this.index,
    required this.identityKey,
    required this.list,
    required this.duration,
    required this.child,
  });

  final int index;
  final Key identityKey;
  final _RevealListState list;
  final Duration duration;
  final Widget child;

  @override
  State<_RevealItem> createState() => _RevealItemState();
}

class _RevealItemState extends State<_RevealItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    // Items the list already revealed once stay visible when the ListView
    // recycles and rebuilds them.
    value: widget.list._wasRevealed(widget.identityKey) ? 1 : 0,
  );
  late CurvedAnimation _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  late bool _revealed = widget.list._wasRevealed(widget.identityKey);

  @override
  void initState() {
    super.initState();
    widget.list._register(this);
  }

  void reveal({Duration delay = Duration.zero}) {
    if (_revealed) {
      return;
    }
    _revealed = true;
    if (delay > Duration.zero) {
      // Fold the stagger delay into the controller's timeline instead of a
      // Timer, so no timers outlive the animation (host widget tests stay
      // clean).
      final Duration total = delay + widget.duration;
      _controller.duration = total;
      _curve.dispose();
      setState(() {
        _curve = CurvedAnimation(
          parent: _controller,
          curve: Interval(
            delay.inMicroseconds / total.inMicroseconds,
            1,
            curve: Curves.easeOutBack,
          ),
        );
      });
    }
    _controller.forward();
  }

  @override
  void dispose() {
    widget.list._unregister(this);
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.7, end: 1).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
