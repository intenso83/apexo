import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'odontogram_assets.dart';
import 'odontogram_event_model.dart';
import 'odontogram_overlay_model.dart';
import 'treatment_target.dart';

class OdontogramOverlayMarker {
  const OdontogramOverlayMarker({
    required this.kind,
    required this.status,
    this.bridgeRole,
    this.surfaces = const {},
    this.procedureName = '',
  });

  final OdontogramOverlayKind kind;
  final OdontogramEventStatus status;
  final BridgeUnitRole? bridgeRole;
  final Set<DentalSurface> surfaces;
  final String procedureName;
}

/// Returns at most one current marker of each kind for a tooth.
///
/// Events arrive newest-first from the store, so the first non-cancelled event
/// wins for each visual kind. A treatment without an explicit tooth mapping is
/// intentionally kept in history but is not painted here.
List<OdontogramOverlayMarker> odontogramOverlayMarkersForTooth(
  Iterable<OdontogramEvent> events,
  int fdi,
) {
  final seen = <OdontogramOverlayKind>{};
  final result = <OdontogramOverlayMarker>[];
  for (final event in events) {
    if (event.status == OdontogramEventStatus.cancelled ||
        !event.drawsOnTooth(fdi)) {
      continue;
    }
    final kind = event.effectiveOverlayKind;
    if (kind == OdontogramOverlayKind.none || !seen.add(kind)) continue;
    result.add(
      OdontogramOverlayMarker(
        kind: kind,
        status: event.status,
        surfaces: event.surfaces
            .map(_surfaceByName)
            .whereType<DentalSurface>()
            .toSet(),
        procedureName: event.procedureNameSnapshot,
        bridgeRole: event.bridgeUnits
            .where((unit) => unit.toothFdi == fdi)
            .firstOrNull
            ?.role,
      ),
    );
  }
  result
      .sort((a, b) => _paintPriority(a.kind).compareTo(_paintPriority(b.kind)));
  return List.unmodifiable(result);
}

DentalSurface? _surfaceByName(String value) =>
    DentalSurface.values.where((surface) => surface.name == value).firstOrNull;

bool odontogramOverlayVisibleInView(
  OdontogramOverlayKind kind,
  OdontogramView view,
) =>
    view != OdontogramView.oral ||
    kind == OdontogramOverlayKind.crown ||
    kind == OdontogramOverlayKind.filling ||
    kind == OdontogramOverlayKind.extraction;

/// Paints a treatment as a material layer that follows the supplied tooth art.
///
/// Crowns and bridge units reuse the source image as an alpha mask, so enamel
/// highlights remain visible through the clinical colour rather than being
/// covered by a flat icon. The vector painter adds the fine clinical marks.
class OdontogramTreatmentOverlayLayer extends StatelessWidget {
  const OdontogramTreatmentOverlayLayer({
    super.key,
    required this.marker,
    required this.asset,
  });

  final OdontogramOverlayMarker marker;
  final OdontogramAsset asset;

  @override
  Widget build(BuildContext context) {
    if (!odontogramOverlayVisibleInView(marker.kind, asset.view)) {
      return const SizedBox.shrink();
    }
    final material = switch (marker.kind) {
      OdontogramOverlayKind.crown ||
      OdontogramOverlayKind.bridge =>
        _CrownMaterialImage(marker: marker, asset: asset),
      OdontogramOverlayKind.filling =>
        _FillingMaterialImage(marker: marker, asset: asset),
      _ => null,
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        if (material != null) material,
        CustomPaint(
          painter: OdontogramTreatmentOverlayPainter(
            marker: marker,
            asset: asset,
          ),
        ),
      ],
    );
  }
}

class _CrownMaterialImage extends StatelessWidget {
  const _CrownMaterialImage({required this.marker, required this.asset});

  final OdontogramOverlayMarker marker;
  final OdontogramAsset asset;

