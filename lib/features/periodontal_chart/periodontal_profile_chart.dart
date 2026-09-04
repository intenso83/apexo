import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';

import 'periodontal_chart_model.dart';

/// Lightweight periodontal profile drawn directly with Flutter's canvas.
///
/// No charting package, images, or web view is used. The painter consumes the
/// same six-site measurements as the editor and repaints only when its parent
/// chart changes.
class PeriodontalProfileOverview extends StatelessWidget {
  const PeriodontalProfileOverview({
    super.key,
    required this.chart,
  });

  final PeriodontalChart chart;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.cardStrokeColorDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                FluentIcons.line_chart,
                size: 16,
                color: theme.accentColor,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  txt('periodontalProfileGraph'),
                  style: theme.typography.bodyStrong,
                ),
              ),
              Flexible(
                child: Text(
                  txt('periodontalProfileLegend'),
                  textAlign: TextAlign.end,
                  style: theme.typography.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          LayoutBuilder(
            builder: (context, constraints) {
              final upper = _ArchProfile(
                key: const ValueKey('periodontal-profile-upper'),
                title: txt('upperArch'),
                secondaryLabel: txt('periodontalPalatal'),
                teeth: upperPeriodontalTeeth,
                chart: chart,
              );
              final lower = _ArchProfile(
                key: const ValueKey('periodontal-profile-lower'),
                title: txt('lowerArch'),
                secondaryLabel: txt('periodontalLingual'),
                teeth: lowerPeriodontalTeeth,
                chart: chart,
              );
              if (constraints.maxWidth >= 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: upper),
                    const SizedBox(width: 12),
                    Expanded(child: lower),
                  ],
                );
              }
              return Column(
                children: [
                  upper,
                  const SizedBox(height: 12),
                  lower,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ArchProfile extends StatelessWidget {
  const _ArchProfile({
    super.key,
    required this.title,
    required this.secondaryLabel,
    required this.teeth,
    required this.chart,
  });

  final String title;
  final String secondaryLabel;
  final List<int> teeth;
  final PeriodontalChart chart;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    const buccalColor = Color(0xFF1769AA);
    const oralColor = Color(0xFF00897B);
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 7),
      decoration: BoxDecoration(
        color: theme.resources.solidBackgroundFillColorBase,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.resources.cardStrokeColorDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(title, style: theme.typography.caption),
              const Spacer(),
              _LineKey(
                color: buccalColor,
                label: txt('periodontalBuccal'),
              ),
              const SizedBox(width: 10),
              _LineKey(color: oralColor, label: secondaryLabel),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 142,
            child: CustomPaint(
              painter: _PeriodontalProfilePainter(
                chart: chart,
                teeth: teeth,
                gridColor: theme.resources.dividerStrokeColorDefault,
                labelColor: theme.resources.textFillColorSecondary,
                buccalColor: buccalColor,
                oralColor: oralColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineKey extends StatelessWidget {
  const _LineKey({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 15,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: FluentTheme.of(context).typography.caption),
      ],
    );
  }
}

class _PeriodontalProfilePainter extends CustomPainter {
  const _PeriodontalProfilePainter({
    required this.chart,
    required this.teeth,
    required this.gridColor,
    required this.labelColor,
    required this.buccalColor,
    required this.oralColor,
  });

  final PeriodontalChart chart;
  final List<int> teeth;
  final Color gridColor;
  final Color labelColor;
  final Color buccalColor;
  final Color oralColor;

  static const _maximumDepth = 15.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 60 || size.height <= 40) return;
    const left = 25.0;
    const right = 3.0;
    const top = 4.0;
    const bottom = 20.0;
    final plotWidth = size.width - left - right;
    final plotHeight = size.height - top - bottom;
    final toothWidth = plotWidth / teeth.length;

    for (var depth = 0; depth <= _maximumDepth; depth++) {
      final y = top + (depth / _maximumDepth) * plotHeight;
      final isMajor = depth % 3 == 0;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        Paint()
          ..color = gridColor.withAlpha(isMajor ? 145 : 65)
          ..strokeWidth = isMajor ? 0.8 : 0.45,
      );
      if (isMajor) {
        _paintText(
          canvas,
          '$depth',
          Offset(0, y - 6),
          TextStyle(fontSize: 9, color: labelColor),
        );
      }
    }

    for (var index = 0; index < teeth.length; index++) {
      final fdi = teeth[index];
      final x = left + index * toothWidth;
      final tooth = chart.tooth(fdi);
      if (tooth.missing) {
        canvas.drawRect(
          Rect.fromLTWH(x, top, toothWidth, plotHeight),
          Paint()..color = gridColor.withAlpha(45),
        );
      }
      canvas.drawLine(
        Offset(x, top),
        Offset(x, top + plotHeight),
        Paint()
          ..color = gridColor.withAlpha(index == 8 ? 170 : 70)
          ..strokeWidth = index == 8 ? 1.1 : 0.45,
      );
      final labelPainter = TextPainter(
        text: TextSpan(
          text: '$fdi',
          style: TextStyle(fontSize: 9, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset(
          x + (toothWidth - labelPainter.width) / 2,
          top + plotHeight + 4,
        ),
      );
    }
    canvas.drawLine(
      Offset(size.width - right, top),
      Offset(size.width - right, top + plotHeight),
      Paint()
        ..color = gridColor.withAlpha(70)
        ..strokeWidth = 0.45,
    );

    _paintProfile(
      canvas,
      left: left,
      top: top,
      plotWidth: plotWidth,
      plotHeight: plotHeight,
      sites: buccalPeriodontalSites,
      color: buccalColor,
    );
    _paintProfile(
      canvas,
      left: left,
      top: top,
      plotWidth: plotWidth,
      plotHeight: plotHeight,
      sites: lingualPeriodontalSites,
      color: oralColor,
    );
  }

  void _paintProfile(
    Canvas canvas, {
    required double left,
    required double top,
    required double plotWidth,
    required double plotHeight,
    required List<PeriodontalSite> sites,
    required Color color,
  }) {
    final pointCount = teeth.length * 3;
    final step = plotWidth / pointCount;
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    Path? activePath;

    for (var toothIndex = 0; toothIndex < teeth.length; toothIndex++) {
      final fdi = teeth[toothIndex];
      final tooth = chart.tooth(fdi);
      final visualSites = _visualSiteOrder(fdi, sites);
      for (var siteIndex = 0; siteIndex < visualSites.length; siteIndex++) {
        final measurement = tooth.measurement(visualSites[siteIndex]);
        final value = tooth.missing ? null : measurement.probingDepth;
        final sequenceIndex = toothIndex * 3 + siteIndex;
        final x = left + (sequenceIndex + 0.5) * step;
        if (value == null) {
          if (activePath != null) canvas.drawPath(activePath, stroke);
          activePath = null;
          continue;
        }
        final y = top + (value.clamp(0, 15) / _maximumDepth) * plotHeight;
        if (activePath == null) {
          activePath = Path()..moveTo(x, y);
        } else {
          activePath.lineTo(x, y);
        }

        final pointColor = value >= 6
            ? const Color(0xFFB3261E)
            : value >= 4
                ? const Color(0xFFD97706)
                : color;
        canvas.drawCircle(
          Offset(x, y),
          2.45,
          Paint()
            ..color = pointColor
            ..style = PaintingStyle.fill,
        );
        if (measurement.bleedingOnProbing) {
          canvas.drawCircle(
            Offset(x, y),
            4.25,
            Paint()
              ..color = const Color(0xFFD13438)
              ..strokeWidth = 1.25
              ..style = PaintingStyle.stroke,
          );
        }
      }
    }
    if (activePath != null) canvas.drawPath(activePath, stroke);
  }

  List<PeriodontalSite> _visualSiteOrder(
    int fdi,
    List<PeriodontalSite> sites,
  ) {
    final quadrant = fdi ~/ 10;
    return quadrant == 1 || quadrant == 4
        ? sites.reversed.toList(growable: false)
        : sites;
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _PeriodontalProfilePainter oldDelegate) => true;
}
