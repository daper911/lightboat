import 'package:collection/collection.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/lightboat/config.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/models/models.dart';

/// The group the home page calls 线路: `🚀 Proxy`, else the first selector.
Group? lbLineGroup(List<Group> groups) =>
    groups.firstWhereOrNull((group) => group.name == LbConfig.proxyGroup) ??
    groups.firstWhereOrNull((group) => group.type == GroupType.Selector);

/// The lines worth offering: everything in [line] except choices that end in
/// a direct connection, since 线路 never means "no proxy" (01: no 直连 mode).
List<Proxy> lbLineChoices(Group line, List<Group> groups) {
  bool direct(Proxy proxy, Set<String> seen) {
    if (_directTypes.contains(proxy.type)) return true;
    final group = groups.firstWhereOrNull((item) => item.name == proxy.name);
    if (group == null || !seen.add(group.name)) return false;
    return group.all.isNotEmpty &&
        group.all.every((member) => direct(member, seen));
  }

  return [
    for (final proxy in line.all)
      if (!direct(proxy, {})) proxy,
  ];
}

const _directTypes = {'Direct', 'Reject', 'RejectDrop', 'Pass', 'Compatible'};

String lbLineName(String? name) =>
    name == null || name == LbConfig.autoProxy ? LbStrings.autoLine : name;

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
