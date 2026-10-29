/// Fixed studio geometry, mirroring `studio.html` and the plan's target
/// layout.
///
/// These are layout values, not colours: they stay plain `static const`
/// doubles so a widget can read one without a `BuildContext`. The design
/// layer owns every number; feature code must not hard-code its own.
abstract final class ScMetrics {
  /// Unified toolbar height.
  static const double toolbarHeight = 52;

  /// Pipeline stage strip height (an app-specific extension).
  static const double stageStripHeight = 40;

  /// Video library rail width at the reference window.
  static const double libraryWidth = 264;

  /// Inspector rail width at the reference window.
  static const double inspectorWidth = 320;

  /// Library width between 1040 and 1199 logical pixels.
  static const double libraryWidthNarrow1 = 240;

  /// Inspector width between 1040 and 1199 logical pixels.
  static const double inspectorWidthNarrow1 = 292;

  /// Library width between 980 and 1039 logical pixels.
  static const double libraryWidthNarrow2 = 222;

  /// Inspector width between 980 and 1039 logical pixels.
  static const double inspectorWidthNarrow2 = 270;

  /// Gutter between a rail and the preview.
  static const double railGutter = 12;

  /// Smallest preview width that stays readable.
  static const double previewMinWidth = 480;

  /// Width below which the three-pane layout stacks.
  static const double collapseBreakpoint = 980;

  /// First narrow-rail breakpoint.
  static const double narrowBreakpoint1 = 1200;

  /// Second narrow-rail breakpoint.
  static const double narrowBreakpoint2 = 1040;

  /// Shared timeline dock height.
  static const double timelineHeight = 176;

  /// Timeline dock header height.
  static const double timelineHeaderHeight = 34;

  /// Timeline label gutter.
  static const double timelineGutter = 112;

  /// Timeline ruler track height.
  static const double timelineRuler = 24;

  /// Timeline rally track height.
  static const double timelineRally = 44;

  /// Timeline score track height.
  static const double timelineScore = 32;

  /// Working window shown by the timeline, in seconds.
  static const double timelineWindowSeconds = 600;

  /// [timelineWindowSeconds] in whole milliseconds.
  static const int timelineWindowSecondsMs = 600 * 1000;

  /// Smallest drawn rally segment width.
  static const double rallySegmentMinWidth = 14;

  /// Rally segment hit target.
  static const double rallySegmentHitTarget = 20;

  /// Status bar height.
  static const double statusHeight = 30;

  /// Compact row height.
  static const double rowCompact = 44;

  /// Rich row height.
  static const double rowRich = 56;

  /// Confirmation dialog width.
  static const double dialogConfirm = 420;

  /// Settings dialog width.
  static const double dialogSettings = 520;

  /// Export sheet width.
  static const double exportSheetWidth = 440;

  /// Smallest supported window width.
  static const double minWindowWidth = 1100;

  /// Smallest supported window height.
  static const double minWindowHeight = 720;

  /// Reference window width for visual checks.
  static const double referenceWindowWidth = 1440;

  /// Reference window height for visual checks.
  static const double referenceWindowHeight = 900;

  /// Icon button hit target.
  static const double iconButton = 44;

  /// Icon button visual square.
  static const double iconButtonVisual = 36;

  /// Toolbar tool visual square.
  static const double toolButton = 30;

  /// Toolbar icon size.
  static const double toolbarIcon = 18;

  /// Default button height.
  static const double button = 40;

  /// Compact button height.
  static const double buttonCompact = 32;

  /// Inspector tab height.
  static const double tab = 26;

  /// Chip height.
  static const double chip = 20;

  /// Field height.
  static const double field = 34;

  /// Court handle visual square.
  static const double courtHandleVisual = 24;

  /// Court handle hit target.
  static const double courtHandleHit = 44;

  /// Vertical section rhythm on a desktop window.
  static const double sectionYDesktop = 72;

  /// Vertical section rhythm on a tablet-width window.
  static const double sectionYTablet = 56;

  /// Vertical section rhythm on a phone-width window.
  static const double sectionYPhone = 40;

  /// Largest content measure.
  static const double containerMax = 1240;

  /// Content gutter on a desktop window.
  static const double containerGutterDesktop = 40;

  /// Content gutter on a tablet-width window.
  static const double containerGutterTablet = 28;

  /// Content gutter on a phone-width window.
  static const double containerGutterPhone = 20;

  /// Library thumbnail width.
  static const double thumbWidth = 52;

  /// Library thumbnail height: the 16:9 frame at [thumbWidth].
  static const double thumbHeight = 30;

  /// Library thumbnail corner radius.
  static const double thumbRadius = 4;

  /// Horizontal inset of the sketched court inside a library thumbnail.
  static const double thumbCourtInsetX = 8;

  /// Vertical inset of the sketched court inside a library thumbnail.
  static const double thumbCourtInsetY = 4;

  /// Default toolbar search-field width.
  static const double searchFieldWidth = 260;

  /// Leading toolbar inset that keeps the Flutter controls clear of the
  /// native macOS traffic lights (ADR-0003 D6).
  static const double trafficLightInset = 78;

  /// Library thumbnail corner radius role (ADR-0003 D15).
  static const double radiusThumb = 4;

  /// Toolbar tool and dense control corner radius role.
  static const double radiusTool = 7;

  /// Stage strip tab-track corner radius role.
  static const double radiusTabTrack = 8;

  /// Keyboard keycap corner radius role.
  static const double radiusKeycap = 4;

  /// Height of each pane when the studio stacks below
  /// [collapseBreakpoint].
  static const double stackedPaneHeight = 360;

  /// Height of the preview pane's own header strip.
  static const double previewHeaderHeight = 40;
}