  @override
  Widget build(BuildContext context) {
    final color = odontogramTreatmentMaterialColor(
      marker.kind,
      procedureName: marker.procedureName,
    );
    Widget image = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(color, const Color(0xFFFFFFFF), 0.48)!,
          color,
          Color.lerp(color, const Color(0xFF8B713E), 0.10)!,
          Color.lerp(color, const Color(0xFFFFFFFF), 0.36)!,
        ],
        stops: const [0, 0.34, 0.72, 1],
      ).createShader(bounds),
      child: Image.asset(
        asset.assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      ),
    );
    if (asset.flipHorizontally) {
      image = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: image,
      );
    }
    return Opacity(
      opacity: _materialOpacity(marker.status),
      child: ClipRect(
        clipper: _ClinicalCrownClipper(asset),
        child: image,
      ),
    );
  }
}

class _ClinicalCrownClipper extends CustomClipper<Rect> {
  const _ClinicalCrownClipper(this.asset);

  final OdontogramAsset asset;

  @override
  Rect getClip(Size size) {
    if (asset.view == OdontogramView.occlusalIncisal ||
        asset.view == OdontogramView.oral) {
      return Offset.zero & size;
    }
    return asset.jaw == OdontogramJaw.upper
        ? Rect.fromLTRB(0, size.height * 0.53, size.width, size.height)
        : Rect.fromLTRB(0, 0, size.width, size.height * 0.47);
  }

  @override
  bool shouldReclip(covariant _ClinicalCrownClipper oldClipper) =>
      oldClipper.asset.fdi != asset.fdi || oldClipper.asset.view != asset.view;
}

class _FillingMaterialImage extends StatelessWidget {
  const _FillingMaterialImage({required this.marker, required this.asset});

  final OdontogramOverlayMarker marker;
  final OdontogramAsset asset;

  @override
  Widget build(BuildContext context) {
    final color = odontogramTreatmentMaterialColor(marker.kind);
    Widget image = ShaderMask(
      blendMode: BlendMode.modulate,
      shaderCallback: (bounds) => RadialGradient(
        center: const Alignment(-0.35, -0.40),
        radius: 1.15,
        colors: [
          Color.lerp(color, const Color(0xFFFFFFFF), 0.42)!,
          color,
          Color.lerp(color, const Color(0xFF18324A), 0.22)!,
        ],
      ).createShader(bounds),
      child: Image.asset(
        asset.assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      ),
    );
    if (asset.flipHorizontally) {
      image = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: image,
      );
    }
    return Opacity(
      opacity: math.min(1, _materialOpacity(marker.status) + 0.12),
      child: ClipPath(
        clipper: _FillingSurfaceClipper(marker: marker, asset: asset),
        child: image,
      ),
    );
  }
}

class _FillingSurfaceClipper extends CustomClipper<Path> {
  const _FillingSurfaceClipper({required this.marker, required this.asset});

  final OdontogramOverlayMarker marker;
  final OdontogramAsset asset;

  @override
  Path getClip(Size size) => OdontogramTreatmentOverlayPainter(
        marker: marker,
        asset: asset,
      )._combinedFillingPath(size);

  @override
  bool shouldReclip(covariant _FillingSurfaceClipper oldClipper) =>
      oldClipper.asset.fdi != asset.fdi ||
      oldClipper.asset.view != asset.view ||
      !_sameSurfaces(oldClipper.marker.surfaces, marker.surfaces);
}

class OdontogramTreatmentOverlayPainter extends CustomPainter {
  const OdontogramTreatmentOverlayPainter({
    required this.marker,
    required this.asset,
  });

  final OdontogramOverlayMarker marker;
  final OdontogramAsset asset;

