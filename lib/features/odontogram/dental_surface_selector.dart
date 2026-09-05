import 'dart:math' as math;

import 'package:apexo/features/odontogram/odontogram_assets.dart';
import 'package:fluent_ui/fluent_ui.dart';

typedef DentalSurfaceSelectionChanged = void Function(
  DentalSurface surface,
  bool selected,
);

typedef DentalSurfaceLabelBuilder = String Function(
  DentalSurface surface,
  int fdi,
);

/// A lightweight, DentalWin-style five-zone selector for tooth surfaces.
///
/// The horizontal zones follow the orientation used by the odontogram assets:
/// mesial is nearest the dental midline for the supplied [fdi]. The oral zone
/// is shown at the top, the facial/buccal zone at the bottom, and the centre is
/// labelled as incisal or occlusal according to tooth type.
class DentalSurfaceSelector extends StatelessWidget {
  DentalSurfaceSelector({
    Key? key,
    required this.fdi,
    required this.selectedSurfaces,
    this.onChanged,
    this.onSurfaceChanged,
    this.enabled = true,
    this.dimension = 132,
    this.surfaceLabelBuilder,
    this.selectedColor,
    this.unselectedColor,
    this.borderColor,
  })  : assert(dimension >= 80),
        assert(
          fdi ~/ 10 >= 1 && fdi ~/ 10 <= 4 && fdi % 10 >= 1 && fdi % 10 <= 8,
          'fdi must identify a supported permanent tooth',
        ),
        super(key: key ?? rootKey(fdi));

  /// Surfaces represented by this selector. Whole-tooth treatments use their
  /// own handling mode and are intentionally excluded.
  static const selectableSurfaces = <DentalSurface>{
    DentalSurface.mesial,
    DentalSurface.distal,
    DentalSurface.facial,
    DentalSurface.oral,
    DentalSurface.occlusalIncisal,
  };

  static ValueKey<String> rootKey(int fdi) =>
      ValueKey<String>('dental-surface-selector-$fdi');

  static ValueKey<String> surfaceKey(int fdi, DentalSurface surface) =>
      ValueKey<String>('dental-surface-selector-$fdi-${surface.name}');

  final int fdi;
  final Set<DentalSurface> selectedSurfaces;

  /// Called with the complete five-zone selection after a zone is toggled.
  final ValueChanged<Set<DentalSurface>>? onChanged;

  /// Called with the individual zone and its new state after a toggle.
  final DentalSurfaceSelectionChanged? onSurfaceChanged;

  final bool enabled;
  final double dimension;

  /// Overrides the full, adaptive label used by accessibility services.
  final DentalSurfaceLabelBuilder? surfaceLabelBuilder;

  final Color? selectedColor;
  final Color? unselectedColor;
  final Color? borderColor;

  bool get _canChange =>
      enabled && (onChanged != null || onSurfaceChanged != null);

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final mesialOnLeft = _mesialIsOnLeft(fdi);
    final selected = selectedSurfaces.intersection(selectableSurfaces);
    final effectiveSelectedColor =
        selectedColor ?? theme.accentColor.withValues(alpha: 0.30);
    final effectiveUnselectedColor = unselectedColor ?? theme.cardColor;
    final effectiveBorderColor =
        borderColor ?? theme.resources.surfaceStrokeColorDefault;
    final labelColor = _canChange
        ? theme.resources.textFillColorPrimary
        : theme.resources.textFillColorDisabled;

    final positions = <DentalSurface, Offset>{
      DentalSurface.oral: const Offset(0.50, 0.15),
      DentalSurface.facial: const Offset(0.50, 0.85),
      DentalSurface.occlusalIncisal: const Offset(0.50, 0.50),
      if (mesialOnLeft) ...{
        DentalSurface.mesial: const Offset(0.15, 0.50),
        DentalSurface.distal: const Offset(0.85, 0.50),
      } else ...{
        DentalSurface.distal: const Offset(0.15, 0.50),
        DentalSurface.mesial: const Offset(0.85, 0.50),
      },
    };

