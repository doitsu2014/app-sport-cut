/// What the user did with a machine-proposed rally boundary.
enum SuggestionDecisionKind {
  /// Turned the proposal into an unscored rally.
  accepted,

  /// Hid the proposal for this analysis generation.
  dismissed,
}

/// A durable decision scoped to one version of the analysis inputs.
class SuggestionDecision {
  /// Create a reviewed suggestion record.
  const SuggestionDecision({
    required this.generationId,
    required this.candidateId,
    required this.kind,
    this.rallyId,
  });

  /// Identity of the analysis generation.
  final String generationId;

  /// Identity of the proposal within that generation.
  final String candidateId;

  /// Accepted or dismissed by the user.
  final SuggestionDecisionKind kind;

  /// Rally created by acceptance, when it still exists.
  final String? rallyId;
}