  @override
  void paint(Canvas canvas, Size size) {
    final statusColor = odontogramStatusOverlayColor(marker.status);
    final baseMaterialColor = odontogramTreatmentMaterialColor(
      marker.kind,
      procedureName: marker.procedureName,
    );
    final materialColor = marker.status == OdontogramEventStatus.planned
        ? Color.lerp(
            baseMaterialColor,
            const Color(0xFF90CAF9),
            0.58,
          )!
            .withValues(alpha: 0.74)
        : baseMaterialColor;
    switch (marker.kind) {
      case OdontogramOverlayKind.none:
        return;
      case OdontogramOverlayKind.filling:
        _paintPlannedOutline(canvas, _combinedFillingPath(size), size);
        return;
      case OdontogramOverlayKind.crown:
        _paintPlannedOutline(canvas, odontogramCrownPath(asset, size), size);
        return;
      case OdontogramOverlayKind.rootCanal:
        _paintRootCanal(canvas, size, statusColor, materialColor);
        return;
      case OdontogramOverlayKind.extraction:
        _paintExtraction(canvas, size, statusColor, materialColor);
        return;
      case OdontogramOverlayKind.implant:
        _paintImplant(canvas, size, statusColor, materialColor);
        return;
      case OdontogramOverlayKind.bridge:
        _paintBridge(canvas, size, statusColor, materialColor);
        return;
    }
  }

