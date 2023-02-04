import 'dart:math' show min, max;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show debugPaintSizeEnabled, ViewportOffset;

void main() {
  // debugPaintSizeEnabled = true;

  runApp(
    const MaterialApp(
      home: PhotoWithFilterPage(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class PhotoWithFilterPage extends StatefulWidget {
  const PhotoWithFilterPage({super.key});

  @override
  State<PhotoWithFilterPage> createState() => _PhotoWithFilterPageState();
}

class _PhotoWithFilterPageState extends State<PhotoWithFilterPage> {
  Color selectedColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned.fill(
          child: PhotoWithFilterView(filterColor: selectedColor),
        ),
        ColorSelectorView(
          onColorSelected: (Color color) {
            setState(() {
              selectedColor = color;
            });
          },
        )
      ],
    );
  }
}

class ColorSelectorView extends StatelessWidget {
  const ColorSelectorView({
    super.key,
    required this.onColorSelected,
    this.colorCountOnScreen = 5,
    this.ringWidth = 8.0,
    this.verticlePaddingSize = 24.0,
  });

  final void Function(Color selectedColor) onColorSelected;
  final int colorCountOnScreen;
  final double ringWidth;
  final double verticlePaddingSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final double itemSize = constraints.maxWidth * 1.0 / colorCountOnScreen;

      return Stack(
        alignment: Alignment.bottomCenter,
        children: [
          ShadowView(
            height: itemSize + verticlePaddingSize * 2,
          ),
          ColorsView(
            colors: [
              Colors.white,
              ...List.generate(
                Colors.primaries.length,
                (index) =>
                    Colors.primaries[(index * 4) % Colors.primaries.length],
              )
            ],
            onColorSelected: onColorSelected,
            fullWidth: constraints.maxWidth,
            colorCountOnScreen: colorCountOnScreen,
            itemSize: itemSize,
            verticlePaddingSize: verticlePaddingSize,
            ringWidth: ringWidth,
          ),
          IgnorePointer(
            // `RingView` with `Padding` is on `ColorsView` (in `Stack`).
            // Without `IgnorePointer`, user cannot slide the `ColorSelectorView`
            // when mouse on or finger tapped at the most center `ColorView`.
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: verticlePaddingSize),
              child: RingView(
                size: itemSize,
                borderWidth: ringWidth,
              ),
            ),
          )
        ],
      );
    });
  }
}

class ColorsView extends StatefulWidget {
  const ColorsView({
    super.key,
    required this.colors,
    required this.onColorSelected,
    required this.itemSize,
    required this.fullWidth,
    required this.verticlePaddingSize,
    required this.ringWidth,
    required this.colorCountOnScreen,
  });

  final List<Color> colors;
  final void Function(Color selectedColor) onColorSelected;
  final double itemSize;
  final double fullWidth;
  final double verticlePaddingSize;
  final double ringWidth;
  final int colorCountOnScreen;

  @override
  State<ColorsView> createState() => _ColorsViewState();
}

class _ColorsViewState extends State<ColorsView> {
  late final PageController _pageController;
  late int _currentPage;

  int get colorCount => widget.colors.length;
  Color itemColor(int index) => widget.colors[index % colorCount];

  @override
  void initState() {
    super.initState();
    _currentPage = 0;
    _pageController = PageController(
      initialPage: _currentPage,
      viewportFraction: 1.0 / widget.colorCountOnScreen,
    );
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final newPage = (_pageController.page ?? 0.0).round();
    if (newPage != _currentPage) {
      _currentPage = newPage;
      widget.onColorSelected(widget.colors[_currentPage]);
    }
  }

