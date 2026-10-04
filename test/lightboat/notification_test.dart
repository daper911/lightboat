import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/lightboat/notification.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _groups = [
  Group(type: GroupType.Selector, name: '🚀 Proxy', now: '🌏 Auto'),
  Group(type: GroupType.URLTest, name: '🌏 Auto', now: '香港 HK1 · Hysteria2'),
];

void main() {
  test('follows Auto to the node it picked', () {
    expect(lbCurrentNode(_groups), '香港 HK1 · Hysteria2');
    expect(
      lbCurrentNode(const [
        Group(
          type: GroupType.Selector,
          name: '🚀 Proxy',
          now: '香港 HK1 · Reality',
        ),
      ]),
      '香港 HK1 · Reality',
    );
    expect(lbCurrentNode(const []), isNull);
  });

  test('the notification title names the line once groups load', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(lbNotificationTitleProvider), LbStrings.appName);
    container.read(groupsProvider.notifier).value = _groups;
    expect(
      container.read(lbNotificationTitleProvider),
      '${LbStrings.appName} · 香港 HK1 · Hysteria2',
    );
  });
}
