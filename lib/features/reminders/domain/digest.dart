import 'package:meta/meta.dart';
import 'package:parcel_khata/features/reminders/domain/needs_attention.dart';

/// Quiet hours as minutes since midnight; the window may wrap midnight.
@immutable
class QuietHours {
  const QuietHours({required this.startMinute, required this.endMinute});

  final int startMinute;
  final int endMinute;

  bool get isEmpty => startMinute == endMinute;

  bool contains(int minuteOfDay) {
    if (isEmpty) return false;
    return startMinute < endMinute
        ? minuteOfDay >= startMinute && minuteOfDay < endMinute
        : minuteOfDay >= startMinute || minuteOfDay < endMinute;
  }

  /// If [t] falls inside quiet hours, the first moment after them.
  DateTime shiftOutOf(DateTime t) {
    final m = t.hour * 60 + t.minute;
    if (!contains(m)) return t;
    final day = DateTime(t.year, t.month, t.day);
    final end = day.add(Duration(minutes: endMinute));
    if (end.isAfter(t)) return end;
    return end.add(const Duration(days: 1));
  }
}

@immutable
class DigestCounts {
  const DigestCounts({
    this.stale = 0,
    this.overdueCod = 0,
    this.returns = 0,
    this.drafts = 0,
    this.disputes = 0,
    this.toDispatch = 0,
    this.backup = 0,
    this.overdueCodPoisha = 0,
  });

  final int stale;
  final int overdueCod;
  final int returns;
  final int drafts;
  final int disputes;
  final int toDispatch;
  final int backup;
  final int overdueCodPoisha;

  int get total => stale + overdueCod + returns + drafts + disputes + toDispatch + backup;
  bool get isEmpty => total == 0;
}

abstract final class DigestBuilder {
  /// Counts the queue for the digest, honoring per-type toggles.
  static DigestCounts count(
    List<AttentionItem> items, {
    Set<AttentionKind>? enabled,
  }) {
    var stale = 0, overdue = 0, returns = 0, drafts = 0, disputes = 0, dispatch = 0, backup = 0;
    var money = 0;
    for (final i in items) {
      if (enabled != null && !enabled.contains(i.kind)) continue;
      switch (i.kind) {
        case AttentionKind.staleHandedOver:
          stale++;
        case AttentionKind.overdueCod:
          overdue++;
          money += i.order?.outstandingPoisha ?? 0;
        case AttentionKind.returnTooLong:
          returns++;
        case AttentionKind.oldDraft:
          drafts++;
        case AttentionKind.dispute:
          disputes++;
        case AttentionKind.toDispatch:
          dispatch++;
        case AttentionKind.backupDue:
          backup++;
      }
    }
    return DigestCounts(
      stale: stale,
      overdueCod: overdue,
      returns: returns,
      drafts: drafts,
      disputes: disputes,
      toDispatch: dispatch,
      backup: backup,
      overdueCodPoisha: money,
    );
  }

  /// Next local time at [minuteOfDay] strictly after [now], moved out of quiet
  /// hours.
  static DateTime nextFireTime(DateTime now, int minuteOfDay, {QuietHours? quiet}) {
    var t = DateTime(now.year, now.month, now.day).add(Duration(minutes: minuteOfDay));
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return quiet == null ? t : quiet.shiftOutOf(t);
  }
}
