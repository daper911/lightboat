import 'dart:collection';

/// A request the app made itself; the Core's log never sees these.
class LbEvent {
  final DateTime at;
  final String request;
  final String result;
  final int ms;
  final String? detail;

  const LbEvent({
    required this.at,
    required this.request,
    required this.result,
    required this.ms,
    this.detail,
  });

  String format() {
    final local = at.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final zone =
        '$sign${two(offset.inHours.abs())}:${two(offset.inMinutes.abs() % 60)}';
    final time =
        '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)} $zone';
    final more = detail == null ? '' : '  $detail';
    return '$time  $request  $result  ${ms}ms$more';
  }
}

class LbEvents {
  static const capacity = 30;
  static const _detailLimit = 160;

  final Queue<LbEvent> _items = Queue();

  /// The query is dropped, so a subscription token never lands here.
  void add({
    required String method,
    required Uri uri,
    required String result,
    required Duration elapsed,
    Object? detail,
  }) {
    final text = detail?.toString().replaceAll('\n', ' ');
    _items.addLast(
      LbEvent(
        at: DateTime.now(),
        request: '$method ${uri.host}${uri.path}',
        result: result,
        ms: elapsed.inMilliseconds,
        detail: text == null || text.length <= _detailLimit
            ? text
            : '${text.substring(0, _detailLimit)}…',
      ),
    );
    while (_items.length > capacity) {
      _items.removeFirst();
    }
  }

  List<LbEvent> recent([int count = capacity]) =>
      _items.toList().reversed.take(count).toList().reversed.toList();

  void clear() => _items.clear();
}

final lbEvents = LbEvents();
