const double compactPanelWidth = 350;
const double desktopPanelBreakpoint = 710;

double sidePanelWidthForLayout({
  required double layoutWidth,
  required bool minimized,
  double? desktopWidthFraction,
  bool desktopExpanded = false,
}) {
  if (layoutWidth < 490 && minimized) return layoutWidth;
  if (layoutWidth < desktopPanelBreakpoint || desktopWidthFraction == null) {
    return compactPanelWidth;
  }
  if (desktopExpanded) return layoutWidth;

  final maximumWidth = layoutWidth - compactPanelWidth;
  return (layoutWidth * desktopWidthFraction)
      .clamp(compactPanelWidth, maximumWidth)
      .toDouble();
}

double mainScreenWidthForLayout({
  required double layoutWidth,
  required bool panelVisible,
  required double panelWidth,
  required bool desktopExpanded,
}) {
  if (!panelVisible ||
      layoutWidth < desktopPanelBreakpoint ||
      desktopExpanded) {
    return layoutWidth;
  }

  return (layoutWidth - panelWidth - 5).clamp(0, layoutWidth).toDouble();
}