  void _onColorSelected(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 450),
      curve: Curves.ease,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollable(
      controller: _pageController,
      axisDirection: AxisDirection.right,
      physics: const PageScrollPhysics(),
      viewportBuilder: (context, viewportOffset) {
        viewportOffset.applyViewportDimension(widget.fullWidth);
        viewportOffset.applyContentDimensions(
            0.0, widget.itemSize * (colorCount - 1));

        return Padding(
          padding: EdgeInsets.symmetric(vertical: widget.verticlePaddingSize),
          child: SizedBox(
            height: widget.itemSize,
            child: Flow(
              delegate: ColorsViewFlowDelegate(
                viewportOffset: viewportOffset,
                colorCountOnScreen: widget.colorCountOnScreen,
              ),
              children: [
                for (int i = 0; i < colorCount; i++)
                  Padding(
                    padding: EdgeInsets.all(widget.ringWidth),
                    child: ColorView(
                      onTap: () => _onColorSelected(i),
                      color: itemColor(i),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ColorsViewFlowDelegate extends FlowDelegate {
  ColorsViewFlowDelegate({
    required this.viewportOffset,
    required this.colorCountOnScreen,
  }) : super(repaint: viewportOffset);

  final ViewportOffset viewportOffset;
  final int colorCountOnScreen;

  @override
  void paintChildren(FlowPaintingContext context) {
    final count = context.childCount;

    // All available painting width
    final size = context.size.width;

    // The distance that a single item "newPage" takes up from the perspective
    // of the scroll paging system. We also use this size for the width and
    // height of a single item.
    final itemExtent = size / colorCountOnScreen;

    // The current scroll position expressed as an item fraction, e.g., 0.0,
    // or 1.0, or 1.3, or 2.9, etc. A value of 1.3 indicates that item at
    // index 1 is active, and the user has scrolled 30% towards the item at
    // index 2.
    final active = viewportOffset.pixels / itemExtent;

    // Index of the first item we need to paint at this moment.
    // At most, we paint 3 items to the left of the active item.
    final minimum = max(0, active.floor() - 3).toInt();

    // Index of the last item we need to paint at this moment.
    // At most, we paint 3 items to the right of the active item.
    final maximum = min(count - 1, active.ceil() + 3).toInt();

    // Generate transforms for the visible items and sort by distance.
    for (var index = minimum; index <= maximum; index++) {
      final itemXFromCenter = itemExtent * index - viewportOffset.pixels;
      final percentFromCenter = 1.0 - (itemXFromCenter / (size / 2)).abs();
      final itemScale = 0.5 + (percentFromCenter * 0.5);
      final opacity = 0.25 + (percentFromCenter * 0.75);

      final itemTransform = Matrix4.identity()
        ..translate((size - itemExtent) / 2)
        ..translate(itemXFromCenter)
        ..translate(itemExtent / 2, itemExtent / 2)
        ..multiply(Matrix4.diagonal3Values(itemScale, itemScale, 1.0))
        ..translate(-itemExtent / 2, -itemExtent / 2);

      context.paintChild(
        index,
        transform: itemTransform,
        opacity: opacity,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ColorsViewFlowDelegate oldDelegate) {
    return oldDelegate.viewportOffset != viewportOffset;
  }
}

class ColorView extends StatelessWidget {
  const ColorView({
    super.key,
    required this.color,
    required this.onTap,
  });

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: ClipOval(
            child: Image(
                image: const AssetImage("assets/texture.jpg"),
                color: color.withOpacity(0.5),
                colorBlendMode: BlendMode.hardLight)),
      ),
    );
  }
}

class PhotoWithFilterView extends StatelessWidget {
  const PhotoWithFilterView({super.key, required this.filterColor});

  final Color filterColor;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: const AssetImage("assets/photo.jpg"),
      color: filterColor.withOpacity(0.5),
      colorBlendMode: BlendMode.color,
      fit: BoxFit.cover,
    );
  }
}

class ShadowView extends StatelessWidget {
  final double height;

  const ShadowView({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black87,
            ],
          ),
        ),
        child: SizedBox.expand(),
      ),
    );
  }
}

class RingView extends StatelessWidget {
  const RingView({super.key, required this.size, required this.borderWidth});

  final double size;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(width: borderWidth, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
