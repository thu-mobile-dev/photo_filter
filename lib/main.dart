import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const double ring_width = 8.0;
const double vertical_padding_size = 24.0;
const int color_count_on_screen = 5;
const double viewport_fraction_per_color = 1.0 / color_count_on_screen;

void main() {
  debugPaintSizeEnabled = true;

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
      children: [
        Positioned.fill(
          child: PhotoView(filterColor: selectedColor),
        ),
        Positioned(
            left: 0.0,
            right: 0.0,
            bottom: 0.0,
            child: ColorSelectorView(
              onColorChanged: (Color newColor) {
                setState(() {
                  selectedColor = newColor;
                });
              },
            ))
      ],
    );
  }
}

class ColorSelectorView extends StatefulWidget {
  const ColorSelectorView({
    super.key,
    required this.onColorChanged,
  });

  final void Function(Color selectedColor) onColorChanged;

  @override
  State<ColorSelectorView> createState() => _ColorSelectorViewState();
}

class _ColorSelectorViewState extends State<ColorSelectorView> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final itemSize = constraints.maxWidth * viewport_fraction_per_color;

      return Stack(
        alignment: Alignment.bottomCenter,
        children: [
          ShadowView(
            height: itemSize + vertical_padding_size * 2,
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
            onColorChanged: widget.onColorChanged,
            fullWidth: constraints.maxWidth,
            itemSize: itemSize,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: RingView(
              size: itemSize,
              width: ring_width,
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
    required this.onColorChanged,
    required this.itemSize,
    required this.fullWidth,
  });

  final List<Color> colors;
  final void Function(Color selectedColor) onColorChanged;
  final double itemSize;
  final double fullWidth;

  @override
  State<ColorsView> createState() => _ColorsViewState();
}

class _ColorsViewState extends State<ColorsView> {
  late final PageController _controller;
  late int _page;

  int get filterCount => widget.colors.length;

  Color itemColor(int index) => widget.colors[index % filterCount];

  @override
  void initState() {
    super.initState();
    _page = 0;
    _controller = PageController(
      initialPage: _page,
      viewportFraction: viewport_fraction_per_color,
    );
    _controller.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final page = (_controller.page ?? 0).round();
    if (page != _page) {
      _page = page;
      widget.onColorChanged(widget.colors[page]);
    }
  }

  void _onColorChanged(int index) {
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 450),
      curve: Curves.ease,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollable(
      controller: _controller,
      axisDirection: AxisDirection.right,
      physics: const PageScrollPhysics(),
      viewportBuilder: (context, viewportOffset) {
        viewportOffset.applyViewportDimension(widget.fullWidth);
        viewportOffset.applyContentDimensions(
            0.0, widget.itemSize * (filterCount - 1));
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: SizedBox(
            height: widget.itemSize,
            child: Flow(
              delegate: ColorsViewFlowDelegate(
                viewportOffset: viewportOffset,
                colorsPerScreen: color_count_on_screen,
              ),
              children: [
                for (int i = 0; i < filterCount; i++)
                  Padding(
                    padding: const EdgeInsets.all(ring_width),
                    child: ColorView(
                      onTap: () => _onColorChanged(i),
                      filterColor: itemColor(i),
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
    required this.colorsPerScreen,
  }) : super(repaint: viewportOffset);

  final ViewportOffset viewportOffset;
  final int colorsPerScreen;

  @override
  void paintChildren(FlowPaintingContext context) {
    final count = context.childCount;

    // All available painting width
    final size = context.size.width;

    // The distance that a single item "page" takes up from the perspective
    // of the scroll paging system. We also use this size for the width and
    // height of a single item.
    final itemExtent = size / colorsPerScreen;

    // The current scroll position expressed as an item fraction, e.g., 0.0,
    // or 1.0, or 1.3, or 2.9, etc. A value of 1.3 indicates that item at
    // index 1 is active, and the user has scrolled 30% towards the item at
    // index 2.
    final active = viewportOffset.pixels / itemExtent;

    // Index of the first item we need to paint at this moment.
    // At most, we paint 3 items to the left of the active item.
    final min = math.max(0, active.floor() - 3).toInt();

    // Index of the last item we need to paint at this moment.
    // At most, we paint 3 items to the right of the active item.
    final max = math.min(count - 1, active.ceil() + 3).toInt();

    // Generate transforms for the visible items and sort by distance.
    for (var index = min; index <= max; index++) {
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
    required this.filterColor,
    this.onTap,
  });

  final Color filterColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: ClipOval(
            child: Image(
                image: const AssetImage("assets/texture.jpg"),
                color: filterColor.withOpacity(0.5),
                colorBlendMode: BlendMode.hardLight)),
      ),
    );
  }
}

class PhotoView extends StatelessWidget {
  const PhotoView({super.key, required this.filterColor});

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
  const RingView({super.key, required this.size, required this.width});

  final double size;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(width: width, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