  void _paintPlannedOutline(Canvas canvas, Path path, Size size) {
    if (marker.status != OdontogramEventStatus.planned ||
        path.getBounds().isEmpty) {
      return;
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.15, size.shortestSide * 0.055)
        ..color =
            odontogramStatusOverlayColor(marker.status).withValues(alpha: 0.92),
    );
  }

  Path _combinedFillingPath(Size size) {
    final requested = marker.surfaces.isEmpty
        ? const {DentalSurface.occlusalIncisal}
        : marker.surfaces;
    Path? combined;
    for (final surface in requested) {
      final path = _fillingPathForSurface(surface, size);
      if (path.getBounds().isEmpty) continue;
      combined = combined == null
          ? path
          : Path.combine(PathOperation.union, combined, path);
    }
    return combined ?? Path();
  }

  Path _fillingPathForSurface(DentalSurface surface, Size size) {
    if (surface == DentalSurface.wholeTooth) {
      return odontogramCrownPath(asset, size);
    }
    final mesialOnLeft = asset.flipHorizontally;
    if (asset.view == OdontogramView.occlusalIncisal) {
      final center = Offset(size.width * 0.5, size.height * 0.5);
      final rect = switch (surface) {
        DentalSurface.mesial => Rect.fromCenter(
            center: Offset(
              size.width * (mesialOnLeft ? 0.37 : 0.63),
              center.dy,
            ),
            width: size.width * 0.22,
            height: size.height * 0.32,
          ),
        DentalSurface.distal => Rect.fromCenter(
            center: Offset(
              size.width * (mesialOnLeft ? 0.63 : 0.37),
              center.dy,
            ),
            width: size.width * 0.22,
            height: size.height * 0.32,
          ),
        DentalSurface.facial => Rect.fromCenter(
            center: Offset(center.dx, size.height * 0.36),
            width: size.width * 0.43,
            height: size.height * 0.18,
          ),
        DentalSurface.oral => Rect.fromCenter(
            center: Offset(center.dx, size.height * 0.64),
            width: size.width * 0.43,
            height: size.height * 0.18,
          ),
        DentalSurface.occlusalIncisal => Rect.fromCenter(
            center: center,
            width: size.width *
                (asset.toothType == OdontogramToothType.molar ? 0.30 : 0.25),
            height: size.height *
                (asset.toothType == OdontogramToothType.molar ? 0.23 : 0.20),
          ),
        DentalSurface.wholeTooth => Rect.zero,
      };
      return _organicFillingBlob(rect);
    }

    if ((surface == DentalSurface.facial &&
            asset.view != OdontogramView.facial) ||
        (surface == DentalSurface.oral && asset.view != OdontogramView.oral)) {
      return Path();
    }
    final upper = asset.jaw == OdontogramJaw.upper;
    final crownCenterY = size.height * (upper ? 0.75 : 0.25);
    final sideX = switch (surface) {
      DentalSurface.mesial => size.width * (mesialOnLeft ? 0.31 : 0.69),
      DentalSurface.distal => size.width * (mesialOnLeft ? 0.69 : 0.31),
      _ => size.width * 0.5,
    };
    final rect = switch (surface) {
      DentalSurface.mesial || DentalSurface.distal => Rect.fromCenter(
          center: Offset(sideX, crownCenterY),
          width: size.width * 0.15,
          height: size.height * 0.21,
        ),
      DentalSurface.facial || DentalSurface.oral => Rect.fromCenter(
          center: Offset(size.width * 0.5, crownCenterY),
          width: size.width * 0.36,
          height: size.height * 0.20,
        ),
      DentalSurface.occlusalIncisal => Rect.fromCenter(
          center: Offset(
            size.width * 0.5,
            size.height * (upper ? 0.84 : 0.16),
          ),
          width: size.width * 0.38,
          height: size.height * 0.10,
        ),
      DentalSurface.wholeTooth => Rect.zero,
    };
    return _organicFillingBlob(rect);
  }

  Path _organicFillingBlob(Rect rect) {
    if (rect.isEmpty) return Path();
    Offset point(double x, double y) =>
        Offset(rect.left + rect.width * x, rect.top + rect.height * y);
    return Path()
      ..moveTo(point(0.08, 0.48).dx, point(0.08, 0.48).dy)
      ..cubicTo(
        point(0.10, 0.18).dx,
        point(0.10, 0.18).dy,
        point(0.36, 0.04).dx,
        point(0.36, 0.04).dy,
        point(0.55, 0.10).dx,
        point(0.55, 0.10).dy,
      )
      ..cubicTo(
        point(0.82, 0.04).dx,
        point(0.82, 0.04).dy,
        point(0.96, 0.30).dx,
        point(0.96, 0.30).dy,
        point(0.89, 0.54).dx,
        point(0.89, 0.54).dy,
      )
      ..cubicTo(
        point(0.95, 0.79).dx,
        point(0.95, 0.79).dy,
        point(0.68, 0.98).dx,
        point(0.68, 0.98).dy,
        point(0.47, 0.90).dx,
        point(0.47, 0.90).dy,
      )
      ..cubicTo(
        point(0.21, 0.98).dx,
        point(0.21, 0.98).dy,
        point(0.02, 0.75).dx,
        point(0.02, 0.75).dy,
        point(0.08, 0.48).dx,
        point(0.08, 0.48).dy,
      )
      ..close();
  }

  void _paintRootCanal(
    Canvas canvas,
    Size size,
    Color statusColor,
    Color materialColor,
  ) {
    if (asset.view == OdontogramView.occlusalIncisal) {
      final chamber = Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.5),
        width: size.width *
            (asset.toothType == OdontogramToothType.molar ? 0.32 : 0.25),
        height: size.height *
            (asset.toothType == OdontogramToothType.molar ? 0.27 : 0.22),
      );
      canvas.drawOval(
        chamber,
        Paint()..color = materialColor.withValues(alpha: 0.20),
      );
      canvas.drawOval(
        chamber,
        _stroke(statusColor.withValues(alpha: 0.70), size, 0.9),
      );
      for (final center in _canalCenters(size)) {
        canvas.drawCircle(
          center,
          size.shortestSide * 0.070,
          Paint()..color = const Color(0xD9FFFFFF),
        );
        canvas.drawCircle(
          center,
          size.shortestSide * 0.043,
          Paint()..color = materialColor,
        );
      }
      return;
    }

    final upper = asset.jaw == OdontogramJaw.upper;
    final chamberY = size.height * (upper ? 0.70 : 0.30);
    final routes = _canalRoutes();
    final chamber = Rect.fromCenter(
      center: Offset(size.width * 0.5, chamberY),
      width: size.width * (routes.length == 1 ? 0.10 : 0.18),
      height: size.height * 0.065,
    );
    canvas.drawOval(
      chamber.inflate(size.shortestSide * 0.020),
      Paint()..color = const Color(0xCFFFFFFF),
    );
    canvas.drawOval(
      chamber,
      Paint()..color = materialColor.withValues(alpha: 0.92),
    );
    canvas.drawOval(
      chamber,
      _stroke(statusColor.withValues(alpha: 0.68), size, 0.65),
    );
    for (final route in routes) {
      final apexY = size.height * route.apexY;
      final path = Path()
        ..moveTo(size.width * route.chamberX, chamberY)
        ..cubicTo(
          size.width * route.controlX,
          chamberY + (apexY - chamberY) * 0.34,
          size.width * route.controlX,
          chamberY + (apexY - chamberY) * 0.72,
          size.width * route.apexX,
          apexY,
        );
      canvas.drawPath(path, _stroke(const Color(0xCFFFFFFF), size, 2.35));
      canvas.drawPath(path, _stroke(materialColor, size, 1.10));
      canvas.drawPath(
        path,
        _stroke(
          Color.lerp(materialColor, const Color(0xFFFFFFFF), 0.48)!
              .withValues(alpha: 0.62),
          size,
          0.30,
        ),
      );
      canvas.drawCircle(
        Offset(size.width * route.apexX, apexY),
        size.shortestSide * 0.018,
        Paint()..color = materialColor,
      );
    }
  }

  List<
      ({
        double chamberX,
        double controlX,
        double apexX,
        double apexY,
      })> _canalRoutes() {
    final toothPosition = asset.fdi % 10;
    final upper = asset.jaw == OdontogramJaw.upper;
    double orient(double x) => asset.flipHorizontally ? 1 - x : x;
    List<
        ({
          double chamberX,
          double controlX,
          double apexX,
          double apexY,
        })> single(double apexX, double apexY) => [
          (
            chamberX: 0.50,
            controlX: (0.50 + apexX) / 2,
            apexX: apexX,
            apexY: apexY,
          ),
        ];
    final routes = switch (asset.toothType) {
      OdontogramToothType.incisor => single(
          upper
              ? (toothPosition == 1 ? 0.44 : 0.46)
              : (toothPosition == 1 ? 0.48 : 0.49),
          upper ? 0.08 : 0.92,
        ),
      OdontogramToothType.canine => single(
          upper ? 0.50 : 0.51,
          upper ? 0.08 : 0.92,
        ),
      OdontogramToothType.premolar => single(
          upper
              ? (toothPosition == 4 ? 0.45 : 0.37)
              : (toothPosition == 4 ? 0.52 : 0.54),
          upper ? 0.08 : 0.92,
        ),
      OdontogramToothType.molar => upper
          ? switch (toothPosition) {
              6 => const [
                  (
                    chamberX: 0.47,
                    controlX: 0.45,
                    apexX: 0.44,
                    apexY: 0.08,
                  ),
                  (
                    chamberX: 0.53,
                    controlX: 0.54,
                    apexX: 0.54,
                    apexY: 0.16,
                  ),
                ],
              7 => const [
                  (
                    chamberX: 0.47,
                    controlX: 0.41,
                    apexX: 0.38,
                    apexY: 0.08,
                  ),
                  (
                    chamberX: 0.53,
                    controlX: 0.49,
                    apexX: 0.47,
                    apexY: 0.14,
                  ),
                ],
              _ => single(0.35, 0.08),
            }
          : switch (toothPosition) {
              6 => const [
                  (
                    chamberX: 0.47,
                    controlX: 0.40,
                    apexX: 0.36,
                    apexY: 0.89,
                  ),
                  (
                    chamberX: 0.53,
                    controlX: 0.56,
                    apexX: 0.54,
                    apexY: 0.93,
                  ),
                ],
              7 => const [
                  (
                    chamberX: 0.47,
                    controlX: 0.38,
                    apexX: 0.33,
                    apexY: 0.87,
                  ),
                  (
                    chamberX: 0.53,
                    controlX: 0.48,
                    apexX: 0.46,
                    apexY: 0.93,
                  ),
                ],
              _ => single(0.49, 0.93),
            },
    };
    return [
      for (final route in routes)
        (
          chamberX: orient(route.chamberX),
          controlX: orient(route.controlX),
          apexX: orient(route.apexX),
          apexY: route.apexY,
        ),
    ];
  }

  List<Offset> _canalCenters(Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final horizontal = size.width * 0.105;
    final vertical = size.height * 0.085;
    return switch (asset.toothType) {
      OdontogramToothType.incisor || OdontogramToothType.canine => [center],
      OdontogramToothType.premolar => [
          center.translate(-horizontal, 0),
          center.translate(horizontal, 0),
        ],
      OdontogramToothType.molar => [
          center.translate(-horizontal, vertical),
          center.translate(horizontal, vertical),
          center.translate(0, -vertical),
        ],
    };
  }

  void _paintExtraction(
    Canvas canvas,
    Size size,
    Color statusColor,
    Color materialColor,
  ) {
    final halo = _stroke(const Color(0xE6FFFFFF), size, 5.0)
      ..strokeCap = StrokeCap.round;
    final paint = _stroke(materialColor.withValues(alpha: 0.94), size, 2.9)
      ..strokeCap = StrokeCap.round;
    final firstStart = Offset(size.width * 0.22, size.height * 0.18);
    final firstEnd = Offset(size.width * 0.78, size.height * 0.82);
    final secondStart = Offset(size.width * 0.78, size.height * 0.18);
    final secondEnd = Offset(size.width * 0.22, size.height * 0.82);
    canvas.drawLine(firstStart, firstEnd, halo);
    canvas.drawLine(secondStart, secondEnd, halo);
    canvas.drawLine(firstStart, firstEnd, paint);
    canvas.drawLine(secondStart, secondEnd, paint);
    canvas.drawLine(
      Offset(size.width * 0.36, size.height * 0.50),
      Offset(size.width * 0.64, size.height * 0.50),
      _stroke(statusColor.withValues(alpha: 0.82), size, 1.0),
    );
  }

  void _paintImplant(
    Canvas canvas,
    Size size,
    Color statusColor,
    Color materialColor,
  ) {
    if (asset.view == OdontogramView.occlusalIncisal) {
      final center = Offset(size.width * 0.5, size.height * 0.5);
      final radius = size.shortestSide * 0.135;
      canvas.drawCircle(
        center,
        radius * 1.22,
        Paint()..color = const Color(0xCFFFFFFF),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            colors: [
              Color.lerp(materialColor, const Color(0xFFFFFFFF), 0.55)!,
              materialColor,
              Color.lerp(materialColor, const Color(0xFF1E3442), 0.45)!,
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
      canvas.drawCircle(
        center,
        radius,
        _stroke(statusColor.withValues(alpha: 0.86), size, 1.15),
      );
      final hexagon = Path();
      for (var index = 0; index < 6; index++) {
        final angle = (math.pi / 3 * index) - math.pi / 2;
        final point =
            center + Offset(math.cos(angle), math.sin(angle)) * radius;
        if (index == 0) {
          hexagon.moveTo(point.dx, point.dy);
        } else {
          hexagon.lineTo(point.dx, point.dy);
        }
      }
      hexagon.close();
      canvas.drawPath(
        hexagon,
        _stroke(const Color(0xD9FFFFFF), size, 1.0),
      );
      return;
    }

    final upper = asset.jaw == OdontogramJaw.upper;
    final crownEdge = size.height * (upper ? 0.56 : 0.44);
    final rootEnd = size.height * (upper ? 0.10 : 0.90);
    final top = math.min(crownEdge, rootEnd);
    final bottom = math.max(crownEdge, rootEnd);
    final centerX = size.width * 0.5;
    final halfWidth = size.width * 0.11;
    final body = Path()
      ..moveTo(centerX - halfWidth, crownEdge)
      ..lineTo(centerX - halfWidth * 0.55, rootEnd)
      ..lineTo(centerX + halfWidth * 0.55, rootEnd)
      ..lineTo(centerX + halfWidth, crownEdge)
      ..close();
    canvas.drawPath(body, _stroke(const Color(0xD9FFFFFF), size, 4.4));
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Color.lerp(materialColor, const Color(0xFF233A4A), 0.38)!,
            Color.lerp(materialColor, const Color(0xFFFFFFFF), 0.58)!,
            materialColor,
            Color.lerp(materialColor, const Color(0xFF1D3341), 0.42)!,
          ],
          stops: const [0, 0.34, 0.64, 1],
        ).createShader(Rect.fromLTRB(
          centerX - halfWidth,
          top,
          centerX + halfWidth,
          bottom,
        )),
    );
    canvas.drawPath(
      body,
      _stroke(statusColor.withValues(alpha: 0.88), size, 1.25),
    );
    for (var index = 1; index <= 5; index++) {
      final y = top + ((bottom - top) * index / 6);
      final progress = (y - top) / (bottom - top);
      final width =
          halfWidth * (upper ? progress : 1 - progress).clamp(0.55, 1.0);
      canvas.drawLine(
        Offset(centerX - width, y),
        Offset(centerX + width, y),
        _stroke(const Color(0xCFEAF3F8), size, 0.82),
      );
    }
    final neck = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, crownEdge),
        width: size.width * 0.24,
        height: size.height * 0.075,
      ),
      Radius.circular(size.shortestSide * 0.035),
    );
    canvas.drawRRect(neck, Paint()..color = const Color(0xFFF0F5F7));
    canvas.drawRRect(
      neck,
      _stroke(statusColor.withValues(alpha: 0.80), size, 1.0),
    );
    canvas.drawLine(
      Offset(centerX - size.width * 0.16, crownEdge),
      Offset(centerX + size.width * 0.16, crownEdge),
      _stroke(materialColor, size, 1.8),
    );
  }

  void _paintBridge(
    Canvas canvas,
    Size size,
    Color statusColor,
    Color materialColor,
  ) {
    final connectorY = asset.view == OdontogramView.facial
        ? (asset.jaw == OdontogramJaw.upper
            ? size.height * 0.78
            : size.height * 0.22)
        : size.height * 0.5;
    canvas.drawLine(
      Offset.zero.translate(0, connectorY),
      Offset(size.width, connectorY),
      _stroke(const Color(0xCFFFFFFF), size, 4.5),
    );
    canvas.drawLine(
      Offset.zero.translate(0, connectorY),
      Offset(size.width, connectorY),
      _stroke(materialColor, size, 2.4),
    );
    final center = Offset(size.width * 0.5, connectorY);
    switch (marker.bridgeRole) {
      case BridgeUnitRole.abutment:
        canvas.drawCircle(
          center,
          size.shortestSide * 0.075,
          Paint()..color = statusColor,
        );
      case BridgeUnitRole.pontic:
        final pontic = Path()
          ..moveTo(center.dx - size.width * 0.10, center.dy)
          ..quadraticBezierTo(
            center.dx,
            center.dy + (asset.jaw == OdontogramJaw.upper ? -6 : 6),
            center.dx + size.width * 0.10,
            center.dy,
          );
        canvas.drawPath(pontic, _stroke(statusColor, size, 1.8));
      case BridgeUnitRole.implantAbutment:
        canvas.drawCircle(
            center, size.shortestSide * 0.09, _stroke(statusColor, size, 1.6));
        canvas.drawLine(
          center.translate(0, -size.height * 0.10),
          center.translate(0, size.height * 0.10),
          _stroke(statusColor, size, 1.2),
        );
      case null:
        canvas.drawCircle(
            center, size.shortestSide * 0.06, Paint()..color = statusColor);
    }
  }

  Paint _stroke(Color color, Size size, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width * (size.shortestSide / 48)
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  @override
  bool shouldRepaint(covariant OdontogramTreatmentOverlayPainter oldDelegate) {
    return oldDelegate.marker.kind != marker.kind ||
        oldDelegate.marker.status != marker.status ||
        oldDelegate.marker.bridgeRole != marker.bridgeRole ||
        oldDelegate.marker.procedureName != marker.procedureName ||
        !_sameSurfaces(oldDelegate.marker.surfaces, marker.surfaces) ||
        oldDelegate.asset.fdi != asset.fdi ||
        oldDelegate.asset.view != asset.view;
  }
}