    final targetExtent = (dimension * 0.27).clamp(28.0, 44.0);
    return SizedBox.square(
      dimension: dimension,
      child: Opacity(
        opacity: _canChange ? 1 : 0.52,
        child: MouseRegion(
          cursor:
              _canChange ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _DentalSurfaceSelectorPainter(
                      fdi: fdi,
                      selectedSurfaces: selected,
                      selectedColor: effectiveSelectedColor,
                      unselectedColor: effectiveUnselectedColor,
                      borderColor: effectiveBorderColor,
                      labelColor: labelColor,
                      mesialOnLeft: mesialOnLeft,
                    ),
                  ),
                ),
              ),
              for (final surface in selectableSurfaces)
                Positioned.fill(
                  child: ClipPath(
                    clipper: _DentalSurfaceZoneClipper(
                      surface: surface,
                      mesialOnLeft: mesialOnLeft,
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTap: _canChange ? () => _toggle(surface) : null,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              for (final entry in positions.entries)
                Positioned(
                  left: (entry.value.dx * dimension) - targetExtent / 2,
                  top: (entry.value.dy * dimension) - targetExtent / 2,
                  width: targetExtent,
                  height: targetExtent,
                  child: Semantics(
                    key: surfaceKey(fdi, entry.key),
                    container: true,
                    button: true,
                    enabled: _canChange,
                    selected: selected.contains(entry.key),
                    label: _surfaceLabel(entry.key),
                    onTap: _canChange ? () => _toggle(entry.key) : null,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTap: _canChange ? () => _toggle(entry.key) : null,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _surfaceLabel(DentalSurface surface) =>
      surfaceLabelBuilder?.call(surface, fdi) ??
      OdontogramAssets.surfaceLabel(surface, fdi);

  void _toggle(DentalSurface surface) {
    final next = <DentalSurface>{
      ...selectedSurfaces.where(selectableSurfaces.contains),
    };
    final willSelect = !next.remove(surface);
    if (willSelect) next.add(surface);
    onSurfaceChanged?.call(surface, willSelect);
    onChanged?.call(Set<DentalSurface>.unmodifiable(next));
  }
}

bool _mesialIsOnLeft(int fdi) {
  final quadrant = fdi ~/ 10;
  return quadrant == 2 || quadrant == 3;
}

String _surfaceAbbreviation(DentalSurface surface, int fdi) {
  final position = fdi % 10;
  final isAnterior = position <= 3;
  final isUpper = fdi ~/ 10 <= 2;
  return switch (surface) {
    DentalSurface.mesial => 'M',
    DentalSurface.distal => 'D',
    DentalSurface.facial => isAnterior ? 'F' : 'B',
    DentalSurface.oral => isUpper ? 'P' : 'L',
    DentalSurface.occlusalIncisal => isAnterior ? 'I' : 'O',
    DentalSurface.wholeTooth => '',
  };
}

class _DentalSurfaceSelectorPainter extends CustomPainter {
  const _DentalSurfaceSelectorPainter({
    required this.fdi,
    required this.selectedSurfaces,
    required this.selectedColor,
    required this.unselectedColor,
    required this.borderColor,
    required this.labelColor,
    required this.mesialOnLeft,
  });

  final int fdi;
  final Set<DentalSurface> selectedSurfaces;
  final Color selectedColor;
  final Color unselectedColor;
  final Color borderColor;
  final Color labelColor;
  final bool mesialOnLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final paths = _paths(size, mesialOnLeft: mesialOnLeft);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, size.shortestSide / 88)
      ..color = borderColor;
    for (final entry in paths.entries) {
      final selected = selectedSurfaces.contains(entry.key);
      canvas.drawPath(
        entry.value,
        Paint()
          ..style = PaintingStyle.fill
          ..color = selected ? selectedColor : unselectedColor,
      );
      canvas.drawPath(entry.value, stroke);
    }

    final centres = <DentalSurface, Offset>{
      DentalSurface.oral: Offset(size.width * 0.50, size.height * 0.15),
      DentalSurface.facial: Offset(size.width * 0.50, size.height * 0.85),
      DentalSurface.occlusalIncisal:
          Offset(size.width * 0.50, size.height * 0.50),
      if (mesialOnLeft) ...{
        DentalSurface.mesial: Offset(size.width * 0.15, size.height * 0.50),
        DentalSurface.distal: Offset(size.width * 0.85, size.height * 0.50),
      } else ...{
        DentalSurface.distal: Offset(size.width * 0.15, size.height * 0.50),
        DentalSurface.mesial: Offset(size.width * 0.85, size.height * 0.50),
      },
    };
    for (final entry in centres.entries) {
      final painter = TextPainter(
        text: TextSpan(
          text: _surfaceAbbreviation(entry.key, fdi),
          style: TextStyle(
            color: labelColor,
            fontSize: math.max(11, size.shortestSide * 0.105),
            fontWeight: selectedSurfaces.contains(entry.key)
                ? FontWeight.bold
                : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        entry.value - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  static Map<DentalSurface, Path> _paths(
    Size size, {
    required bool mesialOnLeft,
  }) {
    final left = size.width * 0.30;
    final right = size.width * 0.70;
    final top = size.height * 0.30;
    final bottom = size.height * 0.70;
    final physicalLeft =
        mesialOnLeft ? DentalSurface.mesial : DentalSurface.distal;
    final physicalRight =
        mesialOnLeft ? DentalSurface.distal : DentalSurface.mesial;

    return {
      DentalSurface.oral: Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(right, top)
        ..lineTo(left, top)
        ..close(),
      physicalRight: Path()
        ..moveTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(right, bottom)
        ..lineTo(right, top)
        ..close(),
      DentalSurface.facial: Path()
        ..moveTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..lineTo(left, bottom)
        ..lineTo(right, bottom)
        ..close(),
      physicalLeft: Path()
        ..moveTo(0, size.height)
        ..lineTo(0, 0)
        ..lineTo(left, top)
        ..lineTo(left, bottom)
        ..close(),
      DentalSurface.occlusalIncisal: Path()
        ..addRect(Rect.fromLTRB(left, top, right, bottom)),
    };
  }

  @override
  bool shouldRepaint(covariant _DentalSurfaceSelectorPainter oldDelegate) =>
      oldDelegate.fdi != fdi ||
      oldDelegate.mesialOnLeft != mesialOnLeft ||
      !_sameSurfaces(oldDelegate.selectedSurfaces, selectedSurfaces) ||
      oldDelegate.selectedColor != selectedColor ||
      oldDelegate.unselectedColor != unselectedColor ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.labelColor != labelColor;
}

class _DentalSurfaceZoneClipper extends CustomClipper<Path> {
  const _DentalSurfaceZoneClipper({
    required this.surface,
    required this.mesialOnLeft,
  });

  final DentalSurface surface;
  final bool mesialOnLeft;

  @override
  Path getClip(Size size) => _DentalSurfaceSelectorPainter._paths(
        size,
        mesialOnLeft: mesialOnLeft,
      )[surface]!;

  @override
  bool shouldReclip(covariant _DentalSurfaceZoneClipper oldClipper) =>
      oldClipper.surface != surface || oldClipper.mesialOnLeft != mesialOnLeft;
}

bool _sameSurfaces(Set<DentalSurface> first, Set<DentalSurface> second) =>
    first.length == second.length && first.containsAll(second);
