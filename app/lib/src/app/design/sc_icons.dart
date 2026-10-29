import 'package:flutter/material.dart';

import 'sc_metrics.dart';

/// The studio icon vocabulary.
///
/// The design system draws Material Symbols Rounded from a network font; the
/// client uses the SDK's bundled rounded Material Icons instead, so the
/// offline guarantee holds (ADR-0003 D7).
abstract final class ScIcons {
  /// Toolbar and control icon size.
  static const double toolbarSize = ScMetrics.toolbarIcon;

  /// Transport play.
  static const IconData play = Icons.play_arrow_rounded;

  /// Transport pause.
  static const IconData pause = Icons.pause_rounded;

  /// Previous rally or clip.
  static const IconData skipPrevious = Icons.skip_previous_rounded;

  /// Next rally or clip.
  static const IconData skipNext = Icons.skip_next_rounded;

  /// Seek backward.
  static const IconData rewind = Icons.fast_rewind_rounded;

  /// Seek forward.
  static const IconData forward = Icons.fast_forward_rounded;

  /// Command or library search.
  static const IconData search = Icons.search_rounded;

  /// Close a sheet or clear a value.
  static const IconData close = Icons.close_rounded;

  /// Add a workspace, rally, or tag.
  static const IconData add = Icons.add_rounded;

  /// Delete the named object.
  static const IconData delete = Icons.delete_outline_rounded;

  /// A completed step.
  static const IconData check = Icons.check_rounded;

  /// A completed or successful state.
  static const IconData checkCircle = Icons.check_circle_outline_rounded;

  /// A warning that does not block.
  static const IconData warning = Icons.warning_amber_rounded;

  /// A failure.
  static const IconData error = Icons.error_outline_rounded;

  /// A live or blocked state.
  static const IconData blocked = Icons.block_rounded;

  /// A job that is running.
  static const IconData running = Icons.autorenew_rounded;

  /// A state that needs the user.
  static const IconData review = Icons.rate_review_rounded;

  /// A state with nothing to report.
  static const IconData idle = Icons.remove_circle_outline_rounded;

  /// The shared timeline.
  static const IconData timeline = Icons.timeline_rounded;

  /// A video or the library.
  static const IconData movie = Icons.movie_rounded;

  /// The score panel.
  static const IconData scoreboard = Icons.scoreboard_rounded;

  /// Import a recording.
  static const IconData upload = Icons.file_upload_rounded;

  /// Export a reel.
  static const IconData download = Icons.download_rounded;

  /// Enter focus mode.
  static const IconData fullscreen = Icons.fullscreen_rounded;

  /// Leave focus mode.
  static const IconData fullscreenExit = Icons.fullscreen_exit_rounded;

  /// Previous pipeline stage.
  static const IconData chevronLeft = Icons.chevron_left_rounded;

  /// Next pipeline stage.
  static const IconData chevronRight = Icons.chevron_right_rounded;

  /// More actions.
  static const IconData more = Icons.more_horiz_rounded;

  /// Filter a list.
  static const IconData filter = Icons.filter_list_rounded;

  /// The grid layout.
  static const IconData gridView = Icons.grid_view_rounded;

  /// Toggle the inspector rail.
  static const IconData viewSidebar = Icons.view_sidebar_rounded;

  /// Mark the court.
  static const IconData cropFree = Icons.crop_free_rounded;

  /// The court surface.
  static const IconData court = Icons.grid_on_rounded;
}