Path odontogramCrownPath(OdontogramAsset asset, Size size) {
  if (asset.view == OdontogramView.occlusalIncisal) {
    final rect = switch (asset.toothType) {
      OdontogramToothType.molar => Rect.fromLTWH(
          size.width * 0.08,
          size.height * 0.08,
          size.width * 0.84,
          size.height * 0.84,
        ),
      OdontogramToothType.premolar => Rect.fromLTWH(
          size.width * 0.16,
          size.height * 0.08,
          size.width * 0.68,
          size.height * 0.84,
        ),
      OdontogramToothType.incisor ||
      OdontogramToothType.canine =>
        Rect.fromLTWH(
          size.width * 0.20,
          size.height * 0.08,
          size.width * 0.60,
          size.height * 0.84,
        ),
    };
    return Path()..addOval(rect);
  }
  final upper = asset.jaw == OdontogramJaw.upper;
  final top = size.height * (upper ? 0.54 : 0.08);
  final bottom = size.height * (upper ? 0.92 : 0.46);
  return Path()
    ..moveTo(size.width * 0.16, top)
    ..quadraticBezierTo(
      size.width * 0.10,
      (top + bottom) / 2,
      size.width * 0.20,
      bottom,
    )
    ..quadraticBezierTo(
      size.width * 0.50,
      bottom + (upper ? 2 : -2),
      size.width * 0.80,
      bottom,
    )
    ..quadraticBezierTo(
      size.width * 0.90,
      (top + bottom) / 2,
      size.width * 0.84,
      top,
    )
    ..quadraticBezierTo(
      size.width * 0.50,
      top + (upper ? -2 : 2),
      size.width * 0.16,
      top,
    )
    ..close();
}

