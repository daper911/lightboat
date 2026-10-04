import 'package:collection/collection.dart';
import 'package:fl_clash/lightboat/pages/home.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The node traffic leaves through, following 🌏 Auto and any nested group to
/// its current pick.
String? lbCurrentNode(List<Group> groups) {
  var name = lbLineGroup(groups)?.now;
  for (var depth = 0; depth < 4 && name != null; depth++) {
    final group = groups.firstWhereOrNull((item) => item.name == name);
    if (group == null) break;
    name = group.now;
  }
  return name == null || name.isEmpty ? null : name;
}

/// Title of the Android connection notification (FlClash's
/// `currentProfileName`), so the shade names the line in use.
final lbNotificationTitleProvider = Provider<String>((ref) {
  final node = ref.watch(groupsProvider.select(lbCurrentNode));
  return node == null ? LbStrings.appName : '${LbStrings.appName} · $node';
});
