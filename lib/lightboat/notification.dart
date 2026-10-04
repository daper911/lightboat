import 'package:fl_clash/lightboat/line_groups.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Title of the Android connection notification (FlClash's
/// `currentProfileName`), so the shade names the line in use.
final lbNotificationTitleProvider = Provider<String>((ref) {
  final node = ref.watch(groupsProvider.select(lbCurrentNode));
  return node == null ? LbStrings.appName : '${LbStrings.appName} · $node';
});
