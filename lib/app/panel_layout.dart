const double compactPanelWidth = 350;
const double desktopPanelBreakpoint = 710;

double sidePanelWidthForLayout({
  required double layoutWidth,
  required bool minimized,
  double? desktopWidthFraction,
}) {
  if (layoutWidth < 490 && minimized) return layoutWidth;
  if (layoutWidth < desktopPanelBreakpoint || desktopWidthFraction == null) {
    return compactPanelWidth;
  }

  final maximumWidth = layoutWidth - compactPanelWidth;
  return (layoutWidth * desktopWidthFraction)
      .clamp(compactPanelWidth, maximumWidth)
      .toDouble();
}
