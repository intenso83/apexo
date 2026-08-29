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
  });

  final OdontogramOverlayKind kind;
  final OdontogramEventStatus status;
  final BridgeUnitRole? bridgeRole;
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

class OdontogramTreatmentOverlayPainter extends CustomPainter {
  const OdontogramTreatmentOverlayPainter({
    required this.marker,
    required this.asset,
  });

  final OdontogramOverlayMarker marker;
  final OdontogramAsset asset;

  @override
  void paint(Canvas canvas, Size size) {
    final color = odontogramStatusOverlayColor(marker.status);
    switch (marker.kind) {
      case OdontogramOverlayKind.none:
        return;
      case OdontogramOverlayKind.filling:
        _paintFilling(canvas, size, color);
        return;
      case OdontogramOverlayKind.crown:
        _paintCrown(canvas, size, color);
        return;
      case OdontogramOverlayKind.rootCanal:
        _paintRootCanal(canvas, size, color);
        return;
      case OdontogramOverlayKind.extraction:
        _paintExtraction(canvas, size, color);
        return;
      case OdontogramOverlayKind.implant:
        _paintImplant(canvas, size, color);
        return;
      case OdontogramOverlayKind.bridge:
        _paintBridge(canvas, size, color);
        return;
    }
  }

  void _paintFilling(Canvas canvas, Size size, Color color) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = asset.view == OdontogramView.occlusalIncisal
        ? size.shortestSide * 0.19
        : size.shortestSide * 0.13;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = color.withValues(alpha: 0.42),
    );
    canvas.drawCircle(
      center,
      radius,
      _stroke(color, size, 1.8),
    );
  }

  void _paintCrown(Canvas canvas, Size size, Color color) {
    final path = _crownPath(size);
    canvas.drawPath(path, _haloStroke(size, 4.6));
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.34)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(path, _stroke(color, size, 2.7));
    final y = asset.view == OdontogramView.facial
        ? (asset.jaw == OdontogramJaw.upper
            ? size.height * 0.62
            : size.height * 0.38)
        : size.height * 0.22;
    canvas.drawLine(
      Offset(size.width * 0.22, y),
      Offset(size.width * 0.78, y),
      _haloStroke(size, 3.6),
    );
    canvas.drawLine(
      Offset(size.width * 0.22, y),
      Offset(size.width * 0.78, y),
      _stroke(color, size, 1.7),
    );
  }

  void _paintRootCanal(Canvas canvas, Size size, Color color) {
    if (asset.view != OdontogramView.facial) {
      for (final center in _canalCenters(size)) {
        canvas.drawCircle(
          center,
          size.shortestSide * 0.085,
          Paint()..color = const Color(0xE6FFFFFF),
        );
        canvas.drawCircle(
          center,
          size.shortestSide * 0.052,
          Paint()..color = color,
        );
      }
      return;
    }

    final upper = asset.jaw == OdontogramJaw.upper;
    final chamberY = size.height * (upper ? 0.70 : 0.30);
    final rootY = size.height * (upper ? 0.12 : 0.88);
    final canalCount = switch (asset.toothType) {
      OdontogramToothType.incisor || OdontogramToothType.canine => 1,
      OdontogramToothType.premolar => 2,
      OdontogramToothType.molar => 3,
    };
    final spread = switch (canalCount) { 1 => 0.0, 2 => 0.14, _ => 0.21 };
    canvas.drawCircle(
      Offset(size.width * 0.5, chamberY),
      size.shortestSide * 0.12,
      Paint()..color = const Color(0xE6FFFFFF),
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, chamberY),
      size.shortestSide * 0.075,
      Paint()..color = color.withValues(alpha: 0.92),
    );
    for (var index = 0; index < canalCount; index++) {
      final fraction = canalCount == 1 ? 0.5 : index / (canalCount - 1);
      final endX = size.width * (0.5 - spread + (spread * 2 * fraction));
      final path = Path()
        ..moveTo(size.width * 0.5, chamberY)
        ..quadraticBezierTo(
          size.width * (0.5 + (fraction - 0.5) * 0.08),
          (chamberY + rootY) / 2,
          endX,
          rootY,
        );
      canvas.drawPath(path, _haloStroke(size, 4.1));
      canvas.drawPath(path, _stroke(color, size, 2.0));
    }
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

  void _paintExtraction(Canvas canvas, Size size, Color color) {
    final paint = _stroke(color, size, 3.6)..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.18, size.height * 0.16),
      Offset(size.width * 0.82, size.height * 0.84),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.82, size.height * 0.16),
      Offset(size.width * 0.18, size.height * 0.84),
      paint,
    );
  }

  void _paintImplant(Canvas canvas, Size size, Color color) {
    if (asset.view != OdontogramView.facial) {
      final center = Offset(size.width * 0.5, size.height * 0.5);
      final radius = size.shortestSide * 0.15;
      canvas.drawCircle(center, radius, _stroke(color, size, 2.2));
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
      canvas.drawPath(hexagon, _stroke(color, size, 1.4));
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
    canvas.drawPath(
      body,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(body, _stroke(color, size, 2));
    for (var index = 1; index <= 5; index++) {
      final y = top + ((bottom - top) * index / 6);
      final progress = (y - top) / (bottom - top);
      final width =
          halfWidth * (upper ? progress : 1 - progress).clamp(0.55, 1.0);
      canvas.drawLine(
        Offset(centerX - width, y),
        Offset(centerX + width, y),
        _stroke(color, size, 1.1),
      );
    }
    canvas.drawLine(
      Offset(centerX - size.width * 0.16, crownEdge),
      Offset(centerX + size.width * 0.16, crownEdge),
      _stroke(color, size, 2.8),
    );
  }

  void _paintBridge(Canvas canvas, Size size, Color color) {
    _paintCrown(canvas, size, color);
    final connectorY = asset.view == OdontogramView.facial
        ? (asset.jaw == OdontogramJaw.upper
            ? size.height * 0.78
            : size.height * 0.22)
        : size.height * 0.5;
    canvas.drawLine(
      Offset.zero.translate(0, connectorY),
      Offset(size.width, connectorY),
      _stroke(color, size, 3.2),
    );
    final center = Offset(size.width * 0.5, connectorY);
    switch (marker.bridgeRole) {
      case BridgeUnitRole.abutment:
        canvas.drawCircle(
          center,
          size.shortestSide * 0.075,
          Paint()..color = color,
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
        canvas.drawPath(pontic, _stroke(color, size, 2.3));
      case BridgeUnitRole.implantAbutment:
        canvas.drawCircle(
            center, size.shortestSide * 0.09, _stroke(color, size, 2));
        canvas.drawLine(
          center.translate(0, -size.height * 0.10),
          center.translate(0, size.height * 0.10),
          _stroke(color, size, 1.5),
        );
      case null:
        canvas.drawCircle(
            center, size.shortestSide * 0.06, Paint()..color = color);
    }
  }

  Path _crownPath(Size size) {
    if (asset.view != OdontogramView.facial) {
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
          size.width * 0.10, (top + bottom) / 2, size.width * 0.20, bottom)
      ..quadraticBezierTo(size.width * 0.50, bottom + (upper ? 2 : -2),
          size.width * 0.80, bottom)
      ..quadraticBezierTo(
          size.width * 0.90, (top + bottom) / 2, size.width * 0.84, top)
      ..quadraticBezierTo(
          size.width * 0.50, top + (upper ? -2 : 2), size.width * 0.16, top)
      ..close();
  }

  Paint _stroke(Color color, Size size, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width * (size.shortestSide / 48)
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  Paint _haloStroke(Size size, double width) => Paint()
    ..color = const Color(0xE6FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width * (size.shortestSide / 48)
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  @override
  bool shouldRepaint(covariant OdontogramTreatmentOverlayPainter oldDelegate) {
    return oldDelegate.marker.kind != marker.kind ||
        oldDelegate.marker.status != marker.status ||
        oldDelegate.marker.bridgeRole != marker.bridgeRole ||
        oldDelegate.asset.fdi != asset.fdi ||
        oldDelegate.asset.view != asset.view;
  }
}

Color odontogramStatusOverlayColor(OdontogramEventStatus status) =>
    switch (status) {
      OdontogramEventStatus.existing => const Color(0xFF7E57C2),
      OdontogramEventStatus.monitor => const Color(0xFFF59E0B),
      OdontogramEventStatus.planned => const Color(0xFF1976D2),
      OdontogramEventStatus.completed => const Color(0xFF00897B),
      OdontogramEventStatus.cancelled => const Color(0xFF757575),
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
