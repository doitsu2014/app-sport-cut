/// A named group of imported recordings.
///
/// A workspace is a loose folder, not a locked session: it has a title and a
/// creation date, and videos can be added to it at any time. It owns no
/// artifacts of its own — every video in it still runs the existing one-video
/// pipeline.
class Workspace {
  /// Create a workspace.
  const Workspace({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  /// Stable identifier.
  final String id;

  /// Title shown in the workspace list.
  final String title;

  /// When the workspace was created.
  final DateTime createdAt;
}
