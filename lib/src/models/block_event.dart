/// The type of a block event.
enum BlockEventType {
  /// An app was blocked (overlay shown or shield applied).
  blocked,

  /// An app was unblocked (overlay hidden or shield removed).
  unblocked,

  /// A blocked app was attempted to be opened.
  attemptedAccess,

  /// A schedule was activated.
  scheduleActivated,

  /// A schedule was deactivated.
  scheduleDeactivated,
}

/// Represents an event that occurred during app blocking.
class BlockEvent {
  /// Creates a [BlockEvent] instance.
  const BlockEvent({
    required this.type,
    required this.timestamp,
    this.packageName,
    this.scheduleId,
  });

  /// The type of event.
  final BlockEventType type;

  /// When the event occurred.
  final DateTime timestamp;

  /// The package name of the affected app, if applicable.
  final String? packageName;

  /// The schedule ID that triggered this event, if applicable.
  final String? scheduleId;

  /// Creates a [BlockEvent] from a map.
  factory BlockEvent.fromMap(Map<String, dynamic> map) {
    return BlockEvent(
      type: BlockEventType.values.byName(map['type'] as String),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      packageName: map['packageName'] as String?,
      scheduleId: map['scheduleId'] as String?,
    );
  }

  @override
  String toString() =>
      'BlockEvent(type: $type, packageName: $packageName, timestamp: $timestamp)';
}
