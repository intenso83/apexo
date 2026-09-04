import 'package:flutter/material.dart';

class SignatureController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];

  bool get isEmpty =>
      _strokes.fold<int>(0, (count, stroke) => count + stroke.length) < 2;
  List<List<Offset>> get strokes => _strokes;

  void start(Offset point) {
    if (_strokes.length >= 100) return;
    _strokes.add([_clamp(point)]);
    notifyListeners();
  }

  void append(Offset point) {
    if (_strokes.isEmpty || _strokes.last.length >= 1000) return;
    _strokes.last.add(_clamp(point));
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  List<List<Map<String, double>>> toJson() => _strokes
      .where((stroke) => stroke.isNotEmpty)
      .map(
        (stroke) => stroke
            .map((point) => {'x': point.dx, 'y': point.dy})
            .toList(growable: false),
      )
      .toList(growable: false);

  Offset _clamp(Offset point) =>
      Offset(point.dx.clamp(0.0, 1.0), point.dy.clamp(0.0, 1.0));
}

class SignaturePad extends StatefulWidget {
  const SignaturePad({
    super.key,
    required this.controller,
    required this.label,
    required this.clearLabel,
    this.onChanged,
  });

  final SignatureController controller;
  final String label;
  final String clearLabel;
  final VoidCallback? onChanged;

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant SignaturePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
    widget.onChanged?.call();
  }

  Offset _normalized(Offset local, Size size) => Offset(
    size.width == 0 ? 0 : local.dx / size.width,
    size.height == 0 ? 0 : local.dy / size.height,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: widget.controller.isEmpty
                  ? null
                  : widget.controller.clear,
              icon: const Icon(Icons.delete_outline),
              label: Text(widget.clearLabel),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF8B99A6), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                key: const ValueKey('signature_pad'),
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) => widget.controller.start(
                  _normalized(details.localPosition, size),
                ),
                onPanUpdate: (details) => widget.controller.append(
                  _normalized(details.localPosition, size),
                ),
                child: CustomPaint(
                  painter: _SignaturePainter(widget.controller.strokes),
                  size: Size.infinite,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF17243A)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path()
        ..moveTo(stroke.first.dx * size.width, stroke.first.dy * size.height);
      if (stroke.length == 1) {
        path.lineTo(
          stroke.first.dx * size.width + 0.1,
          stroke.first.dy * size.height + 0.1,
        );
      } else {
        for (final point in stroke.skip(1)) {
          path.lineTo(point.dx * size.width, point.dy * size.height);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