bool _sameSurfaces(Set<DentalSurface> first, Set<DentalSurface> second) =>
    first.length == second.length && first.containsAll(second);

Color odontogramStatusOverlayColor(OdontogramEventStatus status) =>
    switch (status) {
      OdontogramEventStatus.existing => const Color(0xFF7E57C2),
      OdontogramEventStatus.monitor => const Color(0xFFF59E0B),
      OdontogramEventStatus.planned => const Color(0xFF1976D2),
      OdontogramEventStatus.completed => const Color(0xFF00897B),
      OdontogramEventStatus.cancelled => const Color(0xFF757575),
    };

Color odontogramTreatmentMaterialColor(
  OdontogramOverlayKind kind, {
  String procedureName = '',
}) {
  final procedure = procedureName.toLowerCase();
  return switch (kind) {
    OdontogramOverlayKind.none => const Color(0x00000000),
    OdontogramOverlayKind.filling => const Color(0xFF438DCC),
    OdontogramOverlayKind.crown ||
    OdontogramOverlayKind.bridge =>
      procedure.contains('gold') || procedure.contains('χρυσ')
          ? const Color(0xFFD5A33E)
          : procedure.contains('zircon') ||
                  procedure.contains('ζιρκον') ||
                  procedure.contains('ceram') ||
                  procedure.contains('κεραμ') ||
                  procedure.contains('porcelain') ||
                  procedure.contains('πορσελ')
              ? const Color(0xFFE1BF82)
              : const Color(0xFFC99A4B),
    OdontogramOverlayKind.rootCanal => const Color(0xFF149C88),
    OdontogramOverlayKind.extraction => const Color(0xFFE05252),
    OdontogramOverlayKind.implant => const Color(0xFF688CA4),
  };
}

double _materialOpacity(OdontogramEventStatus status) => switch (status) {
      OdontogramEventStatus.existing => 0.62,
      OdontogramEventStatus.monitor => 0.46,
      OdontogramEventStatus.planned => 0.40,
      OdontogramEventStatus.completed => 0.76,
      OdontogramEventStatus.cancelled => 0.25,
    };

int _paintPriority(OdontogramOverlayKind kind) => switch (kind) {
      OdontogramOverlayKind.none => 0,
      OdontogramOverlayKind.filling => 10,
      OdontogramOverlayKind.crown => 20,
      OdontogramOverlayKind.rootCanal => 30,
      OdontogramOverlayKind.implant => 40,
      OdontogramOverlayKind.bridge => 50,
      OdontogramOverlayKind.extraction => 100,
    };
